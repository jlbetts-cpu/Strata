import SwiftUI

// The owner's drawings that move in parts (`InkFigure`). Every number is in
// his pixels: the drawing's 2048 canvas, cropped to the box its assets were
// cut from (the cut scripts measured each joint).
//
// **Animated, the cartoon way** (the owner, 2026-10-14: "for the animations
// make them more like animated"): a wind-up before each move, squash and
// stretch, an overshoot that settles, loose parts (a tail, a flap, a dash)
// arriving a beat behind, and a held beat on each key pose. Every joint
// turns or leans about the place the parts meet, so his line stays whole.

/// A target that steps and springs: each (time, change) moves the target by
/// `change` at `time`, and the value follows it on a spring, overshooting and
/// settling. The cartoon "whip to a pose and hold".
private func springSteps(_ t: Double, _ steps: [(Double, Double)], frequency: Double = 2.4, damping: Double = 0.38) -> Double {
    steps.reduce(0) { sum, step in
        t < step.0 ? sum : sum + step.1 * (1 - Ink.spring(t - step.0, frequency: frequency, damping: damping))
    }
}

// MARK: - The cat sliding down the wall (an error)

/// **A cat scratching down a wall** (the owner, 2026-10-14: "a cat scratching
/// down a wall we can use this for an error"). His two drawings: the cat
/// clinging, eyes shut, then scared, eyes wide, its scratches above its claws.
///
/// It hangs, calm. It gathers (a squash, its eyes screwing up), then startles:
/// it springs up stretched, its eyes pop open past round, its mouth gapes, its
/// tail whips over. It slides, stretched long, the arms reaching as the claws
/// drag and the scratches drawn in behind each paw; it lands in a squash, the
/// legs and tail swinging on after it. About 1.1s to the stop, settled by 1.7.
struct ErrorCat: View {
    var height: CGFloat = 150
    var body: some View { InkFigure(script: ErrorCatScript(), height: height) }
}

struct ErrorCatScript: InkScript {
    let canvas = CGSize(width: 760, height: 1510)
    let length: Double? = 1.7

    /// How far it slides: the length of his longest scratch above its paw.
    static let slide = 340.0
    static let gather = 0.14, swap = 0.3, slideFrom = 0.44, slideFor = 0.6
    static var stop: Double { slideFrom + slideFor }

    // Joints, measured on his drawing.
    /// Between the paws: it hangs from its claws, so it squashes and
    /// stretches from there.
    static let claws = CGPoint(x: 415, y: 340)
    static let shoulderLeft = CGPoint(x: 235, y: 647), pawLeftTop = 358.0
    static let shoulderRight = CGPoint(x: 595, y: 654), pawRightTop = 316.0
    static let scratchesLeftEnd = 382.0, scratchesRightEnd = 336.0, scratchesSplit = 450.0
    static let neck = CGPoint(x: 250, y: 760)
    static let tailRoot = CGPoint(x: 300, y: 1338), tailUpRoot = CGPoint(x: 278, y: 1338)
    static let hips = 1200.0
    static let eyeLeftShut = CGPoint(x: 322, y: 760), eyeRightShut = CGPoint(x: 482, y: 625)
    static let eyeLeftWide = CGPoint(x: 332, y: 757), eyeRightWide = CGPoint(x: 497, y: 630)
    static let nose = CGPoint(x: 406, y: 708), noseWide = CGPoint(x: 418, y: 712)
    static let mouth = CGPoint(x: 485, y: 731), mouthWide = CGPoint(x: 452, y: 758)

