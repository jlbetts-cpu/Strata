import AVFoundation
import CoreImage
import MetalKit
import UIKit
import os

/// **The viewfinder, in the colour the photograph will be.**
///
/// The owner, with the build on his phone: "The live filters don't actually
/// work." They were applied at capture and nowhere else, so choosing a look
/// changed the swatch and the saved picture but not the scene you were
/// composing.
///
/// **Why this is not simply "filter the preview".** `AVCaptureVideoPreviewLayer`
/// renders the feed itself and nothing can be put between it and the glass, so
/// a graded viewfinder has to be a second surface fed by
/// `AVCaptureVideoDataOutput` and drawn by hand. This is that surface: a
/// `MTKView` that Core Image renders each frame into.
///
/// **The preview layer stays, underneath, and that is the whole fail-safe.**
/// This view is an overlay on top of it. If Metal is unavailable, if frames
/// stop arriving, or if no look is selected, the overlay is simply hidden and
/// the ordinary preview is already there showing the scene. There is no path
/// where the viewfinder goes black because the grading failed: the worst case
/// is an ungraded picture, which is the camera working.
///
/// **It carries the texture, not just the colour.** It did not, and the owner
/// said so: "there is no film simulation like grain or anything and the looks
/// dont look distinct enough to look good." A colour table is the part the
/// three looks have least in common — Air is its glow, Bright is its clarity,
/// Silver is its grain — so stripping those left three tints of each other.
/// `FilmLookRenderer.live` now runs the whole pipeline bar halation and bloom,
/// which are four blurs for the smallest difference of any step.
@MainActor
final class GradedViewfinder {
    static let log = Logger(subsystem: "JaydenBetts.Strata", category: "viewfinder")

    /// The look being drawn. `.none` hides the overlay, which is the common
    /// case and costs nothing to render.
    var look: FilmLook = FilmLook.look(.none) {
        didSet {
            // The relay keeps reading frames either way, because the tray's
            // swatches need the scene, but it stops waking the main actor.
            relay.wantsFrames = look.kind != .none
            view?.isHidden = !isDrawable
        }
    }

    /// One frame in flight at a time. Without this a main thread that falls
    /// behind accumulates a queue of `Task`s, and the viewfinder drifts
    /// further behind the world the busier the phone gets. Dropping is the
    /// right behaviour for a viewfinder: the next frame is always better than
    /// a late one.
    private var presenting = false

    /// **Where the grain field is sampled from, this frame.**
    ///
    /// `CIRandomGenerator` takes no seed: it is a deterministic function of
    /// position, so the same call gives the same field pinned to the same
    /// coordinates. Drawn unmoved, the grain would sit still while the scene
    /// moved behind it — dirt on the glass rather than grain in the emulsion.
    /// Walking the field by a prime number of points each frame samples
    /// somewhere new without ever repeating a short cycle.
    private var grainPhase: CGPoint = .zero

    /// **What the grade actually costs this phone, and what to do about it.**
    ///
    /// The whole pipeline measured 2.4 to 9.5ms of GPU a frame on this Mac,
    /// against a 33ms budget at 30 frames a second, so it ships complete. But
    /// the Mac is not the phone and the phone is not every phone, and the
    /// failure mode if it is wrong is bad: `alwaysDiscardsLateVideoFrames`
    /// turns a frame that is too slow into a frame that is not delivered, so
    /// a heavy pipeline reads as a stuttering camera rather than as a slow
    /// one.
    ///
    /// The first twenty frames are timed and then a decision is made once.
    /// Over budget, halation and bloom come off — four Gaussian blurs, the
    /// most expensive and least identifying part of a look. Decided once and
    /// then left alone: a pipeline that switched back and forth would show as
    /// the look itself changing while the camera sat still.
    private var costs: [Double] = []
    private var sparingHighlights = false
    private static let budgetMilliseconds = 22.0

    private func frameCost(_ milliseconds: Double) {
        guard costs.count < 20 else { return }
        costs.append(milliseconds)
        guard costs.count == 20 else { return }
        let median = costs.sorted()[10]
        sparingHighlights = median > Self.budgetMilliseconds
        Self.log.notice("""
            graded viewfinder: \(median, format: .fixed(precision: 2), privacy: .public) ms median on the GPU, \(self.sparingHighlights ? "dropping halation and bloom" : "running the whole pipeline", privacy: .public)
            """)
    }

