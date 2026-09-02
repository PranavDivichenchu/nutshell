import Testing
import Foundation
@testable import Nutshell

/// A service whose every call can be told to succeed, fail, or hang until cancelled.
///
/// The hanging behaviour is the point: the bugs these tests cover only appear once a
/// request is genuinely in flight, which a service that returns immediately can never
/// reproduce.
final class SequencedService: FoodFactsService, @unchecked Sendable {
    enum Behaviour {
        case success(SearchPage)
        case failure(Error)
        /// Blocks until the calling task is cancelled, then throws `CancellationError`.
        case hang
        case delayed(SearchPage, Duration)
    }

    private let lock = NSLock()
    private var behaviours: [Behaviour]
    private(set) var calls: [(query: ProductQuery, page: Int)] = []

    init(_ behaviours: [Behaviour]) { self.behaviours = behaviours }

    var callCount: Int {
        lock.lock(); defer { lock.unlock() }
        return calls.count
    }

    func product(barcode: String) async throws -> Product? { nil }

    func search(_ query: ProductQuery, page: Int) async throws -> SearchPage {
        lock.lock()
        calls.append((query, page))
        let behaviour = behaviours.count > 1 ? behaviours.removeFirst() : (behaviours.first ?? .success(.empty))
        lock.unlock()

        switch behaviour {
        case .success(let page):
            return page
        case .failure(let error):
            throw error
        case .hang:
            try await Task.sleep(for: .seconds(30))   // throws on cancellation
            return .empty
        case .delayed(let page, let delay):
            try await Task.sleep(for: delay)
            return page
        }
    }
}

@MainActor
@Suite("Search cancellation and races")
struct SearchCancellationTests {

    private func makeViewModel(_ service: FoodFactsService) throws -> SearchViewModel {
        let name = "off-cancel-tests"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return SearchViewModel(service: service, recentSearches: RecentSearchesStore(defaults: defaults))
    }

    private func product(_ code: String) throws -> Product {
        try JSONDecoder().decode(
            Product.self, from: Data(#"{"code":"\#(code)","product_name":"Product \#(code)"}"#.utf8)
        )
    }

    private func page(_ products: [Product], total: Int? = nil, hasMore: Bool = false, page: Int = 1) -> SearchPage {
        SearchPage(products: products, page: page, totalCount: total ?? products.count, hasMorePages: hasMore)
    }

    /// Regression: `activeQuery` used to be recorded before the request was awaited, so a
    /// search cancelled in flight — by a tab switch, most easily — left the term recorded
    /// with no results and nothing outstanding. The de-duplication guard then refused to
    /// run it ever again and the screen sat on the loading skeleton forever.
    @Test("A search cancelled in flight can be run again with the same query")
    func cancelledSearchIsRetryable() async throws {
        let results = [try product("1"), try product("2")]
        let service = SequencedService([.hang, .success(page(results))])
        let viewModel = try makeViewModel(service)
        viewModel.query = "chocolate"

        // Comfortably past the debounce, so the request is genuinely in flight — this is
        // the state the bug needed, and a wait that merely equals the debounce is racy.
        let inFlight = Task { await viewModel.searchDebounced() }
        try await Task.sleep(for: .milliseconds(900))
        #expect(service.callCount == 1)
        inFlight.cancel()
        await inFlight.value

        // The identical query must now be allowed through rather than short-circuited.
        await viewModel.searchDebounced()

        guard case .results(let shown, _) = viewModel.phase else {
            Issue.record("search wedged after cancellation: \(viewModel.phase)")
            return
        }
        #expect(shown.count == 2)
        #expect(service.callCount == 2)
    }

    /// Regression: `loadMore` treated cancellation as a paging failure and set
    /// `hasMorePages = false`, permanently disabling pagination for that query.
    @Test("A cancelled page prefetch does not disable pagination")
    func cancelledPrefetchKeepsPagingAlive() async throws {
        let first = [try product("1"), try product("2"), try product("3")]
        let second = [try product("4")]

        let service = SequencedService([
            .success(page(first, total: 40, hasMore: true)),
            .hang,
            .success(page(second, total: 40, hasMore: false, page: 2)),
        ])
        let viewModel = try makeViewModel(service)
        viewModel.query = "chocolate"
        await viewModel.searchDebounced()

        // Cancel the prefetch, as scrolling past the trigger row would.
        let prefetch = Task { await viewModel.loadMoreIfNeeded(after: first[2]) }
        try await Task.sleep(for: .milliseconds(120))
        prefetch.cancel()
        await prefetch.value

        // Paging must still be available.
        #expect(viewModel.shouldLoadMore(after: first[2]))
        await viewModel.loadMoreIfNeeded(after: first[2])

        guard case .results(let shown, _) = viewModel.phase else {
            Issue.record("expected results, got \(viewModel.phase)")
            return
        }
        #expect(shown.map(\.code) == ["1", "2", "3", "4"])
    }

    /// Regression: the retry button spawned an untracked Task, so a slow earlier search
    /// could land after a newer one and overwrite the newer results.
    @Test("A slow earlier response cannot overwrite a newer one")
    func staleResponseIsDropped() async throws {
        let stale = [try product("stale")]
        let fresh = [try product("fresh")]

        let service = SequencedService([
            .delayed(page(stale), .milliseconds(600)),   // first search, slow
            .success(page(fresh)),                        // second search, immediate
        ])
        let viewModel = try makeViewModel(service)

        viewModel.query = "chocolate"
        let slow = Task { await viewModel.searchNow() }
        try await Task.sleep(for: .milliseconds(50))

        // A newer search supersedes it and finishes first.
        await viewModel.searchNow()
        guard case .results(let afterFresh, _) = viewModel.phase else {
            Issue.record("expected fresh results, got \(viewModel.phase)")
            return
        }
        #expect(afterFresh.map(\.code) == ["fresh"])

        // When the stale one finally lands it must be ignored.
        await slow.value
        guard case .results(let final, _) = viewModel.phase else {
            Issue.record("expected results to survive, got \(viewModel.phase)")
            return
        }
        #expect(final.map(\.code) == ["fresh"], "a stale response overwrote newer results")
    }

    @Test("Clearing the query abandons anything in flight")
    func clearingAbandonsInFlightWork() async throws {
        let service = SequencedService([.delayed(page([try product("1")]), .milliseconds(400))])
        let viewModel = try makeViewModel(service)

        viewModel.query = "chocolate"
        let inFlight = Task { await viewModel.searchNow() }
        try await Task.sleep(for: .milliseconds(50))

        viewModel.clear()
        await inFlight.value

        #expect(viewModel.phase == .idle)
    }
}
