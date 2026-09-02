import SwiftUI

/// Everything known about one product.
///
/// The screen is a stack of independent sections, each of which omits itself when its
/// data is missing. Because coverage in Open Food Facts varies enormously between
/// records, this is the only layout that stays honest: a well-documented product gets
/// a rich page, a bare one gets a short page, and neither shows empty scaffolding.
struct ProductDetailView: View {
    let product: Product

    @Environment(SavedProductsStore.self) private var saved

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                header

                if !product.dietBadges.isEmpty {
                    dietBadges
                }

                if product.hasAnyScore {
                    scores
                }

                if !product.nutrientLevels.isEmpty {
                    nutrientLevels
                }

                if let nutriments = product.nutriments, !nutriments.isEmpty {
                    NutritionFactsCard(nutriments: nutriments, servingSize: product.servingSize)
                }

                if let ingredients = product.ingredientsText {
                    IngredientsCard(text: ingredients, allergens: product.allergens)
                }

                if !product.allergens.isEmpty {
                    pillSection(
                        title: "Contains",
                        systemImage: "exclamationmark.triangle",
                        items: product.allergens,
                        tint: Color(hex: 0xC2410C)
                    )
                }

                if !product.additives.isEmpty {
                    pillSection(
                        title: "Additives",
                        subtitle: "\(product.additives.count) declared",
                        systemImage: "flask",
                        items: product.additives,
                        tint: Theme.secondaryText
                    )
                }

                if !product.categories.isEmpty {
                    pillSection(
                        title: "Categories",
                        systemImage: "square.grid.2x2",
                        items: Array(product.categories.suffix(6)),
                        tint: Theme.secondaryText
                    )
                }

                if product.isSparse {
                    sparseNotice
                }

                footer
            }
            .padding(Theme.Spacing.medium)
        }
        .background(Theme.background)
        .navigationTitle(product.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { saveButton }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            ProductImage(url: product.imageURL, cornerRadius: Theme.Radius.large)
                .frame(height: 230)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                if let brand = product.brand {
                    Text(brand.uppercased())
                        .font(.display(.caption, weight: .bold))
                        .kerning(0.8)
                        .foregroundStyle(Theme.accent)
                }

                Text(product.name)
                    .font(.display(.title2, weight: .bold))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if let quantity = product.quantity {
                    Text(quantity)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
        }
    }

    private var dietBadges: some View {
        FlowLayout(spacing: Theme.Spacing.tight) {
            ForEach(product.dietBadges) { badge in
                Pill(text: badge.label, systemImage: badge.systemImage)
            }
        }
    }

    private var scores: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            if let score = product.nutriScore {
                ScoreExplainerCard(
                    title: "Nutri-Score",
                    headline: "Grade \(score.letter)",
                    detail: score.summary,
                    tint: score.color
                ) {
                    NutriScoreScale(score: score)
                }
            }

            if let nova = product.novaGroup {
                ScoreExplainerCard(
                    title: "Processing (NOVA)",
                    headline: nova.title,
                    detail: nova.summary,
                    tint: nova.color
                ) {
                    NovaScale(group: nova)
                }
            }

            if let eco = product.ecoScore {
                ScoreExplainerCard(
                    title: "Environmental impact",
                    headline: "Grade \(eco.letter)",
                    detail: eco.summary,
                    tint: eco.color
                ) {
                    EcoScoreScale(score: eco)
                }
            }
        }
    }

    private var nutrientLevels: some View {
        SectionCard(
            title: "At a glance",
            subtitle: "Per 100 g / 100 ml",
            systemImage: "chart.bar.fill"
        ) {
            VStack(spacing: Theme.Spacing.small) {
                ForEach(product.nutrientLevels, id: \.nutrient) { entry in
                    NutrientLevelRow(
                        nutrient: entry.nutrient,
                        level: entry.level,
                        amount: product.nutriments?.formattedAmount(of: entry.nutrient, per: .perHundred)
                    )
                }
            }
        }
    }

    private func pillSection(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        items: [String],
        tint: Color
    ) -> some View {
        SectionCard(title: title, subtitle: subtitle, systemImage: systemImage, tint: tint) {
            FlowLayout(spacing: Theme.Spacing.tight) {
                ForEach(items, id: \.self) { item in
                    Pill(text: item, tint: tint)
                }
            }
        }
    }

    private var sparseNotice: some View {
        SectionCard(title: "Incomplete entry", systemImage: "info.circle") {
            Text("Nobody has filled in the nutrition, ingredients, or scores for this product yet. Open Food Facts is contributed by volunteers, so coverage varies.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
            Text("Barcode \(product.code)")
                .font(.caption.monospacedDigit())
            Link(destination: URL(string: "https://world.openfoodfacts.org/product/\(product.code)")!) {
                HStack(spacing: 4) {
                    Text("View on Open Food Facts")
                    Image(systemName: "arrow.up.right")
                }
                .font(.caption.weight(.medium))
            }
            .tint(Theme.accent)
        }
        .foregroundStyle(Theme.secondaryText)
        .padding(.top, Theme.Spacing.tight)
    }

    private var saveButton: some View {
        let isSaved = saved.contains(product)
        return Button {
            saved.toggle(product)
        } label: {
            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                .foregroundStyle(Theme.accent)
        }
        .accessibilityLabel(isSaved ? "Remove from saved" : "Save product")
        .sensoryFeedback(.selection, trigger: isSaved)
    }
}
