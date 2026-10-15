import Foundation
import CoreLocation
import Observation

/// Locația utilizatorului + județul/regiunea în care se află (prin geocodare inversă).
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    private(set) var location: CLLocation?
    private(set) var currentCounty: String?
    private(set) var currentPlaceName: String?

    var currentRegion: Region? { currentCounty.map(Region.for(county:)) }
    var isAuthorized: Bool { authorization == .authorizedWhenInUse || authorization == .authorizedAlways }
    var isDenied: Bool { authorization == .denied || authorization == .restricted }

    private var lastGeocoded: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 250
        authorization = manager.authorizationStatus
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: manager.startUpdatingLocation()
        default: break
        }
    }

    func requestOnce() {
        if isAuthorized { manager.requestLocation() } else { start() }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        let status = m.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            if self.isAuthorized { self.manager.startUpdatingLocation() }
        }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.location = loc
            await self.reverseGeocodeIfNeeded(loc)
        }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {}

    private func reverseGeocodeIfNeeded(_ loc: CLLocation) async {
        if let last = lastGeocoded, last.distance(from: loc) < 3000 { return }
        lastGeocoded = loc
        guard let mark = try? await geocoder.reverseGeocodeLocation(loc, preferredLocale: Locale(identifier: "ro_RO")).first else { return }
        currentPlaceName = mark.locality ?? mark.subAdministrativeArea ?? mark.name
        if let area = mark.administrativeArea {
            var county = area.replacingOccurrences(of: "Județul ", with: "")
                .replacingOccurrences(of: "Judetul ", with: "")
                .replacingOccurrences(of: " County", with: "")
            if county.folded.contains("bucuresti") || county.folded.contains("bucharest") { county = "București" }
            currentCounty = AddressParser.canonicalCounty(county)
        }
    }
}
