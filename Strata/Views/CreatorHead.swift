import SwiftUI

/// The owner's head, from his portfolio, on the thank-you page beside his
/// photograph.
///
/// Ported from the portfolio's hero (`hero-engine.js`), where it has been
/// tuned for a long time. The faces are photographs with the eyes left blank,
/// and the irises are drawn on top at measured points, so one head can blink,
/// look and change expression without a photograph for every state. Every
/// number in `HeadFace`, and the glance, tilt and brow beats, are that file's.
///
/// ## Why it does not feel like it is watching you
///
/// A face that stares is the fastest way to make a face creepy, so most of
/// what is here is about NOT doing that:
/// - **It breaks eye contact.** People prefer mutual gaze of about three
///   seconds (Binetti et al., 2016, *Royal Society Open Science*); held much
///   longer it reads as a stare. An idle beat looks away every 3.5–8s.
/// - **Eyes lead, head follows.** In a real head turn the eyes land first and
///   the head catches up, and as it arrives the eyes give some of the turn
///   back (Guitton & Volle, 1987, *J. Neurophysiology*). A head that turns
///   with its eyes fixed looks like a mask being rotated.
/// - **It blinks as it turns**, about half the time. Blinks cluster with gaze
///   shifts (Evinger et al., 1994, *Experimental Brain Research*).
/// - **It blinks every three to five seconds, irregularly.** A fixed clock
///   reads as a machine.
/// - **It says hello with its eyebrows first.** The eyebrow flash is a
///   greeting across cultures (Eibl-Eibesfeldt, 1972), then the wink.
/// - **It smiles on its own.** Not because anything happened — this page has
///   nothing to react to — but as one of the idle beats, about as often as it
///   turns.
/// - **Nothing repeats back to back**, and a turn is the rarer beat.
///
/// ## Why it costs nothing
///
/// Every movement is a short spring on a transform — offset, rotation, scale —
/// and between beats nothing runs at all: the loops are asleep in
/// `Task.sleep`, not polling a clock. No `TimelineView`, no `Canvas`, no
/// per-frame work, no breathing loop (a constant idle animation would keep the
/// screen redrawing for as long as the page is open). Both loops are `.task`s,
/// so they stop the moment the page goes away. Under Reduce Motion it only
/// changes expression.
///
/// No shadow. In the portfolio a head casts one only when it is standing on
/// something, and here it is not.
struct CreatorHead: View {
    /// The height of the head itself. The artwork's canvas is larger — the
    /// photograph has transparent margin round it — and overflows this frame
    /// unclipped, so the head lines up by its face rather than its file.
    var side: CGFloat = 44
    /// Eyebrow flash and a wink when it arrives.
    var greets: Bool = false
    /// Where the thing it is curious about lies, as a direction from the head
    /// (-1...1 each way, negative is left and up). It turns to look at it now
    /// and then — on the thank-you page, the photograph.
    var lookTarget: CGPoint = CGPoint(x: -1, y: -0.5)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var face: HeadFace = .neutral
    @State private var browUp = false
    @State private var shut = false
    @State private var blinking = false
    @State private var squash: CGFloat = 1
    /// Where the eyes point within the head, -1...1 each way. Zero is at you.
    @State private var gaze: CGPoint = .zero
    /// Head pose. Yaw turns it (degrees), roll tilts it about the neck
    /// (degrees), lean and dip carry it the few points a turning head travels.
    @State private var yaw: Double = 0
    @State private var roll: Double = 0
    @State private var lean: CGFloat = 0
    @State private var dip: CGFloat = 0
    @State private var reacting = false
    @State private var reaction: Task<Void, Never>?
    @State private var lastBeat: Beat?
    @State private var deck = HeadTakeDeck()

