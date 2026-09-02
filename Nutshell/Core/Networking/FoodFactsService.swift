import SwiftUI

/// The app's dependency on Open Food Facts, expressed as a protocol so that views,
/// previews, and tests can run against canned data without touching the network.
protocol FoodFactsService: Sendable {
    /// - Parameter page: 1-indexed, matching the API's own paging.
    /// - Throws: `APIError` for anything presentable, `CancellationError` when superseded.
    func search(_ query: ProductQuery, page: Int) async throws -> SearchPage

    /// Looks up a single product by barcode.
    /// - Returns: `nil` when the barcode is well-formed but absent from the database,
    ///   which is a normal outcome worth distinguishing from an error.
    func product(barcode: String) async throws -> Product?
}

// MARK: - Environment

private struct FoodFactsServiceKey: EnvironmentKey {
    static let defaultValue: FoodFactsService = OpenFoodFactsClient()
}

extension EnvironmentValues {
    /// Lets a detail screen top up a partial record without threading the client
    /// through every intermediate view.
    var foodFactsService: FoodFactsService {
        get { self[FoodFactsServiceKey.self] }
        set { self[FoodFactsServiceKey.self] = newValue }
    }
}
