import Foundation

/// A single food product as returned by the Open Food Facts search endpoint.
///
/// Every field beyond `code` is optional on purpose. Open Food Facts is filled in by
/// volunteers, so a product may have a name and nothing else. Treating absent data as
/// normal — rather than as an error — is the main constraint this model is built around.
struct Product: Codable, Identifiable, Hashable, Sendable {
    /// The barcode. The only field the API guarantees, and the app's stable identity.
    let code: String

    var id: String { code }

    private let rawName: String?
    private let rawGenericName: String?
    private let rawBrands: LenientString?
    private let rawQuantity: String?
    private let rawServingSize: String?
    private let rawIngredientsText: String?
    private let rawImageURL: String?
    private let rawThumbnailURL: String?
    private let rawNutriScore: String?
    private let rawEcoScore: String?
    private let rawNovaGroup: LenientInt?
    private let rawAllergens: [String]?
    private let rawTraces: [String]?
    private let rawAdditives: [String]?
    private let rawLabels: [String]?
    private let rawCategories: [String]?
    private let rawAnalysis: [String]?
    private let rawNutrientLevels: [String: String]?

    let nutriments: Nutriments?

    enum CodingKeys: String, CodingKey {
        case code
        case rawName = "product_name"
        case rawGenericName = "generic_name"
        case rawBrands = "brands"
        case rawQuantity = "quantity"
        case rawServingSize = "serving_size"
        case rawIngredientsText = "ingredients_text"
        case rawImageURL = "image_front_url"
        case rawThumbnailURL = "image_front_small_url"
        case rawNutriScore = "nutriscore_grade"
        case rawEcoScore = "ecoscore_grade"
        case rawNovaGroup = "nova_group"
        case rawAllergens = "allergens_tags"
        case rawTraces = "traces_tags"
        case rawAdditives = "additives_tags"
        case rawLabels = "labels_tags"
        case rawCategories = "categories_tags"
        case rawAnalysis = "ingredients_analysis_tags"
        case rawNutrientLevels = "nutrient_levels"
        case nutriments
    }

    // MARK: - Presentation

    /// The best available name, falling back through the API's several name fields.
    var name: String {
        rawName?.nilIfBlank ?? rawGenericName?.nilIfBlank ?? "Unnamed product"
    }

    var hasName: Bool { rawName?.nilIfBlank != nil || rawGenericName?.nilIfBlank != nil }

    /// The API packs multiple brands into one comma-separated string.
    var brand: String? {
        rawBrands?.value?
            .split(separator: ",")
            .first
            .map(String.init)?
            .nilIfBlank
    }

    /// Package size, e.g. "1 l" or "250 g".
    ///
    /// Contributors sometimes save a bare unit with no number ("g"), which renders as
    /// a meaningless caption, so a quantity has to contain a digit to count as one.
    var quantity: String? {
        guard let value = rawQuantity?.nilIfBlank, value.contains(where: \.isNumber) else { return nil }
        return value
    }

    var servingSize: String? { rawServingSize?.nilIfBlank }

    var ingredientsText: String? { rawIngredientsText?.nilIfBlank }

    /// The brand, unless the product name already begins with it.
    ///
    /// Common in this database, and otherwise renders as "NUTELLA" directly above
    /// "Nutella". Used by both the row subtitle and the detail header so the two cannot
    /// disagree about it.
    var displayBrand: String? {
        guard let brand else { return nil }
        return name.lowercased().hasPrefix(brand.lowercased()) ? nil : brand
    }

    /// A one-line "Brand · 500 g" caption.
    var subtitle: String? {
        [displayBrand, quantity]
            .compactMap { $0 }
            .joined(separator: " · ")
            .nilIfBlank
    }

    var imageURL: URL? { rawImageURL?.nilIfBlank.flatMap(URL.init(string:)) }
    var thumbnailURL: URL? { rawThumbnailURL?.nilIfBlank.flatMap(URL.init(string:)) ?? imageURL }

    // MARK: - Scores

    var nutriScore: NutriScore? { NutriScore(apiValue: rawNutriScore) }
    var ecoScore: EcoScore? { EcoScore(apiValue: rawEcoScore) }
    var novaGroup: NovaGroup? { rawNovaGroup?.value.flatMap(NovaGroup.init(rawValue:)) }

    var hasAnyScore: Bool { nutriScore != nil || novaGroup != nil || ecoScore != nil }

    // MARK: - Tags

    var allergens: [String] { Tag.humanize(rawAllergens) }
    var traces: [String] { Tag.humanize(rawTraces) }

    /// Allergen names to show as a summary.
    ///
    /// Contributors often paste raw label text into `allergens_tags` alongside the
    /// canonical tag, so a German bar arrives as ["en:milk", "en:nuts", "VOLLMILCHPULVER",
    /// "MANDELN"] and renders as a wall of shouting duplicates. Preferring the recognised
    /// EU-14 labels gives one clean, translated summary — and the raw words are still
    /// visible, highlighted in place, in the ingredient list above.
    var allergenLabels: [String] {
        let recognised = declaredAllergens.map(\.label).sorted()
        // Fall back to the raw tags rather than showing nothing for an allergen that
        // falls outside the fourteen.
        return recognised.isEmpty ? Tag.humanize(rawAllergens) : recognised
    }

    var traceLabels: [String] {
        let recognised = traceAllergens.map(\.label).sorted()
        return recognised.isEmpty ? Tag.humanize(rawTraces) : recognised
    }

