import SwiftUI

// The owner's drawings that move in parts (`InkFigure`). Every number is in
// his pixels: the drawing's 2048 canvas, cropped to the box its assets were
// cut from (the cut scripts measured each joint). Small moves, calm easing,
// and every joint turns about the place the parts meet, so the line stays
// whole.

// MARK: - The cat sliding down the wall (an error)

/// **A cat scratching down a wall** (the owner, 2026-10-14: "a cat scratching
/// down a wall we can use this for an error"). His two drawings: the cat
/// clinging, eyes shut, then scared, eyes wide, its scratches above its claws.
///
/// It clings, it startles (its eyes snap open, its mouth opens, its tail
/// flicks up and over), and it slides down a short way: the arms reach as the
/// claws drag, the scratches are drawn in behind each paw, the tail swishes,
/// and the legs dangle a beat behind and swing as it stops. Then it holds.
/// About 1.2s to the stop, the legs settling a moment after.
struct ErrorCat: View {
    var height: CGFloat = 150
    var body: some View { InkFigure(script: ErrorCatScript(), height: height) }
}

struct ErrorCatScript: InkScript {
    let canvas = CGSize(width: 760, height: 1510)
    let length: Double? = 1.6

    /// How far it slides: the length of his longest scratch above its paw.
    static let slide = 340.0
    static let startle = 0.26, swap = 0.34, slideFrom = 0.36, slideFor = 0.72

    // Joints, measured on his drawing.
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
        // The slide: slow off the mark, slowing as the claws catch.
        let off = -S.slide * (1 - Ink.smooth((t - S.slideFrom) / S.slideFor))
        let jolt = -10 * Ink.bump(t, S.startle, 0.31, 0.46)
        let cat = Ink.move(0, off + jolt)

        // The arms reach as the claws drag: one, then the other.
        let reachLeft = 0.07 * Ink.bump(t, S.slideFrom, 0.62, 1.02)
        let reachRight = 0.07 * Ink.bump(t, 0.44, 0.74, 1.1)
        let armLeft = Ink.scale(1, 1 + reachLeft, about: S.shoulderLeft).then(cat)
        let armRight = Ink.scale(1, 1 + reachRight, about: S.shoulderRight).then(cat)

        // Drawn in behind each paw: down to where its claws are now.
        let frontLeft = S.scratchesLeftEnd + off + jolt - (S.shoulderLeft.y - S.pawLeftTop) * reachLeft
        let frontRight = S.scratchesRightEnd + off + jolt - (S.shoulderRight.y - S.pawRightTop) * reachRight
        let scratches = [CGRect(x: 0, y: 0, width: S.scratchesSplit, height: frontLeft),
                         CGRect(x: S.scratchesSplit, y: 0, width: canvas.width - S.scratchesSplit, height: frontRight)]

        // The head flinches back, then rides the slide.
        let tilt = -2.5 * Ink.bump(t, S.startle, S.swap, 0.62) + 1.2 * Ink.bump(t, 0.55, 0.85, 1.2)
        let head = Ink.rotate(tilt, about: S.neck).then(cat)

        // The eyes tighten, and open wide in the frame they change.
        let squeeze = 1 - 0.4 * Ink.smooth((t - S.startle) / (S.swap - S.startle))
        let open = 0.6 + 0.4 * Ink.backOut((t - S.swap) / 0.3)
        let gape = 0.3 + 0.7 * Ink.backOut((t - S.swap - 0.02) / 0.32)

        // The tail flicks up, and the scared tail swings over and swishes.
        let flick = 10 * Ink.smooth((t - S.startle) / (S.swap - S.startle))
        let swish = -14 * Ink.spring(t - S.swap, frequency: 2.2, damping: 0.42)
            + 5 * sin((t - 0.5) * .pi * 2 / 0.55) * Ink.bump(t, 0.5, 0.75, 1.2)

