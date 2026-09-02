import SwiftUI

/// Products the user bookmarked.
///
/// Saved records are stored whole rather than by barcode, so this tab works with no
/// network at all — the reason it exists is to be there in a grocery aisle.
struct SavedView: View {
    @Environment(SavedProductsStore.self) private var saved
    @Environment(CompareStore.self) private var compare
    @Environment(ProfileStore.self) private var profile

    @State private var isShowingComparison = false
    /// Owned locally so it can be forced back off when the list empties — otherwise
    /// deleting the last row leaves edit mode on with no Done button to leave it.
    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if saved.products.isEmpty {
                    StatusView(
                        systemImage: "bookmark",
                        title: "Nothing saved yet",
                        message: "Swipe a search result, or tap the bookmark on a product, to keep it here for later. Saved products work offline."
                    )
                } else {
                    List {
                        ForEach(saved.products) { product in
                            NavigationLink(value: product) {
                                ProductRow(
                                    product: product,
                                    isComparing: compare.contains(product),
                                    verdict: ProductVerdict.evaluate(product, against: profile.profile)
                                )
                            }
                            .listRowBackground(Theme.background)
                            .listRowSeparatorTint(Theme.separator)
                            .productRowActions(for: product)
                        }
                        .onDelete(perform: saved.remove(atOffsets:))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .safeAreaInset(edge: .bottom) {
                CompareTray(isShowingComparison: $isShowingComparison)
            }
            .environment(\.editMode, $editMode)
            .onChange(of: saved.products.isEmpty) { _, isEmpty in
                if isEmpty { editMode = .inactive }
            }
            .navigationTitle("Saved")
            .navigationDestination(for: Product.self) { ProductDetailView(searchResult: $0) }
            .toolbar {
                if !saved.products.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) { EditButton().tint(Theme.accent) }
                }
            }
            .sheet(isPresented: $isShowingComparison) {
                CompareView(products: compare.products)
            }
        }
    }
}
