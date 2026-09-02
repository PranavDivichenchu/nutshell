import Foundation

/// The app's dependency on Open Food Facts, expressed as a protocol so that views,
/// previews, and tests can run against canned data without touching the network.
protocol FoodFactsService: Sendable {
    /// - Parameter page: 1-indexed, matching the API's own paging.
    /// - Throws: `APIError` for anything presentable, `CancellationError` when superseded.
    func search(_ query: String, page: Int) async throws -> SearchPage
}
