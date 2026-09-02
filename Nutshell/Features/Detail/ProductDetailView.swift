import SwiftUI

/// Everything known about one product.
///
/// The screen is a stack of independent sections, each of which omits itself when its
/// data is missing. Because coverage in Open Food Facts varies enormously between
/// records, this is the only layout that stays honest: a well-documented product gets a
/// rich page, a bare one gets a short page, and neither shows empty scaffolding.
struct ProductDetailView: View {
    let product: Product

    @Environment(SavedProductsStore.self) private var saved
    @Environment(CompareStore.self) private var compare
    @Environment(ProfileStore.self) private var profile
    @Environment(RecentlyViewedStore.self) private var recentlyViewed

    private var verdict: ProductVerdict? {
        ProductVerdict.evaluate(product, against: profile.profile)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                header

                // The most important thing on the screen once a profile exists, so it
                // sits above the scores rather than below them.
                if let verdict {
                    VerdictBanner(verdict: verdict)
                }

                if !product.dietBadges.isEmpty {
                    dietBadges
                }

                if product.hasAnyScore {
                    scores
                }

                if !product.nutrientLevels.isEmpty {
                    nutrientLevels
                }

                if let nutriments = product.nutriments, nutriments.hasData(per: .perHundred) {
                    referenceIntake(nutriments)
                }

                if let nutriments = product.nutriments, !nutriments.isEmpty {
                    NutritionFactsCard(nutriments: nutriments, servingSize: product.servingSize)
                }

                if let ingredients = product.ingredientsText {
                    IngredientsCard(text: ingredients, allergens: product.allergens)
                }

                if !product.allergenLabels.isEmpty {
                    pillSection(
                        title: "Contains",
                        systemImage: "exclamationmark.triangle",
                        items: product.allergenLabels,
                        tint: Color(light: 0xC2410C, dark: 0xF07C58)
                    )
                }

                if !product.traceLabels.isEmpty {
                    pillSection(
                        title: "May contain",
                        subtitle: "Possible cross-contamination declared by the manufacturer",
                        systemImage: "exclamationmark.circle",
                        items: product.traceLabels,
                        tint: Color(light: 0xB45309, dark: 0xE8A33D)
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
        .toolbar { toolbar }
        .task {
            recentlyViewed.record(product)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    compare.toggle(product)
                } label: {
                    Label(compare.contains(product) ? "Remove from compare" : "Add to compare",
                          systemImage: "square.on.square")
                }
                .disabled(!compare.contains(product) && compare.isFull)

                ShareLink(item: openFoodFactsURL, subject: Text(product.name), message: Text(shareSummary)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .tint(Theme.accent)
            .accessibilityLabel("More actions")
        }

        ToolbarItem(placement: .topBarTrailing) { saveButton }
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

    private var openFoodFactsURL: URL {
        URL(string: "https://world.openfoodfacts.org/product/\(product.code)")!
    }

    private var shareSummary: String {
        var parts = [product.name]
        if let brand = product.brand { parts.append(brand) }
        if let score = product.nutriScore { parts.append("Nutri-Score \(score.letter)") }
        if let nova = product.novaGroup { parts.append(nova.title) }
        return parts.joined(separator: " · ")
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

    /// Turns raw grams into "how much of a day is this", which is the form people can
    /// actually act on.
    private func referenceIntake(_ nutriments: Nutriments) -> some View {
        SectionCard(
            title: "Share of a day",
            subtitle: "Per 100 g / 100 ml, against an average adult's reference intake",
            systemImage: "gauge.medium"
        ) {
            VStack(spacing: Theme.Spacing.medium) {
                ForEach(Nutrient.allCases) { nutrient in
                    if let amount = nutriments.amount(of: nutrient, per: .perHundred) {
                        ReferenceIntakeBar(nutrient: nutrient, amount: amount)
                    }
                }

                Text("Reference intake for an average adult (2,000 kcal). Fibre uses the EFSA adequate intake, which is a guideline rather than an official reference. Not personalised advice.")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
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
        SectionCard(title: "Incomplete entry", systemImage: "info.circle", tint: Theme.secondaryText) {
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
            Link(destination: openFoodFactsURL) {
                HStack(spacing: 4) {
                    Text("View on Open Food Facts")
                    Image(systemName: "arrow.up.right")
                }
                .font(.caption.weight(.medium))
            }
            .tint(Theme.accent)
            // Open Food Facts data is ODbL-licensed and requires attribution.
            Text("Data from Open Food Facts, licensed under the Open Database License (ODbL).")
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText.opacity(0.85))
        }
        .foregroundStyle(Theme.secondaryText)
        .padding(.top, Theme.Spacing.tight)
    }
}
