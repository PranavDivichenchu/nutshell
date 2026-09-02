import Testing
import Foundation
@testable import Nutshell

@Suite("Product presentation")
struct ProductTests {

    private func product(_ json: String) throws -> Product {
        try JSONDecoder().decode(Product.self, from: Data(json.utf8))
    }

    @Test("The name falls back through the API's several name fields")
    func nameFallback() throws {
        #expect(try product(#"{"code":"1","product_name":"Oat Drink"}"#).name == "Oat Drink")
        #expect(try product(#"{"code":"1","product_name":"","generic_name":"Oat drink"}"#).name == "Oat drink")
        #expect(try product(#"{"code":"1"}"#).name == "Unnamed product")
        #expect(try product(#"{"code":"1"}"#).hasName == false)
        #expect(try product(#"{"code":"1","product_name":"  "}"#).hasName == false)
    }

    @Test("Only the first of several comma-packed brands is shown")
    func brandParsing() throws {
        #expect(try product(#"{"code":"1","brands":"Oatly, Oatly AB"}"#).brand == "Oatly")
        #expect(try product(#"{"code":"1","brands":""}"#).brand == nil)
        #expect(try product(#"{"code":"1"}"#).brand == nil)
    }

    @Test("A brand the product name already leads with is not repeated")
    func subtitleDropsRedundantBrand() throws {
        // Real case: name "Nutella", brand "Nutella" would read "Nutella / Nutella".
        let redundant = try product(#"{"code":"1","product_name":"Nutella","brands":"Nutella","quantity":"400 g"}"#)
        #expect(redundant.subtitle == "400 g")

        let distinct = try product(#"{"code":"1","product_name":"Nutella Plant-Based","brands":"Ferrero","quantity":"350 g"}"#)
        #expect(distinct.subtitle == "Ferrero · 350 g")

        let brandOnly = try product(#"{"code":"1","product_name":"Spread","brands":"Ferrero"}"#)
        #expect(brandOnly.subtitle == "Ferrero")

        #expect(try product(#"{"code":"1","product_name":"Spread"}"#).subtitle == nil)
    }

    @Test("A quantity with no number is contributor noise, not a quantity")
    func quantityNeedsANumber() throws {
        // Seen in the wild: quantity saved as a bare unit, which renders as "Brand · g".
        #expect(try product(#"{"code":"1","quantity":"g"}"#).quantity == nil)
        #expect(try product(#"{"code":"1","quantity":"250 g"}"#).quantity == "250 g")
        #expect(try product(#"{"code":"1","quantity":"1l"}"#).quantity == "1l")
        #expect(try product(#"{"code":"1","quantity":""}"#).quantity == nil)
    }

    @Test("Only positively confirmed diet claims become badges")
    func dietBadgesAreConservative() throws {
        let confirmed = try product(#"{"code":"1","ingredients_analysis_tags":["en:vegan","en:palm-oil-free"]}"#)
        #expect(Set(confirmed.dietBadges) == [.vegan, .palmOilFree])

        // "maybe-" and "non-" variants must never render as a positive claim — a false
        // "Vegan" badge is the most harmful thing this screen could show.
        let unconfirmed = try product(#"{"code":"1","ingredients_analysis_tags":["en:maybe-vegan","en:non-vegetarian","en:palm-oil-content-unknown"]}"#)
        #expect(unconfirmed.dietBadges.isEmpty)
    }

    @Test("Tags are stripped of their language prefix and humanised")
    func tagHumanising() throws {
        let p = try product(#"{"code":"1","allergens_tags":["en:gluten","fr:lait"],"additives_tags":["en:e340","en:carmine"]}"#)
        #expect(p.allergens == ["Gluten", "Lait"])          // non-en prefixes still parse
        #expect(p.additives.contains("E340"))               // E-numbers stay uppercase
        #expect(p.additives.contains("Carmine"))            // ordinary names stay title case
    }

    @Test("Nutrient levels pair with their amounts and ignore unknown values")
    func nutrientLevels() throws {
        let p = try product("""
        {"code":"1","nutrient_levels":{"fat":"high","salt":"low","sugars":"bogus"},
         "nutriments":{"fat_100g":30.9}}
        """)
        let levels = Dictionary(uniqueKeysWithValues: p.nutrientLevels.map { ($0.nutrient, $0.level) })

        #expect(levels[.fat] == .high)
        #expect(levels[.salt] == .low)
        #expect(levels[.sugars] == nil)   // unparseable level is dropped, not defaulted
    }

    @Test("A record with nothing but a barcode is recognised as sparse")
    func sparseDetection() throws {
        #expect(try product(#"{"code":"1","product_name":"Crackers","nutriments":{}}"#).isSparse)
        #expect(try product(#"{"code":"1","product_name":"X","nutriscore_grade":"b"}"#).isSparse == false)
        #expect(try product(#"{"code":"1","product_name":"X","ingredients_text":"Water"}"#).isSparse == false)
    }

    @Test("NOVA parses whether the API sends a number or a string")
    func novaAcceptsBothEncodings() throws {
        #expect(try product(#"{"code":"1","nova_group":4}"#).novaGroup == .ultraProcessed)
        #expect(try product(#"{"code":"1","nova_group":"3"}"#).novaGroup == .processed)
        #expect(try product(#"{"code":"1","nova_group":null}"#).novaGroup == nil)
        #expect(try product(#"{"code":"1"}"#).novaGroup == nil)
    }

    @Test("A product survives the round-trip the saved list depends on")
    func codableRoundTrip() throws {
        let original = try #require(Product.previews.first)
        let restored = try JSONDecoder().decode(Product.self, from: JSONEncoder().encode(original))

        #expect(restored.code == original.code)
        #expect(restored.name == original.name)
        #expect(restored.brand == original.brand)
        #expect(restored.nutriScore == original.nutriScore)
        #expect(restored.novaGroup == original.novaGroup)
        #expect(restored.ecoScore == original.ecoScore)
        #expect(restored.allergens == original.allergens)
        #expect(restored.dietBadges == original.dietBadges)
        #expect(restored.ingredientsText == original.ingredientsText)
        #expect(restored.nutriments?.amount(of: .fat, per: .perHundred)
                == original.nutriments?.amount(of: .fat, per: .perHundred))
        #expect(restored == original)
    }
}

@Suite("Saved products store")
@MainActor
struct SavedProductsStoreTests {

    /// Each test gets its own file so they can run concurrently without sharing state.
    private func makeStore(_ name: String) -> SavedProductsStore {
        let url = URL.temporaryDirectory.appending(path: "off-tests-\(name).json")
        try? FileManager.default.removeItem(at: url)
        return SavedProductsStore(fileURL: url)
    }

    @Test("Toggling adds, then removes")
    func toggle() throws {
        let store = makeStore("toggle")
        let product = try #require(Product.previews.first)

        #expect(store.contains(product) == false)
        #expect(store.toggle(product) == true)
        #expect(store.products.count == 1)
        #expect(store.contains(product))

        #expect(store.toggle(product) == false)
        #expect(store.products.isEmpty)
        #expect(store.contains(product) == false)
    }

    @Test("Newly saved products come first")
    func mostRecentFirst() throws {
        let store = makeStore("order")
        #expect(Product.previews.count >= 2)

        store.toggle(Product.previews[0])
        store.toggle(Product.previews[1])

        #expect(store.products.first?.code == Product.previews[1].code)
    }

    @Test("Removing by offset keeps the membership index consistent")
    func removeAtOffsets() throws {
        let store = makeStore("remove")
        for product in Product.previews { store.toggle(product) }
        let removed = try #require(store.products.first)

        store.remove(atOffsets: IndexSet(integer: 0))

        #expect(store.contains(removed) == false)
        #expect(store.products.count == Product.previews.count - 1)
    }
}

@Suite("Recent searches store")
@MainActor
struct RecentSearchesStoreTests {

    private func makeStore(_ name: String) throws -> RecentSearchesStore {
        let defaults = try #require(UserDefaults(suiteName: "off-tests-\(name)"))
        defaults.removePersistentDomain(forName: "off-tests-\(name)")
        return RecentSearchesStore(defaults: defaults)
    }

    @Test("Repeating a search moves it to the top instead of duplicating it")
    func deduplicates() throws {
        let store = try makeStore("dedupe")
        store.record("oat milk")
        store.record("yogurt")
        store.record("OAT MILK")   // case-insensitive match

        #expect(store.terms == ["OAT MILK", "yogurt"])
    }

    @Test("History is capped and blank terms are ignored")
    func capAndBlanks() throws {
        let store = try makeStore("cap")
        for index in 0..<20 { store.record("term \(index)") }
        #expect(store.terms.count == 8)
        #expect(store.terms.first == "term 19")

        store.record("   ")
        #expect(store.terms.count == 8)
        #expect(store.terms.first == "term 19")
    }
}
