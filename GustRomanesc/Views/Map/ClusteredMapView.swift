import SwiftUI
import MapKit

/// Cerere de mutare a hărții (zoom pe județ, pe utilizator, pe toată țara).
struct MapFocus: Equatable {
    let id = UUID()
    let region: MKCoordinateRegion
    static func == (l: Self, r: Self) -> Bool { l.id == r.id }

    static func around(_ c: CLLocationCoordinate2D, km: Double) -> MapFocus {
        MapFocus(region: MKCoordinateRegion(center: c, latitudinalMeters: km * 1000, longitudinalMeters: km * 1000))
    }
    static var romania: MapFocus { MapFocus(region: Geo.romaniaRegion) }
}

final class PointAnnotation: NSObject, MKAnnotation {
    let point: ProductionPoint
    let coordinate: CLLocationCoordinate2D
    var title: String? { point.producerName }
    var subtitle: String? {
        point.products.count == 1 ? point.products[0].name : "\(point.products.count) produse"
    }
    init(point: ProductionPoint) {
        self.point = point
        self.coordinate = point.coordinate
    }
}

/// MKMapView cu grupare (clustering) – gestionează fluent ~1.700 de puncte.
struct ClusteredMapView: UIViewRepresentable {
    let points: [ProductionPoint]
    var focus: MapFocus?
    var showsUser = true
    var route: MKRoute? = nil
    var onSelect: (ProductionPoint) -> Void
    var onRegionChange: ((MKCoordinateRegion) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = showsUser
        map.pointOfInterestFilter = .excludingAll
        map.showsCompass = true
        map.showsScale = true
        map.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: Coordinator.pointId)
        map.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
        map.setRegion(focus?.region ?? Geo.romaniaRegion, animated: false)
        context.coordinator.lastFocus = focus
        context.coordinator.sync(points, on: map)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.sync(points, on: map)
        if let focus, focus != context.coordinator.lastFocus {
            context.coordinator.lastFocus = focus
            map.setRegion(focus.region, animated: true)
        }
        context.coordinator.syncRoute(route, on: map)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        static let pointId = "point"
        var parent: ClusteredMapView
        var lastFocus: MapFocus?
        private var current: [Int: PointAnnotation] = [:]
        private var routeOverlay: MKPolyline?

        init(_ parent: ClusteredMapView) { self.parent = parent }

        func sync(_ points: [ProductionPoint], on map: MKMapView) {
            let newIds = Set(points.map(\.id))
            let oldIds = Set(current.keys)
            guard newIds != oldIds else { return }
            let toRemove = oldIds.subtracting(newIds).compactMap { current[$0] }
            map.removeAnnotations(toRemove)
            toRemove.forEach { current[$0.point.id] = nil }
            let toAdd = points.filter { !oldIds.contains($0.id) }.map(PointAnnotation.init(point:))
            toAdd.forEach { current[$0.point.id] = $0 }
            map.addAnnotations(toAdd)
        }

        func syncRoute(_ route: MKRoute?, on map: MKMapView) {
            if routeOverlay === route?.polyline { return }
            if let old = routeOverlay { map.removeOverlay(old) }
            routeOverlay = route?.polyline
            if let line = route?.polyline {
                map.addOverlay(line, level: .aboveRoads)
                map.setVisibleMapRect(line.boundingMapRect, edgePadding: UIEdgeInsets(top: 80, left: 40, bottom: 260, right: 40), animated: true)
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let a = annotation as? PointAnnotation {
                let v = mapView.dequeueReusableAnnotationView(withIdentifier: Self.pointId, for: a) as! MKMarkerAnnotationView
                let cat = a.point.mainCategory
                v.markerTintColor = cat.uiColor
                v.glyphImage = UIImage(systemName: cat.symbol)
                v.clusteringIdentifier = "cpac"
                v.displayPriority = .defaultLow
                v.titleVisibility = .adaptive
                v.subtitleVisibility = .hidden
                v.canShowCallout = false
                return v
            }
            if let cluster = annotation as? MKClusterAnnotation {
                let v = mapView.dequeueReusableAnnotationView(withIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier, for: cluster) as! MKMarkerAnnotationView
                v.markerTintColor = UIColor(Theme.accent)
                let products = cluster.memberAnnotations.compactMap { ($0 as? PointAnnotation)?.point.products.count }.reduce(0, +)
                v.glyphText = products > 999 ? "999+" : "\(products)"
                v.titleVisibility = .hidden
                v.subtitleVisibility = .hidden
                v.displayPriority = .required
                return v
            }
            return nil
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let cluster = view.annotation as? MKClusterAnnotation {
                mapView.deselectAnnotation(cluster, animated: false)
                let rect = cluster.memberAnnotations.reduce(MKMapRect.null) { r, a in
                    let p = MKMapPoint(a.coordinate)
                    return r.union(MKMapRect(x: p.x, y: p.y, width: 1, height: 1))
                }
                // dacă toate punctele sunt practic în același loc, deschidem primul
                if rect.size.width < 200, rect.size.height < 200,
                   let first = cluster.memberAnnotations.first as? PointAnnotation {
                    parent.onSelect(first.point)
                    return
                }
                mapView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 60, left: 60, bottom: 60, right: 60), animated: true)
            } else if let a = view.annotation as? PointAnnotation {
                mapView.deselectAnnotation(a, animated: true)
                parent.onSelect(a.point)
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.onRegionChange?(mapView.region)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let line = overlay as? MKPolyline {
                let r = MKPolylineRenderer(polyline: line)
                r.strokeColor = UIColor(Theme.accent)
                r.lineWidth = 6
                r.lineCap = .round
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
