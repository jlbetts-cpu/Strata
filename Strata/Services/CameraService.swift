import AVFoundation
import UIKit

/// The capture session behind the in-app camera.
///
/// Deliberately thin: configure once, hand back a `UIImage`. Everything about
/// how the camera LOOKS lives in `CameraView`; this only knows how to point a
/// lens at something and read it.
@Observable
@MainActor
final class CameraService: NSObject {

    enum Facing { case back, front }

    /// What the preview layer renders. Handed to the view once and then left
    /// alone — reassigning it mid-session tears down the preview.
    let session = AVCaptureSession()

    private(set) var facing: Facing = .back
    private(set) var isAuthorized = false
    private(set) var isConfigured = false
    /// True while a capture is in flight, so the shutter cannot be re-fired.
    private(set) var isCapturing = false
    /// Front-camera flash is a screen flash, so the view has to know.
    var isFlashOn = false

    private let output = AVCapturePhotoOutput()
    private var input: AVCaptureDeviceInput?
    private let queue = DispatchQueue(label: "camera.session")
    private var onCaptured: ((UIImage?) -> Void)?

    // MARK: - Lifecycle

    func requestAccess() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        default:
            isAuthorized = false
        }
    }

    func start() async {
        await requestAccess()
        guard isAuthorized else { return }
        if !isConfigured { configure() }
        guard isConfigured else { return }
        let session = session
        queue.async { if !session.isRunning { session.startRunning() } }
    }

    func stop() {
        let session = session
        queue.async { if session.isRunning { session.stopRunning() } }
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard let device = camera(for: facing),
              let deviceInput = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(deviceInput),
              session.canAddOutput(output) else {
            session.commitConfiguration()
            return
        }
        session.addInput(deviceInput)
        session.addOutput(output)
        input = deviceInput
        session.commitConfiguration()
        isConfigured = true
    }

    private func camera(for facing: Facing) -> AVCaptureDevice? {
        AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: facing == .back ? .back : .front
        )
    }

    // MARK: - Controls

    func flip() {
        guard isConfigured, let current = input else { return }
        let next: Facing = facing == .back ? .front : .back
        guard let device = camera(for: next),
              let newInput = try? AVCaptureDeviceInput(device: device) else { return }
        session.beginConfiguration()
        session.removeInput(current)
        if session.canAddInput(newInput) {
            session.addInput(newInput)
            input = newInput
            facing = next
        } else {
            session.addInput(current)
        }
        session.commitConfiguration()
    }

    /// The front camera has no lamp, so its flash is the screen. The view owns
    /// that; this says which kind is in play.
    var usesScreenFlash: Bool { facing == .front }

    // MARK: - Capture

    func capture(_ completion: @escaping (UIImage?) -> Void) {
        guard isConfigured, !isCapturing else { completion(nil); return }
        isCapturing = true
        onCaptured = completion

        let settings = AVCapturePhotoSettings()
        // Only the rear camera has a lamp to fire.
        if !usesScreenFlash, output.supportedFlashModes.contains(.on) {
            settings.flashMode = isFlashOn ? .on : .off
        }
        output.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let data = photo.fileDataRepresentation()
        Task { @MainActor in
            self.isCapturing = false
            let image = data.flatMap(UIImage.init(data:))
            // The front camera records what the LENS sees, which is the mirror
            // image of the preview you were looking at. Flipping it back is
            // what makes the photo match the moment you took it.
            let corrected: UIImage?
            if self.facing == .front, let image, let cg = image.cgImage {
                corrected = UIImage(cgImage: cg, scale: image.scale, orientation: .leftMirrored)
            } else {
                corrected = image
            }
            self.onCaptured?(corrected)
            self.onCaptured = nil
        }
    }
}
