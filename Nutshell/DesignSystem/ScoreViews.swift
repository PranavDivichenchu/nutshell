import SwiftUI

/// One cell of a grade scale.
///
/// Every swatch keeps its full colour and its own readable glyph colour; the selected
/// one is larger and ringed. An earlier version dimmed the unselected fills and drew
/// white on top of them, which measured as low as 1.14:1 — effectively invisible.
private struct GradeSwatch: View {
    let text: String
    let fill: Color
    let foreground: Color
    let isActive: Bool

    @ScaledMetric(relativeTo: .headline) private var scale: CGFloat = 1

    var body: some View {
        Text(text)
            .font(.system(size: (isActive ? 22 : 15) * scale, weight: .heavy, design: .rounded))
            .foregroundStyle(foreground)
            .frame(width: (isActive ? 44 : 32) * scale, height: (isActive ? 52 : 38) * scale)
            .background(fill.opacity(isActive ? 1 : 0.55), in: .rect(cornerRadius: 10))
            .overlay {
                if isActive {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Theme.primaryText.opacity(0.55), lineWidth: 2)
                }
            }
            .accessibilityHidden(true)
    }
}

/// The compact Nutri-Score letter tile used in list rows.
struct NutriScoreTile: View {
    let score: NutriScore
    var baseSize: CGFloat = 28

    /// The grade is the densest signal in a row, so it has to grow with Dynamic Type
    /// like everything around it rather than staying pinned at one size.
    @ScaledMetric(relativeTo: .headline) private var scale: CGFloat = 1

    private var size: CGFloat { baseSize * scale }

    var body: some View {
        Text(score.letter)
            .font(.system(size: size * 0.6, weight: .heavy, design: .rounded))
            .foregroundStyle(score.onColor)
            .frame(width: size, height: size)
            .background(score.color, in: .rect(cornerRadius: size * 0.28))
            .accessibilityLabel("Nutri-Score \(score.letter)")
    }
}

/// The full A–E Nutri-Score scale with the product's grade raised out of the strip.
///
/// Reproducing the on-pack visual rather than inventing a new one means people who
/// already recognise Nutri-Score don't have to learn anything to read this screen.
struct NutriScoreScale: View {
    let score: NutriScore

    var body: some View {
        HStack(spacing: 4) {
            ForEach(NutriScore.allCases) { grade in
                GradeSwatch(
                    text: grade.letter,
                    fill: grade.color,
                    foreground: grade.onColor,
                    isActive: grade == score
                )
            }
        }
        .animation(.snappy, value: score)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Nutri-Score \(score.letter). \(score.summary)")
    }
}

/// The four-step NOVA processing scale.
struct NovaScale: View {
    let group: NovaGroup

    var body: some View {
        HStack(spacing: 4) {
            ForEach(NovaGroup.allCases) { candidate in
                GradeSwatch(
                    text: "\(candidate.rawValue)",
                    fill: candidate.color,
                    foreground: candidate.onColor,
                    isActive: candidate == group
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("NOVA group \(group.rawValue) of 4. \(group.title). \(group.summary)")
    }
}

/// The five-step environmental impact scale.
struct EcoScoreScale: View {
    let score: EcoScore

    var body: some View {
        HStack(spacing: 4) {
            ForEach(EcoScore.allCases) { grade in
                GradeSwatch(
                    text: grade.letter,
                    fill: grade.color,
                    foreground: grade.onColor,
                    isActive: grade == score
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Eco-Score \(score.letter). \(score.summary)")
    }
}

/// A grade card: the scale itself, then a plain-language reading of it.
///
/// Generic over its scale rather than taking an `AnyView`, so each score keeps its own
/// concrete view type and SwiftUI can still diff it.
struct ScoreExplainerCard<Scale: View>: View {
    let title: String
    let headline: String
    let detail: String
    let tint: Color
    @ViewBuilder let scale: Scale

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                Text(title)
                    .font(.display(.caption, weight: .bold))
                    .textCase(.uppercase)
                    .kerning(0.6)
                    .foregroundStyle(Theme.secondaryText)

                scale

                VStack(alignment: .leading, spacing: 2) {
                    Text(headline)
                        // The raw score colours are chosen to sit under a glyph, not on
                        // the page — the yellows fail badly as text in light mode.
                        .font(.display(.headline))
                        .foregroundStyle(Theme.primaryText)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        // One sentence rather than the grade announced once per swatch.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(headline). \(detail)")
    }
}

/// A single traffic-light nutrient reading, e.g. "Sugars — High — 34 g".
struct NutrientLevelRow: View {
    let nutrient: Nutrient
    let level: NutrientLevel
    let amount: String?

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // At accessibility sizes the three columns cannot coexist on one line, so they
        // stack rather than each truncating to a fragment.
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: Theme.Spacing.small) {
                    levelDot
                    Text(nutrient.label)
                        .font(.subheadline)
                        .foregroundStyle(Theme.primaryText)
                }
                HStack(spacing: Theme.Spacing.small) {
                    if let amount {
                        Text(amount)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(Theme.secondaryText)
                    }
                    levelTag
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
        } else {
            compactBody
        }
    }

    private var levelDot: some View {
        Circle()
            .fill(level.color)
            .frame(width: 12, height: 12)
            .overlay { Circle().strokeBorder(level.color.opacity(0.3), lineWidth: 4) }
            .accessibilityHidden(true)
    }

    private var levelTag: some View {
        Text(level.label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(level.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(level.color.opacity(0.12), in: .capsule)
    }

    private var accessibilityText: String {
        "\(nutrient.label): \(level.label)\(amount.map { ", \($0)" } ?? "")"
    }

    private var compactBody: some View {
        HStack(spacing: Theme.Spacing.small) {
            levelDot

            Text(nutrient.label)
                .font(.subheadline)
                .foregroundStyle(Theme.primaryText)

            Spacer(minLength: Theme.Spacing.small)

            if let amount {
                Text(amount)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Theme.secondaryText)
            }

            levelTag
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }
}
