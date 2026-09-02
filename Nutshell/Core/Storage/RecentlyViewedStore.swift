import Foundation
import Observation

/// The last handful of products opened, so getting back to one takes a tap rather than
/// remembering the search that found it.
@Observable
@MainActor
final class RecentlyViewedStore {
    private static let limit = 12

    private(set) var products: [Product] = []
    private let fileURL: URL

    init(fileURL: URL = .recentlyViewed) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([Product].self, from: data) {
            products = decoded
        }
    }

    /// Records a view, moving a product already in the list to the front rather than
    /// letting it appear twice.
    func record(_ product: Product) {
        products.removeAll { $0.code == product.code }
        products.insert(product, at: 0)
        if products.count > Self.limit { products.removeLast(products.count - Self.limit) }
        persist()
    }

    func clear() {
        products.removeAll()
        persist()
    }

    private func persist() {
        let snapshot = products
        let url = fileURL
        Task.detached(priority: .utility) {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try? data.write(to: url, options: .atomic)
        }
    }
}

extension URL {
    static var recentlyViewed: URL {
        URL.applicationSupportDirectory.appending(path: "recently-viewed.json")
    }
}
