import CoreLocation

final class CurrentLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentCoordinate: CLLocationCoordinate2D?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let locationManager = CLLocationManager()
    private var shouldRequestAlwaysAuthorization = false
    private var shouldUseCachedLocation = true
    private var minimumLocationTimestamp: Date?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestCurrentLocation(allowCachedLocation: Bool = true) {
        shouldUseCachedLocation = allowCachedLocation
        minimumLocationTimestamp = allowCachedLocation ? nil : Date()
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if shouldUseCachedLocation {
                // 先嘗試快取，有效就直接用，不清 nil，地圖可立即跳回真實位置。
                let hadCache = publishRecentCachedLocationIfAvailable()
                if !hadCache {
                    currentCoordinate = nil
                }
            } else {
                currentCoordinate = nil
            }
            locationManager.startUpdatingLocation()
        case .notDetermined:
            currentCoordinate = nil
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            currentCoordinate = nil
        @unknown default:
            currentCoordinate = nil
        }
    }

    func requestAlwaysAuthorizationIfPossible() {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse:
            shouldRequestAlwaysAuthorization = false
            locationManager.requestAlwaysAuthorization()
        case .notDetermined:
            shouldRequestAlwaysAuthorization = true
            locationManager.requestWhenInUseAuthorization()
        default:
            shouldRequestAlwaysAuthorization = false
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedAlways
            || manager.authorizationStatus == .authorizedWhenInUse {
            if shouldUseCachedLocation {
                publishRecentCachedLocationIfAvailable()
            } else {
                currentCoordinate = nil
            }
            shouldUseCachedLocation = true
            manager.startUpdatingLocation()
        }
        if manager.authorizationStatus == .authorizedWhenInUse,
           shouldRequestAlwaysAuthorization {
            shouldRequestAlwaysAuthorization = false
            manager.requestAlwaysAuthorization()
        }
    }

    private static let locationFreshnessInterval: TimeInterval = 180

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let minimumTimestamp = minimumLocationTimestamp
        guard let location = locations.last(where: { location in
            location.horizontalAccuracy >= 0 &&
            Date().timeIntervalSince(location.timestamp) <= Self.locationFreshnessInterval &&
            (minimumTimestamp.map { location.timestamp >= $0 } ?? true)
        }) else { return }
        minimumLocationTimestamp = nil
        currentCoordinate = location.coordinate
        manager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        minimumLocationTimestamp = nil
        manager.stopUpdatingLocation()
    }

    @discardableResult
    private func publishRecentCachedLocationIfAvailable() -> Bool {
        guard let location = locationManager.location,
              location.horizontalAccuracy >= 0,
              Date().timeIntervalSince(location.timestamp) <= Self.locationFreshnessInterval else {
            return false
        }
        currentCoordinate = location.coordinate
        return true
    }
}
