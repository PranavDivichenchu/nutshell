import Testing
import Foundation
@testable import Nutshell

/// A service whose every call is scripted and counted, so the view model's state machine
/// can be driven through paths the real API makes hard to reproduce on demand.
final class ScriptedService: FoodFactsService, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [Result<SearchPage, Error>]
    private(set) var calls: [(query: ProductQuery, page: Int)] = []

    init(_ responses: [Result<SearchPage, Error>]) {
        self.responses = responses
    }

    convenience init(products: [Product], totalCount: Int? = nil, hasMore: Bool = false) {
        self.init([.success(SearchPage(
            products: products, page: 1, totalCount: totalCount ?? products.count, hasMorePages: hasMore
        ))])
    }

    var callCount: Int {
        lock.lock(); defer { lock.unlock() }
        return calls.count
    }

    func product(barcode: String) async throws -> Product? { nil }

    func search(_ query: ProductQuery, page: Int) async throws -> SearchPage {
        lock.lock()
        calls.append((query, page))
        let response = responses.count > 1 ? responses.removeFirst() : (responses.first ?? .success(.empty))
        lock.unlock()
        return try response.get()
    }
}

@MainActor
@Suite("Search view model")
struct SearchViewModelTests {

    private func makeViewModel(_ service: FoodFactsService) throws -> SearchViewModel {
        let name = "off-vm-tests"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return SearchViewModel(service: service, recentSearches: RecentSearchesStore(defaults: defaults))
    }

