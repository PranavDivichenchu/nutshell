import Foundation

/// Client for Search-a-licious, the full-text search backend Open Food Facts now
/// recommends over the legacy `cgi/search.pl` CGI.
///
/// It exists because the legacy endpoint is genuinely unreliable — measured over this
/// project, roughly one request in three comes back as a 503 HTML maintenance page,
/// including requests it served seconds earlier. Search-a-licious answered every probe
/// in well under a second.
///
/// The trade is coverage: its index carries names, brands, images, scores, nutriments,
/// and allergens — everything a result row and a dietary verdict need — but not
/// ingredient text, quantities, or additives. So it backs the *list*, and the detail
/// screen tops a product up by barcode from the v2 endpoint.
struct SearchALiciousClient: FoodFactsService {
    static let pageSize = 20

    private static let userAgent = "Nutshell/1.0 (iOS; github.com/pranavdivichenchu)"

    /// Only fields this index actually holds. Asking for others silently returns nothing.
    private static let fields = [
        "code", "product_name", "product_name_en", "generic_name", "generic_name_en",
        "brands", "image_front_url", "image_front_small_url",
        "nutriscore_grade", "ecoscore_grade", "nova_group",
        "allergens_tags", "ingredients_analysis_tags", "categories_tags",
        "nutrient_levels", "nutriments",
    ].joined(separator: ",")

    private let session: URLSession
    /// Barcode lookups go to v2 either way; there is no point reimplementing them.
    private let productLookup: OpenFoodFactsClient

    init(session: URLSession = .foodFacts) {
        self.session = session
        self.productLookup = OpenFoodFactsClient(session: session)
    }

    func product(barcode: String) async throws -> Product? {
        try await productLookup.product(barcode: barcode)
    }

    func search(_ query: String, page: Int) async throws -> SearchPage {
        var components = URLComponents(string: "https://search.openfoodfacts.org/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: String(Self.pageSize)),
            URLQueryItem(name: "fields", value: Self.fields),
        ]
        guard let url = components.url else { throw APIError.unreadableResponse }

        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw OpenFoodFactsClient.mapped(error)
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.unreadableResponse }
        switch http.statusCode {
        case 200...299: break
        case 429: throw APIError.rateLimited
        case 500...599: throw APIError.serviceUnavailable
        default: throw APIError.unexpected(statusCode: http.statusCode)
        }

        let decoded: SearchALiciousResponse
        do {
            decoded = try JSONDecoder().decode(SearchALiciousResponse.self, from: data)
        } catch {
            throw APIError.unreadableResponse
        }

        let usable = decoded.hits.filter(\.hasName)
        let currentPage = decoded.page?.value ?? page
        // Unlike the legacy endpoint, this `page_count` really is a count of pages.
        let hasMore = (decoded.pageCount?.value).map { currentPage < $0 }
            ?? (decoded.hits.count >= Self.pageSize)

        return SearchPage(
            products: usable,
            page: currentPage,
            totalCount: decoded.count?.value ?? usable.count,
            hasMorePages: hasMore
        )
    }
}

/// Search-a-licious returns its results under `hits` rather than `products`.
struct SearchALiciousResponse: Decodable {
    let hits: [Product]
    let count: LenientInt?
    let page: LenientInt?
    let pageCount: LenientInt?

    enum CodingKeys: String, CodingKey {
        case hits, count, page
        case pageCount = "page_count"
    }
}
