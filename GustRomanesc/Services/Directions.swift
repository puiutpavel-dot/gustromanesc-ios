import UIKit
import MapKit

/// Deschide navigația în aplicația preferată (Apple Maps, Google Maps, Waze).
enum NavigationApp: String, CaseIterable, Identifiable {
    case appleMaps, googleMaps, waze
    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleMaps: "Apple Maps"
        case .googleMaps: "Google Maps"
        case .waze: "Waze"
        }
    }

    var symbol: String {
        switch self {
        case .appleMaps: "map.fill"
        case .googleMaps: "globe.europe.africa.fill"
        case .waze: "car.fill"
        }
    }

    @MainActor
    func open(to coordinate: CLLocationCoordinate2D, name: String) {
        let lat = coordinate.latitude, lon = coordinate.longitude
        switch self {
        case .appleMaps:
            let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            item.name = name
            item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
        case .googleMaps:
            let app = URL(string: "comgooglemaps://?daddr=\(lat),\(lon)&directionsmode=driving")!
            let web = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(lat),\(lon)&travelmode=driving")!
            UIApplication.shared.open(UIApplication.shared.canOpenURL(app) ? app : web)
        case .waze:
            let app = URL(string: "waze://?ll=\(lat),\(lon)&navigate=yes")!
            let web = URL(string: "https://waze.com/ul?ll=\(lat),\(lon)&navigate=yes")!
            UIApplication.shared.open(UIApplication.shared.canOpenURL(app) ? app : web)
        }
    }

    /// Traseu cu mai multe opriri (Google Maps acceptă până la ~9 puncte intermediare).
    @MainActor
    static func openMultiStop(_ stops: [CLLocationCoordinate2D]) {
        guard let destination = stops.last else { return }
        let waypoints = stops.dropLast().prefix(9).map { "\($0.latitude),\($0.longitude)" }.joined(separator: "|")
        var c = URLComponents(string: "https://www.google.com/maps/dir/")!
        c.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "destination", value: "\(destination.latitude),\(destination.longitude)"),
            URLQueryItem(name: "travelmode", value: "driving"),
        ]
        if !waypoints.isEmpty { c.queryItems?.append(URLQueryItem(name: "waypoints", value: waypoints)) }
        if let url = c.url { UIApplication.shared.open(url) }
    }
}

/// Calculează un traseu rutier în aplicație (MapKit).
enum RoutePlanner {
    static func route(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> MKRoute {
        let req = MKDirections.Request()
        req.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        req.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        req.transportType = .automobile
        let response = try await MKDirections(request: req).calculate()
        guard let route = response.routes.first else { throw URLError(.cannotFindHost) }
        return route
    }

    static func format(_ time: TimeInterval) -> String {
        let minutes = Int(time / 60)
        if minutes < 60 { return "\(minutes) min" }
        return minutes % 60 == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(minutes % 60) min"
    }
}
