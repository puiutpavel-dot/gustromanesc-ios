import SwiftUI
import Observation
import MapKit

enum AppTab: Hashable { case home, map, explore, search, favorites }

/// Navigare între taburi: „vezi pe hartă” din orice ecran.
@MainActor
@Observable
final class AppRouter {
    var tab: AppTab = .home
    var mapFocus: MapFocus?
    var mapSelectedPoint: ProductionPoint?
    var mapCountyFilter: String?

    func showOnMap(_ point: ProductionPoint) {
        mapCountyFilter = nil
        mapFocus = .around(point.coordinate, km: 8)
        mapSelectedPoint = point
        tab = .map
    }

    func showCountyOnMap(_ county: String, points: [ProductionPoint]) {
        mapCountyFilter = county
        mapFocus = Self.fit(points.map(\.coordinate)) ?? Geo.countyCenters[county].map { MapFocus.around($0, km: 120) }
        tab = .map
    }

    static func fit(_ coords: [CLLocationCoordinate2D]) -> MapFocus? {
        guard !coords.isEmpty else { return nil }
        let lats = coords.map(\.latitude), lons = coords.map(\.longitude)
        let center = CLLocationCoordinate2D(latitude: (lats.min()! + lats.max()!) / 2, longitude: (lons.min()! + lons.max()!) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max((lats.max()! - lats.min()!) * 1.3, 0.08),
                                    longitudeDelta: max((lons.max()! - lons.min()!) * 1.3, 0.08))
        return MapFocus(region: MKCoordinateRegion(center: center, span: span))
    }
}