    func parts(at t: Double, stoppedAt: Double?) -> [InkPart] {
        typealias S = ErrorCatScript
        let scared = t >= S.swap
        // The beats: gather, leap, fall, land.
        let gather = Ink.bump(t, S.gather, 0.27, S.swap + 0.01)
        let leap = Ink.springOut(t - S.swap, frequency: 2.2, damping: 0.5)
        let fall = Ink.bump(t, S.slideFrom, 0.72, S.stop)
        let land = Ink.springOut(t - S.stop, frequency: 2.4, damping: 0.4)
        let sy = 1 - 0.06 * gather + 0.14 * leap + 0.05 * fall - 0.1 * land
        let sx = 1 + 0.03 * gather - 0.06 * leap - 0.02 * fall + 0.05 * land
        let off = -S.slide * (1 - Ink.smooth((t - S.slideFrom) / S.slideFor))
        let rise = -40 * leap
        let cat = Ink.scale(sx, sy, about: S.claws).then(Ink.move(0, off + rise))

        // The arms reach as the claws drag: one, then the other.
        let reachLeft = 0.12 * Ink.bump(t, S.slideFrom, 0.64, 0.98)
        let reachRight = 0.12 * Ink.bump(t, 0.5, 0.76, 1.04)
        let armLeft = Ink.scale(1, 1 + reachLeft, about: S.shoulderLeft).then(cat)
        let armRight = Ink.scale(1, 1 + reachRight, about: S.shoulderRight).then(cat)

        // Drawn in behind each paw: down to where its claws are now.
        let frontLeft = S.scratchesLeftEnd + off + rise - (S.shoulderLeft.y - S.pawLeftTop) * reachLeft
        let frontRight = S.scratchesRightEnd + off + rise - (S.shoulderRight.y - S.pawRightTop) * reachRight
        let scratches = [CGRect(x: 0, y: 0, width: S.scratchesSplit, height: frontLeft),
                         CGRect(x: S.scratchesSplit, y: 0, width: canvas.width - S.scratchesSplit, height: frontRight)]

        // The head ducks into the gather, flinches back, and nods on landing.
        let tilt = 2 * gather - 6 * leap + 1.5 * Ink.bump(t, 0.55, 0.85, 1.1) + 4 * land
        let head = Ink.rotate(tilt, about: S.neck).then(cat)

        // The eyes screw shut, then pop open past round and settle.
        let screw = 1 - 0.55 * gather
        let pop = 1 - 0.5 * Ink.spring(t - S.swap, frequency: 3, damping: 0.32)
        let gape = 1 - 0.75 * Ink.spring(t - S.swap - 0.03, frequency: 2.8, damping: 0.35)

        // The tail winds down, whips over, and swings on after the landing.
        let wind = 14 * gather
        let whip = -22 * Ink.spring(t - S.swap, frequency: 2.0, damping: 0.3)
            + 6 * sin((t - 0.5) * .pi * 2 / 0.5) * Ink.bump(t, 0.5, 0.75, S.stop)
            - 12 * Ink.springOut(t - S.stop - 0.05, frequency: 2.0, damping: 0.3)

        // The legs hang a beat behind: drawn up as it leaps and drops,
        // swinging long after it stops.
        let hang = 1 - 0.05 * leap - 0.05 * fall + 0.1 * Ink.springOut(t - S.stop + 0.04, frequency: 2.0, damping: 0.3)
        let swing = 0.09 * Ink.springOut(t - S.stop, frequency: 1.6, damping: 0.28)
        let legs = Ink.scale(1, hang, about: CGPoint(x: 0, y: S.hips)).then(Ink.shearX(swing, aboutY: S.hips)).then(cat)

        return [
            InkPart(asset: "ErrorCatLines", opacity: t >= S.slideFrom ? 1 : 0, reveal: scratches),
            InkPart(asset: "ErrorCatTorso", transform: cat),
            InkPart(asset: "ErrorCatLegs", transform: legs),
            InkPart(asset: "ErrorCatTail", transform: Ink.rotate(wind, about: S.tailRoot).then(cat), opacity: scared ? 0 : 1),
            InkPart(asset: "ErrorCatTailUp", transform: Ink.rotate(whip, about: S.tailUpRoot).then(cat), opacity: scared ? 1 : 0),
            InkPart(asset: "ErrorCatArmLeft", transform: armLeft),
            InkPart(asset: "ErrorCatArmRight", transform: armRight),
            InkPart(asset: "ErrorCatHead", transform: head),
            InkPart(asset: "ErrorCatEyeLeftShut", transform: Ink.scale(1 + 0.15 * gather, screw, about: S.eyeLeftShut).then(head), opacity: scared ? 0 : 1),
            InkPart(asset: "ErrorCatEyeRightShut", transform: Ink.scale(1 + 0.15 * gather, screw, about: S.eyeRightShut).then(head), opacity: scared ? 0 : 1),
            InkPart(asset: "ErrorCatNose", transform: head, opacity: scared ? 0 : 1),
            InkPart(asset: "ErrorCatMouth", transform: Ink.scale(screw, screw, about: S.mouth).then(head), opacity: scared ? 0 : 1),
            InkPart(asset: "ErrorCatEyeLeftWide", transform: Ink.scale(pop, pop * (1 + 0.1 * leap), about: S.eyeLeftWide).then(head), opacity: scared ? 1 : 0),
            InkPart(asset: "ErrorCatEyeRightWide", transform: Ink.scale(pop, pop * (1 + 0.1 * leap), about: S.eyeRightWide).then(head), opacity: scared ? 1 : 0),
            InkPart(asset: "ErrorCatNoseWide", transform: Ink.scale(pop, pop, about: S.noseWide).then(head), opacity: scared ? 1 : 0),
            InkPart(asset: "ErrorCatMouthWide", transform: Ink.scale(max(gape, 0.05), max(gape, 0.05), about: S.mouthWide).then(head), opacity: scared ? 1 : 0),
        ]
    }

    /// Reduce Motion: the scared cat, as he drew it.
    var still: [InkPart] {
        ["ErrorCatLines", "ErrorCatTorso", "ErrorCatLegs", "ErrorCatTailUp", "ErrorCatArmLeft", "ErrorCatArmRight",
         "ErrorCatHead", "ErrorCatEyeLeftWide", "ErrorCatEyeRightWide", "ErrorCatNoseWide", "ErrorCatMouthWide"]
            .map { InkPart(asset: $0) }
    }
}

// MARK: - The thumbs up (a one-off success)

/// **A thumbs up** (the owner, 2026-10-14: "a thumbs up animation we can use
/// that for a bunch of things"). His two drawings: a fist, and the thumb up
/// with a little face on it.
///
/// The fist winds up, straining as the fingers squeeze; the thumb shoots up
/// out of it, stretched tall and thin, overshoots, and wobbles to a stop as
/// the fingers spring back. Its face blinks (eyes widening first) and its
/// smile grows past wide and settles. About 1s, then it holds.
struct ThumbsUp: View {
    var height: CGFloat = 110
    var body: some View { InkFigure(script: ThumbsUpScript(), height: height) }
}

