import Testing
import Foundation
@testable import Nutshell

private func product(_ json: String) throws -> Product {
    try JSONDecoder().decode(Product.self, from: Data(json.utf8))
}

@Suite("Allergen tag matching")
struct AllergenTests {

    @Test("Tags map onto the EU fourteen regardless of language prefix")
    func matching() {
        #expect(Allergen.matching(tag: "en:milk") == .milk)
        #expect(Allergen.matching(tag: "fr:milk") == .milk)
        #expect(Allergen.matching(tag: "milk") == .milk)
        // Slugs that differ from the case name.
        #expect(Allergen.matching(tag: "en:sesame-seeds") == .sesame)
        #expect(Allergen.matching(tag: "en:sulphur-dioxide-and-sulphites") == .sulphites)
    }

    @Test("Free text contributors paste into the tag list does not match anything")
    func rejectsFreeText() {
        // Real values seen in the wild on a German product.
        #expect(Allergen.matching(tag: "VOLLMILCHPULVER") == nil)
        #expect(Allergen.matching(tag: "en:") == nil)
        #expect(Allergen.matching(tag: "") == nil)
    }

    @Test("The summary prefers canonical labels over raw contributor text")
    func labelsPreferCanonical() throws {
        let messy = try product("""
        {"code":"1","allergens_tags":["en:milk","en:nuts","VOLLMILCHPULVER","MANDELN"]}
        """)
        // One clean translated summary rather than four shouting duplicates.
        #expect(messy.allergenLabels == ["Milk", "Tree nuts"])
    }

    @Test("An allergen outside the fourteen still shows rather than vanishing")
    func fallsBackToRawTags() throws {
        let exotic = try product(#"{"code":"1","allergens_tags":["en:carmine"]}"#)
        #expect(exotic.allergenLabels == ["Carmine"])
    }
}

@Suite("Dietary verdict")
struct ProductVerdictTests {

    private var milkFree: DietaryProfile {
        DietaryProfile(avoidedAllergens: [.milk])
    }

