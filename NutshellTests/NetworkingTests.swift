import Testing
import Foundation
@testable import Nutshell

/// Serves a scripted queue of responses so the client's behaviour against the failures
/// Open Food Facts actually produces can be tested without touching the network.
final class StubURLProtocol: URLProtocol {

    struct Stub {
        var status: Int = 200
        var body: Data
        var headers: [String: String] = ["Content-Type": "application/json"]

        static func json(_ string: String, status: Int = 200) -> Stub {
            Stub(status: status, body: Data(string.utf8))
        }

        /// What the endpoint really returns when it is overloaded: an HTML page,
        /// sometimes with a 200.
        static func maintenanceHTML(status: Int = 503) -> Stub {
            Stub(
                status: status,
                body: Data("<!DOCTYPE html><html><head><title>Page temporarily unavailable</title></head></html>".utf8),
                headers: ["Content-Type": "text/html"]
            )
        }
    }

    private static let lock = NSLock()
    private static var queue: [Stub] = []
    private static var recorded: [URLRequest] = []

    static func script(_ stubs: [Stub]) {
        lock.lock(); defer { lock.unlock() }
        queue = stubs
        recorded = []
    }

    static var requests: [URLRequest] {
        lock.lock(); defer { lock.unlock() }
        return recorded
    }

    private static func next(for request: URLRequest) -> Stub {
        lock.lock(); defer { lock.unlock() }
        recorded.append(request)
        // The last stub repeats, so a test needn't script every retry.
        return queue.count > 1 ? queue.removeFirst() : (queue.first ?? .json("{}"))
    }

    /// A session that answers only from the script above.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let stub = Self.next(for: request)
        let response = HTTPURLResponse(
            url: request.url!, statusCode: stub.status, httpVersion: "HTTP/1.1", headerFields: stub.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }
}

@Suite("Open Food Facts client", .serialized)
struct OpenFoodFactsClientTests {

    private func makeClient() -> OpenFoodFactsClient {
        OpenFoodFactsClient(session: StubURLProtocol.makeSession())
    }

    private static let twoProducts = """
    {"count": 42, "page": 1, "page_count": 3, "page_size": 20,
     "products": [
       {"code":"1","product_name":"Oat Drink","brands":"Oatly","nutriscore_grade":"d","nova_group":3},
       {"code":"2","product_name":"Oat Milk","brands":"Alpro","nutriscore_grade":"c"}
     ]}
    """

    @Test("A healthy response decodes into a page with cursor state")
    func decodesPage() async throws {
        StubURLProtocol.script([.json(Self.twoProducts)])

        let page = try await makeClient().search(.text("oat"), page: 1)

        #expect(page.products.count == 2)
        #expect(page.totalCount == 42)
        #expect(page.page == 1)
        #expect(page.hasMorePages)               // page 1 of 3
        #expect(page.products.first?.name == "Oat Drink")
    }

    @Test("The last page reports no more pages")
    func lastPage() async throws {
        StubURLProtocol.script([.json("""
        {"count": 42, "page": 3, "page_count": 3, "products":
          [{"code":"9","product_name":"Last"}]}
        """)])

        let page = try await makeClient().search(.text("oat"), page: 3)
        #expect(page.hasMorePages == false)
    }

    @Test("Records with no name are dropped before they reach the UI")
    func filtersUnnamedProducts() async throws {
        StubURLProtocol.script([.json("""
        {"count": 3, "page": 1, "page_count": 1, "products": [
          {"code":"1","product_name":"Real Product"},
          {"code":"2","product_name":""},
          {"code":"3"}
        ]}
        """)])

        let page = try await makeClient().search(.text("oat"), page: 1)

        #expect(page.products.count == 1)
        #expect(page.products.first?.code == "1")
        // The API's own count is preserved — it describes the query, not the filtered page.
        #expect(page.totalCount == 3)
    }

