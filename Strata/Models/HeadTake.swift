import CoreGraphics
import Foundation

/// **A tap's expression**: which faces it wears, what the eyes and the head
/// do, and how long it holds.
///
/// Owner, 2026-09-15: "there should be a bunch of expressions and they should
/// hold for longer." A tap used to pull one wink for 1.4s (the creator's head)
/// or cut to another face with no motion at all (the sticker). There are
/// twelve now, each held 2.6 to 3.4 seconds, drawn from a shuffled deck so the
/// same one never comes twice running, and a new tap switches at once.
///
/// Built only from what a head already has: its captured faces, its shut
/// eyes, the drawn irises and the rig's yaw, roll, lean, dip and squash.
/// Nothing is drawn onto a face. Every take looks away from the viewer, and a
/// face whose eyes are the photograph's own (smile, wink) is never given a
/// gaze cue, because it would do nothing.
///
/// Pure data, so the whole catalogue is pinned by `HeadTakeTests`.
/// `LivingHeadView.play` and `CreatorHead` interpret it.
nonisolated struct HeadTake: Equatable, Sendable {
    nonisolated enum ID: String, CaseIterable, Sendable {
        case grin, laugh, wink, winkGrin, surprised, doubleTake, eyebrow, sideEye, sleepy, thinking, nod, shake
    }

    /// How the eyes get where a look sends them.
    nonisolated enum Speed: Equatable, Sendable {
        /// `GridConstants.eyeSaccade`, the normal look.
        case saccade
        /// `GridConstants.naturalSettle`: a slow drift away.
        case drift
        /// `GridConstants.tapPopSpring`: snapped back.
        case snap
    }

    /// Which spring a pose moves on.
    nonisolated enum Motion: Equatable, Sendable {
        /// `GridConstants.headTurn`.
        case turn
        /// `GridConstants.headNod`: one beat of a nod or a shake.
        case nod
        /// `GridConstants.headTakeEaseBack`: a sleepy droop.
        case droop
    }

    nonisolated enum Step: Equatable, Sendable {
        /// Put on a face. A face the head lacks is skipped.
        case face(HeadRig.Expression)
        /// Send the eyes somewhere, -1...1 each way. `keepsRest` keeps the
        /// resting point underneath.
        case look(x: Double, y: Double, keepsRest: Bool = false, speed: Speed = .saccade)
        /// Hand the eyes back to where they rest.
        case release
        /// Degrees for yaw and roll; lean and dip as shares of the head's side.
        case pose(yaw: Double = 0, roll: Double = 0, lean: Double = 0, dip: Double = 0, motion: Motion = .turn)
        /// Lids down or up. Only a head with shut eyes has them.
        case lids(shut: Bool)
        /// A small squash and back, like a breath of laughter.
        case bounce
    }

    nonisolated struct Cue: Equatable, Sendable {
        /// Seconds from the tap.
        let at: TimeInterval
        let step: Step
    }

    /// What a played take carries to a view: which one, which way it is
    /// mirrored, and a nonce so the same id can be played again.
    nonisolated struct Played: Equatable, Sendable {
        let id: ID
        let direction: Double
        let nonce: Int
    }

    let id: ID
    /// Faces the take cannot do without.
    let needs: Set<HeadRig.Expression>
    /// It cannot do without shut eyes.
    let needsShut: Bool
    /// The face at its height: all Reduce Motion shows.
    let face: HeadRig.Expression
    /// Tap to ease-back, seconds.
    let hold: TimeInterval
    /// Authored for direction +1, sorted, every `at` before `hold`.
    let cues: [Cue]

    /// Mirrors x, yaw, roll and lean. Never y, dip or faces.
    func cues(direction: Double) -> [Cue] {
        let d = direction < 0 ? -1.0 : 1.0
        return cues.map { cue in
            switch cue.step {
            case let .look(x, y, keepsRest, speed):
                return Cue(at: cue.at, step: .look(x: x * d, y: y, keepsRest: keepsRest, speed: speed))
            case let .pose(yaw, roll, lean, dip, motion):
                return Cue(at: cue.at, step: .pose(yaw: yaw * d, roll: roll * d, lean: lean * d, dip: dip, motion: motion))
            default:
                return cue
            }
        }
    }

    /// One thing that happens at one moment of a take.
    nonisolated enum Event: Equatable, Sendable {
        case cue(Step)
        /// The end of the hold: the eyes and the head go back to calm, and
        /// the face with them unless the sticker is keeping it.
        case easeBack
    }

    nonisolated struct Moment: Equatable, Sendable {
        let at: TimeInterval
        let event: Event
    }

    /// **Everything the player does, in order, with the ease-back as its last
    /// moment.** `LivingHeadView.play` and `CreatorHead.play` walk this, so
    /// the timing a test reads is the timing that runs.
    func schedule(direction: Double) -> [Moment] {
        cues(direction: direction).map { Moment(at: $0.at, event: .cue($0.step)) }
            + [Moment(at: hold, event: .easeBack)]
    }

    /// Where the eyes are left looking when a kept take ends, which is what a
    /// sticker's photograph draws (`HeadStill`). The take's last look, unless
    /// it keeps the resting point (which wanders) or hands the eyes back.
    func stillGaze(direction: Double) -> CGPoint? {
        var gaze: CGPoint?
        for cue in cues(direction: direction) {
            switch cue.step {
            case let .look(x, y, keepsRest, _):
                gaze = keepsRest ? nil : CGPoint(x: x, y: y)
            case .release:
                gaze = nil
            default:
                break
            }
        }
        return gaze
    }

    /// The face a head is left wearing when this take's hold ends, given the
    /// faces it has: the last face cue it can do. What a sticker keeps, and so
    /// what gets drawn into the photograph.
    func endFace(has: (HeadRig.Expression) -> Bool) -> HeadRig.Expression {
        var face: HeadRig.Expression = .neutral
        for cue in cues {
            if case let .face(next) = cue.step, next == .neutral || has(next) { face = next }
        }
        return face
    }

    // MARK: - The catalogue

    static let catalogue: [HeadTake] = {
        typealias C = Cue
        let short = GridConstants.headTakeHoldShort, mid = GridConstants.headTakeHold
        let long = GridConstants.headTakeHoldLong
        return [
            // A grin, the head tipped with it.
            HeadTake(id: .grin, needs: [.smile], needsShut: false, face: .smile, hold: mid, cues: [
                C(at: 0, step: .face(.smile)),
                C(at: 0, step: .pose(roll: 3))
            ]),
            // A grin with three small nods of laughter.
            HeadTake(id: .laugh, needs: [.smile], needsShut: false, face: .smile, hold: mid - 0.2, cues: [
                C(at: 0, step: .face(.smile)),
                C(at: 0, step: .pose(roll: 2)),
                C(at: 0.12, step: .pose(roll: 2, dip: 0.025, motion: .nod)),
                C(at: 0.23, step: .pose(roll: 2, motion: .nod)),
                C(at: 0.34, step: .pose(roll: 2, dip: 0.025, motion: .nod)),
                C(at: 0.45, step: .pose(roll: 2, motion: .nod)),
                C(at: 0.56, step: .pose(roll: 2, dip: 0.025, motion: .nod)),
                C(at: 0.67, step: .pose(roll: 2, motion: .nod))
            ]),
            // The head cocks and leans in, then the wink.
            HeadTake(id: .wink, needs: [.wink], needsShut: false, face: .wink, hold: short, cues: [
                C(at: 0, step: .pose(roll: 5, lean: 0.03)),
                C(at: 0.06, step: .face(.wink))
            ]),
            // A wink that breaks into a grin.
            HeadTake(id: .winkGrin, needs: [.wink, .smile], needsShut: false, face: .smile, hold: mid + 0.2, cues: [
                C(at: 0, step: .face(.wink)),
                C(at: 0, step: .pose(roll: 4)),
                C(at: 0.9, step: .face(.smile)),
                C(at: 0.9, step: .bounce),
                C(at: 0.9, step: .pose(roll: 2))
            ]),
            // Something caught its eye: eyes off and up, the head lifts.
            HeadTake(id: .surprised, needs: [.surprised], needsShut: false, face: .surprised, hold: mid - 0.2, cues: [
                C(at: 0, step: .look(x: 0.6, y: -0.3)),
                C(at: 0, step: .pose(roll: -1.5, dip: -0.03)),
                C(at: 0.06, step: .face(.surprised)),
                C(at: 0.2, step: .bounce)
            ]),
            // Drift away, snap back, brows up.
            HeadTake(id: .doubleTake, needs: [.browsUp], needsShut: false, face: .browsUp, hold: short, cues: [
                C(at: 0, step: .look(x: 0.8, y: 0, speed: .drift)),
                C(at: 0, step: .pose(roll: 1.6)),
                C(at: 0.5, step: .look(x: -0.5, y: -0.05, speed: .snap)),
                C(at: 0.5, step: .pose()),
                C(at: 0.61, step: .face(.browsUp))
            ]),
            // The People's Eyebrow: head cocked, brows up, eyes off to the side.
            HeadTake(id: .eyebrow, needs: [.browsUp], needsShut: false, face: .browsUp, hold: mid, cues: [
                C(at: 0, step: .pose(roll: 4.6, dip: 0.02)),
                C(at: 0.24, step: .face(.browsUp)),
                C(at: 0.24, step: .look(x: -0.55, y: 0.05))
            ]),
            // Deadpan: the eyes go, the head does not, then a slow blink.
            HeadTake(id: .sideEye, needs: [], needsShut: false, face: .neutral, hold: mid, cues: [
                C(at: 0, step: .look(x: 0.9, y: 0.05)),
                C(at: 1.5, step: .lids(shut: true)),
                C(at: 2.125, step: .lids(shut: false))
            ]),
            // Dozing off: droop, lids down, up, down, then wakes with a start.
            HeadTake(id: .sleepy, needs: [], needsShut: true, face: .neutral, hold: long, cues: [
                C(at: 0, step: .look(x: 0, y: 0.35, keepsRest: true)),
                C(at: 0, step: .pose(roll: 6, dip: 0.02, motion: .droop)),
                C(at: 0.5, step: .lids(shut: true)),
                C(at: 1.2, step: .lids(shut: false)),
                C(at: 2.0, step: .lids(shut: true)),
                C(at: 2.9, step: .lids(shut: false)),
                C(at: 2.9, step: .pose()),
                C(at: 2.9, step: .face(.browsUp)),
                C(at: 3.12, step: .face(.neutral))
            ]),
            // Eyes up and off, the head turns a little with them.
            HeadTake(id: .thinking, needs: [], needsShut: false, face: .neutral, hold: mid, cues: [
                C(at: 0, step: .look(x: 0.45, y: -0.8)),
                C(at: 0.08, step: .pose(yaw: 6, roll: 2.5)),
                C(at: 1.6, step: .look(x: 0.2, y: -0.85))
            ]),
            // Three nods, and a smile if it has one.
            HeadTake(id: .nod, needs: [], needsShut: false, face: .neutral, hold: short, cues: [
                C(at: 0, step: .look(x: 0.1, y: 0.2, keepsRest: true)),
                C(at: 0.1, step: .pose(dip: 0.03, motion: .nod)),
                C(at: 0.2, step: .pose(motion: .nod)),
                C(at: 0.3, step: .pose(dip: 0.03, motion: .nod)),
                C(at: 0.4, step: .pose(motion: .nod)),
                C(at: 0.5, step: .pose(dip: 0.03, motion: .nod)),
                C(at: 0.6, step: .pose(motion: .nod)),
                C(at: 0.8, step: .face(.smile))
            ]),
            // A little shake of the head, and brows up if it has them.
            HeadTake(id: .shake, needs: [], needsShut: false, face: .neutral, hold: short, cues: [
                C(at: 0, step: .look(x: -0.5, y: 0)),
                C(at: 0.08, step: .pose(yaw: 8, roll: 1, motion: .nod)),
                C(at: 0.19, step: .pose(yaw: -8, roll: 1, motion: .nod)),
                C(at: 0.3, step: .pose(yaw: 6, roll: 1, motion: .nod)),
                C(at: 0.41, step: .pose(yaw: -6, roll: 1, motion: .nod)),
                C(at: 0.52, step: .pose(motion: .nod)),
                C(at: 0.7, step: .face(.browsUp))
            ])
        ]
    }()

    static func take(_ id: ID) -> HeadTake {
        catalogue.first { $0.id == id }!
    }

    /// The takes a head can do. Under Reduce Motion only a change of face is
    /// left, so it is one take per face it has other than neutral, and no two
    /// taps land on the same picture.
    static func available(faces: Set<HeadRig.Expression>, hasShut: Bool, reduceMotion: Bool) -> [HeadTake] {
        let doable = catalogue.filter { $0.needs.isSubset(of: faces) && (hasShut || !$0.needsShut) }
        guard reduceMotion else { return doable }
        var seen = Set<HeadRig.Expression>()
        return doable.filter { take in
            guard take.face != .neutral, faces.contains(take.face), !seen.contains(take.face) else { return false }
            seen.insert(take.face)
            return true
        }
    }
}

/// **Random without an immediate repeat**: a shuffled bag, refilled when it
/// runs out, whose first draw is never the one played last. Every take is seen
/// before any is seen twice.
nonisolated struct HeadTakeDeck: Sendable {
    private(set) var last: HeadTake.ID?
    private var bag: [HeadTake.ID] = []

    init() {}

    mutating func next<G: RandomNumberGenerator>(from available: [HeadTake], using rng: inout G) -> HeadTake? {
        guard !available.isEmpty else { return nil }
        let ids = Set(available.map(\.id))
        bag.removeAll { !ids.contains($0) }
        if bag.isEmpty {
            bag = available.map(\.id).shuffled(using: &rng)
            if bag.count > 1, bag.first == last { bag.swapAt(0, 1) }
        }
        let id = bag.removeFirst()
        last = id
        return HeadTake.take(id)
    }

    mutating func next(from available: [HeadTake]) -> HeadTake? {
        var rng = SystemRandomNumberGenerator()
        return next(from: available, using: &rng)
    }
}
