import SwiftUI

/// The floating tray that collects products queued for comparison.
///
/// It only exists while something is selected, so it costs nothing when unused — and it
/// makes the half-finished state of "I picked one, now pick another" visible instead of
/// hiding it behind a mode.
struct CompareTray: View {
    @Environment(CompareStore.self) private var compare
    @Binding var isShowingComparison: Bool

    var body: some View {
        if !compare.products.isEmpty {
            HStack(spacing: Theme.Spacing.small) {
                HStack(spacing: -10) {
                    ForEach(compare.products) { product in
                        ProductImage(url: product.thumbnailURL, cornerRadius: 8)
                            .frame(width: 34, height: 34)
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Theme.surface, lineWidth: 2)
                            }
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(compare.products.count) selected")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                    Text(compare.canCompare ? "Ready to compare" : "Pick one more")
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer(minLength: 0)

                Button("Clear") { compare.clear() }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.secondaryText)

                Button {
                    isShowingComparison = true
                } label: {
                    Text("Compare")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(compare.canCompare ? Theme.accent : Theme.secondaryText.opacity(0.4), in: .capsule)
                }
                .disabled(!compare.canCompare)
            }
            .padding(.horizontal, Theme.Spacing.medium)
            .padding(.vertical, Theme.Spacing.small)
            .background(.regularMaterial, in: .capsule)
            .overlay { Capsule().strokeBorder(Theme.separator, lineWidth: 1) }
            .padding(.horizontal, Theme.Spacing.medium)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.snappy, value: compare.products.count)
        }
    }
}

/// Adds "Save" and "Compare" to any product row, in both swipe and long-press form so the
/// action is discoverable rather than hidden behind a gesture people have to guess.
struct ProductRowActions: ViewModifier {
    let product: Product

    @Environment(SavedProductsStore.self) private var saved
    @Environment(CompareStore.self) private var compare

    func body(content: Content) -> some View {
        let isSaved = saved.contains(product)
        let isComparing = compare.contains(product)

        content
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button { saved.toggle(product) } label: {
                    Label(isSaved ? "Remove" : "Save",
                          systemImage: isSaved ? "bookmark.slash.fill" : "bookmark.fill")
                }
                .tint(isSaved ? .gray : Theme.accent)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button { compare.toggle(product) } label: {
                    Label(isComparing ? "Remove" : "Compare",
                          systemImage: isComparing ? "minus.circle" : "square.on.square")
                }
                .tint(Color(hex: 0x4C6EF5))
                .disabled(!isComparing && compare.isFull)
            }
            .contextMenu {
                Button {
                    saved.toggle(product)
                } label: {
                    Label(isSaved ? "Remove from saved" : "Save",
                          systemImage: isSaved ? "bookmark.slash" : "bookmark")
                }
                Button {
                    compare.toggle(product)
                } label: {
                    Label(isComparing ? "Remove from compare" : "Add to compare",
                          systemImage: "square.on.square")
                }
                .disabled(!isComparing && compare.isFull)
            }
    }
}

extension View {
    func productRowActions(for product: Product) -> some View {
        modifier(ProductRowActions(product: product))
    }
}