    private func product(_ code: String, _ name: String) throws -> Product {
        try JSONDecoder().decode(
            Product.self, from: Data(#"{"code":"\#(code)","product_name":"\#(name)"}"#.utf8)
        )
    }

    @Test("A query too short to be meaningful never reaches the network")
    func shortQueriesAreIdle() async throws {
        let service = ScriptedService(products: [])
        let viewModel = try makeViewModel(service)

        viewModel.query = "o"
        await viewModel.searchDebounced()

        #expect(viewModel.phase == .idle)
        #expect(service.callCount == 0)   // one-character queries match nearly everything
    }

    @Test("Clearing the search bar returns to the idle state")
    func clearingResets() async throws {
        let viewModel = try makeViewModel(ScriptedService(products: [try product("1", "Oat Drink")]))

        viewModel.query = "oat"
        await viewModel.searchDebounced()
        #expect(viewModel.phase != .idle)

        viewModel.clear()
        #expect(viewModel.phase == .idle)
        #expect(viewModel.query.isEmpty)
    }

    @Test("A successful search publishes its results and total")
    func publishesResults() async throws {
        let products = [try product("1", "Oat Drink"), try product("2", "Oat Milk")]
        let viewModel = try makeViewModel(ScriptedService(products: products, totalCount: 500))

        viewModel.query = "oat"
        await viewModel.searchDebounced()

        guard case .results(let shown, let total) = viewModel.phase else {
            Issue.record("expected results, got \(viewModel.phase)")
            return
        }
        #expect(shown.map(\.code) == ["1", "2"])
        #expect(total == 500)
    }

    @Test("An empty result set is a distinct state from a failure")
    func emptyResultsAreNotAnError() async throws {
        let viewModel = try makeViewModel(ScriptedService(products: []))

        viewModel.query = "zzzznotafood"
        await viewModel.searchDebounced()

        #expect(viewModel.phase == .noResults(query: "zzzznotafood"))
    }

    @Test("A failure surfaces the specific error, not a generic one")
    func failuresSurfaceTheError() async throws {
        let viewModel = try makeViewModel(ScriptedService([.failure(APIError.serviceUnavailable)]))

        viewModel.query = "oat"
        await viewModel.searchDebounced()

        #expect(viewModel.phase == .failed(.serviceUnavailable))
    }

    @Test("After a failure the identical query can be retried")
    func identicalQueryIsRetryableAfterFailure() async throws {
        // Guards against the de-duplication that skips repeat queries also blocking retry.
        let service = ScriptedService([
            .failure(APIError.serviceUnavailable),
            .success(SearchPage(products: [try product("1", "Oat Drink")], page: 1, totalCount: 1, hasMorePages: false)),
        ])
        let viewModel = try makeViewModel(service)

        viewModel.query = "oat"
        await viewModel.searchDebounced()
        #expect(viewModel.phase == .failed(.serviceUnavailable))

        await viewModel.searchNow()

        guard case .results(let shown, _) = viewModel.phase else {
            Issue.record("retry did not produce results, got \(viewModel.phase)")
            return
        }
        #expect(shown.count == 1)
        #expect(service.callCount == 2)
    }

    @Test("Repeating a search already on screen does not refetch")
    func identicalQueryIsNotRefetched() async throws {
        let service = ScriptedService(products: [try product("1", "Oat Drink")])
        let viewModel = try makeViewModel(service)

        viewModel.query = "oat"
        await viewModel.searchDebounced()
        await viewModel.searchDebounced()   // e.g. the view reappearing

        #expect(service.callCount == 1)
    }

    @Test("A superseded search is cancelled before it is ever sent")
    func debounceCancelsSupersededSearches() async throws {
        let service = ScriptedService(products: [try product("1", "Oat Drink")])
        let viewModel = try makeViewModel(service)

        viewModel.query = "oat milk"
        let task = Task { await viewModel.searchDebounced() }
        task.cancel()                       // stands in for the next keystroke
        await task.value

        #expect(service.callCount == 0)
        #expect(viewModel.phase == .idle)
    }

    @Test("Paging appends the next page and de-duplicates repeated barcodes")
    func paginationDeduplicates() async throws {
        let first = [try product("1", "A"), try product("2", "B"), try product("3", "C")]
        // The API genuinely repeats products across page boundaries.
        let second = [try product("3", "C"), try product("4", "D")]

        let service = ScriptedService([
            .success(SearchPage(products: first, page: 1, totalCount: 5, hasMorePages: true)),
            .success(SearchPage(products: second, page: 2, totalCount: 5, hasMorePages: false)),
        ])
        let viewModel = try makeViewModel(service)

        viewModel.query = "oat"
        await viewModel.searchDebounced()
        await viewModel.loadMoreIfNeeded(after: first[2])

        guard case .results(let shown, _) = viewModel.phase else {
            Issue.record("expected results, got \(viewModel.phase)")
            return
        }
        #expect(shown.map(\.code) == ["1", "2", "3", "4"])   // "3" appears once
        #expect(service.calls.last?.page == 2)
    }

    @Test("Paging stops at the last page")
    func doesNotPageBeyondTheEnd() async throws {
        let products = [try product("1", "A")]
        let service = ScriptedService([
            .success(SearchPage(products: products, page: 1, totalCount: 1, hasMorePages: false)),
        ])
        let viewModel = try makeViewModel(service)

        viewModel.query = "oat"
        await viewModel.searchDebounced()
        await viewModel.loadMoreIfNeeded(after: products[0])

        #expect(service.callCount == 1)
    }

    @Test("A failed page keeps the results already on screen")
    func pageFailureDoesNotDiscardResults() async throws {
        let first = [try product("1", "A"), try product("2", "B")]
        let service = ScriptedService([
            .success(SearchPage(products: first, page: 1, totalCount: 9, hasMorePages: true)),
            .failure(APIError.serviceUnavailable),
        ])
        let viewModel = try makeViewModel(service)

        viewModel.query = "oat"
        await viewModel.searchDebounced()
        await viewModel.loadMoreIfNeeded(after: first[1])

        guard case .results(let shown, _) = viewModel.phase else {
            Issue.record("results were discarded on a failed page: \(viewModel.phase)")
            return
        }
        #expect(shown.count == 2)
    }
}
