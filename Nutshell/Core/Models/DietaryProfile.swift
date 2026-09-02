import Foundation

/// The fourteen allergens EU law requires to be declared, which is exactly the set
/// Open Food Facts tags with `allergens_tags` and `traces_tags`.
enum Allergen: String, Codable, CaseIterable, Identifiable, Sendable {
    case gluten, crustaceans, eggs, fish, peanuts, soybeans, milk
    case nuts, celery, mustard, sesame, sulphites, lupin, molluscs

    var id: String { rawValue }

    /// The Open Food Facts tag slug, which does not always match the case name.
    var tagSlug: String {
        switch self {
        case .sesame: "sesame-seeds"
        case .sulphites: "sulphur-dioxide-and-sulphites"
        default: rawValue
        }
    }

    var label: String {
        switch self {
        case .gluten: "Gluten"
        case .crustaceans: "Crustaceans"
        case .eggs: "Eggs"
        case .fish: "Fish"
        case .peanuts: "Peanuts"
        case .soybeans: "Soy"
        case .milk: "Milk"
        case .nuts: "Tree nuts"
        case .celery: "Celery"
        case .mustard: "Mustard"
        case .sesame: "Sesame"
        case .sulphites: "Sulphites"
        case .lupin: "Lupin"
        case .molluscs: "Molluscs"
        }
    }

    var systemImage: String {
        switch self {
        case .gluten: "laurel.leading"
        case .crustaceans, .molluscs, .fish: "fish"
        case .eggs: "oval.portrait"
        case .peanuts, .nuts: "circle.hexagongrid"
        case .soybeans, .lupin: "leaf"
        case .milk: "drop"
        case .celery, .mustard, .sesame: "carrot"
        case .sulphites: "flask"
        }
    }

    /// Matches an Open Food Facts tag such as `en:milk` or `fr:lait`, ignoring the
    /// language prefix since contributors use several.
    static func matching(tag: String) -> Allergen? {
        let normalised = Tag.slug(from: tag).lowercased().trimmed
        guard !normalised.isEmpty else { return nil }
        return allCases.first { $0.tagSlug == normalised || $0.rawValue == normalised }
    }
}

/// What the person using the app is trying to avoid or require.
///
/// Kept as plain data so it can be persisted, diffed, and — importantly — reasoned about
/// without a network call, which is what lets a verdict render instantly in a list row.
struct DietaryProfile: Codable, Equatable, Sendable {
    var avoidedAllergens: Set<Allergen> = []
    var requiredDiets: Set<DietBadge> = []
    /// Products more processed than this are flagged. `nil` means the user doesn't care.
    var maximumProcessing: NovaGroup?
    /// Products graded worse than this are flagged. `nil` means the user doesn't care.
    var minimumNutriScore: NutriScore?

    var isEmpty: Bool {
        avoidedAllergens.isEmpty && requiredDiets.isEmpty
            && maximumProcessing == nil && minimumNutriScore == nil
    }

    /// A one-line summary for the profile tab and the home screen.
    var summary: String {
        guard !isEmpty else { return "No preferences set" }

        var parts: [String] = []
        if !avoidedAllergens.isEmpty {
            let count = avoidedAllergens.count
            parts.append("Avoiding \(count) allergen\(count == 1 ? "" : "s")")
        }
        if !requiredDiets.isEmpty {
            parts.append(requiredDiets.map { $0.label }.sorted().joined(separator: ", "))
        }
        if let maximumProcessing {
            parts.append("NOVA \(maximumProcessing.rawValue) or lower")
        }
        if let minimumNutriScore {
            parts.append("Nutri-Score \(minimumNutriScore.letter) or better")
        }
        return parts.joined(separator: " · ")
    }
}
