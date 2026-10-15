import SwiftUI
import CoreLocation

struct FavoritesView: View {
    @Environment(CatalogStore.self) private var store
    @Environment(Favorites.self) private var favorites
    @Environment(LocationService.self) private var location

    private var items: [Product] {
        let list = store.products.filter { favorites.contains($0) }
        guard let loc = location.location else { return list }
        return list.sorted { $0.location.distance(from: loc) < $1.location.distance(from: loc) }
    }

    /// Opriri unice (un producător = o oprire), ordonate „cel mai apropiat următor”.
    private var tripStops: [CLLocationCoordinate2D] {
        var remaining = Dictionary(grouping: items, by: \.pointId).compactMap { $0.value.first?.location }
        var current = location.location ?? remaining.first
        var ordered: [CLLocation] = []
        while let c = current, !remaining.isEmpty {
            let idx = remaining.indices.min { remaining[$0].distance(from: c) < remaining[$1].distance(from: c) }!
            let next = remaining.remove(at: idx)
            ordered.append(next)
            current = next
        }
        return ordered.map(\.coordinate)
    }

    var body: some View {
        NavigationStack {
            List {
                if items.count >= 2 {
                    Section {
                        Button {
                            NavigationApp.openMultiStop(Array(tripStops.prefix(10)))
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "point.3.filled.connected.trianglepath.dotted").font(.title2).foregroundStyle(Theme.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Traseu gustos").font(.headline).foregroundStyle(.primary)
                                    Text("Un drum prin \(min(tripStops.count, 10)) producători salvați, în ordinea cea mai scurtă (Google Maps)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                Section {
                    ForEach(items) { p in
                        NavigationLink(value: p) {
                            ProductRow(product: p, distance: location.location.map { p.location.distance(from: $0) })
                        }
                        .swipeActions {
                            Button(role: .destructive) { favorites.toggle(p) } label: { Label("Șterge", systemImage: "heart.slash") }
                        }
                    }
                }
            }
            .overlay {
                if items.isEmpty {
                    EmptyStateView(symbol: "heart", title: "Niciun favorit încă",
                                   message: "Apasă ♥ pe un produs ca să-l păstrezi aici și să-ți planifici un traseu gustos.")
                }
            }
            .navigationTitle("Favorite")
            .navigationDestination(for: Product.self) { ProductDetailView(product: $0) }
        }
    }
}
