import CoreLocation
import Foundation

struct JoystickMovementEngine {
    private static let earthRadiusMeters = 6_371_008.8

    /// 計算目標座標（節流由呼叫端負責）
    func destination(
        from origin: CLLocationCoordinate2D,
        joystickAngleDegrees: Double,
        speedKilometersPerHour: Double,
        elapsed: TimeInterval
    ) -> CLLocationCoordinate2D? {
        let distance = max(speedKilometersPerHour, 0) / 3.6 * max(elapsed, 0)
        guard distance > 0 else { return origin }

        let inputRadians = (joystickAngleDegrees - 180) * .pi / 180
        let east = cos(inputRadians)
        let north = -sin(inputRadians)
        let bearing = atan2(east, north)
        let angularDistance = distance / Self.earthRadiusMeters
        let latitude = origin.latitude * .pi / 180
        let longitude = origin.longitude * .pi / 180

        let destinationLatitude = asin(
            sin(latitude) * cos(angularDistance)
                + cos(latitude) * sin(angularDistance) * cos(bearing)
        )
        let destinationLongitude = longitude + atan2(
            sin(bearing) * sin(angularDistance) * cos(latitude),
            cos(angularDistance) - sin(latitude) * sin(destinationLatitude)
        )
        let normalizedLongitude = (destinationLongitude + 3 * .pi)
            .truncatingRemainder(dividingBy: 2 * .pi) - .pi

        return CLLocationCoordinate2D(
            latitude: destinationLatitude * 180 / .pi,
            longitude: normalizedLongitude * 180 / .pi
        )
    }
}
