import Foundation

enum LocationSimulationCommandQueue {
    static let shared = DispatchQueue(label: "com.ufogo.location-sim", qos: .userInitiated)

    static func preconditionIsolated() {
        dispatchPrecondition(condition: .onQueue(shared))
    }
}

struct LocationSimulationError: Error, Equatable, Identifiable, LocalizedError {
    let code: Int32
    let operation: String

    var id: String { "\(operation)-\(code)" }

    var errorDescription: String? {
        LocationSimulationErrorCatalog.message(for: code, operation: operation)
    }
}

extension Result {
    var failure: Failure? {
        guard case .failure(let error) = self else { return nil }
        return error
    }
}

private protocol DeviceLocationTransport: AnyObject {
    func setLocation(
        deviceIP: String,
        latitude: Double,
        longitude: Double,
        pairingFile: String
    ) -> Int32
    func clearLocation() -> Int32
    func resetConnectionState()
}

private final class ClosureDeviceLocationTransport: DeviceLocationTransport {
    private let setOperation: (String, Double, Double, String) -> Int32
    private let clearOperation: () -> Int32
    private let resetOperation: () -> Void

    init(
        setOperation: @escaping (String, Double, Double, String) -> Int32,
        clearOperation: @escaping () -> Int32,
        resetOperation: @escaping () -> Void
    ) {
        self.setOperation = setOperation
        self.clearOperation = clearOperation
        self.resetOperation = resetOperation
    }

    func setLocation(
        deviceIP: String,
        latitude: Double,
        longitude: Double,
        pairingFile: String
    ) -> Int32 {
        setOperation(deviceIP, latitude, longitude, pairingFile)
    }

    func clearLocation() -> Int32 {
        clearOperation()
    }

    func resetConnectionState() {
        resetOperation()
    }
}

/// Thread-safe because every transport access is serialized through `queue`.
final class LocationSimulationService: @unchecked Sendable {
    static let shared = LocationSimulationService()

    typealias Completion = @MainActor (Result<Void, LocationSimulationError>) -> Void

    private let queue: DispatchQueue
    private let transport: DeviceLocationTransport

    init(
        queue: DispatchQueue = LocationSimulationCommandQueue.shared,
        setOperation: @escaping (String, Double, Double, String) -> Int32 = {
            ProductionDeviceLocationTransport.shared.setLocation(
                deviceIP: $0,
                latitude: $1,
                longitude: $2,
                pairingFile: $3
            )
        },
        clearOperation: @escaping () -> Int32 = {
            ProductionDeviceLocationTransport.shared.clearLocation()
        },
        resetOperation: @escaping () -> Void = {
            ProductionDeviceLocationTransport.shared.resetConnectionState()
        }
    ) {
        self.queue = queue
        self.transport = ClosureDeviceLocationTransport(
            setOperation: setOperation,
            clearOperation: clearOperation,
            resetOperation: resetOperation
        )
    }

    func setLocation(
        deviceIP: String,
        latitude: Double,
        longitude: Double,
        pairingFile: String,
        operation: String,
        completion: @escaping Completion
    ) {
        queue.async {
            let code = self.transport.setLocation(
                deviceIP: deviceIP,
                latitude: latitude,
                longitude: longitude,
                pairingFile: pairingFile
            )
            let result = Self.result(code: code, operation: operation)
            Task { @MainActor in completion(result) }
        }
    }

    func setLocation(
        deviceIP: String,
        latitude: Double,
        longitude: Double,
        pairingFile: String,
        operation: String
    ) async -> Result<Void, LocationSimulationError> {
        await withCheckedContinuation { continuation in
            setLocation(
                deviceIP: deviceIP,
                latitude: latitude,
                longitude: longitude,
                pairingFile: pairingFile,
                operation: operation
            ) { result in
                continuation.resume(returning: result)
            }
        }
    }

