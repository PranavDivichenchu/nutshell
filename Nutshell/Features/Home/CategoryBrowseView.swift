import SwiftUI

/// A single Open Food Facts category.
///
/// Browsing asks a different question from searching, and gets a different screen for
/// it. A tile labelled "Cereal" filters on `en:breakfast-cereals` and returns corn
/// flakes and muesli; the same word typed into the search field matches names, brands
/// and ingredients, and turns up cereal bars and oatmeal cookies. Both are right for
/// what they are, which is why they are no longer the same code path.
struct CategoryBrowseView: View {
    let category: BrowseCategory

    @State private var viewModel: SearchViewModel
    @State private var filters = SearchFilters()
    @State private var isShowingFilters = false
    @State private var isShowingComparison = false

    @Environment(CompareStore.self) private var compare
    @Environment(ProfileStore.self) private var profile

    init(category: BrowseCategory, service: FoodFactsService, recentSearches: RecentSearchesStore) {
        self.category = category
        _viewModel = State(wrappedValue: SearchViewModel(service: service, recentSearches: recentSearches))
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ProductResultsView(
                viewModel: viewModel,
                filters: $filters,
                emptyMessage: "Nothing in this category came back. That usually means the database is busy rather than empty.",
                onAdjustFilters: { isShowingFilters = true }
            )
        }
        .safeAreaInset(edge: .bottom) {
            CompareTray(isShowingComparison: $isShowingComparison)
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { isShowingFilters = true } label: {
                    Image(systemName: filters.isActive
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                }
                .tint(Theme.accent)
                .accessibilityLabel("Filter and sort")
            }
        }
        .task { await viewModel.browse(category) }
        .sheet(isPresented: $isShowingFilters) {
            SearchFilterSheet(filters: $filters, hasProfile: !profile.profile.isEmpty)
        }
        .sheet(isPresented: $isShowingComparison) {
            CompareView(products: compare.products)
        }
    }
}
