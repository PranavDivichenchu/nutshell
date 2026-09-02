import SwiftUI

/// A product as a small card, for the horizontal shelves on the home screen.
struct ProductCard: View {
    let product: Product
    var verdict: ProductVerdict?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
            ProductImage(url: product.thumbnailURL)
                .frame(width: 116, height: 116)
                .overlay(alignment: .topTrailing) {
                    if let verdict {
                        Image(systemName: verdict.level.systemImage)
                            .font(.caption)
                            .foregroundStyle(verdict.level.tint)
                            .padding(5)
                            .background(Theme.surface, in: .circle)
                            .padding(5)
                    }
                }

            Text(product.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            HStack(spacing: 5) {
                if let score = product.nutriScore {
                    NutriScoreTile(score: score, size: 18)
                }
                if let brand = product.brand {
                    Text(brand)
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .frame(width: 116)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
