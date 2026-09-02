import Testing
import Foundation
@testable import Nutshell

/// Settings a user typed in have to survive a relaunch. These build a store, change it,
/// throw it away, and build a second one over the same storage — which is what actually
/// happens on next launch.
@MainActor
@Suite("Persistence across launches")
struct PersistenceTests {

    private func defaults(_ name: String) throws -> UserDefaults {
        let suite = "off-persist-\(name)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func product(_ code: String) throws -> Product {
        try JSONDecoder().decode(
            Product.self, from: Data(#"{"code":"\#(code)","product_name":"P\#(code)"}"#.utf8)
        )
    }

    @Test("A dietary profile survives a relaunch")
    func profileSurvives() throws {
        let store = try defaults("profile")

        let first = ProfileStore(defaults: store)
        first.toggle(Allergen.milk)
        first.toggle(Allergen.peanuts)
        first.toggle(DietBadge.vegan)
        first.profile.maximumProcessing = .processed
        first.profile.minimumNutriScore = .c

        // Relaunch.
        let second = ProfileStore(defaults: store)

        #expect(second.profile.avoidedAllergens == [.milk, .peanuts])
        #expect(second.profile.requiredDiets == [.vegan])
        #expect(second.profile.maximumProcessing == .processed)
        #expect(second.profile.minimumNutriScore == .c)
    }

    @Test("Clearing the profile is also persisted, not just forgotten in memory")
    func clearingPersists() throws {
        let store = try defaults("profile-clear")

        let first = ProfileStore(defaults: store)
        first.toggle(Allergen.milk)
        #expect(ProfileStore(defaults: store).profile.avoidedAllergens == [.milk])

        first.reset()
        #expect(ProfileStore(defaults: store).profile.isEmpty)
    }

    @Test("Toggling an allergen off is persisted")
    func togglingOffPersists() throws {
        let store = try defaults("profile-toggle")

        let first = ProfileStore(defaults: store)
        first.toggle(Allergen.milk)
        first.toggle(Allergen.milk)

        #expect(ProfileStore(defaults: store).profile.avoidedAllergens.isEmpty)
    }

    @Test("Recent searches survive a relaunch")
    func recentSearchesSurvive() throws {
        let store = try defaults("recents")

        let first = RecentSearchesStore(defaults: store)
        first.record("oat milk")
        first.record("chocolate")

        #expect(RecentSearchesStore(defaults: store).terms == ["chocolate", "oat milk"])
    }

    @Test("Saved products survive a relaunch")
    func savedProductsSurvive() async throws {
        let url = URL.temporaryDirectory.appending(path: "off-persist-saved-\(#function).json")
        try? FileManager.default.removeItem(at: url)

        let first = SavedProductsStore(fileURL: url)
        first.toggle(try product("1"))
        first.toggle(try product("2"))

        // The write is deliberately asynchronous, so wait for the file rather than
        // assuming it landed.
        try await waitForFile(at: url)

        let second = SavedProductsStore(fileURL: url)
        #expect(second.products.map(\.code) == ["2", "1"])   // most recent first
    }

    @Test("Removing a saved product is persisted too")
    func removalPersists() async throws {
        let url = URL.temporaryDirectory.appending(path: "off-persist-removal-\(#function).json")
        try? FileManager.default.removeItem(at: url)

        let first = SavedProductsStore(fileURL: url)
        let item = try product("1")
        first.toggle(item)
        try await waitForFile(at: url)

        first.toggle(item)   // remove
        try await waitForFile(at: url, containing: "\"code\":\"1\"", absent: true)

        #expect(SavedProductsStore(fileURL: url).products.isEmpty)
    }

    /// Polls briefly for the asynchronous write to land.
    private func waitForFile(
        at url: URL, containing needle: String? = nil, absent: Bool = false
    ) async throws {
        for _ in 0..<60 {
            if let data = try? Data(contentsOf: url) {
                let text = String(decoding: data, as: UTF8.self)
                let matches = needle.map { text.contains($0) } ?? true
                if absent ? !matches : matches { return }
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        Issue.record("the store never wrote to \(url.lastPathComponent)")
    }
}
