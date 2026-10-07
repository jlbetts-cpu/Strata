import SwiftUI

/// **October: the skeleton dances, and the crow lands on his hand** (the
/// owner, 2026-10-06: "the idea was a dancing skeleton since all the bones
/// are separate", "make sure the skeleton actually looks like he's dancing,
/// all his body parts moving, doing a genuine move without overlapping
/// elements", "make the animation feel as realistic as possible", and his
/// pick: October with the crow).
///
/// **The move is the Saturday Night Fever point**, up and down on the beat
/// at 116 BPM, and the realism is in what the rest of the body does about it:
///
/// - **The point snaps and the hips groove.** The arm leaves a fifth of a
///   beat early and hits on the beat, a touch past the mark; the hips swing
///   on a smooth curve under it, a little behind, as weight follows a move.
/// - **The feet stay planted.** Each leg is solved from the hip to the floor
///   (`legs`), so the knees bend where the hips put them. Seen from the
///   front a bending knee mostly comes toward you, so most of the bend is
///   taken as foreshortening and only the rest as the knee moving out.
/// - **The leg without the weight** lifts its heel and pops its knee in.
/// - **Everything follows a beat behind**: the torso after the hips, the
///   head after the torso, the hands after the arms.
/// - **No two bones ever touch.** Every pose was rendered and checked pixel
///   by pixel against every other bone (0 overlapping pixels); the bent
///   elbow opens as it bends so its knobs never meet.
///
/// Then the crow (his, from the scarecrow's shoulder) flies in and stands on
/// the raised hand as the dance settles; the hand gives under it and the
/// head tilts up to look. Once, then again on a tap: the crow takes off,
/// he dances, it comes back. Nothing loops (`Illustration` has why).
///
/// The layers and the joints come from `docs/illustrations/skeleton.py`.
struct OctoberDance: View {
    var line: String?
    var height: CGFloat = 290
    var onRest: (@MainActor () -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var playedAt: Date?
    @State private var plays = 0
    @State private var awake = false

    var body: some View {
        VStack(spacing: GridConstants.gapItem) {
            stage
                .frame(width: height * Rig.size.width / Rig.size.height, height: height)
                .frame(minHeight: height * 0.5, maxHeight: height)
                .layoutPriority(1)
            if let line { DrawingLine(text: line) }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(line ?? "")
        .accessibilityHidden(line == nil)
    }

    @ViewBuilder
    private var stage: some View {
        if reduceMotion {
            scene(Dance.pose(at: .infinity, play: 1))
                .onAppear { onRest?() }
        } else if !awake {
            // His drawing first, still, and the timeline a beat later: built
            // in the same turn as the page, it added 0.4s to the first tap on
            // Memories (measured 2026-10-07, 1349ms against 956ms without).
            scene(Dance.pose(at: 0, play: 1))
                .task {
                    try? await Task.sleep(for: .milliseconds(150))
                    awake = true
                }
        } else {
            TimelineView(.animation(paused: playedAt == nil)) { context in
                let t = plays == 0 ? 0 : playedAt.map { context.date.timeIntervalSince($0) } ?? .infinity
                scene(Dance.pose(at: t, play: max(plays, 1)))
            }
            .contentShape(Rectangle())
            .onTapGesture { play() }
            .onAppear {
                plays = 0
                play()
                #if DEBUG
                if DebugHarness.argument("-strataRenderDance") != nil { renderFrames() }
                #endif
            }
            .onDisappear { playedAt = nil }
        }
    }

    #if DEBUG
    /// `-strataRenderDance 1`: every twelfth of a second of the first play
    /// and a replay, drawn to Documents/dance as pictures, so the motion can
    /// be checked frame by frame on a machine too busy to film it.
    private func renderFrames() {
        let folder = URL.documentsDirectory.appending(path: "dance")
        try? FileManager.default.removeItem(at: folder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for play in [1, 2] {
            for (i, t) in stride(from: 0.0, through: Dance.duration(play: play), by: 1.0 / 12).enumerated() {
                let renderer = ImageRenderer(content: scene(Dance.pose(at: t, play: play))
                    .frame(width: 290 * Rig.size.width / Rig.size.height, height: 290)
                    .padding(60)
                    .background(Color.white))
                renderer.scale = 2
                if let data = renderer.uiImage?.pngData() {
                    try? data.write(to: folder.appending(path: String(format: "p%d_%03d.png", play, i)))
                }
            }
        }
        print("DANCE-RENDERED", folder.path)
    }
    #endif

    private func scene(_ pose: Dance.Pose) -> some View {
        GeometryReader { geo in
            let s = geo.size.height / Rig.size.height
            ZStack(alignment: .topLeading) {
                ForEach(Rig.bones, id: \.self) { bone in
                    layer(bone, pose.bones[bone] ?? .identity, scale: s)
                        .opacity(bone == "RHand" ? 1 - pose.crowSitting : 1)
                }
                layer("CrowSit", pose.crow, scale: s).opacity(pose.crowSitting)
                layer("CrowHead", pose.crow * pose.crowHead, scale: s).opacity(pose.crowSitting)
                layer("CrowDown", pose.crow, scale: s).opacity(pose.crowDown)
                layer("CrowOut", pose.crow, scale: s).opacity(pose.crowSpread)
            }
        }
    }

    private func layer(_ name: String, _ m: Mat, scale s: CGFloat) -> some View {
        Image("MonthOctoberSkel" + name)
            .renderingMode(.template)
            .resizable()
            .frame(width: Rig.size.width * s, height: Rig.size.height * s)
            .foregroundStyle(AppColors.drawingInk)
            // The rig works in the drawing's pixels; the view in points.
            .transformEffect(m.affine(scale: s))
    }

    private func play() {
        guard playedAt == nil else { return }
        plays += 1
        let started = Date()
        playedAt = started
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Dance.duration(play: plays) + 0.05))
            if playedAt == started {
                playedAt = nil
                onRest?()
            }
        }
    }
}