    func clearLocation(
        operation: String,
        after delay: TimeInterval = 0,
        completion: @escaping Completion
    ) {
        queue.asyncAfter(deadline: .now() + delay) {
            let code = self.transport.clearLocation()
            let result = Self.result(code: code, operation: operation)
            Task { @MainActor in completion(result) }
        }
    }

    func clearLocation(
        operation: String,
        after delay: TimeInterval = 0
    ) async -> Result<Void, LocationSimulationError> {
        await withCheckedContinuation { continuation in
            clearLocation(operation: operation, after: delay) { result in
                continuation.resume(returning: result)
            }
        }
    }

    func resetConnectionState() {
        queue.async {
            self.transport.resetConnectionState()
        }
    }

    func resetConnectionState() async {
        await withCheckedContinuation { continuation in
            queue.async {
                self.transport.resetConnectionState()
                continuation.resume(returning: ())
            }
        }
    }

    static func result(
        code: Int32,
        operation: String
    ) -> Result<Void, LocationSimulationError> {
        code == 0
            ? .success(())
            : .failure(LocationSimulationError(code: code, operation: operation))
    }

    /// App 即將終止時同步清除定位（best-effort，在 ~5 秒視窗內完成）。
    func clearLocationSync() {
        queue.sync {
            _ = self.transport.clearLocation()
        }
    }
}

struct LocationSimulationErrorDefinition: Identifiable {
    let code: Int32
    let title: String
    let recovery: String
    var id: Int32 { code }
}

enum LocationSimulationErrorCatalog {
    static let definitions: [LocationSimulationErrorDefinition] = [
        .init(code: 1, title: "目標位址無效", recovery: "請檢查 VPN 與目標 IP 設定。"),
        .init(code: 2, title: "配對文件無法讀取", recovery: "請重新導入此裝置的有效配對文件。"),
        .init(code: 3, title: "配對 Tunnel 建立失敗", recovery: "請確認 Wi-Fi 與 LocalDevVPN 已開啟。"),
        .init(code: 9, title: "RSD 連線失敗", recovery: "請重新連接 VPN 後再試一次。"),
        .init(code: 10, title: "定位服務建立失敗", recovery: "請確認目前 iOS 版本相容並重新連線。"),
        .init(code: 11, title: "座標設定失敗", recovery: "請停止模擬、重新連線後再試一次。"),
        .init(code: 12, title: "清除模擬位置失敗", recovery: "目前可能沒有有效連線，請重新連線後再停止。"),
        .init(code: 13, title: "另一種模擬正在執行", recovery: "請先停止目前的定位模擬。"),
        .init(code: 14, title: "尚未啟動模擬", recovery: "請先啟動定位後再更新座標。")
    ]

    static func definition(for code: Int32) -> LocationSimulationErrorDefinition {
        definitions.first(where: { $0.code == code })
            ?? .init(code: code, title: "未知錯誤", recovery: "請重新連線；若持續發生，請保留錯誤碼回報。")
    }

    static func message(for code: Int32, operation: String) -> String {
        let error = definition(for: code)
        return "\(operation)失敗（錯誤碼 \(code)：\(error.title)）。\(error.recovery)"
    }
}

#if targetEnvironment(simulator)

private final class ProductionDeviceLocationTransport: DeviceLocationTransport {
    static let shared = ProductionDeviceLocationTransport()

    func setLocation(
        deviceIP: String,
        latitude: Double,
        longitude: Double,
        pairingFile: String
    ) -> Int32 {
        LocationSimulationCommandQueue.preconditionIsolated()
        return 0
    }

    func clearLocation() -> Int32 {
        LocationSimulationCommandQueue.preconditionIsolated()
        return 0
    }

    func resetConnectionState() {
        LocationSimulationCommandQueue.preconditionIsolated()
    }
}

#else

import idevice

private enum LocationSimulationStatus {
    static let ok: Int32 = 0
    static let invalidIP: Int32 = 1
    static let pairingRead: Int32 = 2
    static let providerCreate: Int32 = 3
    static let remoteServer: Int32 = 9
    static let locationSimulation: Int32 = 10
    static let locationSet: Int32 = 11
    static let locationClear: Int32 = 12
}

