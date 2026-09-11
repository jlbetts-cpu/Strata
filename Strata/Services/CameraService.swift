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

    /// Whether the composition guides are drawn.
    ///
    /// It lives here, on the observable service, rather than in a `@State` or
    /// `@AppStorage` on the view. Both of those toggled exactly ONCE and then
    /// stopped — measured through the button's own accessibility value across
    /// four taps: `on → off → off → off`, with the button's frame unchanged
    /// and hittable every time. `isFlashOn`, two points away in the same row
    /// and driven by the same button helper, toggled every time. Whatever the
    /// cause, the observable object is the storage that demonstrably works in
    /// this view.
    /// No `didSet`. A property observer on an `@Observable` stored property
    /// is where the macro's generated accessors and the observer meet, and it
    /// is not a combination to rely on — persistence happens at the call site
    /// instead, which is one line and cannot interfere with observation.
    var showsGuides = UserDefaults.standard.object(forKey: "cameraShowsGuides") as? Bool ?? true

    /// Off / 3 / 10 — the three delays iOS Camera offers.
    var timerSeconds = UserDefaults.standard.integer(forKey: "cameraTimerSeconds")

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
        // Raise the ceiling once, here, or every capture is silently capped at
        // `.balanced` — the setting on `AVCapturePhotoSettings` cannot exceed
        // this and throws if it tries.
        output.maxPhotoQualityPrioritization = .quality
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
            // A new device starts at its own 1x with its own metering. Without
            // this the pill keeps reading whatever the old lens was at, and
            // the first pinch jumps.
            zoom = 1
            exposureBias = 0
            applyPortraitCropIfFront(device)
        } else {
            session.addInput(current)
        }
        session.commitConfiguration()
    }

    /// How much of the front camera's field to crop away by default.
    ///
    /// **The front lens is very wide, and wide is unkind to faces.** At about
    /// 23mm equivalent, anything nearest the lens — which, holding a phone at
    /// arm's length, is your nose — is enlarged relative to everything behind
    /// it, and features drift outwards toward the edges. It is the reason
    /// selfies taken at arm's length rarely look like the person.
    ///
    /// Cropping to roughly 30mm removes most of it. This is not a filter and
    /// nothing is retouched: it is the framing a portrait lens would give, and
    /// it is what Apple's own camera does — on recent phones the front
    /// camera's "1x" IS a crop, with 0.5x offered as the wider view. Here it
    /// is simply where the front camera starts; a pinch still reaches the full
    /// field.
    ///
    /// **Unverifiable on this machine**, like everything else about capture:
    /// the simulator has no camera, so this is reasoned from the optics and
    /// has to be judged on a real phone.
    static let frontPortraitCrop: CGFloat = 1.3

    private func applyPortraitCropIfFront(_ device: AVCaptureDevice) {
        guard device.position == .front else { return }
        let wanted = min(Self.frontPortraitCrop, device.activeFormat.videoMaxZoomFactor)
        guard wanted > 1 else { return }
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = wanted
            device.unlockForConfiguration()
            zoom = wanted
        } catch {
            // A device that will not lock is being reconfigured; the wide
            // framing is a worse default, not a broken one.
        }
    }

    /// The front camera has no lamp, so its flash is the screen. The view owns
    /// that; this says which kind is in play.
    var usesScreenFlash: Bool { facing == .front }

    // MARK: - Frames, for making a head

    /// The video output `HeadCaptureEngine` reads, while a head is being made.
    ///
    /// Attached only then, so the ordinary camera does no extra work. The
    /// session drops to 1080p while it is attached — Vision reads every frame
    /// of a blink, and a 12MP photo-preset frame thirty times a second is
    /// heat for no benefit to a head drawn at 88pt — and goes back to the
    /// photo preset when it is removed.
    private var frameOutput: AVCaptureVideoDataOutput?
    private var presetBeforeFrames: AVCaptureSession.Preset?
    /// The zoom to put back when the head maker is finished with the camera.
    private var zoomBeforeFrames: CGFloat?

    /// Turns to the front lens if it is not already there.
    func useFrontCamera() {
        if facing == .back { flip() }
    }

    /// Hand frames to something that is MEASURING the face rather than
    /// photographing it — the head maker.
    ///
    /// **The portrait crop comes off for the duration.** `frontPortraitCrop`
    /// exists so a selfie is framed at roughly 30mm instead of 23mm, which is
    /// kinder to a face; but it multiplies everything in the frame, and
    /// `HeadFraming` decides distance from the face's height as a FRACTION of
    /// that frame. Measured: the target is 0.34 with a tolerance of 0.08, so a
    /// correctly framed face reads 0.442 at 1.3x — past the ceiling — and the
    /// maker says "Move back a little" however far back you go. To satisfy it
    /// you would have to stand 30% further away than the outline intends.
    /// Reported exactly that way: "its having trouble detecting my head and
    /// saying to move back a little even though im far away."
    ///
    /// A wider field is the right thing here for a second reason: the maker
    /// wants headroom around the head it is cutting out, and a crop is the
    /// opposite of headroom.
    func attachFrames(_ output: AVCaptureVideoDataOutput) {
        guard isConfigured, frameOutput == nil else { return }
        zoomBeforeFrames = zoom
        setZoom(1)
        session.beginConfiguration()
        presetBeforeFrames = session.sessionPreset
        if session.canSetSessionPreset(.hd1920x1080) { session.sessionPreset = .hd1920x1080 }
        guard session.canAddOutput(output) else {
            if let previous = presetBeforeFrames { session.sessionPreset = previous }
            session.commitConfiguration()
            return
        }
        session.addOutput(output)
        if let connection = output.connection(with: .video) {
            // Upright and mirrored, so a frame is the picture in the preview:
            // the face Vision measures is the face you are looking at.
            if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = facing == .front
            }
        }
        session.commitConfiguration()
        frameOutput = output
    }

    func detachFrames() {
        guard let output = frameOutput else { return }
        session.beginConfiguration()
        session.removeOutput(output)
        if let previous = presetBeforeFrames, session.canSetSessionPreset(previous) {
            session.sessionPreset = previous
        }
        session.commitConfiguration()
        frameOutput = nil
        presetBeforeFrames = nil
        // Back to the framing the shutter wants.
        if let previous = zoomBeforeFrames {
            setZoom(previous)
            zoomBeforeFrames = nil
        }
    }

    // MARK: - Zoom

    /// How far in the lens is, as a multiple. 1 is the lens's own field.
    private(set) var zoom: CGFloat = 1

    /// The most this camera will go to.
    ///
    /// Capped at 8 whatever the hardware claims. Past that a wide-angle lens
    /// is enlarging pixels rather than resolving anything, and a control that
    /// keeps moving while the picture stops improving is a control that lies.
    /// The front camera usually maxes out far below it and the `min` handles
    /// that on its own.
    var maxZoom: CGFloat {
        guard let device = input?.device else { return 1 }
        return min(device.activeFormat.videoMaxZoomFactor, 8)
    }

    /// Whether the lens can move at all, so the view can leave the control out
    /// rather than draw one that does nothing.
    var canZoom: Bool { maxZoom > 1.05 }

    // MARK: - Focus and exposure

    /// How far the exposure is pushed, in stops. 0 is what the camera chose.
    private(set) var exposureBias: Float = 0

    /// The range this device will accept, so the view can clamp a drag rather
    /// than discovering the limit by being refused.
    var exposureBiasRange: ClosedRange<Float> {
        guard let device = input?.device else { return 0...0 }
        return device.minExposureTargetBias...device.maxExposureTargetBias
    }

    /// Points the lens at a spot, in DEVICE coordinates (0-1, origin top-left
    /// of the sensor's landscape frame). The view converts from the layer.
    ///
    /// Focus and exposure are pointed together, which is what a tap on the
    /// native camera does: you are not saying "measure light here" or "sharpen
    /// here", you are saying "this is the subject".
    ///
    /// Both modes are set only if the device supports them. A front camera
    /// usually has fixed focus and will refuse `focusPointOfInterest`
    /// entirely — asking anyway throws, and a throw here would take the
    /// exposure change down with it.
    func focus(at point: CGPoint) {
        guard let device = input?.device else { return }
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
            }
            if device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
            }
            if device.isExposureModeSupported(.autoExpose) {
                device.exposureMode = .autoExpose
            }
            // A tap is a fresh reading, so the bias it was carrying no longer
            // describes anything.
            device.setExposureTargetBias(0)
            exposureBias = 0
            device.unlockForConfiguration()
        } catch {
            // Being reconfigured. The next tap carries the same intent.
        }
    }

    /// Pushes the exposure up or down, in stops, clamped to what the device
    /// accepts. Safe to call on every frame of a drag.
    func setExposureBias(_ stops: Float) {
        guard let device = input?.device else { return }
        let clamped = min(max(stops, device.minExposureTargetBias),
                          device.maxExposureTargetBias)
        guard abs(clamped - exposureBias) > 0.01 else { return }
        do {
            try device.lockForConfiguration()
            device.setExposureTargetBias(clamped)
            device.unlockForConfiguration()
            exposureBias = clamped
        } catch { }
    }

    /// Back to whatever the camera decides on its own, everywhere in the
    /// frame. What flipping or leaving the screen should leave behind.
    func resetFocus() {
        guard let device = input?.device else { return }
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.setExposureTargetBias(0)
            exposureBias = 0
            device.unlockForConfiguration()
        } catch { }
    }

    /// Sets the zoom, clamped. Safe to call on every frame of a pinch.
    ///
    /// The device has to be LOCKED to be written to, and a lock left open
    /// makes every later configuration change fail silently — which is why
    /// this is one function and not a begin/change/end trio anybody could get
    /// half-right.
    func setZoom(_ factor: CGFloat) {
        guard let device = input?.device else { return }
        let clamped = min(max(factor, 1), maxZoom)
        guard abs(clamped - zoom) > 0.001 else { return }
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
            zoom = clamped
        } catch {
            // A device that will not lock is one that is being reconfigured.
            // Dropping the frame is right; the next pinch event carries the
            // same intent.
        }
    }

    // MARK: - Capture

    func capture(_ completion: @escaping (UIImage?) -> Void) {
        guard isConfigured, !isCapturing else { completion(nil); return }
        isCapturing = true
        onCaptured = completion

        // The selfie is saved the way you were looking at it.
        //
        // The preview is mirrored — a front camera has to be, or reaching left
        // moves you right and framing yourself is impossible. But
        // `AVCapturePhotoOutput` saves the UNMIRRORED frame by default: the
        // view from the lens, which is how other people see you and is not the
        // face you just composed. Every parting, every crooked smile, is on
        // the wrong side, and it is the single most common "why do I look
        // weird in this photo" complaint.
        //
        // Apple added "Mirror Front Camera" in iOS 14 for exactly this, off by
        // default. Here it is always on, because there is no case in this app
        // where you want a photo that disagrees with the viewfinder you framed
        // it in.
        //
        // Set on the CONNECTION rather than by rotating the UIImage after the
        // fact. `automaticallyAdjustsVideoMirroring` has to be turned off
        // first or the assignment is silently ignored.
        if let connection = output.connection(with: .video) {
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = usesScreenFlash
            }
        }

        let settings = AVCapturePhotoSettings()
        // **Ask for the good pipeline, not the quick one.**
        //
        // `AVCapturePhotoSettings` defaults to `.balanced`, which trades away
        // the multi-frame work — Deep Fusion and the noise reduction that
        // matter most in the indoor light most photographs in this app are
        // taken in, and most of all on the front camera, whose sensor is the
        // smaller one. `.quality` costs a fraction of a second of processing
        // AFTER the shutter, which nobody sees, and it is the difference
        // between a clean face and a noisy one.
        //
        // The output's ceiling has to be raised first: a settings value above
        // `maxPhotoQualityPrioritization` throws.
        // `QualityPrioritization` is not Comparable, but its raw values are
        // ordered speed < balanced < quality, so compare those.
        settings.photoQualityPrioritization =
            output.maxPhotoQualityPrioritization.rawValue >= AVCapturePhotoOutput.QualityPrioritization.quality.rawValue
            ? .quality : output.maxPhotoQualityPrioritization
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
            // No orientation surgery here. Mirroring is set on the capture
            // connection before the shot; rebuilding the UIImage with
            // `.leftMirrored` afterwards also ROTATED it a quarter turn, which
            // is why that approach is wrong and not just redundant.
            self.onCaptured?(data.flatMap(UIImage.init(data:)))
            self.onCaptured = nil
        }
    }
}
