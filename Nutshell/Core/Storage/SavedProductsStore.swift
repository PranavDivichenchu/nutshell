import Foundation
import Observation

/// The user's saved products, held in memory and mirrored to a JSON file on disk.
///
/// Saving keeps the whole `Product`, not just its barcode, so the saved list stays
/// browsable offline and never depends on the API being reachable.
@Observable
@MainActor
final class SavedProductsStore {
    private(set) var products: [Product] = []

    /// Barcodes, kept alongside the array so membership checks in list rows stay O(1).
    private var savedCodes: Set<String> = []

    private let fileURL: URL

    init(fileURL: URL = .savedProducts) {
        self.fileURL = fileURL
        load()
    }

    func contains(_ product: Product) -> Bool {
        savedCodes.contains(product.code)
    }

    /// Adds the product, or removes it if already saved. Returns the resulting state.
    @discardableResult
    func toggle(_ product: Product) -> Bool {
        if savedCodes.contains(product.code) {
            products.removeAll { $0.code == product.code }
            savedCodes.remove(product.code)
        } else {
            // Most recently saved first — the order people expect from a saved list.
            products.insert(product, at: 0)
            savedCodes.insert(product.code)
        }
        persist()
        return savedCodes.contains(product.code)
    }

    func remove(atOffsets offsets: IndexSet) {
        for index in offsets { savedCodes.remove(products[index].code) }
        products.remove(atOffsets: offsets)
        persist()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Product].self, from: data) else { return }
        products = decoded
        savedCodes = Set(decoded.map(\.code))
    }

    private func persist() {
        let snapshot = products
        let url = fileURL
        // Writing is fire-and-forget: the in-memory list is the source of truth for the
        // UI, and a failed write only costs this change on next launch.
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
    static var savedProducts: URL {
        URL.applicationSupportDirectory.appending(path: "saved-products.json")
    }
}
