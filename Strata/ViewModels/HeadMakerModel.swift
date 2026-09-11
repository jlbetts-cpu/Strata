import Observation
import UIKit

/// The steps of making a head, and the camera and engine behind them.
///
/// Line up, press, blink, smile, raise your brows (the last two skippable),
/// lift out, look, keep. Nothing is placed by hand at any point — see
/// `docs/profile-and-head-plan.md` §5.2 for why.
@Observable
@MainActor
final class HeadMakerModel {
    enum Step: Equatable { case starting, unavailable, lining, blink, smile, brows, surprised, making, preview, failed }

    struct Result {
        let rig: HeadRig
        let payload: HeadStore.Payload
    }

    private(set) var step: Step = .starting
    private(set) var hint: HeadFraming.Hint? = .noFace
    /// Portrait 1080p until the first frame says otherwise.
    private(set) var frameSize = CGSize(width: 1080, height: 1920)
    private(set) var failure = ""
    private(set) var result: Result?

    let camera = CameraService()
    let engine = HeadCaptureEngine()

    private var linedUpSince: Date?
    private var flow: Task<Void, Never>?

    /// A slow, deliberate blink is about 400ms. Two seconds holds one with
    /// room either side for somebody who reads the prompt first.
    static let blinkWindow: Duration = .milliseconds(2200)
    static let smileWindow: Duration = .milliseconds(1600)
    static let browsWindow: Duration = .milliseconds(1600)
    static let surprisedWindow: Duration = .milliseconds(1600)

    func start() async {
        await camera.start()
        guard camera.isConfigured else {
            step = .unavailable
            return
        }
        camera.useFrontCamera()
        camera.attachFrames(engine.output)
        engine.onUpdate = { [weak self] update in
            Task { @MainActor in self?.receive(update) }
        }
        step = .lining
        engine.begin(.lining)
    }

    func stop() {
        flow?.cancel()
        engine.begin(.idle)
        engine.onUpdate = nil
        camera.detachFrames()
        camera.stop()
    }

    /// Where the outline asks the face to be. The view works it out from where
    /// it draws the outline, so the two can never disagree.
    func setTarget(_ target: HeadFraming.Target) {
        engine.setTarget(target)
    }

    private func receive(_ update: HeadCaptureEngine.Update) {
        frameSize = update.frameSize
        guard step == .lining else { return }
        hint = update.hint
        guard update.hint == nil else {
            linedUpSince = nil
            return
        }
        // One tick the moment you are lined up, so you know the shutter will
        // take without having to look at it.
        if linedUpSince == nil {
            linedUpSince = Date()
            HapticsEngine.tick()
        }
    }

    /// Whether the shutter can be pressed.
    var isLinedUp: Bool { step == .lining && hint == nil }

    /// The shutter. The person decides when — after a last touch of the hair —
    /// rather than a timer deciding for them.
    func beginCapture() {
        guard isLinedUp else { return }
        HapticsEngine.snap()
        run(from: .blink)
    }

    private func run(from start: Step) {
        flow?.cancel()
        linedUpSince = nil
        let sequence: [(step: Step, phase: HeadCaptureEngine.Phase, window: Duration)] = [
            (.blink, .blink, Self.blinkWindow),
            (.smile, .smile, Self.smileWindow),
            (.brows, .brows, Self.browsWindow),
            (.surprised, .surprised, Self.surprisedWindow)
        ]
        guard let first = sequence.firstIndex(where: { $0.step == start }) else { return }
        flow = Task { @MainActor in
            for stage in sequence[first...] {
                step = stage.step
                engine.begin(stage.phase)
                if stage.step != .blink { HapticsEngine.tick() }
                try? await Task.sleep(for: stage.window)
                guard !Task.isCancelled else { return }
            }
            await make()
        }
    }