        // The legs hang a beat behind: drawn up as it drops, swinging long
        // as it stops.
        let stop = S.slideFrom + S.slideFor
        let hang = 1 - 0.035 * Ink.bump(t, S.slideFrom, 0.55, 0.85)
            + 0.05 * Ink.springOut(t - stop + 0.12, frequency: 2.0, damping: 0.35)
        let swing = 0.04 * Ink.springOut(t - stop + 0.08, frequency: 1.6, damping: 0.3)
        let legs = Ink.scale(1, hang, about: CGPoint(x: 0, y: S.hips)).then(Ink.shearX(swing, aboutY: S.hips)).then(cat)

        return [
            InkPart(asset: "ErrorCatLines", opacity: t >= S.slideFrom ? 1 : 0, reveal: scratches),
            InkPart(asset: "ErrorCatTorso", transform: cat),
            InkPart(asset: "ErrorCatLegs", transform: legs),
            InkPart(asset: "ErrorCatTail", transform: Ink.rotate(flick, about: S.tailRoot).then(cat), opacity: scared ? 0 : 1),
            InkPart(asset: "ErrorCatTailUp", transform: Ink.rotate(swish, about: S.tailUpRoot).then(cat), opacity: scared ? 1 : 0),
            InkPart(asset: "ErrorCatArmLeft", transform: armLeft),
            InkPart(asset: "ErrorCatArmRight", transform: armRight),
            InkPart(asset: "ErrorCatHead", transform: head),
            InkPart(asset: "ErrorCatEyeLeftShut", transform: Ink.scale(1, squeeze, about: S.eyeLeftShut).then(head), opacity: scared ? 0 : 1),
            InkPart(asset: "ErrorCatEyeRightShut", transform: Ink.scale(1, squeeze, about: S.eyeRightShut).then(head), opacity: scared ? 0 : 1),
            InkPart(asset: "ErrorCatNose", transform: head, opacity: scared ? 0 : 1),
            InkPart(asset: "ErrorCatMouth", transform: Ink.scale(squeeze, squeeze, about: S.mouth).then(head), opacity: scared ? 0 : 1),
            InkPart(asset: "ErrorCatEyeLeftWide", transform: Ink.scale(open, open, about: S.eyeLeftWide).then(head), opacity: scared ? 1 : 0),
            InkPart(asset: "ErrorCatEyeRightWide", transform: Ink.scale(open, open, about: S.eyeRightWide).then(head), opacity: scared ? 1 : 0),
            InkPart(asset: "ErrorCatNoseWide", transform: head, opacity: scared ? 1 : 0),
            InkPart(asset: "ErrorCatMouthWide", transform: Ink.scale(gape, gape, about: S.mouthWide).then(head), opacity: scared ? 1 : 0),
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
/// The fingers curl tighter, the thumb springs up out of the fist past
/// upright and back, and its face blinks once and smiles wider. About 0.8s,
/// then it holds.
struct ThumbsUp: View {
    var height: CGFloat = 110
    var body: some View { InkFigure(script: ThumbsUpScript(), height: height) }
}

struct ThumbsUpScript: InkScript {
    let canvas = CGSize(width: 900, height: 670)
    let length: Double? = 0.9

    static let swap = 0.3
    /// Where the curled fingers meet the palm, and where the thumb stands.
    static let palm = CGPoint(x: 610, y: 490), thumbBase = CGPoint(x: 612, y: 265)
    static let eyeLeft = CGPoint(x: 618, y: 120), eyeRight = CGPoint(x: 667, y: 115)
    static let smile = CGPoint(x: 660, y: 162)

    func parts(at t: Double, stoppedAt: Double?) -> [InkPart] {
        typealias S = ThumbsUpScript
        let up = t >= S.swap
        // The fingers tighten, then let go with a little give as the thumb comes up.
        let curl = up ? 0.04 * Ink.spring(t - S.swap, frequency: 3, damping: 0.45)
                      : 0.04 * Ink.smooth((t - 0.06) / 0.2)
        let fist = Ink.scale(1 - curl, 1 - curl * 0.4, about: S.palm)
        // The thumb springs up from half height, past upright, and back.
        let rise = 1 - 0.5 * Ink.spring(t - S.swap, frequency: 2.4, damping: 0.42)
        let wobble = 4 * Ink.springOut(t - S.swap, frequency: 2.4, damping: 0.42)
        let thumb = Ink.scale(1, rise, about: S.thumbBase).then(Ink.rotate(wobble, about: S.thumbBase))
        // One blink, then the smile widens.
        let blink = 1 - 0.8 * Ink.bump(t, 0.6, 0.66, 0.74)
        let grin = 1 + 0.2 * (1 - Ink.spring(t - 0.5, frequency: 3, damping: 0.5))
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
            InkPart(asset: "ThumbsUpFaceSmile", transform: Ink.scale(grin, grin * 0.5 + 0.5, about: S.smile).then(thumb), opacity: up ? 1 : 0),
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
/// the legs swing toward each other and back, each knee bending and its foot
/// lifting as the leg comes through, the body bobbing twice a stride and the
/// head swaying with it. Now and then it blinks, and an ear twitches; the
/// smile widens once and stays. It loops because it is the "working" sign;
/// stopped, it eases back to his pose.
struct JoiningWalk: View {
    var height: CGFloat = 130
    var walking = true
    var body: some View { InkFigure(script: JoiningWalkScript(), height: height, running: walking) }
}

struct JoiningWalkScript: InkScript {
    let canvas = CGSize(width: 1240, height: 1340)
    let length: Double? = nil
    let settle = 0.9

    static let stride = 1.1
    static let hip = 635.0, knee = 840.0
    static let cuffLeft = CGPoint(x: 160, y: 1180), cuffRight = CGPoint(x: 1095, y: 1102)
    static let waist = CGPoint(x: 470, y: 480)
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
        let inLeft = 0.16 * amount * (1 - cos(phase)) / 2
        let inRight = 0.16 * amount * (1 + cos(phase)) / 2
        // Each leg lifts as it comes in: the knee bends, the shin trails.
        let liftLeft = amount * max(0, sin(phase)), liftRight = amount * max(0, -sin(phase))
        var bob = -12 * amount * pow(sin(phase), 2)
        if let stoppedAt { bob += 6 * Ink.springOut(t - stoppedAt - 0.2, frequency: 2, damping: 0.4) }
        let body = Ink.move(0, bob)

        func leg(thigh: Double, lift: Double, cuff: CGPoint, toe: Double) -> (CGAffineTransform, CGAffineTransform, CGAffineTransform) {
            let thighT = Ink.shearX(thigh, aboutY: S.hip)
            let atKnee = thigh * (S.knee - S.hip)
            // The shin trails the way the thigh came from.
            let trail = thigh >= 0 ? -0.22 * lift : 0.22 * lift
            let shinT = Ink.scale(1, 1 - 0.07 * lift, about: CGPoint(x: 0, y: S.knee))
                .then(Ink.shearX(thigh + trail, aboutY: S.knee))
                .then(Ink.move(atKnee, 0))
            let moved = cuff.applying(shinT)
            let sockT = Ink.rotate(toe * lift, about: cuff).then(Ink.move(moved.x - cuff.x, moved.y - cuff.y))
            return (thighT.then(body), shinT.then(body), sockT.then(body))
        }
        let (thighL, shinL, sockL) = leg(thigh: inLeft, lift: liftLeft, cuff: S.cuffLeft, toe: 10)
        let (thighR, shinR, sockR) = leg(thigh: -inRight, lift: liftRight, cuff: S.cuffRight, toe: -10)

        let head = Ink.rotate(1.2 * amount * sin(phase), about: S.waist).then(body)
        let twitch = t.truncatingRemainder(dividingBy: 2.2)
        let blinkAt = t.truncatingRemainder(dividingBy: 2.9)
        let blink = Ink.bump(blinkAt, 2.0, 2.06, 2.16)
        let grin = 1 + 0.22 * Ink.smooth((t - 0.4) / 0.5)
        return [
            InkPart(asset: "CrewsJoinHips", transform: body),
            InkPart(asset: "CrewsJoinThighLeft", transform: thighL),
            InkPart(asset: "CrewsJoinShinLeft", transform: shinL),
            InkPart(asset: "CrewsJoinSockLeft", transform: sockL),
            InkPart(asset: "CrewsJoinThighRight", transform: thighR),
            InkPart(asset: "CrewsJoinShinRight", transform: shinR),
            InkPart(asset: "CrewsJoinSockRight", transform: sockR),
            InkPart(asset: "CrewsJoinHead", transform: head),
            InkPart(asset: "CrewsJoinEarLeft", transform: Ink.rotate(6 * Ink.bump(twitch, 1.25, 1.33, 1.5), about: S.earLeft).then(head)),
            InkPart(asset: "CrewsJoinEarRight", transform: Ink.rotate(-8 * Ink.bump(twitch, 1.2, 1.28, 1.45), about: S.earRight).then(head)),
            InkPart(asset: "CrewsJoinEyeLeft", transform: Ink.scale(1 - 0.15 * blink, 1 - 0.7 * blink, about: S.eyeLeft).then(head)),
            InkPart(asset: "CrewsJoinEyeRight", transform: Ink.scale(1 - 0.15 * blink, 1 - 0.7 * blink, about: S.eyeRight).then(head)),
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
/// The box looks around, one way and then the other, its "?" bobbing and its
/// flaps flapping as it turns; the arms swing a little behind the turn, and
/// the weight shifts from one foot to the other under it. About 2.4s, once.
struct NoFaceFigure: View {
    var height: CGFloat = 220
    var ink: Color = AppColors.onDarkStrong
    var body: some View { InkFigure(script: NoFaceScript(), height: height, ink: ink) }
}

struct NoFaceScript: InkScript {
    let canvas = CGSize(width: 780, height: 1630)
    let length: Double? = 2.45

    static let neck = CGPoint(x: 470, y: 590)
    static let mark = CGPoint(x: 455, y: 330)
    static let flapLeftHinge = (CGPoint(x: 119, y: 494), CGPoint(x: 262, y: 569))
    static let flapRightHinge = (CGPoint(x: 675, y: 556), CGPoint(x: 662, y: 650))
    static let flapFrontHinge = 575.0
    static let shoulderLeft = CGPoint(x: 230, y: 625), shoulderRight = CGPoint(x: 575, y: 670)
    static let waist = 870.0, ankles = 1420.0

    static func look(_ t: Double) -> Double {
        Ink.keys(t, [(0, 0), (0.55, -4), (0.9, -4), (1.5, 4), (1.85, 4), (2.35, 0)])
    }

    func parts(at t: Double, stoppedAt: Double?) -> [InkPart] {
        typealias S = NoFaceScript
        let tilt = S.look(t)
        // The weight goes onto the foot away from where it looks.
        let sway = -2.5 * tilt
        let upper = Ink.move(sway, 0)
        let box = Ink.rotate(tilt, about: S.neck).then(upper)
        // The "?" bobs as the box turns, a beat behind it.
        let bob = -10 * Ink.bump(t, 0.05, 0.3, 0.65) - 10 * Ink.bump(t, 1.0, 1.25, 1.6) - 6 * Ink.bump(t, 1.9, 2.1, 2.4)
        let mark = Ink.rotate(-0.6 * (tilt - S.look(t - 0.12)) * 4, about: S.mark).then(Ink.move(0, bob)).then(box)
        let flapLeft = 1 - 0.25 * Ink.bump(t, 0.45, 0.6, 0.8) - 0.2 * Ink.bump(t, 1.6, 1.75, 1.95)
        let flapRight = 1 - 0.3 * Ink.bump(t, 0.5, 0.65, 0.85) - 0.25 * Ink.bump(t, 1.65, 1.8, 2.0)
        let flapFront = 1 - 0.12 * Ink.bump(t, 0.55, 0.7, 0.9) - 0.1 * Ink.bump(t, 1.7, 1.85, 2.05)
        // The arms swing behind the turn.
        let arm = -0.8 * S.look(t - 0.15)
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
            InkPart(asset: "HeadMakerNoFaceMarkDot", transform: mark),
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
/// shut with a face.
///
/// The shackle swings down and clicks shut, and at the click four short
/// dashes in his pen spring out from where it went in and fade (the only
/// ink here that is not cut from his drawings, which he asked for). The lock
/// gives a little, the keyhole draws up into the round nose, the eyes open,
/// the mouth curves into his smile, and it winks. About 1.5s, once.
struct LockingLock: View {
    var height: CGFloat = 150
    var body: some View { InkFigure(script: JournalLockScript(), height: height) }
}

struct JournalLockScript: InkScript {
    let canvas = CGSize(width: 840, height: 1050)
    let length: Double? = 1.6

    static let click = 0.42, face = 0.62
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
        // Open, then falling shut, faster as it goes, as a dropped shackle does.
        let swing = shut ? 0 : -16 * (1 - Ink.easeIn((t - 0.15) / (S.click - 0.15)))
        // The lock gives a little at the click.
        let give = Ink.springOut(t - S.click, frequency: 3, damping: 0.45)
        let lock = Ink.scale(1 + 0.02 * give, 1 - 0.03 * give, about: S.base)
        let shackle = Ink.rotate(swing, about: S.hinge).then(lock)
        // The keyhole draws up into the round of the nose.
        let draw = 1 - 0.75 * Ink.smooth((t - 0.5) / (S.face - 0.5))
        let nose = 0.85 + 0.15 * Ink.backOut((t - S.face) / 0.2)
        let eyeLeft = Ink.backOut((t - 0.66) / 0.2), eyeRight = Ink.backOut((t - 0.7) / 0.2)
        let curve = Ink.backOut((t - 0.76) / 0.26)
        // The wink: one eye shuts and opens, the smile lifting on that side.
        let wink = Ink.bump(t, 1.12, 1.2, 1.34)
        let smile = Ink.scale(max(curve, 0.01), max(curve, 0.01), about: S.smileEnd)
            .then(Ink.rotate(22 * (1 - Ink.clamp(curve)) - 6 * wink, about: S.smileEnd))
        let faceOn = t >= S.face
        return [
            InkPart(asset: "JournalLockBody", transform: lock),
            InkPart(asset: "JournalLockShackle", transform: shackle),
            InkPart(asset: "JournalLockShackleOpen", transform: shackle, opacity: shut ? 0 : 1),
            InkPart(asset: "JournalLockShackleShut", transform: shackle, opacity: shut ? 1 : 0),
            InkPart(asset: "JournalLockKeyhole", transform: Ink.scale(1, draw, about: S.keyhole).then(lock), opacity: faceOn ? 0 : 1),
            InkPart(asset: "JournalLockNose", transform: Ink.scale(nose, nose, about: S.nose).then(lock), opacity: faceOn ? 1 : 0),
            InkPart(asset: "JournalLockEyeLeft", transform: Ink.scale(max(eyeLeft, 0.01), max(eyeLeft, 0.01), about: S.eyeLeft).then(lock), opacity: t >= 0.66 ? 1 : 0),
            InkPart(asset: "JournalLockEyeRight", transform: Ink.scale(max(eyeRight, 0.01) * (1 - 0.1 * wink), max(eyeRight, 0.01) * (1 - 0.85 * wink), about: S.eyeRight).then(lock), opacity: t >= 0.7 ? 1 : 0),
            InkPart(asset: "JournalLockSmile", transform: smile.then(lock), opacity: t >= 0.76 ? 1 : 0),
        ]
    }

    /// The click: four short dashes out from where the shackle went in,
    /// springing outward and fading.
    func strokes(at t: Double) -> [InkStroke] {
        typealias S = JournalLockScript
        let s = t - S.click
        guard s > 0, s < 0.42 else { return [] }
        let out = Ink.backOut(s / 0.16)
        let fade = 1 - Ink.smooth((s - 0.2) / 0.22)
        return [-115.0, -80, -45, -10].map { degrees in
            let a = degrees * .pi / 180
            let r0 = 55 + 30 * out, r1 = r0 + 30 + 10 * out
            return InkStroke(from: CGPoint(x: S.catchPoint.x + r0 * cos(a), y: S.catchPoint.y + r0 * sin(a)),
                             to: CGPoint(x: S.catchPoint.x + r1 * cos(a), y: S.catchPoint.y + r1 * sin(a)),
                             opacity: fade)
        }
    }

    /// Reduce Motion: shut, with its face.
    var still: [InkPart] {
        ["JournalLockBody", "JournalLockShackle", "JournalLockShackleShut", "JournalLockNose",
         "JournalLockEyeLeft", "JournalLockEyeRight", "JournalLockSmile"].map { InkPart(asset: $0) }
    }
}
