import AVFoundation
import SwiftUI

/// Live barcode capture.
///
/// AVFoundation has no SwiftUI equivalent, so this is the one place the app reaches for
/// UIKit. The session is configured and started off the main thread — doing it inline
/// blocks the first frame for long enough to be visible as a stutter.
struct BarcodeCameraView: UIViewControllerRepresentable {
    let onDetect: (String) -> Void

    func makeUIViewController(context: Context) -> BarcodeCameraController {
        let controller = BarcodeCameraController()
        controller.onDetect = onDetect
        return controller
    }

    func updateUIViewController(_ controller: BarcodeCameraController, context: Context) {
        controller.onDetect = onDetect
    }
}

final class BarcodeCameraController: UIViewController {

    /// The symbologies actually printed on food packaging. Narrowing the list measurably
    /// reduces false positives compared with accepting every type AVFoundation supports.
    private static let symbologies: [AVMetadataObject.ObjectType] =
        [.ean13, .ean8, .upce, .code128, .itf14]

    var onDetect: ((String) -> Void)?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "app.nutshell.camera-session")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    /// Guards against the same barcode firing on every frame while the camera lingers.
    private var hasDelivered = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasDelivered = false
        sessionQueue.async { [session] in
            if !session.isRunning { session.startRunning() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Leaving the camera running costs battery and holds the capture device.
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }

        let output = AVCaptureMetadataOutput()
        session.beginConfiguration()
        session.addInput(input)
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        // Must be set after the output is attached, or the types are rejected.
        output.metadataObjectTypes = Self.symbologies.filter(output.availableMetadataObjectTypes.contains)
        session.commitConfiguration()

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer
    }
}

extension BarcodeCameraController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasDelivered,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue?.trimmed,
              !value.isEmpty else { return }

        hasDelivered = true
        onDetect?(value)
    }
}

/// Whether this device can offer live capture at all — false on every simulator, which
/// is why the scan screen always offers a photo and a manual path alongside it.
enum CameraAvailability {
    static var hasCamera: Bool {
        AVCaptureDevice.default(for: .video) != nil
    }

    static var authorizationStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    static func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
}
