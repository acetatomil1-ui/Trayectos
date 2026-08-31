import MapKit
import SwiftUI

struct MapRoute: Identifiable {
    let id: String
    let coordinates: [CLLocationCoordinate2D]
    let color: UIColor
    let firstTimestamp: Date?
    let lastTimestamp: Date?

    init(block: RouteBlock, color: UIColor) {
        id = block.id
        coordinates = block.points.map { $0.coordinate.clCoordinate }
        self.color = color
        firstTimestamp = block.points.first?.timestamp
        lastTimestamp = block.points.last?.timestamp
    }
}

struct RouteMapView: UIViewRepresentable {
    let routes: [MapRoute]

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.showsBuildings = true
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .realistic)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let signature = routes.map { route in
            "\(route.id)-\(route.coordinates.count)-\(route.color.description)"
        }
        .joined(separator: "|")

        guard signature != context.coordinator.lastSignature else { return }
        context.coordinator.lastSignature = signature
        context.coordinator.colorsByOverlay.removeAll()

        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        var combinedRect = MKMapRect.null
        var allTimedCoordinates: [(coordinate: CLLocationCoordinate2D, date: Date)] = []

        for route in routes {
            guard !route.coordinates.isEmpty else { continue }

            for coordinate in route.coordinates {
                let pointRect = MKMapRect(origin: MKMapPoint(coordinate), size: MKMapSize(width: 0, height: 0))
                combinedRect = combinedRect.isNull ? pointRect : combinedRect.union(pointRect)
            }

            if let firstTimestamp = route.firstTimestamp,
               let firstCoordinate = route.coordinates.first {
                allTimedCoordinates.append((firstCoordinate, firstTimestamp))
            }
            if let lastTimestamp = route.lastTimestamp,
               let lastCoordinate = route.coordinates.last {
                allTimedCoordinates.append((lastCoordinate, lastTimestamp))
            }

            guard route.coordinates.count > 1 else { continue }
            let polyline = MKPolyline(coordinates: route.coordinates, count: route.coordinates.count)
            context.coordinator.colorsByOverlay[ObjectIdentifier(polyline)] = route.color
            mapView.addOverlay(polyline, level: .aboveRoads)
        }

        if let first = allTimedCoordinates.min(by: { $0.date < $1.date }),
           let last = allTimedCoordinates.max(by: { $0.date < $1.date }) {
            if first.date == last.date || coordinatesAreEqual(first.coordinate, last.coordinate) {
                mapView.addAnnotation(RouteEndpointAnnotation(coordinate: first.coordinate, kind: .single))
            } else {
                mapView.addAnnotations([
                    RouteEndpointAnnotation(coordinate: first.coordinate, kind: .start),
                    RouteEndpointAnnotation(coordinate: last.coordinate, kind: .end)
                ])
            }
        }

        guard !combinedRect.isNull else { return }

        if combinedRect.size.width < 1 && combinedRect.size.height < 1 {
            let center = MKCoordinateRegion(
                center: routes.first?.coordinates.first ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
                latitudinalMeters: 4_000,
                longitudinalMeters: 4_000
            )
            mapView.setRegion(center, animated: true)
        } else {
            let minimumSpan = MKMapSize(width: 8_000, height: 8_000)
            let paddedRect = combinedRect.insetBy(
                dx: -max(combinedRect.size.width * 0.08, minimumSpan.width),
                dy: -max(combinedRect.size.height * 0.08, minimumSpan.height)
            )
            mapView.setVisibleMapRect(
                paddedRect,
                edgePadding: UIEdgeInsets(top: 54, left: 34, bottom: 54, right: 34),
                animated: true
            )
        }
    }

    private func coordinatesAreEqual(
        _ lhs: CLLocationCoordinate2D,
        _ rhs: CLLocationCoordinate2D
    ) -> Bool {
        abs(lhs.latitude - rhs.latitude) < 0.000_001 &&
        abs(lhs.longitude - rhs.longitude) < 0.000_001
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var lastSignature = ""
        var colorsByOverlay: [ObjectIdentifier: UIColor] = [:]

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = colorsByOverlay[ObjectIdentifier(polyline)] ?? .systemIndigo
            renderer.lineWidth = 5
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let endpoint = annotation as? RouteEndpointAnnotation else { return nil }

            let identifier = "RouteEndpoint"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: endpoint, reuseIdentifier: identifier)

            view.annotation = endpoint
            view.canShowCallout = true
            view.markerTintColor = endpoint.kind.tintColor
            view.glyphImage = UIImage(systemName: endpoint.kind.symbolName)
            view.titleVisibility = .adaptive
            view.displayPriority = .required
            return view
        }
    }
}

private final class RouteEndpointAnnotation: NSObject, MKAnnotation {
    enum Kind {
        case start
        case end
        case single

        var title: String {
            switch self {
            case .start: return "Inicio"
            case .end: return "Fin"
            case .single: return "Punto registrado"
            }
        }

        var tintColor: UIColor {
            switch self {
            case .start: return .systemTeal
            case .end: return .systemIndigo
            case .single: return .systemBlue
            }
        }

        var symbolName: String {
            switch self {
            case .start: return "location.fill"
            case .end: return "flag.checkered"
            case .single: return "mappin"
            }
        }
    }

    let coordinate: CLLocationCoordinate2D
    let kind: Kind
    var title: String? { kind.title }

    init(coordinate: CLLocationCoordinate2D, kind: Kind) {
        self.coordinate = coordinate
        self.kind = kind
    }
}