    @Test("With no preferences set the app stays silent")
    func noPreferencesYieldsNoVerdict() throws {
        let p = try product(#"{"code":"1","product_name":"X","allergens_tags":["en:milk"]}"#)
        #expect(ProductVerdict.evaluate(p, against: DietaryProfile()) == nil)
    }

    @Test("A declared allergen blocks the product")
    func declaredAllergenBlocks() throws {
        let p = try product("""
        {"code":"1","product_name":"Chocolate","allergens_tags":["en:milk"],"ingredients_text":"Sugar, milk"}
        """)
        let verdict = try #require(ProductVerdict.evaluate(p, against: milkFree))

        #expect(verdict.level == .avoid)
        #expect(verdict.reasons.contains { $0.text == "Contains milk" })
    }

    @Test("A trace warning cautions but does not block")
    func tracesCaution() throws {
        let p = try product("""
        {"code":"1","product_name":"Bar","traces_tags":["en:milk"],"ingredients_text":"Oats, sugar"}
        """)
        let verdict = try #require(ProductVerdict.evaluate(p, against: milkFree))

        #expect(verdict.level == .caution)
        #expect(verdict.reasons.contains { $0.text == "May contain milk" })
    }

    @Test("A declared allergen is not also reported as a trace")
    func declaredWinsOverTrace() throws {
        let p = try product("""
        {"code":"1","product_name":"X","allergens_tags":["en:milk"],"traces_tags":["en:milk"],
         "ingredients_text":"Milk"}
        """)
        let verdict = try #require(ProductVerdict.evaluate(p, against: milkFree))

        #expect(verdict.level == .avoid)
        #expect(verdict.reasons.filter { $0.text.localizedCaseInsensitiveContains("milk") }.count == 1)
    }

    @Test("A clean product with real data matches")
    func cleanProductMatches() throws {
        let p = try product("""
        {"code":"1","product_name":"Oat Drink","allergens_tags":["en:gluten"],
         "ingredients_text":"Water, oats"}
        """)
        let verdict = try #require(ProductVerdict.evaluate(p, against: milkFree))

        #expect(verdict.level == .match)
        #expect(verdict.reasons.isEmpty)
    }

    /// The single most important behaviour in this file. Open Food Facts is mostly
    /// missing ingredient data, and reporting those products as safe would be dangerous.
    @Test("A product with no ingredient data is never reported as safe")
    func absentDataIsNotSafety() throws {
        let bare = try product(#"{"code":"1","product_name":"Mystery snack"}"#)
        let verdict = try #require(ProductVerdict.evaluate(bare, against: milkFree))

        #expect(verdict.level == .unverifiable)
        #expect(verdict.level != .match)
        #expect(verdict.reasons.contains { $0.text.contains("No ingredient data") })
    }

    @Test("A contradicted diet blocks, but an unknown one only flags uncertainty")
    func dietStatusDistinguishesDenialFromSilence() throws {
        let profile = DietaryProfile(requiredDiets: [.vegan])

        let confirmed = try product(#"{"code":"1","product_name":"X","ingredients_analysis_tags":["en:vegan"]}"#)
        #expect(ProductVerdict.evaluate(confirmed, against: profile)?.level == .match)

        let denied = try product(#"{"code":"1","product_name":"X","ingredients_analysis_tags":["en:non-vegan"]}"#)
        #expect(ProductVerdict.evaluate(denied, against: profile)?.level == .avoid)

        // "maybe-vegan" is not a denial, and must not be treated as one.
        let maybe = try product(#"{"code":"1","product_name":"X","ingredients_analysis_tags":["en:maybe-vegan"]}"#)
        #expect(ProductVerdict.evaluate(maybe, against: profile)?.level == .unverifiable)
    }

    @Test("Processing and grade limits produce cautions, not blocks")
    func softPreferences() throws {
        let profile = DietaryProfile(maximumProcessing: .processed, minimumNutriScore: .c)
        let p = try product("""
        {"code":"1","product_name":"X","nova_group":4,"nutriscore_grade":"e","ingredients_text":"Sugar"}
        """)
        let verdict = try #require(ProductVerdict.evaluate(p, against: profile))

        #expect(verdict.level == .caution)
        #expect(verdict.reasons.contains { $0.text.contains("Ultra-processed") })
        #expect(verdict.reasons.contains { $0.text.contains("Nutri-Score E") })
    }

    @Test("A product inside the stated limits passes them")
    func softPreferencesSatisfied() throws {
        let profile = DietaryProfile(maximumProcessing: .processed, minimumNutriScore: .c)
        let p = try product("""
        {"code":"1","product_name":"X","nova_group":2,"nutriscore_grade":"a","ingredients_text":"Oats"}
        """)
        #expect(ProductVerdict.evaluate(p, against: profile)?.level == .match)
    }

    @Test("Blocking reasons outrank cautions in the reported level")
    func blockingOutranksCaution() throws {
        let profile = DietaryProfile(avoidedAllergens: [.milk], maximumProcessing: .unprocessed)
        let p = try product("""
        {"code":"1","product_name":"X","allergens_tags":["en:milk"],"nova_group":4,
         "ingredients_text":"Milk, sugar"}
        """)
        #expect(ProductVerdict.evaluate(p, against: profile)?.level == .avoid)
    }
}

@Suite("Search filters")
struct SearchFilterTests {

    private func products() throws -> [Product] {
        [
            try product(#"{"code":"1","product_name":"Clean","nutriscore_grade":"a","nova_group":1,"ingredients_text":"Oats","nutriments":{"fat_100g":1}}"#),
            try product(#"{"code":"2","product_name":"Junk","nutriscore_grade":"e","nova_group":4,"ingredients_text":"Sugar","nutriments":{"fat_100g":30}}"#),
            try product(#"{"code":"3","product_name":"Bare"}"#),
        ]
    }

    @Test("An unknown grade is not silently treated as passing the filter")
    func unknownValuesDoNotPass() throws {
        var filters = SearchFilters()
        filters.minimumNutriScore = .c

        let result = filters.apply(to: try products(), profile: DietaryProfile())
        #expect(result.map(\.code) == ["1"])   // "3" has no grade and must not sneak through
    }

    @Test("Processing limits exclude both worse and unknown")
    func processingLimit() throws {
        var filters = SearchFilters()
        filters.maximumProcessing = .culinaryIngredient

        #expect(filters.apply(to: try products(), profile: DietaryProfile()).map(\.code) == ["1"])
    }

    @Test("Complete-data-only requires a grade, nutrition, and ingredients together")
    func completeDataOnly() throws {
        var filters = SearchFilters()
        filters.requiresCompleteData = true

        #expect(filters.apply(to: try products(), profile: DietaryProfile()).map(\.code) == ["1", "2"])
    }

    @Test("Hiding conflicts removes what the profile says to avoid")
    func hidesConflicts() throws {
        var filters = SearchFilters()
        filters.hidesConflicts = true
        let items = [
            try product(#"{"code":"1","product_name":"Safe","ingredients_text":"Oats"}"#),
            try product(#"{"code":"2","product_name":"Milky","allergens_tags":["en:milk"],"ingredients_text":"Milk"}"#),
        ]

        let result = filters.apply(to: items, profile: DietaryProfile(avoidedAllergens: [.milk]))
        #expect(result.map(\.code) == ["1"])
    }

    @Test("Sorting puts the best first and pushes unknowns to the end")
    func sorting() throws {
        var filters = SearchFilters()
        filters.sort = .healthiest

        // "Bare" has no grade; it must sort last rather than counting as best.
        #expect(filters.apply(to: try products(), profile: DietaryProfile()).map(\.code) == ["1", "2", "3"])
    }

    @Test("An untouched filter set reports itself inactive")
    func inactiveByDefault() {
        #expect(SearchFilters().isActive == false)
        #expect(SearchFilters().activeCount == 0)
    }
}

@Suite("Compare store")
@MainActor
struct CompareStoreTests {

    @Test("The tray fills to its cap and then refuses more")
    func capacity() throws {
        let store = CompareStore()
        let items = (1...4).map { try! product(#"{"code":"\#($0)","product_name":"P\#($0)"}"#) }

        for item in items.prefix(3) { #expect(store.toggle(item)) }
        #expect(store.isFull)
        #expect(store.canCompare)

        #expect(store.toggle(items[3]) == false)   // rejected, not silently swapped
        #expect(store.products.count == 3)
    }

    @Test("Two products are needed before comparing means anything")
    func needsTwo() throws {
        let store = CompareStore()
        store.toggle(try product(#"{"code":"1","product_name":"One"}"#))
        #expect(store.canCompare == false)

        store.toggle(try product(#"{"code":"2","product_name":"Two"}"#))
        #expect(store.canCompare)
    }
}

@Suite("Reference intake")
struct ReferenceIntakeTests {

    @Test("A fraction of the daily reference is computed per nutrient")
    func fractions() throws {
        let half = try #require(ReferenceIntake.fraction(of: 35, for: .fat))   // 35 of 70 g
        #expect(abs(half - 0.5) < 0.001)

        let full = try #require(ReferenceIntake.fraction(of: 2000, for: .energy))
        #expect(abs(full - 1.0) < 0.001)
    }

    @Test("A wildly mis-entered figure cannot draw a bar off the screen")
    func clamped() throws {
        let huge = try #require(ReferenceIntake.fraction(of: 999_999, for: .salt))
        #expect(huge == 2)
    }

    @Test("Fibre is flagged as a guideline rather than an official reference")
    func fibreIsNotOfficial() {
        #expect(ReferenceIntake.isOfficial(.fiber) == false)
        #expect(ReferenceIntake.isOfficial(.salt))
    }
}
