import SwiftUI

/// One product in the results list.
///
/// The row answers the two questions a search result has to answer at a glance —
/// "is this the product I meant?" and "is it any good?" — with the photo and name
/// for the first, and the Nutri-Score tile for the second.
struct ProductRow: View {
    let product: Product
    var isSaved: Bool = false

    var body: some View {
        HStack(spacing: Theme.Spacing.medium) {
            ProductImage(url: product.thumbnailURL)
                .frame(width: 62, height: 62)

            VStack(alignment: .leading, spacing: 3) {
                Text(product.name)
                    .font(.display(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(2)

                if let subtitle = product.subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                }

                if let nova = product.novaGroup {
                    Text(nova.title)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(nova.color)
                        .padding(.top, 1)
                }
            }

            Spacer(minLength: 0)

            VStack(spacing: Theme.Spacing.tight) {
                if let score = product.nutriScore {
                    NutriScoreTile(score: score)
                } else {
                    // An explicit "no grade" marker is more honest than an empty gap,
                    // which would read as an app bug rather than as missing data.
                    Text("–")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.secondaryText.opacity(0.5))
                        .frame(width: 28, height: 28)
                        .background(Theme.surfaceRaised, in: .rect(cornerRadius: 8))
                        .accessibilityLabel("No Nutri-Score available")
                }

                if isSaved {
                    Image(systemName: "bookmark.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.accent)
                        .accessibilityLabel("Saved")
                }
            }
        }
        .padding(.vertical, Theme.Spacing.small)
        .contentShape(.rect)
    }
}