struct ThumbsUpScript: InkScript {
    let canvas = CGSize(width: 900, height: 670)
    let length: Double? = 1.1

    static let swap = 0.32
    /// Where the curled fingers meet the palm, and where the thumb stands.
    static let palm = CGPoint(x: 610, y: 490), thumbBase = CGPoint(x: 612, y: 265)
    static let eyeLeft = CGPoint(x: 618, y: 120), eyeRight = CGPoint(x: 667, y: 115)
    static let nose = CGPoint(x: 646, y: 138), smile = CGPoint(x: 660, y: 162)

    func parts(at t: Double, stoppedAt: Double?) -> [InkPart] {
        typealias S = ThumbsUpScript
        let up = t >= S.swap
        // The wind-up: the fingers squeeze, straining, then spring back past
        // where they were as the thumb goes.
        let strain = Ink.smooth((t - 0.08) / 0.2)
        let squeeze = up ? 0.1 * Ink.spring(t - S.swap, frequency: 3.2, damping: 0.35)
                         : 0.1 * strain + 0.008 * sin(t * 140) * strain
        let fist = Ink.scale(1 - squeeze, 1, about: S.palm)
        // The thumb shoots up from a stub, stretched thin, past upright, and
        // wobbles to a stop.
        let sy = 1 - 0.75 * Ink.spring(t - S.swap, frequency: 2.6, damping: 0.32)
        let sx = min(max(1 - 0.3 * (sy - 1), 0.9), 1.12)
        let wobble = 10 * Ink.springOut(t - S.swap, frequency: 2.6, damping: 0.32)
        let thumb = Ink.scale(sx, sy, about: S.thumbBase).then(Ink.rotate(wobble, about: S.thumbBase))
        // The blink: the eyes widen, shut, and open with a pop.
        let blink: Double = {
            if t < 0.72 { return 1 + 0.3 * Ink.smooth((t - 0.64) / 0.08) }
            if t < 0.77 { return 1.3 - 1.2 * Ink.smooth((t - 0.72) / 0.05) }
            if t < 0.82 { return 0.1 }
            return 1 - 0.9 * Ink.spring(t - 0.82, frequency: 3.5, damping: 0.4)
        }()
        let grin = 1 + 0.25 * (1 - Ink.spring(t - 0.55, frequency: 3, damping: 0.4))
        return [
            InkPart(asset: "ThumbsUpArm"),
            InkPart(asset: "ThumbsUpFingers", transform: fist),
            InkPart(asset: "ThumbsUpFistBack", opacity: up ? 0 : 1),
            InkPart(asset: "ThumbsUpFistTop", transform: fist, opacity: up ? 0 : 1),
            InkPart(asset: "ThumbsUpHandTop", opacity: up ? 1 : 0),
            InkPart(asset: "ThumbsUpThumb", transform: thumb, opacity: up ? 1 : 0),
            InkPart(asset: "ThumbsUpFaceEyeLeft", transform: Ink.scale(1, blink, about: S.eyeLeft).then(thumb), opacity: up ? 1 : 0),
            InkPart(asset: "ThumbsUpFaceEyeRight", transform: Ink.scale(1, blink, about: S.eyeRight).then(thumb), opacity: up ? 1 : 0),
            InkPart(asset: "ThumbsUpFaceNose", transform: thumb, opacity: up ? 1 : 0),
            InkPart(asset: "ThumbsUpFaceSmile", transform: Ink.scale(grin, 1 + (grin - 1) * 0.6, about: S.smile).then(thumb), opacity: up ? 1 : 0),
        ]
    }

    var still: [InkPart] {
        ["ThumbsUpArm", "ThumbsUpFingers", "ThumbsUpHandTop", "ThumbsUpThumb",
         "ThumbsUpFaceEyeLeft", "ThumbsUpFaceEyeRight", "ThumbsUpFaceNose", "ThumbsUpFaceSmile"].map { InkPart(asset: $0) }
    }
}

// MARK: - The cat walking in trousers (joining a crew)

/// **The cat in trousers, walking** (the owner, 2026-10-14: "really gonna
/// need to make the legs bendy for this one naturally for the small animation
/// and the eyes and mouth and stuff"). His drawing mid-stride, each leg cut at
/// the hip and at the knee where his line kinks, the socks at the cuff.
///
/// It walks in place while a crew is joining, which makes it the spinner:
/// each leg comes in from his stride and goes back out, half a stride behind
/// the other, its knee bending, its shin trailing and its toe lifting as it
/// comes through. The body bobs twice a stride, the head squashing as a foot
/// lands and stretching at the top, swaying a beat behind; the ears flop
/// after it. Now and then it blinks, and the smile widens once and keeps a
/// little bounce. It loops because it is the "working" sign; stopped, it
/// eases back to his pose with a last little bob.
struct JoiningWalk: View {
    var height: CGFloat = 130
    var walking = true
    var body: some View { InkFigure(script: JoiningWalkScript(), height: height, running: walking) }
}