// MARK: - The rig

/// The skeleton's bones and joints, in the drawing's own pixels
/// (`docs/illustrations/skeleton-rig.json`).
enum Rig {
    static let size = CGSize(width: 538, height: 900)

    static let bones = ["LThigh", "LShin", "LFoot", "RThigh", "RShin", "RFoot", "Pelvis", "Ribs",
                        "LUpper", "LFore", "LHand", "RUpper", "RFore", "RHand", "Skull"]

    static let neck = CGPoint(x: 214.02, y: 428.05)
    static let waist = CGPoint(x: 255.18, y: 598.17)
    static let pelvis = CGPoint(x: 255.18, y: 622.87)
    static let rShoulder = CGPoint(x: 316.65, y: 443.96)
    static let rElbow = CGPoint(x: 357.8, y: 355.61)
    static let rWrist = CGPoint(x: 377.56, y: 259.57)
    static let lShoulder = CGPoint(x: 130.61, y: 467.56)
    static let lElbow = CGPoint(x: 91.1, y: 563.05)
    static let lWrist = CGPoint(x: 71.89, y: 639.33)
    static let lHip = CGPoint(x: 188.23, y: 652.5)
    static let lKnee = CGPoint(x: 175.61, y: 746.34)
    static let lAnkle = CGPoint(x: 173.96, y: 841.28)
    static let rHip = CGPoint(x: 314.45, y: 662.93)
    static let rKnee = CGPoint(x: 322.13, y: 750.73)
    static let rAnkle = CGPoint(x: 321.59, y: 836.34)
    /// Where the crow's feet stand on the fingertips, and the middle of its
    /// body above them.
    static let crowFeet = CGPoint(x: 394.02, y: 208.54)
    static let crowBody = CGPoint(x: 344.85, y: 148.83)
    /// Where its head turns on its neck.
    static let crowNeck = CGPoint(x: 376.46, y: 145.32)
    /// **His palm, up top** (the owner: "the bird should appear to be
    /// sitting on his hand up top of his dance, you can remove fingers if
    /// that helps sell the on the palm look"): the head of the raised
    /// forearm, where the crow's feet hold on. His fingers go as it settles
    /// (the crow's body would hide them; the bits that showed round it looked
    /// broken) and come back as it leaves.
    static let palm = CGPoint(x: 386, y: 254)
}

/// A 2D affine transform as a matrix, so the rig composes the way it was
/// prototyped: parent, then child, read left to right.
struct Mat: Equatable {
    var a = 1.0, b = 0.0, tx = 0.0
    var c = 0.0, d = 1.0, ty = 0.0

    static let identity = Mat()

