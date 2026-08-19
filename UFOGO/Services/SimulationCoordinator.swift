import CoreLocation
import Combine
import Foundation

enum SimulationMode: String, Equatable {
    case fixedLocation
    case route
}

enum SimulationSessionState: Equatable {
    case idle
    case starting(SimulationMode)
    case running(SimulationMode)
    case stopping(SimulationMode)
    case failed(SimulationMode?, LocationSimulationError)

    var activeMode: SimulationMode? {
        switch self {
        case .idle:
            return nil
        case .starting(let mode), .running(let mode), .stopping(let mode):
            return mode
        case .failed:
            return nil
        }
    }
}

@MainActor
final class SimulationCoordinator: ObservableObject {
    static let shared = SimulationCoordinator()
    private static let recoverableStartFailureCodes: Set<Int32> = [3, 9]
    private static let recoverableUpdateFailureCodes: Set<Int32> = [3, 9, 11]
    private static let recoverableStopFailureCodes: Set<Int32> = [3, 9, 12]
    private static let startRetryDelayNanoseconds: UInt64 = 300_000_000

    @Published private(set) var state: SimulationSessionState = .idle
    @Published private(set) var lastCoordinate: CLLocationCoordinate2D?

    private let service: LocationSimulationService
    private var generation = 0
    private var allowsModeSwitchWhileHoldingLocation = false

    init(service: LocationSimulationService = .shared) {
        self.service = service
    }

    func start(
        mode: SimulationMode,
        coordinate: CLLocationCoordinate2D,
        deviceIP: String,
        pairingFile: String,
        operation: String,
        completion: @escaping @MainActor (Result<Void, LocationSimulationError>) -> Void
    ) {
        Task {
            completion(await start(
                mode: mode,
                coordinate: coordinate,
                deviceIP: deviceIP,
                pairingFile: pairingFile,
                operation: operation
            ))
        }
    }

    @discardableResult
    func start(
        mode: SimulationMode,
        coordinate: CLLocationCoordinate2D,
        deviceIP: String,
        pairingFile: String,
        operation: String
    ) async -> Result<Void, LocationSimulationError> {
        if let activeMode = state.activeMode,
           activeMode != mode,
           !allowsModeSwitchWhileHoldingLocation {
            let error = LocationSimulationError(code: 13, operation: operation)
            state = .failed(activeMode, error)
            return .failure(error)
        }

        allowsModeSwitchWhileHoldingLocation = false
        generation += 1
        let commandGeneration = generation
        state = .starting(mode)
        let result = await setLocationWithRecoverableRetry(
            deviceIP: deviceIP,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            pairingFile: pairingFile,
            operation: operation,
            retryFailureCodes: Self.recoverableStartFailureCodes
        )

        guard commandGeneration == generation else { return result }

        switch result {
        case .success:
            lastCoordinate = coordinate
            state = .running(mode)
            BackgroundSimulationManager.shared.markSimulationActive(mode: mode)
            let bgActivity: BackgroundLocationManager.Activity = (mode == .route) ? .route : .continuousLocation
            BackgroundLocationManager.shared.requestStart(for: bgActivity)
        case .failure(let error):
            state = .failed(mode, error)
        }
        return result
    }

    @discardableResult
    func update(
        coordinate: CLLocationCoordinate2D,
        deviceIP: String,
        pairingFile: String,
        operation: String
    ) async -> Result<Void, LocationSimulationError> {
        guard case .running(let mode) = state else {
            let error = LocationSimulationError(code: 14, operation: operation)
            return .failure(error)
        }

        let commandGeneration = generation
        let result = await setLocationWithRecoverableRetry(
            deviceIP: deviceIP,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            pairingFile: pairingFile,
            operation: operation,
            retryFailureCodes: Self.recoverableUpdateFailureCodes
        )
        guard commandGeneration == generation else { return result }

        switch result {
        case .success:
            lastCoordinate = coordinate
            state = .running(mode)
        case .failure(let error):
            // Keep session in running state for transient update failures.
            // Callers still receive the failure and can decide UI/retry behavior.
            state = .running(mode)
            _ = error
        }
        return result
    }

    func update(
        coordinate: CLLocationCoordinate2D,
        deviceIP: String,
        pairingFile: String,
        operation: String,
        completion: @escaping @MainActor (Result<Void, LocationSimulationError>) -> Void
    ) {
        Task {
            completion(await update(
                coordinate: coordinate,
                deviceIP: deviceIP,
                pairingFile: pairingFile,
                operation: operation
            ))
        }
    }

    @discardableResult
    func stop(
        operation: String,
        after delay: TimeInterval = 0
    ) async -> Result<Void, LocationSimulationError> {
        let mode = state.activeMode
        allowsModeSwitchWhileHoldingLocation = false
        generation += 1
        let commandGeneration = generation
        if let mode {
            state = .stopping(mode)
        }

        let result = await clearLocationWithRecoverableRetry(
            operation: operation,
            after: delay,
            retryFailureCodes: Self.recoverableStopFailureCodes
        )
        guard commandGeneration == generation else { return result }

        switch result {
        case .success:
            lastCoordinate = nil
            state = .idle
        case .failure(let error):
            state = .failed(mode, error)
        }
        return result
    }

    /// 使用者已停止目前的移動，但裝置仍保留最後模擬座標。
    /// 下一次啟動可直接接管並切換模式，不必先清除座標。
    func allowNextModeSwitchWhileHoldingLocation() {
        allowsModeSwitchWhileHoldingLocation = true
    }

    func stop(
        operation: String,
        after delay: TimeInterval = 0,
        completion: @escaping @MainActor (Result<Void, LocationSimulationError>) -> Void
    ) {
        Task {
            completion(await stop(operation: operation, after: delay))
        }
    }

    private func setLocationWithRecoverableRetry(
        deviceIP: String,
        latitude: Double,
        longitude: Double,
        pairingFile: String,
        operation: String,
        retryFailureCodes: Set<Int32>
    ) async -> Result<Void, LocationSimulationError> {
        var result = await service.setLocation(
            deviceIP: deviceIP,
            latitude: latitude,
            longitude: longitude,
            pairingFile: pairingFile,
            operation: operation
        )

        guard shouldRetryRecoverableFailure(result, retryFailureCodes: retryFailureCodes) else {
            return result
        }

        await service.resetConnectionState()
        try? await Task.sleep(nanoseconds: Self.startRetryDelayNanoseconds)
        result = await service.setLocation(
            deviceIP: deviceIP,
            latitude: latitude,
            longitude: longitude,
            pairingFile: pairingFile,
            operation: "\(operation)（重試）"
        )
        return result
    }

    private func clearLocationWithRecoverableRetry(
        operation: String,
        after delay: TimeInterval,
        retryFailureCodes: Set<Int32>
    ) async -> Result<Void, LocationSimulationError> {
        var result = await service.clearLocation(operation: operation, after: delay)

        guard shouldRetryRecoverableFailure(result, retryFailureCodes: retryFailureCodes) else {
            return result
        }

        await service.resetConnectionState()
        try? await Task.sleep(nanoseconds: Self.startRetryDelayNanoseconds)
        result = await service.clearLocation(
            operation: "\(operation)（重試）",
            after: 0
        )
        return result
    }

    private func shouldRetryRecoverableFailure(
        _ result: Result<Void, LocationSimulationError>,
        retryFailureCodes: Set<Int32>
    ) -> Bool {
        guard case .failure(let error) = result else { return false }
        return retryFailureCodes.contains(error.code)
    }

}
