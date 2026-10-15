import SwiftUI
import MapKit

struct ProductDetailView: View {
    let product: Product
    var showMapButton = true

    @Environment(CatalogStore.self) private var store
    @Environment(LocationService.self) private var location
    @Environment(Favorites.self) private var favorites
    @Environment(AppRouter.self) private var router
    @State private var showCertInfo = false
    @State private var expanded = false

    private var distance: CLLocationDistance? { location.location.map { product.location.distance(from: $0) } }
    private var siblings: [Product] {
        (store.productsByProducer[product.producerId] ?? []).filter { $0.id != product.id }
    }
    private var similarNearby: [Product] {
        store.products.filter { $0.category == product.category && $0.producerId != product.producerId }
            .map { ($0, $0.location.distance(from: product.location)) }
            .filter { $0.1 < 60_000 }
            .sorted { $0.1 < $1.1 }
            .prefix(10).map(\.0)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                actions
                if !product.description.isEmpty { descriptionSection }
                certificateSection
                locationSection
                if !siblings.isEmpty { siblingsSection }
                if !similarNearby.isEmpty { similarSection }
                Text("Sursa: Catalogul Produselor și Activităților Certificate (CPAC), AFIR.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(Theme.paper)
        .navigationTitle(product.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ShareLink(item: shareText) { Image(systemName: "square.and.arrow.up") }
                Button { favorites.toggle(product) } label: {
                    Image(systemName: favorites.contains(product) ? "heart.fill" : "heart")
                        .foregroundStyle(Theme.accent)
                }
                .accessibilityLabel(favorites.contains(product) ? "Scoate din favorite" : "Adaugă la favorite")
            }
        }
        .sheet(isPresented: $showCertInfo) { CertificationInfoSheet(highlight: product.certification) }
    }

