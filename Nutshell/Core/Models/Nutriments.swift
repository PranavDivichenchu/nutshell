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

    /// Which direction counts as "better" when two products are compared.
    ///
    /// Protein and fibre are the two nutrients people want more of; for everything else
    /// on this label, less is the healthier choice.
    var lowerIsBetter: Bool {
        switch self {
        case .proteins, .fiber: false
        default: true
        }
    }

    var unit: NutrientUnit { self == .energy ? .kilocalories : .grams }

    /// The API keys this nutrient can arrive under, in preference order.
    ///
    /// Products imported from the US taxonomy store carbohydrates as
    /// `carbohydrates-total`, which otherwise renders an empty Carbohydrates row sitting
    /// directly above a populated Sugars sub-row.
    var apiKeys: [String] {
        switch self {
        case .carbohydrates: ["carbohydrates", "carbohydrates-total"]
        case .fiber: ["fiber", "dietary-fiber"]
        case .energy: ["energy-kcal"]
        default: [rawValue]
        }
    }
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
    /// Qualifiers the label carries, keyed by nutrient name: `"<"`, `">"`, `"~"` and so on.
    private let modifiers: [String: String]

    init(values: [String: Double] = [:], modifiers: [String: String] = [:]) {
        self.values = values
        self.modifiers = modifiers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        var parsed: [String: Double] = [:]
        var qualifiers: [String: String] = [:]

        for key in container.allKeys {
            let name = key.stringValue

            // A modifier says the number is a bound, not a measurement. Dropping it turns
            // "less than 0.5 g of salt" into a flat "0.5 g", which is a different claim.
            if name.hasSuffix("_modifier") {
                if let symbol = try? container.decode(String.self, forKey: key), !symbol.isEmpty {
                    qualifiers[String(name.dropLast("_modifier".count))] = symbol
                }
                continue
            }

            // `*_unit` and `*_label` describe a value rather than being one.
            guard !name.hasSuffix("_unit"), !name.hasSuffix("_label") else { continue }
            if let value = try? container.decode(LenientDouble.self, forKey: key).value {
                parsed[name] = value
            }
        }

        values = parsed
        modifiers = qualifiers
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        for (key, value) in values {
            try container.encode(value, forKey: DynamicCodingKey(key))
        }
        for (key, symbol) in modifiers {
            try container.encode(symbol, forKey: DynamicCodingKey(key + "_modifier"))
        }
    }

    /// The qualifier attached to a nutrient, if the label gave one.
    func modifier(for nutrient: Nutrient) -> String? {
        for key in nutrient.apiKeys {
            if let symbol = modifiers[key] { return symbol }
        }
        return nil
    }

    /// The amount of a nutrient for the given basis, or `nil` when the contributor
    /// never filled it in — which is common enough that callers must handle it.
    func amount(of nutrient: Nutrient, per basis: NutritionBasis) -> Double? {
        for key in nutrient.apiKeys {
            if let value = values[key + basis.apiSuffix] { return value }
        }
        // Energy is sometimes only present in kilojoules; convert rather than show nothing.
        if nutrient == .energy, let kilojoules = values["energy" + basis.apiSuffix] {
            return kilojoules / 4.184
        }
        return nil
    }

    func formattedAmount(of nutrient: Nutrient, per basis: NutritionBasis) -> String? {
        guard let amount = amount(of: nutrient, per: basis) else { return nil }
        let rendered = nutrient.unit.format(amount)
        // "< 0.5 g" is what the packet says; "0.5 g" is a claim the packet did not make.
        guard let symbol = modifier(for: nutrient), symbol != "=" else { return rendered }
        return "\(symbol) \(rendered)"
    }

    /// Whether there is anything worth rendering a nutrition table for.
    func hasData(per basis: NutritionBasis) -> Bool {
        Nutrient.allCases.contains { amount(of: $0, per: basis) != nil }
    }

    var isEmpty: Bool { values.isEmpty }
}
