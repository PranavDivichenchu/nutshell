import Foundation

/// Live client for the Open Food Facts search endpoint.
struct OpenFoodFactsClient: FoodFactsService {
    static let pageSize = 20

    /// Open Food Facts asks every client to identify itself, and throttles those that don't.
    private static let userAgent = "Nutshell/1.0 (iOS; github.com/pranavdivichenchu)"

    /// A product record carries ~200 keys, most of them OCR debris and scoring
    /// internals. Requesting only what the UI renders cuts a 20-result page from
    /// roughly 1 MB to under 100 KB, which is the single biggest win available here.
    private static let fields = [
        "code", "product_name", "generic_name", "brands", "quantity", "serving_size",
        "ingredients_text", "image_front_url", "image_front_small_url",
        "nutriscore_grade", "ecoscore_grade", "nova_group",
        "allergens_tags", "traces_tags", "additives_tags", "labels_tags", "categories_tags",
        "ingredients_analysis_tags", "nutrient_levels", "nutriments", "nutrition_data_per",
    ].joined(separator: ",")

    /// The search endpoint fails intermittently under its own load, answering roughly
    /// one request in three with a 503 HTML page — including requests it served
    /// seconds earlier. Since this is a GET, retrying is safe, and two short retries
    /// turn most of those failures into results instead of an error screen.
    private static let retryDelays: [Duration] = [.milliseconds(500), .milliseconds(1200)]

    private let session: URLSession

    init(session: URLSession = .foodFacts) {
        self.session = session
    }

    func search(_ query: String, page: Int) async throws -> SearchPage {
        let request = try Self.makeRequest(query: query, page: page)
        var attempt = 0

        while true {
            do {
                return try await fetchPage(request, requestedPage: page)
            } catch let error as APIError where error.isTransient && attempt < Self.retryDelays.count {
                // Cancellation during the backoff propagates, abandoning a stale search.
                try await Task.sleep(for: Self.retryDelays[attempt])
                attempt += 1
            }
        }
    }

    /// Looks a product up by barcode.
    ///
    /// This deliberately uses the v2 product endpoint rather than the search endpoint the
    /// rest of the app uses. v2 resolves a barcode directly and is markedly more reliable
    /// than `cgi/search.pl`, which is the piece of infrastructure that 503s constantly —
    /// and a scanner that fails a third of the time is not a scanner.
    func product(barcode: String) async throws -> Product? {
        let digits = barcode.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }

        var components = URLComponents(string: "https://world.openfoodfacts.org/api/v2/product/\(digits).json")!
        components.queryItems = [URLQueryItem(name: "fields", value: Self.fields)]
        guard let url = components.url else { throw APIError.unreadableResponse }

        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        var attempt = 0
        while true {
            do {
                return try await fetchProduct(request)
            } catch let error as APIError where error.isTransient && attempt < Self.retryDelays.count {
                try await Task.sleep(for: Self.retryDelays[attempt])
                attempt += 1
            }
        }
    }

    private func fetchProduct(_ request: URLRequest) async throws -> Product? {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw Self.mapped(error)
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.unreadableResponse }
        switch http.statusCode {
        // v2 answers 404 for an unknown barcode, which is an answer, not a failure.
        case 404: return nil
        case 200...299: break
        case 429, 500...599: throw APIError.serviceUnavailable
        default: throw APIError.unexpected(statusCode: http.statusCode)
        }

        guard data.looksLikeJSON else { throw APIError.serviceUnavailable }

        do {
            let envelope = try JSONDecoder().decode(ProductResponse.self, from: data)
            // status 0 means "product not found" even under a 200.
            guard envelope.status?.value != 0, let product = envelope.product, product.hasName else { return nil }
            return product
        } catch {
            throw APIError.unreadableResponse
        }
    }

    private func fetchPage(_ request: URLRequest, requestedPage page: Int) async throws -> SearchPage {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw Self.mapped(error)
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.unreadableResponse }
        switch http.statusCode {
        case 200...299: break
        case 429, 500...599: throw APIError.serviceUnavailable
        default: throw APIError.unexpected(statusCode: http.statusCode)
        }

        // Under load the endpoint answers 200 with an HTML maintenance page, so the
        // status code alone isn't enough to trust the body.
        guard data.looksLikeJSON else { throw APIError.serviceUnavailable }

        let decoded: SearchResponse
        do {
            decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        } catch {
            throw APIError.unreadableResponse
        }

        return Self.makePage(from: decoded, requestedPage: page)
    }

    // MARK: - Request building

    private static func makeRequest(query: String, page: Int) throws -> URLRequest {
        var components = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")!
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: String(pageSize)),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "fields", value: fields),
        ]
        guard let url = components.url else { throw APIError.unreadableResponse }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    // MARK: - Response shaping

    private static func makePage(from response: SearchResponse, requestedPage: Int) -> SearchPage {
        // Search matches on many fields, so it surfaces records that are little more
        // than a barcode. Those are dead ends in the UI — drop them before they reach it.
        let usable = response.products.filter(\.hasName)

        let page = response.page?.value ?? requestedPage
        let total = response.count?.value ?? usable.count
        let pageCount = response.pageCount?.value

        let hasMore = if let pageCount {
            page < pageCount
        } else {
            // Without a page count, a full page implies there is probably another.
            response.products.count >= pageSize
        }

        return SearchPage(products: usable, page: page, totalCount: total, hasMorePages: hasMore)
    }

    private static func mapped(_ error: URLError) -> Error {
        switch error.code {
        case .cancelled: CancellationError()
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed: APIError.offline
        case .timedOut: APIError.timedOut
        default: APIError.unreadableResponse
        }
    }
}

// MARK: - Session

extension URLSession {
    /// A session tuned for this API: short timeouts because the endpoint is slow when
    /// healthy and hangs when it isn't, and an on-disk cache so paging back through
    /// results — or repeating a search — costs nothing.
    static let foodFacts: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.urlCache = URLCache(
            memoryCapacity: 16 * 1024 * 1024,
            diskCapacity: 128 * 1024 * 1024
        )
        return URLSession(configuration: configuration)
    }()
}

private extension Data {
    /// Cheap sniff for a JSON body, to catch HTML error pages served with a 200.
    var looksLikeJSON: Bool {
        guard let first = first(where: { !($0 == 0x20 || $0 == 0x0A || $0 == 0x0D || $0 == 0x09) })
        else { return false }
        return first == UInt8(ascii: "{") || first == UInt8(ascii: "[")
    }
}