    private var shareText: String {
        "\(product.name) – \(product.producerName), \(product.locality), jud. \(product.county). \(product.certification.title). https://maps.apple.com/?ll=\(product.coordinate.latitude),\(product.coordinate.longitude)&q=\(product.producerName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                CategoryIcon(category: product.category, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.category.title.uppercased()).font(.caption.weight(.bold)).foregroundStyle(product.category.color)
                    Text(product.name).font(.title2.weight(.bold)).fixedSize(horizontal: false, vertical: true)
                }
            }
            FolkStripe(height: 8).clipShape(Capsule())
            HStack {
                Button { showCertInfo = true } label: {
                    Chip(title: product.certification.title, symbol: product.certification.symbol, color: product.certification.color, filled: true)
                }
                Spacer()
                RatingView(rating: product.rating)
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            DirectionsMenu(coordinate: product.coordinate, name: product.producerName) {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill").font(.title3)
                    Text(distance.map { Geo.formattedDistance($0) } ?? "Navighează").font(.caption.weight(.semibold))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(.white)
            }
            NavigationLink {
                RouteView(destination: product.coordinate, title: product.producerName)
            } label: {
                actionTile("point.topleft.down.to.point.bottomright.curvepath.fill",
                           distance.map { Geo.estimatedDriveTime($0) } ?? "Traseu")
            }
            if showMapButton, let point = store.point(for: product) {
                Button { router.showOnMap(point) } label: { actionTile("map.fill", "Pe hartă") }
            }
        }
        .buttonStyle(.plain)
    }

    private func actionTile(_ symbol: String, _ title: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.title3)
            Text(title).font(.caption.weight(.semibold)).lineLimit(1)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .foregroundStyle(Theme.accent)
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Despre produs")
            Text(product.description)
                .font(.body)
                .lineLimit(expanded ? nil : 6)
                .fixedSize(horizontal: false, vertical: true)
            if product.description.count > 320 {
                Button(expanded ? "Mai puțin" : "Citește tot") { withAnimation { expanded.toggle() } }
                    .font(.subheadline.weight(.semibold)).tint(Theme.accent)
            }
        }
        .card()
    }

    private var certificateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Atestat")
            infoRow("Tip", product.certification.title, "rosette")
            infoRow("Număr", product.certificateNumber, "number")
            if let y = product.certificateYear { infoRow("An", String(y), "calendar") }
            Button { showCertInfo = true } label: {
                Label("Ce înseamnă acest atestat?", systemImage: "info.circle")
            }
            .font(.subheadline.weight(.semibold)).tint(Theme.accent)
        }
        .card()
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Unde îl găsești")
            infoRow("Producător", product.producerName, "person.crop.square.filled.and.at.rectangle")
            infoRow("Punct de lucru", product.pointAddress, "mappin.and.ellipse")
            if product.producerAddress != product.pointAddress, !product.producerAddress.isEmpty {
                infoRow("Sediu", product.producerAddress, "building.2")
            }
            infoRow("Regiune", "\(product.region.title) · jud. \(product.county)", product.region.symbol)
            if product.isApproximateLocation {
                Label("Producătorul nu are coordonate exacte; pinul e în centrul județului.", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
            Map(initialPosition: .region(MKCoordinateRegion(center: product.coordinate, latitudinalMeters: 6000, longitudinalMeters: 6000))) {
                Marker(product.producerName, systemImage: product.category.symbol, coordinate: product.coordinate)
                    .tint(product.category.color)
                UserAnnotation()
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .allowsHitTesting(false)
            Button {
                UIPasteboard.general.string = product.pointAddress
            } label: { Label("Copiază adresa", systemImage: "doc.on.doc") }
                .font(.subheadline.weight(.semibold)).tint(Theme.accent)
        }
        .card()
    }

    private var siblingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink {
                ProducerView(producer: store.producer(for: product))
            } label: {
                HStack {
                    SectionHeader(title: "De la același producător", subtitle: "\(siblings.count) produse")
                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            carousel(siblings.prefix(12).map { $0 })
        }
    }

    private var similarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "\(product.category.title) în apropiere", subtitle: "La cel mult 60 km de acest producător")
            carousel(similarNearby)
        }
    }

    private func carousel(_ items: [Product]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(items) { p in
                    NavigationLink { ProductDetailView(product: p, showMapButton: showMapButton) } label: {
                        ProductCard(product: p, distance: location.location.map { p.location.distance(from: $0) })
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func infoRow(_ label: String, _ value: String, _ symbol: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).frame(width: 22).foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.subheadline).textSelection(.enabled)
            }
        }
    }
}

extension View {
    func card() -> some View {
        self.padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct ProducerView: View {
    let producer: Producer
    @Environment(CatalogStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(producer.name).font(.title3.weight(.bold))
                    if !producer.address.isEmpty {
                        Label(producer.address, systemImage: "building.2").font(.subheadline).foregroundStyle(.secondary)
                    }
                    let cats = Set(producer.products.map(\.category)).sorted { $0.title < $1.title }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack { ForEach(cats) { Chip(title: $0.title, symbol: $0.symbol, color: $0.color) } }
                    }
                }
            }
            Section("\(producer.products.count) produse atestate") {
                ForEach(producer.products) { p in
                    NavigationLink { ProductDetailView(product: p) } label: { ProductRow(product: p) }
                }
            }
        }
        .navigationTitle("Producător")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CertificationInfoSheet: View {
    var highlight: CertificationType? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Toate produsele din aplicație sunt înscrise în Catalogul Produselor și Activităților Certificate (CPAC) al AFIR. Iată ce înseamnă fiecare atestat:")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(CertificationType.allCases.filter { $0 != .other }) { c in
                    VStack(alignment: .leading, spacing: 6) {
                        Label(c.title, systemImage: c.symbol).font(.headline).foregroundStyle(c.color)
                        Text(c.explanation).font(.subheadline)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(c == highlight ? c.color.opacity(0.12) : nil)
                }
            }
            .navigationTitle("Tipuri de atestate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Gata") { dismiss() } } }
        }
    }
}
