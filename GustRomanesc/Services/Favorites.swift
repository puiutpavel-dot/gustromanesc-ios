import Foundation
import Observation

/// Produse salvate de utilizator, ținute local.
@MainActor
@Observable
final class Favorites {
    private(set) var ids: Set<Int> = []
    private let key = "favoriteProductIds"

    init() {
        ids = Set(UserDefaults.standard.array(forKey: key) as? [Int] ?? [])
    }

    func contains(_ p: Product) -> Bool { ids.contains(p.id) }

    func toggle(_ p: Product) {
        if ids.contains(p.id) { ids.remove(p.id) } else { ids.insert(p.id) }
        UserDefaults.standard.set(Array(ids), forKey: key)
    }
}
