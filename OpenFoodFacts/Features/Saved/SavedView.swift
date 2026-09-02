import SwiftUI

/// Products the user bookmarked.
///
/// Saved records are stored whole rather than by barcode, so this tab works with no
/// network at all — the reason it exists is to be there in a grocery aisle.
struct SavedView: View {
    @Environment(SavedProductsStore.self) private var saved

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if saved.products.isEmpty {
                    StatusView(
                        systemImage: "bookmark",
                        title: "Nothing saved yet",
                        message: "Swipe a search result, or tap the bookmark on a product, to keep it here for later."
                    )
                } else {
                    List {
                        ForEach(saved.products) { product in
                            NavigationLink(value: product) {
                                ProductRow(product: product)
                            }
                            .listRowBackground(Theme.background)
                            .listRowSeparatorTint(Theme.separator)
                        }
                        .onDelete(perform: saved.remove(atOffsets:))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Saved")
            .navigationDestination(for: Product.self) { ProductDetailView(product: $0) }
            .toolbar {
                if !saved.products.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) { EditButton().tint(Theme.accent) }
                }
            }
        }
    }
}
