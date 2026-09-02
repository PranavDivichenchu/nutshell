import SwiftUI

struct SearchView: View {
    @State private var viewModel: SearchViewModel
    @Environment(SavedProductsStore.self) private var saved
    @Environment(RecentSearchesStore.self) private var recentSearches

    init(service: FoodFactsService, recentSearches: RecentSearchesStore) {
        _viewModel = State(wrappedValue: SearchViewModel(service: service, recentSearches: recentSearches))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                content
            }
            .navigationTitle("Search")
            .navigationDestination(for: Product.self) { ProductDetailView(product: $0) }
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
        List {
            Section {
                ForEach(products) { product in
                    NavigationLink(value: product) {
                        ProductRow(product: product, isSaved: saved.contains(product))
                    }
                    .listRowBackground(Theme.background)
                    .listRowSeparatorTint(Theme.separator)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        saveButton(for: product)
                    }
                    .task {
                        // Prefetch the next page as the end of the list approaches.
                        await viewModel.loadMoreIfNeeded(after: product)
                    }
                }
            } header: {
                Text("\(total.formatted()) \(total == 1 ? "result" : "results")")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .textCase(nil)
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

    private func saveButton(for product: Product) -> some View {
        let isSaved = saved.contains(product)
        return Button {
            saved.toggle(product)
        } label: {
            Label(isSaved ? "Remove" : "Save", systemImage: isSaved ? "bookmark.slash.fill" : "bookmark.fill")
        }
        .tint(isSaved ? .gray : Theme.accent)
    }
}
