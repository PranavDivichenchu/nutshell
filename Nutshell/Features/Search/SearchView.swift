import SwiftUI

struct SearchView: View {
    @State private var viewModel: SearchViewModel
    @State private var filters = SearchFilters()
    @State private var isShowingFilters = false
    @State private var isShowingComparison = false

    @Environment(SavedProductsStore.self) private var saved
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
            .navigationDestination(for: Product.self) { ProductDetailView(product: $0) }
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
            .onChange(of: router.pendingQuery) { _, query in
                guard let query else { return }
                viewModel.query = query
                router.pendingQuery = nil
            }
            .sheet(isPresented: $isShowingFilters) {
                SearchFilterSheet(filters: $filters, hasProfile: !profile.profile.isEmpty)
            }
            .sheet(isPresented: $isShowingComparison) {
                CompareView(products: compare.products)
            }
        }
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
        switch viewModel.phase {
        case .idle:
            SearchIdleView(
                recentSearches: recentSearches.terms,
                onSelect: { viewModel.apply(recentSearch: $0) },
                onClearRecents: recentSearches.clear
            )

        case .searching:
            VStack {
                SearchLoadingView()
                Spacer()
            }

        case .results(let products, let total):
            resultsList(products, total: total)

        case .noResults(let query):
            StatusView(
                systemImage: "magnifyingglass",
                title: "No matches",
                message: "Nothing in Open Food Facts matches “\(query)”. Try a broader term or a brand name.",
                actionTitle: "Clear search",
                action: viewModel.clear
            )

        case .failed(let error):
            StatusView(
                systemImage: error.systemImage,
                title: error.errorDescription ?? "Something went wrong",
                message: error.recoverySuggestion ?? "",
                actionTitle: "Try again",
                action: { Task { await viewModel.searchNow() } }
            )
        }
    }

    private func resultsList(_ products: [Product], total: Int) -> some View {
        let visible = filters.apply(to: products, profile: profile.profile)
        let hiddenCount = products.count - visible.count

        return List {
            Section {
                if visible.isEmpty {
                    // Filtering locally can empty a page while the database still has
                    // matches, so say that rather than implying there are none.
                    filteredOutNotice(loaded: products.count)
                        .listRowBackground(Theme.background)
                        .listRowSeparator(.hidden)
                }

                ForEach(visible) { product in
                    NavigationLink(value: product) {
                        ProductRow(
                            product: product,
                            isSaved: saved.contains(product),
                            isComparing: compare.contains(product),
                            verdict: ProductVerdict.evaluate(product, against: profile.profile)
                        )
                    }
                    .listRowBackground(Theme.background)
                    .listRowSeparatorTint(Theme.separator)
                    .productRowActions(for: product)
                    .task {
                        // Prefetch the next page as the end of the list approaches.
                        await viewModel.loadMoreIfNeeded(after: product)
                    }
                }
            } header: {
                resultsHeader(total: total, showing: visible.count, hidden: hiddenCount)
            } footer: {
                if viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView().controlSize(.small)
                        Spacer()
                    }
                    .padding(.vertical, Theme.Spacing.medium)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
    }

    private func resultsHeader(total: Int, showing: Int, hidden: Int) -> some View {
        HStack {
            Text("\(total.formatted()) \(total == 1 ? "result" : "results")")
            if hidden > 0 {
                Text("· \(hidden) hidden by filters")
                    .foregroundStyle(Theme.accent)
            }
            Spacer()
            if filters.sort != .relevance {
                Text(filters.sort.label)
            }
        }
        .font(.footnote)
        .foregroundStyle(Theme.secondaryText)
        .textCase(nil)
    }

    private func filteredOutNotice(loaded: Int) -> some View {
        VStack(spacing: Theme.Spacing.small) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Theme.secondaryText.opacity(0.7))
            Text("Nothing in the first \(loaded) results matches your filters")
                .font(.display(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.primaryText)
                .multilineTextAlignment(.center)
            Text("Scroll to load more, or loosen the filters.")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
            Button("Adjust filters") { isShowingFilters = true }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, Theme.Spacing.large)
                .padding(.vertical, Theme.Spacing.small)
                .background(Theme.accent, in: .capsule)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.section)
    }
}
