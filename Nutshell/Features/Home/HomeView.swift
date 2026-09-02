import SwiftUI

/// The landing screen.
///
/// A search app that opens onto an empty search bar puts the work of thinking of
/// something on the person who just launched it. This opens onto the three things they
/// are most likely to want: scan the thing in their hand, return to something they looked
/// at, or browse.
struct HomeView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ProfileStore.self) private var profile
    @Environment(SavedProductsStore.self) private var saved
    @Environment(RecentlyViewedStore.self) private var recentlyViewed

    /// Each tile runs the search it is named after.
    ///
    /// These used to be aisle names mapped onto different queries — "Breakfast" ran
    /// "cereal", "Dairy" ran "yogurt". Tapping one and landing on a search bar with a
    /// different word in it just reads as a bug, so the label and the query are now the
    /// same string. Broad terms, because they come back well populated.
    private static let shortcuts: [(term: String, symbol: String)] = [
        ("Cereal", "sun.horizon"),
        ("Crisps", "takeoutbag.and.cup.and.straw"),
        ("Chocolate", "square.grid.2x2"),
        ("Yogurt", "drop"),
        ("Bread", "basket"),
        ("Pasta", "fork.knife"),
        ("Peanut butter", "circle.hexagongrid"),
        ("Sparkling water", "cup.and.saucer"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                        scanCard
                        profileCard

                        if !recentlyViewed.products.isEmpty {
                            shelf(title: "Pick up where you left off", products: recentlyViewed.products)
                        }
                        if !saved.products.isEmpty {
                            shelf(title: "Saved", products: saved.products)
                        }

                        shortcutGrid
                    }
                    .padding(Theme.Spacing.medium)
                }
            }
            .navigationTitle("Nutshell")
            .navigationDestination(for: Product.self) { ProductDetailView(searchResult: $0) }
        }
    }

    // MARK: - Scan

    private var scanCard: some View {
        Button {
            router.isScanning = true
        } label: {
            HStack(spacing: Theme.Spacing.medium) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Scan a barcode")
                        .font(.display(.headline))
                        .foregroundStyle(.white)
                    Text("Point at a packet to see what's in it")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(Theme.Spacing.medium)
            .background(
                LinearGradient(
                    colors: [Color(hex: 0x1D7A44), Color(hex: 0x14532D)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                in: .rect(cornerRadius: Theme.Radius.large)
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the barcode scanner")
    }

    // MARK: - Profile

    private var profileCard: some View {
        Button {
            router.tab = .profile
        } label: {
            HStack(spacing: Theme.Spacing.small) {
                Image(systemName: profile.profile.isEmpty ? "person.crop.circle.badge.plus" : "checkmark.seal.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.profile.isEmpty ? "Set what you avoid" : "Checking every product")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                    Text(profile.profile.isEmpty
                         ? "Allergens and diets, so results are checked for you"
                         : profile.profile.summary)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(Theme.Spacing.medium)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.large)
                    .strokeBorder(Theme.separator, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shelves

    private func shelf(title: String, products: [Product]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            sectionTitle(title)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Theme.Spacing.medium) {
                    ForEach(products) { product in
                        NavigationLink(value: product) {
                            ProductCard(
                                product: product,
                                verdict: ProductVerdict.evaluate(product, against: profile.profile)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
            // Let the shelf bleed to the screen edge so it reads as scrollable.
            .padding(.horizontal, -Theme.Spacing.medium)
            .contentMargins(.horizontal, Theme.Spacing.medium, for: .scrollContent)
        }
    }

    private var shortcutGrid: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            sectionTitle("Browse")

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 104), spacing: Theme.Spacing.small)],
                spacing: Theme.Spacing.small
            ) {
                ForEach(Self.shortcuts, id: \.term) { shortcut in
                    Button {
                        router.search(for: shortcut.term)
                    } label: {
                        VStack(spacing: Theme.Spacing.tight) {
                            Image(systemName: shortcut.symbol)
                                .font(.title3)
                                .foregroundStyle(Theme.accent)
                                .accessibilityHidden(true)
                            Text(shortcut.term)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(Theme.primaryText)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.medium)
                        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.medium))
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.Radius.medium)
                                .strokeBorder(Theme.separator, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Search for \(shortcut.term)")
                }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.display(.subheadline, weight: .bold))
            .textCase(.uppercase)
            .kerning(0.6)
            .foregroundStyle(Theme.secondaryText)
    }
}
