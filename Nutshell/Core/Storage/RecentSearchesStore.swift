import Foundation
import Observation

/// A short history of search terms, so returning to an empty search bar offers
/// something useful instead of a blank screen.
@Observable
@MainActor
final class RecentSearchesStore {
    private static let limit = 8
    private static let defaultsKey = "recent-searches"

    private(set) var terms: [String] = []
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        terms = defaults.stringArray(forKey: Self.defaultsKey) ?? []
    }

    /// Records a term, moving an existing entry back to the top rather than duplicating it.
    func record(_ term: String) {
        guard let cleaned = term.trimmed.nilIfBlank else { return }
        terms.removeAll { $0.caseInsensitiveCompare(cleaned) == .orderedSame }
        terms.insert(cleaned, at: 0)
        if terms.count > Self.limit { terms.removeLast(terms.count - Self.limit) }
        defaults.set(terms, forKey: Self.defaultsKey)
    }

    func clear() {
        terms.removeAll()
        defaults.removeObject(forKey: Self.defaultsKey)
    }
}
