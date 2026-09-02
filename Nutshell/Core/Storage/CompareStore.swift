import Foundation
import Observation

/// The products currently queued up for side-by-side comparison.
///
/// Deliberately NOT persisted: comparing is something you do for thirty seconds in front
/// of a shelf, and finding yesterday's comparison still loaded would be noise.
@Observable
@MainActor
final class CompareStore {
    /// Three columns is what fits on a phone before the numbers stop being readable.
    static let maximum = 3

    private(set) var products: [Product] = []

    var isFull: Bool { products.count >= Self.maximum }
    var canCompare: Bool { products.count >= 2 }

    func contains(_ product: Product) -> Bool {
        products.contains { $0.code == product.code }
    }

    /// - Returns: whether the product is in the tray afterwards.
    @discardableResult
    func toggle(_ product: Product) -> Bool {
        if contains(product) {
            products.removeAll { $0.code == product.code }
            return false
        }
        guard !isFull else { return false }
        products.append(product)
        return true
    }

    func remove(_ product: Product) {
        products.removeAll { $0.code == product.code }
    }

    func clear() { products.removeAll() }
}