struct JoiningWalkScript: InkScript {
    let canvas = CGSize(width: 1240, height: 1340)
    let length: Double? = nil
    let settle = 0.9

    static let stride = 1.0
    static let hip = 635.0, knee = 840.0
    static let cuffLeft = CGPoint(x: 160, y: 1180), cuffRight = CGPoint(x: 1095, y: 1102)
    static let waist = CGPoint(x: 470, y: 490)
    static let earLeft = CGPoint(x: 285, y: 148), earRight = CGPoint(x: 560, y: 120)
    static let eyeLeft = CGPoint(x: 379, y: 213), eyeRight = CGPoint(x: 524, y: 183)
    static let mouth = CGPoint(x: 485, y: 246)

    func parts(at t: Double, stoppedAt: Double?) -> [InkPart] {
        typealias S = JoiningWalkScript
        var amount = Ink.smooth(t / 0.3)
        if let stoppedAt { amount *= 1 - Ink.smooth((t - stoppedAt) / 0.45) }
        let phase = t / S.stride * 2 * .pi
        // Each leg comes in from his stride and goes back out, the two half a
        // stride apart, so one is always coming through as the other goes
        // back. Never wider than he drew it.
        let inLeft = 0.22 * amount * (1 - cos(phase)) / 2
        let inRight = 0.22 * amount * (1 + cos(phase)) / 2
        // Each leg lifts as it comes in: the knee bends, the shin trails.
        let liftLeft = amount * max(0, sin(phase)), liftRight = amount * max(0, -sin(phase))
        var bob = -22 * amount * pow(sin(phase), 2)
        if let stoppedAt { bob += 10 * Ink.springOut(t - stoppedAt - 0.2, frequency: 2, damping: 0.35) }
        let body = Ink.move(0, bob)

        func leg(thigh: Double, lift: Double, cuff: CGPoint, toe: Double) -> (CGAffineTransform, CGAffineTransform, CGAffineTransform) {
            let thighT = Ink.shearX(thigh, aboutY: S.hip)
            let atKnee = thigh * (S.knee - S.hip)
            // The shin trails the way the thigh came from.
            let trail = thigh >= 0 ? -0.3 * lift : 0.3 * lift
            let shinT = Ink.scale(1, 1 - 0.12 * lift, about: CGPoint(x: 0, y: S.knee))
                .then(Ink.shearX(thigh + trail, aboutY: S.knee))
                .then(Ink.move(atKnee, 0))
            let moved = cuff.applying(shinT)
            let sockT = Ink.rotate(toe * lift, about: cuff).then(Ink.move(moved.x - cuff.x, moved.y - cuff.y))
            return (thighT.then(body), shinT.then(body), sockT.then(body))
        }
        let (thighL, shinL, sockL) = leg(thigh: inLeft, lift: liftLeft, cuff: S.cuffLeft, toe: 16)
        let (thighR, shinR, sockR) = leg(thigh: -inRight, lift: liftRight, cuff: S.cuffRight, toe: -16)

        // The head squashes as a foot lands and stretches at the top of the
        // bob, a beat behind; it sways the same beat behind.
        let late = phase - 0.4
        let squash = 1 + 0.045 * amount * (2 * pow(sin(late), 2) - 1)
        let head = Ink.scale(1 / squash.squareRoot(), squash, about: S.waist)
            .then(Ink.rotate(2.5 * amount * sin(late), about: S.waist)).then(body)
        // The ears flop after the head, and twitch now and then.
        let twitch = t.truncatingRemainder(dividingBy: 2.2)
        let flop = amount * sin(2 * phase - 1.3)
        let earL = 6 * flop + 8 * Ink.bump(twitch, 1.25, 1.33, 1.5)
        let earR = -7 * flop - 10 * Ink.bump(twitch, 1.2, 1.28, 1.45)
        let blinkAt = t.truncatingRemainder(dividingBy: 2.9)
        let blink = Ink.bump(blinkAt, 2.0, 2.06, 2.16)
        let grin = 1 + 0.22 * Ink.smooth((t - 0.4) / 0.5) + 0.06 * amount * pow(sin(late), 2)
        return [
            InkPart(asset: "CrewsJoinHips", transform: body),
            InkPart(asset: "CrewsJoinThighLeft", transform: thighL),
            InkPart(asset: "CrewsJoinShinLeft", transform: shinL),
            InkPart(asset: "CrewsJoinSockLeft", transform: sockL),
            InkPart(asset: "CrewsJoinThighRight", transform: thighR),
            InkPart(asset: "CrewsJoinShinRight", transform: shinR),
            InkPart(asset: "CrewsJoinSockRight", transform: sockR),
            InkPart(asset: "CrewsJoinHead", transform: head),
            InkPart(asset: "CrewsJoinEarLeft", transform: Ink.rotate(earL, about: S.earLeft).then(head)),
            InkPart(asset: "CrewsJoinEarRight", transform: Ink.rotate(earR, about: S.earRight).then(head)),
            InkPart(asset: "CrewsJoinEyeLeft", transform: Ink.scale(1 - 0.15 * blink, 1 - 0.75 * blink, about: S.eyeLeft).then(head)),
            InkPart(asset: "CrewsJoinEyeRight", transform: Ink.scale(1 - 0.15 * blink, 1 - 0.75 * blink, about: S.eyeRight).then(head)),
            InkPart(asset: "CrewsJoinNose", transform: head),
            InkPart(asset: "CrewsJoinMouth", transform: Ink.scale(grin, 1 + (grin - 1) * 0.4, about: S.mouth).then(head)),
        ]
    }

