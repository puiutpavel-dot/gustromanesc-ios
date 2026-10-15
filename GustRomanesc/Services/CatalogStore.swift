import Foundation
import CoreLocation
import Observation

/// Descarcă catalogul CPAC, îl păstrează local și construiește indexurile folosite de ecrane.
@MainActor
@Observable
final class CatalogStore {
    enum LoadState: Equatable {
        case idle, loading(progress: Double), loaded, failed(String)
    }

    private(set) var state: LoadState = .idle
    private(set) var products: [Product] = []
    private(set) var points: [ProductionPoint] = []
    private(set) var lastUpdated: Date?
    private(set) var isRefreshing = false

    private(set) var productsByCounty: [String: [Product]] = [:]
    private(set) var productsByRegion: [Region: [Product]] = [:]
    private(set) var productsByProducer: [Int: [Product]] = [:]
    private(set) var pointsById: [Int: ProductionPoint] = [:]

    var counties: [String] {
        productsByCounty.keys.sorted { $0.compare($1, locale: Locale(identifier: "ro_RO")) == .orderedAscending }
    }

    private let api = CPACClient()
    private let cacheURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("cpac-catalog.json")
    }()
    private let maxCacheAge: TimeInterval = 7 * 24 * 3600

    // MARK: Încărcare

    func bootstrap() async {
        if products.isEmpty, let cached = loadCache() {
            apply(records: cached.records)
            lastUpdated = cached.date
            state = .loaded
        }
        let stale = lastUpdated.map { Date().timeIntervalSince($0) > maxCacheAge } ?? true
        if products.isEmpty {
            await refresh(showProgress: true)
        } else if stale {
            await refresh(showProgress: false)
        }
    }

    func refresh(showProgress: Bool = false) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        if showProgress || products.isEmpty { state = .loading(progress: 0) }
        do {
            let records = try await api.fetchAll { [weak self] p in
                Task { @MainActor in
                    guard let self, case .loading = self.state else { return }
                    self.state = .loading(progress: p)
                }
            }
            apply(records: records)
            lastUpdated = Date()
            saveCache(records)
            state = .loaded
        } catch {
            if products.isEmpty {
                state = .failed("Nu am putut descărca catalogul AFIR. Verifică conexiunea la internet și încearcă din nou.\n(\(error.localizedDescription))")
            } else {
                state = .loaded   // rămânem pe datele salvate
            }
        }
    }

    private func apply(records: [CPACRecord]) {
        var seen = Set<Int>()
        let list = records.compactMap { r -> Product? in
            guard seen.insert(r.AtestatId).inserted else { return nil }
            return Product(record: r)
        }
        products = list.sorted { $0.name.compare($1.name, locale: Locale(identifier: "ro_RO")) == .orderedAscending }
        productsByCounty = Dictionary(grouping: products, by: \.county)
        productsByRegion = Dictionary(grouping: products, by: \.region)
        productsByProducer = Dictionary(grouping: products, by: \.producerId)

        let grouped = Dictionary(grouping: products, by: \.pointId)
        points = grouped.compactMap { id, items in
            guard let first = items.first else { return nil }
            return ProductionPoint(
                id: id,
                coordinate: first.coordinate,
                producerName: first.producerName,
                address: first.pointAddress,
                locality: first.locality,
                county: first.county,
                products: items.sorted { $0.rating > $1.rating },
                isApproximate: first.isApproximateLocation
            )
        }
        pointsById = Dictionary(uniqueKeysWithValues: points.map { ($0.id, $0) })
    }

    // MARK: Interogări

    func producer(for product: Product) -> Producer {
        Producer(id: product.producerId, name: product.producerName, address: product.producerAddress,
                 products: productsByProducer[product.producerId] ?? [product])
    }

    func point(for product: Product) -> ProductionPoint? { pointsById[product.pointId] }

    func products(near location: CLLocation, radiusKm: Double) -> [(product: Product, distance: CLLocationDistance)] {
        let r = radiusKm * 1000
        return products
            .map { ($0, $0.location.distance(from: location)) }
            .filter { $0.1 <= r }
            .sorted { $0.1 < $1.1 }
            .map { (product: $0.0, distance: $0.1) }
    }

    func nearestPoints(to location: CLLocation, limit: Int) -> [(point: ProductionPoint, distance: CLLocationDistance)] {
        points.map { (point: $0, distance: $0.location.distance(from: location)) }
            .sorted { $0.distance < $1.distance }
            .prefix(limit).map { $0 }
    }

    func search(_ query: String, filter: ProductFilter, from location: CLLocation?) -> [Product] {
        let terms = query.folded.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        var result = products.filter { p in
            filter.matches(p) && terms.allSatisfy { p.searchBlob.contains($0) }
        }
        switch filter.sort {
        case .distance:
            if let location {
                result.sort { $0.location.distance(from: location) < $1.location.distance(from: location) }
            }
        case .rating: result.sort { $0.rating > $1.rating }
        case .name: break
        case .newest: result.sort { ($0.certificateYear ?? 0) > ($1.certificateYear ?? 0) }
        }
        return result
    }

    /// Un produs „al zilei”, stabil pe parcursul unei zile.
    var productOfTheDay: Product? {
        guard !products.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        let candidates = products.filter { $0.rating >= 4.5 && $0.description.count > 80 }
        let pool = candidates.isEmpty ? products : candidates
        return pool[day % pool.count]
    }

    // MARK: Cache

    private struct CacheFile: Codable { let date: Date; let records: [CPACRecord] }

    private func loadCache() -> CacheFile? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(CacheFile.self, from: data)
    }

    private func saveCache(_ records: [CPACRecord]) {
        let file = CacheFile(date: Date(), records: records)
        Task.detached(priority: .background) { [cacheURL] in
            if let data = try? JSONEncoder().encode(file) {
                try? data.write(to: cacheURL, options: .atomic)
            }
        }
    }
}

