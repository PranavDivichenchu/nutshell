import SwiftUI

struct SearchView: View {
    @State private var viewModel: SearchViewModel
    @State private var filters = SearchFilters()
    @State private var isShowingFilters = false
    @State private var isShowingComparison = false

    @Environment(CompareStore.self) private var compare
    @Environment(ProfileStore.self) private var profile
    @Environment(RecentSearchesStore.self) private var recentSearches
    @Environment(AppRouter.self) private var router

    init(service: FoodFactsService, recentSearches: RecentSearchesStore) {
        _viewModel = State(wrappedValue: SearchViewModel(service: service, recentSearches: recentSearches))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                content
            }
            .safeAreaInset(edge: .bottom) {
                CompareTray(isShowingComparison: $isShowingComparison)
            }
            .navigationTitle("Search")
            .navigationDestination(for: Product.self) { ProductDetailView(searchResult: $0) }
            .toolbar { toolbar }
            .searchable(
                text: $viewModel.query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search foods, brands, barcodes"
            )
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            // `.task(id:)` restarts on every keystroke and cancels the run it replaces,
            // which is what makes the debounce inside the view model work.
            .task(id: viewModel.query) {
                await viewModel.searchDebounced()
            }
            // Both hooks are needed. `onChange` catches a hand-off while this tab is
            // already alive; `onAppear` catches the first one after launch, when the tab
            // is built *after* Home has already set the query and so never observes the
            // change at all — the tile silently did nothing in that case.
            .onAppear { consumePendingQuery() }
            .onChange(of: router.pendingQuery) { _, _ in consumePendingQuery() }
            .sheet(isPresented: $isShowingFilters) {
                SearchFilterSheet(filters: $filters, hasProfile: !profile.profile.isEmpty)
            }
            .sheet(isPresented: $isShowingComparison) {
                CompareView(products: compare.products)
            }
        }
    }

    /// Takes a query handed over by another tab, if there is one.
    private func consumePendingQuery() {
        guard let pending = router.pendingQuery else { return }
        viewModel.query = pending
        router.pendingQuery = nil
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { router.isScanning = true } label: {
                Image(systemName: "barcode.viewfinder")
            }
            .tint(Theme.accent)
            .accessibilityLabel("Scan a barcode")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { isShowingFilters = true } label: {
                Image(systemName: filters.isActive
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
            }
            .tint(Theme.accent)
            .accessibilityLabel(filters.isActive
                                ? "Filter and sort, \(filters.activeCount) active"
                                : "Filter and sort")
        }
    }

    @ViewBuilder
    private var content: some View {
        if case .idle = viewModel.phase {
            SearchIdleView(
                recentSearches: recentSearches.terms,
                onSelect: { viewModel.apply(recentSearch: $0) },
                onClearRecents: recentSearches.clear
            )
        } else {
            ProductResultsView(
                viewModel: viewModel,
                filters: $filters,
                emptyMessage: "Nothing in Open Food Facts matches that. Try a broader term or a brand name.",
                onAdjustFilters: { isShowingFilters = true },
                onClearSearch: viewModel.clear
            )
        }
    }
}
