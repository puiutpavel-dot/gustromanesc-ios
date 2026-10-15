import SwiftUI

/// Explorează pe regiuni istorice → județe → produse.
struct ExploreView: View {
    @Environment(CatalogStore.self) private var store
    @Environment(LocationService.self) private var location

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(Region.allCases) { region in
                        let items = store.productsByRegion[region] ?? []
                        if !items.isEmpty {
                            NavigationLink(value: region) { RegionCard(region: region, products: items, isHere: location.currentRegion == region) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .background(Theme.paper)
            .navigationTitle("Regiuni")
            .navigationDestination(for: Region.self) { RegionView(region: $0) }
            .navigationDestination(for: Product.self) { ProductDetailView(product: $0) }
            .navigationDestination(for: CountyRoute.self) { CountyView(county: $0.name) }
        }
    }
}

struct CountyRoute: Hashable { let name: String }

struct RegionCard: View {
    let region: Region
    let products: [Product]
    var isHere = false

    var topCategories: [(ProductCategory, Int)] {
        Dictionary(grouping: products, by: \.category).map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }.prefix(3).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: region.symbol).font(.title2).foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(region.color.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(region.title).font(.headline).foregroundStyle(.primary)
                        if isHere { Chip(title: "Ești aici", symbol: "location.fill", color: Theme.accent, filled: true) }
                    }
                    Text(region.tagline).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            HStack(spacing: 6) {
                Text("\(products.count) produse").font(.caption.weight(.bold)).foregroundStyle(region.color)
                ForEach(topCategories, id: \.0) { item in
                    Chip(title: "\(item.0.title) \(item.1)", symbol: item.0.symbol, color: item.0.color)
                }
            }
            .lineLimit(1)
        }
        .card()
    }
}

struct RegionView: View {
    let region: Region
    @Environment(CatalogStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(LocationService.self) private var location

    var body: some View {
        let counties = region.counties.filter { store.productsByCounty[$0] != nil }
            + (region == .republicaMoldova ? store.counties.filter { Region.countyToRegion[$0] == nil } : [])
        let products = store.productsByRegion[region] ?? []
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(region.tagline).font(.subheadline).foregroundStyle(.secondary)
                    Button {
                        let pts = store.points.filter { counties.contains($0.county) }
                        router.mapCountyFilter = nil
                        router.mapFocus = AppRouter.fit(pts.map(\.coordinate))
                        router.tab = .map
                    } label: { Label("Vezi regiunea pe hartă", systemImage: "map.fill") }
                        .buttonStyle(.borderedProminent).tint(region.color)
                }
                .padding(.vertical, 4)
            }
            Section("Județe") {
                ForEach(counties, id: \.self) { c in
                    NavigationLink(value: CountyRoute(name: c)) {
                        HStack {
                            Text(c)
                            if location.currentCounty == c { Image(systemName: "location.fill").foregroundStyle(Theme.accent).font(.caption) }
                            Spacer()
                            Text("\(store.productsByCounty[c]?.count ?? 0)").foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                }
            }
            Section("Cele mai apreciate din \(region.title)") {
                ForEach(products.sorted { $0.rating > $1.rating }.prefix(15)) { p in
                    NavigationLink(value: p) { ProductRow(product: p) }
                }
            }
        }
        .navigationTitle(region.title)
    }
}

struct CountyView: View {
    let county: String
    @Environment(CatalogStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(LocationService.self) private var location
    @State private var category: ProductCategory?
    @State private var query = ""
    @State private var sort: SortOrder = .rating

    private var all: [Product] { store.productsByCounty[county] ?? [] }

    private var items: [Product] {
        let q = query.folded
        var list = all.filter { (category == nil || $0.category == category) && (q.isEmpty || $0.searchBlob.contains(q)) }
        switch sort {
        case .rating: list.sort { $0.rating > $1.rating }
        case .name: break
        case .newest: list.sort { ($0.certificateYear ?? 0) > ($1.certificateYear ?? 0) }
        case .distance:
            if let loc = location.location { list.sort { $0.location.distance(from: loc) < $1.location.distance(from: loc) } }
        }
        return list
    }

    private var categoriesHere: [ProductCategory] {
        ProductCategory.allCases.filter { c in all.contains { $0.category == c } }
    }

    var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button { category = nil } label: { Chip(title: "Toate (\(all.count))", color: Theme.accent, filled: category == nil) }
                        ForEach(categoriesHere) { c in
                            Button { category = (category == c ? nil : c) } label: {
                                Chip(title: c.title, symbol: c.symbol, color: c.color, filled: category == c)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                Button {
                    router.showCountyOnMap(county, points: store.points.filter { $0.county == county })
                } label: { Label("Vezi județul pe hartă", systemImage: "map.fill") }
                    .tint(Theme.accent)
            }
            Section("\(items.count) produse") {
                ForEach(items) { p in
                    NavigationLink(value: p) { ProductRow(product: p, distance: location.location.map { p.location.distance(from: $0) }) }
                }
            }
        }
        .searchable(text: $query, prompt: "Caută în \(county)")
        .navigationTitle("Județul \(county)")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sortare", selection: $sort) {
                        ForEach(SortOrder.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                    }
                } label: { Image(systemName: "arrow.up.arrow.down") }
            }
        }
    }
}
