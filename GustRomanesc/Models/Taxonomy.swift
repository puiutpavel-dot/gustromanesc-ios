import SwiftUI

// MARK: - Categorii de produs (aceleași ca pe cpac.afir.info)

enum ProductCategory: String, CaseIterable, Identifiable, Hashable {
    case vegetablesFruits, dairy, meat, honey, bakery, fish, drinks, wineries, gastroPoint, other

    var id: String { rawValue }

    init(name: String?) {
        switch (name ?? "").folded {
        case let s where s.contains("legume") || s.contains("fructe"): self = .vegetablesFruits
        case let s where s.contains("lapte"): self = .dairy
        case let s where s.contains("carne"): self = .meat
        case let s where s.contains("apicol"): self = .honey
        case let s where s.contains("panifica"): self = .bakery
        case let s where s.contains("peste"): self = .fish
        case let s where s.contains("bauturi"): self = .drinks
        case let s where s.contains("crame"): self = .wineries
        case let s where s.contains("p.g.l") || s.contains("gastronomic"): self = .gastroPoint
        default: self = .other
        }
    }

    var title: String {
        switch self {
        case .vegetablesFruits: "Legume și fructe"
        case .dairy: "Lactate"
        case .meat: "Carne"
        case .honey: "Produse apicole"
        case .bakery: "Panificație"
        case .fish: "Pește"
        case .drinks: "Băuturi"
        case .wineries: "Crame"
        case .gastroPoint: "Puncte gastronomice"
        case .other: "Altele"
        }
    }

    var symbol: String {
        switch self {
        case .vegetablesFruits: "carrot.fill"
        case .dairy: "drop.fill"
        case .meat: "fork.knife"
        case .honey: "hexagon.fill"
        case .bakery: "birthday.cake.fill"
        case .fish: "fish.fill"
        case .drinks: "mug.fill"
        case .wineries: "wineglass.fill"
        case .gastroPoint: "house.lodge.fill"
        case .other: "basket.fill"
        }
    }

    var color: Color {
        switch self {
        case .vegetablesFruits: Color(red: 0.36, green: 0.60, blue: 0.23)
        case .dairy: Color(red: 0.33, green: 0.55, blue: 0.80)
        case .meat: Color(red: 0.72, green: 0.20, blue: 0.18)
        case .honey: Color(red: 0.90, green: 0.62, blue: 0.10)
        case .bakery: Color(red: 0.70, green: 0.47, blue: 0.25)
        case .fish: Color(red: 0.16, green: 0.55, blue: 0.62)
        case .drinks: Color(red: 0.50, green: 0.33, blue: 0.62)
        case .wineries: Color(red: 0.52, green: 0.10, blue: 0.27)
        case .gastroPoint: Color(red: 0.85, green: 0.38, blue: 0.20)
        case .other: Color(red: 0.45, green: 0.45, blue: 0.40)
        }
    }

    var uiColor: UIColor { UIColor(color) }
}

// MARK: - Tipuri de atestat / certificare

enum CertificationType: Hashable, Identifiable, CaseIterable {
    case traditional, consecratedRecipe, mountain, pdo, pgi, spiritsGI, wine, nationalProtection, tsg, organic, gastroPoint, other

    static var allCases: [CertificationType] {
        [.mountain, .traditional, .consecratedRecipe, .gastroPoint, .organic, .wine, .pgi, .pdo, .tsg, .spiritsGI, .nationalProtection, .other]
    }

    var id: String { title }

    init(id: Int, name: String?) {
        switch id {
        case 1: self = .traditional
        case 2: self = .consecratedRecipe
        case 3: self = .mountain
        case 4: self = .pdo
        case 5: self = .pgi
        case 6: self = .spiritsGI
        case 7: self = .wine
        case 18: self = .nationalProtection
        case 19: self = .tsg
        case 20: self = .organic
        case 21: self = .gastroPoint
        default: self = .other
        }
    }

    var title: String {
        switch self {
        case .traditional: "Produs tradițional"
        case .consecratedRecipe: "Rețetă consacrată"
        case .mountain: "Produs montan"
        case .pdo: "Denumire de origine protejată"
        case .pgi: "Indicație geografică protejată"
        case .spiritsGI: "IG – băuturi spirtoase"
        case .wine: "Vin certificat"
        case .nationalProtection: "Protecție națională"
        case .tsg: "Specialitate tradițională garantată"
        case .organic: "Certificat ecologic"
        case .gastroPoint: "Punct gastronomic local"
        case .other: "Alt atestat"
        }
    }

