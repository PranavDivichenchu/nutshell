import SwiftUI

/// Renders whatever state a product query is in.
///
/// Shared by the Search tab and the category browse screen so the two cannot drift
/// apart: same rows, same filtering, same pagination, same error handling.
struct ProductResultsView: View {
    let viewModel: SearchViewModel
    @Binding var filters: SearchFilters

    /// What to say when the query itself returned nothing.
    let emptyMessage: String
    let onAdjustFilters: () -> Void
    /// Offered on the empty state. Absent for a category, which has nothing to clear.
    var onClearSearch: (() -> Void)?

    @Environment(SavedProductsStore.self) private var saved
    @Environment(CompareStore.self) private var compare
    @Environment(ProfileStore.self) private var profile

    var body: some View {
        switch viewModel.phase {
        case .idle:
            Color.clear

        case .searching:
            VStack {
                SearchLoadingView()
                Spacer()
            }

        case .results(let products, let total):
            list(products, total: total)

        case .noResults:
            StatusView(
                systemImage: "magnifyingglass",
                title: "No matches",
                message: emptyMessage,
                actionTitle: onClearSearch == nil ? nil : "Clear search",
                action: onClearSearch
            )

        case .failed(let error):
            StatusView(
                systemImage: error.systemImage,
                title: error.errorDescription ?? "Something went wrong",
                message: error.recoverySuggestion ?? "",
                actionTitle: "Try again",
                action: { Task { await viewModel.retry() } }
            )
        }
    }

    private func list(_ products: [Product], total: Int) -> some View {
        let visible = filters.apply(to: products, profile: profile.profile)
        let hidden = products.count - visible.count

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
                header(total: total, hidden: hidden)
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

    private func header(total: Int, hidden: Int) -> some View {
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
                .foregroundStyle(Theme.secondaryText)
                .accessibilityHidden(true)
            Text("Nothing in the first \(loaded) results matches your filters")
                .font(.display(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.primaryText)
                .multilineTextAlignment(.center)
            Text("Scroll to load more, or loosen the filters.")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
            Button(action: onAdjustFilters) {
                Text("Adjust filters")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.Spacing.large)
                    .frame(minHeight: 44)
                    .background(Theme.accentFill, in: .capsule)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.section)
    }
}