    static func move(_ x: Double, _ y: Double) -> Mat { Mat(tx: x, ty: y) }
    static func turn(_ degrees: Double) -> Mat {
        let r = degrees * .pi / 180
        return Mat(a: cos(r), b: -sin(r), c: sin(r), d: cos(r))
    }
    static func scale(_ k: Double) -> Mat { Mat(a: k, d: k) }
    static func scale(_ x: Double, _ y: Double) -> Mat { Mat(a: x, d: y) }
    /// Turned about a point.
    static func about(_ p: CGPoint, _ degrees: Double) -> Mat {
        .move(p.x, p.y) * .turn(degrees) * .move(-p.x, -p.y)
    }
    /// Scaled about a point.
    static func scaled(about p: CGPoint, _ k: Double) -> Mat {
        .move(p.x, p.y) * .scale(k) * .move(-p.x, -p.y)
    }

    static func * (m: Mat, n: Mat) -> Mat {
        Mat(a: m.a * n.a + m.b * n.c, b: m.a * n.b + m.b * n.d, tx: m.a * n.tx + m.b * n.ty + m.tx,
            c: m.c * n.a + m.d * n.c, d: m.c * n.b + m.d * n.d, ty: m.c * n.tx + m.d * n.ty + m.ty)
    }

    func apply(_ p: CGPoint) -> CGPoint {
        CGPoint(x: a * p.x + b * p.y + tx, y: c * p.x + d * p.y + ty)
    }

    /// For SwiftUI, in points: the drawing's pixels times `scale`.
    func affine(scale s: CGFloat) -> CGAffineTransform {
        CGAffineTransform(a: a, b: c, c: b, d: d, tx: tx * s, ty: ty * s)
    }
}

// MARK: - The dance

enum Dance {
    struct Pose {
        var bones: [String: Mat] = [:]
        var crow = Mat.identity
        /// The head cocking on its neck once it has settled.
        var crowHead = Mat.identity
        /// How much of the crow is each of his drawings: sitting, wings
        /// down, wings spread.
        var crowSitting = 0.0
        var crowDown = 0.0
        var crowSpread = 0.0
    }

    static let bpm = 116.0
    /// Eight beats, and a third of one for the last point to land.
    static let beats = 8.3
    static var length: Double { beats * 60 / bpm }
    /// The crow sets off once he has stopped, so it lands on a still hand
    /// (the owner: a crow that rode the dancing hand looked "like a glitch,
    /// not natural").
    static var crowSetsOff: Double { length + 0.15 }
    static var crowLands: Double { crowSetsOff + IllustrationMotion.Crow.fly }

    /// A later play: the crow takes off first, and the dance starts once it
    /// is away.
    static func start(play: Int) -> Double { play <= 1 ? 0 : IllustrationMotion.Crow.away + 0.1 }

    static func duration(play: Int) -> Double {
        start(play: play) + crowLands + IllustrationMotion.Crow.settle + 0.9
    }

    // MARK: Curves

    static func smooth(_ x: Double) -> Double {
        let u = min(max(x, 0), 1)
        return u * u * (3 - 2 * u)
    }

    static func back(_ x: Double, _ s: Double = 1.6) -> Double {
        let u = min(max(x, 0), 1) - 1
        return 1 + (s + 1) * u * u * u + s * u * u
    }

    /// 0 pointing up, as he drew it; 1 pointing down. Leaves a fifth of a
    /// beat early and hits on the beat, a touch past the mark.
    static func point(_ b: Double) -> Double {
        let x = b + 0.2
        let k = Int(floor(x))
        let from = Double(((k - 1) % 2 + 2) % 2), to = Double((k % 2 + 2) % 2)
        return from + (to - from) * back((x - Double(k)) / 0.42)
    }

    /// Down on the beat: the knees give as the point lands.
    static func dip(_ b: Double, lag: Double = 0) -> Double {
        let x = (b - lag).truncatingRemainder(dividingBy: 1)
        let u = x < 0 ? x + 1 : x
        return exp(-pow(u - 0.08, 2) / 0.02) + exp(-pow(u - 1.08, 2) / 0.02)
    }

    // MARK: The pose

