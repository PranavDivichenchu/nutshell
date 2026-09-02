import Foundation

/// EU reference intakes for an average adult (8400 kJ / 2000 kcal), the same basis used
/// for the "%RI" figures printed on European packaging.
///
/// These turn an abstract "30.9 g of fat" into "44% of a day", which is the number people
/// can actually act on. Deliberately labelled as a generic adult reference in the UI — it
/// is not personalised advice, and the app should not pretend otherwise.
enum ReferenceIntake {

    /// The daily reference amount for a nutrient, in the nutrient's own unit.
    static func daily(for nutrient: Nutrient) -> Double? {
        switch nutrient {
        case .energy: 2000        // kcal
        case .fat: 70             // g
        case .saturatedFat: 20    // g
        case .carbohydrates: 260  // g
        case .sugars: 90          // g
        case .proteins: 50        // g
        case .salt: 6             // g
        // Fibre has no EU reference intake; EFSA's adequate intake is 25 g.
        case .fiber: 25
        }
    }

    /// The fraction of a day's reference intake, clamped so a wildly mis-entered value
    /// cannot draw a bar off the screen.
    static func fraction(of amount: Double, for nutrient: Nutrient) -> Double? {
        guard let daily = daily(for: nutrient), daily > 0 else { return nil }
        return min(amount / daily, 2)
    }

    /// Whether this nutrient's reference is an official EU value, for footnoting.
    static func isOfficial(_ nutrient: Nutrient) -> Bool { nutrient != .fiber }
}
