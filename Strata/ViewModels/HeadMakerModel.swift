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
    // Hashable, not merely Equatable: `landed` is a set of them and the
    // screen's pip row is a `ForEach` over them.
    enum Step: Hashable { case starting, unavailable, lining, blink, smile, brows, surprised, wink, blinkAgain, making, preview, failed }

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
    /// Whether the expression being asked for right now has landed.
    private(set) var caught = false
    /// Which of the four have landed so far, so the screen can say how many
    /// there are and how many are done — the other half of "idk if it is
    /// working" is not knowing how much is left.
    private(set) var landed: Set<Step> = []

    let camera = CameraService()
    let engine = HeadCaptureEngine()

    private var linedUpSince: Date?
    /// When a face first appeared, whether or not it was in the outline.
    private var faceSeenSince: Date?
    private var flow: Task<Void, Never>?

    /// **Ceilings, not durations.** A stage ends as soon as the engine says
    /// the expression landed, so these are how long somebody gets, not how
    /// long everybody waits. That is what lets them be generous: they were
    /// 2.2s and 1.6s when they were fixed waits, which is not long enough to
    /// read four words and produce a face if you did not know what was
    /// coming, and there was no way to finish early if you did.
    ///
    /// A person who does as asked now gets through in about half the time it
    /// used to take; a person who hesitates gets half again as long.
    static let blinkWindow: Duration = .milliseconds(3000)
    static let smileWindow: Duration = .milliseconds(2600)
    static let browsWindow: Duration = .milliseconds(2600)
    static let surprisedWindow: Duration = .milliseconds(2600)
    /// A wink is one movement, not a face to arrange, so it lands as fast as
    /// a blink does once it is understood. The window is the blink's, which
    /// leaves room to read the words and try twice.
    static let winkWindow: Duration = .milliseconds(3000)

    /// How long a stage keeps watching after the expression first lands.
    /// The engine keeps the BEST frame, not the first that passed, so ending
    /// the instant the threshold is crossed would keep the smallest smile
    /// that counted rather than the biggest one made.
    static let settle: Duration = .milliseconds(350)

    /// The blink stage will not end before this however fast the eyes shut.
    /// It is the only stage that also has to come away with a good OPEN
    /// frame — the neutral face IS the head — and somebody who blinks the
    /// instant they are asked would otherwise leave nothing but half-open
    /// frames to build it from.
    static let leastBlink: Duration = .milliseconds(1400)

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
        canPressAnyway = false
        faceSeenSince = nil
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
        switch step {
        case .lining:
            hint = update.hint
            // A face that is visible but not yet framed still counts: it is
            // the thing the patience above is measured on.
            if update.hint == .noFace {
                faceSeenSince = nil
                canPressAnyway = false
            } else {
                let seen = faceSeenSince ?? Date()
                faceSeenSince = seen
                if !canPressAnyway, Date().timeIntervalSince(seen) >= Self.patience {
                    canPressAnyway = true
                    HapticsEngine.tick()
                }
            }
            guard update.hint == nil else {
                linedUpSince = nil
                return
            }
            // One tick the moment you are lined up, so you know the shutter
            // will take without having to look at it.
            if linedUpSince == nil {
                linedUpSince = Date()
                HapticsEngine.tick()
            }
        case .blink, .smile, .brows, .surprised, .wink, .blinkAgain:
            // The same tick, for the same reason: it landed, and you felt it
            // without having to look away from your own face.
            guard update.phase == Self.phase(for: step) else { return }
            guard update.caught, !caught else { return }
            caught = true
            landed.insert(Self.pip(for: step))
            HapticsEngine.tick()
        default:
            break
        }
    }

    static func phase(for step: Step) -> HeadCaptureEngine.Phase {
        if step == .blinkAgain { return .blinkAgain }
        return sequence.first { $0.step == step }?.phase ?? .idle
    }

    /// The pip a step fills: asking again for the blink is still the blink.
    static func pip(for step: Step) -> Step {
        step == .blinkAgain ? .blink : step
    }

    /// **One more blink, only when the first was missed** (owner,
    /// 2026-09-16). A head without a real blink can never blink, and a head
    /// that never blinks is the one thing the creator's head never is. Asked
    /// once, at the end, when everything else is already in hand; if it is
    /// missed again the head is made without one, as before.
    static func asksBlinkAgain(blinkCaught: Bool) -> Bool { !blinkCaught }

    /// A quick blink lands in well under a second once it is understood; this
    /// leaves room to read four words and try twice.
    static let blinkAgainWindow: Duration = .milliseconds(2600)

    /// Whether the face is where the outline asks for it.
    var isLinedUp: Bool { step == .lining && hint == nil }

    /// **Nobody may be stuck outside their own head.**
    ///
    /// The shutter used to take only a perfectly lined-up face, so anybody the
    /// framing disagreed with could never start at all: "it doesnt ever get
    /// started in making the head." The outline is guidance, not a gate. Once
    /// a face has been visible for a few seconds the shutter takes, and the
    /// caption keeps saying what would make it better.
    private(set) var canPressAnyway = false

    var canCapture: Bool { step == .lining && (hint == nil || canPressAnyway) }

    /// How long a face has to be visible before the shutter stops insisting.
    static let patience: TimeInterval = 5

    /// The shutter. The person decides when — after a last touch of the hair —
    /// rather than a timer deciding for them.
    func beginCapture() {
        guard canCapture else { return }
        HapticsEngine.snap()
        run(from: .blink)
    }

    /// The asks, in order. `Step` is the screen's word for one of them.
    ///
    /// **The wink is last on purpose.** It is the one people enjoy and the one
    /// some people cannot do, and both of those want it at the end: a flow
    /// that finishes on the fun one is remembered as fun, and an expression
    /// nobody manages costs nothing when everything before it is already in
    /// hand. Every stage after the blink is optional to the head.
    static let sequence: [(step: Step, phase: HeadCaptureEngine.Phase, window: Duration)] = [
        (.blink, .blink, HeadMakerModel.blinkWindow),
        (.smile, .smile, HeadMakerModel.smileWindow),
        (.brows, .brows, HeadMakerModel.browsWindow),
        (.surprised, .surprised, HeadMakerModel.surprisedWindow),
        (.wink, .wink, HeadMakerModel.winkWindow)
    ]

    /// **Each stage ends when it has what it came for, not when a clock runs
    /// out.** The old loop slept for a fixed window per expression and asked
    /// the engine nothing, so it could neither finish early for somebody who
    /// did as asked nor wait for somebody who was still reading — and it
    /// found out that a smile had been missed only at the very end, on the
    /// preview caption. Now the window is only a ceiling.
    private func run(from start: Step) {
        flow?.cancel()
        linedUpSince = nil
        guard let first = Self.sequence.firstIndex(where: { $0.step == start }) else { return }
        landed = []
        flow = Task { @MainActor in
            for stage in Self.sequence[first...] {
                caught = false
                step = stage.step
                engine.begin(stage.phase)
                if stage.step != .blink { HapticsEngine.tick() }
                await watch(for: stage.window,
                            atLeast: stage.step == .blink ? Self.leastBlink : .zero)
                guard !Task.isCancelled else { return }
            }
            if Self.asksBlinkAgain(blinkCaught: engine.caught(.shut)) {
                caught = false
                step = .blinkAgain
                engine.begin(.blinkAgain)
                HapticsEngine.tick()
                await watch(for: Self.blinkAgainWindow, atLeast: .zero)
                guard !Task.isCancelled else { return }
            }
            await make()
        }
    }

    /// Waits until the expression lands or the ceiling is reached, then keeps
    /// watching for `settle` so the best frame is really the best one made.
    ///
    /// Polled rather than awaited on a continuation: `caught` is set from the
    /// camera's callback hopping to this actor, and a 60ms poll is both a
    /// frame's worth of latency and about a tenth of what a person can
    /// perceive as a delay. A continuation here would have to be resumed from
    /// `receive` exactly once, and a phase that lands twice — or a cancel
    /// arriving between the two — is a crash rather than a late tick.
    private func watch(for ceiling: Duration, atLeast floor: Duration) async {
        let start = ContinuousClock.now
        let deadline = start + ceiling
        let earliest = start + floor
        while ContinuousClock.now < deadline {
            if caught, ContinuousClock.now >= earliest { break }
            try? await Task.sleep(for: .milliseconds(60))
            if Task.isCancelled { return }
        }
        guard caught else { return }
        try? await Task.sleep(for: Self.settle)
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
        let side = HeadStore.side, chin = HeadStore.chin, contentHeight = HeadStore.contentHeight

        // Only what was really done is kept. Thick frames can make shut look
        // half open, and a "smile" measured on a neutral mouth is a second
        // neutral face — both worse than leaving the expression out.
        //
        // **Asked of the engine, not re-derived here.** This used to be four
        // inline copies of the same judgement, which is one copy more than
        // the screen can be told without risking a tick that turns out to be
        // a lie. `HeadCaptureEngine.caught(_:)` is the only copy now.
        let shut = engine.caught(.shut) ? takes[.shut] : nil
        let smile = engine.caught(.smile) ? takes[.smile] : nil
        let brows = engine.caught(.brows) ? takes[.brows] : nil
        let surprised = engine.caught(.surprised) ? takes[.surprised] : nil
        let wink = engine.caught(.wink) ? takes[.wink] : nil

        let payload = await Task.detached(priority: .userInitiated) { () -> HeadStore.Payload? in
            // **The crop is decided after the person is lifted out**, because
            // that is the only moment the hair can be measured: a lot of hair
            // reaches past what the face box guesses, and the crown was cut by
            // the top of the square. See `HeadFraming.crop(crownReach:)`.
            guard let lifted = HeadCaptureEngine.lift(open) else { return nil }
            let base = HeadFraming.crop(face: open.face, in: size, contentHeight: contentHeight,
                                        chin: chin, eyes: openEyes, chinPoint: open.chin,
                                        crownReach: HeadCaptureEngine.crownReach(of: lifted, take: open))
            // Every other expression lined up with this one by the eyes, so
            // changing face never moves the head.
            func aligned(_ take: HeadCaptureEngine.Take) -> CGRect {
                take.eyeCentres.map { HeadFraming.alignedCrop(reference: base, referenceEyes: openEyes, eyes: $0) } ?? base
            }
            let shutCrop = shut.map(aligned), smileCrop = smile.map(aligned), browsCrop = brows.map(aligned)
            let surprisedCrop = surprised.map(aligned)
            let winkCrop = wink.map(aligned)

            guard let neutral = HeadCaptureEngine.cutOut(open, lifted: lifted, crop: base, side: side,
                                                         chin: chin, paintsEyes: true) else {
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
            // Keeps its own eyes. Painting takes both of them or neither, and
            // one drawn iris beside one shut eye is exactly the uncanny thing
            // the rule exists to prevent — the same reason a grin keeps its
            // own narrowed eyes.
            if let wink, let winkCrop,
               let made = HeadCaptureEngine.cutOut(wink, crop: winkCrop, side: side, chin: chin, paintsEyes: false) {
                faces[.wink] = HeadStore.Face(png: made.png, eyes: [])
            }
            var shutPNG: Data?
            if let shut, let shutCrop {
                shutPNG = HeadCaptureEngine.cutOut(shut, crop: shutCrop, side: side, chin: chin, paintsEyes: false)?.png
            }
            // The creator's kind of face from these captures: shut eyes on
            // every face that can blink, brows that change only the brows.
            return HeadStore.Payload(faces: faces, shut: shutPNG).derived()
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
        caught = false
        landed = []
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
        // Part-way through, so the pip row can be photographed with some of
        // it done rather than only empty or full.
        case "blink":
            step = .blink
        case "smile":
            step = .smile
            landed = [.blink]
        case "brows":
            step = .brows
            landed = [.blink, .smile]
        case "surprised":
            step = .surprised
            landed = [.blink, .smile, .brows]
        case "blinkagain":
            step = .blinkAgain
            landed = [.smile, .brows, .surprised, .wink]
        case "wink":
            step = .wink
            landed = [.blink, .smile, .brows, .surprised]
        case "caught":
            step = .smile
            landed = [.blink, .smile]
            caught = true
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
