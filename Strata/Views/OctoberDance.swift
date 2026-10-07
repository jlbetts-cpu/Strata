import SwiftUI

/// **October: the skeleton dances** (the owner, 2026-10-06: "the idea was a
/// dancing skeleton since all the bones are separate", "make sure the
/// skeleton actually looks like he's dancing, all his body parts moving,
/// doing a genuine move without overlapping elements", "make the animation
/// feel as realistic as possible").
///
/// **Short, as the crews' cheer is** (2026-10-07: "too long, I want like a
/// pretty short dance but still being expressive ... remove the bird for
/// now ... look at the crew, a very short but expressive animation"). About
/// 1.2s: a dip, the point down on the hit, the snap back up to his drawing,
/// a settle. Eight beats with a crow landing after them was the first cut.
///
/// **The move is the Saturday Night Fever point**, and the realism is in
/// what the rest of the body does about it:
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
/// Once, then again on a tap. Nothing loops (`Illustration` has why).
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
                }
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
    static let size = CGSize(width: 614, height: 900)

    static let bones = ["LThigh", "LShin", "LFoot", "RThigh", "RShin", "RFoot", "Pelvis", "Ribs",
                        "LUpper", "LFore", "LHand", "RUpper", "RFore", "RHand", "Skull"]

    static let neck = CGPoint(x: 265.91, y: 313.64)
    static let waist = CGPoint(x: 317.05, y: 525.0)
    static let pelvis = CGPoint(x: 317.05, y: 555.68)
    static let rShoulder = CGPoint(x: 393.41, y: 333.41)
    static let rElbow = CGPoint(x: 444.55, y: 223.64)
    static let rWrist = CGPoint(x: 469.09, y: 104.32)
    static let lShoulder = CGPoint(x: 162.27, y: 362.73)
    static let lElbow = CGPoint(x: 113.18, y: 481.36)
    static let lWrist = CGPoint(x: 89.32, y: 576.14)
    static let lHip = CGPoint(x: 233.86, y: 592.5)
    static let lKnee = CGPoint(x: 218.18, y: 709.09)
    static let lAnkle = CGPoint(x: 216.14, y: 827.05)
    static let rHip = CGPoint(x: 390.68, y: 605.45)
    static let rKnee = CGPoint(x: 400.23, y: 714.55)
    static let rAnkle = CGPoint(x: 399.55, y: 820.91)
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
    }

    /// Quicker than a song's beat: the phrase is two hits, down and up.
    static let bpm = 140.0
    /// Up as drawn, down on the first beat, up on the second, and a third of
    /// a beat to land it.
    static let beats = 2.35
    static var length: Double { beats * 60 / bpm }
    /// How much bigger than the long version each move is: a short phrase
    /// has to say it in fewer beats.
    static let size = 1.3

    static func start(play: Int) -> Double { 0 }

    static func duration(play: Int) -> Double { length + 0.15 }

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
        let env = dancing ? smooth(t / 0.12) * (1 - smooth((t - (length - 0.32)) / 0.32)) : 0
        let b = dancing ? t * bpm / 60 : 0

        let pt = point(b) * env
        let groove = 0.5 * cos(.pi * (b - 0.12)) * env
        func pointed(_ lag: Double) -> Double { point(b - lag) * env }

        var p = Pose()
        let P = Mat.move(-30 * size * px * groove, (12 * dip(b) + 5 * dip(b + 0.5)) * size * px * env)
            * .about(Rig.pelvis, 5 * size * groove)
        p.bones["Pelvis"] = P
        // The torso leans into the point, a breath behind the hips.
        let torso = P * .move(0, 3 * px * dip(b, lag: 0.05) * env)
            * .about(Rig.waist, (5 * (0.5 * env - pointed(0.06)) - 2 * env - 3 * groove))
        p.bones["Ribs"] = torso
        // The head lags the body, tilts with the point, nods on the beat.
        p.bones["Skull"] = torso * .move(0, 7 * px * dip(b, lag: 0.12) * env)
            * .about(Rig.neck, 7 * size * (0.5 * env - pointed(0.16)))
        // The pointing arm; held, it still pumps a little on the off-beat.
        let upper = torso * .about(Rig.rShoulder, 118 * pt + (5 - 10 * pt) * dip(b + 0.5) * env)
        p.bones["RUpper"] = upper
        let fore = upper * .about(Rig.rElbow, 12 * pt - 6 * (pt - pointed(0.1)))
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

        return p
    }

    /// The artwork's pixels, which the dance was tuned in, to the drawing's.
    static let px = 900.0 / 1320.0

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
}