    static func pose(at time: Double, play: Int) -> Pose {
        let t = time - start(play: play)
        // The dance, eased in and out so it starts and ends on his drawing.
        let dancing = t > 0 && t < length
        let env = dancing ? smooth(t / 0.4) * (1 - smooth((t - (length - 0.7)) / 0.7)) : 0
        let b = dancing ? t * bpm / 60 : 0

        let pt = point(b) * env
        let groove = 0.5 * cos(.pi * (b - 0.12)) * env
        func pointed(_ lag: Double) -> Double { point(b - lag) * env }

        // The crow: on the hand, taking off, away, coming back.
        let crowT = time - start(play: play) - crowSetsOff
        let landed = crowT - IllustrationMotion.Crow.fly
        // The hand gives under its weight as it lands, and his head tilts up
        // to look at it.
        let give = landed > 0 && landed < 6
            ? IllustrationMotion.springOut(landed, frequency: 2.2, damping: 0.35) * 7 : 0
        var look = landed > 0 ? smooth((landed - 0.15) / 0.45) : 0
        var push = 0.0
        if play > 1 && time < start(play: play) {
            // Taking off: the hand is pushed down as it leaps, and the head
            // comes back.
            let away = time - IllustrationMotion.Crow.crouch
            push = away > 0 ? IllustrationMotion.springOut(away, frequency: 2.4, damping: 0.4) * 6 : 0
            look = 1 - smooth(time / 0.5)
        }

        var p = Pose()
        let P = Mat.move(-30 * px * groove, (12 * dip(b) + 5 * dip(b + 0.5)) * px * env)
            * .about(Rig.pelvis, 5 * groove)
        p.bones["Pelvis"] = P
        // The torso leans into the point, a breath behind the hips.
        let torso = P * .move(0, 3 * px * dip(b, lag: 0.05) * env)
            * .about(Rig.waist, (5 * (0.5 * env - pointed(0.06)) - 2 * env - 3 * groove))
        p.bones["Ribs"] = torso
        // The head lags the body, tilts with the point, nods on the beat.
        p.bones["Skull"] = torso * .move(0, 7 * px * dip(b, lag: 0.12) * env)
            * .about(Rig.neck, 7 * (0.5 * env - pointed(0.16)) + 6 * look)
        // The pointing arm; held, it still pumps a little on the off-beat.
        let upper = torso * .about(Rig.rShoulder, 118 * pt + (5 - 10 * pt) * dip(b + 0.5) * env + give + push)
        p.bones["RUpper"] = upper
        let fore = upper * .about(Rig.rElbow, 12 * pt - 6 * (pt - pointed(0.1)) - give * 0.6)
        p.bones["RFore"] = fore
        let hand = fore * .about(Rig.rWrist, -40 * (pt - pointed(0.12)))
        p.bones["RHand"] = hand
        // The other arm hangs as the point goes up and comes up bent as it
        // goes down; the elbow opens as it bends so its knobs never meet.
        let lp = pointed(0.05)
        let lUpper = torso * .about(Rig.lShoulder, 30 * lp)
        p.bones["LUpper"] = lUpper
        let axis = CGPoint(x: Rig.lElbow.x - Rig.lShoulder.x, y: Rig.lElbow.y - Rig.lShoulder.y)
        let axisLength = hypot(axis.x, axis.y)
        let open = 0.22 * 40 * lp * px
        let lFore = lUpper * .move(axis.x / axisLength * open, axis.y / axisLength * open)
            * .about(Rig.lElbow, -40 * lp)
        p.bones["LFore"] = lFore
        p.bones["LHand"] = lFore * .about(Rig.lWrist, 30 * (lp - pointed(0.17)))
        // The legs: feet planted, knees where the hips put them.
        for (side, out, light) in [("L", 1.0, smooth(-groove * 2)), ("R", -1.0, smooth(groove * 2))] {
            let hip = side == "L" ? Rig.lHip : Rig.rHip
            let knee = side == "L" ? Rig.lKnee : Rig.rKnee
            let ankle = side == "L" ? Rig.lAnkle : Rig.rAnkle
            let lifted = CGPoint(x: ankle.x, y: ankle.y - 10 * px * light)
            let (thigh, shin) = leg(from: P.apply(hip), to: lifted, hip: hip, knee: knee, ankle: ankle,
                                    out: out, pop: light)
            p.bones[side + "Thigh"] = thigh
            p.bones[side + "Shin"] = shin
            p.bones[side + "Foot"] = .identity
        }

        // The crow flies free, and only once it is sitting does it move with
        // the hand: the hand gives under it. Taking off, it leaves the hand
        // where it was rather than riding the push.
        let leaving = play > 1 && time < start(play: play)
        let seat = landed > 0 && !leaving ? fore.apply(Rig.palm) : Rig.palm
        p.crow = .move(seat.x - Rig.crowFeet.x, seat.y - Rig.crowFeet.y) * crowPose(crowT, play: play, time: time)
        let frames = crowFrames(crowT, play: play, time: time)
        p.crowSitting = frames.sitting
        p.crowDown = frames.down
        p.crowSpread = frames.spread
        if landed > 0 && landed < 6 {
            p.crowHead = .about(Rig.crowNeck, IllustrationMotion.Crow.headCock(at: landed))
        }
        return p
    }

