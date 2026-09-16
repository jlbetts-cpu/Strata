import CoreGraphics
import Foundation

/// **A head's idle life, as data.**
///
/// Owner, 2026-09-16: "make sure the custom head is up to the same standards,
/// animations, movements and the way it moves" as his own black-and-white
/// head. There used to be two engines, and a made head turned its head about
/// thirteen times less often than his while its eyes fidgeted eighty times a
/// minute. Now there is one: idle beats are cue lists in `HeadTake`'s own
/// vocabulary, resolved here with their randomness baked in, and
/// `LivingHeadView` plays them with the same `apply` that plays a tap.
///
/// ## Why it does not feel like it is watching you
///
/// Carried over from the creator's head, where it was first written down:
/// - **It breaks eye contact.** People prefer mutual gaze of about three
///   seconds (Binetti et al., 2016, *Royal Society Open Science*); held much
///   longer it reads as a stare. The eyes rest on you for 1.2 to 2.6 seconds,
///   never more than 3, and then always look away on purpose. In chrome they
///   never rest on you at all.
/// - **Eyes lead, head follows.** In a real head turn the eyes land first and
///   the head catches up, and as it arrives the eyes give some of the turn
///   back (Guitton & Volle, 1987, *J. Neurophysiology*). A head that turns
///   with its eyes fixed looks like a mask being rotated.
/// - **It blinks as it turns**, about half the time. Blinks cluster with gaze
///   shifts (Evinger et al., 1994, *Experimental Brain Research*).
/// - **It blinks every three to five seconds, irregularly.** A fixed clock
///   reads as a machine.
/// - **It says hello with its eyebrows first.** The eyebrow flash is a
///   greeting across cultures (Eibl-Eibesfeldt, 1972), then a wink.
/// - **Nothing repeats back to back.**
nonisolated enum HeadBeat {
    nonisolated enum ID: String, CaseIterable, Sendable {
        case glance, turn, tilt, down, brow, browFlash, lift, smile, nod,
             peoplesEyebrow, sideEye, eyeRoll, doubleTake, slowBlink, surprise, wink, hello
    }

    /// Faces a beat cannot do without.
    static func needs(_ id: ID) -> Set<HeadRig.Expression> {
        switch id {
        case .brow, .browFlash, .peoplesEyebrow, .doubleTake: return [.browsUp]
        case .smile: return [.smile]
        case .surprise: return [.surprised]
        case .wink: return [.wink]
        default: return []
        }
    }

    /// Beats that need the neutral face's shut eyes.
    static func needsShut(_ id: ID) -> Bool { id == .slowBlink }

    /// Beats that turn the head in 3D.
    static func turnsHead(_ id: ID) -> Bool { id == .glance || id == .turn }
}

