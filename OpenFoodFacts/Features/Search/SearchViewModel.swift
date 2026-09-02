import Foundation
import Observation

@Observable
@MainActor
final class SearchViewModel {

    /// The mutually exclusive states the results area can be in. Modelling them as one
    /// enum rather than a set of booleans makes impossible combinations unrepresentable
    /// — no "loading and failed at the same time".
    enum Phase: Equatable {
        case idle
        case searching
        case results([Product], total: Int)
        case noResults(query: String)
        case failed(APIError)
    }

    /// Long enough that an average typist triggers one request per word rather than
    /// per keystroke, which matters because this endpoint rate-limits aggressively.
    private static let debounce = Duration.milliseconds(350)

    /// One character matches nearly everything and wastes a request.
    private static let minimumQueryLength = 2

    var query = ""
    private(set) var phase: Phase = .idle
    private(set) var isLoadingMore = false

    private var loadedProducts: [Product] = []
    private var currentPage = 1
    private var hasMorePages = false
    private var activeQuery = ""

    private let service: FoodFactsService
    private let recentSearches: RecentSearchesStore

    init(service: FoodFactsService = OpenFoodFactsClient(), recentSearches: RecentSearchesStore) {
        self.service = service
        self.recentSearches = recentSearches
    }

    // MARK: - Searching

    /// Debounces, then runs the search.
    ///
    /// Driven by `.task(id: query)`, so SwiftUI cancels the previous call the moment the
    /// query changes: the sleep below throws and the superseded request is abandoned
    /// before it is ever sent. That is the whole debounce — no timers to invalidate.
    func searchDebounced() async {
        let trimmed = query.trimmed

        guard trimmed.count >= Self.minimumQueryLength else {
            reset()
            return
        }

        // Re-running the same search (e.g. on view reappearance) should not flicker.
        guard trimmed != activeQuery else { return }

        do {
            try await Task.sleep(for: Self.debounce)
        } catch {
            return // Superseded by a newer keystroke.
        }

        await performSearch(trimmed)
    }

    /// Runs the current query immediately, skipping the debounce. Used by the retry
    /// button and by tapping a recent search.
    func searchNow() async {
        guard let trimmed = query.trimmed.nilIfBlank else { return }
        activeQuery = ""
        await performSearch(trimmed)
    }

    private func performSearch(_ term: String) async {
        phase = .searching
        activeQuery = term

        do {
            let page = try await service.search(term, page: 1)
            guard !Task.isCancelled else { return }

            loadedProducts = page.products
            currentPage = page.page
            hasMorePages = page.hasMorePages

            if page.products.isEmpty {
                phase = .noResults(query: term)
            } else {
                phase = .results(page.products, total: page.totalCount)
                recentSearches.record(term)
            }
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            activeQuery = "" // Allow an identical query to be retried.
            phase = .failed(error as? APIError ?? .unreadableResponse)
        }
    }

    // MARK: - Pagination

    /// Whether the given product is close enough to the end of the list to prefetch.
    func shouldLoadMore(after product: Product) -> Bool {
        guard hasMorePages, !isLoadingMore else { return false }
        // Start the next page three rows early so scrolling stays continuous.
        return loadedProducts.suffix(3).contains { $0.code == product.code }
    }

    func loadMoreIfNeeded(after product: Product) async {
        guard shouldLoadMore(after: product) else { return }
        await loadMore()
    }

    private func loadMore() async {
        guard hasMorePages, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let next = try await service.search(activeQuery, page: currentPage + 1)
            guard !Task.isCancelled, case .results = phase else { return }

            // The API can repeat products across pages; de-duplicate by barcode so
            // SwiftUI never sees two rows with the same identity.
            let known = Set(loadedProducts.map(\.code))
            loadedProducts += next.products.filter { !known.contains($0.code) }

            currentPage = next.page
            hasMorePages = next.hasMorePages
            phase = .results(loadedProducts, total: next.totalCount)
        } catch {
            // A failed page shouldn't discard results already on screen; stop paging quietly.
            hasMorePages = false
        }
    }

    // MARK: - Editing

    func apply(recentSearch term: String) {
        query = term
    }

    func clear() {
        query = ""
        reset()
    }

    private func reset() {
        loadedProducts = []
        activeQuery = ""
        currentPage = 1
        hasMorePages = false
        phase = .idle
    }
}
