import SwiftUI

/// The ingredient list, with declared allergens picked out inline.
///
/// Allergens arrive as a separate tag array, not as markup inside the text. Matching
/// them back into the paragraph means someone scanning for "milk" or "soy" finds it
/// without reading the whole list — the one thing people genuinely need this text for.
struct IngredientsCard: View {
    let text: String
    let allergens: [String]

    var body: some View {
        SectionCard(
            title: "Ingredients",
            subtitle: allergens.isEmpty ? nil : "Allergens are highlighted",
            systemImage: "list.bullet"
        ) {
            Text(highlighted)
                .font(.subheadline)
                .foregroundStyle(Theme.primaryText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var highlighted: AttributedString {
        var attributed = AttributedString(text)

        for range in allergenWordRanges() {
            let lower = attributed.index(attributed.startIndex, offsetByCharacters: range.lowerBound)
            let upper = attributed.index(attributed.startIndex, offsetByCharacters: range.upperBound)
            attributed[lower..<upper].font = .subheadline.bold()
            attributed[lower..<upper].foregroundColor = Theme.warning
        }

        return attributed
    }

    /// Character-offset ranges of whole words naming a declared allergen.
    ///
    /// Matching on whole words rather than raw substrings is what keeps this readable:
    /// the allergen "nuts" occurs inside "hazelnuts", and highlighting only the tail of
    /// that word looks like a rendering fault rather than a warning.
    private func allergenWordRanges() -> [Range<Int>] {
        let needles = Set(allergens.map { $0.lowercased() }.filter { $0.count >= 3 })
        guard !needles.isEmpty else { return [] }

        var ranges: [Range<Int>] = []
        var word = ""
        var wordStart = 0

        func endWord(at end: Int) {
            defer { word = "" }
            guard !word.isEmpty else { return }
            // Match both directions so "nuts" catches "hazelnuts" and "soybeans"
            // catches "soybean", without short words matching everything.
            let isAllergen = needles.contains { needle in
                word.contains(needle) || (word.count >= 4 && needle.contains(word))
            }
            if isAllergen { ranges.append(wordStart..<end) }
        }

        for (offset, character) in text.enumerated() {
            if character.isLetter {
                if word.isEmpty { wordStart = offset }
                word.append(Character(character.lowercased()))
            } else {
                endWord(at: offset)
            }
        }
        endWord(at: text.count)

        return ranges
    }
}