/// Filtre comune pentru căutare și hartă.
struct ProductFilter: Equatable {
    var categories: Set<ProductCategory> = []
    var certifications: Set<CertificationType> = []
    var regions: Set<Region> = []
    var county: String? = nil
    var minRating: Double = 0
    var sort: SortOrder = .distance

    var isActive: Bool {
        !categories.isEmpty || !certifications.isEmpty || !regions.isEmpty || county != nil || minRating > 0
    }
    var activeCount: Int {
        categories.count + certifications.count + regions.count + (county == nil ? 0 : 1) + (minRating > 0 ? 1 : 0)
    }

    func matches(_ p: Product) -> Bool {
        (categories.isEmpty || categories.contains(p.category)) &&
        (certifications.isEmpty || certifications.contains(p.certification)) &&
        (regions.isEmpty || regions.contains(p.region)) &&
        (county == nil || county == p.county) &&
        p.rating >= minRating
    }
}

// MARK: - Client HTTP

struct CPACClient {
    static let base = URL(string: "https://cpac.afir.info")!
    private let pageSize = 250   // maximul acceptat de server
    private let categoryIds = [0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 13]
    private let certificationIds = [0, 1, 2, 3, 4, 5, 6, 7, 18, 19, 20, 21]

    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 30
        c.httpAdditionalHeaders = ["Accept": "application/json", "X-Requested-With": "XMLHttpRequest"]
        return URLSession(configuration: c)
    }()

    private func url(page: Int) -> URL {
        var c = URLComponents(url: Self.base.appendingPathComponent("GetListaProduseData"), resolvingAgainstBaseURL: false)!
        var items = [URLQueryItem(name: "q", value: "all")]
        items += categoryIds.map { URLQueryItem(name: "fCp", value: String($0)) }
        items += certificationIds.map { URLQueryItem(name: "fTa", value: String($0)) }
        items += [URLQueryItem(name: "ps", value: String(pageSize)), URLQueryItem(name: "pn", value: String(page))]
        c.queryItems = items
        return c.url!
    }

    private func page(_ n: Int) async throws -> CPACResponse {
        var lastError: Error = URLError(.unknown)
        for attempt in 0..<3 {
            do {
                let (data, response) = try await session.data(from: url(page: n))
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                return try JSONDecoder().decode(CPACResponse.self, from: data)
            } catch {
                lastError = error
                try? await Task.sleep(nanoseconds: UInt64(attempt + 1) * 700_000_000)
            }
        }
        throw lastError
    }

    /// Paginile sunt numerotate de la 1.
    func fetchAll(progress: @escaping @Sendable (Double) -> Void) async throws -> [CPACRecord] {
        let first = try await page(1)
        let totalPages = max(first.TotalPages ?? 1, 1)
        var all = first.Records
        progress(1 / Double(totalPages))
        guard totalPages > 1 else { return all }

        try await withThrowingTaskGroup(of: (Int, [CPACRecord]).self) { group in
            var next = 2
            var done = 1
            var results: [Int: [CPACRecord]] = [:]
            let concurrency = 4
            for _ in 0..<min(concurrency, totalPages - 1) {
                let n = next; next += 1
                group.addTask { (n, try await page(n).Records) }
            }
            while let item = try await group.next() {
                results[item.0] = item.1
                done += 1
                progress(Double(done) / Double(totalPages))
                if next <= totalPages {
                    let m = next; next += 1
                    group.addTask { (m, try await page(m).Records) }
                }
            }
            for n in 2...totalPages { all += results[n] ?? [] }
        }
        return all
    }
}
