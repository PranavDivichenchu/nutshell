import Foundation

/// One page of search results, plus the cursor state needed to fetch the next.
struct SearchPage: Sendable, Equatable {
    let products: [Product]
    let page: Int
    let totalCount: Int
    let hasMorePages: Bool

    static let empty = SearchPage(products: [], page: 1, totalCount: 0, hasMorePages: false)
}

/// The raw envelope the search endpoint wraps its results in.
struct SearchResponse: Decodable {
    let products: [Product]
    let count: LenientInt?
    let page: LenientInt?
    let pageCount: LenientInt?
    let pageSize: LenientInt?

    enum CodingKeys: String, CodingKey {
        case products, count, page
        case pageCount = "page_count"
        case pageSize = "page_size"
    }
}

/// The envelope the v2 single-product endpoint wraps one product in.
struct ProductResponse: Decodable {
    let product: Product?
    let status: LenientInt?
}