    var still: [InkPart] {
        ["CrewsJoinHips", "CrewsJoinThighLeft", "CrewsJoinShinLeft", "CrewsJoinSockLeft", "CrewsJoinThighRight",
         "CrewsJoinShinRight", "CrewsJoinSockRight", "CrewsJoinHead", "CrewsJoinEarLeft", "CrewsJoinEarRight",
         "CrewsJoinEyeLeft", "CrewsJoinEyeRight", "CrewsJoinNose", "CrewsJoinMouth"].map { InkPart(asset: $0) }
    }
}

// MARK: - The box over the head (no face found)

/// **Somebody with a box over their head, a "?" on it** (the owner,
/// 2026-10-14: "here is the error finding face one"). The head maker's "no
/// face found" slot.
///
/// The box looks one way and then the other: each look winds up the other
/// way first, whips over past where it stops, and holds. The box leans from
/// its bottom edge (so it stays on the shoulders) and squashes into each
/// wind-up; the "?" hops and squashes as it lands; the flaps flop after each
/// turn; the arms swing on behind it, and the weight shifts from one foot to
/// the other. About 1.9s, once.
struct NoFaceFigure: View {
    var height: CGFloat = 220
    var ink: Color = AppColors.onDarkStrong
    var body: some View { InkFigure(script: NoFaceScript(), height: height, ink: ink) }
}

struct NoFaceScript: InkScript {
    let canvas = CGSize(width: 780, height: 1630)
    let length: Double? = 1.9

    /// The box's bottom edge, where it sits on the shoulders, and its top.
    static let boxBottom = 590.0, boxTop = 29.0
    static let mark = CGPoint(x: 455, y: 330), markFoot = CGPoint(x: 455, y: 446)
    static let flapLeftHinge = (CGPoint(x: 119, y: 494), CGPoint(x: 262, y: 569))
    static let flapRightHinge = (CGPoint(x: 675, y: 556), CGPoint(x: 662, y: 650))
    static let flapFrontHinge = 575.0
    static let shoulderLeft = CGPoint(x: 230, y: 625), shoulderRight = CGPoint(x: 575, y: 670)
    static let waist = 870.0, ankles = 1420.0
    /// The turns: when each look whips over.
    static let turns = [0.3, 0.95, 1.45]

    /// How far the box's top leans, in his pixels: a wind-up the other way,
    /// a whip past the look, a hold.
    static func lean(_ t: Double) -> Double {
        springSteps(t, [(0.12, 20), (0.3, -120), (0.85, -18), (0.95, 218), (1.45, -100)])
    }

    func parts(at t: Double, stoppedAt: Double?) -> [InkPart] {
        typealias S = NoFaceScript
        let lean = S.lean(t)
        // The weight goes onto the foot away from the look, a beat behind.
        let sway = -0.18 * S.lean(t - 0.05)
        let upper = Ink.move(sway, 0)
        let windUp = Ink.bump(t, 0.1, 0.22, 0.3) + Ink.bump(t, 0.83, 0.9, 0.96)
        let whip = abs(Ink.springOut(t - 0.3, frequency: 2.4, damping: 0.38)) + abs(Ink.springOut(t - 0.95, frequency: 2.4, damping: 0.38))
        let squash = 1 - 0.06 * windUp + 0.05 * whip
        let box = Ink.scale(1 / squash.squareRoot(), squash, about: CGPoint(x: 470, y: S.boxBottom))
            .then(Ink.shearX(lean / (S.boxTop - S.boxBottom), aboutY: S.boxBottom)).then(upper)
        // The "?" hops at each turn and squashes as it lands, swinging behind.
        let hop = Ink.bump(t, 0.3, 0.42, 0.56) + Ink.bump(t, 0.95, 1.07, 1.21) + 0.6 * Ink.bump(t, 1.45, 1.55, 1.68)
        let landing = Ink.springOut(t - 0.56, frequency: 3, damping: 0.4) + Ink.springOut(t - 1.21, frequency: 3, damping: 0.4)
        let markSquash = 1 + 0.12 * hop - 0.15 * landing
        let markSwing = -0.12 * (S.lean(t) - S.lean(t - 0.1))
        let mark = Ink.scale(1 / markSquash.squareRoot(), markSquash, about: S.markFoot)
            .then(Ink.rotate(markSwing, about: S.mark)).then(Ink.move(0, -34 * hop)).then(box)
        // The flaps flop after each turn.
        let flop = S.turns.reduce(0.0) { $0 + Ink.springOut(t - $1 - 0.06, frequency: 3, damping: 0.3) }
        let flapLeft = 1 - 0.4 * flop, flapRight = 1 + 0.45 * flop, flapFront = 1 - 0.18 * flop
        // The arms swing on behind the turn.
        let arm = 0.07 * S.lean(t - 0.14)
        // Legs lean from the ankles to carry the sway; the shoes stay put.
        let legs = Ink.shearX(sway / (S.waist - S.ankles), aboutY: S.ankles)
        return [
            InkPart(asset: "HeadMakerNoFaceShoes"),
            InkPart(asset: "HeadMakerNoFaceLegs", transform: legs),
            InkPart(asset: "HeadMakerNoFaceTorso", transform: upper),
            InkPart(asset: "HeadMakerNoFaceArmLeft", transform: Ink.rotate(arm, about: S.shoulderLeft).then(upper)),
            InkPart(asset: "HeadMakerNoFaceArmRight", transform: Ink.rotate(arm, about: S.shoulderRight).then(upper)),
            InkPart(asset: "HeadMakerNoFaceBox", transform: box),
            InkPart(asset: "HeadMakerNoFaceFlapLeft", transform: Ink.fold(flapLeft, hinge: S.flapLeftHinge.0, S.flapLeftHinge.1).then(box)),
            InkPart(asset: "HeadMakerNoFaceFlapRight", transform: Ink.fold(flapRight, hinge: S.flapRightHinge.0, S.flapRightHinge.1).then(box)),
            InkPart(asset: "HeadMakerNoFaceFlapFront", transform: Ink.scale(1, flapFront, about: CGPoint(x: 0, y: S.flapFrontHinge)).then(box)),
            InkPart(asset: "HeadMakerNoFaceMark", transform: mark),
            InkPart(asset: "HeadMakerNoFaceMarkDot", transform: Ink.move(0, 10 * landing).then(mark)),
        ]
    }

