import SwiftUI

// MARK: - Nutri-Score

/// The European front-of-pack nutrition label, A (best) through E (worst).
enum NutriScore: String, Codable, CaseIterable, Identifiable, Sendable {
    case a, b, c, d, e

    var id: String { rawValue }
    var letter: String { rawValue.uppercased() }

    /// Official Nutri-Score palette, so the badge reads the same as it does on packaging.
    var hex: UInt32 {
        switch self {
        case .a: 0x038141
        case .b: 0x85BB2F
        case .c: 0xFECB02
        case .d: 0xEE8100
        case .e: 0xE63E11
        }
    }

    var color: Color { Color(hex: hex) }

    /// Black or white, whichever is actually readable on this grade's colour. The
    /// yellow and light-green grades fail badly against white, which is why this is
    /// computed rather than hard-coded to white everywhere.
    var onColor: Color { Color.readableForeground(on: hex) }

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

    var hex: UInt32 {
        switch self {
        case .unprocessed: 0x00AA00
        case .culinaryIngredient: 0xFFCC00
        case .processed: 0xFF6600
        case .ultraProcessed: 0xE63E11
        }
    }

    var color: Color { Color(hex: hex) }
    var onColor: Color { Color.readableForeground(on: hex) }
}

// MARK: - Eco-Score

/// The environmental impact grade, A (lowest impact) through F (highest).
///
/// Note this scale runs to F, unlike Nutri-Score. Treating it as a–e made the whole
/// Environmental impact card disappear for exactly the products it matters most for.
enum EcoScore: String, Codable, CaseIterable, Identifiable, Sendable {
    case a, b, c, d, e, f

    var id: String { rawValue }
    var letter: String { rawValue.uppercased() }

    var hex: UInt32 {
        switch self {
        case .a: 0x1E8F4E
        case .b: 0x7FBB3F
        case .c: 0xF0B400
        case .d: 0xE87E04
        case .e: 0xD8422C
        case .f: 0x8E1F13
        }
    }

    var color: Color { Color(hex: hex) }
    var onColor: Color { Color.readableForeground(on: hex) }

    var summary: String {
        switch self {
        case .a: "Very low environmental impact"
        case .b: "Low environmental impact"
        case .c: "Moderate environmental impact"
        case .d: "High environmental impact"
        case .e: "Very high environmental impact"
        case .f: "Extremely high environmental impact"
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
