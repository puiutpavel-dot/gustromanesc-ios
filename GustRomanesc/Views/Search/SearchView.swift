import SwiftUI

struct SearchView: View {
    @Environment(CatalogStore.self) private var store
    @Environment(LocationService.self) private var location
    @State private var query = ""
    @State private var filter = ProductFilter()
    @State private var showFilters = false
    @State private var results: [Product] = []

    private let suggestions = ["telemea", "brânză de burduf", "miere de salcâm", "pălincă", "zacuscă", "slănină", "cozonac", "dulceață", "cașcaval", "horincă", "pastramă", "magiun"]

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty && !filter.isActive {
                    Section("Încearcă") {
                        FlowLayout(spacing: 8) {
                            ForEach(suggestions, id: \.self) { s in
                                Button { query = s } label: { Chip(title: s, symbol: "magnifyingglass", color: Theme.accent) }
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                if filter.isActive {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) { activeFilterChips }
                        }
                        Button("Șterge filtrele", role: .destructive) { filter = ProductFilter(sort: filter.sort) }
                    }
                }
                Section(results.isEmpty ? "" : "\(results.count) rezultate") {
                    ForEach(results.prefix(400)) { p in
                        NavigationLink(value: p) {
                            ProductRow(product: p, distance: location.location.map { p.location.distance(from: $0) })
                        }
                    }
                }
            }
            .overlay {
                if results.isEmpty && (!query.isEmpty || filter.isActive) {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Produs, producător, localitate…")
            .navigationTitle("Caută")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Sortare", selection: $filter.sort) {
                            ForEach(SortOrder.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                        }
                    } label: { Image(systemName: "arrow.up.arrow.down") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showFilters = true } label: {
                        Image(systemName: filter.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .overlay(alignment: .topTrailing) {
                                if filter.activeCount > 0 {
                                    Text("\(filter.activeCount)").font(.caption2.bold()).foregroundStyle(.white)
                                        .padding(3).background(Theme.accent, in: Circle()).offset(x: 8, y: -8)
                                }
                            }
                    }
                }
            }
            .sheet(isPresented: $showFilters) { FilterSheet(filter: $filter) }
            .navigationDestination(for: Product.self) { ProductDetailView(product: $0) }
            .task(id: SearchKey(query: query, filter: filter, hasLocation: location.location != nil)) {
                try? await Task.sleep(nanoseconds: 180_000_000)   // debounce
                guard !Task.isCancelled else { return }
                if query.trimmed.isEmpty && !filter.isActive { results = []; return }
                results = store.search(query, filter: filter, from: location.location)
            }
        }
    }

    @ViewBuilder private var activeFilterChips: some View {
        ForEach(Array(filter.categories), id: \.self) { c in
            Button { filter.categories.remove(c) } label: { Chip(title: c.title, symbol: "xmark", color: c.color, filled: true) }
        }
        ForEach(Array(filter.certifications), id: \.self) { c in
            Button { filter.certifications.remove(c) } label: { Chip(title: c.shortTitle, symbol: "xmark", color: c.color, filled: true) }
        }
        ForEach(Array(filter.regions), id: \.self) { r in
            Button { filter.regions.remove(r) } label: { Chip(title: r.title, symbol: "xmark", color: r.color, filled: true) }
        }
        if let c = filter.county {
            Button { filter.county = nil } label: { Chip(title: "Jud. \(c)", symbol: "xmark", color: Theme.forest, filled: true) }
        }
        if filter.minRating > 0 {
            Button { filter.minRating = 0 } label: { Chip(title: "≥ \(filter.minRating.formatted()) ★", symbol: "xmark", color: Theme.ochre, filled: true) }
        }
    }
}

private struct SearchKey: Equatable {
    let query: String
    let filter: ProductFilter
    let hasLocation: Bool
}

struct FilterSheet: View {
    @Binding var filter: ProductFilter
    @Environment(CatalogStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Categorie") {
                    ForEach(ProductCategory.allCases) { c in
                        toggleRow(c.title, c.symbol, c.color, filter.categories.contains(c)) {
                            if filter.categories.contains(c) { filter.categories.remove(c) } else { filter.categories.insert(c) }
                        }
                    }
                }
                Section("Tip de atestat") {
                    ForEach(CertificationType.allCases.filter { $0 != .other }) { c in
                        toggleRow(c.title, c.symbol, c.color, filter.certifications.contains(c)) {
                            if filter.certifications.contains(c) { filter.certifications.remove(c) } else { filter.certifications.insert(c) }
                        }
                    }
                }
                Section("Regiune") {
                    ForEach(Region.allCases) { r in
                        toggleRow(r.title, r.symbol, r.color, filter.regions.contains(r)) {
                            if filter.regions.contains(r) { filter.regions.remove(r) } else { filter.regions.insert(r) }
                        }
                    }
                }
                Section("Județ") {
                    Picker("Județ", selection: $filter.county) {
                        Text("Oricare").tag(String?.none)
                        ForEach(store.counties, id: \.self) { Text($0).tag(Optional($0)) }
                    }
                }
                Section("Rating minim") {
                    Picker("Rating", selection: $filter.minRating) {
                        Text("Oricare").tag(0.0)
                        Text("3+ ★").tag(3.0)
                        Text("4+ ★").tag(4.0)
                        Text("4,5+ ★").tag(4.5)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Filtre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Resetează") { filter = ProductFilter(sort: filter.sort) }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Aplică") { dismiss() } }
            }
        }
    }

    private func toggleRow(_ title: String, _ symbol: String, _ color: Color, _ on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: symbol).foregroundStyle(.primary)
                Spacer()
                if on { Image(systemName: "checkmark").foregroundStyle(color).fontWeight(.bold) }
            }
        }
    }
}

/// Aranjare pe rânduri care se rup automat (pentru sugestii).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > width, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
            maxX = max(maxX, x)
        }
        return CGSize(width: min(maxX, width), height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}
