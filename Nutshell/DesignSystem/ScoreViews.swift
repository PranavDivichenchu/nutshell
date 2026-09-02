import SwiftUI

/// The compact Nutri-Score letter tile used in list rows.
struct NutriScoreTile: View {
    let score: NutriScore
    var size: CGFloat = 28

    var body: some View {
        Text(score.letter)
            .font(.system(size: size * 0.6, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
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
                let isActive = grade == score
                Text(grade.letter)
                    .font(.system(size: isActive ? 22 : 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: isActive ? 44 : 32, height: isActive ? 52 : 38)
                    .background(grade.color.opacity(isActive ? 1 : 0.35), in: .rect(cornerRadius: 10))
                    .scaleEffect(isActive ? 1 : 0.96)
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
                let isActive = candidate == group
                Text("\(candidate.rawValue)")
                    .font(.system(size: isActive ? 20 : 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: isActive ? 44 : 32, height: isActive ? 52 : 38)
                    .background(candidate.color.opacity(isActive ? 1 : 0.3), in: .rect(cornerRadius: 10))
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
                let isActive = grade == score
                Text(grade.letter)
                    .font(.system(size: isActive ? 22 : 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: isActive ? 44 : 32, height: isActive ? 52 : 38)
                    .background(grade.color.opacity(isActive ? 1 : 0.3), in: .rect(cornerRadius: 10))
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
                        .font(.display(.headline))
                        .foregroundStyle(tint)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// A single traffic-light nutrient reading, e.g. "Sugars — High — 34 g".
struct NutrientLevelRow: View {
    let nutrient: Nutrient
    let level: NutrientLevel
    let amount: String?

    var body: some View {
        HStack(spacing: Theme.Spacing.small) {
            Circle()
                .fill(level.color)
                .frame(width: 12, height: 12)
                .overlay { Circle().strokeBorder(level.color.opacity(0.3), lineWidth: 4) }

            Text(nutrient.label)
                .font(.subheadline)
                .foregroundStyle(Theme.primaryText)

            Spacer(minLength: Theme.Spacing.small)

            if let amount {
                Text(amount)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Theme.secondaryText)
            }

            Text(level.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(level.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(level.color.opacity(0.12), in: .capsule)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(nutrient.label): \(level.label)\(amount.map { ", \($0)" } ?? "")")
    }
}
