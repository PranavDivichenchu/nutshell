import SwiftUI

/// Where the user tells the app what to watch for.
///
/// Everything here is optional and the app is fully usable with none of it set — but once
/// it is, every row and every detail screen answers "is this for me?" instead of just
/// "what is this?".
struct ProfileView: View {
    @Environment(ProfileStore.self) private var store

    var body: some View {
        @Bindable var store = store

        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                        intro
                        allergenSection
                        dietSection
                        processingSection
                        gradeSection
                        caveat

                        if !store.profile.isEmpty {
                            Button("Clear all preferences") { store.reset() }
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color(light: 0xC2410C, dark: 0xF07C58))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.Spacing.small)
                        }
                    }
                    .padding(Theme.Spacing.medium)
                }
            }
            .navigationTitle("You")
        }
    }

    // MARK: - Sections

    private var intro: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
            Text(store.profile.isEmpty ? "Make it yours" : store.profile.summary)
                .font(.display(.title3, weight: .bold))
                .foregroundStyle(Theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("Tell Nutshell what to look out for and every product will be checked against it as you browse.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var allergenSection: some View {
        SectionCard(
            title: "Allergens to avoid",
            subtitle: "The fourteen allergens European labelling law requires to be declared.",
            systemImage: "exclamationmark.triangle"
        ) {
            FlowLayout(spacing: Theme.Spacing.tight) {
                ForEach(Allergen.allCases) { allergen in
                    let isOn = store.profile.avoidedAllergens.contains(allergen)
                    Button {
                        store.toggle(allergen)
                    } label: {
                        Pill(
                            text: allergen.label,
                            systemImage: isOn ? "checkmark" : nil,
                            tint: isOn ? Color(light: 0xC2410C, dark: 0xF07C58) : Theme.secondaryText
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(allergen.label)
                    .accessibilityAddTraits(isOn ? [.isSelected] : [])
                }
            }
        }
    }

    private var dietSection: some View {
        SectionCard(title: "Diet", systemImage: "leaf") {
            FlowLayout(spacing: Theme.Spacing.tight) {
                ForEach(DietBadge.allCases) { diet in
                    let isOn = store.profile.requiredDiets.contains(diet)
                    Button {
                        store.toggle(diet)
                    } label: {
                        Pill(
                            text: diet.label,
                            systemImage: isOn ? "checkmark" : diet.systemImage,
                            tint: isOn ? Theme.accent : Theme.secondaryText
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? [.isSelected] : [])
                }
            }
        }
    }

    private var processingSection: some View {
        @Bindable var store = store

        return SectionCard(
            title: "Processing",
            subtitle: "Flag products more processed than this on the NOVA scale.",
            systemImage: "gearshape.2"
        ) {
            Picker("Maximum processing", selection: $store.profile.maximumProcessing) {
                Text("No limit").tag(NovaGroup?.none)
                ForEach(NovaGroup.allCases) { group in
                    Text("\(group.rawValue) · \(group.title)").tag(NovaGroup?.some(group))
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.accent)
        }
    }

    private var gradeSection: some View {
        @Bindable var store = store

        return SectionCard(
            title: "Nutri-Score",
            subtitle: "Flag products graded worse than this.",
            systemImage: "chart.bar"
        ) {
            Picker("Minimum Nutri-Score", selection: $store.profile.minimumNutriScore) {
                Text("No limit").tag(NutriScore?.none)
                ForEach(NutriScore.allCases) { score in
                    Text("\(score.letter) or better").tag(NutriScore?.some(score))
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.accent)
        }
    }

    /// Stated plainly rather than buried, because someone with a real allergy might
    /// otherwise take a green tick as a guarantee.
    private var caveat: some View {
        SectionCard(title: "Please read", systemImage: "info.circle", tint: Theme.secondaryText) {
            Text("""
            Open Food Facts is filled in by volunteers, so a product's ingredient list may be incomplete or \
            out of date. Nutshell tells you when it doesn't have enough data to check rather than guessing — \
            but it can't replace reading the packet. If you have a serious allergy, always check the label.
            """)
            .font(.footnote)
            .foregroundStyle(Theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}
