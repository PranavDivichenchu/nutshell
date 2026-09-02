import Foundation
import Observation

/// Cross-tab navigation state.
///
/// Home needs to be able to hand a query to Search — tapping "Chocolate" should land on
/// real results, not just switch tabs and leave an empty search bar.
@Observable
@MainActor
final class AppRouter {
    enum Tab: Hashable { case home, search, saved, profile }

    var tab: Tab = .home

    /// A query Home has handed over. Search consumes it and clears it.
    var pendingQuery: String?

    /// Whether the scan sheet is up. Reachable from both Home and Search.
    var isScanning = false

    func search(for query: String) {
        pendingQuery = query
        tab = .search
    }
}