    @Test("An HTML maintenance page served with a 200 is not mistaken for data")
    func rejectsHTMLBodyWithSuccessStatus() async {
        StubURLProtocol.script([.maintenanceHTML(status: 200)])

        await #expect(throws: APIError.serviceUnavailable) {
            try await makeClient().search(.text("oat"), page: 1)
        }
    }

    @Test("A transient 503 is retried, and the retry's data is returned")
    func retriesTransientFailure() async throws {
        // This is the endpoint's normal behaviour: fail, then succeed on the same request.
        StubURLProtocol.script([
            .maintenanceHTML(status: 503),
            .json(Self.twoProducts),
        ])

        let page = try await makeClient().search(.text("oat"), page: 1)

        #expect(page.products.count == 2)
        #expect(StubURLProtocol.requests.count == 2)   // it really did retry
    }

    @Test("Retries are bounded, and a persistent outage surfaces as an error")
    func retriesAreBounded() async {
        StubURLProtocol.script([.maintenanceHTML(status: 503)])

        await #expect(throws: APIError.serviceUnavailable) {
            try await makeClient().search(.text("oat"), page: 1)
        }
        // One initial attempt plus two retries — not an unbounded loop.
        #expect(StubURLProtocol.requests.count == 3)
    }

    @Test("A client error is reported as-is and never retried")
    func doesNotRetryClientErrors() async {
        StubURLProtocol.script([.json("{}", status: 404)])

        await #expect(throws: APIError.unexpected(statusCode: 404)) {
            try await makeClient().search(.text("oat"), page: 1)
        }
        #expect(StubURLProtocol.requests.count == 1)   // retrying a 404 would be pointless
    }

    @Test("Malformed JSON is reported as unreadable, not as an outage")
    func malformedJSON() async {
        StubURLProtocol.script([.json(#"{"products": "not an array"}"#)])

        await #expect(throws: APIError.unreadableResponse) {
            try await makeClient().search(.text("oat"), page: 1)
        }
        #expect(StubURLProtocol.requests.count == 1)
    }

    @Test("The request carries the query, paging, field projection and a User-Agent")
    func requestShape() async throws {
        StubURLProtocol.script([.json(Self.twoProducts)])
        _ = try await makeClient().search(.text("dark chocolate"), page: 2)

        let request = try #require(StubURLProtocol.requests.first)
        let url = try #require(request.url?.absoluteString)
        let components = try #require(URLComponents(string: url))
        let items = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        )

        #expect(items["search_terms"] == "dark chocolate")
        #expect(items["json"] == "1")
        #expect(items["page"] == "2")
        #expect(items["page_size"] == "20")
        // Without the projection a page is ~1 MB instead of ~3 KB.
        #expect(items["fields"]?.contains("nutriments") == true)
        #expect(items["fields"]?.contains("nutriscore_grade") == true)
        // Open Food Facts throttles clients that don't identify themselves.
        #expect(request.value(forHTTPHeaderField: "User-Agent")?.isEmpty == false)
    }

    @Test("A category is sent as a tag filter, not as free text")
    func categoryQueryShape() async throws {
        StubURLProtocol.script([.json(Self.twoProducts)])
        _ = try await makeClient().search(.category("en:breakfast-cereals"), page: 1)

        let request = try #require(StubURLProtocol.requests.first)
        let url = try #require(request.url?.absoluteString)
        let components = try #require(URLComponents(string: url))
        let items = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        )

        // Searching the word "cereal" returns cereal bars and oatmeal cookies; filtering
        // the category returns the category. These must not be the same request.
        #expect(items["search_terms"] == nil)
        #expect(items["tagtype_0"] == "categories")
        #expect(items["tag_contains_0"] == "contains")
        // The legacy endpoint wants the slug without its language prefix.
        #expect(items["tag_0"] == "breakfast-cereals")
    }

    @Test("Every browse category carries a language-prefixed tag")
    func browseCategoriesAreWellFormed() {
        #expect(BrowseCategory.all.isEmpty == false)
        for category in BrowseCategory.all {
            #expect(category.tag.hasPrefix("en:"), "\(category.name) tag \(category.tag)")
            #expect(category.name.isEmpty == false)
            #expect(Tag.slug(from: category.tag).isEmpty == false)
        }
        // Tags must be unique, or two tiles would open the same list.
        #expect(Set(BrowseCategory.all.map(\.tag)).count == BrowseCategory.all.count)
    }

    @Test("Only genuinely transient failures are marked retryable")
    func transienceClassification() {
        #expect(APIError.serviceUnavailable.isTransient)
        #expect(APIError.timedOut.isTransient)
        #expect(APIError.offline.isTransient == false)
        #expect(APIError.unreadableResponse.isTransient == false)
        #expect(APIError.unexpected(statusCode: 404).isTransient == false)
    }

    @Test("Every error can explain itself to the user")
    func errorsArePresentable() {
        let errors: [APIError] = [
            .offline, .serviceUnavailable, .unreadableResponse, .timedOut, .unexpected(statusCode: 500),
        ]
        for error in errors {
            #expect(error.errorDescription?.isEmpty == false)
            #expect(error.recoverySuggestion?.isEmpty == false)
            #expect(error.systemImage.isEmpty == false)
        }
    }
}
