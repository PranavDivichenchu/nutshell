import SwiftUI

/// Whether a product fits the person looking at it.
///
/// The whole point of the dietary profile is that this is computed locally and instantly,
/// so it can render in a search row without a second network call.
///
/// The design rule that matters most here: **absence of evidence is never treated as
/// evidence of absence.** Most Open Food Facts records have no allergen data at all, and
/// reporting those as "safe" would be the single most harmful thing this app could do.
/// They resolve to `.unverifiable` instead.
struct ProductVerdict: Equatable {

    enum Level: Int, Comparable, Equatable {
        case match          // meets every stated preference
        case unverifiable   // the data needed to judge simply isn't there
        case caution        // traces, or a soft preference missed
        case avoid          // contains something the user avoids

        static func < (a: Level, b: Level) -> Bool { a.rawValue < b.rawValue }
    }

    struct Reason: Identifiable, Equatable {
        let id: String
        let text: String
    }

    let level: Level
    let reasons: [Reason]

    /// Returned when the user has stated no preferences — the app should stay silent
    /// rather than showing a meaningless green tick on every row.
    static let noPreferences = ProductVerdict(level: .match, reasons: [])

    // MARK: - Evaluation

    static func evaluate(_ product: Product, against profile: DietaryProfile) -> ProductVerdict? {
        guard !profile.isEmpty else { return nil }

        var blocking: [Reason] = []
        var cautions: [Reason] = []
        var gaps: [Reason] = []

        // 1. Declared allergens are hard blocks.
        for allergen in profile.avoidedAllergens.intersection(product.declaredAllergens).sorted(by: { $0.label < $1.label }) {
            blocking.append(Reason(id: "allergen-\(allergen.rawValue)", text: "Contains \(allergen.label.lowercased())"))
        }

        // 2. Traces are a warning, not a block — but they are why someone set the profile.
        for allergen in profile.avoidedAllergens.intersection(product.traceAllergens)
            .subtracting(product.declaredAllergens)
            .sorted(by: { $0.label < $1.label }) {
            cautions.append(Reason(id: "trace-\(allergen.rawValue)", text: "May contain \(allergen.label.lowercased())"))
        }

        // 3. Diet claims: contradicted blocks, merely unknown does not.
        for diet in profile.requiredDiets.sorted(by: { $0.label < $1.label }) {
            switch product.dietStatus(for: diet) {
            case .confirmed:
                continue
            case .contradicted:
                blocking.append(Reason(id: "diet-\(diet.rawValue)", text: "Not \(diet.label.lowercased())"))
            case .unknown:
                gaps.append(Reason(id: "diet-unknown-\(diet.rawValue)", text: "\(diet.label) status unknown"))
            }
        }

        // 4. Soft preferences about processing and nutrition.
        if let limit = profile.maximumProcessing {
            if let nova = product.novaGroup, nova.rawValue > limit.rawValue {
                cautions.append(Reason(id: "nova", text: "\(nova.title) (NOVA \(nova.rawValue))"))
            } else if product.novaGroup == nil {
                gaps.append(Reason(id: "nova-unknown", text: "Processing level unknown"))
            }
        }

        if let floor = profile.minimumNutriScore {
            if let score = product.nutriScore, score.rawValue > floor.rawValue {
                cautions.append(Reason(id: "grade", text: "Nutri-Score \(score.letter)"))
            } else if product.nutriScore == nil {
                gaps.append(Reason(id: "grade-unknown", text: "No Nutri-Score"))
            }
        }

        // 5. The honesty check: if allergens are being avoided but this record carries no
        //    ingredient data, nothing above proved anything.
        if !profile.avoidedAllergens.isEmpty, !product.hasIngredientData {
            gaps.append(Reason(id: "no-ingredients", text: "No ingredient data to check against"))
        }

        if !blocking.isEmpty {
            return ProductVerdict(level: .avoid, reasons: blocking + cautions)
        }
        if !cautions.isEmpty {
            return ProductVerdict(level: .caution, reasons: cautions + gaps)
        }
        if !gaps.isEmpty {
            return ProductVerdict(level: .unverifiable, reasons: gaps)
        }
        return ProductVerdict(level: .match, reasons: [])
    }
}

// MARK: - Presentation

extension ProductVerdict.Level {
    var tint: Color {
        switch self {
        case .match: Color(light: 0x1D7A44, dark: 0x4FBF7B)
        case .unverifiable: Color(light: 0x6B7075, dark: 0x9BA2A8)
        case .caution: Color(light: 0xB45309, dark: 0xE8A33D)
        case .avoid: Color(light: 0xC2410C, dark: 0xF07C58)
        }
    }

    var systemImage: String {
        switch self {
        case .match: "checkmark.circle.fill"
        case .unverifiable: "questionmark.circle.fill"
        case .caution: "exclamationmark.triangle.fill"
        case .avoid: "xmark.octagon.fill"
        }
    }

    var headline: String {
        switch self {
        case .match: "Fits your preferences"
        case .unverifiable: "Not enough data to tell"
        case .caution: "Worth a closer look"
        case .avoid: "Doesn't fit your preferences"
        }
    }

    /// Spoken by VoiceOver in place of the colour, which carries the meaning visually.
    var accessibilityPrefix: String {
        switch self {
        case .match: "Matches your preferences"
        case .unverifiable: "Cannot be verified"
        case .caution: "Caution"
        case .avoid: "Avoid"
        }
    }
}
