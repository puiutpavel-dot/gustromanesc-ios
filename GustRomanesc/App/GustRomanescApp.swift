import SwiftUI

@main
struct GustRomanescApp: App {
    @State private var store = CatalogStore()
    @State private var location = LocationService()
    @State private var favorites = Favorites()
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(location)
                .environment(favorites)
                .environment(router)
                .tint(Theme.accent)
        }
    }
}

struct RootView: View {
    @Environment(CatalogStore.self) private var store
    @Environment(LocationService.self) private var location
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase

    private var loadingProgress: Double {
        if case .loading(let p) = store.state { return p }
        return 0
    }

    var body: some View {
        @Bindable var router = router
        Group {
            switch store.state {
            case .idle, .loading where store.products.isEmpty:
                LoadingView(progress: loadingProgress)
            case .failed(let message) where store.products.isEmpty:
                FailedView(message: message) { Task { await store.refresh(showProgress: true) } }
            default:
                TabView(selection: $router.tab) {
                    HomeView()
                        .tabItem { Label("Acasă", systemImage: "house.fill") }.tag(AppTab.home)
                    MapScreen()
                        .tabItem { Label("Hartă", systemImage: "map.fill") }.tag(AppTab.map)
                    ExploreView()
                        .tabItem { Label("Regiuni", systemImage: "square.grid.3x3.square") }.tag(AppTab.explore)
                    SearchView()
                        .tabItem { Label("Caută", systemImage: "magnifyingglass") }.tag(AppTab.search)
                    FavoritesView()
                        .tabItem { Label("Favorite", systemImage: "heart.fill") }.tag(AppTab.favorites)
                }
            }
        }
        .task {
            location.start()
            await store.bootstrap()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { location.requestOnce() }
        }
    }
}

struct LoadingView: View {
    let progress: Double
    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "basket.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.accent.gradient)
            VStack(spacing: 6) {
                Text("Gust Românesc").font(.largeTitle.weight(.bold))
                Text("Adun produsele atestate din toată țara…").foregroundStyle(.secondary)
            }
            ProgressView(value: progress).tint(Theme.accent).frame(maxWidth: 240)
            Text("Doar la prima pornire – apoi totul merge și offline.").font(.footnote).foregroundStyle(.secondary)
            Spacer()
            FolkStripe(height: 14)
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity)
        .background(Theme.paper)
    }
}

struct FailedView: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        ContentUnavailableView {
            Label("Nu am putut încărca produsele", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Încearcă din nou", action: retry).buttonStyle(.borderedProminent).tint(Theme.accent)
        }
    }
}
