import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// A colour that resolves differently in light and dark appearance.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }
}

/// The app's visual constants, kept in one place so spacing and colour stay consistent
/// across screens without every view inventing its own numbers.
enum Theme {

    // MARK: - Surfaces

    /// A warm off-white rather than pure white — food photography sits better on it,
    /// and it keeps the cards distinguishable from the page.
    static let background = Color(light: 0xF7F5F0, dark: 0x0E1012)
    static let surface = Color(light: 0xFFFFFF, dark: 0x1B1E21)
    static let surfaceRaised = Color(light: 0xF2EFE9, dark: 0x25292D)
    static let separator = Color(light: 0xE6E1D8, dark: 0x2E3338)
    /// Deliberately a step darker than `surfaceRaised` so loading placeholders stay
    /// visible against the page instead of dissolving into it.
    static let skeleton = Color(light: 0xE8E3D9, dark: 0x2A2F34)

    // MARK: - Content

    static let accent = Color(light: 0x1D7A44, dark: 0x4FBF7B)
    static let primaryText = Color(light: 0x14171A, dark: 0xF2F4F5)
    static let secondaryText = Color(light: 0x6B7075, dark: 0x9BA2A8)

    // MARK: - Metrics

    enum Spacing {
        static let tight: CGFloat = 6
        static let small: CGFloat = 10
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let section: CGFloat = 28
    }

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 14
        static let large: CGFloat = 20
    }
}

// MARK: - Typography

extension Font {
    /// Rounded type for headings gives the app a softer, food-adjacent voice while
    /// staying entirely within the system font.
    static func display(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}

// MARK: - Building blocks

/// The standard content container: a rounded surface with a hairline border.
struct Card<Content: View>: View {
    var padding: CGFloat = Theme.Spacing.medium
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.large)
                    .strokeBorder(Theme.separator, lineWidth: 1)
            }
    }
}

/// A titled group of content. Sections carry their own heading so detail screens can be
/// composed by listing them, in label-then-content order.
struct SectionCard<Content: View>: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    var tint: Color = Theme.accent
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            HStack(spacing: Theme.Spacing.tight) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption)
                        .foregroundStyle(tint)
                }
                Text(title)
                    .font(.display(.subheadline, weight: .bold))
                    .textCase(.uppercase)
                    .kerning(0.6)
                    .foregroundStyle(Theme.secondaryText)
            }

            Card {
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    content
                }
            }
        }
    }
}

/// A small rounded tag used for diet claims, allergens, and additives.
struct Pill: View {
    let text: String
    var systemImage: String?
    var tint: Color = Theme.accent

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage).font(.caption2)
            }
            Text(text)
                .font(.footnote.weight(.medium))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.12), in: .capsule)
        .overlay {
            Capsule().strokeBorder(tint.opacity(0.22), lineWidth: 1)
        }
    }
}

/// Wraps its children onto as many lines as needed — used for pill groups, where a
/// horizontal scroll view would hide content behind an edge.
struct FlowLayout: Layout {
    var spacing: CGFloat = Theme.Spacing.tight

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews: subviews, width: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let projected = current.indices.isEmpty ? size.width : current.width + spacing + size.width

            if projected > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }

            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }

        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
