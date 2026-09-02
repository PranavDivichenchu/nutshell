import SwiftUI

/// The compact verdict marker shown on a search result row.
///
/// Small, but it is the reason the list is scannable: it answers "does this fit me?"
/// before the name has even been read.
struct VerdictBadge: View {
    let verdict: ProductVerdict

    var body: some View {
        Image(systemName: verdict.level.systemImage)
            .font(.footnote)
            .foregroundStyle(verdict.level.tint)
            .accessibilityLabel(verdict.level.accessibilityPrefix)
    }
}

/// The full verdict banner at the top of a product's detail view.
struct VerdictBanner: View {
    let verdict: ProductVerdict

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.small) {
            Image(systemName: verdict.level.systemImage)
                .font(.title3)
                .foregroundStyle(verdict.level.tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(verdict.level.headline)
                    .font(.display(.subheadline, weight: .bold))
                    .foregroundStyle(verdict.level.tint)

                if verdict.reasons.isEmpty {
                    Text("Nothing here conflicts with what you told us to watch for.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(verdict.reasons) { reason in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("•").foregroundStyle(Theme.secondaryText)
                            Text(reason.text)
                                .font(.footnote)
                                .foregroundStyle(Theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(verdict.level.tint.opacity(0.10), in: .rect(cornerRadius: Theme.Radius.large))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.large)
                .strokeBorder(verdict.level.tint.opacity(0.28), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(verdict.level.accessibilityPrefix). \(verdict.reasons.map(\.text).joined(separator: ". "))"
        )
    }
}

/// One nutrient as a share of a day's reference intake.
///
/// A bar rather than a bare percentage because the comparison between rows is the useful
/// part — you can see at a glance that the sugar bar is the one that matters.
struct ReferenceIntakeBar: View {
    let nutrient: Nutrient
    let amount: Double

    private var fraction: Double? { ReferenceIntake.fraction(of: amount, for: nutrient) }

    /// Amber past half a day's intake, red past a full day — the same convention as
    /// the traffic-light labels people already read on packaging.
    private var tint: Color {
        guard let fraction else { return Theme.secondaryText }
        return switch fraction {
        case ..<0.5: Color(light: 0x1D7A44, dark: 0x4FBF7B)
        case ..<1.0: Color(light: 0xB45309, dark: 0xE8A33D)
        default: Color(light: 0xC2410C, dark: 0xF07C58)
        }
    }

    var body: some View {
        if let fraction {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(nutrient.label)
                        .font(.subheadline)
                        .foregroundStyle(Theme.primaryText)
                    Spacer(minLength: Theme.Spacing.small)
                    Text(nutrient.unit.format(amount))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Theme.secondaryText)
                    Text("\(Int((fraction * 100).rounded()))%")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(tint)
                        .frame(minWidth: 48, alignment: .trailing)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.surfaceRaised)
                        Capsule()
                            .fill(tint)
                            .frame(width: max(3, proxy.size.width * min(fraction, 1)))
                    }
                }
                .frame(height: 7)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "\(nutrient.label): \(nutrient.unit.format(amount)), \(Int((fraction * 100).rounded())) percent of the daily reference intake"
            )
        }
    }
}