    /// The artwork's pixels, which the dance was tuned in, to the drawing's.
    static let px = 900.0 / 1640.0

    /// Two bones from the hip to a planted ankle.
    static func leg(from H: CGPoint, to A: CGPoint, hip: CGPoint, knee: CGPoint, ankle: CGPoint,
                    out: Double, pop: Double, give: Double = 0.6) -> (Mat, Mat) {
        let straight = hypot(ankle.x - hip.x, ankle.y - hip.y)
        let reach = hypot(A.x - H.x, A.y - H.y)
        let k = 1 - give * max(0, 1 - reach / straight)
        let L1 = hypot(knee.x - hip.x, knee.y - hip.y) * k
        let L2 = hypot(ankle.x - knee.x, ankle.y - knee.y) * k
        let D = min(reach, L1 + L2 - 0.001)
        let u = CGPoint(x: (A.x - H.x) / reach, y: (A.y - H.y) / reach)
        let along = (L1 * L1 - L2 * L2 + D * D) / (2 * D)
        let h = sqrt(max(L1 * L1 - along * along, 0))
        let n = CGPoint(x: -u.y * out, y: u.x * out)
        // A popped knee swings from out, through straight, to in.
        let side = h * (1 - 2 * pop) - pop * 14 * px
        let K = CGPoint(x: H.x + u.x * along + n.x * side, y: H.y + u.y * along + n.y * side)
        func angle(_ v: CGPoint) -> Double { atan2(v.y, v.x) * 180 / .pi }
        let th = angle(CGPoint(x: K.x - H.x, y: K.y - H.y)) - angle(CGPoint(x: knee.x - hip.x, y: knee.y - hip.y))
        let sh = angle(CGPoint(x: A.x - K.x, y: A.y - K.y)) - angle(CGPoint(x: ankle.x - knee.x, y: ankle.y - knee.y))
        let thigh = Mat.move(H.x, H.y) * .turn(th) * .move(-hip.x, -hip.y) * .scaled(about: hip, k)
        let shin = Mat.move(K.x, K.y) * .turn(sh) * .move(-knee.x, -knee.y) * .scaled(about: knee, k)
        return (thigh, shin)
    }

    // MARK: The crow

    /// The crow's flight, in the drawing's pixels, about its feet (landing)
    /// or its middle (in the air), as `IllustrationMotion.Crow` flies it.
    static func crowPose(_ t: Double, play: Int, time: Double) -> Mat {
        let pose: LayerPose
        if play > 1 && time < start(play: play) {
            pose = IllustrationMotion.Crow.leaving(at: time, flies: true)
        } else if t < 0 {
            return .move(0, -Rig.size.height * 2)
        } else {
            pose = IllustrationMotion.Crow.arriving(at: t, flies: true)
        }
        let pivot = pose.anchor == .bottom ? Rig.crowFeet : Rig.crowBody
        return .move(pose.x * Rig.size.width, pose.y * Rig.size.height)
            * .move(pivot.x, pivot.y) * .turn(pose.rotation) * .scale(pose.scaleX, pose.scaleY)
            * .move(-pivot.x, -pivot.y)
    }

    static func crowFrames(_ t: Double, play: Int, time: Double) -> (sitting: Double, down: Double, spread: Double) {
        let w: (perched: Double, down: Double, out: Double)
        if play > 1 && time < start(play: play) {
            w = IllustrationMotion.Crow.frames(leavingAt: time)
        } else if t < 0 {
            return (0, 0, 0)
        } else {
            w = IllustrationMotion.Crow.frames(arrivingAt: t)
        }
        let fade = t < 0 ? 1 : min(1, t / 0.1)
        let crouch = IllustrationMotion.Crow.crouch, away = IllustrationMotion.Crow.away
        let gone = play > 1 && time < start(play: play)
            ? max(0, 1 - max(0, (time - crouch) / (away - crouch) - 0.85) / 0.15)
            : 1
        return (w.perched * fade * gone, w.down * fade * gone, w.out * fade * gone)
    }
}