    /// Allergens the label declares outright, mapped onto the EU fourteen.
    var declaredAllergens: Set<Allergen> {
        Set((rawAllergens ?? []).compactMap(Allergen.matching(tag:)))
    }

    /// Allergens the label warns the product *may* contain through cross-contamination.
    var traceAllergens: Set<Allergen> {
        Set((rawTraces ?? []).compactMap(Allergen.matching(tag:)))
    }

    /// Whether there is enough ingredient or allergen data to say anything trustworthy
    /// about what is in this product. Most Open Food Facts records fail this test, and
    /// treating "nothing listed" as "contains nothing" would be actively dangerous.
    var hasIngredientData: Bool {
        ingredientsText != nil || !(rawAllergens ?? []).isEmpty || !(rawAnalysis ?? []).isEmpty
    }

    /// What the database can actually say about one diet claim: confirmed, contradicted,
    /// or simply not known.
    func dietStatus(for badge: DietBadge) -> DietStatus {
        let tags = Set(rawAnalysis ?? [])
        if tags.contains(badge.confirmingTag) { return .confirmed }
        if badge.denyingTags.contains(where: tags.contains) { return .contradicted }
        return .unknown
    }
    var additives: [String] { Tag.humanize(rawAdditives, transform: Tag.uppercaseENumber) }
    var labels: [String] { Tag.humanize(rawLabels) }
    var categories: [String] { Tag.humanize(rawCategories) }

    /// Diet claims the API could positively confirm. Unconfirmed and negative
    /// analyses are dropped rather than shown, so a badge is never misleading.
    var dietBadges: [DietBadge] {
        let tags = Set(rawAnalysis ?? [])
        return DietBadge.allCases.filter { tags.contains($0.confirmingTag) }
    }

    var nutrientLevels: [(nutrient: Nutrient, level: NutrientLevel)] {
        guard let rawNutrientLevels else { return [] }
        return Nutrient.allCases.compactMap { nutrient in
            guard let raw = rawNutrientLevels[nutrient.rawValue],
                  let level = NutrientLevel(rawValue: raw) else { return nil }
            return (nutrient, level)
        }
    }

    /// Whether this record is missing the fields the search index does not carry.
    ///
    /// Search results can come from either backend, and the faster one holds no
    /// ingredient text, quantity, or additives. Rather than showing a thinner page for
    /// those, the detail view tops the record up by barcode.
    var needsDetailEnrichment: Bool {
        ingredientsText == nil
    }

    /// True when the record is too sparse to justify opening a detail view's worth of
    /// sections — used to show an honest "this entry is incomplete" state instead.
    var isSparse: Bool {
        !hasAnyScore && ingredientsText == nil && (nutriments?.isEmpty ?? true)
    }
}

/// A diet claim that Open Food Facts derived from the ingredient list.
enum DietBadge: String, Codable, Hashable, CaseIterable, Identifiable, Sendable {
    case vegan, vegetarian, palmOilFree

    var id: String { rawValue }

    /// The exact tag that means "confirmed"; `maybe-` and `non-` variants are ignored.
    var confirmingTag: String {
        switch self {
        case .vegan: "en:vegan"
        case .vegetarian: "en:vegetarian"
        case .palmOilFree: "en:palm-oil-free"
        }
    }

    /// Tags that positively contradict the claim. Note these are NOT the same as the
    /// claim being absent — Open Food Facts distinguishes "not vegan" from "unknown",
    /// and so must the app.
    var denyingTags: [String] {
        switch self {
        case .vegan: ["en:non-vegan"]
        case .vegetarian: ["en:non-vegetarian"]
        case .palmOilFree: ["en:palm-oil"]
        }
    }

    var label: String {
        switch self {
        case .vegan: "Vegan"
        case .vegetarian: "Vegetarian"
        case .palmOilFree: "Palm oil free"
        }
    }

    var systemImage: String {
        switch self {
        case .vegan: "leaf.fill"
        case .vegetarian: "carrot.fill"
        case .palmOilFree: "tree.fill"
        }
    }
}

/// What the database can say about a diet claim.
enum DietStatus: Sendable {
    case confirmed, contradicted, unknown
}

/// Open Food Facts tags arrive language-prefixed and slugified (`"en:palm-oil-free"`).
enum Tag {
    /// Strips the language prefix from a tag: `"en:palm-oil-free"` becomes `"palm-oil-free"`.
    ///
    /// Deliberately not `split(separator:)`, which drops empty subsequences — a tag of
    /// just `"en:"` (which the database does contain) would collapse to a single element
    /// and trap on the second index.
    static func slug(from tag: String) -> String {
        guard let colon = tag.firstIndex(of: ":") else { return tag }
        return String(tag[tag.index(after: colon)...])
    }

    static func humanize(_ tags: [String]?, transform: (String) -> String = { $0 }) -> [String] {
        (tags ?? []).compactMap { tag in
            let slug = slug(from: tag)
            guard let cleaned = slug.replacingOccurrences(of: "-", with: " ").nilIfBlank else { return nil }
            return transform(cleaned.prefix(1).uppercased() + cleaned.dropFirst())
        }
    }

    /// Renders additive codes as "E340" rather than "E340".capitalized quirks.
    static func uppercaseENumber(_ value: String) -> String {
        let isENumber = value.count <= 6 && value.lowercased().first == "e"
            && value.dropFirst().first?.isNumber == true
        return isENumber ? value.uppercased() : value
    }
}