    var shortTitle: String {
        switch self {
        case .traditional: "Tradițional"
        case .consecratedRecipe: "Rețetă consacrată"
        case .mountain: "Montan"
        case .pdo: "DOP"
        case .pgi: "IGP"
        case .spiritsGI: "IG spirtoase"
        case .wine: "Vin certificat"
        case .nationalProtection: "Protecție națională"
        case .tsg: "STG"
        case .organic: "Bio / Eco"
        case .gastroPoint: "PGL"
        case .other: "Atestat"
        }
    }

    var symbol: String {
        switch self {
        case .traditional: "seal.fill"
        case .consecratedRecipe: "book.closed.fill"
        case .mountain: "mountain.2.fill"
        case .pdo, .pgi, .spiritsGI, .nationalProtection: "checkmark.shield.fill"
        case .wine: "wineglass"
        case .tsg: "rosette"
        case .organic: "leaf.fill"
        case .gastroPoint: "fork.knife.circle.fill"
        case .other: "doc.text.fill"
        }
    }

    /// Explicație pe înțelesul tuturor.
    var explanation: String {
        switch self {
        case .traditional:
            "Produs fabricat din materii prime locale, după o rețetă și un procedeu tradițional, care se diferențiază clar de produse similare. Atestat de Ministerul Agriculturii."
        case .consecratedRecipe:
            "Produs făcut după o rețetă românească consacrată, publicată înainte de 1990, fără aditivi interziși. Rețeta e respectată întocmai."
        case .mountain:
            "Produs obținut în zona montană, din materii prime provenite în principal din zona montană și procesat tot acolo. Poartă logo-ul „produs montan”."
        case .pdo:
            "Denumire de origine protejată (DOP) la nivel european: toate etapele de producție au loc în aria geografică delimitată, iar calitățile se datorează locului."
        case .pgi:
            "Indicație geografică protejată (IGP) la nivel european: cel puțin o etapă de producție are loc în zona de origine, care îi dă reputația."
        case .spiritsGI:
            "Băutură spirtoasă cu indicație geografică protejată (ex. pălinci, țuici) – denumirea este legată de zona de producție."
        case .wine:
            "Vin cu denumire de origine controlată sau indicație geografică, provenit din podgorii delimitate."
        case .nationalProtection:
            "Produs care beneficiază de protecție tranzitorie la nivel național, până la înregistrarea europeană."
        case .tsg:
            "Specialitate tradițională garantată (STG): rețeta sau metoda tradițională sunt protejate la nivel european, oriunde s-ar produce."
        case .organic:
            "Produs certificat ecologic (bio): fără pesticide și îngrășăminte de sinteză, controlat de un organism de certificare."
        case .gastroPoint:
            "Punct gastronomic local (PGL): fermă sau gospodărie autorizată să servească turiștilor mâncare gătită din produse proprii sau locale."
        case .other:
            "Produs atestat înscris în Catalogul Produselor și Activităților Certificate (AFIR)."
        }
    }

    var color: Color {
        switch self {
        case .traditional: .orange
        case .consecratedRecipe: .brown
        case .mountain: .teal
        case .pdo, .pgi, .spiritsGI, .nationalProtection, .tsg: .indigo
        case .wine: Color(red: 0.52, green: 0.10, blue: 0.27)
        case .organic: .green
        case .gastroPoint: Color(red: 0.85, green: 0.38, blue: 0.20)
        case .other: .gray
        }
    }
}

// MARK: - Regiuni istorice

enum Region: String, CaseIterable, Identifiable, Hashable {
    case transilvania, maramures, crisana, banat, oltenia, muntenia, bucurestiIlfov, dobrogea, moldova, bucovina, republicaMoldova

    var id: String { rawValue }

    var title: String {
        switch self {
        case .transilvania: "Transilvania"
        case .maramures: "Maramureș și Țara Oașului"
        case .crisana: "Crișana"
        case .banat: "Banat"
        case .oltenia: "Oltenia"
        case .muntenia: "Muntenia"
        case .bucurestiIlfov: "București – Ilfov"
        case .dobrogea: "Dobrogea"
        case .moldova: "Moldova"
        case .bucovina: "Bucovina"
        case .republicaMoldova: "Republica Moldova"
        }
    }

