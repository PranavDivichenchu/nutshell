import Testing
import Foundation
@testable import Nutshell

private func product(_ json: String) throws -> Product {
    try JSONDecoder().decode(Product.self, from: Data(json.utf8))
}

@Suite("Cross-backend decoding")
struct CrossBackendDecodingTests {

    @Test("`brands` decodes whether it arrives as a string or an array")
    func lenientBrands() throws {
        // Legacy endpoint: comma-joined text.
        #expect(try product(#"{"code":"1","brands":"Oatly, Oatly AB"}"#).brand == "Oatly")
        // Search-a-licious: a real array.
        #expect(try product(#"{"code":"1","brands":["Nutella","Ferrero"]}"#).brand == "Nutella")
        #expect(try product(#"{"code":"1","brands":[]}"#).brand == nil)
        #expect(try product(#"{"code":"1","brands":null}"#).brand == nil)
    }

    @Test("A Search-a-licious payload decodes into the same domain model")
    func searchALiciousEnvelope() throws {
        let json = """
        {"hits":[
          {"code":"3017620422003","product_name":"Nutella","brands":["Nutella"],
           "nutriscore_grade":"e","nova_group":4,"allergens_tags":["en:milk","en:nuts"],
           "nutriments":{"fat_100g":30.9,"sugars_100g":56.3}}
         ],
         "count":10000,"page":1,"page_size":20,"page_count":500}
        """
        let decoded = try JSONDecoder().decode(SearchALiciousResponse.self, from: Data(json.utf8))

        #expect(decoded.hits.count == 1)
        #expect(decoded.count?.value == 10000)
        // Unlike the legacy endpoint, this page_count really is a count of pages.
        #expect(decoded.pageCount?.value == 500)

        let hit = try #require(decoded.hits.first)
        #expect(hit.name == "Nutella")
        #expect(hit.brand == "Nutella")
        #expect(hit.declaredAllergens == [.milk, .nuts])
        #expect(hit.nutriments?.amount(of: .fat, per: .perHundred) == 30.9)
    }

    @Test("A record from the search index knows it needs topping up")
    func enrichmentMarker() throws {
        // Search-a-licious carries no ingredient text.
        #expect(try product(#"{"code":"1","product_name":"X"}"#).needsDetailEnrichment)
        #expect(try product(#"{"code":"1","product_name":"X","ingredients_text":"Oats"}"#).needsDetailEnrichment == false)
    }
}

@Suite("Backend fallback")
struct FallbackServiceTests {

    private struct Stub: FoodFactsService {
        var result: Result<SearchPage, Error>
        func search(_ query: String, page: Int) async throws -> SearchPage { try result.get() }
        func product(barcode: String) async throws -> Product? { nil }
    }