    /// True when a look is selected AND frames are arriving.
    private var isDrawable: Bool { look.kind != .none && relay.isLive }

    private(set) var view: GradedPreviewView?
    let relay = CameraFrameRelay()
    private var watchdog: Timer?

    init() {
        relay.onFrame = { [weak self] image, means in
            Task { @MainActor in
                guard let self, !self.presenting else { return }
                self.presenting = true
                self.present(image, means: means)
                self.presenting = false
            }
        }
    }

    /// Builds the drawing surface, or returns nil if this machine has no Metal
    /// device — the simulator, and any failure mode on hardware. The caller
    /// then simply never adds an overlay.
    func makeView() -> GradedPreviewView? {
        if let view { return view }
        guard let made = GradedPreviewView.make(cost: { [weak self] ms in
            Task { @MainActor in self?.frameCost(ms) }
        }) else {
            Self.log.error("graded viewfinder: no Metal device, staying on the plain preview")
            return nil
        }
        made.isHidden = true
        view = made
        startWatchdog()
        return made
    }

    private func present(_ image: CIImage, means: [Double]?) {
        guard let view else { return }
        guard look.kind != .none else {
            if !view.isHidden { view.isHidden = true }
            return
        }
        grainPhase = CGPoint(x: grainPhase.x + 1013, y: grainPhase.y + 1409)
        let graded = FilmLookRenderer.shared.live(look, to: image, means: means, phase: grainPhase,
                                                  sparingHighlights: sparingHighlights)
        view.show(graded)
        if view.isHidden { view.isHidden = false }
    }

    /// **If frames stop, uncover the plain preview rather than freezing.**
    ///
    /// A `MTKView` holds its last drawable, so a stalled pipeline would leave
    /// a still photograph of a moment ago sitting over a live camera, which is
    /// worse than no grading at all: it looks like the camera has frozen. One
    /// second without a frame hides the overlay and the ungraded feed is
    /// already underneath it.
    private func startWatchdog() {
        watchdog?.invalidate()
        watchdog = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let view = self.view, !view.isHidden else { return }
                if !self.relay.isLive {
                    Self.log.error("graded viewfinder: no frames for 1s, falling back to the plain preview")
                    view.isHidden = true
                }
            }
        }
    }

    func stop() {
        watchdog?.invalidate()
        watchdog = nil
        view?.isHidden = true
    }
}

