import Testing
import Foundation
@testable import Nutshell

/// The decoding boundary is where this app absorbs Open Food Facts' loose typing.
/// If it regresses, every screen shows wrong numbers, so it gets the most coverage.
@Suite("Lenient decoding")
struct LenientDecodingTests {

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    @Test("A double survives every encoding the API uses for it")
    func doubleAcceptsAllEncodings() throws {
        struct Box: Decodable { let v: LenientDouble }

        #expect(try decode(Box.self, #"{"v": 3.5}"#).v.value == 3.5)
        #expect(try decode(Box.self, #"{"v": 3}"#).v.value == 3)
        #expect(try decode(Box.self, #"{"v": "3.5"}"#).v.value == 3.5)
        #expect(try decode(Box.self, #"{"v": " 3.5 "}"#).v.value == 3.5)   // padded strings occur
        #expect(try decode(Box.self, #"{"v": null}"#).v.value == nil)
        #expect(try decode(Box.self, #"{"v": "trace"}"#).v.value == nil)   // non-numeric text
        #expect(try decode(Box.self, #"{"v": ""}"#).v.value == nil)
    }

    @Test("An int survives every encoding the API uses for it")
    func intAcceptsAllEncodings() throws {
        struct Box: Decodable { let v: LenientInt }

        #expect(try decode(Box.self, #"{"v": 4}"#).v.value == 4)
        #expect(try decode(Box.self, #"{"v": "4"}"#).v.value == 4)
        #expect(try decode(Box.self, #"{"v": 4.0}"#).v.value == 4)
        #expect(try decode(Box.self, #"{"v": null}"#).v.value == nil)
        #expect(try decode(Box.self, #"{"v": "unknown"}"#).v.value == nil)
    }

    @Test("Blank strings are treated as missing data")
    func blankHandling() {
        #expect("".nilIfBlank == nil)
        #expect("   ".nilIfBlank == nil)
        #expect("\n\t".nilIfBlank == nil)
        #expect("  Oatly ".nilIfBlank == "Oatly")
    }
}

@Suite("Nutriments")
struct NutrimentsTests {

    private func nutriments(_ json: String) throws -> Nutriments {
        try JSONDecoder().decode(Nutriments.self, from: Data(json.utf8))
    }

    @Test("Values are read per basis, and unit metadata is not mistaken for a value")
    func basisAndUnitFiltering() throws {
        let n = try nutriments("""
        {"fat_100g": 3.2, "fat_serving": "1.6", "fat_unit": "g",
         "salt_100g": 0.0975, "sugars_modifier": "~", "proteins_label": "Protein"}
        """)

        #expect(n.amount(of: .fat, per: .perHundred) == 3.2)
        #expect(n.amount(of: .fat, per: .perServing) == 1.6)
        #expect(n.amount(of: .salt, per: .perHundred) == 0.0975)
        // A "_unit" key must not be parsed as a nutrient value.
        #expect(n.amount(of: .sugars, per: .perHundred) == nil)
    }

    @Test("Energy falls back to kilojoules when kilocalories are absent")
    func energyKilojouleFallback() throws {
        let kcal = try nutriments(#"{"energy-kcal_100g": 250}"#)
        #expect(kcal.amount(of: .energy, per: .perHundred) == 250)

        let kj = try nutriments(#"{"energy_100g": 1046}"#)
        let converted = try #require(kj.amount(of: .energy, per: .perHundred))
        #expect(abs(converted - 250) < 0.5)   // 1046 kJ ≈ 250 kcal

        // The fallback must not leak into other nutrients.
        #expect(kj.amount(of: .fat, per: .perHundred) == nil)
    }

    @Test("Sub-gram amounts are promoted to milligrams so salt stays readable")
    func unitFormatting() {
        #expect(NutrientUnit.grams.format(0.0975).contains("mg"))
        #expect(NutrientUnit.grams.format(3.2).hasSuffix("g"))
        #expect(NutrientUnit.grams.format(3.2).contains("mg") == false)
        #expect(NutrientUnit.kilocalories.format(250).contains("kcal"))
        // Zero is a real measurement, not a sub-gram value to promote.
        #expect(NutrientUnit.grams.format(0).contains("mg") == false)
    }

    @Test("Data presence is reported per basis")
    func dataPresence() throws {
        let hundredOnly = try nutriments(#"{"fat_100g": 3.2}"#)
        #expect(hundredOnly.hasData(per: .perHundred))
        #expect(hundredOnly.hasData(per: .perServing) == false)
        #expect(hundredOnly.isEmpty == false)

        #expect(try nutriments("{}").isEmpty)
    }

    @Test("Nutriments round-trip through Codable for the saved-products store")
    func roundTrip() throws {
        let original = try nutriments(#"{"fat_100g": 3.2, "energy-kcal_100g": 250, "salt_serving": 0.5}"#)
        let restored = try JSONDecoder().decode(Nutriments.self, from: JSONEncoder().encode(original))

        #expect(restored.amount(of: .fat, per: .perHundred) == 3.2)
        #expect(restored.amount(of: .energy, per: .perHundred) == 250)
        #expect(restored.amount(of: .salt, per: .perServing) == 0.5)
    }
}

@Suite("Grades")
struct GradeTests {

    @Test("Only real A–E grades are accepted", arguments: [
        ("a", NutriScore.a), ("E", .e), (" c ", .c),
    ])
    func validGrades(input: String, expected: NutriScore) {
        #expect(NutriScore(apiValue: input) == expected)
    }

    @Test("Placeholder grades are treated as missing, not rendered", arguments: [
        "unknown", "not-applicable", "", "   ", "f", "1",
    ])
    func placeholderGrades(input: String) {
        // These all appear in real payloads; showing them as a badge would be a lie.
        #expect(NutriScore(apiValue: input) == nil)
        #expect(EcoScore(apiValue: input) == nil)
    }

    @Test("A nil grade is missing data")
    func nilGrade() {
        #expect(NutriScore(apiValue: nil) == nil)
        #expect(EcoScore(apiValue: nil) == nil)
    }

    @Test("NOVA groups are bounded to 1–4")
    func novaBounds() {
        #expect(NovaGroup(rawValue: 1) == .unprocessed)
        #expect(NovaGroup(rawValue: 4) == .ultraProcessed)
        #expect(NovaGroup(rawValue: 0) == nil)
        #expect(NovaGroup(rawValue: 5) == nil)
    }
}