    var tagline: String {
        switch self {
        case .transilvania: "Brânzeturi de burduf, afumături și dulcețuri de munte"
        case .maramures: "Horincă, pită pe vatră și lactate de stână"
        case .crisana: "Pălincă, slănină și produse de câmpie și deal"
        case .banat: "Cârnați, șuncă și preparate cu influențe șvăbești"
        case .oltenia: "Vinuri, miere și bunătăți din Subcarpați"
        case .muntenia: "Telemea, pastramă, mici de Pleșcoi și vinuri de deal"
        case .bucurestiIlfov: "Producători mici aproape de oraș"
        case .dobrogea: "Pește din Deltă, vinuri și produse din stepă"
        case .moldova: "Cozonaci, vinuri de Cotnari și brânzeturi"
        case .bucovina: "Mâncare de munte, afumături și miere de Bucovina"
        case .republicaMoldova: "Producători de peste Prut"
        }
    }

    var symbol: String {
        switch self {
        case .transilvania, .bucovina: "mountain.2.fill"
        case .maramures: "tree.fill"
        case .crisana, .banat: "leaf.fill"
        case .oltenia: "sun.max.fill"
        case .muntenia: "wineglass.fill"
        case .bucurestiIlfov: "building.2.fill"
        case .dobrogea: "water.waves"
        case .moldova: "sparkles"
        case .republicaMoldova: "flag.fill"
        }
    }

    var color: Color {
        switch self {
        case .transilvania: Color(red: 0.20, green: 0.45, blue: 0.35)
        case .maramures: Color(red: 0.30, green: 0.38, blue: 0.20)
        case .crisana: Color(red: 0.55, green: 0.55, blue: 0.20)
        case .banat: Color(red: 0.78, green: 0.55, blue: 0.15)
        case .oltenia: Color(red: 0.85, green: 0.45, blue: 0.15)
        case .muntenia: Color(red: 0.62, green: 0.20, blue: 0.22)
        case .bucurestiIlfov: Color(red: 0.35, green: 0.35, blue: 0.45)
        case .dobrogea: Color(red: 0.15, green: 0.45, blue: 0.65)
        case .moldova: Color(red: 0.45, green: 0.25, blue: 0.55)
        case .bucovina: Color(red: 0.15, green: 0.35, blue: 0.55)
        case .republicaMoldova: Color(red: 0.20, green: 0.30, blue: 0.60)
        }
    }

    var counties: [String] {
        Region.countyToRegion.filter { $0.value == self }.map(\.key).sorted { $0.compare($1, locale: Locale(identifier: "ro_RO")) == .orderedAscending }
    }

    static func `for`(county: String) -> Region {
        countyToRegion[county] ?? .republicaMoldova
    }

    static let countyToRegion: [String: Region] = [
        "Alba": .transilvania, "Brașov": .transilvania, "Cluj": .transilvania, "Covasna": .transilvania,
        "Harghita": .transilvania, "Hunedoara": .transilvania, "Mureș": .transilvania, "Sibiu": .transilvania,
        "Bistrița-Năsăud": .transilvania, "Sălaj": .transilvania,
        "Maramureș": .maramures, "Satu Mare": .maramures,
        "Bihor": .crisana, "Arad": .crisana,
        "Timiș": .banat, "Caraș-Severin": .banat,
        "Dolj": .oltenia, "Gorj": .oltenia, "Mehedinți": .oltenia, "Olt": .oltenia, "Vâlcea": .oltenia,
        "Argeș": .muntenia, "Brăila": .muntenia, "Buzău": .muntenia, "Călărași": .muntenia, "Dâmbovița": .muntenia,
        "Giurgiu": .muntenia, "Ialomița": .muntenia, "Prahova": .muntenia, "Teleorman": .muntenia,
        "București": .bucurestiIlfov, "Ilfov": .bucurestiIlfov,
        "Constanța": .dobrogea, "Tulcea": .dobrogea,
        "Bacău": .moldova, "Galați": .moldova, "Iași": .moldova, "Neamț": .moldova, "Vaslui": .moldova, "Vrancea": .moldova,
        "Suceava": .bucovina, "Botoșani": .bucovina,
    ]
}

// MARK: - Sortare

enum SortOrder: String, CaseIterable, Identifiable {
    case distance, rating, name, newest
    var id: String { rawValue }
    var title: String {
        switch self {
        case .distance: "Cele mai apropiate"
        case .rating: "Cele mai apreciate"
        case .name: "Alfabetic"
        case .newest: "Cele mai noi atestate"
        }
    }
    var symbol: String {
        switch self {
        case .distance: "location.fill"
        case .rating: "star.fill"
        case .name: "textformat"
        case .newest: "calendar"
        }
    }
}
