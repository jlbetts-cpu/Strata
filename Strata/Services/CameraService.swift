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
    /// The front camera's viewfinder with the face touch on it, live.
    let retouch = LiveRetouch()

    private(set) var facing: Facing = .back
    private(set) var isAuthorized = false
    private(set) var isConfigured = false
    @ObservationIgnored private var configureFailed = false
    /// True while a capture is in flight, so the shutter cannot be re-fired.
    private(set) var isCapturing = false
    /// **Off, Auto, On** (the owner, 2026-10-12: the camera "should have
    /// most of the familiar features that casual people use on the Apple
    /// camera"). Auto is the lamp's own: the phone decides from the light.
    /// The front camera's flash is the screen held lit, which cannot decide
    /// anything, so in front it is off or on.
    enum Flash: String { case off, auto, on }
    var flash: Flash = .off
    /// Front-camera flash is a screen flash, so the view has to know.
    var isFlashOn: Bool {
        get { flash == .on }
        set { flash = newValue ? .on : .off }
    }

    /// The next of the three, as a tap on the bolt moves it.
    func cycleFlash() {
        switch flash {
        case .off: flash = !usesScreenFlash && output.supportedFlashModes.contains(.auto) ? .auto : .on
        case .auto: flash = .on
        case .on: flash = .off
        }
    }

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
    ///
    /// **Off until you turn it on** (the owner, 2026-10-03: "turn off the rule
    /// of third lines off by default"). An empty viewfinder is the camera at
    /// its cleanest; the grid is one tap away for whoever wants it, and a
    /// choice already made is kept.
    var showsGuides = UserDefaults.standard.object(forKey: "cameraShowsGuides") as? Bool ?? false

    /// Off / 3 / 10 — the three delays iOS Camera offers.
    var timerSeconds = UserDefaults.standard.integer(forKey: "cameraTimerSeconds")

    private let output = AVCapturePhotoOutput()
    private var input: AVCaptureDeviceInput?
    private let queue = DispatchQueue(label: "camera.session")
    private var onCaptured: ((UIImage?) -> Void)?

    /// **Which way up, asked of the phone for as long as the camera is open**
    /// (the owner, 2026-10-12: "sometimes the orientation is wrong";
    /// `docs/camera.md`). The app is held to portrait, so nothing ever told
    /// a photograph the phone had been turned: held sideways, it came out a
    /// quarter turn off. This is Apple's own object for exactly that, kept
    /// (it was made and thrown away, read once), and it feeds three things:
    /// the photograph, the viewfinder, and the front camera's live frames.
    @ObservationIgnored private var rotation: AVCaptureDevice.RotationCoordinator?
    @ObservationIgnored private var rotationWatch: NSKeyValueObservation?
    @ObservationIgnored private weak var previewLayer: AVCaptureVideoPreviewLayer?
    @ObservationIgnored private var watchesSubject = false
    @ObservationIgnored private var focusedAt = Date.distantPast

    /// The viewfinder this camera is showing in, so the two agree about
    /// which way is up.
    func attach(previewLayer layer: AVCaptureVideoPreviewLayer) {
        previewLayer = layer
        if isConfigured { watchRotation() }
    }

    private func watchRotation() {
        rotationWatch = nil
        guard let device = input?.device else { rotation = nil; return }
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        rotation = coordinator
        applyPreviewRotation()
        rotationWatch = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.applyPreviewRotation() }
        }
    }

    private func applyPreviewRotation() {
        guard let rotation, let layer = previewLayer else { return }
        let angle = rotation.videoRotationAngleForHorizonLevelPreview
        // Only when it is different: writing the same angle still makes a
        // running session stop and think.
        if let connection = layer.connection, connection.isVideoRotationAngleSupported(angle),
           connection.videoRotationAngle != angle {
            connection.videoRotationAngle = angle
        }
        orientRetouch()
    }

    // MARK: - Lifecycle

    /// **Whether the person has actually said no, as opposed to not having
    /// been asked.**
    ///
    /// `isAuthorized` is false in both cases and the view could not tell them
    /// apart, so a refusal drew the same thing an unopened camera does: a
    /// black rectangle with the wordmark and a shutter on it. That is the
    /// screen the owner reported as "a blank black screen", and it is the
    /// app's LAUNCH tab, so it is the first thing a tester who taps Don't
    /// Allow ever sees. `CameraView` reads this to say so instead.
    private(set) var isDenied = false

    func requestAccess() async {
        #if DEBUG
        // `-strataFakeLens`: the video is the lens, so the camera is allowed.
        if FakeLens.shared != nil {
            isAuthorized = true
            isDenied = false
            return
        }
        if DebugHarness.cameraDenied {
            isAuthorized = false
            isDenied = true
            return
        }
        #endif
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            isDenied = false
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
            // Asked and answered, so a no here is a real no.
            isDenied = !isAuthorized
        default:
            // .denied and .restricted. A restricted camera cannot be granted
            // from Settings either, but the sentence below does not promise
            // it can: it says where the switch lives, and on a restricted
            // device there simply is not one.
            isAuthorized = false
            isDenied = true
        }
    }

    func start() async {
        guard await prepare() else { return }
        await run()
    }

    /// Access asked and the session configured, NOT running: what a caller
    /// that reconfigures before the first frame (the head maker's front
    /// camera and frames) calls, so nothing is configured while it starts.
    @discardableResult
    func prepare() async -> Bool {
        await requestAccess()
        guard isAuthorized else { return false }
        // A phone with no camera (the simulator) fails the same way every
        // time; looking for one again on every open was main-thread work on
        // the first frame of the inline camera's motion.
        if !isConfigured, !configureFailed {
            configure()
            configureFailed = !isConfigured
        }
        return isConfigured
    }

    /// **Running, and only returns once it is** (2026-10-09, the onboarding
    /// face screen's crash). `startRunning` happens on `queue`; it used to be
    /// dispatched and forgotten, and the head maker then flipped to the front
    /// camera and added its frame output on the main thread at once. A
    /// `startRunning` that landed between that `beginConfiguration` and its
    /// commit is an NSGenericException: on a real phone, every so often,
    /// the app died on "Make My Head". The simulator has no camera and never
    /// got there.
    func run() async {
        // **One camera running in the app at a time** (the owner, 2026-10-17:
        // "make sure the inline camera and the Camera tab never fight over the
        // camera"). Each camera has its own session, and a second one started
        // while the first still runs interrupts it rather than stopping it, so
        // the first could come back underneath when the second closed. The
        // one starting now stops the last one, and waits for it to stop.
        if let other = Self.running, other !== self { await other.halt() }
        Self.running = self
        let session = session
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            queue.async {
                if !session.isRunning { session.startRunning() }
                done.resume()
            }
        }
        // Asked again now the viewfinder is on screen: a layer that was
        // handed over before it was in a window may have answered for
        // nowhere (the camera review, 2026-10-12).
        applyPreviewRotation()
    }

    /// Whether this camera is the one the phone is using right now. The
    /// tab's camera stays in the hierarchy when another camera opens over
    /// it or you leave the tab; this is how it knows to keep quiet.
    var isLive: Bool { session.isRunning && !session.isInterrupted }

    func stop() {
        let session = session
        queue.async { if session.isRunning { session.stopRunning() } }
        if Self.running === self { Self.running = nil }
    }

    /// The camera most recently started, while it is.
    @ObservationIgnored private static weak var running: CameraService?

    /// Stopped, and only returns once it has.
    func halt() async {
        let session = session
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            queue.async {
                if session.isRunning { session.stopRunning() }
                done.resume()
            }
        }
        if Self.running === self { Self.running = nil }
    }

    /// Waits for a start or stop still on `queue` to finish: called before
    /// every configuration on the main thread, so the two never interleave.
    private func settleQueue() {
        queue.sync {}
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
        if session.canAddOutput(retouch.output) {
            session.addOutput(retouch.output)
            orientRetouch()
        }
        session.commitConfiguration()
        retouch.setEnabled(facing == .front)
        isConfigured = true
        watchRotation()
        watchSubject()
        // **Open at 1x, not at the widest lens.**
        //
        // On a virtual device the zoom factor 1.0 is the ULTRA WIDE, so a
        // phone with three cameras would have opened the camera at 0.5x and
        // the picture would have been wider than anybody asked for.
        // `CameraLenses.base(for:)` is the factor that means 1x on whatever
        // device this turned out to be, and on a single lens phone it is 1.
        setZoom(CameraLenses.base(for: device))
    }

    /// **Every lens the phone has, not just the middle one.**
    ///
    /// The owner asked for the lens picker back, and the picker was drawn and
    /// wired and completely inert, because this asked for
    /// `.builtInWideAngleCamera` and that is the 1x lens and only the 1x
    /// lens. A phone with three cameras reported no switchover factors, so
    /// `CameraLenses.stops` came back with one entry and the control hid
    /// itself rather than drawing dead buttons. Nothing in the view needed to
    /// change; this line was the whole of it.
    ///
    /// A virtual device (triple, dual wide, dual) is one `AVCaptureDevice`
    /// that switches between its own physical lenses as the zoom crosses
    /// `virtualDeviceSwitchOverVideoZoomFactors`, which is what makes 0.5x
    /// and 3x a zoom rather than a device swap. Preference order is most
    /// lenses first, and the last entry is exactly what this used to return.
    ///
    /// The front camera stays the single wide angle: there is only one.
    private func camera(for facing: Facing) -> AVCaptureDevice? {
        guard facing == .back else {
            return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        }
        let preferred: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,     // ultra wide + wide + telephoto
            .builtInDualWideCamera,   // ultra wide + wide
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

    // MARK: - Controls

    func flip() {
        guard isConfigured, let current = input else { return }
        let next: Facing = facing == .back ? .front : .back
        guard let device = camera(for: next),
              let newInput = try? AVCaptureDeviceInput(device: device) else { return }
        settleQueue()
        session.beginConfiguration()
        session.removeInput(current)
        if session.canAddInput(newInput) {
            session.addInput(newInput)
            input = newInput
            facing = next
            // The old lens's answer about which way is up is not this one's.
            rotationWatch = nil
            rotation = nil
            // The screen held lit cannot be on Auto.
            if next == .front, flash == .auto { flash = .off }
            // A new device starts at its own 1x with its own metering. Without
            // this the pill keeps reading whatever the old lens was at, and
            // the first pinch jumps.
            zoom = 1
            exposureBias = 0
            applyPortraitCropIfFront(device)
            orientRetouch()
            retouch.setEnabled(next == .front)
            // Same reason as `configure()`: on a virtual device, 1.0 is the
            // ultra wide, so flipping back to a three lens camera has to land
            // on its 1x rather than on its widest.
            if next == .back { setZoom(CameraLenses.base(for: device)) }
        } else {
            session.addInput(current)
        }
        session.commitConfiguration()
        watchRotation()
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

    /// The live frames upright and, for the front camera, mirrored, so a
    /// frame is the picture the preview layer would have shown. The angle is
    /// asked of the device: the iPhone 17 front sensor is mounted a quarter
    /// turn from its predecessors (see `attachFrames`).
    ///
    /// **The viewfinder's angle, not the photograph's** (2026-10-12). These
    /// frames are drawn in the viewfinder, which stays upright on the screen
    /// however the phone is held; the angle asked for was the one for a
    /// photograph, which follows the phone. Flip to the front camera while
    /// holding the phone sideways and the picture was turned, and stayed
    /// turned. Before a viewfinder is known it is asked the old way.
    private func orientRetouch() {
        guard let connection = retouch.output.connection(with: .video), let input else { return }
        let angle: CGFloat
        if let rotation, previewLayer != nil {
            angle = rotation.videoRotationAngleForHorizonLevelPreview
        } else {
            angle = AVCaptureDevice.RotationCoordinator(device: input.device, previewLayer: nil)
                .videoRotationAngleForHorizonLevelCapture
        }
        if connection.isVideoRotationAngleSupported(angle), connection.videoRotationAngle != angle {
            connection.videoRotationAngle = angle
        }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = facing == .front
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
        settleQueue()
        session.beginConfiguration()
        // The head maker has the frames to itself: the live touch steps out
        // (one video output at a time), and the maker sees the plain face it
        // measures.
        retouch.setEnabled(false)
        session.removeOutput(retouch.output)
        presetBeforeFrames = session.sessionPreset
        if session.canSetSessionPreset(.hd1920x1080) { session.sessionPreset = .hd1920x1080 }
        guard session.canAddOutput(output) else {
            if let previous = presetBeforeFrames { session.sessionPreset = previous }
            if session.canAddOutput(retouch.output) { session.addOutput(retouch.output); orientRetouch() }
            session.commitConfiguration()
            retouch.setEnabled(facing == .front)
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

    func detachFrames() {
        guard let output = frameOutput else { return }
        settleQueue()
        session.beginConfiguration()
        session.removeOutput(output)
        if let previous = presetBeforeFrames, session.canSetSessionPreset(previous) {
            session.sessionPreset = previous
        }
        if session.canAddOutput(retouch.output) {
            session.addOutput(retouch.output)
            orientRetouch()
        }
        session.commitConfiguration()
        retouch.setEnabled(facing == .front)
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
        // **Measured from 1x, not from the ultra wide.** On a virtual device
        // the raw factor counts from the widest lens, so a triple camera's 8
        // is a displayed 4x once the 0.5x base is taken out. Dividing keeps
        // the ceiling meaning the same thing on every phone: eight times the
        // picture you see at 1x.
        let ceiling = min(device.activeFormat.videoMaxZoomFactor, 8 * CameraLenses.base(for: device))
        return ceiling
    }

    /// Whether the lens can move at all, so the view can leave the control out
    /// rather than draw one that does nothing.
    var canZoom: Bool { maxZoom > 1.05 }

    // MARK: - Focus and exposure

    /// How far the exposure is pushed, in stops. 0 is what the camera chose.
    private(set) var exposureBias: Float = 0

    /// **Two stops either way, which is what Apple's own camera offers, not
    /// the eight the hardware will accept.**
    ///
    /// The owner, on the shipped build: "exposure levels go way too high and
    /// low", and "could you just research the settings Apple does, because
    /// the exposure is way too much."
    ///
    /// He is right and the number was the whole bug. This returned
    /// `device.minExposureTargetBias...device.maxExposureTargetBias`, which
    /// on an iPhone is **-8 to +8 EV**. A stop is a doubling, so that range
    /// spans a factor of 256 in either direction: the top of it is a white
    /// screen and the bottom is a black one, and a drag of a few hundred
    /// points crossed most of it.
    ///
    /// iOS Camera's own sun slider, the one beside the focus box, is about
    /// two stops either way, and every third party camera worth using clamps
    /// to two or three for the same reason: past that you are not adjusting
    /// the picture, you are destroying it. The hardware range still bounds
    /// this, because a device that offers less must not be asked for more.
    ///
    /// The drag's sensitivity is unchanged at one stop per 120 points, which
    /// now means the full range is a 240pt drag rather than a 960pt one.
    static let biasLimit: Float = 2

    var exposureBiasRange: ClosedRange<Float> {
        guard let device = input?.device else { return 0...0 }
        return max(device.minExposureTargetBias, -Self.biasLimit)
            ... min(device.maxExposureTargetBias, Self.biasLimit)
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
            // **A tap is not for ever** (2026-10-12, `docs/camera.md`). One
            // tap focused there and then never again by itself: point the
            // phone at something else and it stayed soft until the next tap.
            // The phone is asked to say when the picture has changed, and
            // then it goes back to looking after itself (`watchSubject`), as
            // Apple's camera does.
            device.isSubjectAreaChangeMonitoringEnabled = true
            focusedAt = Date()
            device.unlockForConfiguration()
        } catch {
            // Being reconfigured. The next tap carries the same intent.
        }
    }

    /// How many times the camera has gone back to focusing by itself, so the
    /// view can put the square away when it no longer describes anything.
    private(set) var focusReleases = 0

    /// By selector, which the system forgets by itself when this camera
    /// goes; a block would have been left behind for every camera opened.
    private func watchSubject() {
        guard !watchesSubject else { return }
        watchesSubject = true
        NotificationCenter.default.addObserver(self, selector: #selector(subjectAreaChanged(_:)),
                                               name: AVCaptureDevice.subjectAreaDidChangeNotification, object: nil)
    }

    @objc nonisolated private func subjectAreaChanged(_ note: Notification) {
        Task { @MainActor in self.subjectChanged() }
    }

    private func subjectChanged() {
        // **Only the camera that is running** (the camera review,
        // 2026-10-12). Every camera hears every lens, and the phone has one
        // back lens: the tab's camera, stopped under the add sheet's, went
        // back to automatic on the lens the sheet's camera had just been
        // pointed with.
        guard isLive else { return }
        // Not in the second after the tap (the lens moving is itself a
        // change), and not while the brightness is being held somewhere by
        // hand: a picture made lighter has changed, and letting go then
        // would fight the finger that is dragging it.
        guard Date().timeIntervalSince(focusedAt) > 1, abs(exposureBias) < 0.01 else { return }
        resetFocus()
        focusReleases += 1
    }

    /// Pushes the exposure up or down, in stops, clamped to what the device
    /// accepts. Safe to call on every frame of a drag.
    func setExposureBias(_ stops: Float) {
        guard let device = input?.device else { return }
        // Clamped to the app's own two stops, not the hardware's eight. See
        // `biasLimit`.
        let clamped = min(max(stops, max(device.minExposureTargetBias, -Self.biasLimit)),
                          min(device.maxExposureTargetBias, Self.biasLimit))
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
        let centre = CGPoint(x: 0.5, y: 0.5)
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported { device.focusPointOfInterest = centre }
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposurePointOfInterestSupported { device.exposurePointOfInterest = centre }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.setExposureTargetBias(0)
            exposureBias = 0
            device.isSubjectAreaChangeMonitoringEnabled = false
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
        let clamped = CameraLenses.clamped(factor, max: maxZoom)
        guard abs(clamped - zoom) > 0.001 else { return }
        do {
            try device.lockForConfiguration()
            // A pinch that starts while a lens button's glide is still
            // running takes over from it.
            if device.isRampingVideoZoom { device.cancelVideoZoomRamp() }
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
            zoom = clamped
        } catch {
            // A device that will not lock is one that is being reconfigured.
            // Dropping the frame is right; the next pinch event carries the
            // same intent.
        }
    }

    /// How long a lens button takes to get there, whatever the distance.
    static let glideSeconds: CGFloat = 0.25

    /// **To a lens, gliding** (2026-10-12): a lens button on Apple's camera
    /// slides the picture to the next lens; this one cut. The phone does the
    /// slide itself, handing over between its lenses on the way, at a rate
    /// in doublings a second.
    func glide(to factor: CGFloat) {
        guard let device = input?.device else { return }
        let clamped = CameraLenses.clamped(factor, max: maxZoom)
        guard abs(clamped - zoom) > 0.001 else { return }
        let doublings = abs(log2(clamped / max(zoom, 0.001)))
        do {
            try device.lockForConfiguration()
            device.ramp(toVideoZoomFactor: clamped, withRate: Float(max(doublings / Self.glideSeconds, 1)))
            device.unlockForConfiguration()
            zoom = clamped
        } catch { }
    }

    // MARK: - Capture

    func capture(_ completion: @escaping (UIImage?) -> Void) {
        #if DEBUG
        // `-strataFakeLens`: the frame of the video on screen is the photograph.
        if let lens = FakeLens.shared { completion(lens.snapshot()); return }
        #endif
        // **Running, or nothing** (the camera review, 2026-10-12). A photo
        // asked of a stopped camera never answers, and `isCapturing` is only
        // put back by the answer: the shutter would have been dead until the
        // app was opened again. A volume button can reach a camera that is
        // not the one showing.
        guard isConfigured, !isCapturing, isLive else { completion(nil); return }
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
            // **The photograph is told which way up the phone is**, at the
            // moment it is taken (`rotation`). Lying flat, the phone answers
            // with the last way it was held.
            if let angle = rotation?.videoRotationAngleForHorizonLevelCapture,
               connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
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
        if !usesScreenFlash {
            let wanted: AVCaptureDevice.FlashMode = switch flash {
            case .off: .off
            case .auto: .auto
            case .on: .on
            }
            if output.supportedFlashModes.contains(wanted) { settings.flashMode = wanted }
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
