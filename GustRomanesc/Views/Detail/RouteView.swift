import SwiftUI
import MapKit

/// Traseul rutier de la tine până la producător, calculat în aplicație.
struct RouteView: View {
    let destination: CLLocationCoordinate2D
    let title: String

    @Environment(LocationService.self) private var location
    @Environment(CatalogStore.self) private var store
    @State private var route: MKRoute?
    @State private var error: String?
    @State private var loading = false
    @State private var focus: MapFocus

    init(destination: CLLocationCoordinate2D, title: String) {
        self.destination = destination
        self.title = title
        _focus = State(initialValue: .around(destination, km: 30))
    }

    private var destinationPoint: [ProductionPoint] {
        store.points.filter { abs($0.coordinate.latitude - destination.latitude) < 0.00001 && abs($0.coordinate.longitude - destination.longitude) < 0.00001 }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ClusteredMapView(points: destinationPoint, focus: focus, route: route, onSelect: { _ in })
                .ignoresSafeArea(edges: .bottom)

            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.headline).lineLimit(2)
                if loading {
                    HStack { ProgressView(); Text("Calculez traseul…").foregroundStyle(.secondary) }
                } else if let route {
                    HStack(spacing: 18) {
                        stat(RoutePlanner.format(route.expectedTravelTime), "durată", "clock.fill")
                        stat(Geo.formattedDistance(route.distance), "distanță", "road.lanes")
                    }
                } else if let error {
                    Text(error).font(.subheadline).foregroundStyle(.secondary)
                }
                DirectionsMenu(coordinate: destination, name: title) {
                    Label("Pornește navigația", systemImage: "location.north.line.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding()
        }
        .navigationTitle("Traseu")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: location.location == nil) { await compute() }
    }

    private func stat(_ value: String, _ label: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(value, systemImage: symbol).font(.title3.weight(.bold)).foregroundStyle(Theme.accent)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func compute() async {
        guard let from = location.location?.coordinate else {
            error = location.isDenied
                ? "Activează accesul la locație din Setări ca să-ți calculez traseul."
                : "Aștept locația ta…"
            location.requestOnce()
            return
        }
        loading = true
        defer { loading = false }
        do {
            route = try await RoutePlanner.route(from: from, to: destination)
            error = nil
        } catch {
            self.error = "Nu am găsit un traseu rutier. Poți încerca direct în aplicația de navigație."
        }
    }
}
