import Foundation

/// Runs a primary backend and falls back to a second when the primary is unavailable.
///
/// The assignment names `cgi/search.pl` as the endpoint, so it stays primary — but it
/// fails often enough that treating it as the only option would make the app feel broken
/// through no fault of its own. Search-a-licious catches those failures.
///
/// Only *availability* failures fall through. A malformed response or a 404 means the
/// primary answered and the answer was bad; retrying elsewhere would just hide a real
/// problem behind a second request.
struct FallbackFoodFactsService: FoodFactsService {
    let primary: FoodFactsService
    let fallback: FoodFactsService

    func search(_ query: String, page: Int) async throws -> SearchPage {
        do {
            return try await primary.search(query, page: page)
        } catch let error as APIError where error.isWorthFallingBackFrom {
            return try await fallback.search(query, page: page)
        }
    }

    func product(barcode: String) async throws -> Product? {
        do {
            return try await primary.product(barcode: barcode)
        } catch let error as APIError where error.isWorthFallingBackFrom {
            return try await fallback.product(barcode: barcode)
        }
    }
}

extension APIError {
    /// Whether a second backend is worth trying. Being offline is not the endpoint's
    /// fault, and a second request would fail identically.
    var isWorthFallingBackFrom: Bool {
        switch self {
        case .serviceUnavailable, .timedOut, .rateLimited: true
        case .offline, .unreadableResponse, .unexpected: false
        }
    }
}
