import CoreLocation
import Foundation

enum CoordinateDisplayFormatter {
    static func string(_ coordinate: CLLocationCoordinate2D) -> String {
        string(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    static func string(latitude: Double, longitude: Double) -> String {
        String(
            format: "%.6f, %.6f",
            locale: Locale(identifier: "en_US_POSIX"),
            latitude,
            longitude
        )
    }
}
