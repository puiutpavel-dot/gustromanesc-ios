import Foundation
import CoreLocation
import MapKit

enum AddressParser {
    /// "…, Județul Brașov" → "Brașov"; normalizează diacriticele vechi și "Satu-Mare".
    static func county(from address: String) -> String? {
        let a = address.romanianNormalized
        if let r = a.range(of: #"Jude[tț]ul\s+([^,]+)"#, options: .regularExpression) {
            var name = String(a[r])
            name = name.replacingOccurrences(of: #"Jude[tț]ul\s+"#, with: "", options: .regularExpression).trimmed
            return canonicalCounty(name)
        }
        if a.folded.contains("bucuresti") { return "București" }
        if a.folded.contains("sector ") { return "București" }
        return nil
    }

    static func canonicalCounty(_ raw: String) -> String {
        let n = raw.romanianNormalized.replacingOccurrences(of: "Satu-Mare", with: "Satu Mare")
        // potrivire fără diacritice cu lista oficială
        let f = n.folded
        if let match = Region.countyToRegion.keys.first(where: { $0.folded == f }) { return match }
        return n
    }

    /// Prima componentă utilă a adresei: satul dacă există, altfel orașul/comuna.
    static func locality(from address: String) -> String {
        let parts = address.romanianNormalized.split(separator: ",").map { String($0).trimmed }
        if let sat = parts.first(where: { $0.hasPrefix("Sat ") }) {
            return clean(sat)
        }
        return parts.first.map(clean) ?? ""
    }

    private static func clean(_ s: String) -> String {
        let prefixes = ["Municipiul ", "Mun. ", "Oraș ", "Oras ", "Orașul ", "Comuna ", "Com. ", "Sat ", "Satul "]
        for p in prefixes where s.hasPrefix(p) { return String(s.dropFirst(p.count)).trimmed }
        return s
    }

    /// Acceptă "45.79" și "23,86"; ignoră coordonate în afara României / Rep. Moldova.
    static func coordinate(lat: String?, lon: String?) -> CLLocationCoordinate2D? {
        func num(_ s: String?) -> Double? {
            guard let s = s?.trimmed.replacingOccurrences(of: ",", with: "."), !s.isEmpty else { return nil }
            return Double(s)
        }
        guard var la = num(lat), var lo = num(lon) else { return nil }
        // unele înregistrări au lat/lon inversate
        if (20...30.5).contains(la) && (43...48.6).contains(lo) { swap(&la, &lo) }
        guard (43.4...48.6).contains(la), (20.0...30.5).contains(lo) else { return nil }
        return CLLocationCoordinate2D(latitude: la, longitude: lo)
    }
}

enum Geo {
    static let romaniaRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 45.95, longitude: 24.95),
        span: MKCoordinateSpan(latitudeDelta: 6.2, longitudeDelta: 9.6)
    )

    /// Reședințele de județ – folosite ca rezervă când lipsesc coordonatele și pentru „du-mă în județ”.
    static let countyCenters: [String: CLLocationCoordinate2D] = [
        "Alba": .init(latitude: 46.0733, longitude: 23.5805),
        "Arad": .init(latitude: 46.1866, longitude: 21.3123),
        "Argeș": .init(latitude: 44.8565, longitude: 24.8692),
        "Bacău": .init(latitude: 46.5670, longitude: 26.9146),
        "Bihor": .init(latitude: 47.0465, longitude: 21.9189),
        "Bistrița-Năsăud": .init(latitude: 47.1357, longitude: 24.4896),
        "Botoșani": .init(latitude: 47.7487, longitude: 26.6694),
        "Brașov": .init(latitude: 45.6427, longitude: 25.5887),
        "Brăila": .init(latitude: 45.2692, longitude: 27.9575),
        "București": .init(latitude: 44.4268, longitude: 26.1025),
        "Buzău": .init(latitude: 45.1500, longitude: 26.8333),
        "Caraș-Severin": .init(latitude: 45.3000, longitude: 21.8833),
        "Călărași": .init(latitude: 44.2000, longitude: 27.3333),
        "Cluj": .init(latitude: 46.7712, longitude: 23.6236),
        "Constanța": .init(latitude: 44.1598, longitude: 28.6348),
        "Covasna": .init(latitude: 45.8667, longitude: 25.7833),
        "Dâmbovița": .init(latitude: 44.9254, longitude: 25.4567),
        "Dolj": .init(latitude: 44.3302, longitude: 23.7949),
        "Galați": .init(latitude: 45.4353, longitude: 28.0080),
        "Giurgiu": .init(latitude: 43.9037, longitude: 25.9699),
        "Gorj": .init(latitude: 45.0333, longitude: 23.2833),
        "Harghita": .init(latitude: 46.3600, longitude: 25.8000),
        "Hunedoara": .init(latitude: 45.8667, longitude: 22.9000),
        "Ialomița": .init(latitude: 44.5667, longitude: 27.3667),
        "Iași": .init(latitude: 47.1585, longitude: 27.6014),
        "Ilfov": .init(latitude: 44.5500, longitude: 26.1000),
        "Maramureș": .init(latitude: 47.6567, longitude: 23.5850),
        "Mehedinți": .init(latitude: 44.6369, longitude: 22.6597),
        "Mureș": .init(latitude: 46.5425, longitude: 24.5575),
        "Neamț": .init(latitude: 46.9275, longitude: 26.3708),
        "Olt": .init(latitude: 44.4333, longitude: 24.3667),
        "Prahova": .init(latitude: 44.9333, longitude: 26.0333),
        "Satu Mare": .init(latitude: 47.7900, longitude: 22.8900),
        "Sălaj": .init(latitude: 47.1833, longitude: 23.0500),
        "Sibiu": .init(latitude: 45.7983, longitude: 24.1256),
        "Suceava": .init(latitude: 47.6514, longitude: 26.2556),
        "Teleorman": .init(latitude: 43.9833, longitude: 25.3333),
        "Timiș": .init(latitude: 45.7489, longitude: 21.2087),
        "Tulcea": .init(latitude: 45.1667, longitude: 28.8000),
        "Vaslui": .init(latitude: 46.6333, longitude: 27.7333),
        "Vâlcea": .init(latitude: 45.1000, longitude: 24.3667),
        "Vrancea": .init(latitude: 45.7000, longitude: 27.1833),
    ]

    static func formattedDistance(_ meters: CLLocationDistance) -> String {
        if meters < 1000 { return "\(Int(meters.rounded())) m" }
        let km = meters / 1000
        return km < 10 ? String(format: "%.1f km", km) : "\(Int(km.rounded())) km"
    }

    /// Estimare grosieră a timpului cu mașina (drum ≈ 1,3 × distanța aeriană, ~55 km/h medie).
    static func estimatedDriveTime(_ meters: CLLocationDistance) -> String {
        let minutes = Int((meters * 1.3 / 1000) / 55 * 60)
        if minutes < 60 { return "~\(max(minutes, 1)) min" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "~\(h) h" : "~\(h) h \(m) min"
    }
}