    private func page(_ code: String) throws -> SearchPage {
        SearchPage(products: [try product(#"{"code":"\#(code)","product_name":"P"}"#)],
                   page: 1, totalCount: 1, hasMorePages: false)
    }

    @Test("The primary's results are used when it works")
    func prefersPrimary() async throws {
        let service = FallbackFoodFactsService(
            primary: Stub(result: .success(try page("primary"))),
            fallback: Stub(result: .success(try page("fallback")))
        )
        let result = try await service.search("oat", page: 1)
        #expect(result.products.first?.code == "primary")
    }

    @Test("An unavailable primary falls through to the second backend", arguments: [
        APIError.serviceUnavailable, .timedOut, .rateLimited,
    ])
    func fallsBackOnAvailabilityFailures(error: APIError) async throws {
        let service = FallbackFoodFactsService(
            primary: Stub(result: .failure(error)),
            fallback: Stub(result: .success(try page("fallback")))
        )
        let result = try await service.search("oat", page: 1)
        #expect(result.products.first?.code == "fallback")
    }

    /// A malformed response means the primary answered and the answer was wrong.
    /// Retrying elsewhere would hide a real bug behind a second request.
    @Test("A bad response is surfaced rather than papered over", arguments: [
        APIError.unreadableResponse, .offline, .unexpected(statusCode: 404),
    ])
    func doesNotFallBackOnRealErrors(error: APIError) async throws {
        let service = FallbackFoodFactsService(
            primary: Stub(result: .failure(error)),
            fallback: Stub(result: .success(try page("fallback")))
        )
        await #expect(throws: error) { try await service.search("oat", page: 1) }
    }
}

@Suite("Hostile input")
struct HostileInputTests {

    @Test("Non-finite numbers are rejected rather than stored")
    func rejectsNonFinite() throws {
        // JSON has no NaN literal, but the values arrive as strings often enough — and
        // Double("NaN") and Double("inf") both succeed.
        let json = #"{"fat_100g": "NaN", "salt_100g": "inf", "sugars_100g": "3.4"}"#
        let nutriments = try JSONDecoder().decode(Nutriments.self, from: Data(json.utf8))

        #expect(nutriments.amount(of: .fat, per: .perHundred) == nil)
        #expect(nutriments.amount(of: .salt, per: .perHundred) == nil)
        #expect(nutriments.amount(of: .sugars, per: .perHundred) == 3.4)

        // The whole point: JSONEncoder throws on a non-finite Double, so one of these
        // reaching storage used to make every later save of the saved list fail silently.
        #expect(throws: Never.self) { try JSONEncoder().encode(nutriments) }
    }

    @Test("A saved product survives a round-trip even when the source had junk numbers")
    func savedProductRoundTripsDespiteJunk() throws {
        let p = try product(#"{"code":"1","product_name":"X","nutriments":{"fat_100g":"NaN","salt_100g":1.2}}"#)
        let restored = try JSONDecoder().decode(Product.self, from: JSONEncoder().encode(p))
        #expect(restored.nutriments?.amount(of: .salt, per: .perHundred) == 1.2)
    }

    @Test("An out-of-range number does not trap the Int conversion")
    func hugeNumbersDoNotTrap() throws {
        struct Box: Decodable { let v: LenientInt }
        // Int(Double) traps on both of these.
        #expect(try JSONDecoder().decode(Box.self, from: Data(#"{"v": 1e30}"#.utf8)).v.value == nil)
        #expect(try JSONDecoder().decode(Box.self, from: Data(#"{"v": -1e30}"#.utf8)).v.value == nil)
        #expect(try JSONDecoder().decode(Box.self, from: Data(#"{"v": 4}"#.utf8)).v.value == 4)
    }

    @Test("A tag that is only a language prefix does not crash the parser")
    func degenerateTags() {
        // Regression: split(separator:) drops empty subsequences, so "en:" produced a
        // one-element array and indexing [1] trapped.
        #expect(Allergen.matching(tag: "en:") == nil)
        #expect(Tag.humanize(["en:", ":", ""]) == [])
        #expect(Tag.slug(from: "en:") == "")
        #expect(Tag.slug(from: "en:milk") == "milk")
        #expect(Tag.slug(from: "milk") == "milk")
    }
}

@Suite("Data coverage")
struct DataCoverageTests {

    @Test("Eco-Score runs to F, not E")
    func ecoScoreF() throws {
        // Grading the worst products a–e made their whole card disappear.
        #expect(EcoScore(apiValue: "f") == .f)
        let p = try product(#"{"code":"1","product_name":"X","ecoscore_grade":"f"}"#)
        #expect(p.ecoScore == .f)
        #expect(p.hasAnyScore)
    }

    @Test("Carbohydrates are found under the US taxonomy's key too")
    func carbohydrateAlias() throws {
        let us = try JSONDecoder().decode(
            Nutriments.self,
            from: Data(#"{"carbohydrates-total_100g": 52.5, "sugars_100g": 50}"#.utf8)
        )
        // Previously rendered "—" directly above a populated Sugars sub-row.
        #expect(us.amount(of: .carbohydrates, per: .perHundred) == 52.5)

        let standard = try JSONDecoder().decode(
            Nutriments.self, from: Data(#"{"carbohydrates_100g": 12}"#.utf8)
        )
        #expect(standard.amount(of: .carbohydrates, per: .perHundred) == 12)
    }

    @Test("The brand is shown once, not once per view")
    func brandIsNotDuplicated() throws {
        let redundant = try product(#"{"code":"1","product_name":"Nutella","brands":"Nutella"}"#)
        #expect(redundant.displayBrand == nil)
        #expect(redundant.subtitle == nil)

        let distinct = try product(#"{"code":"1","product_name":"Barista Edition","brands":"Oatly"}"#)
        #expect(distinct.displayBrand == "Oatly")
    }
}
