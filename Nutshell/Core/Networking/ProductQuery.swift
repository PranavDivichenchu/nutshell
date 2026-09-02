import Foundation

/// What to ask the database for.
///
/// Free text and a category are genuinely different questions, and conflating them is
/// why browsing used to be wrong. Searching "cereal" matches names, brands and
/// ingredients, so it legitimately returns cereal bars, rice cakes and oatmeal cookies —
/// measured, 15 of the first 16 results were not breakfast cereal. That is correct
/// behaviour for a text search and the wrong answer for a tile labelled "Cereal".
enum ProductQuery: Hashable, Sendable {
    /// Free text the user typed.
    case text(String)
    /// An Open Food Facts category tag, e.g. `en:breakfast-cereals`.
    case category(String)

    /// The tag without its language prefix, which is the form the legacy endpoint wants.
    var categorySlug: String? {
        guard case .category(let tag) = self else { return nil }
        return Tag.slug(from: tag)
    }

    /// The text a user typed, if this came from the search field.
    var searchText: String? {
        guard case .text(let value) = self else { return nil }
        return value
    }
}

/// A category offered on the home screen.
///
/// Every tag here was checked against the live index before being listed; an unlisted or
/// misspelled tag returns an empty screen rather than an error, which is the worst way
/// for this to fail.
struct BrowseCategory: Hashable, Identifiable, Sendable {
    let name: String
    let tag: String
    let symbol: String

    var id: String { tag }
    var query: ProductQuery { .category(tag) }

    static let all: [BrowseCategory] = [
        BrowseCategory(name: "Cereal", tag: "en:breakfast-cereals", symbol: "sun.horizon"),
        BrowseCategory(name: "Crisps", tag: "en:crisps", symbol: "takeoutbag.and.cup.and.straw"),
        BrowseCategory(name: "Chocolate", tag: "en:chocolates", symbol: "square.grid.2x2"),
        BrowseCategory(name: "Yogurt", tag: "en:yogurts", symbol: "drop"),
        BrowseCategory(name: "Bread", tag: "en:breads", symbol: "basket"),
        BrowseCategory(name: "Pasta", tag: "en:pastas", symbol: "fork.knife"),
        BrowseCategory(name: "Peanut butter", tag: "en:peanut-butters", symbol: "circle.hexagongrid"),
        // en:sparkling-waters exists in the taxonomy but is empty; this is the populated one.
        BrowseCategory(name: "Sparkling water", tag: "en:carbonated-waters", symbol: "cup.and.saucer"),
    ]
}
