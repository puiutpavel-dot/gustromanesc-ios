import SwiftUI
import CoreLocation

struct HomeView: View {
    @Environment(CatalogStore.self) private var store
    @Environment(LocationService.self) private var location
    @Environment(AppRouter.self) private var router
    @State private var radiusKm: Double = 50
    @State private var showCertInfo = false
    @State private var showAbout = false

    private var nearby: [(product: Product, distance: CLLocationDistance)] {
        guard let loc = location.location else { return [] }
        return store.products(near: loc, radiusKm: radiusKm)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    hero
                    if let p = store.productOfTheDay { productOfTheDay(p) }
                    nearbySection
                    if let county = location.currentCounty, let items = store.productsByCounty[county], !items.isEmpty {
                        countySection(county, items)
                    }
                    categoriesSection
                    certificationBanner
                }
                .padding(.vertical)
            }
            .background(Theme.paper)
            .navigationTitle("Gust Românesc")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAbout = true } label: { Image(systemName: "info.circle") }
                }
            }
            .refreshable { await store.refresh() }
            .navigationDestination(for: Product.self) { ProductDetailView(product: $0) }
            .navigationDestination(for: ProductCategory.self) { CategoryProductsView(category: $0) }
            .sheet(isPresented: $showCertInfo) { CertificationInfoSheet() }
            .sheet(isPresented: $showAbout) { AboutView() }
        }
    }

    // MARK: Secțiuni

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            FolkStripe()
            VStack(alignment: .leading, spacing: 6) {
                if let place = location.currentPlaceName, let county = location.currentCounty {
                    Text("Ești în \(place)").font(.title2.weight(.bold))
                    HStack(spacing: 6) {
                        Chip(title: "Județul \(county)", symbol: "mappin.circle.fill", color: Theme.accent)
                        if let r = location.currentRegion { Chip(title: r.title, symbol: r.symbol, color: r.color) }
                    }
                } else if location.isDenied {
                    Text("Descoperă gusturile României").font(.title2.weight(.bold))
                    Text("Activează locația din Setări ca să vezi producătorii din jurul tău.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button("Deschide Setările") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                    .buttonStyle(.bordered).tint(Theme.accent)
                } else if location.location == nil {
                    Text("Descoperă gusturile României").font(.title2.weight(.bold))
                    Button {
                        location.start()
                    } label: { Label("Arată-mi ce e lângă mine", systemImage: "location.fill") }
                        .buttonStyle(.borderedProminent).tint(Theme.accent)
                } else {
                    Text("Bunătăți din jurul tău").font(.title2.weight(.bold))
                }
                Text("\(store.products.count.formatted()) produse atestate de la \(Set(store.products.map(\.producerId)).count.formatted()) producători din \(store.productsByCounty.count) județe")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.horizontal)
        }
    }

    private func productOfTheDay(_ p: Product) -> some View {
        NavigationLink(value: p) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Produsul zilei", systemImage: "sparkles").font(.caption.weight(.bold)).foregroundStyle(Theme.ochre)
                    Spacer()
                    RatingView(rating: p.rating, compact: true)
                }
                HStack(alignment: .top, spacing: 12) {
                    CategoryIcon(category: p.category, size: 54)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(p.name).font(.headline).foregroundStyle(.primary).multilineTextAlignment(.leading)
                        Text("\(p.producerName) · \(p.locality), \(p.county)").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text(p.description).font(.subheadline).foregroundStyle(.secondary).lineLimit(3).multilineTextAlignment(.leading)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.ochre.opacity(0.5), lineWidth: 1))
            )
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var nearbySection: some View {
        if location.location != nil {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    SectionHeader(title: "Lângă tine", subtitle: "\(nearby.count) produse pe o rază de \(Int(radiusKm)) km")
                    Menu {
                        Picker("Rază", selection: $radiusKm) {
                            ForEach([10.0, 25, 50, 100, 200], id: \.self) { Text("\(Int($0)) km").tag($0) }
                        }
                    } label: { Chip(title: "\(Int(radiusKm)) km", symbol: "scope", color: Theme.accent) }
                }
                .padding(.horizontal)

                if nearby.isEmpty {
                    Text("Niciun producător atestat pe această rază. Mărește raza sau explorează harta.")
                        .font(.subheadline).foregroundStyle(.secondary).padding(.horizontal)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(nearby.prefix(15), id: \.product.id) { item in
                                NavigationLink(value: item.product) { ProductCard(product: item.product, distance: item.distance) }
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal).padding(.vertical, 4)
                    }
                    NavigationLink {
                        NearbyListView(radiusKm: $radiusKm)
                    } label: {
                        Label("Vezi toate cele \(nearby.count) produse", systemImage: "list.bullet")
                            .font(.subheadline.weight(.semibold))
                    }
                    .tint(Theme.accent)
                    .padding(.horizontal)
                }
            }
        }
    }

    private func countySection(_ county: String, _ items: [Product]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Din județul \(county)", subtitle: "\(items.count) produse atestate")
                NavigationLink { CountyView(county: county) } label: {
                    Text("Toate").font(.subheadline.weight(.semibold))
                }
                .tint(Theme.accent)
            }
            .padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items.sorted { $0.rating > $1.rating }.prefix(12)) { p in
                        NavigationLink(value: p) { ProductCard(product: p) }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal).padding(.vertical, 4)
            }
        }
    }

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Pe categorii").padding(.horizontal)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(ProductCategory.allCases) { c in
                    let count = store.products.filter { $0.category == c }.count
                    if count > 0 {
                        NavigationLink(value: c) {
                            HStack(spacing: 10) {
                                CategoryIcon(category: c, size: 38)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(c.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                                    Text("\(count)").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(10)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var certificationBanner: some View {
        Button { showCertInfo = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill").font(.title).foregroundStyle(Theme.forest)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ce înseamnă „montan”, „tradițional”, DOP sau IGP?").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text("Ghid scurt al atestatelor").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .card()
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Lista completă „Lângă tine”

struct NearbyListView: View {
    @Binding var radiusKm: Double
    @Environment(CatalogStore.self) private var store
    @Environment(LocationService.self) private var location
    @State private var category: ProductCategory?

    var body: some View {
        let items: [(product: Product, distance: CLLocationDistance)] = location.location.map {
            store.products(near: $0, radiusKm: radiusKm).filter { category == nil || $0.product.category == category }
        } ?? []
        List {
            Section {
                VStack(alignment: .leading) {
                    Text("Rază: \(Int(radiusKm)) km").font(.subheadline.weight(.semibold))
                    Slider(value: $radiusKm, in: 5...300, step: 5).tint(Theme.accent)
                }
                Picker("Categorie", selection: $category) {
                    Text("Toate categoriile").tag(ProductCategory?.none)
                    ForEach(ProductCategory.allCases) { Label($0.title, systemImage: $0.symbol).tag(Optional($0)) }
                }
            }
            Section("\(items.count) produse") {
                ForEach(items, id: \.product.id) { item in
                    NavigationLink(value: item.product) { ProductRow(product: item.product, distance: item.distance) }
                }
            }
        }
        .overlay {
            if items.isEmpty {
                EmptyStateView(symbol: "location.slash", title: "Nimic pe această rază", message: "Mărește raza sau schimbă categoria.")
            }
        }
        .navigationTitle("Lângă tine")
    }
}

struct CategoryProductsView: View {
    let category: ProductCategory
    @Environment(CatalogStore.self) private var store
    @Environment(LocationService.self) private var location
    @State private var region: Region?

    private var items: [Product] {
        var list = store.products.filter { $0.category == category && (region == nil || $0.region == region) }
        if let loc = location.location { list.sort { $0.location.distance(from: loc) < $1.location.distance(from: loc) } }
        return list
    }

    var body: some View {
        List(items) { p in
            NavigationLink(value: p) { ProductRow(product: p, distance: location.location.map { p.location.distance(from: $0) }) }
        }
        .navigationTitle(category.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Regiune", selection: $region) {
                        Text("Toată țara").tag(Region?.none)
                        ForEach(Region.allCases) { Text($0.title).tag(Optional($0)) }
                    }
                } label: { Image(systemName: region == nil ? "map" : "map.fill") }
            }
        }
    }
}
