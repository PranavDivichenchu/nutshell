import SwiftUI

// MARK: - Nutri-Score

/// The European front-of-pack nutrition label, A (best) through E (worst).
enum NutriScore: String, Codable, CaseIterable, Identifiable, Sendable {
    case a, b, c, d, e

    var id: String { rawValue }
    var letter: String { rawValue.uppercased() }

    /// Official Nutri-Score palette, so the badge reads the same as it does on packaging.
    var color: Color {
        switch self {
        case .a: Color(hex: 0x038141)
        case .b: Color(hex: 0x85BB2F)
        case .c: Color(hex: 0xFECB02)
        case .d: Color(hex: 0xEE8100)
        case .e: Color(hex: 0xE63E11)
        }
    }

    var summary: String {
        switch self {
        case .a: "Excellent nutritional quality"
        case .b: "Good nutritional quality"
        case .c: "Average nutritional quality"
        case .d: "Poor nutritional quality"
        case .e: "Bad nutritional quality"
        }
    }

    /// Grades outside A–E ("unknown", "not-applicable") are treated as missing data.
    init?(apiValue: String?) {
        guard let value = apiValue?.trimmed.lowercased(), let score = NutriScore(rawValue: value) else { return nil }
        self = score
    }
}

// MARK: - NOVA

/// The NOVA classification of how heavily a food has been processed, 1 through 4.
enum NovaGroup: Int, Codable, CaseIterable, Identifiable, Sendable {
    case unprocessed = 1
    case culinaryIngredient = 2
    case processed = 3
    case ultraProcessed = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .unprocessed: "Unprocessed"
        case .culinaryIngredient: "Culinary ingredient"
        case .processed: "Processed"
        case .ultraProcessed: "Ultra-processed"
        }
    }

    var summary: String {
        switch self {
        case .unprocessed: "Whole or minimally processed food"
        case .culinaryIngredient: "Substance extracted from food, used in cooking"
        case .processed: "Food with added salt, sugar, oil, or preservatives"
        case .ultraProcessed: "Industrial formulation with additives and refined ingredients"
        }
    }

    var color: Color {
        switch self {
        case .unprocessed: Color(hex: 0x00AA00)
        case .culinaryIngredient: Color(hex: 0xFFCC00)
        case .processed: Color(hex: 0xFF6600)
        case .ultraProcessed: Color(hex: 0xE63E11)
        }
    }
}

// MARK: - Eco-Score

/// The environmental impact grade, A (lowest impact) through E (highest).
enum EcoScore: String, Codable, CaseIterable, Identifiable, Sendable {
    case a, b, c, d, e

    var id: String { rawValue }
    var letter: String { rawValue.uppercased() }

    var color: Color {
        switch self {
        case .a: Color(hex: 0x1E8F4E)
        case .b: Color(hex: 0x7FBB3F)
        case .c: Color(hex: 0xF0B400)
        case .d: Color(hex: 0xE87E04)
        case .e: Color(hex: 0xD8422C)
        }
    }

    var summary: String {
        switch self {
        case .a: "Very low environmental impact"
        case .b: "Low environmental impact"
        case .c: "Moderate environmental impact"
        case .d: "High environmental impact"
        case .e: "Very high environmental impact"
        }
    }

    init?(apiValue: String?) {
        guard let value = apiValue?.trimmed.lowercased(), let score = EcoScore(rawValue: value) else { return nil }
        self = score
    }
}

// MARK: - Nutrient levels

/// The traffic-light rating Open Food Facts assigns to fat, saturated fat, sugars, and salt.
enum NutrientLevel: String, Codable, Sendable {
    case low, moderate, high

    var label: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .low: Color(hex: 0x038141)
        case .moderate: Color(hex: 0xEE8100)
        case .high: Color(hex: 0xE63E11)
        }
    }
}
