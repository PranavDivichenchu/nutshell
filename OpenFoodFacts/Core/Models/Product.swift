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
    private let rawBrands: String?
    private let rawQuantity: String?
    private let rawServingSize: String?
    private let rawIngredientsText: String?
    private let rawImageURL: String?
    private let rawThumbnailURL: String?
    private let rawNutriScore: String?
    private let rawEcoScore: String?
    private let rawNovaGroup: LenientInt?
    private let rawAllergens: [String]?
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
        rawBrands?.nilIfBlank?
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

    /// A one-line "Brand · 500 g" caption.
    ///
    /// The brand is dropped when the product name already begins with it, which is
    /// common in this database and otherwise renders as "Nutella / Nutella".
    var subtitle: String? {
        let redundantBrand = brand.map { name.lowercased().hasPrefix($0.lowercased()) } ?? false
        return [redundantBrand ? nil : brand, quantity]
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

    /// True when the record is too sparse to justify opening a detail view's worth of
    /// sections — used to show an honest "this entry is incomplete" state instead.
    var isSparse: Bool {
        !hasAnyScore && ingredientsText == nil && (nutriments?.isEmpty ?? true)
    }
}

/// A diet claim that Open Food Facts derived from the ingredient list.
enum DietBadge: String, CaseIterable, Identifiable, Sendable {
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

/// Open Food Facts tags arrive language-prefixed and slugified (`"en:palm-oil-free"`).
enum Tag {
    static func humanize(_ tags: [String]?, transform: (String) -> String = { $0 }) -> [String] {
        (tags ?? []).compactMap { tag in
            let slug = tag.contains(":") ? String(tag.split(separator: ":", maxSplits: 1)[1]) : tag
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