    var still: [InkPart] {
        ["HeadMakerNoFaceShoes", "HeadMakerNoFaceLegs", "HeadMakerNoFaceTorso", "HeadMakerNoFaceArmLeft",
         "HeadMakerNoFaceArmRight", "HeadMakerNoFaceBox", "HeadMakerNoFaceFlapLeft", "HeadMakerNoFaceFlapRight",
         "HeadMakerNoFaceFlapFront", "HeadMakerNoFaceMark", "HeadMakerNoFaceMarkDot"].map { InkPart(asset: $0) }
    }
}

// MARK: - The lock (Lock Journal, in the walkthrough)

/// **The lock, locking** (the owner, 2026-10-14: "the animation being it
/// locking with like little doodle lines coming out when it clocks and then
/// the lock smiling"). His two drawings: the lock open with its keyhole, and
/// shut with a face. (`LockingLock`, because `JournalLock` is the service
/// that keeps the journal locked.)
///
/// It waits open; the shackle winds up higher, then slams down and clicks
/// shut. The lock squashes at the click and springs back, and four short
/// dashes in his pen shoot out from where the shackle went in, trailing and
/// fading (the only ink here not cut from his drawings, which he asked
/// for). The keyhole squashes up into the round nose, the eyes pop open,
/// the mouth curves into his smile past wide; a held beat; then a wink, the
/// lock tipping toward it. About 1.8s, once.
struct LockingLock: View {
    var height: CGFloat = 150
    var body: some View { InkFigure(script: JournalLockScript(), height: height) }
}

struct JournalLockScript: InkScript {
    let canvas = CGSize(width: 840, height: 1050)
    let length: Double? = 1.85

    static let click = 0.44, face = 0.6
    /// The shackle turns on its left legs, where they go into the lock.
    static let hinge = CGPoint(x: 88, y: 394)
    static let base = CGPoint(x: 390, y: 1040)
    /// Where the shackle goes in, and the dashes come out.
    static let catchPoint = CGPoint(x: 705, y: 410)
    static let keyhole = CGPoint(x: 375, y: 655), nose = CGPoint(x: 381, y: 655)
    static let eyeLeft = CGPoint(x: 172, y: 620), eyeRight = CGPoint(x: 555, y: 614)
    static let smileEnd = CGPoint(x: 458, y: 818)