/// Reads the camera's frames, keeps the newest one, and measures white balance
/// at its own cadence.
///
/// `nonisolated`, because `captureOutput` arrives on its own queue and must not
/// hop to the main actor per frame.
final class CameraFrameRelay: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "camera.viewfinder.frames", qos: .userInitiated)
    private let lock = NSLock()
    private var lastFrameAt: CFTimeInterval = 0
    private var latest: CIImage?
    private var counter = 0
    private var means: [Double]?
    private var announced = false
    private var dropped = 0
    private var statsAt: CFTimeInterval = 0
    private var sinceStats = 0

    /// Handed each frame, on the frame queue's schedule, but only while
    /// `wantsFrames`. The newest frame is always kept regardless, because the
    /// tray's swatches ask for one whenever it opens.
    var onFrame: ((CIImage, [Double]?) -> Void)?

    /// Whether anything is drawing frames. False whenever the look is `.none`,
    /// which is the common case, so the ordinary camera costs one `CIImage`
    /// wrapper a frame and nothing else.
    var wantsFrames = false

    /// **How often the white balance is re-measured.** `measureMeans` is a
    /// synchronous GPU to CPU readback, so once a frame would stall every
    /// frame, and because the reading moves slightly frame to frame the
    /// balance would visibly breathe while the camera sat still. Every 15
    /// frames is about twice a second, which is ample for white balance and
    /// is the cadence `FilmLookRenderer` documents for exactly this path.
    private static let measureEvery = 15

    override init() {
        super.init()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: queue)
    }

    /// **Delivered frame rate, every five seconds.** The answer to "is it
    /// smooth" should be a number he can read off a log rather than a feeling,
    /// and a rate that sits at 30 while dropped stays at 0 is the pipeline
    /// keeping up. A rate that sags is the place to look next.
    private func reportRate() {
        let now = CACurrentMediaTime()
        lock.lock()
        sinceStats &+= 1
        if statsAt == 0 { statsAt = now; lock.unlock(); return }
        let elapsed = now - statsAt
        guard elapsed >= 5 else { lock.unlock(); return }
        let count = sinceStats, drops = dropped
        sinceStats = 0; statsAt = now
        lock.unlock()
        let fps = Double(count) / elapsed
        GradedViewfinder.log.notice(
            "graded viewfinder: \(fps, format: .fixed(precision: 1), privacy: .public) fps delivered, \(drops, privacy: .public) dropped total")
    }

    /// True while frames have arrived recently. The viewfinder uncovers the
    /// plain preview when this goes false.
    var isLive: Bool {
        lock.lock(); defer { lock.unlock() }
        return lastFrameAt > 0 && CACurrentMediaTime() - lastFrameAt < 1.0
    }

    /// The newest frame as a small `UIImage`, for the tray's swatches.
    func snapshot(maxSide: CGFloat) -> UIImage? {
        lock.lock(); let image = latest; lock.unlock()
        guard let image else { return nil }
        let side = max(image.extent.width, image.extent.height)
        guard side > 0 else { return nil }
        let scale = min(1, maxSide / side)
        let small = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return FilmLookRenderer.shared.uiImage(from: small)
    }

    /// **Dropped frames, counted rather than guessed at.** `alwaysDiscardsLateVideoFrames`
    /// means the system throws away a frame it could not hand over in time, and
    /// that is the right behaviour for a viewfinder, but it is also the first
    /// symptom of a pipeline that is too slow. Silent dropping is how a
    /// stuttering camera gets reported as "it feels laggy" with nothing to
    /// look at.
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        lock.lock(); dropped &+= 1; let total = dropped; lock.unlock()
        if total == 1 || total % 60 == 0 {
            GradedViewfinder.log.error("graded viewfinder: dropped \(total, privacy: .public) frames")
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let image = CIImage(cvPixelBuffer: buffer)

        lock.lock()
        latest = image
        lastFrameAt = CACurrentMediaTime()
        counter &+= 1
        let shouldMeasure = counter % Self.measureEvery == 0 || means == nil
        let first = !announced
        if first { announced = true }
        lock.unlock()

        if first {
            GradedViewfinder.log.notice("""
                graded viewfinder: first frame \(Int(image.extent.width), privacy: .public)                x\(Int(image.extent.height), privacy: .public),                 rotation \(Int(connection.videoRotationAngle), privacy: .public),                 mirrored \(connection.isVideoMirrored, privacy: .public)
                """)
        }
        reportRate()
        guard wantsFrames else { return }
        if shouldMeasure, let measured = FilmLookRenderer.shared.measureMeans(image) {
            lock.lock(); means = measured; lock.unlock()
        }
        lock.lock(); let current = means; lock.unlock()
        onFrame?(image, current)
    }
}

/// A `MTKView` that draws one `CIImage` per frame, aspect-filled.
final class GradedPreviewView: MTKView {
    private let ciContext: CIContext
    private let commands: MTLCommandQueue
    private let space = CGColorSpace(name: CGColorSpace.displayP3)
    private var image: CIImage?
    private var announced = false
    private var drawn = 0
    /// Handed the GPU time for a frame, from the command buffer's own clock.
    private let reportCost: @Sendable (Double) -> Void

    /// Nil where there is no Metal device: the simulator, and any failure on
    /// hardware. The caller then never adds an overlay and the plain preview
    /// is the viewfinder.
    static func make(cost: @escaping @Sendable (Double) -> Void) -> GradedPreviewView? {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else { return nil }
        return GradedPreviewView(device: device, queue: queue, cost: cost)
    }

    private init(device: MTLDevice, queue: MTLCommandQueue, cost: @escaping @Sendable (Double) -> Void) {
        commands = queue
        reportCost = cost
        ciContext = CIContext(mtlCommandQueue: queue, options: [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3) as Any,
            .cacheIntermediates: false
        ])
        super.init(frame: .zero, device: device)
        // Required for Core Image to render into the drawable's texture.
        framebufferOnly = false
        colorPixelFormat = .bgra8Unorm

