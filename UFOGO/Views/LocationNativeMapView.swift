import MapKit
import SwiftUI

struct LocationNativeMapView: UIViewRepresentable {
    @Binding var coordinate: CLLocationCoordinate2D?
    let rotation: Double
    let isMoving: Bool
    let onTap: (CLLocationCoordinate2D) -> Void
    @ObservedObject var sharedMapState: SharedLocationMapState

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> SharedNativeMapContainerView {
        let container = SharedNativeMapContainerView()
        configure(container, coordinator: context.coordinator)
        return container
    }

    func updateUIView(_ container: SharedNativeMapContainerView, context: Context) {
        context.coordinator.parent = self
        configure(container, coordinator: context.coordinator)
    }

    private func configure(
        _ container: SharedNativeMapContainerView,
        coordinator: Coordinator
    ) {
        guard sharedMapState.activeTabID == AppFeature.home.id else {
            coordinator.isLocationTabActive = false
            return
        }
        let isEnteringLocationTab = !coordinator.isLocationTabActive
        coordinator.isLocationTabActive = true
        let mapView = SharedNativeMapStore.shared.mapView
        mapView.delegate = coordinator
        coordinator.installTapIfNeeded(on: mapView)
        mapView.gestureRecognizers?.forEach {
            if $0.name == "RouteMapTap" { $0.isEnabled = false }
            if $0.name == "LocationMapTap" { $0.isEnabled = true }
        }
        coordinator.applyPendingCenterRequest(on: mapView)
        coordinator.updateMarker(on: mapView)
        if isEnteringLocationTab, let coordinate {
            SharedNativeMapStore.shared.center(
                at: coordinate,
                preserveZoom: true
            )
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: LocationNativeMapView
        private weak var mapView: MKMapView?
        private var appliedCenterRequestID: UUID?
        var isLocationTabActive = false

        init(_ parent: LocationNativeMapView) { self.parent = parent }

        func installTapIfNeeded(on mapView: MKMapView) {
            self.mapView = mapView
            guard mapView.gestureRecognizers?.contains(where: {
                $0.name == "LocationMapTap"
            }) != true else { return }
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            tap.name = "LocationMapTap"
            tap.delegate = self
            tap.cancelsTouchesInView = false
            mapView.addGestureRecognizer(tap)
        }

        func updateMarker(on mapView: MKMapView) {
            mapView.removeOverlays(mapView.overlays)
            let unrelatedAnnotations = mapView.annotations.filter {
                !($0 is LocationMapAnnotation)
            }
            mapView.removeAnnotations(unrelatedAnnotations)

            guard let coordinate = parent.coordinate else {
                let existing = mapView.annotations.compactMap {
                    $0 as? LocationMapAnnotation
                }
                mapView.removeAnnotations(existing)
                return
            }

            let annotation: LocationMapAnnotation
            if let current = mapView.annotations.first(where: {
                $0 is LocationMapAnnotation
            }) as? LocationMapAnnotation {
                annotation = current
                if CLLocation(
                    latitude: annotation.coordinate.latitude,
                    longitude: annotation.coordinate.longitude
                ).distance(from: CLLocation(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )) > 0.01 {
                    annotation.coordinate = coordinate
                }
                annotation.rotation = parent.rotation
                annotation.moving = parent.isMoving
            } else {
                annotation = LocationMapAnnotation(
                    coordinate: coordinate,
                    rotation: parent.rotation,
                    moving: parent.isMoving
                )
                mapView.addAnnotation(annotation)
            }
            if let view = mapView.view(for: annotation) as? LocationMapAnnotationView {
                view.configure(rotation: annotation.rotation, moving: annotation.moving)
            }
        }

        func applyPendingCenterRequest(on mapView: MKMapView) {
            guard let request = parent.sharedMapState.nativeMapCenterRequest,
                  request.id != appliedCenterRequestID else { return }
            appliedCenterRequestID = request.id
            SharedNativeMapStore.shared.center(
                at: request.coordinate,
                preserveZoom: request.preserveZoom
            )
        }

        @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended, let mapView else { return }
            let point = recognizer.location(in: mapView)
            parent.onTap(mapView.convert(point, toCoordinateFrom: mapView))
        }

        func mapView(
            _ mapView: MKMapView,
            viewFor annotation: MKAnnotation
        ) -> MKAnnotationView? {
            guard let marker = annotation as? LocationMapAnnotation else { return nil }
            let view = LocationMapAnnotationView(annotation: marker, reuseIdentifier: "Location")
            view.configure(rotation: marker.rotation, moving: marker.moving)
            return view
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.sharedMapState.visibleRegion = mapView.region
            parent.sharedMapState.lastCamera = MapCamera(
                centerCoordinate: mapView.camera.centerCoordinate,
                distance: mapView.camera.centerCoordinateDistance,
                heading: mapView.camera.heading,
                pitch: mapView.camera.pitch
            )
        }
    }
}

private final class LocationMapAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    var rotation: Double
    var moving: Bool

    init(coordinate: CLLocationCoordinate2D, rotation: Double, moving: Bool) {
        self.coordinate = coordinate
        self.rotation = rotation
        self.moving = moving
    }
}

private final class LocationMapAnnotationView: MKAnnotationView {
    private let symbol = UIImageView()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 24, height: 24)
        symbol.frame = bounds
        symbol.contentMode = .center
        symbol.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: 12,
            weight: .bold
        )
        addSubview(symbol)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(rotation: Double, moving: Bool) {
        symbol.backgroundColor = .systemBlue
        symbol.layer.cornerRadius = 12
        symbol.layer.borderColor = UIColor.white.cgColor
        symbol.layer.borderWidth = 2
        symbol.tintColor = .white
        symbol.image = moving ? UIImage(systemName: "location.north.fill") : nil
        symbol.transform = CGAffineTransform(rotationAngle: rotation * .pi / 180)
    }
}