    func parts(at t: Double, stoppedAt: Double?) -> [InkPart] {
        typealias S = JournalLockScript
        let shut = t >= S.click
        // Open; wound up higher; slammed down, faster as it goes.
        let swing: Double = {
            if t < 0.12 { return -16 }
            if t < 0.3 { return -16 - 8 * Ink.smooth((t - 0.12) / 0.18) }
            if t < S.click { let u = (t - 0.3) / (S.click - 0.3); return -24 * (1 - u * u * u) }
            return 0
        }()
        // The click: a squash that springs back, and later a tip toward the wink.
        let give = Ink.springOut(t - S.click, frequency: 3, damping: 0.35)
        let wink = Ink.bump(t, 1.2, 1.32, 1.6)
        let lock = Ink.scale(1 + 0.08 * give, 1 - 0.12 * give, about: S.base)
            .then(Ink.rotate(4 * wink, about: S.base))
        let shackle = Ink.rotate(swing, about: S.hinge).then(lock)
        // The keyhole squashes up into the round of the nose, which pops.
        let draw = 1 - 0.8 * Ink.smooth((t - 0.5) / (S.face - 0.5))
        let nose = 1 - 0.35 * Ink.spring(t - S.face, frequency: 3.5, damping: 0.35)
        // The eyes pop open past round; the mouth curves into his smile.
        let eyeLeft = max(1 - Ink.spring(t - 0.64, frequency: 3.2, damping: 0.35), 0.01)
        let eyeRightOpen = max(1 - Ink.spring(t - 0.68, frequency: 3.2, damping: 0.35), 0.01)
        let curve = max(1 - Ink.spring(t - 0.74, frequency: 2.8, damping: 0.35), 0.01)
        // The wink: the eye widens, shuts, holds, and pops back.
        let shutEye: Double = {
            if t < 1.18 { return 1 }
            if t < 1.26 { return 1 + 0.25 * Ink.smooth((t - 1.18) / 0.08) }
            if t < 1.32 { return 1.25 - 1.15 * Ink.smooth((t - 1.26) / 0.06) }
            if t < 1.44 { return 0.1 }
            return 1 - 0.9 * Ink.spring(t - 1.44, frequency: 3, damping: 0.4)
        }()
        let smile = Ink.scale(curve, curve, about: S.smileEnd)
            .then(Ink.rotate(30 * (1 - Ink.clamp(curve)) - 8 * wink, about: S.smileEnd))
        let faceOn = t >= S.face
        return [
            InkPart(asset: "JournalLockBody", transform: lock),
            InkPart(asset: "JournalLockShackle", transform: shackle),
            InkPart(asset: "JournalLockShackleOpen", transform: shackle, opacity: shut ? 0 : 1),
            InkPart(asset: "JournalLockShackleShut", transform: shackle, opacity: shut ? 1 : 0),
            InkPart(asset: "JournalLockKeyhole", transform: Ink.scale(1, draw, about: S.keyhole).then(lock), opacity: faceOn ? 0 : 1),
            InkPart(asset: "JournalLockNose", transform: Ink.scale(nose, nose, about: S.nose).then(lock), opacity: faceOn ? 1 : 0),
            InkPart(asset: "JournalLockEyeLeft", transform: Ink.scale(eyeLeft, eyeLeft, about: S.eyeLeft).then(lock), opacity: t >= 0.64 ? 1 : 0),
            InkPart(asset: "JournalLockEyeRight", transform: Ink.scale(eyeRightOpen, eyeRightOpen * shutEye, about: S.eyeRight).then(lock), opacity: t >= 0.68 ? 1 : 0),
            InkPart(asset: "JournalLockSmile", transform: smile.then(lock), opacity: t >= 0.74 ? 1 : 0),
        ]
    }

    /// The click: four short dashes shooting out from where the shackle went
    /// in, each a moment after the last, shrinking as they fly and fading.
    func strokes(at t: Double) -> [InkStroke] {
        typealias S = JournalLockScript
        return [-115.0, -80, -45, -10].enumerated().compactMap { index, degrees in
            let s = t - S.click - Double(index) * 0.02
            guard s > 0, s < 0.45 else { return nil }
            let a = degrees * .pi / 180
            let fly = 1 - pow(1 - Ink.clamp(s / 0.3), 3)
            let r0 = 45 + 45 * fly
            let r1 = r0 + 10 + 28 * (1 - Ink.smooth((s - 0.08) / 0.3))
            return InkStroke(from: CGPoint(x: S.catchPoint.x + r0 * cos(a), y: S.catchPoint.y + r0 * sin(a)),
                             to: CGPoint(x: S.catchPoint.x + r1 * cos(a), y: S.catchPoint.y + r1 * sin(a)),
                             opacity: 1 - Ink.smooth((s - 0.22) / 0.2))
        }
    }

    /// Reduce Motion: shut, with its face.
    var still: [InkPart] {
        ["JournalLockBody", "JournalLockShackle", "JournalLockShackleShut", "JournalLockNose",
         "JournalLockEyeLeft", "JournalLockEyeRight", "JournalLockSmile"].map { InkPart(asset: $0) }
    }
}

// MARK: - The cloud in sunglasses (signed out of iCloud)

/// **The cloud screen for the no cloud** (the owner, 2026-10-14: "Here is the
/// cloud screen for the no cloud"). His cloud in dark glasses, a small frown,
/// standing on two thin legs in big sneakers. Crews when the person is signed
/// out of iCloud.
///
/// It waits, put out: the side-on sneaker taps twice, toe up and down, its
/// laces bouncing a beat behind; a held beat; then a sigh: the cloud draws
/// up tall and lets it out in a squash, its knees giving, its glasses sliding
/// down a touch and the frown wobbling; the glasses are pushed back up past
/// where they sit and settle; another held beat. It loops gently, 2.6s a
/// round, while the screen is up.
struct NoCloudFigure: View {
    var height: CGFloat = 150
    var body: some View { InkFigure(script: NoCloudScript(), height: height) }
}

struct NoCloudScript: InkScript {
    let canvas = CGSize(width: 980, height: 1370)
    let length: Double? = nil