        // **Wide colour, or the grade looks wrong rather than merely flat.**
        //
        // The pipeline works in extended linear Display P3 and renders out in
        // Display P3, which is what the preview layer shows on this screen. But
        // a `CAMetalLayer` defaults to sRGB, so P3 numbers written into it are
        // READ as sRGB and come out oversaturated: the reds go fluorescent and
        // the skin goes hot. Telling the layer its own colour space is what
        // makes the render mean what it says.
        //
        // The owner's bar: "the live should look better than the actual iOS
        // camera." It cannot be better while it is in the wrong colour space.
        (layer as? CAMetalLayer)?.colorspace = CGColorSpace(name: CGColorSpace.displayP3)

        // **The screen's own pixels, not points.** `autoResizeDrawable` sizes
        // the drawable as bounds times `contentScaleFactor`, so a factor of 1
        // would render the whole viewfinder at a third of the resolution on a
        // 3x screen and read as soft. Set rather than inherited, because the
        // inherited value depends on whoever adds this as a subview.
        contentScaleFactor = UIScreen.main.scale
        // Driven by the camera, not by the display link: a frame arrives and
        // is drawn. Ticking at 60Hz for a 30Hz feed would draw each frame twice.
        isPaused = true
        enableSetNeedsDisplay = false
        isOpaque = true
        isUserInteractionEnabled = false
        autoResizeDrawable = true
        backgroundColor = .black
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("not from a nib") }

    func show(_ image: CIImage) {
        self.image = image
        draw()
    }

    override func draw(_ rect: CGRect) {
        guard let image,
              let drawable = currentDrawable,
              let buffer = commands.makeCommandBuffer() else { return }
        let width = CGFloat(drawable.texture.width)
        let height = CGFloat(drawable.texture.height)
        guard width > 0, height > 0, image.extent.width > 0, image.extent.height > 0 else { return }

        // Aspect fill, the same framing `videoGravity = .resizeAspectFill`
        // gives the layer underneath — so uncovering the plain preview does
        // not move the picture.
        let scale = max(width / image.extent.width, height / image.extent.height)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let placed = scaled.transformed(by: CGAffineTransform(
            translationX: (width - scaled.extent.width) / 2 - scaled.extent.origin.x,
            y: (height - scaled.extent.height) / 2 - scaled.extent.origin.y))

        // **Flipped, because Core Image and a Metal texture disagree about
        // which way y runs.** Core Image works y-up; a texture is addressed
        // y-down. Measured rather than assumed, in
        // `GradedViewfinderOrientationTests`: a mark placed at the top of a
        // 2x2 picture arrives in the texture's BOTTOM row, red 255 where the
        // top row reads 0.
        //
        // This is the fault the owner reported as "the camera for some reason
        // is a weird orientation". Without it the graded overlay is the scene
        // upside down, sitting on a preview layer that is the right way up.
        let upright = placed.transformed(by: CGAffineTransform(scaleX: 1, y: -1)
            .concatenating(CGAffineTransform(translationX: 0, y: height)))

        if !announced {
            announced = true
            GradedViewfinder.log.notice("""
                graded viewfinder: drawing frame \(Int(image.extent.width), privacy: .public)                x\(Int(image.extent.height), privacy: .public)                 into drawable \(Int(width), privacy: .public)x\(Int(height), privacy: .public),                 scale \(scale, privacy: .public), flipped y
                """)
        }

        ciContext.render(upright, to: drawable.texture, commandBuffer: buffer,
                         bounds: CGRect(x: 0, y: 0, width: width, height: height),
                         colorSpace: space ?? CGColorSpaceCreateDeviceRGB())

        // **What the grade costs the GPU, as a number.** The live pipeline
        // grew from one colour table to eight passes when the looks came back
        // with their texture, and "is it smooth" should not be answered by
        // feel. 33ms is the whole budget at 30 frames a second, so a reading
        // near it is the signal to drop a blur. Sampled every sixtieth frame,
        // and measured on the command buffer's own clock rather than by
        // timing `commit`, which returns before the GPU has started.
        drawn &+= 1
        let report = reportCost
        let announce = drawn % 60 == 1
        if drawn <= 20 || announce {
            buffer.addCompletedHandler { finished in
                let ms = (finished.gpuEndTime - finished.gpuStartTime) * 1000
                report(ms)
                if announce {
                    GradedViewfinder.log.notice(
                        "graded viewfinder: \(ms, format: .fixed(precision: 2), privacy: .public) ms on the GPU for one frame")
                }
            }
        }
        buffer.present(drawable)
        buffer.commit()
    }
}
