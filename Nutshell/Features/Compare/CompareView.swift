import SwiftUI

/// Two or three products side by side.
///
/// The design goal is a decision, not a data dump: every row marks which product wins it,
/// so the answer is visible without doing arithmetic in a shop aisle.
struct CompareView: View {
    let products: [Product]

    @Environment(ProfileStore.self) private var profile
    @Environment(\.dismiss) private var dismiss

    private let labelWidth: CGFloat = 96

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.large) {
                        headerRow
                        verdictRow
                        scoreRows
                        nutrientTable
                        footnote
                    }
                    .padding(Theme.Spacing.medium)
                }
            }
            .navigationTitle("Compare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.tint(Theme.accent)
                }
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.small) {
            Color.clear.frame(width: labelWidth, height: 1)
            ForEach(products) { product in
                VStack(spacing: Theme.Spacing.tight) {
                    ProductImage(url: product.thumbnailURL)
                        .frame(height: 68)
                    Text(product.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                    if let brand = product.brand {
                        Text(brand)
                            .font(.caption2)
                            .foregroundStyle(Theme.secondaryText)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Verdict

    @ViewBuilder
    private var verdictRow: some View {
        let verdicts = products.map { ProductVerdict.evaluate($0, against: profile.profile) }
        if verdicts.contains(where: { $0 != nil }) {
            comparisonRow(label: "For you") { index in
                if let verdict = verdicts[index] {
                    VStack(spacing: 3) {
                        Image(systemName: verdict.level.systemImage)
                            .foregroundStyle(verdict.level.tint)
                        Text(verdict.level.accessibilityPrefix)
                            .font(.caption2)
                            .foregroundStyle(verdict.level.tint)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    Text("—").foregroundStyle(Theme.secondaryText)
                }
            }
        }
    }

    // MARK: - Scores

    private var scoreRows: some View {
        VStack(spacing: 0) {
            comparisonRow(label: "Nutri-Score") { index in
                if let score = products[index].nutriScore {
                    NutriScoreTile(score: score, baseSize: 30)
                } else {
                    missing
                }
            }
            Divider().overlay(Theme.separator)
            comparisonRow(label: "Processing") { index in
                if let nova = products[index].novaGroup {
                    VStack(spacing: 2) {
                        Text("\(nova.rawValue)")
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundStyle(nova.onColor)
                            .frame(width: 30, height: 30)
                            .background(nova.color, in: .rect(cornerRadius: 8))
                        Text(nova.title)
                            .font(.caption2)
                            .foregroundStyle(Theme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    missing
                }
            }
        }
        .padding(.vertical, Theme.Spacing.tight)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.large))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.large)
                .strokeBorder(Theme.separator, lineWidth: 1)
        }
    }

    // MARK: - Nutrients

    private var nutrientTable: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Text("Per 100 g / 100 ml")
                .font(.display(.subheadline, weight: .bold))
                .textCase(.uppercase)
                .kerning(0.6)
                .foregroundStyle(Theme.secondaryText)

            VStack(spacing: 0) {
                ForEach(Array(Nutrient.allCases.enumerated()), id: \.element) { index, nutrient in
                    let amounts = products.map { $0.nutriments?.amount(of: nutrient, per: .perHundred) }
                    let winner = bestIndex(of: amounts, for: nutrient)

                    comparisonRow(label: nutrient.label) { column in
                        if let amount = amounts[column] {
                            Text(nutrient.unit.format(amount))
                                .font(.footnote.monospacedDigit())
                                .foregroundStyle(column == winner ? Theme.accent : Theme.primaryText)
                                .fontWeight(column == winner ? .bold : .regular)
                        } else {
                            missing
                        }
                    }

                    if index < Nutrient.allCases.count - 1 {
                        Divider().overlay(Theme.separator)
                    }
                }
            }
            .padding(.vertical, Theme.Spacing.tight)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.large)
                    .strokeBorder(Theme.separator, lineWidth: 1)
            }
        }
    }

    /// The winning column for a nutrient, or `nil` when nothing wins — a tie, or fewer
    /// than two products actually carry the figure.
    private func bestIndex(of amounts: [Double?], for nutrient: Nutrient) -> Int? {
        let present = amounts.enumerated().compactMap { index, value in value.map { (index, $0) } }
        guard present.count >= 2 else { return nil }

        let best = nutrient.lowerIsBetter
            ? present.min { $0.1 < $1.1 }
            : present.max { $0.1 < $1.1 }
        guard let best else { return nil }

        // A tie has no winner worth highlighting.
        guard present.filter({ $0.1 == best.1 }).count == 1 else { return nil }
        return best.0
    }

    // MARK: - Building blocks

    private var missing: some View {
        Text("—")
            .font(.footnote)
            .foregroundStyle(Theme.tertiaryText)
            .accessibilityLabel("Not available")
    }

    private func comparisonRow<Cell: View>(
        label: String,
        @ViewBuilder cell: @escaping (Int) -> Cell
    ) -> some View {
        HStack(alignment: .center, spacing: Theme.Spacing.small) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
                .frame(width: labelWidth, alignment: .leading)

            ForEach(products.indices, id: \.self) { index in
                cell(index).frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, Theme.Spacing.medium)
        .padding(.vertical, Theme.Spacing.small)
    }

    private var footnote: some View {
        Text("Bold marks the better figure. Protein and fibre count upwards; everything else counts down. A dash means nobody has contributed that figure yet.")
            .font(.caption)
            .foregroundStyle(Theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}