    /// The portfolio's clock. Its blink steps on an 8fps grid, and the
    /// posterised snap is what makes it read as a blink rather than a fade.
    private static let step: Duration = .milliseconds(125)
    /// The portfolio's iris travel (`TRAVEL`): a full look moves the iris 16%
    /// of the eye's width.
    private static let travel: CGFloat = 0.16
    /// How far a full turn goes. Past about 20° a flat photograph stops
    /// reading as a head and starts reading as a card.
    private static let maxYaw: Double = 16

    var body: some View {
        let canvas = side / HeadFace.contentHeight
        ZStack {
            Image(artwork)
                .resizable()
                .interpolation(.high)
            // A shut face has no iris. A drawn eyelid with a live iris sitting
            // on it does not read as a blink; it reads as broken.
            if !shut {
                ForEach(face.eyes.indices, id: \.self) { i in
                    let eye = face.eyes[i]
                    let size = CGSize(width: 2 * HeadFace.eyeRX * canvas,
                                      height: 2 * (eye.ry ?? HeadFace.eyeRY) * canvas)
                    HeadEye(size: size,
                            look: CGSize(width: gaze.x * size.width * Self.travel,
                                         height: gaze.y * size.height * Self.travel))
                        .position(x: eye.x * canvas, y: eye.y * canvas)
                }
            }
        }
        .frame(width: canvas, height: canvas)
        .scaleEffect(x: 1, y: squash, anchor: .bottom)
        .rotation3DEffect(.degrees(yaw), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
        .rotationEffect(.degrees(roll), anchor: .bottom)
        .offset(x: lean, y: dip)
        .frame(width: side, height: side)
        .contentShape(Rectangle())
        .onTapGesture { tapped() }
        .accessibilityHidden(true)
        .task { await greet() }
        #if DEBUG
        .task { await debugTakes() }
        #endif
        .task(id: reduceMotion) { await blinkWhileCalm() }
        .task(id: reduceMotion) { await beatWhileIdle() }
    }

    private var artwork: String {
        if shut { return face.closed }
        if browUp, face == .neutral { return HeadFace.neutralBrowsUp }
        return face.open
    }

    // MARK: - Expressions

    private func greet() async {
        guard greets else { return }
        // Long enough for the page to have finished arriving, so the hello is
        // seen rather than lost in the transition.
        try? await Task.sleep(for: .milliseconds(700))
        guard !Task.isCancelled else { return }
        if !reduceMotion {
            browUp = true
            try? await Task.sleep(for: .milliseconds(240))
            browUp = false
            try? await Task.sleep(for: .milliseconds(160))
            guard !Task.isCancelled else { return }
        }
        show(.wink, for: 1.6)
    }

    private func show(_ next: HeadFace, for seconds: Double) {
        reaction?.cancel()
        reacting = true
        reaction = Task { @MainActor in
            await change(to: next)
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            await change(to: .neutral)
            reacting = false
        }
    }

    /// A smile and a wink pop straight in — a blink on the way to a grin
    /// reads as hesitation. A calm face is reached through a blink, so the
    /// swap happens behind the lids, which is how the portfolio does it.
    private func change(to next: HeadFace) async {
        guard next != face else { return }
        if reduceMotion || next.popsIn {
            shut = false
            squash = 1
            face = next
            return
        }
        await blink(reopeningOn: next, allowDouble: false)
    }

    // MARK: - Tap expressions

    /// **A tap plays one of twelve expressions** (`HeadTake`), held 2.6 to
    /// 3.4 seconds, never the same one twice running, and a new tap switches at
    /// once. It used to be one wink for 1.4s: "there should be a bunch of
    /// expressions and they should hold for longer." The same catalogue as a
    /// made head, read here through this head's own faces.
    private func tapped() {
        let available = HeadTake.available(faces: Set(HeadRig.Expression.allCases), hasShut: true,
                                           reduceMotion: reduceMotion)
        guard let next = deck.next(from: available) else { return }
        HapticsEngine.lightTap()
        play(next, direction: Bool.random() ? 1 : -1)
    }

    /// The portfolio's faces for a rig's expressions. Raised brows are the
    /// neutral face with its brow picture.
    private static func headFace(_ expression: HeadRig.Expression) -> HeadFace {
        switch expression {
        case .neutral, .browsUp: return .neutral
        case .surprised: return .rest
        case .smile: return .smile
        case .wink: return .wink
        }
    }

    private func wear(_ expression: HeadRig.Expression) {
        face = Self.headFace(expression)
        browUp = expression == .browsUp
    }

    /// Runs in `reaction`, so a new tap (or the greeting) cancels it, and
    /// every sleep throws: an interrupted take stops dead.
    private func play(_ take: HeadTake, direction: Double) {
        reaction?.cancel()
        reacting = true
        reaction = Task { @MainActor in
            let start = ContinuousClock.now
            let easeBack = start + .seconds(HeadTake.easeBackAt(take))
            shut = false
            squash = 1
            if reduceMotion {
                wear(take.face)
                do { try await Task.sleep(until: easeBack, clock: .continuous) } catch { return }
                wear(.neutral)
                reacting = false
                return
            }
            look(.zero)
            pose()
            let opensOnFace = take.cues.contains { cue in
                if case .face = cue.step { return cue.at <= 0.1 }
                return false
            }
            if !opensOnFace { wear(.neutral) }
            for cue in take.cues(direction: direction) {
                do { try await Task.sleep(until: start + .seconds(cue.at), clock: .continuous) } catch { return }
                apply(cue.step)
            }
            do { try await Task.sleep(until: easeBack, clock: .continuous) } catch { return }
            look(.zero)
            pose(animation: GridConstants.headTakeEaseBack)
            shut = false
            squash = 1
            browUp = false
            await change(to: .neutral)
            guard !Task.isCancelled else { return }
            reacting = false
        }
    }

    private func apply(_ step: HeadTake.Step) {
        switch step {
        case let .face(expression):
            wear(expression)
        case let .look(x, y, _, _):
            look(CGPoint(x: x, y: y))
        case .release:
            look(.zero)
        case let .pose(yaw, roll, lean, dip, motion):
            let animation: Animation
            switch motion {
            case .turn: animation = GridConstants.headTurn
            case .nod: animation = GridConstants.headNod
            case .droop: animation = GridConstants.headTakeEaseBack
            }
            pose(yaw: min(max(yaw, -Self.maxYaw), Self.maxYaw), roll: roll,
                 lean: CGFloat(lean) * side, dip: CGFloat(dip) * side, animation: animation)
        case let .lids(closed):
            shut = closed
            squash = closed ? 0.94 : 1
        case .bounce:
            withAnimation(GridConstants.tapSquashSpring) { squash = 0.975 }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(160))
                guard !shut else { return }
                withAnimation(GridConstants.naturalSettle) { squash = 1 }
            }
        }
    }

    #if DEBUG
    /// `-strataHeadTake cycle|<id>`: plays the takes on their own, so each
    /// can be photographed at its hold. Logged as `[strata-head] take`.
    private func debugTakes() async {
        guard let wanted = DebugHarness.headTake else { return }
        try? await Task.sleep(for: .seconds(greets ? 5 : 3))
        var turn = 0
        while !Task.isCancelled {
            let pool = HeadTake.available(faces: Set(HeadRig.Expression.allCases), hasShut: true,
                                          reduceMotion: reduceMotion)
            let list = wanted == "cycle" ? pool : pool.filter { $0.id.rawValue.lowercased() == wanted }
            guard !list.isEmpty else { return }
            for next in list {
                turn += 1
                NSLog("[strata-head] take \(next.id.rawValue) hold \(next.hold) (creator)")
                play(next, direction: turn % 2 == 0 ? -1 : 1)
                try? await Task.sleep(for: .seconds(next.hold + 1.2))
                guard !Task.isCancelled else { return }
            }
        }
    }
    #endif

    // MARK: - Blinking

    private func blinkWhileCalm() async {
        guard !reduceMotion else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(Int.random(in: 2600...5800)))
            guard !Task.isCancelled else { return }
            guard !reacting, face.isCalm else { continue }
            await blink(allowDouble: true)
        }
    }

    /// Snap shut with a slight crunch, hold a step or two, reopen — and about
    /// one time in four, blink again straight after, because people do.
    private func blink(reopeningOn next: HeadFace? = nil, allowDouble: Bool) async {
        // Already mid-blink: ride that one rather than start a second on top.
        if blinking {
            if let next { face = next }
            return
        }
        blinking = true
        let deep = CGFloat.random(in: 0.905...0.935)
        shut = true
        squash = deep
        try? await Task.sleep(for: Self.step)
        squash = deep + 0.045
        for _ in 0..<Int.random(in: 1...2) {
            try? await Task.sleep(for: Self.step)
        }
        if allowDouble, Double.random(in: 0..<1) < 0.24 {
            shut = false
            squash = 1
            try? await Task.sleep(for: Self.step)
            shut = true
            squash = 0.92
            try? await Task.sleep(for: Self.step)
            squash = 0.95
            try? await Task.sleep(for: Self.step)
        }
        // A cancelled blink still ends open, but must not overwrite the face a
        // newer reaction has already put up.
        if let next, !Task.isCancelled { face = next }
        shut = false
        squash = 1
        blinking = false
    }

    // MARK: - Idle beats

    private enum Beat: String {
        case turn, glance, tilt, brow, down, smile
    }

    private func beatWhileIdle() async {
        guard !reduceMotion else { return }
        // Let the hello finish before anything else happens.
        try? await Task.sleep(for: .seconds(greets ? 3.4 : 1.5))
        while !Task.isCancelled {
            if !reacting, face.isCalm { await perform(nextBeat()) }
            let rest = Self.forcedBeat == nil ? Int.random(in: 3500...8000) : 1500
            try? await Task.sleep(for: .milliseconds(rest))
        }
    }

    /// Weighted, never the same beat twice running. A turn is the big move,
    /// so it is the rarer one; a head that keeps turning looks agitated.
    private func nextBeat() -> Beat {
        if let forced = Self.forcedBeat { return forced }
        // **A smile it arrives at on its own.** This used to be a reaction to
        // the win count going up — which cannot happen where this head
        // actually lives. It is on the onboarding thank-you page, and nobody
        // logs a win there: "the smile when you win doesnt make sense anymore
        // since its only in the onboarding it should just smile naturally."
        //
        // Rarer than a glance and about as often as a turn. A face that keeps
        // smiling at nothing is doing a bit; one that smiles now and then is
        // pleased you are here, which is what this page is for.
        let weights: [(Beat, Double)] = [(.glance, 0.26), (.turn, 0.19), (.tilt, 0.18),
                                         (.smile, 0.16), (.down, 0.12), (.brow, 0.09)]
        let pool = weights.filter { $0.0 != lastBeat }
        var r = Double.random(in: 0..<pool.reduce(0) { $0 + $1.1 })
        for (beat, weight) in pool {
            if r < weight { return beat }
            r -= weight
        }
        return pool[0].0
    }

    private func perform(_ beat: Beat) async {
        lastBeat = beat
        let dir: CGFloat = Bool.random() ? 1 : -1
        switch beat {
        case .turn:
            // Eyes first.
            look(lookTarget)
            guard await beatPause(90) else { return }
            if Double.random(in: 0..<1) < 0.5 {
                Task { await blink(allowDouble: false) }
            }
            // Then the head, tipping toward what it is looking at.
            pose(yaw: Double(lookTarget.x) * Self.maxYaw,
                 roll: Double(lookTarget.x) * 3,
                 lean: lookTarget.x * scaled(3),
                 dip: lookTarget.y * scaled(1.5))
            guard await beatPause(380) else { return }
            // The head has carried the eyes most of the way, so they give some back.
            look(CGPoint(x: lookTarget.x * 0.45, y: lookTarget.y * 0.45))
            guard await beatPause(Int.random(in: 1200...2200)) else { return }
            // And back to you — eyes first again.
            look(.zero)
            guard await beatPause(90) else { return }
            pose()
            guard await beatPause(650) else { return }
        case .glance:
            // Portfolio: eyes 0.5 to one side, a 1.1° tip, 1150ms.
            look(CGPoint(x: dir * 0.5, y: -0.05))
            guard await beatPause(80) else { return }
            pose(yaw: Double(dir) * 5, roll: Double(dir) * 1.1, lean: dir * scaled(1))
            guard await beatPause(900) else { return }
            look(.zero)
            pose()
            guard await beatPause(400) else { return }
        case .tilt:
            // Portfolio: a 3° tilt, eyes barely moving, 1500ms.
            look(CGPoint(x: dir * 0.1, y: 0))
            pose(roll: Double(dir) * 3)
            guard await beatPause(1300) else { return }
            look(.zero)
            pose()
            guard await beatPause(500) else { return }
        case .brow:
            // Portfolio: brows up for the middle half of 940ms.
            guard face == .neutral, !shut else { return }
            look(CGPoint(x: 0, y: -0.04))
            browUp = true
            guard await beatPause(480) else { return }
            browUp = false
            look(.zero)
            guard await beatPause(460) else { return }
        case .smile:
            // Eyes up a touch as it goes, the way a real one does, and back to
            // calm through the usual return in `show`.
            look(CGPoint(x: 0, y: -0.05))
            show(.smile, for: Double.random(in: 1.3...2.0))
            await pause(Int.random(in: 1500...2300))
            look(.zero)
        case .down:
            // A look at the words underneath, then back.
            look(CGPoint(x: -0.2, y: 1))
            guard await beatPause(80) else { return }
            pose(roll: Double(dir) * 1.2, dip: scaled(1.5))
            guard await beatPause(Int.random(in: 900...1500)) else { return }
            look(.zero)
            pose()
            guard await beatPause(500) else { return }
        }
    }

    /// A distance in points, scaled to the head's size. The numbers are what
    /// looked right on a 92pt head.
    private func scaled(_ points: CGFloat) -> CGFloat { points * side / 92 }

    /// Saccades are the fastest movement a body makes, so the eyes land
    /// before the head has started.
    private func look(_ point: CGPoint) {
        withAnimation(GridConstants.eyeSaccade) { gaze = point }
    }

    private func pose(yaw y: Double = 0, roll r: Double = 0, lean l: CGFloat = 0, dip d: CGFloat = 0,
                      animation: Animation = GridConstants.headTurn) {
        withAnimation(animation) {
            yaw = y
            roll = r
            lean = l
            dip = d
        }
    }

    private func pause(_ milliseconds: Int) async {
        try? await Task.sleep(for: .milliseconds(milliseconds))
    }

    /// An idle beat's pause. False when a tap's expression started while it
    /// slept: the beat stops rather than turning the head under the take.
    private func beatPause(_ milliseconds: Int) async -> Bool {
        try? await Task.sleep(for: .milliseconds(milliseconds))
        return !Task.isCancelled && !reacting
    }

    #if DEBUG
    /// `-strataHeadBeat turn|glance|tilt|brow|down` repeats one beat with a
    /// short rest, so it can be photographed rather than waited for.
    private static let forcedBeat: Beat? = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-strataHeadBeat"), i + 1 < args.count else { return nil }
        return Beat(rawValue: args[i + 1])
    }()
    #else
    private static let forcedBeat: Beat? = nil
    #endif
}