/// **A tiny seedable generator**, so the same seed gives the same life on any
/// head, and the tests can read it. `SystemRandomNumberGenerator` cannot be
/// seeded.
nonisolated struct HeadRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// **What a head does, and when.** Pure: picks beats, rests, fixations,
/// micro-saccades and blinks, and resolves a beat into moments. The view only
/// sleeps and applies.
nonisolated struct HeadDirector: Sendable {
    nonisolated struct Fixation: Equatable, Sendable {
        let gaze: CGPoint
        let hold: Double
        /// Resting on you.
        let contact: Bool
    }

    nonisolated struct Blink: Equatable, Sendable {
        let gap: Double
        /// The squash as the lids close. 1: none.
        let depth: Double
        /// Steps the lids stay down after the crunch releases.
        let steps: Int
        let double: Bool
    }

    let life: HeadLife
    let faces: Set<HeadRig.Expression>
    let shutFaces: Set<HeadRig.Expression>
    let lookTarget: CGPoint?
    let forced: HeadBeat.ID?
    /// Three streams, one per loop, so the beats, the eyes and the blinks
    /// draw the same numbers from the same seed however the loops interleave
    /// on a busy main thread: two heads on one page stay in step.
    private(set) var random: HeadRandom
    private(set) var eyeRandom: HeadRandom
    private(set) var blinkRandom: HeadRandom
    private(set) var lastBeat: HeadBeat.ID?
    private(set) var lastWasContact = false

    init(life: HeadLife, faces: Set<HeadRig.Expression>, shutFaces: Set<HeadRig.Expression>,
         lookTarget: CGPoint? = nil, seed: UInt64? = nil, forced: HeadBeat.ID? = nil) {
        self.life = life
        self.faces = faces.union([.neutral])
        self.shutFaces = shutFaces
        self.lookTarget = lookTarget
        self.forced = forced
        var system = SystemRandomNumberGenerator()
        let base = seed ?? system.next()
        random = HeadRandom(seed: base)
        eyeRandom = HeadRandom(seed: base ^ 0xE1E5_0000_0000_0001)
        blinkRandom = HeadRandom(seed: base ^ 0xB11C_0000_0000_0002)
    }

    // MARK: - Chance

    mutating func uniform(_ range: ClosedRange<Double>) -> Double {
        Double.random(in: range, using: &random)
    }

    mutating func chance(_ share: Double) -> Bool {
        Double.random(in: 0..<1, using: &random) < share
    }

    private mutating func eyeUniform(_ range: ClosedRange<Double>) -> Double {
        Double.random(in: range, using: &eyeRandom)
    }

    private mutating func blinkUniform(_ range: ClosedRange<Double>) -> Double {
        Double.random(in: range, using: &blinkRandom)
    }

    // MARK: - Beats

    /// The beats this head can do, weighted, after substitutions: a head
    /// without raised brows lifts instead, one without a smile nods, and one
    /// that cannot blink turns its head more instead. In a fixed order, so two
    /// heads with the same faces pick the same way from the same seed.
    var weights: [(HeadBeat.ID, Double)] {
        var w = life.beatWeights
        if !faces.contains(.browsUp) {
            if let brow = w[.brow] { w[.lift, default: 0] += brow }
            for id in [HeadBeat.ID.brow, .browFlash, .peoplesEyebrow, .doubleTake] { w[id] = nil }
        }
        if !faces.contains(.smile), let smile = w[.smile] {
            w[.nod, default: 0] += smile
            w[.smile] = nil
        }
        if !faces.contains(.surprised) { w[.surprise] = nil }
        if !faces.contains(.wink) { w[.wink] = nil }
        if !shutFaces.contains(.neutral), let slow = w[.slowBlink] {
            if life.movesHead { w[.turn, default: 0] += slow }
            w[.slowBlink] = nil
        }
        w[.hello] = nil
        return HeadBeat.ID.allCases.compactMap { id in
            guard let weight = w[id], weight > 0 else { return nil }
            return (id, weight)
        }
    }

    /// Rest before the next beat, seconds.
    mutating func nextRest() -> Double {
        forced == nil ? uniform(life.beatRest) : 1.5
    }

    /// Weighted, never the same beat twice running, and which way it goes.
    mutating func nextBeat() -> (id: HeadBeat.ID, direction: Double) {
        let direction: Double = chance(0.5) ? 1 : -1
        let all = weights
        if let forced, all.contains(where: { $0.0 == forced }) {
            lastBeat = forced
            return (forced, direction)
        }
        var pool = all.filter { $0.0 != lastBeat }
        if pool.isEmpty { pool = all }
        guard !pool.isEmpty else { return (.glance, direction) }
        var roll = Double.random(in: 0..<pool.reduce(0) { $0 + $1.1 }, using: &random)
        var picked = pool[0].0
        for (id, weight) in pool {
            if roll < weight { picked = id; break }
            roll -= weight
        }
        lastBeat = picked
        return (picked, direction)
    }

    /// **A beat as moments**, direction and randomness resolved, ending with
    /// `.end`. Authored from the creator's head for glance, turn, tilt, down,
    /// brow and smile; the made head's extras keep their own numbers.
    mutating func resolve(_ id: HeadBeat.ID, direction dir: Double) -> [HeadTake.Moment] {
        typealias S = HeadTake.Step
        var cues: [(Double, S)] = []
        let moves = life.movesHead
        let maxYaw = life.maxYaw
        func at(_ t: Double, _ step: S) { cues.append((t, step)) }
        func pose(_ t: Double, yaw: Double = 0, roll: Double = 0, lean: Double = 0, dip: Double = 0,
                  motion: HeadTake.Motion = .turn) {
            guard moves else { return }
            at(t, .pose(yaw: min(max(yaw, -maxYaw), maxYaw), roll: roll, lean: lean, dip: dip, motion: motion))
        }
        /// The creator's distances were points on a 92pt head.
        func pts(_ points: Double) -> Double { points / 92 }
        let lead = GridConstants.headEyesLead, glanceLead = GridConstants.headEyesLeadGlance
        var end: Double

        switch id {
        case .glance:
            // Eyes to one side, then the head turns a little after them.
            at(0, .look(x: dir * 0.5, y: -0.05))
            pose(glanceLead, yaw: dir * GridConstants.headGlanceYaw, roll: dir * 1.1, lean: dir * pts(1))
            at(glanceLead + 0.9, .release)
            pose(glanceLead + 0.9)
            end = glanceLead + 1.3
        case .turn:
            // Eyes first, a blink half the time, then the head, tipping toward
            // what it looks at; as it arrives the eyes give some of it back.
            let target = lookTarget ?? CGPoint(x: dir, y: -0.1)
            let tx = Double(target.x), ty = Double(target.y)
            at(0, .look(x: tx, y: ty))
            if shutFaces.contains(.neutral), chance(0.5) {
                let depth = life.blinkDepth.map { uniform($0) } ?? 1
                at(lead, .blink(depth: depth, steps: chance(0.5) ? 2 : 1, double: false))
            }
            pose(lead, yaw: tx * maxYaw, roll: tx * 3, lean: tx * pts(3), dip: ty * pts(1.5))
            let given = lead + 0.38
            at(given, .look(x: tx * 0.45, y: ty * 0.45))
            let back = given + uniform(GridConstants.headTurnHold)
            at(back, .release)
            pose(back + lead)
            end = back + lead + 0.65
        case .tilt:
            at(0, .look(x: dir * 0.1, y: 0, keepsRest: true))
            pose(0, roll: dir * 3)
            at(1.3, .release)
            pose(1.3)
            end = 1.8
        case .down:
            // A look at the words underneath, then back.
            let target = CGPoint(x: -0.2, y: 1)
            at(0, .look(x: Double(target.x), y: Double(target.y)))
            pose(glanceLead, roll: dir * 1.2, dip: pts(1.5))
            let back = glanceLead + uniform(GridConstants.headDownHold)
            at(back, .release)
            pose(back)
            end = back + 0.5
        case .brow:
            at(0, .look(x: 0, y: -0.04, keepsRest: true))
            at(0, .face(.browsUp))
            at(0.48, .face(.neutral))
            at(0.48, .release)
            end = 0.94
        case .lift:
            // A head without raised brows says the same "oh, hello" with posture.
            at(0, .look(x: 0, y: -0.2, keepsRest: true))
            pose(0, dip: -0.015)
            at(0.48, .release)
            pose(0.48)
            end = 0.94
        case .browFlash:
            at(0, .face(.browsUp))
            at(0.22, .face(.neutral))
            end = 0.3
        case .smile:
            at(0, .look(x: 0, y: -0.05, keepsRest: true))
            at(0, .face(.smile))
            let back = uniform(GridConstants.headSmileHold)
            at(back, .settle)
            at(back, .release)
            end = back + 0.4
        case .nod:
            // A head without a smile is warm with motion instead.
            at(0, .look(x: 0.1, y: 0.2, keepsRest: true))
            for i in 0..<3 {
                pose(0.1 + Double(i) * 0.2, dip: 0.03, motion: .nod)
                pose(0.2 + Double(i) * 0.2, motion: .nod)
            }
            at(0.9, .release)
            end = 1.2
        case .sideEye:
            at(0, .look(x: dir * 0.9, y: 0.05))
            at(1.05, .release)
            end = 1.32
        case .doubleTake:
            at(0, .look(x: dir * 0.8, y: 0, speed: .drift))
            pose(0, roll: dir * 1.6)
            at(0.57, .look(x: -dir * 0.5, y: -0.05, speed: .snap))
            pose(0.57)
            at(0.68, .face(.browsUp))
            at(1.24, .face(.neutral))
            at(1.24, .release)
            end = 1.3
        case .peoplesEyebrow:
            pose(0, roll: dir * 4.6, dip: 0.02)
            at(0.24, .face(.browsUp))
            at(0.24, .look(x: -dir * 0.55, y: 0.05))
            at(1.53, .face(.neutral))
            at(1.53, .release)
            pose(1.53)
            end = 1.7
        case .eyeRoll:
            for index in 0...8 {
                let angle = Double(index) / 8 * .pi
                at(Double(index) * 0.125, .look(x: cos(angle) * -0.8 * dir, y: -sin(angle) * 0.95))
                pose(Double(index) * 0.125, roll: sin(angle) * 2.2 * dir)
            }
            at(1.125, .release)
            pose(1.125)
            end = 1.4
            // Sometimes amused with itself afterwards.
            if faces.contains(.smile), chance(0.4) {
                at(1.275, .face(.smile))
                at(1.975, .settle)
                end = 2.4
            }
        case .slowBlink:
            at(0, .look(x: 0, y: 0.25, keepsRest: true))
            at(0.42, .lids(shut: true))
            at(1.045, .lids(shut: false))
            at(1.345, .release)
            end = 1.4
        case .surprise:
            at(0, .look(x: dir * 0.6, y: -0.2))
            pose(0, roll: -dir * 1.5, dip: -0.02)
            at(0, .face(.surprised))
            let back = uniform(GridConstants.headSurpriseHold)
            pose(back)
            at(back, .settle)
            at(back + 0.25, .release)
            end = back + 0.4
        case .wink:
            pose(0, roll: dir * 4)
            at(0, .face(.wink))
            at(0.65, .settle)
            pose(0.65)
            end = 0.85
        case .hello:
            return greeting()
        }
        return Self.moments(cues, end: end)
    }

    /// **The hello**: brows first (240ms), then a wink held 1.6s, or a smile
    /// on a head without one. Beats then wait `firstBeatAfterHello`.
    mutating func greeting() -> [HeadTake.Moment] {
        var cues: [(Double, HeadTake.Step)] = []
        var t = GridConstants.headHelloDelay
        if faces.contains(.browsUp) {
            cues.append((t, .face(.browsUp)))
            cues.append((t + GridConstants.headHelloBrows, .face(.neutral)))
            t += 0.4
        }
        var end = t
        if faces.contains(.wink) {
            cues.append((t, .face(.wink)))
            cues.append((t + GridConstants.headHelloWink, .settle))
            end = t + GridConstants.headHelloWink + 0.25
        } else if faces.contains(.smile) {
            let hold = uniform(GridConstants.headSmileHold)
            cues.append((t, .look(x: 0, y: -0.05, keepsRest: true)))
            cues.append((t, .face(.smile)))
            cues.append((t + hold, .settle))
            cues.append((t + hold, .release))
            end = t + hold + 0.4
        }
        return Self.moments(cues, end: end)
    }

    private static func moments(_ cues: [(Double, HeadTake.Step)], end: Double) -> [HeadTake.Moment] {
        let sorted = cues.enumerated().sorted { a, b in
            a.element.0 == b.element.0 ? a.offset < b.offset : a.element.0 < b.element.0
        }
        return sorted.map { HeadTake.Moment(at: $0.element.0, event: .cue($0.element.1)) }
            + [HeadTake.Moment(at: max(end, cues.map(\.0).max() ?? 0), event: .end)]
    }

    // MARK: - Eyes

    /// **Where the eyes are drawn**: the resting point (kept by `restShare`),
    /// micro-saccades and a beat's or take's look, composed. When the resting
    /// point is NOT eye contact the result never comes nearer the middle than
    /// `headStareFloor`: a look that keeps the rest (a take's sleepy droop, a
    /// nod) can otherwise cancel an away point straight up and hold near
    /// contact for a whole take.
    static func composedGaze(rest: CGPoint, restShare: CGFloat, micro: CGPoint, look: CGPoint,
                             restIsContact: Bool) -> CGPoint {
        var x = Double(rest.x * restShare + micro.x + look.x)
        var y = Double(rest.y * restShare + micro.y + look.y)
        if !restIsContact {
            let floor = GridConstants.headStareFloor
            let length = hypot(x, y)
            if length < floor {
                if length < 0.001 {
                    // No direction left: out along the resting point, or down.
                    let rx = Double(rest.x), ry = Double(rest.y)
                    let r = hypot(rx, ry)
                    (x, y) = r > 0.001 ? (rx / r * floor, ry / r * floor) : (0, floor)
                } else {
                    x *= floor / length
                    y *= floor / length
                }
            }
        }
        return CGPoint(x: min(max(x, -1), 1), y: min(max(y, -1), 1))
    }

    /// **Where the eyes rest next, and for how long.** On an expressive head,
    /// after a look away the eyes come back to you about half the time, for
    /// 1.2 to 2.6 seconds (never more than `headContactMax`), and after that
    /// they ALWAYS look away. Everything that is not contact rests at least
    /// `headStareFloor` out from the middle. `allowContact` is false during a
    /// take, a kept sticker gaze, and anywhere calm.
    mutating func nextFixation(allowContact: Bool = true) -> Fixation {
        if life.contactShare > 0, allowContact, !lastWasContact, eyeUniform(0...1) < life.contactShare {
            lastWasContact = true
            let side: Double = eyeUniform(0...1) < 0.5 ? 1 : -1
            let gaze = CGPoint(x: side * eyeUniform(0.02...0.08), y: eyeUniform(-0.04...0.04))
            let hold = min(eyeUniform(life.contactHold), GridConstants.headContactMax)
            return Fixation(gaze: gaze, hold: hold, contact: true)
        }
        lastWasContact = false
        return Fixation(gaze: nextAway(), hold: eyeUniform(life.wander), contact: false)
    }

    /// A point that is not you: out from the middle, flattened vertically,
    /// and never inside the stare floor.
    mutating func nextAway() -> CGPoint {
        let floor = GridConstants.headStareFloor
        let angle = eyeUniform(0...(2 * .pi))
        let radius = eyeUniform(floor...0.9)
        var x = cos(angle) * radius, y = sin(angle) * radius * 0.62 - 0.04
        let length = hypot(x, y)
        if length < floor {
            let grow = floor / max(length, 0.001)
            x *= grow
            y *= grow
        }
        return CGPoint(x: x, y: y)
    }

    /// A micro-saccade and the wait before it. Nil on a calm head.
    mutating func nextMicro() -> (offset: CGPoint, after: Double)? {
        guard life.microSaccades else { return nil }
        let x = GridConstants.headMicroX, y = GridConstants.headMicroY
        return (CGPoint(x: eyeUniform(-x...x), y: eyeUniform(-y...y)), eyeUniform(GridConstants.headMicroEvery))
    }

    // MARK: - Blinks

    /// The creator's blink: a gap of 2.6 to 5.8s, a crunch as the lids close
    /// (expressive only), one or two steps shut, and one time in four a
    /// second blink straight after.
    mutating func nextBlink(allowDouble: Bool = true) -> Blink {
        let gap = blinkUniform(GridConstants.headBlinkGap)
        let depth = life.blinkDepth.map { blinkUniform($0) } ?? 1
        let steps = blinkUniform(0...1) < 0.5 ? 2 : 1
        let double = allowDouble && blinkUniform(0...1) < GridConstants.headDoubleBlinkShare
        return Blink(gap: gap, depth: depth, steps: steps, double: double)
    }
}
