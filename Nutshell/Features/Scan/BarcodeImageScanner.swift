import Foundation
import Vision

/// Finds a barcode inside a still image.
///
/// This exists so the scanner is usable without a camera — from a photo of a package, or
/// a screenshot someone was sent. It is also the only way to exercise the scan flow in
/// the Simulator, which has no camera, so it doubles as the demo path.
enum BarcodeImageScanner {

    /// The symbologies actually printed on food packaging.
    private static let symbologies: [VNBarcodeSymbology] = [.ean13, .ean8, .upce, .code128, .itf14]

    enum Failure: LocalizedError {
        case unreadableImage
        case noBarcodeFound

        var errorDescription: String? {
            switch self {
            case .unreadableImage: "That image couldn't be read"
            case .noBarcodeFound: "No barcode found in that image"
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .unreadableImage: "Try a different photo, or type the digits below."
            case .noBarcodeFound: "Make sure the barcode is in frame, level, and in focus."
            }
        }
    }

    static func firstBarcode(in data: Data) async throws -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw Failure.unreadableImage
        }

        // Vision is synchronous and CPU-bound; keep it off the main actor.
        let payload: String? = await Task.detached(priority: .userInitiated) {
            detect(in: image)
        }.value

        guard let payload else { throw Failure.noBarcodeFound }
        return payload
    }

    /// Tries each detector revision, newest first.
    ///
    /// The newest revision is the most accurate, but it is ML-backed and its inference
    /// context cannot be created in every environment — notably the Simulator, where it
    /// fails outright. The older revisions use a classic image-processing path that still
    /// works there. Walking down the list means the feature degrades in accuracy rather
    /// than disappearing.
    private static func detect(in image: CGImage) -> String? {
        for revision in VNDetectBarcodesRequest.supportedRevisions.sorted(by: >) {
            let request = VNDetectBarcodesRequest()
            request.revision = revision

            // Not every revision supports every symbology; asking for an unsupported one
            // throws, so intersect with what this revision actually offers.
            if let supported = try? request.supportedSymbologies() {
                let wanted = symbologies.filter(supported.contains)
                if !wanted.isEmpty { request.symbologies = wanted }
            }

            guard (try? VNImageRequestHandler(cgImage: image).perform([request])) != nil else {
                continue   // this revision is unavailable here; try an older one
            }

            if let payload = (request.results ?? [])
                .compactMap(\.payloadStringValue)
                .first(where: { !$0.trimmed.isEmpty }) {
                return payload.trimmed
            }
        }
        return nil
    }
}
