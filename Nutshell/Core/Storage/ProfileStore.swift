import Foundation
import Observation

/// The user's dietary profile, persisted across launches.
@Observable
@MainActor
final class ProfileStore {
    private static let defaultsKey = "dietary-profile"

    var profile: DietaryProfile {
        didSet { persist() }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode(DietaryProfile.self, from: data) {
            profile = decoded
        } else {
            profile = DietaryProfile()
        }
    }

    func toggle(_ allergen: Allergen) {
        if profile.avoidedAllergens.contains(allergen) {
            profile.avoidedAllergens.remove(allergen)
        } else {
            profile.avoidedAllergens.insert(allergen)
        }
    }

    func toggle(_ diet: DietBadge) {
        if profile.requiredDiets.contains(diet) {
            profile.requiredDiets.remove(diet)
        } else {
            profile.requiredDiets.insert(diet)
        }
    }

    func reset() {
        profile = DietaryProfile()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
