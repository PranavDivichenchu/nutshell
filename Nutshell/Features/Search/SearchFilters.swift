import SwiftUI

/// Narrowing and ordering applied to the results already on screen.
///
/// These run locally rather than as API parameters, and the UI says so. The search
/// endpoint's own filtering is unreliable and slow, and re-querying on every toggle would
/// be punishing against a service that rate-limits this hard.
struct SearchFilters: Equatable {
    var maximumProcessing: NovaGroup?
    var minimumNutriScore: NutriScore?
    var requiresCompleteData = false
    /// Hide anything the dietary profile says to avoid.
    var hidesConflicts = false
    var sort: SortOrder = .relevance

    enum SortOrder: String, CaseIterable, Identifiable {
        case relevance, healthiest, leastProcessed, name

        var id: String { rawValue }

        var label: String {
            switch self {
            case .relevance: "Best match"
            case .healthiest: "Best Nutri-Score"
            case .leastProcessed: "Least processed"
            case .name: "Name"
            }
        }
    }

    var isActive: Bool {
        maximumProcessing != nil || minimumNutriScore != nil
            || requiresCompleteData || hidesConflicts || sort != .relevance
    }

    var activeCount: Int {
        var count = 0
        if maximumProcessing != nil { count += 1 }
        if minimumNutriScore != nil { count += 1 }
        if requiresCompleteData { count += 1 }
        if hidesConflicts { count += 1 }
        if sort != .relevance { count += 1 }
        return count
    }

    func apply(to products: [Product], profile: DietaryProfile) -> [Product] {
        var result = products.filter { product in
            if let limit = maximumProcessing {
                // An unknown NOVA group can't be shown to satisfy the limit.
                guard let nova = product.novaGroup, nova.rawValue <= limit.rawValue else { return false }
            }
            if let floor = minimumNutriScore {
                guard let score = product.nutriScore, score.rawValue <= floor.rawValue else { return false }
            }
            if requiresCompleteData {
                guard product.nutriScore != nil,
                      product.nutriments?.hasData(per: .perHundred) == true,
                      product.ingredientsText != nil else { return false }
            }
            if hidesConflicts, !profile.isEmpty {
                let verdict = ProductVerdict.evaluate(product, against: profile)
                guard verdict?.level != .avoid else { return false }
            }
            return true
        }

        switch sort {
        case .relevance:
            break   // the API's own ordering, which is genuinely useful
        case .healthiest:
            // Products with no grade sort last rather than counting as best.
            result.sort { ($0.nutriScore?.rawValue ?? "z") < ($1.nutriScore?.rawValue ?? "z") }
        case .leastProcessed:
            result.sort { ($0.novaGroup?.rawValue ?? .max) < ($1.novaGroup?.rawValue ?? .max) }
        case .name:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        return result
    }
}

/// The filter sheet.
struct SearchFilterSheet: View {
    @Binding var filters: SearchFilters
    let hasProfile: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Sort by") {
                    Picker("Sort", selection: $filters.sort) {
                        ForEach(SearchFilters.SortOrder.allCases) { order in
                            Text(order.label).tag(order)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Only show") {
                    Picker("Processing", selection: $filters.maximumProcessing) {
                        Text("Any").tag(NovaGroup?.none)
                        ForEach(NovaGroup.allCases) { group in
                            Text("NOVA \(group.rawValue) or lower").tag(NovaGroup?.some(group))
                        }
                    }
                    Picker("Nutri-Score", selection: $filters.minimumNutriScore) {
                        Text("Any").tag(NutriScore?.none)
                        ForEach(NutriScore.allCases) { score in
                            Text("\(score.letter) or better").tag(NutriScore?.some(score))
                        }
                    }
                    Toggle("Complete data only", isOn: $filters.requiresCompleteData)
                    if hasProfile {
                        Toggle("Hide what I avoid", isOn: $filters.hidesConflicts)
                    }
                }

                Section {
                    Button("Reset", role: .destructive) { filters = SearchFilters() }
                        .disabled(!filters.isActive)
                } footer: {
                    Text("Filters apply to the results already loaded, not to the whole database. Scroll to load more.")
                }
            }
            .navigationTitle("Filter & sort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.tint(Theme.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
