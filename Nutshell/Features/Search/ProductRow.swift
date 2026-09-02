import SwiftUI

/// One product in a results list.
///
/// The row answers three questions at a glance, in the order people ask them: is this the
/// product I meant (photo, name, brand), is it any good (Nutri-Score, processing), and —
/// once a profile is set — is it right for *me* (the verdict marker).
struct ProductRow: View {
    let product: Product
    var isSaved: Bool = false
    var isComparing: Bool = false
    var verdict: ProductVerdict?

    /// The thumbnail and grade tile are fixed sizes in a fixed-width row; without
    /// scaling they crowd the text off the row entirely at accessibility sizes.
    @ScaledMetric(relativeTo: .subheadline) private var thumbnail: CGFloat = 62

    var body: some View {
        HStack(spacing: Theme.Spacing.medium) {
            ProductImage(url: product.thumbnailURL)
                .frame(width: thumbnail, height: thumbnail)

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

                HStack(spacing: Theme.Spacing.tight) {
                    if let nova = product.novaGroup {
                        Text(nova.title)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(nova.color)
                    }
                    if let verdict, verdict.level != .match {
                        HStack(spacing: 3) {
                            VerdictBadge(verdict: verdict)
                            if let first = verdict.reasons.first {
                                Text(first.text)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(verdict.level.tint)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding(.top, 1)
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
                        .foregroundStyle(Theme.tertiaryText)
                        .frame(width: 28, height: 28)
                        .background(Theme.surfaceRaised, in: .rect(cornerRadius: 8))
                        .accessibilityLabel("No Nutri-Score available")
                }

                HStack(spacing: 3) {
                    if isSaved {
                        Image(systemName: "bookmark.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.accent)
                            .accessibilityLabel("Saved")
                    }
                    if isComparing {
                        Image(systemName: "square.on.square.fill")
                            .font(.caption2)
                            .foregroundStyle(Color(hex: 0x4C6EF5))
                            .accessibilityLabel("In compare")
                    }
                }
            }
        }
        .padding(.vertical, Theme.Spacing.small)
        .contentShape(.rect)
    }
}
