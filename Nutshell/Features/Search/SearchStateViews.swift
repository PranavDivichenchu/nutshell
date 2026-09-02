import SwiftUI

// MARK: - Idle

/// What fills the screen before anyone has typed anything.
///
/// A bare search bar puts the burden of thinking up a query on the user. Recent
/// searches and a few starting points make the first tap obvious.
struct SearchIdleView: View {
    let recentSearches: [String]
    let onSelect: (String) -> Void
    let onClearRecents: () -> Void

    /// Broad, common categories chosen to return dense, well-populated results —
    /// a first impression of the database at its best rather than its patchiest.
    private static let suggestions = [
        "Oat milk", "Greek yogurt", "Dark chocolate", "Granola",
        "Olive oil", "Hummus", "Sparkling water", "Peanut butter",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                if !recentSearches.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                        HStack {
                            sectionTitle("Recent")
                            Spacer()
                            Button("Clear", action: onClearRecents)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(Theme.accent)
                        }

                        VStack(spacing: 0) {
                            ForEach(Array(recentSearches.enumerated()), id: \.element) { index, term in
                                Button { onSelect(term) } label: {
                                    HStack(spacing: Theme.Spacing.small) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.footnote)
                                            .foregroundStyle(Theme.secondaryText)
                                        Text(term)
                                            .foregroundStyle(Theme.primaryText)
                                        Spacer()
                                        Image(systemName: "arrow.up.left")
                                            .font(.caption)
                                            .foregroundStyle(Theme.secondaryText.opacity(0.6))
                                    }
                                    .font(.subheadline)
                                    .padding(.vertical, 11)
                                    .contentShape(.rect)
                                }
                                .buttonStyle(.plain)

                                if index < recentSearches.count - 1 {
                                    Divider().overlay(Theme.separator)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.medium)
                        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.large))
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.Radius.large)
                                .strokeBorder(Theme.separator, lineWidth: 1)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    sectionTitle(recentSearches.isEmpty ? "Try searching for" : "Popular")
                    FlowLayout(spacing: Theme.Spacing.tight) {
                        ForEach(Self.suggestions, id: \.self) { suggestion in
                            Button { onSelect(suggestion) } label: {
                                Pill(text: suggestion)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(Theme.Spacing.medium)
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

// MARK: - Loading

/// Placeholder rows shaped like real results.
///
/// A skeleton rather than a spinner because the layout is known in advance: the list
/// doesn't jump when content lands, and the wait reads as progress instead of a stall.
struct SearchLoadingView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                HStack(spacing: Theme.Spacing.medium) {
                    RoundedRectangle(cornerRadius: Theme.Radius.medium)
                        .fill(Theme.skeleton)
                        .frame(width: 62, height: 62)

                    VStack(alignment: .leading, spacing: 7) {
                        Capsule().fill(Theme.skeleton).frame(width: 190, height: 12)
                        Capsule().fill(Theme.skeleton).frame(width: 110, height: 10)
                    }

                    Spacer()

                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.skeleton)
                        .frame(width: 28, height: 28)
                }
                .padding(.vertical, Theme.Spacing.small)
                .opacity(isAnimating ? 0.45 : 1)
                .animation(
                    .easeInOut(duration: 0.85)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.06),
                    value: isAnimating
                )
            }
        }
        .padding(.horizontal, Theme.Spacing.medium)
        .onAppear { isAnimating = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Searching")
    }
}

// MARK: - Terminal states

/// The shared shape for "nothing to show and here's why", with an optional action.
struct StatusView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Theme.Spacing.medium) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(Theme.secondaryText.opacity(0.7))

            VStack(spacing: Theme.Spacing.tight) {
                Text(title)
                    .font(.display(.title3, weight: .bold))
                    .foregroundStyle(Theme.primaryText)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.Spacing.large)
                    .padding(.vertical, Theme.Spacing.small)
                    .background(Theme.accent, in: .capsule)
            }
        }
        .padding(Theme.Spacing.large)
        .frame(maxWidth: .infinity)
    }
}
