import Foundation

/// The nutrients this app surfaces, in the order a nutrition label lists them.
///
/// Open Food Facts exposes hundreds of keys; showing all of them would bury the
/// handful people actually read. This is the standard label set plus fiber.
enum Nutrient: String, CaseIterable, Identifiable, Sendable {
    case energy = "energy-kcal"
    case fat
    case saturatedFat = "saturated-fat"
    case carbohydrates
    case sugars
    case fiber
    case proteins
    case salt

    var id: String { rawValue }

    var label: String {
        switch self {
        case .energy: "Energy"
        case .fat: "Fat"
        case .saturatedFat: "Saturated fat"
        case .carbohydrates: "Carbohydrates"
        case .sugars: "Sugars"
        case .fiber: "Fiber"
        case .proteins: "Protein"
        case .salt: "Salt"
        }
    }

    /// Saturated fat and sugars are sub-rows of fat and carbohydrates on a real label.
    var isSubEntry: Bool { self == .saturatedFat || self == .sugars }

    var unit: NutrientUnit { self == .energy ? .kilocalories : .grams }
}

enum NutrientUnit: Sendable {
    case grams, kilocalories

    /// Formats a value the way a nutrition label would, promoting sub-gram
    /// amounts to milligrams so salt content stays readable.
    func format(_ value: Double) -> String {
        switch self {
        case .kilocalories:
            "\(value.formatted(.number.precision(.fractionLength(0)))) kcal"
        case .grams where value > 0 && value < 1:
            "\((value * 1000).formatted(.number.precision(.fractionLength(0...1)))) mg"
        case .grams:
            "\(value.formatted(.number.precision(.fractionLength(0...1)))) g"
        }
    }
}

/// Which reference quantity a nutrition figure is measured against.
enum NutritionBasis: String, CaseIterable, Identifiable, Sendable {
    case perHundred, perServing

    var id: String { rawValue }
    var apiSuffix: String { self == .perHundred ? "_100g" : "_serving" }
}

/// A sparse bag of nutrition figures keyed by the API's flat `nutriments` dictionary.
///
/// The payload mixes numbers, numeric strings, and unit strings under ~200 keys, so
/// the values are flattened into a plain `[String: Double]` at decode time and read
/// back through the type-safe `Nutrient` accessors.
struct Nutriments: Codable, Hashable, Sendable {
    private let values: [String: Double]

    init(values: [String: Double] = [:]) { self.values = values }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        var parsed: [String: Double] = [:]
        for key in container.allKeys {
            // `*_unit`, `*_modifier`, and `*_label` are strings describing a value, not values.
            guard !key.stringValue.hasSuffix("_unit"),
                  !key.stringValue.hasSuffix("_modifier"),
                  !key.stringValue.hasSuffix("_label") else { continue }
            if let value = try? container.decode(LenientDouble.self, forKey: key).value {
                parsed[key.stringValue] = value
            }
        }
        values = parsed
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        for (key, value) in values {
            try container.encode(value, forKey: DynamicCodingKey(key))
        }
    }

    /// The amount of a nutrient for the given basis, or `nil` when the contributor
    /// never filled it in — which is common enough that callers must handle it.
    func amount(of nutrient: Nutrient, per basis: NutritionBasis) -> Double? {
        values[nutrient.rawValue + basis.apiSuffix]
            // Energy is sometimes only present in kilojoules; convert rather than show nothing.
            ?? (nutrient == .energy ? values["energy" + basis.apiSuffix].map { $0 / 4.184 } : nil)
    }

    func formattedAmount(of nutrient: Nutrient, per basis: NutritionBasis) -> String? {
        amount(of: nutrient, per: basis).map(nutrient.unit.format)
    }

    /// Whether there is anything worth rendering a nutrition table for.
    func hasData(per basis: NutritionBasis) -> Bool {
        Nutrient.allCases.contains { amount(of: $0, per: basis) != nil }
    }

    var isEmpty: Bool { values.isEmpty }
}