private final class ProductionDeviceLocationTransport: DeviceLocationTransport {
    static let shared = ProductionDeviceLocationTransport()

    private var adapter: OpaquePointer?
    private var handshake: OpaquePointer?
    private var remoteServer: OpaquePointer?
    private var locationSimulation: OpaquePointer?

    private func cleanup() {
        if let locationSimulation {
            location_simulation_free(locationSimulation)
            self.locationSimulation = nil
        }
        if let remoteServer {
            remote_server_free(remoteServer)
            self.remoteServer = nil
        }
        if let handshake {
            rsd_handshake_free(handshake)
            self.handshake = nil
        }
        if let adapter {
            adapter_free(adapter)
            self.adapter = nil
        }
    }

    func setLocation(
        deviceIP: String,
        latitude: Double,
        longitude: Double,
        pairingFile: String
    ) -> Int32 {
        LocationSimulationCommandQueue.preconditionIsolated()

    if let locationSimulation {
        if let ffiError = location_simulation_set(locationSimulation, latitude, longitude) {
            idevice_error_free(ffiError)
            cleanup()
        } else {
            return LocationSimulationStatus.ok
        }
    }

    var address = sockaddr_in()
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = in_port_t(49152).bigEndian

    let inetResult = deviceIP.withCString { inet_pton(AF_INET, $0, &address.sin_addr) }
    guard inetResult == 1 else {
        return LocationSimulationStatus.invalidIP
    }

    var pairingHandle: OpaquePointer?
    let pairingError = pairingFile.withCString { rp_pairing_file_read($0, &pairingHandle) }
    if let pairingError {
        idevice_error_free(pairingError)
        return LocationSimulationStatus.pairingRead
    }

    guard let pairingHandle else {
        return LocationSimulationStatus.pairingRead
    }

    defer { rp_pairing_file_free(pairingHandle) }

    let providerError = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            tunnel_create_rppairing(
                $0,
                socklen_t(MemoryLayout<sockaddr_in>.stride),
                "UFOGeoLocation",
                pairingHandle,
                nil,
                nil,
                &adapter,
                &handshake
            )
        }
    }

    if let providerError {
        idevice_error_free(providerError)
        cleanup()
        return LocationSimulationStatus.providerCreate
    }

    let remoteServerError = remote_server_connect_rsd(
        adapter,
        handshake,
        &remoteServer
    )
    if let remoteServerError {
        idevice_error_free(remoteServerError)
        cleanup()
        return LocationSimulationStatus.remoteServer
    }

    let locationSimulationError = location_simulation_new(
        remoteServer,
        &locationSimulation
    )
    if let locationSimulationError {
        idevice_error_free(locationSimulationError)
        cleanup()
        return LocationSimulationStatus.locationSimulation
    }
    // location_simulation_new borrows the server pointer. The caller continues
    // to own it and releases it after the location handle during cleanup.

    let locationSetError = location_simulation_set(
        locationSimulation,
        latitude,
        longitude
    )
    if let locationSetError {
        idevice_error_free(locationSetError)
        cleanup()
        return LocationSimulationStatus.locationSet
    }

    return LocationSimulationStatus.ok
    }

    func clearLocation() -> Int32 {
        LocationSimulationCommandQueue.preconditionIsolated()

    guard let locationSimulation else {
        // Stopping an already-stopped simulation is a successful no-op.
        return LocationSimulationStatus.ok
    }

    let ffiError = location_simulation_clear(locationSimulation)
    cleanup()

    if let ffiError {
        idevice_error_free(ffiError)
        return LocationSimulationStatus.locationClear
    }

    return LocationSimulationStatus.ok
    }

    func resetConnectionState() {
        LocationSimulationCommandQueue.preconditionIsolated()
        cleanup()
    }
}

#endif
