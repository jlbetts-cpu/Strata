import AVFoundation
import UIKit
import os

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
    /// Filled by the delegate while one shutter press is in flight. A RAW
    /// capture delivers two photographs and they arrive in either order, so
    /// both are held and the choice is made once at the end.
    private var capturedRaw: Data?
    private var capturedProcessed: UIImage?
    private var capturedMirrored = false

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

    /// **Returns when the session is actually running.**
    ///
    /// It used to dispatch `startRunning` onto `queue` and return
    /// immediately, so the caller's very next line ran on the main actor
    /// BESIDE the start. `AVCaptureSession` raises an Objective-C exception
    /// when it is reconfigured underneath a start, and an Objective-C
    /// exception is not something Swift can catch: it goes to
    /// `std::terminate`. That is what terminated the app on his phone, inside
    /// `-[AVCaptureSession startRunning]` on thread 5.
    ///
    /// Awaiting the queue makes the ordering a property of the code rather
    /// than of timing: everything a caller writes after `await start()` is
    /// strictly after the session is up, whichever thread it then runs on.
    func start() async {
        await requestAccess()
        guard isAuthorized else { return }
        if !isConfigured { configure() }
        guard isConfigured else { return }
        let session = session
        wantsRunning = true
        watchForTrouble()
        await withCheckedContinuation { continuation in
            queue.async {
                if !session.isRunning { session.startRunning() }
                continuation.resume()
            }
        }
    }

    func stop() {
        wantsRunning = false
        isInterrupted = false
        // Nothing points at a lens after this, so nothing should be holding a
        // reading from one either.
        resetFocus()
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
        // Made here, once, so it has the whole session to track gravity. See
        // `rotation`.
        rotation = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
        // The base has to be known before any zoom is read or set, because
        // every number this class publishes is divided by it.
        zoomBase = lensBase(for: device, facing: facing)
        zoom = 1
        setLensToOneX(device)
        watchForSceneChanges()
    }

    /// **Every lens the phone has, not just the middle one.**
    ///
    /// This asked for `.builtInWideAngleCamera`, which is the 1x lens and
    /// only the 1x lens. On a phone with three cameras that meant the
    /// ultra-wide and the telephoto were never opened: 0.5x did not exist,
    /// 2x was a digital crop of the main sensor, and the two other pieces of
    /// glass in somebody's pocket went unused for the whole life of the app.
    /// It is the first thing anybody coming from the system camera reaches
    /// for.
    ///
    /// A VIRTUAL device is the answer rather than three real ones. It
    /// presents the whole stack as one input and hands over between the
    /// physical lenses itself as the zoom factor crosses
    /// `virtualDeviceSwitchOverVideoZoomFactors` — which is what makes the
    /// handover seamless, because the session never reconfigures and the
    /// preview never blinks. Switching devices by hand is the version that
    /// stutters.
    ///
    /// Asked for in order of how much glass each one carries, so a Pro gets
    /// all three and a phone with two gets both. The plain wide angle is last
    /// and is what an older phone, an iPad or the front camera resolves to,
    /// where the rest of this simply collapses to what it always was.
    private func camera(for facing: Facing) -> AVCaptureDevice? {
        guard facing == .back else {
            return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        }
        let preferred: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,     // ultra-wide + wide + telephoto
            .builtInDualWideCamera,   // ultra-wide + wide
            .builtInDualCamera,       // wide + telephoto
            .builtInWideAngleCamera   // one lens, which is what this used to be
        ]
        let found = AVCaptureDevice.DiscoverySession(deviceTypes: preferred,
                                                     mediaType: .video,
                                                     position: .back).devices
        for type in preferred {
            if let device = found.first(where: { $0.deviceType == type }) { return device }
        }
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }

    /// **The device factor that people call 1x.**
    ///
    /// `videoZoomFactor` is measured from a virtual device's WIDEST lens, so
    /// on anything with an ultra-wide, factor 1.0 is the 0.5x view and the
    /// familiar 1x lives at the first switchover point. Every number this
    /// class publishes is divided by this, so `zoom` means what it says on
    /// the screen and nothing above this line has to think about it.
    ///
    /// The front camera's base is its portrait crop for the same reason: its
    /// 1x is a crop on Apple's own phones too, and pinching out from it
    /// reaches the full field.
    private func lensBase(for device: AVCaptureDevice, facing: Facing) -> CGFloat {
        if facing == .front {
            return min(Self.frontPortraitCrop, device.activeFormat.videoMaxZoomFactor)
        }
        guard device.constituentDevices.first?.deviceType == .builtInUltraWideCamera,
              let first = device.virtualDeviceSwitchOverVideoZoomFactors.first else { return 1 }
        return CGFloat(truncating: first)
    }

    /// Where the physical lenses are, in the numbers shown on screen: 0.5, 1,
    /// and whatever this phone's telephoto is. One entry on a phone with one
    /// lens, and the control that offers them hides itself.
    /// The stop a tap on the lens control should go to: the next one up, and
    /// back to the widest from the top. Somewhere between two stops, it goes
    /// to the one above, so a pinch followed by a tap tidies up rather than
    /// jumping backwards.
    var nextStop: CGFloat { Self.stop(after: zoom, in: opticalStops) }

    var opticalStops: [CGFloat] {
        guard let device = input?.device else { return [1] }
        return Self.stops(base: zoomBase,
                          switchovers: device.virtualDeviceSwitchOverVideoZoomFactors.map {
                              CGFloat(truncating: $0)
                          },
                          minZoom: minZoom, maxZoom: maxZoom)
    }

    /// **The stops, as arithmetic**, so the mapping can be checked on a
    /// machine with no camera — which is the only place any of this can be
    /// checked at all.
    ///
    /// `switchovers` are device factors, as the device reports them; `base`
    /// is the one that equals 1x. Out comes the list of numbers a person
    /// reads on the control.
    nonisolated static func stops(base: CGFloat, switchovers: [CGFloat],
                                  minZoom: CGFloat, maxZoom: CGFloat) -> [CGFloat] {
        guard base > 0 else { return [1] }
        var stops: [CGFloat] = [1 / base]
        stops.append(contentsOf: switchovers.map { $0 / base })
        if !stops.contains(where: { abs($0 - 1) < 0.01 }) { stops.append(1) }
        return stops.sorted()
            .filter { $0 >= minZoom - 0.001 && $0 <= maxZoom + 0.001 }
    }

    /// The next stop up, wrapping to the widest from the top. From somewhere
    /// between two stops it goes to the one ABOVE, so a pinch followed by a
    /// tap tidies up rather than jumping backwards.
    nonisolated static func stop(after zoom: CGFloat, in stops: [CGFloat]) -> CGFloat {
        guard let first = stops.first, let last = stops.last else { return 1 }
        if let above = stops.first(where: { $0 > zoom + 0.01 }) { return above }
        return zoom > last - 0.01 ? first : last
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
            zoomBase = lensBase(for: device, facing: next)
            zoom = 1
            exposureBias = 0
            // A new device starts at its own metering, so the look's pull has
            // to be put back on it or the next frame is a stop bright.
            applyExposure()
            // And a new device needs its own coordinator: the front sensor is
            // mounted differently from the back one on recent phones.
            rotation = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
            setLensToOneX(device)
        } else {
            session.addInput(current)
        }
        session.commitConfiguration()
        // The connection is new after a flip, so the graded surface has to be
        // told which way up it is and whether it is a selfie.
        reorientPreviewFrames()
    }

    /// How much of the front camera's field its 1x is.
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
    /// camera's "1x" IS a crop, with 0.5x offered as the wider view.
    ///
    /// **It is the front camera's `lensBase` now**, rather than a one-off
    /// crop applied after a flip. That is the same idea expressed once: a
    /// lens has a factor its 1x sits at, the back camera's is its ultra-wide
    /// switchover, the front camera's is this, and pinching out from either
    /// reaches the full field the glass can see.
    static let frontPortraitCrop: CGFloat = 1.3

    /// Puts a freshly attached lens at the 1x its own base defines.
    private func setLensToOneX(_ device: AVCaptureDevice) {
        let wanted = min(max(zoomBase, 1), device.activeFormat.videoMaxZoomFactor)
        guard wanted > 1 else { return }
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = wanted
            device.unlockForConfiguration()
        } catch {
            // A device that will not lock is being reconfigured; the wider
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
    /// The graded viewfinder's output. See `attachPreviewFrames`.
    private var previewFrames: AVCaptureVideoDataOutput?
    /// The preview layer's rotation, copied at attach so a flip can restore it.
    private var frameAngle: CGFloat = 90

    /// **Which way up the world is, for the PHOTOGRAPH.**
    ///
    /// Held for the whole session rather than made at the shutter, because a
    /// freshly created coordinator has not observed the device yet and
    /// answers with a default. This one has had the whole time the camera was
    /// open to track gravity.
    ///
    /// It is a different question from the one the graded overlay asks, and
    /// the two must not be confused again. The overlay has to agree with the
    /// preview layer it is drawn on, which is portrait and stays portrait
    /// because the app is. The photograph has to agree with the WORLD.
    private var rotation: AVCaptureDevice.RotationCoordinator?
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
        // **The widest the lens goes, not "1x".** 1x is a crop on the front
        // camera and the middle lens on the back, and the maker wants
        // headroom around the head it is cutting out. See `minZoom`.
        setZoom(minZoom)
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
            //
            // **The angle is asked of the device, not assumed.** This was a
            // hard-coded 90, which is portrait for the front camera up to the
            // iPhone 16 — and wrong on the iPhone 17 line, whose front sensor
            // is mounted a quarter turn differently: Apple's own coordinator
            // answers 0 for portrait there (developer.apple.com/forums/
            // thread/813548). Every frame the maker analysed arrived turned,
            // so the chin was looked for on the wrong side of the eyes, the
            // crop kept the torso instead of the hair, the neck fade landed on
            // the wrong end, and the head came out the wrong way up. From a
            // phone: "the orientation is still upside down", "it doesnt cut off
            // the neck and torso". The preview never showed it, because the
            // preview layer rotates itself.
            let angle = input.map {
                AVCaptureDevice.RotationCoordinator(device: $0.device, previewLayer: nil)
                    .videoRotationAngleForHorizonLevelCapture
            } ?? 90
            if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = facing == .front
            }
        }
        session.commitConfiguration()
        frameOutput = output
    }

    /// **Frames for the graded viewfinder**, which is a different job from
    /// `attachFrames` above and therefore a different method.
    ///
    /// That one is the head maker's: it drops the session to 1080p and resets
    /// the zoom to 1, because Vision is measuring a face and the portrait crop
    /// breaks its distance estimate. Neither is acceptable here. The
    /// viewfinder must keep the `.photo` preset and the exact framing the
    /// shutter is about to use, or the picture would not be the one that was
    /// composed. `.photo` already yields preview-sized buffers, so there is
    /// nothing to gain by changing it.
    ///
    /// **This runs on the session queue, and that is the whole point of the
    /// rewrite.** It crashed on his phone, inside `startRunning`:
    ///
    ///     Thread 5, closure #1 in CameraService.start()
    ///     -[AVCaptureSession startRunning] -> objc_exception_throw
    ///
    /// `start()` dispatches `startRunning` onto `queue` and returns
    /// immediately, so the caller's next line ran on the MAIN actor while the
    /// session was starting on the session queue. `AVCaptureSession` raises an
    /// Objective-C exception when its configuration is mutated underneath a
    /// start, and an Objective-C exception is not something Swift can catch:
    /// it goes straight to `std::terminate`.
    ///
    /// `queue` is serial, so dispatching the configuration onto it orders this
    /// strictly after the start rather than beside it. Every session mutation
    /// this feature makes now happens here, on that queue, inside one
    /// begin/commit pair, with `canAddOutput` checked.
    ///
    /// **It cannot fail loudly.** If the output cannot be added for any
    /// reason, `previewFrames` stays nil, no frames are ever delivered, the
    /// overlay stays hidden, and the camera is exactly the camera it was
    /// before this feature existed.
    func attachPreviewFrames(_ output: AVCaptureVideoDataOutput, matching angle: CGFloat) {
        guard isConfigured, previewFrames == nil, frameOutput == nil else { return }
        let session = self.session
        frameAngle = angle
        let mirrored = facing == .front
        queue.async {
            let added = Self.addOnce(output, to: session) {
                Self.orient(output, angle: angle, mirrored: mirrored)
            }
            Task { @MainActor [weak self] in
                self?.previewFrames = added ? output : nil
            }
        }
    }

    func detachPreviewFrames() {
        guard let output = previewFrames else { return }
        previewFrames = nil
        let session = self.session
        queue.async {
            guard session.outputs.contains(where: { $0 === output }) else { return }
            session.beginConfiguration()
            session.removeOutput(output)
            session.commitConfiguration()
        }
    }

    /// **Adds an output to a session exactly once.**
    ///
    /// Idempotent by construction: adding an output the session already holds
    /// is one of the things `-[AVCaptureSession addOutput:]` raises on, and a
    /// raise here is a termination rather than an error. `canAddOutput` is the
    /// documented precondition and is checked rather than assumed.
    ///
    /// `configure` runs inside the same begin/commit pair, because a
    /// connection does not exist until the output is added and setting a
    /// property on it afterwards would be a second reconfiguration.
    ///
    /// Static and `nonisolated` so it can be exercised by a test with a bare
    /// session and no camera, which is the only part of this that a machine
    /// without a lens can check.
    nonisolated static func addOnce(_ output: AVCaptureOutput,
                                    to session: AVCaptureSession,
                                    configure: () -> Void = {}) -> Bool {
        if session.outputs.contains(where: { $0 === output }) { return true }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        guard session.canAddOutput(output) else {
            GradedViewfinder.log.error(
                "graded viewfinder: the session refused the frame output, staying on the plain preview")
            return false
        }
        session.addOutput(output)
        configure()
        return true
    }

    /// Upright, and mirrored on the front lens, so the graded surface shows
    /// what the preview layer under it shows.
    ///
    /// **The angle is the preview layer's own, copied.** It was asked of an
    /// `AVCaptureDevice.RotationCoordinator` instead, first as
    /// `videoRotationAngleForHorizonLevelPreview` and then, in the commit that
    /// added the y-flip, as `...ForHorizonLevelCapture`. Both are answers to a
    /// question this surface is not asking. The overlay has exactly one
    /// correctness condition — that it agree with the preview layer it is
    /// drawn on top of — and the way to satisfy a condition like that is to
    /// read the other side of it rather than to derive it a second time and
    /// hope the two derivations agree. They did not: changing the property and
    /// adding the flip in one commit moved the picture 180 degrees twice, and
    /// the owner saw exactly what he had seen before. "The filter orientation
    /// ones are still flipped upside down."
    ///
    /// Copying it also means no device can be wrong here. Whatever the layer
    /// does, on whatever phone, this does the same.
    nonisolated static func orient(_ output: AVCaptureVideoDataOutput,
                                   angle: CGFloat, mirrored: Bool) {
        guard let connection = output.connection(with: .video) else { return }
        if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = mirrored
        }
        GradedViewfinder.log.notice(
            "graded viewfinder: connection set to \(Int(angle), privacy: .public) degrees, mirrored \(connection.isVideoMirrored, privacy: .public)")
    }

    /// Re-orients after a flip, on the session queue for the same reason
    /// everything else here is.
    private func reorientPreviewFrames() {
        guard let output = previewFrames else { return }
        let angle = frameAngle
        let mirrored = facing == .front
        queue.async { Self.orient(output, angle: angle, mirrored: mirrored) }
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

    /// How far in the lens is, in the numbers shown on screen: 0.5, 1, 2.
    /// See `lensBase` for why that is not the same as `videoZoomFactor`.
    private(set) var zoom: CGFloat = 1

    /// The device factor that equals 1x here. Set with the input.
    private var zoomBase: CGFloat = 1

    /// The widest this phone goes, as a number people read: 0.5 with an
    /// ultra-wide, 1 without one.
    var minZoom: CGFloat { max(1 / max(zoomBase, 0.0001), 0.1) }

    /// The most this camera will go to.
    ///
    /// Capped at 8 whatever the hardware claims. Past that a wide-angle lens
    /// is enlarging pixels rather than resolving anything, and a control that
    /// keeps moving while the picture stops improving is a control that lies.
    /// The front camera usually maxes out far below it and the `min` handles
    /// that on its own.
    var maxZoom: CGFloat {
        guard let device = input?.device else { return 1 }
        return min(device.activeFormat.videoMaxZoomFactor / max(zoomBase, 0.0001), 8)
    }

    /// Whether the lens can move at all, so the view can leave the control out
    /// rather than draw one that does nothing.
    var canZoom: Bool { maxZoom > 1.05 || minZoom < 0.95 }

    // MARK: - Focus and exposure

    /// How far the exposure is pushed, in stops. 0 is what the camera chose.
    ///
    /// This is what the PERSON asked for, by dragging. What the sensor is
    /// actually set to is this minus `lookPull`. They are kept apart because
    /// they mean different things and one must not eat the other: a drag is
    /// "make this brighter", and a pull is a look protecting its highlights.
    private(set) var exposureBias: Float = 0

    /// **How far the look asks the sensor to underexpose, in stops.**
    ///
    /// This is what Fujifilm's DR200 and DR400 actually are, and the pipeline
    /// was only doing half of it. A recipe that says DR400 does not lift
    /// shadows on whatever it happened to capture: it deliberately
    /// underexposes by two stops so the highlights are never clipped in the
    /// first place, and lifts the rest back in processing. Highlights that
    /// have already blown cannot be recovered by any amount of grading, and
    /// this pipeline was lifting shadows on an image whose sky was already
    /// gone.
    ///
    /// The lift back happens in `FilmLookRenderer`, which is handed the same
    /// number, so the viewfinder and the photograph are both pulled and both
    /// lifted and the pair still agree.
    private(set) var lookPull: Float = 0

    /// What the sensor is set to: the drag, less the look's pull, clamped to
    /// what this device will accept.
    private func applyExposure() {
        guard let device = input?.device else { return }
        let wanted = min(max(exposureBias - lookPull,
                             device.minExposureTargetBias), device.maxExposureTargetBias)
        do {
            try device.lockForConfiguration()
            device.setExposureTargetBias(wanted)
            device.unlockForConfiguration()
        } catch {
            // A device that will not lock is being reconfigured; the next
            // change carries the same intent.
        }
    }

    /// Set when the look changes. Capped at two stops, because past that a
    /// pull on a processed frame is buying highlight headroom with shadow
    /// noise at a rate that stops being worth it.
    func setLookPull(_ stops: Double) {
        let wanted = Float(min(max(stops, 0), 2))
        guard abs(wanted - lookPull) > 0.01 else { return }
        lookPull = wanted
        applyExposure()
    }

    /// The range this device will accept, so the view can clamp a drag rather
    /// than discovering the limit by being refused.
    var exposureBiasRange: ClosedRange<Float> {
        guard let device = input?.device else { return 0...0 }
        return device.minExposureTargetBias...device.maxExposureTargetBias
    }

    /// **Held focus and exposure, the way press-and-hold does it everywhere
    /// else.**
    ///
    /// A tap points the camera at something and lets it settle; this pins it
    /// there and says so, which is what you want when the thing you are
    /// photographing is about to move, or when you are metering off your hand
    /// and then framing something else. Tapping anywhere releases it.
    private(set) var isLocked = false

    func lockFocusAndExposure(at point: CGPoint) {
        guard let device = input?.device else { return }
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported { device.focusPointOfInterest = point }
            if device.isExposurePointOfInterestSupported { device.exposurePointOfInterest = point }
            // Locked outright rather than left to settle: a held reading must
            // not drift afterwards, which is the entire difference between
            // this and a tap.
            if device.isFocusModeSupported(.locked) { device.focusMode = .locked }
            if device.isExposureModeSupported(.locked) { device.exposureMode = .locked }
            // Nothing should undo a lock on its own.
            device.isSubjectAreaChangeMonitoringEnabled = false
            device.unlockForConfiguration()
            isLocked = true
        } catch { }
    }

    /// Watches for the scene changing under a tapped focus. See `focus(at:)`.
    private var subjectAreaObserver: NSObjectProtocol?

    /// **What to do when the camera is taken away and given back.**
    ///
    /// Nothing watched for either, so a session that stopped stayed stopped:
    /// a phone call, a FaceTime call, Control Centre's own camera, or another
    /// app claiming the lens left a permanently black viewfinder with working
    /// buttons on top of it. The only way out was leaving the tab and coming
    /// back. It is the most likely thing on this screen to actually happen to
    /// somebody, and it looked like the app was broken.
    ///
    /// Three notifications, and they mean different things. A RUNTIME ERROR
    /// is the session failing, and the one worth recovering from is
    /// `mediaServicesWereReset`, where the whole media stack has restarted
    /// underneath us and the session simply needs starting again. Anything
    /// else is a failure the session cannot be talked out of, and pretending
    /// otherwise is a restart loop. An INTERRUPTION is the system taking the
    /// camera for something more important, and it ENDS, which is the moment
    /// to take it back.
    ///
    /// `wantsRunning` is what makes recovery safe: set by `start`, cleared by
    /// `stop`, so nothing here can bring the camera back to life after
    /// somebody has left the screen. A camera that restarts itself in the
    /// background is the exact thing this app promises never to be.
    private var troubleObservers: [NSObjectProtocol] = []
    private var wantsRunning = false
    /// True while the system has the camera, so the view can say so rather
    /// than showing black and hoping.
    private(set) var isInterrupted = false

    private func watchForTrouble() {
        for observer in troubleObservers { NotificationCenter.default.removeObserver(observer) }
        let centre = NotificationCenter.default
        troubleObservers = [
            centre.addObserver(forName: AVCaptureSession.runtimeErrorNotification,
                               object: session, queue: .main) { [weak self] note in
                let error = note.userInfo?[AVCaptureSessionErrorKey] as? AVError
                Task { @MainActor in self?.recover(from: error) }
            },
            centre.addObserver(forName: AVCaptureSession.wasInterruptedNotification,
                               object: session, queue: .main) { [weak self] note in
                let raw = note.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int
                Task { @MainActor in
                    self?.isInterrupted = true
                    GradedViewfinder.log.notice(
                        "camera: interrupted, reason \(raw ?? -1, privacy: .public)")
                }
            },
            centre.addObserver(forName: AVCaptureSession.interruptionEndedNotification,
                               object: session, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.isInterrupted = false
                    self?.resumeIfWanted()
                }
            }
        ]
    }

    private func recover(from error: AVError?) {
        GradedViewfinder.log.error(
            "camera: runtime error \(error?.code.rawValue ?? -1, privacy: .public)")
        guard error?.code == .mediaServicesWereReset else { return }
        resumeIfWanted()
    }

    /// Starts again only if somebody is still looking at this screen.
    func resumeIfWanted() {
        guard wantsRunning else { return }
        let session = self.session
        queue.async { if !session.isRunning { session.startRunning() } }
    }

    private func watchForSceneChanges() {
        if let subjectAreaObserver {
            NotificationCenter.default.removeObserver(subjectAreaObserver)
        }
        subjectAreaObserver = NotificationCenter.default.addObserver(
            forName: AVCaptureDevice.subjectAreaDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.isLocked else { return }
                self.resetFocus()
            }
        }
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
            // **Ask to be told when the scene moves on.**
            //
            // Both modes above hold after they converge, which is what a tap
            // to focus means — and `resetFocus` existed to undo it and was
            // NEVER CALLED. So one tap locked the focus and the exposure for
            // the rest of the session: point at a lamp, tap, turn to a face,
            // and the face was metered for the lamp with no way back short
            // of flipping the camera twice.
            //
            // This is how the system camera returns on its own. The device
            // posts `subjectAreaDidChangeNotification` when what is in front
            // of it has changed enough to be a different picture, and that
            // is the moment to go back to deciding for itself.
            device.isSubjectAreaChangeMonitoringEnabled = true
            // A tap anywhere releases a hold. That is how press-and-hold
            // works everywhere else and it is the only release this screen
            // needs: there is no second control to find.
            isLocked = false
            // A tap is a fresh reading, so the bias it was carrying no longer
            // describes anything.
            // The person's own bias goes, the look's pull stays: a tap is a
            // fresh reading, not a change of look.
            device.setExposureTargetBias(-lookPull)
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
        exposureBias = clamped
        applyExposure()
    }

    /// Back to whatever the camera decides on its own, everywhere in the
    /// frame. What flipping or leaving the screen should leave behind.
    /// Back to the camera deciding for itself. Called when the scene changes
    /// under a tapped focus, when a lock is released, and when the camera is
    /// put away.
    func resetFocus() {
        guard let device = input?.device else { return }
        isLocked = false
        do {
            try device.lockForConfiguration()
            device.isSubjectAreaChangeMonitoringEnabled = false
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.setExposureTargetBias(-lookPull)
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
    /// Takes a number people read — 0.5, 1, 2.4 — and puts the lens there,
    /// which on a virtual device may mean handing over to a different piece
    /// of glass. The device does that itself; nothing here reconfigures.
    func setZoom(_ factor: CGFloat) {
        guard let device = input?.device else { return }
        let clamped = min(max(factor, minZoom), maxZoom)
        guard abs(clamped - zoom) > 0.001 else { return }
        let onDevice = min(max(clamped * zoomBase, 1),
                           device.activeFormat.videoMaxZoomFactor)
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = onDevice
            device.unlockForConfiguration()
            zoom = clamped
        } catch {
            // A device that will not lock is one that is being reconfigured.
            // Dropping the frame is right; the next pinch event carries the
            // same intent.
        }
    }

    // MARK: - Capture

    /// **`singleFrame` asks the phone to stop improving the picture.**
    ///
    /// The owner's answer to which pipeline to use: "is it possible to keep
    /// the apple processing on none and turning it off for the film
    /// simulation?" It is, and it is a better answer than either of the ones
    /// offered, because the person has already said which they want by
    /// choosing a look.
    ///
    /// **What the two pipelines are.** Apple's default is multi-frame: Deep
    /// Fusion and Smart HDR fuse several exposures, sharpen aggressively and
    /// tone-map the result flat. It produces the cleanest file this phone can
    /// make, especially in a dim room, and it is the right answer to "take
    /// the best photograph you can" — which is what None means.
    ///
    /// It is the wrong answer to a film look, for two reasons. The sharpening
    /// and the flat HDR curve are the two things people mean by a photograph
    /// looking digital, and they fight everything the grade is doing: the
    /// shoulder that was rolling highlights off, the soft toe, the grain that
    /// a sharpener finds and amplifies. And the viewfinder reads the preview
    /// stream while the still goes through the fusion stack, so the picture
    /// cannot match the frame it was composed in. This app now promises that
    /// it does. It is the same thing the IIWII camera verifies on: the saved
    /// image matches the live preview rather than shifting into Apple's HDR
    /// photo.
    ///
    /// So a look means `.speed`, which is a single frame with none of that,
    /// and None means `.quality`, which is everything the phone has. The cost
    /// is honest and belongs to whoever chose the look: one frame in a dark
    /// room is a noisier frame, and grain is what the look was adding anyway.
    ///
    /// Only the per-shot `AVCapturePhotoSettings` is touched. Zero shutter
    /// lag and responsive capture are properties of the OUTPUT, and toggling
    /// those between shots would be reconfiguring a running session, which is
    /// what terminated the app once already.
    func capture(singleFrame: Bool = false, raw: Bool = false,
                 _ completion: @escaping (UIImage?) -> Void) {
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
            // **The photograph is levelled to the world, and it never was.**
            //
            // This connection's rotation was never set, so it sat at its
            // portrait default for the life of the app. Hold the phone on its
            // side and the scene is on its side in the file: a landscape shot
            // came out as a portrait photograph of a fallen-over world.
            //
            // The viewfinder hid it. A preview layer renders the sensor
            // through its own connection, so the world looks right through
            // the glass whichever way you are holding it — and the app is
            // portrait locked, so nothing else ever rotated to give it away.
            //
            // This is the HORIZON LEVEL angle, which is the opposite of what
            // the graded overlay takes, and the difference is the whole
            // point. The overlay has to agree with the preview layer it is
            // painted on. The photograph has to agree with gravity, so that
            // looking at it later shows what your eyes saw through the glass
            // rather than what the phone's sensor happened to be pointing at.
            if let angle = rotation?.videoRotationAngleForHorizonLevelCapture,
               connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = usesScreenFlash
            }
        }

        // **Bayer RAW, and an ordinary photograph in the same shutter press.**
        //
        // `AVCapturePhotoSettings(rawPixelFormatType:processedFormat:)` asks
        // for both, and both arrive. That is deliberately more work than
        // asking for RAW alone: developing a RAW is the one thing in this
        // app that cannot be tested on a machine with no camera, and a
        // developer that returns nil would otherwise cost somebody the
        // photograph they just took. With both in hand the RAW is an
        // UPGRADE that is taken when it works and silently skipped when it
        // does not.
        //
        // Apple ProRAW is not asked for and must not be: it is still
        // multi-frame, with Smart HDR and Deep Fusion baked into the file,
        // which is the exact thing being avoided. `isBayerRAWPixelFormat`
        // picks the real sensor format out of whatever this device offers,
        // and a device that offers none simply takes an ordinary photograph.
        let rawFormat = raw ? output.availableRawPhotoPixelFormatTypes.first(where: {
            AVCapturePhotoOutput.isBayerRAWPixelFormat($0)
        }) : nil
        let settings: AVCapturePhotoSettings
        if let rawFormat {
            settings = AVCapturePhotoSettings(
                rawPixelFormatType: rawFormat,
                processedFormat: [AVVideoCodecKey: AVVideoCodecType.hevc])
        } else {
            settings = AVCapturePhotoSettings()
        }
        capturedRaw = nil
        capturedProcessed = nil
        capturedMirrored = usesScreenFlash
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
        let wanted: AVCapturePhotoOutput.QualityPrioritization = singleFrame ? .speed : .quality
        settings.photoQualityPrioritization =
            output.maxPhotoQualityPrioritization.rawValue >= wanted.rawValue
            ? wanted : output.maxPhotoQualityPrioritization
        // Only the rear camera has a lamp to fire.
        if !usesScreenFlash, output.supportedFlashModes.contains(.on) {
            settings.flashMode = isFlashOn ? .on : .off
        }
        output.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    /// Called once per photograph, so twice when RAW was asked for, and in no
    /// guaranteed order. Nothing is decided here; both are just put down.
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let data = photo.fileDataRepresentation()
        let isRaw = photo.isRawPhoto
        Task { @MainActor in
            if isRaw {
                self.capturedRaw = data
            } else {
                // No orientation surgery here. Mirroring is set on the
                // capture connection before the shot; rebuilding the UIImage
                // with `.leftMirrored` afterwards also ROTATED it a quarter
                // turn, which is why that approach is wrong and not just
                // redundant.
                self.capturedProcessed = data.flatMap(UIImage.init(data:))
            }
        }
    }

    /// **Everything has been delivered, so now choose.**
    ///
    /// This runs after both photographs, which is why the decision lives here
    /// rather than in the callback above: the RAW may arrive second, and a
    /// choice made on the first one would be a coin toss. The RAW is taken
    /// when it develops and the ordinary photograph is taken when it does
    /// not, so the worst case of the whole RAW feature is the camera exactly
    /// as it was before it existed.
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        Task { @MainActor in
            self.isCapturing = false
            let processed = self.capturedProcessed
            let mirrored = self.capturedMirrored
            var chosen = processed
            var developedOK = false
            if let dng = self.capturedRaw {
                // Off the main actor: developing a RAW is tens of
                // milliseconds of CPU and GPU and the shutter animation is
                // running.
                let developed = await Task.detached(priority: .userInitiated) {
                    RawDeveloper.shared.develop(dng, mirrored: mirrored)
                }.value
                if let developed { chosen = developed; developedOK = true }
            }
            // **Say which path ran and what came back.**
            //
            // The owner: "the filtered photo never loaded on the block." That
            // can be three different faults — the RAW never arrived, it
            // arrived and would not develop, or nothing was captured at all —
            // and they are indistinguishable from the outside. This is the
            // one line that tells them apart on his next run, because none of
            // it can be reproduced on a machine with no lens.
            GradedViewfinder.log.notice("""
                capture: raw \(self.capturedRaw?.count ?? 0, privacy: .public) bytes, processed \(processed == nil ? "none" : "yes", privacy: .public), developed \(developedOK ? "yes" : "no", privacy: .public), returning \(chosen == nil ? "NOTHING" : "a photograph", privacy: .public)
                """)
            self.capturedRaw = nil
            self.capturedProcessed = nil
            self.onCaptured?(chosen)
            self.onCaptured = nil
        }
    }
}
