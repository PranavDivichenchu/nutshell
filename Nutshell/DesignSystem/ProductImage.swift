import SwiftUI

/// Product photography with a graceful fallback.
///
/// A large share of Open Food Facts entries have no photo, and packshots that do exist
/// are inconsistently cropped on white or transparent backgrounds. Rendering them
/// `.fit` inside a neutral tile keeps a results list visually even instead of ragged.
struct ProductImage: View {
    let url: URL?
    var cornerRadius: CGFloat = Theme.Radius.medium

    var body: some View {
        Rectangle()
            .fill(Theme.surfaceRaised)
            .overlay {
                if let url {
                    AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .padding(4)
                                .transition(.opacity)
                        case .failure:
                            placeholder
                        case .empty:
                            ProgressView().controlSize(.small)
                        @unknown default:
                            placeholder
                        }
                    }
                } else {
                    placeholder
                }
            }
            .clipShape(.rect(cornerRadius: cornerRadius))
            .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Image(systemName: "takeoutbag.and.cup.and.straw")
            .font(.title3)
            .foregroundStyle(Theme.secondaryText.opacity(0.5))
    }
}
