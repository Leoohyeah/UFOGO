import CoreLocation
import Foundation

struct RouteSimulationState {
    var pointIndex: Int
    var segmentProgress: Double
    var coordinate: CLLocationCoordinate2D
    var orbitAngleRadians: Double = -.pi / 2
    var isOrbitingCurrentPoint: Bool = false
}

enum RouteSimulationTransition {
    case advanced(RouteSimulationState)
    case completed(RouteSimulationState)
}

struct RouteSimulationEngine {
    private static let earthRadiusMeters: Double = 6_378_137

    private let coordinates: [CLLocationCoordinate2D]
    private let startIndex: Int
    private let completionMode: PathCompletionMode
    private let planningMode: RoutePlanningMode
    private let orbitRadiusMeters: Double

    init?(
        coordinates: [CLLocationCoordinate2D],
        startIndex: Int,
        completionMode: PathCompletionMode,
        planningMode: RoutePlanningMode,
        orbitRadiusMeters: Double = 30
    ) {
        guard coordinates.count >= 2, coordinates.indices.contains(startIndex) else {
            return nil
        }
        self.coordinates = coordinates
        self.startIndex = startIndex
        self.completionMode = completionMode
        self.planningMode = planningMode
        self.orbitRadiusMeters = max(1, orbitRadiusMeters)
    }

    func initialState() -> RouteSimulationState {
        RouteSimulationState(
            pointIndex: startIndex,
            segmentProgress: 0,
            coordinate: coordinates[startIndex]
        )
    }

    func advance(
        state: RouteSimulationState,
        distanceMeters: Double
    ) -> RouteSimulationTransition {
        if planningMode == .orbitEachWaypoint {
            return advanceByOrbitingWaypoint(state: state, distanceMeters: distanceMeters)
        }

        guard coordinates.indices.contains(state.pointIndex) else {
            return .completed(initialState())
        }

        var nextState = state
        var remainingDistance = max(distanceMeters, 0)
        let iterationLimit = max(coordinates.count * 10_000, 10_000)
        var iterations = 0

        while remainingDistance > 0, iterations < iterationLimit {
            iterations += 1
            let fromIndex = nextState.pointIndex
            guard let toIndex = nextIndex(after: fromIndex) else {
                nextState.coordinate = coordinates[fromIndex]
                return .completed(nextState)
            }

            let from = coordinates[fromIndex]
            let to = coordinates[toIndex]
            let segmentDistance = max(distance(from: from, to: to), 0.01)
            let distanceToEnd = segmentDistance * (1 - nextState.segmentProgress)

            if remainingDistance < distanceToEnd {
                nextState.segmentProgress += remainingDistance / segmentDistance
                nextState.coordinate = interpolate(
                    from: from,
                    to: to,
                    progress: nextState.segmentProgress
                )
                return .advanced(nextState)
            }

            remainingDistance -= distanceToEnd
            nextState.pointIndex = toIndex
            nextState.segmentProgress = 0
            nextState.coordinate = to

            if completionMode == .stopAtLast, toIndex == coordinates.count - 1 {
                return .completed(nextState)
            }
            if completionMode == .returnToStart,
               toIndex == startIndex,
               fromIndex != startIndex {
                return .completed(nextState)
            }
        }

        return .advanced(nextState)
    }

    private func advanceByOrbitingWaypoint(
        state: RouteSimulationState,
        distanceMeters: Double
    ) -> RouteSimulationTransition {
        guard coordinates.indices.contains(state.pointIndex) else {
            return .completed(initialState())
        }

        var nextState = state
        var remainingDistance = max(distanceMeters, 0)
        let circumference = 2 * .pi * orbitRadiusMeters
        let iterationLimit = max(coordinates.count * 2_000, 10_000)
        var iterations = 0

        while remainingDistance > 0, iterations < iterationLimit {
            iterations += 1
            let center = coordinates[nextState.pointIndex]

            if !nextState.isOrbitingCurrentPoint {
                // 進入新點位時先瞬移到中心，再開始繞圈。
                nextState.coordinate = center
                nextState.segmentProgress = 0
                nextState.orbitAngleRadians = -.pi / 2
                nextState.isOrbitingCurrentPoint = true
            }

            let lapRemaining = circumference * (1 - nextState.segmentProgress)
            if remainingDistance < lapRemaining {
                nextState.segmentProgress += remainingDistance / circumference
                nextState.orbitAngleRadians += remainingDistance / orbitRadiusMeters
                nextState.coordinate = orbitCoordinate(
                    center: center,
                    radiusMeters: orbitRadiusMeters,
                    angleRadians: nextState.orbitAngleRadians
                )
                return .advanced(nextState)
            }

            // 完成此點的 1 圈繞行，移往下一個點。
            remainingDistance -= lapRemaining
            nextState.segmentProgress = 0
            nextState.orbitAngleRadians += lapRemaining / orbitRadiusMeters
            nextState.coordinate = orbitCoordinate(
                center: center,
                radiusMeters: orbitRadiusMeters,
                angleRadians: nextState.orbitAngleRadians
            )
            nextState.isOrbitingCurrentPoint = false

            if nextState.pointIndex < coordinates.count - 1 {
                // 移往下一個點位。
                nextState.pointIndex += 1
                nextState.coordinate = coordinates[nextState.pointIndex]
            } else {
                // 最後一個點位完成後，依到達終點設定決定下一步。
                switch completionMode {
                case .stopAtLast:
                    nextState.coordinate = center
                    return .completed(nextState)
                case .loop:
                    nextState.pointIndex = 0
                    nextState.coordinate = coordinates[0]
                case .returnToStart:
                    nextState.pointIndex = startIndex
                    nextState.coordinate = coordinates[startIndex]
                    return .completed(nextState)
                }
            }
        }

        return .advanced(nextState)
    }

    private func nextIndex(after index: Int) -> Int? {
        if index < coordinates.count - 1 {
            return index + 1
        }
        switch completionMode {
        case .stopAtLast:
            return nil
        case .returnToStart, .loop:
            return 0
        }
    }

    private func orbitCoordinate(
        center: CLLocationCoordinate2D,
        radiusMeters: Double,
        angleRadians: Double
    ) -> CLLocationCoordinate2D {
        let lat1 = center.latitude * .pi / 180
        let lon1 = center.longitude * .pi / 180
        let angularDistance = radiusMeters / Self.earthRadiusMeters
        let bearing = angleRadians + (.pi / 2)

        let sinLat1 = sin(lat1)
        let cosLat1 = cos(lat1)
        let sinAngularDistance = sin(angularDistance)
        let cosAngularDistance = cos(angularDistance)

        let lat2 = asin(
            sinLat1 * cosAngularDistance +
            cosLat1 * sinAngularDistance * cos(bearing)
        )
        let lon2 = lon1 + atan2(
            sin(bearing) * sinAngularDistance * cosLat1,
            cosAngularDistance - sinLat1 * sin(lat2)
        )

        return CLLocationCoordinate2D(
            latitude: lat2 * 180 / .pi,
            longitude: lon2 * 180 / .pi
        )
    }

    private func distance(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> CLLocationDistance {
        CLLocation(latitude: from.latitude, longitude: from.longitude)
            .distance(from: CLLocation(latitude: to.latitude, longitude: to.longitude))
    }

    private func interpolate(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        progress: Double
    ) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: from.latitude + (to.latitude - from.latitude) * progress,
            longitude: from.longitude + (to.longitude - from.longitude) * progress
        )
    }
}