    private func make() async {
        step = .making
        engine.begin(.idle)
        let takes = engine.takes
        guard let open = takes[.open], let openEyes = open.eyeCentres else {
            fail("Couldn't get a clear picture. Try again somewhere a little brighter.")
            return
        }

        let size = CGSize(width: open.image.width, height: open.image.height)
        let side = HeadStore.side, chin = HeadStore.chin
        let base = HeadFraming.crop(face: open.face, in: size, contentHeight: HeadStore.contentHeight, chin: chin)
        // Every other expression lined up with this one by the eyes, so
        // changing face never moves the head.
        func aligned(_ take: HeadCaptureEngine.Take) -> CGRect {
            take.eyeCentres.map { HeadFraming.alignedCrop(reference: base, referenceEyes: openEyes, eyes: $0) } ?? base
        }

        // Only what was really done is kept. Thick frames can make shut look
        // half open, and a "smile" measured on a neutral mouth is a second
        // neutral face — both worse than leaving the expression out.
        let shut = takes[.shut].flatMap { HeadFraming.isRealBlink(open: open.score, shut: $0.score) ? $0 : nil }
        let smile = takes[.smile].flatMap { take -> HeadCaptureEngine.Take? in
            guard let neutral = open.smileWidth, let wide = take.smileWidth else { return take }
            return HeadFraming.isRealSmile(neutral: neutral, smile: wide) ? take : nil
        }
        let brows = takes[.brows].flatMap { take -> HeadCaptureEngine.Take? in
            guard let neutral = open.browRaise, let raised = take.browRaise else { return take }
            return HeadFraming.isRealBrowRaise(neutral: neutral, raised: raised) ? take : nil
        }
        let surprised = takes[.surprised].flatMap { take -> HeadCaptureEngine.Take? in
            guard let neutral = open.mouthOpen, let wide = take.mouthOpen else { return take }
            return HeadFraming.isRealSurprise(neutral: neutral, surprised: wide) ? take : nil
        }
        let shutCrop = shut.map(aligned), smileCrop = smile.map(aligned), browsCrop = brows.map(aligned)
        let surprisedCrop = surprised.map(aligned)

        let payload = await Task.detached(priority: .userInitiated) { () -> HeadStore.Payload? in
            guard let neutral = HeadCaptureEngine.cutOut(open, crop: base, side: side, chin: chin, paintsEyes: true) else {
                return nil
            }
            var faces: [HeadRig.Expression: HeadStore.Face] = [.neutral: HeadStore.Face(png: neutral.png, eyes: neutral.eyes)]
            if let smile, let smileCrop,
               let made = HeadCaptureEngine.cutOut(smile, crop: smileCrop, side: side, chin: chin, paintsEyes: false) {
                faces[.smile] = HeadStore.Face(png: made.png, eyes: [])
            }
            if let brows, let browsCrop,
               let made = HeadCaptureEngine.cutOut(brows, crop: browsCrop, side: side, chin: chin, paintsEyes: true) {
                faces[.browsUp] = HeadStore.Face(png: made.png, eyes: made.eyes)
            }
            if let surprised, let surprisedCrop,
               let made = HeadCaptureEngine.cutOut(surprised, crop: surprisedCrop, side: side, chin: chin, paintsEyes: true) {
                faces[.surprised] = HeadStore.Face(png: made.png, eyes: made.eyes)
            }
            var shutPNG: Data?
            if let shut, let shutCrop {
                shutPNG = HeadCaptureEngine.cutOut(shut, crop: shutCrop, side: side, chin: chin, paintsEyes: false)?.png
            }
            return HeadStore.Payload(faces: faces, shut: shutPNG)
        }.value

        guard !Task.isCancelled else { return }
        guard let payload, let rig = HeadStore.rig(from: payload) else {
            fail("Couldn't finish your head. Try again in front of a plainer background.")
            return
        }
        result = Result(rig: rig, payload: payload)
        HapticsEngine.success()
        step = .preview
    }

    func retake() {
        flow?.cancel()
        result = nil
        hint = .noFace
        step = .lining
        engine.begin(.lining)
    }

    /// True when the head is on disk.
    func save() -> Bool {
        guard let result else { return false }
        do {
            try HeadStore.shared.save(result.payload)
            return true
        } catch {
            fail("Couldn't save your head. Try again.")
            return false
        }
    }

    private func fail(_ message: String) {
        failure = message
        step = .failed
        engine.begin(.idle)
    }

    #if DEBUG
    /// Puts the maker straight into one state — `-strataOpenHeadMaker`.
    func applyDebugState(_ state: String) {
        switch state {
        case "blink":
            step = .blink
        case "smile":
            step = .smile
        case "brows":
            step = .brows
        case "surprised":
            step = .surprised
        case "failed":
            fail("Couldn't get a clear picture. Try again somewhere a little brighter.")
        case "preview", "lift":
            if let rig = HeadRig.creator() {
                result = Result(rig: rig, payload: HeadStore.Payload(faces: [:], shut: nil))
                step = .preview
            }
        default:
            hint = .moveCloser
            step = .lining
        }
    }
    #endif
}
