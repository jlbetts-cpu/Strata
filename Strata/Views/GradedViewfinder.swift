import SwiftUI
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
    /// **Two rungs, and it can measure again after stepping down.**
    ///
    /// It had one: over budget, halation and bloom came off, and that was
    /// that. On his phone the whole pipeline was too slow and losing two
    /// blurs was not enough, so it stepped down once and stayed laggy.
    ///
    /// Now it measures, steps down, and measures AGAIN. The second rung also
    /// drops the glow and the clarity, which are the last two multi-pass
    /// filters, leaving colour, the tone curve, grain and the vignette —
    /// everything that costs one pass per pixel. That floor is cheap on any
    /// phone that can run the camera at all, and it still looks like a film
    /// look rather than like nothing.
    private var costs: [Double] = []
    private(set) var sparingHighlights = false
    private(set) var sparingBlurs = false
    /// Under 33ms is the 30fps budget; 18 leaves room for everything else on
    /// the screen, which on this one is a whole viewfinder's worth of chrome.
    private static let budgetMilliseconds = 18.0

    private func frameCost(_ milliseconds: Double) {
        guard costs.count < 20 else { return }
        costs.append(milliseconds)
        guard costs.count == 20 else { return }
        let median = costs.sorted()[10]
        guard median > Self.budgetMilliseconds else {
            Self.log.notice("""
                graded viewfinder: \(median, format: .fixed(precision: 2), privacy: .public) ms median, running the whole pipeline
                """)
            return
        }
        if !sparingHighlights {
            sparingHighlights = true
            Self.log.notice("""
                graded viewfinder: \(median, format: .fixed(precision: 2), privacy: .public) ms median, dropping halation and bloom
                """)
        } else {
            sparingBlurs = true
            Self.log.notice("""
                graded viewfinder: \(median, format: .fixed(precision: 2), privacy: .public) ms median, dropping glow and clarity too
                """)
        }
        // Measure the new pipeline rather than assuming one step was enough.
        costs.removeAll(keepingCapacity: true)
    }

    /// True when a look is selected AND frames are arriving.
    private var isDrawable: Bool { look.kind != .none && relay.isLive }

    private(set) var view: GradedPreviewView?
    /// The colour the composition guides are painted in. See `SceneTint`.
    let tint = SceneTint()
    let relay = CameraFrameRelay()
    private var watchdog: Timer?

    init() {
        relay.onSceneMean = { [weak self] means in
            Task { @MainActor in self?.tint.update(sceneMean: means) }
        }
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
        // The frame arriving here was underexposed by `pullStops` at the
        // sensor, so it is lifted by exactly the same amount the photograph
        // will be. That is what keeps the viewfinder and the picture the same
        // brightness while both keep their highlights.
        let graded = FilmLookRenderer.shared.live(look, to: image, means: means, phase: grainPhase,
                                                  sparingHighlights: sparingHighlights,
                                                  sparingBlurs: sparingBlurs,
                                                  pulledStops: look.pullStops)
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

/// **The colour of what the camera is pointed at, for the guides to be drawn
/// in.**
///
/// The owner, on the thirds lines: "what I liked about my figma compared to
/// this is it took the color but it didnt emulate glass, it was more flat."
///
/// His own node draws them `#98A184` at half opacity: flat paint, one colour,
/// no blur and no blend mode. `#98A184` is not from the palette — it is the
/// grass in the photograph behind it, lightened and drained. "I took the
/// colour from the background kinda and then turned the transparency down."
///
/// A fixed sage is right over grass and wrong over a kitchen counter, so what
/// generalises is the relationship rather than the value. That used to be done
/// with `glassEffect`, which was the only thing that would draw at all over a
/// `UIViewRepresentable` — a SwiftUI `Material` composites to nothing there,
/// measured at zero pixels of difference. But glass is a material, with a
/// refracted edge and a specular, and he can see it: it is not what his file
/// does.
///
/// The camera is already handing this class a measurement of the whole frame,
/// for white balance. Painting the lines from that is his relationship,
/// reproduced exactly and flatly: take the scene's colour, drain most of the
/// saturation out of it, lift it well above the scene's own brightness, and
/// draw it at half opacity. Sage over grass, pale blue over sky, warm over a
/// lit room, and flat everywhere.
@MainActor
@Observable
final class SceneTint {

    /// Where there is no camera yet: the simulator, the first frames of a
    /// launch, and any device that will not hand over frames. Neutral rather
    /// than tinted, because inventing a colour for a scene nobody has seen is
    /// worse than not tinting at all.
    static let fallback = Color(white: 0.78)

    private(set) var colour: Color = SceneTint.fallback

    /// Lifted and drained, in the proportion his own line has to his own
    /// grass.
    ///
    /// Measured off his file rather than chosen. His grass reads about
    /// (0.35, 0.45, 0.20) in HSV terms — hue 0.233, saturation 0.56, value
    /// 0.45 — and `#98A184` is hue 0.218, saturation 0.18, value 0.63. The
    /// hue is held, the saturation is about a third of the scene's, and the
    /// value is about 1.4 times it. Those two numbers are the whole
    /// transform.
    ///
    /// The value is then held inside a corridor. Below 0.55 a line over a
    /// dark room would disappear, and he asked for "still very visible";
    /// above 0.95 a line over a bright sky would be white paint, and he asked
    /// for the opposite of that — "the white UI has some trouble being
    /// visible against the bright image, I want it to be semi invisible." Low
    /// contrast over bright IS the intent here, and the ceiling is what keeps
    /// it from becoming a hairline of pure white.
    nonisolated static func tint(forSceneMean means: [Double]) -> Color? {
        guard means.count == 3 else { return nil }
        let scene = FilmLook.RGB(min(max(means[0], 0), 1),
                                 min(max(means[1], 0), 1),
                                 min(max(means[2], 0), 1))
        let (hue, saturation, value) = FilmLook.hsv(scene)
        // **The chroma is held, not drained, and that took a measurement to
        // get right.**
        //
        // Draining it by two thirds is the relationship his `#98A184` has to
        // his GRASS, and grass is a region. This number is the average of the
        // WHOLE frame — sky, rock, water and trees together — which has
        // already done most of the draining by itself. Measured on his own
        // valley photograph, the frame's mean saturation is 0.11 where the
        // grass alone is about 0.56; draining that again gave 0.036, which
        // composited to a neutral grey indistinguishable from the fallback.
        // The line was not taking any colour from the picture at all, and a
        // profile across it said so: the paint came back at (182, 186, 188).
        //
        // So the drain is already in the input, twice over, and the chroma
        // has to be put BACK for the line to be coloured at all. Measured on
        // his valley: hue 0.590, saturation 0.079, value 0.487. At 2.2 that
        // is a chroma of 0.174, which is within a hair of his own line's
        // 0.179 — the same amount of colour he chose, arrived at from the
        // frame instead of from the grass.
        //
        // A floor, so a grey room still gets a line. A ceiling, so a
        // photograph that really is all one colour gets a tinted line rather
        // than a coloured one.
        let chroma = min(max(saturation * 2.2, 0.05), 0.18)
        let lifted = min(max(value * 1.4, 0.55), 0.95)
        let out = FilmLook.rgb(h: hue, s: chroma, v: lifted)
        return Color(.displayP3, red: out.r, green: out.g, blue: out.b)
    }

    func update(sceneMean means: [Double]) {
        guard let next = Self.tint(forSceneMean: means) else { return }
        let (h, sat, v) = FilmLook.hsv(FilmLook.RGB(means[0], means[1], means[2]))
        GradedViewfinder.log.notice("""
            guides: scene hue \(h, format: .fixed(precision: 3), privacy: .public), saturation \(sat, format: .fixed(precision: 3), privacy: .public), value \(v, format: .fixed(precision: 3), privacy: .public)
            """)
        // Half a second, because the measurement moves as the camera moves and
        // a line that changes colour in steps reads as flicker. Long enough to
        // be a drift, short enough that walking indoors is not followed by a
        // line from outside.
        withAnimation(.easeInOut(duration: 0.5)) { colour = next }
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

    /// Handed every new whole-frame measurement, look or no look, so the
    /// guides can be painted in the colour of what the camera is pointed at.
    /// See `SceneTint`.
    var onSceneMean: (([Double]) -> Void)?

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
        // **Half as often when no look is on**, because then the only thing
        // that wants this is the guide colour and a line that re-tints once a
        // second is already drifting faster than a room's light changes. With
        // a look on, the white balance wants the finer cadence.
        let cadence = wantsFrames ? Self.measureEvery : Self.measureEvery * 2
        let shouldMeasure = counter % cadence == 0 || means == nil
        let first = !announced
        if first { announced = true }
        lock.unlock()

        if first {
            GradedViewfinder.log.notice("""
                graded viewfinder: first frame \(Int(image.extent.width), privacy: .public)                x\(Int(image.extent.height), privacy: .public),                 rotation \(Int(connection.videoRotationAngle), privacy: .public),                 mirrored \(connection.isVideoMirrored, privacy: .public)
                """)
        }
        reportRate()

        // Measured BEFORE the look gate, because the guides want it whether a
        // look is chosen or not. It is a synchronous GPU readback, which is
        // why it happens on a cadence rather than per frame, and it happens
        // on this queue rather than the main one.
        if shouldMeasure, let measured = FilmLookRenderer.shared.measureMeans(image) {
            lock.lock(); means = measured; lock.unlock()
            onSceneMean?(measured)
        }
        guard wantsFrames else { return }
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

        // **Two, not three, and this is where the lag was.**
        //
        // The owner, on the device: "the filters make everything very laggy."
        //
        // `.photo` hands the video output a PREVIEW sized buffer, around 1440
        // points tall. Rendering that into a drawable at the screen's 3x
        // scale means computing a 2622 point tall picture out of a 1440 point
        // source: two and a quarter times the pixels, for detail the source
        // does not contain. Every blur, every unsharp mask and every grain
        // sample in the pipeline was paying for it.
        //
        // At 2x the drawable is still comfortably above the source, so
        // nothing is lost that was ever there, and the whole pipeline gets
        // 55% cheaper. A factor of 1 really would read as soft; three was
        // simply free resolution nobody could see.
        contentScaleFactor = min(UIScreen.main.scale, 2)
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

        // **NOT flipped, and this cost three rounds to establish.**
        //
        // The owner reported the live viewfinder upside down three times. The
        // first fix changed the connection angle and added a y flip in one
        // commit, and on his phone both were 180 degree moves, so they
        // cancelled and he saw exactly what he had seen before. The second
        // kept the flip on the strength of a probe that rendered a 2x2 image
        // into a bare `MTLTexture` and read it back with `getBytes`.
        //
        // **That probe measured the wrong thing.** `getBytes` reads memory
        // order. A drawable presented by a `CAMetalLayer` is not displayed in
        // memory order, so a result about byte layout says nothing about what
        // ends up on the glass — and the flip it justified was the entire
        // fault.
        //
        // `ViewfinderLabView` measures the right thing: the real
        // `GradedPreviewView`, on screen, beside the same photograph drawn by
        // SwiftUI. With the flip in, the graded surface had rocks at the top
        // and sky at the bottom while SwiftUI had it the right way up. Core
        // Image renders into an `MTKView`'s drawable the right way up, and
        // there is nothing to correct.
        let upright = placed

        if !announced {
            announced = true
            GradedViewfinder.log.notice("""
                graded viewfinder: drawing frame \(Int(image.extent.width), privacy: .public)                x\(Int(image.extent.height), privacy: .public)                 into drawable \(Int(width), privacy: .public)x\(Int(height), privacy: .public),                 scale \(scale, privacy: .public)
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