// MARK: - Faces

/// One expression: an open photograph, its shut twin, and where the eyes are.
///
/// Coordinates are fractions of the square canvas, measured against the
/// artwork in the portfolio's calibration mode (`hero-engine.js`, `FACES`).
/// Open and shut variants share a canvas, so a blink never moves the head.
struct HeadFace: Equatable {
    struct Eye: Equatable {
        let x: CGFloat
        let y: CGFloat
        var ry: CGFloat? = nil
    }

    let open: String
    let closed: String
    let eyes: [Eye]

    static func == (a: HeadFace, b: HeadFace) -> Bool { a.open == b.open }

    /// The eye's radii when a face does not override them (`RX`, `RY`).
    static let eyeRX: CGFloat = 0.0385
    static let eyeRY: CGFloat = 0.0192
    /// How much of the canvas's height the neutral head fills, crown to chin.
    /// Measured from the artwork's alpha: 0.113 to 0.898.
    static let contentHeight: CGFloat = 0.785
    /// Neutral with the brows raised. Same canvas and eyes as neutral — the
    /// portfolio swaps the picture and nothing else.
    static let neutralBrowsUp = "HeadNeutralBrowsUp"

    static let neutral = HeadFace(open: "HeadNeutral", closed: "HeadNeutralClosed",
                                  eyes: [Eye(x: 0.3999, y: 0.5176), Eye(x: 0.6018, y: 0.5265)])
    static let rest = HeadFace(open: "HeadRest", closed: "HeadRestClosed",
                               eyes: [Eye(x: 0.4000, y: 0.5169), Eye(x: 0.6041, y: 0.5269)])
    /// One eye open; the other is shut in the photograph.
    static let wink = HeadFace(open: "HeadWink", closed: "HeadWinkClosed",
                               eyes: [Eye(x: 0.4000, y: 0.5169, ry: 0.0172)])
    /// The eyes are part of the photograph — a grin narrows them past the
    /// point where a drawn iris sits right.
    static let smile = HeadFace(open: "HeadSmile", closed: "HeadSmileClosed", eyes: [])