    static let round = 2.6
    static let cloudFoot = CGPoint(x: 470, y: 650)
    static let glasses = CGPoint(x: 575, y: 420), frown = CGPoint(x: 615, y: 535)
    // The legs: where each meets the cloud, its knee, and its foot.
    static let legLeft = (top: 658.0, knee: 770.0, foot: 902.0, x: 390.0)
    static let legRight = (top: 645.0, knee: 760.0, foot: 878.0, x: 560.0)
    static let heel = CGPoint(x: 505, y: 1160), ankle = CGPoint(x: 545, y: 878)
    static let lacesRight = CGPoint(x: 645, y: 1000), lacesLeft = CGPoint(x: 375, y: 965)

    /// The two taps: toe up and down, twice, quickly.
    static func tap(_ c: Double) -> Double {
        c > 0 && c < 0.56 ? max(0, sin(.pi * c / 0.28)) : 0
    }

    func parts(at t: Double, stoppedAt: Double?) -> [InkPart] {
        typealias S = NoCloudScript
        let c = t.truncatingRemainder(dividingBy: S.round)
        // The sigh: drawn up tall, let out in a squash, settling.
        let inhale = Ink.bump(c, 0.9, 1.2, 1.32)
        let exhale = Ink.bump(c, 1.2, 1.36, 1.8)
        let settle = Ink.springOut(c - 1.36, frequency: 2.6, damping: 0.35) * Ink.smooth((2.4 - c) / 0.3)
        let sy = 1 + 0.07 * inhale - 0.08 * exhale + 0.03 * settle
        let sx = 1 - 0.03 * inhale + 0.05 * exhale - 0.02 * settle
        let dy = -14 * inhale + 18 * exhale
        let cloud = Ink.scale(sx, sy, about: S.cloudFoot).then(Ink.move(0, dy))
        // The glasses slide down a touch on the sigh and are pushed back up
        // past where they sit.
        let slide = 10 * Ink.bump(c, 1.25, 1.42, 1.8) - 4 * Ink.bump(c, 1.8, 1.9, 2.1)
        let glasses = Ink.move(0, slide).then(cloud)
        // The frown wobbles as the breath goes out.
        let wobble = Ink.springOut(c - 1.24, frequency: 3, damping: 0.3)
        let frown = Ink.scale(1 + 0.2 * wobble, 1 - 0.15 * wobble, about: S.frown)
            .then(Ink.rotate(6 * wobble, about: S.frown)).then(cloud)

        // The sneaker taps, turning on its heel, and the laces follow it a
        // beat late and keep going a little after.
        let toe = -12 * S.tap(c)
        let shoe = Ink.rotate(toe, about: S.heel)
        let lag = -6 * (S.tap(c - 0.06) - S.tap(c)) - 5 * Ink.springOut(c - 0.56, frequency: 3, damping: 0.35)
        let lacesRight = Ink.rotate(lag, about: S.lacesRight).then(shoe)
        let lacesLeft = Ink.scale(1, 1 + 0.08 * wobble, about: S.lacesLeft)
        let ankle = S.ankle.applying(shoe)

        // The legs: their tops ride the cloud, their knees give on the sigh,
        // the tapping one's foot goes where the shoe takes it.
        func leg(_ l: (top: Double, knee: Double, foot: Double, x: Double), out: Double, foot: CGPoint) -> (CGAffineTransform, CGAffineTransform) {
            let top = l.top + dy, topDx = (sx - 1) * (l.x - S.cloudFoot.x)
            let footY = l.foot + foot.y, share = (l.knee - l.top) / (l.foot - l.top)
            let knee = top + (footY - top) * share
            let kneeDx = topDx + (foot.x - topDx) * share + out * exhale
            return (Ink.segment(l.top, to: top, dx0: topDx, l.knee, to: knee, dx1: kneeDx),
                    Ink.segment(l.knee, to: knee, dx0: kneeDx, l.foot, to: footY, dx1: foot.x))
        }
        let (thighL, shinL) = leg(S.legLeft, out: -24, foot: .zero)
        let (thighR, shinR) = leg(S.legRight, out: 24, foot: CGPoint(x: ankle.x - S.ankle.x, y: ankle.y - S.ankle.y))
        return [
            InkPart(asset: "NoCloudShoeLeft"),
            InkPart(asset: "NoCloudLacesLeft", transform: lacesLeft),
            InkPart(asset: "NoCloudShoeRight", transform: shoe),
            InkPart(asset: "NoCloudLacesRight", transform: lacesRight),
            InkPart(asset: "NoCloudThighLeft", transform: thighL),
            InkPart(asset: "NoCloudShinLeft", transform: shinL),
            InkPart(asset: "NoCloudThighRight", transform: thighR),
            InkPart(asset: "NoCloudShinRight", transform: shinR),
            InkPart(asset: "NoCloudBody", transform: cloud),
            InkPart(asset: "NoCloudGlasses", transform: glasses),
            InkPart(asset: "NoCloudFrown", transform: frown),
        ]
    }

    var still: [InkPart] {
        ["NoCloudShoeLeft", "NoCloudLacesLeft", "NoCloudShoeRight", "NoCloudLacesRight", "NoCloudThighLeft",
         "NoCloudShinLeft", "NoCloudThighRight", "NoCloudShinRight", "NoCloudBody", "NoCloudGlasses", "NoCloudFrown"]
            .map { InkPart(asset: $0) }
    }
}
