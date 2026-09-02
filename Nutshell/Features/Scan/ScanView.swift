import PhotosUI
import SwiftUI

/// The scan screen.
///
/// It offers three ways in on purpose: the camera when there is one, a photo when there
/// isn't, and typing the digits when the barcode is damaged or the light is bad. A
/// scanner that only works in perfect conditions gets abandoned in a shop aisle — and the
/// photo path is also the only way to exercise this flow in the Simulator.
struct ScanView: View {
    @State private var viewModel: ScanViewModel
    @State private var photoItem: PhotosPickerItem?
    @State private var pushedProduct: Product?

    @Environment(\.dismiss) private var dismiss

    init(service: FoodFactsService) {
        _viewModel = State(wrappedValue: ScanViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: Theme.Spacing.large) {
                    captureArea
                        .frame(maxHeight: 380)
                        .clipShape(.rect(cornerRadius: Theme.Radius.large))
                        .padding(.horizontal, Theme.Spacing.medium)

                    alternatives
                        .padding(.horizontal, Theme.Spacing.medium)

                    Spacer(minLength: 0)
                }
                .padding(.top, Theme.Spacing.medium)
            }
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }.tint(Theme.accent)
                }
            }
            .navigationDestination(item: $pushedProduct) { ProductDetailView(searchResult: $0) }
            .task { await viewModel.requestCameraAccessIfNeeded() }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task { await viewModel.scan(photo: item) }
            }
            .onChange(of: viewModel.phase) { _, phase in
                // Hand a successful scan straight to the detail view — the product is the
                // point, not a confirmation screen in between.
                if case .found(let product) = phase {
                    pushedProduct = product
                    viewModel.reset()
                    photoItem = nil
                }
            }
            .sensoryFeedback(.success, trigger: pushedProduct?.code)
        }
    }

    // MARK: - Capture

    @ViewBuilder
    private var captureArea: some View {
        if viewModel.cameraExists && viewModel.cameraAuthorized {
            ZStack {
                BarcodeCameraView { barcode in
                    Task { await viewModel.lookUp(barcode) }
                }
                reticle
                if viewModel.isBusy { busyOverlay }
            }
        } else {
            unavailableCamera
        }
    }

    private var reticle: some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(.white.opacity(0.9), style: StrokeStyle(lineWidth: 3, dash: [14, 10]))
            .frame(height: 150)
            .padding(.horizontal, 36)
            .shadow(radius: 6)
            .overlay(alignment: .bottom) {
                Text("Point at a barcode")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.45), in: .capsule)
                    .offset(y: 34)
            }
            .accessibilityHidden(true)
    }

    private var busyOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
            ProgressView().tint(.white)
        }
        .accessibilityLabel("Looking up product")
    }

    private var unavailableCamera: some View {
        VStack(spacing: Theme.Spacing.small) {
            Image(systemName: viewModel.cameraExists ? "camera.metering.unknown" : "camera.fill")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Theme.secondaryText)

            Text(viewModel.cameraExists ? "Camera access is off" : "No camera on this device")
                .font(.display(.headline))
                .foregroundStyle(Theme.primaryText)

            Text(viewModel.cameraExists
                 ? "Enable camera access in Settings, or use one of the options below."
                 : "Scan from a photo instead, or type the digits under the barcode.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.medium)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .background(Theme.surface)
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.large)
                .strokeBorder(Theme.separator, lineWidth: 1)
        }
    }

    // MARK: - Fallbacks

    private var alternatives: some View {
        VStack(spacing: Theme.Spacing.medium) {
            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                Label("Scan from a photo", systemImage: "photo.on.rectangle.angled")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Theme.accent, in: .capsule)
                    .foregroundStyle(.white)
            }
            .disabled(viewModel.isBusy)

            VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                Text("Or enter the barcode")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)

                HStack(spacing: Theme.Spacing.small) {
                    TextField("8–14 digits", text: $viewModel.manualEntry)
                        .keyboardType(.numberPad)
                        .textContentType(.none)
                        .font(.body.monospacedDigit())
                        .padding(.horizontal, Theme.Spacing.medium)
                        .padding(.vertical, 11)
                        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.medium))
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.Radius.medium)
                                .strokeBorder(Theme.separator, lineWidth: 1)
                        }

                    Button {
                        Task { await viewModel.submitManualEntry() }
                    } label: {
                        Image(systemName: "arrow.right")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                viewModel.manualEntryIsValid ? Theme.accent : Theme.secondaryText.opacity(0.4),
                                in: .circle
                            )
                    }
                    .disabled(!viewModel.manualEntryIsValid || viewModel.isBusy)
                    .accessibilityLabel("Look up barcode")
                }
            }

            status
        }
    }

    @ViewBuilder
    private var status: some View {
        switch viewModel.phase {
        case .looking:
            HStack(spacing: Theme.Spacing.small) {
                ProgressView().controlSize(.small)
                Text("Looking it up…").font(.footnote).foregroundStyle(Theme.secondaryText)
            }
        case .notFound(let barcode):
            scanMessage(
                icon: "questionmark.circle",
                title: "Not in the database",
                detail: "Barcode \(barcode) isn't in Open Food Facts yet. Anyone can add it at openfoodfacts.org.",
                tint: Theme.secondaryText
            )
        case .failed(let message, let suggestion):
            scanMessage(
                icon: "exclamationmark.triangle",
                title: message,
                detail: suggestion ?? "",
                tint: Color(light: 0xC2410C, dark: 0xF07C58)
            )
        case .ready, .found:
            EmptyView()
        }
    }

    private func scanMessage(icon: String, title: String, detail: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.small) {
            Image(systemName: icon).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.primaryText)
                if !detail.isEmpty {
                    Text(detail).font(.footnote).foregroundStyle(Theme.secondaryText)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.medium)
        .background(tint.opacity(0.10), in: .rect(cornerRadius: Theme.Radius.medium))
    }
}
