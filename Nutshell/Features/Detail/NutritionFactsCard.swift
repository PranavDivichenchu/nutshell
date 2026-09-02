import SwiftUI

/// The nutrition table, with a per-100 g / per-serving toggle.
///
/// The toggle only appears when the product actually carries serving-level data, which
/// is roughly half of them. Offering a control that silently produces an empty table
/// would be worse than not offering it.
struct NutritionFactsCard: View {
    let nutriments: Nutriments
    let servingSize: String?

    @State private var basis: NutritionBasis = .perHundred

    private var availableBases: [NutritionBasis] {
        NutritionBasis.allCases.filter { nutriments.hasData(per: $0) }
    }

    var body: some View {
        if availableBases.isEmpty {
            SectionCard(title: "Nutrition", systemImage: "chart.bar.doc.horizontal") {
                Text("No nutrition data has been contributed for this product yet.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
        } else {
            SectionCard(
                title: "Nutrition",
                subtitle: subtitle,
                systemImage: "chart.bar.doc.horizontal"
            ) {
                VStack(spacing: Theme.Spacing.small) {
                    if availableBases.count > 1 {
                        Picker("Measured per", selection: $basis) {
                            Text("Per 100 g").tag(NutritionBasis.perHundred)
                            Text("Per serving").tag(NutritionBasis.perServing)
                        }
                        .pickerStyle(.segmented)
                        .padding(.bottom, 2)
                    }

                    VStack(spacing: 0) {
                        ForEach(Nutrient.allCases) { nutrient in
                            NutritionRow(
                                nutrient: nutrient,
                                value: nutriments.formattedAmount(of: nutrient, per: basis)
                            )
                            if nutrient != Nutrient.allCases.last {
                                Divider().overlay(Theme.separator)
                            }
                        }
                    }
                }
                .onAppear {
                    // Fall back to whichever basis has data if the default is empty.
                    if !availableBases.contains(basis), let first = availableBases.first {
                        basis = first
                    }
                }
            }
        }
    }

    private var subtitle: String {
        switch basis {
        case .perHundred: "Per 100 g / 100 ml"
        case .perServing: servingSize.map { "Per serving · \($0)" } ?? "Per serving"
        }
    }
}

private struct NutritionRow: View {
    let nutrient: Nutrient
    let value: String?

    var body: some View {
        HStack {
            Text(nutrient.label)
                .font(nutrient.isSubEntry ? .subheadline : .subheadline.weight(.medium))
                .foregroundStyle(nutrient.isSubEntry ? Theme.secondaryText : Theme.primaryText)
                // Indent sub-entries the way a printed nutrition label does.
                .padding(.leading, nutrient.isSubEntry ? Theme.Spacing.medium : 0)

            Spacer(minLength: Theme.Spacing.small)

            Text(value ?? "—")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(value == nil ? Theme.secondaryText.opacity(0.5) : Theme.primaryText)
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(nutrient.label), \(value ?? "not available")")
    }
}