    var isCalm: Bool { self == .neutral || self == .rest }
    var popsIn: Bool { self == .smile || self == .wink }
}

/// An iris, pupil and catchlight, clipped to the eye's opening.
///
/// The iris is 0.6 of the eye's width and 1.05 of its height, so the lids
/// crop it top and bottom the way real ones do. The catchlight does not move
/// with the gaze — it belongs to the light, not the eye. Sized from outside
/// rather than with a `GeometryReader`, so a look animates an offset and
/// nothing is laid out again.
private struct HeadEye: View {
    let size: CGSize
    let look: CGSize

    var body: some View {
        let w = size.width, h = size.height
        let iw = w * 0.6, ih = h * 1.05
        ZStack {
            ZStack {
                Ellipse()
                    .fill(RadialGradient(
                        stops: [
                            .init(color: Color(white: 0.02), location: 0),
                            .init(color: Color(white: 0.03), location: 0.25),
                            .init(color: Color(white: 0.10), location: 0.39),
                            .init(color: Color(red: 0.035, green: 0.043, blue: 0.141), location: 0.57),
                            .init(color: Color(white: 0.09), location: 0.72),
                            .init(color: Color(white: 0.04), location: 0.88),
                            .init(color: Color(white: 0.01), location: 1),
                        ],
                        center: .center, startRadius: 0, endRadius: hypot(iw, ih) / 2))
                    .frame(width: iw, height: ih)
                Ellipse()
                    .fill(.black)
                    .frame(width: iw * 0.55, height: ih * 0.55)
            }
            .offset(look)
            Ellipse()
                .fill(RadialGradient(
                    stops: [
                        .init(color: .white.opacity(0.98), location: 0),
                        .init(color: .white.opacity(0.72), location: 0.24),
                        .init(color: .white.opacity(0), location: 0.6),
                    ],
                    center: .center, startRadius: 0, endRadius: w * 0.1))
                .frame(width: w * 0.2, height: h * 0.2)
                .offset(x: w * -0.08, y: h * -0.14)
        }
        .frame(width: w, height: h)
        .clipShape(Ellipse())
    }
}
