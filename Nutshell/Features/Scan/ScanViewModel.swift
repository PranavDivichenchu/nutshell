import Foundation
import Observation
import PhotosUI
import SwiftUI

@Observable
@MainActor
final class ScanViewModel {

    enum Phase: Equatable {
        case ready
        case looking(barcode: String)
        case found(Product)
        case notFound(barcode: String)
        case failed(message: String, suggestion: String?)
    }

    private(set) var phase: Phase = .ready
    var manualEntry = ""

    /// Whether the live camera should be shown, versus the photo and manual fallbacks.
    private(set) var cameraAuthorized = false
    let cameraExists = CameraAvailability.hasCamera

    private let service: FoodFactsService

    init(service: FoodFactsService) {
        self.service = service
    }

    var isBusy: Bool {
        if case .looking = phase { return true }
        return false
    }

    /// A barcode must be 8–14 digits; anything else is a typo, not a lookup.
    var manualEntryIsValid: Bool {
        let digits = manualEntry.filter(\.isNumber)
        return digits.count >= 8 && digits.count <= 14
    }

    func requestCameraAccessIfNeeded() async {
        guard cameraExists else { return }
        switch CameraAvailability.authorizationStatus {
        case .authorized:
            cameraAuthorized = true
        case .notDetermined:
            cameraAuthorized = await CameraAvailability.requestAccess()
        default:
            cameraAuthorized = false
        }
    }

    /// Entry point for the live camera, which fires repeatedly while a barcode is in
    /// frame. The busy guard keeps those extra frames from stacking up lookups.
    func lookUp(_ barcode: String) async {
        guard !isBusy else { return }
        await performLookup(barcode)
    }

    private func performLookup(_ barcode: String) async {
        let digits = barcode.filter(\.isNumber)
        guard !digits.isEmpty else {
            phase = .ready
            return
        }

        phase = .looking(barcode: digits)
        do {
            if let product = try await service.product(barcode: digits) {
                phase = .found(product)
            } else {
                phase = .notFound(barcode: digits)
            }
        } catch is CancellationError {
            phase = .ready
        } catch let error as APIError {
            phase = .failed(message: error.errorDescription ?? "Lookup failed",
                            suggestion: error.recoverySuggestion)
        } catch {
            phase = .failed(message: "Lookup failed", suggestion: error.localizedDescription)
        }
    }

    func submitManualEntry() async {
        guard !isBusy else { return }
        await performLookup(manualEntry)
    }

    func scan(photo item: PhotosPickerItem) async {
        guard !isBusy else { return }

        // Decoding the image and looking the result up are one continuous operation from
        // the user's point of view, so they share a single busy state — and the lookup
        // must go through `performLookup`, since the public entry point would see that
        // busy state and refuse to run.
        phase = .looking(barcode: "")
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw BarcodeImageScanner.Failure.unreadableImage
            }
            let barcode = try await BarcodeImageScanner.firstBarcode(in: data)
            await performLookup(barcode)
        } catch let error as BarcodeImageScanner.Failure {
            phase = .failed(message: error.errorDescription ?? "Couldn't read that image",
                            suggestion: error.recoverySuggestion)
        } catch {
            phase = .failed(message: "Couldn't read that image", suggestion: error.localizedDescription)
        }
    }

    func reset() {
        phase = .ready
        manualEntry = ""
    }
}
