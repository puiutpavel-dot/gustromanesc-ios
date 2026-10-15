import SwiftUI
import MapKit

struct MapScreen: View {
    @Environment(CatalogStore.self) private var store
    @Environment(LocationService.self) private var location
    @Environment(AppRouter.self) private var router

    @State private var categories: Set<ProductCategory> = []
    @State private var certification: CertificationType?
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var localFocus: MapFocus?
    @State private var listInArea = false

    private var filteredPoints: [ProductionPoint] {
        store.points.filter { pt in
            (router.mapCountyFilter == nil || pt.county == router.mapCountyFilter) &&
            pt.products.contains { p in
                (categories.isEmpty || categories.contains(p.category)) &&
                (certification == nil || p.certification == certification)
            }
        }
    }

    private var pointsInView: [ProductionPoint] {
        guard let r = visibleRegion else { return [] }
        let latR = (r.center.latitude - r.span.latitudeDelta / 2)...(r.center.latitude + r.span.latitudeDelta / 2)
        let lonR = (r.center.longitude - r.span.longitudeDelta / 2)...(r.center.longitude + r.span.longitudeDelta / 2)
        return filteredPoints.filter { latR.contains($0.coordinate.latitude) && lonR.contains($0.coordinate.longitude) }
    }

    var body: some View {
        @Bindable var router = router
        ZStack(alignment: .top) {
            ClusteredMapView(
                points: filteredPoints,
                focus: localFocus ?? router.mapFocus,
                onSelect: { router.mapSelectedPoint = $0 },
                onRegionChange: { visibleRegion = $0 }
            )
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 8) {
                categoryBar
                if let county = router.mapCountyFilter {
                    Button { router.mapCountyFilter = nil } label: {
                        Chip(title: "Județul \(county)", symbol: "xmark.circle.fill", color: Theme.forest, filled: true)
                    }
                }
            }
            .padding(.top, 6)

            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    areaButton
                    Spacer()
                    controls
                }
                .padding()
            }
        }
        .onChange(of: router.mapFocus) { _, _ in localFocus = nil }
        .sheet(item: $router.mapSelectedPoint) { point in
            PointSheet(point: point)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $listInArea) {
            NavigationStack {
                AreaListView(points: pointsInView)
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    Button("Toate atestatele") { certification = nil }
                    Divider()
                    ForEach(CertificationType.allCases) { c in
                        Button { certification = c } label: { Label(c.title, systemImage: c.symbol) }
                    }
                } label: {
                    Chip(title: certification?.shortTitle ?? "Atestat", symbol: "line.3.horizontal.decrease.circle.fill",
                         color: Theme.accent, filled: certification != nil)
                }
                ForEach(ProductCategory.allCases) { c in
                    Button {
                        if categories.contains(c) { categories.remove(c) } else { categories.insert(c) }
                    } label: {
                        Chip(title: c.title, symbol: c.symbol, color: c.color, filled: categories.contains(c))
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 2)
        }
    }

    private var areaButton: some View {
        Button { listInArea = true } label: {
            Label(pointsInView.isEmpty ? "Niciun producător aici" : "\(pointsInView.count) producători în zonă",
                  systemImage: "list.bullet")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
        }
        .disabled(pointsInView.isEmpty)
        .tint(.primary)
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Menu {
                ForEach(Region.allCases) { region in
                    let counties = region.counties.filter { store.productsByCounty[$0] != nil }
                    if !counties.isEmpty {
                        Section(region.title) {
                            ForEach(counties, id: \.self) { c in
                                Button(c) {
                                    let pts = store.points.filter { $0.county == c }
                                    router.showCountyOnMap(c, points: pts)
                                }
                            }
                        }
                    }
                }
            } label: { mapButton("square.grid.3x3.square") }
            Button { localFocus = .romania; router.mapCountyFilter = nil } label: { mapButton("globe.europe.africa") }
            Button {
                if let loc = location.location { localFocus = .around(loc.coordinate, km: 40) } else { location.start() }
            } label: { mapButton(location.location == nil ? "location" : "location.fill") }
        }
    }

    private func mapButton(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.title3)
            .frame(width: 46, height: 46)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .foregroundStyle(Theme.accent)
    }
}

/// Lista producătorilor vizibili pe hartă.
struct AreaListView: View {
    let points: [ProductionPoint]
    @Environment(LocationService.self) private var location
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    var sorted: [ProductionPoint] {
        guard let loc = location.location else { return points.sorted { $0.producerName < $1.producerName } }
        return points.sorted { $0.location.distance(from: loc) < $1.location.distance(from: loc) }
    }

    var body: some View {
        List(sorted) { pt in
            Button {
                dismiss()
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    router.mapSelectedPoint = pt
                }
            } label: {
                HStack(spacing: 12) {
                    CategoryIcon(category: pt.mainCategory, size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pt.producerName).font(.headline).foregroundStyle(.primary)
                        Text("\(pt.products.count) produse · \(pt.locality), \(pt.county)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let loc = location.location {
                        Text(Geo.formattedDistance(pt.location.distance(from: loc))).font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                    }
                }
            }
        }
        .navigationTitle("În zona hărții")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Foaia care apare când atingi un punct de pe hartă.
struct PointSheet: View {
    let point: ProductionPoint
    @Environment(LocationService.self) private var location

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(point.producerName).font(.title3.weight(.bold))
                        Label(point.address, systemImage: "mappin.and.ellipse").font(.subheadline).foregroundStyle(.secondary)
                        if point.isApproximate {
                            Label("Locație aproximativă (centrul județului)", systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.orange)
                        }
                        if let loc = location.location {
                            let d = point.location.distance(from: loc)
                            Text("\(Geo.formattedDistance(d)) de tine · \(Geo.estimatedDriveTime(d)) cu mașina")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                        }
                        HStack {
                            DirectionsMenu(coordinate: point.coordinate, name: point.producerName) {
                                Label("Navighează", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            NavigationLink {
                                RouteView(destination: point.coordinate, title: point.producerName)
                            } label: {
                                Label("Traseu", systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        .tint(Theme.accent)
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                }
                Section("\(point.products.count) produse atestate") {
                    ForEach(point.products) { p in
                        NavigationLink(value: p) { ProductRow(product: p) }
                    }
                }
            }
            .navigationDestination(for: Product.self) { ProductDetailView(product: $0, showMapButton: false) }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
