import MapKit
import SwiftUI
import UIKit

@MainActor
final class SharedNativeMapStore {
    static let shared = SharedNativeMapStore()

    let mapView: MKMapView = {
        let map = MKMapView()
        map.mapType = .standard
        map.showsCompass = true
        map.showsScale = true
        map.isPitchEnabled = false
        map.isRotateEnabled = true
        return map
    }()

    private init() {}

    func center(
        at coordinate: CLLocationCoordinate2D,
        preserveZoom: Bool
    ) {
        if preserveZoom,
           mapView.region.span.latitudeDelta > 0,
           mapView.region.span.longitudeDelta > 0 {
            mapView.setCenter(coordinate, animated: false)
        } else {
            mapView.setRegion(
                SharedLocationMapState.defaultSimulationRegion(centeredAt: coordinate),
                animated: false
            )
        }
    }

    func attach(_ mapView: MKMapView, to container: UIView) {
        mapView.isPitchEnabled = false
        if mapView.camera.pitch != 0 {
            mapView.camera.pitch = 0
        }
        guard mapView.superview !== container else { return }
        mapView.removeFromSuperview()
        mapView.translatesAutoresizingMaskIntoConstraints = false
        container.insertSubview(mapView, at: 0)
        NSLayoutConstraint.activate([
            mapView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            mapView.topAnchor.constraint(equalTo: container.topAnchor),
            mapView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }
}

struct SharedNativeMapHostView: UIViewRepresentable {
    func makeUIView(context: Context) -> SharedNativeMapContainerView {
        let container = SharedNativeMapContainerView()
        container.isUserInteractionEnabled = true
        SharedNativeMapStore.shared.attach(
            SharedNativeMapStore.shared.mapView,
            to: container
        )
        return container
    }

    func updateUIView(
        _ container: SharedNativeMapContainerView,
        context: Context
    ) {
        SharedNativeMapStore.shared.attach(
            SharedNativeMapStore.shared.mapView,
            to: container
        )
    }
}

final class SharedNativeMapContainerView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
