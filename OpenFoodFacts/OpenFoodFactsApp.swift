import SwiftUI

@main
struct OpenFoodFactsApp: App {
    /// Composition root: the one place the live API client is chosen. Everything
    /// downstream depends on the `FoodFactsService` protocol, so previews and tests
    /// can substitute their own without touching a view.
    private let service: FoodFactsService = OpenFoodFactsClient()

    @State private var saved = SavedProductsStore()
    @State private var recentSearches = RecentSearchesStore()

    var body: some Scene {
        WindowGroup {
            RootView(service: service, recentSearches: recentSearches)
                .environment(saved)
                .environment(recentSearches)
                .tint(Theme.accent)
        }
    }
}

struct RootView: View {
    let service: FoodFactsService
    let recentSearches: RecentSearchesStore

    var body: some View {
        TabView {
            SearchView(service: service, recentSearches: recentSearches)
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            SavedView()
                .tabItem { Label("Saved", systemImage: "bookmark") }
        }
    }
}
