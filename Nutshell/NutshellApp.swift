import SwiftUI

@main
struct NutshellApp: App {
    /// Composition root: the one place the live API client is chosen. Everything
    /// downstream depends on the `FoodFactsService` protocol, so previews and tests can
    /// substitute their own without touching a view.
    /// The endpoint named in the brief stays primary; Search-a-licious catches the
    /// roughly one request in three that it drops.
    private let service: FoodFactsService = FallbackFoodFactsService(
        primary: OpenFoodFactsClient(),
        fallback: SearchALiciousClient()
    )

    @State private var saved = SavedProductsStore()
    @State private var recentSearches = RecentSearchesStore()
    @State private var recentlyViewed = RecentlyViewedStore()
    @State private var profile = ProfileStore()
    @State private var compare = CompareStore()
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView(service: service, recentSearches: recentSearches)
                .environment(saved)
                .environment(recentSearches)
                .environment(recentlyViewed)
                .environment(profile)
                .environment(compare)
                .environment(router)
                .environment(\.foodFactsService, service)
                .tint(Theme.accent)
        }
    }
}

struct RootView: View {
    let service: FoodFactsService
    let recentSearches: RecentSearchesStore

    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.tab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppRouter.Tab.home)

            SearchView(service: service, recentSearches: recentSearches)
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(AppRouter.Tab.search)

            SavedView()
                .tabItem { Label("Saved", systemImage: "bookmark.fill") }
                .tag(AppRouter.Tab.saved)

            ProfileView()
                .tabItem { Label("You", systemImage: "person.crop.circle") }
                .tag(AppRouter.Tab.profile)
        }
        // Scanning is a task, not a place — it takes over the screen and hands back a
        // product, so it is a cover rather than a fifth tab.
        .fullScreenCover(isPresented: $router.isScanning) {
            ScanView(service: service)
        }
    }
}
