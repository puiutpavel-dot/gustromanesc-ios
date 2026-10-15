import Foundation
import CoreLocation

/// Răspunsul brut al endpoint-ului https://cpac.afir.info/GetListaProduseData
struct CPACResponse: Decodable {
    let Succes: Bool?
    let TotalRecords: Int?
    let TotalPages: Int?
    let CurrentPage: Int?
    let Records: [CPACRecord]
}

/// Un rând din catalogul CPAC, exact cum vine de la AFIR.
struct CPACRecord: Codable, Hashable {
    let AtestatId: Int
    let AtestatNr: String?
    let AtestatAn: Int?
    let AtestatTipId: Int?
    let AtestatTipDenumire: String?
    let ProducatorId: Int?
    let ProducatorDenumire: String?
    let ProducatorAdrsa: String?
    let PunctDeLucruId: Int?
    let PunctDeLucruAdresa: String?
    let CV1: String?
    let CV2: String?
    let ProdusId: Int?
    let ProdusDenumire: String?
    let ProdusCategorie: String?
    let ProdusDescriere: String?
    let ProdusRating: Double?
    let ProdusCategorieIconUrlPath: String?
}

/// Produsul curățat și îmbogățit, folosit în toată aplicația.
struct Product: Identifiable, Hashable {
    let id: Int                 // AtestatId
    let certificateNumber: String
    let certificateYear: Int?
    let certification: CertificationType
    let producerId: Int
    let producerName: String
    let producerAddress: String
    let pointId: Int
    let pointAddress: String
    let coordinate: CLLocationCoordinate2D
    let isApproximateLocation: Bool
    let name: String
    let category: ProductCategory
    let description: String
    let rating: Double
    let county: String
    let region: Region
    let locality: String

    static func == (l: Product, r: Product) -> Bool { l.id == r.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    var location: CLLocation { CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude) }

    /// Text în care se caută (fără diacritice, litere mici).
    let searchBlob: String

    init?(record r: CPACRecord) {
        guard let rawName = r.ProdusDenumire?.trimmed, !rawName.isEmpty else { return nil }
        id = r.AtestatId
        certificateNumber = r.AtestatNr?.trimmed ?? "—"
        if let y = r.AtestatAn, (1800...2100).contains(y) { certificateYear = y } else { certificateYear = nil }
        certification = CertificationType(id: r.AtestatTipId ?? 0, name: r.AtestatTipDenumire)
        producerId = r.ProducatorId ?? 0
        producerName = r.ProducatorDenumire?.trimmed.nilIfEmpty ?? "Producător necunoscut"
        producerAddress = r.ProducatorAdrsa?.trimmed ?? ""
        pointId = r.PunctDeLucruId ?? -(r.ProducatorId ?? r.AtestatId)
        pointAddress = r.PunctDeLucruAdresa?.trimmed.nilIfEmpty ?? producerAddress
        name = rawName
        category = ProductCategory(name: r.ProdusCategorie)
        description = r.ProdusDescriere?.trimmed ?? ""
        rating = r.ProdusRating ?? 0

        let countyName = AddressParser.county(from: pointAddress) ?? AddressParser.county(from: producerAddress) ?? "Necunoscut"
        county = countyName
        region = Region.for(county: countyName)
        locality = AddressParser.locality(from: pointAddress)

        if let c = AddressParser.coordinate(lat: r.CV1, lon: r.CV2) {
            coordinate = c
            isApproximateLocation = false
        } else if let c = Geo.countyCenters[countyName] {
            coordinate = c
            isApproximateLocation = true
        } else {
            return nil
        }

        searchBlob = [name, producerName, locality, county, category.title, certification.title, description]
            .joined(separator: " ").folded
    }
}

/// Un loc de pe hartă: un punct de lucru cu toate produsele lui.
struct ProductionPoint: Identifiable, Hashable {
    let id: Int
    let coordinate: CLLocationCoordinate2D
    let producerName: String
    let address: String
    let locality: String
    let county: String
    let products: [Product]
    let isApproximate: Bool

    static func == (l: Self, r: Self) -> Bool { l.id == r.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    var mainCategory: ProductCategory {
        Dictionary(grouping: products, by: \.category).max { $0.value.count < $1.value.count }?.key ?? .other
    }
    var location: CLLocation { CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude) }
}

struct Producer: Identifiable, Hashable {
    let id: Int
    let name: String
    let address: String
    let products: [Product]
    static func == (l: Self, r: Self) -> Bool { l.id == r.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfEmpty: String? { isEmpty ? nil : self }
    /// Litere mici, fără diacritice, cu ş/ţ vechi normalizate.
    var folded: String {
        replacingOccurrences(of: "ş", with: "ș").replacingOccurrences(of: "ţ", with: "ț")
            .replacingOccurrences(of: "Ş", with: "Ș").replacingOccurrences(of: "Ţ", with: "Ț")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "ro_RO"))
    }
    /// Normalizează ş/ţ cu sedilă la ș/ț cu virgulă.
    var romanianNormalized: String {
        replacingOccurrences(of: "ş", with: "ș").replacingOccurrences(of: "ţ", with: "ț")
            .replacingOccurrences(of: "Ş", with: "Ș").replacingOccurrences(of: "Ţ", with: "Ț")
    }
}
