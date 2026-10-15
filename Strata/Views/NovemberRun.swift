import SwiftUI

/// **November: the turkey runs** (the owner, 2026-10-14: "for november i
/// want to do an animation around the same length as the skeleton of a
/// running turkey here are the two images I made could you make the rest by
/// moving parts of the turkey", then "make sure for the animations you are
/// animating as many parts as possible", the legs bending naturally, "and
/// the eyes and mouth and stuff").
///
/// His standing turkey, cut into thirteen parts and moved, never redrawn:
/// every pixel of every layer is his ink at his alpha, only on its own
/// layer, and each layer reaches 3px past its cut into the one it meets so
/// no hairline shows at a join. His running drawing is the stride's reach:
/// the legs swing out toward it and come back to him standing.
///
/// **1.6s, with its hold**: October's 1.0s dance plus a crouch before the
/// first step and a held beat after the landing (`TurkeyRun` has the cartoon
/// timing). A crouch, three steps, left, right, left, with air between, a
/// landing on both feet as he drew it, a hold and one blink.
///
/// - **The legs bend.** Each is three pieces, thigh, shin and toes, hung
///   from the hip. The knee folds hard as the leg swings through, gives on
///   the footfall, and the toes curl down on the push-off and lift before
///   they land.
/// - **The body squashes and stretches**, bobs up into a hop between steps
///   and leans into the run.
/// - **The head thrusts forward past its mark** a beat behind each step,
///   the beak opens on it, and the wattle trails the head.
/// - **The fan whips after the body** and settles a beat after it.
///
/// **Nothing comes apart.** A turkey is one outline, not loose bones, so a
/// part that moves where it meets another is moved by a transform that holds
/// the line they share still (`TurkeyRun.fixing`): the head on the neck, the
/// beak on the face, the wattle between the beak and the throat, the fan on
/// the back. The joins stay joined at every frame.
///
/// Once, then again on a tap. Nothing loops (`Illustration` has why).
struct NovemberRun: View {
    var line: String?
    var height: CGFloat = 290
    var onRest: (@MainActor () -> Void)? = nil
    /// His drawing standing still, for a page that only shows it (Settings).
    var still = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var playedAt: Date?
    @State private var plays = 0
    @State private var awake = false

    var body: some View {
        VStack(spacing: GridConstants.gapItem) {
            // Scaled to the room it is given, never overflowing it, as
            // October's is (`OctoberDance`).
            GeometryReader { geo in
                stage
                    .frame(width: height * TurkeyRig.size.width / TurkeyRig.size.height, height: height)
                    .scaleEffect(min(1, geo.size.height / height))
                    .frame(width: geo.size.width, height: geo.size.height)
            }
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
        if reduceMotion || still {
            scene(TurkeyRun.pose(at: .infinity))
                .onAppear { onRest?() }
        } else if !awake {
            // His drawing first, still, and the timeline a beat later, as
            // October's (`OctoberDance` has the measurement).
            scene(TurkeyRun.pose(at: 0))
                .task {
                    try? await Task.sleep(for: .milliseconds(150))
                    awake = true
                }
        } else {
            TimelineView(.animation(paused: playedAt == nil)) { context in
                let t = plays == 0 ? 0 : playedAt.map { context.date.timeIntervalSince($0) } ?? .infinity
                scene(TurkeyRun.pose(at: t))
            }
            .contentShape(Rectangle())
            .onTapGesture { play() }
            .onAppear {
                plays = 0
                play()
                #if DEBUG
                if DebugHarness.argument("-strataRenderRun") != nil { renderFrames() }
                #endif
            }
            .onDisappear { playedAt = nil }
            // Plays when it comes into view, not only when it is built
            // (`OctoberDance` has why).
            .onScrollVisibilityChange(threshold: 0.6) { visible in
                guard visible else { return }
                playedAt = nil
                plays = 0
                play()
            }
        }
    }

    #if DEBUG
    /// `-strataRenderRun 1`: every twelfth of a second of a play, drawn to
    /// Documents/run as pictures, so the motion can be checked frame by frame.
    private func renderFrames() {
        let folder = URL.documentsDirectory.appending(path: "run")
        try? FileManager.default.removeItem(at: folder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (i, t) in stride(from: 0.0, through: TurkeyRun.duration, by: 1.0 / 12).enumerated() {
            let renderer = ImageRenderer(content: scene(TurkeyRun.pose(at: t))
                .frame(width: 290 * TurkeyRig.size.width / TurkeyRig.size.height, height: 290)
                .padding(60)
                .background(Color.white))
            renderer.scale = 2
            if let data = renderer.uiImage?.pngData() {
                try? data.write(to: folder.appending(path: String(format: "r_%03d.png", i)))
            }
        }
        print("RUN-RENDERED", folder.path)
    }
    #endif

    private func scene(_ pose: [String: Mat]) -> some View {
        GeometryReader { geo in
            let s = geo.size.height / TurkeyRig.size.height
            ZStack(alignment: .topLeading) {
                ForEach(TurkeyRig.parts, id: \.self) { part in
                    layer(part, pose[part] ?? .identity, scale: s)
                }
            }
        }
    }

    private func layer(_ name: String, _ m: Mat, scale s: CGFloat) -> some View {
        Image("MonthNovemberTurkey" + name)
            .renderingMode(.template)
            .resizable()
            .frame(width: TurkeyRig.size.width * s, height: TurkeyRig.size.height * s)
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
            try? await Task.sleep(for: .seconds(TurkeyRun.duration + 0.05))
            if playedAt == started {
                playedAt = nil
                onRest?()
            }
        }
    }
}

// MARK: - The rig

/// The turkey's parts and joins, in the drawing's own pixels. The canvas
/// is October's scale: 1320 of his 2048 pixels tall (y 320 to 1640, x 480 to
/// 1680) drawn at 900, so his pen lands at the skeleton's weight on the page.
enum TurkeyRig {
    static let size = CGSize(width: 818, height: 900)

    /// Back to front: the far leg, the near leg, the fan behind the body,
    /// then the head and what is on it.
    static let parts = ["RThigh", "RShin", "RFoot", "LThigh", "LShin", "LFoot", "Tail", "Body",
                        "Wattle", "Head", "Beak", "Eye", "Smile"]

    /// Where the throat's front line leaves the wattle, and where the back
    /// leaves the neck: the line the head moves about.
    static let throat = CGPoint(x: 90.0, y: 425.45)
    static let nape = CGPoint(x: 255.68, y: 351.82)
    /// Where the beak meets the crown, and the wattle under it.
    static let beakTop = CGPoint(x: 155.45, y: 196.36)
    static let beakBase = CGPoint(x: 189.55, y: 278.18)
    /// The fan's two edges on the back.
    static let fanLeft = CGPoint(x: 375.0, y: 337.5)
    static let fanRight = CGPoint(x: 537.27, y: 429.55)
    static let eye = CGPoint(x: 220.91, y: 198.41)
    static let smile = CGPoint(x: 214.09, y: 261.14)
    static let chest = CGPoint(x: 354.55, y: 531.82)
    static let belly = CGPoint(x: 415.91, y: 702.27)
    static let lHip = CGPoint(x: 245.45, y: 710.45)
    static let lKnee = CGPoint(x: 245.45, y: 768.41)
    static let lAnkle = CGPoint(x: 241.36, y: 810.0)
    static let rHip = CGPoint(x: 322.5, y: 710.45)
    static let rKnee = CGPoint(x: 327.27, y: 765.68)
    static let rAnkle = CGPoint(x: 325.91, y: 807.95)
}

// MARK: - The run

/// **Cartoon timing** (the owner, 2026-10-14: "for the animations make them
/// more like animated"): the classic principles, on his drawing.
///
/// - **Anticipation**: a crouch and a lean back, the fan drawn in and the
///   head pulled back, before the first push.
/// - **Squash and stretch**: the body squashes on each footfall and on the
///   landing and stretches up off each push.
/// - **A hop of air** between strides: the body rises off every step.
/// - **Arcs**: the legs swing wide and the knee folds hard as each comes
///   through.
/// - **Overshoot**: the head thrusts past its mark on each step and on the
///   landing, and rings back.
/// - **Follow-through**: the wattle trails the head and the fan whips after
///   the body, both settling a beat after it stops.
/// - **A held pose**: he lands on both feet as he drew it, holds, and blinks
///   once.
enum TurkeyRun {
    /// The crouch, three steps, the landing and the held beat. Longer than
    /// October's 1.0s dance by the anticipation and the hold.
    static let length = 1.45
    static var duration: Double { length + 0.15 }
    /// The crouch, until the first push.
    static let crouch = 0.20
    /// Three footfalls, left, right, left, and the air after the last.
    static let runTime = 0.85
    static var landing: Double { crouch + runTime }
    /// One and a half strides: three footfalls.
    static let strides = 1.5

    static func smooth(_ x: Double) -> Double { Dance.smooth(x) }

    /// An angle brought into -pi...pi, for a bump around one point of the stride.
    static func wrap(_ x: Double) -> Double {
        let r = (x + .pi).truncatingRemainder(dividingBy: 2 * .pi)
        return (r < 0 ? r + 2 * .pi : r) - .pi
    }

    static func bump(_ x: Double, at c: Double, width w: Double) -> Double { exp(-pow((x - c) / w, 2)) }

    /// A struck spring: nothing before `u` = 0, then a swing that dies away.
    static func kick(_ u: Double, decay: Double, hz: Double) -> Double {
        u > 0 ? exp(-u / decay) * sin(2 * .pi * hz * u) : 0
    }

    // MARK: Time

    /// The crouch: down and back, released into the first push.
    static func ant(_ t: Double) -> Double { smooth(t / 0.16) * (1 - smooth((t - 0.16) / 0.07)) }
    /// How much of the run is on: up after the push, down into the landing.
    static func runEnv(_ t: Double) -> Double {
        let r = t - crouch
        guard r > 0, r < runTime else { return 0 }
        return smooth(r / 0.08) * (1 - smooth((r - (runTime - 0.2)) / 0.2))
    }
    static func phi(_ t: Double) -> Double { 2 * .pi * strides * max(t - crouch, 0) / runTime }
    /// 0 on each footfall, pi in the air between.
    static func psi(_ t: Double) -> Double { 2 * phi(t) - .pi }
    /// The air between strides: 0 on a foot, 1 at the top of the hop.
    static func air(_ t: Double) -> Double { runEnv(t) * (1 - cos(psi(t))) / 2 }
    /// The landing on both feet: a squash that eases off.
    static func land(_ t: Double) -> Double {
        let u = t - landing
        return u > 0 ? smooth(u / 0.04) * exp(-u / 0.09) : 0
    }
    /// Everything that rings after the landing is quiet by the end.
    static func fin(_ t: Double) -> Double { 1 - smooth((t - (length - 0.1)) / 0.1) }

    static let footfalls: [Double] = [1.0, 3.0, 5.0].map { crouch + runTime * $0 / 6 }

    /// The body's height, down positive: down in the crouch, up in the hops.
    static func bob(_ t: Double) -> Double {
        (-22 * air(t) + 10 * ant(t) + 8 * land(t)) * fin(t)
    }

    /// How far forward the head is: pulled back in the crouch, forward a
    /// beat after each footfall and past its mark, hard forward on the
    /// landing and ringing back.
    static func thrust(_ t: Double) -> Double {
        let run = runEnv(t) * (0.06 + 0.06 * cos(psi(t) - 0.9))
        var over = 0.0
        for f in footfalls { over += runEnv(f) * 0.05 * kick(t - f - 0.05, decay: 0.07, hz: 4) }
        let u = t - landing
        return (-0.10 * ant(t) + run + over + 0.12 * land(t) + 0.06 * kick(u - 0.03, decay: 0.1, hz: 2.6)) * fin(t)
    }

    /// **A move that keeps one line still**: everything slides along the
    /// line from `p` to `q` (`shear`, per pixel of distance from it) and
    /// stretches away from it (`stretch`), while every point on it stays
    /// where it is. Two parts that meet on that line stay met.
    static func fixing(_ p: CGPoint, _ q: CGPoint, toward side: CGPoint,
                       shear k: Double, stretch s: Double = 1) -> Mat {
        let len = hypot(q.x - p.x, q.y - p.y)
        let u = CGPoint(x: (q.x - p.x) / len, y: (q.y - p.y) / len)
        var n = CGPoint(x: u.y, y: -u.x)
        if (side.x - p.x) * n.x + (side.y - p.y) * n.y < 0 { n = CGPoint(x: -n.x, y: -n.y) }
        let v = CGPoint(x: k * u.x + (s - 1) * n.x, y: k * u.y + (s - 1) * n.y)
        var m = Mat(a: 1 + v.x * n.x, b: v.x * n.y, c: v.y * n.x, d: 1 + v.y * n.y)
        m.tx = p.x - (m.a * p.x + m.b * p.y)
        m.ty = p.y - (m.c * p.x + m.d * p.y)
        return m
    }

    // MARK: The pose

    static func pose(at t: Double) -> [String: Mat] {
        // Standing as he drew him, before and after.
        guard t > 0, t < length else { return [:] }
        let ant = ant(t), env = runEnv(t), land = land(t), fin = fin(t)
        let phi = phi(t), psi = psi(t)
        let u = t - landing

        var p: [String: Mat] = [:]

        // The body: squashed in the crouch, on each footfall and on the
        // landing (wider as it goes shorter), stretched up off each push.
        let squash = env * bump(wrap(psi), at: 0.35, width: 0.45)
        let stretch = env * bump(wrap(psi), at: 1.4, width: 0.5) + 0.8 * bump(t, at: crouch + 0.04, width: 0.04)
        let q = (0.10 * squash + 0.12 * ant + 0.16 * land - 0.07 * stretch
                 - 0.05 * kick(u - 0.06, decay: 0.09, hz: 3)) * fin
        // Leaning back into the crouch, forward into the run, rocking on
        // the landing.
        let pitch = (5 * ant - 5 * env + 2 * env * sin(psi - 1.0) - 4 * land
                     + 2.5 * kick(u - 0.04, decay: 0.12, hz: 2.6)) * fin
        let B = Mat.move(0, bob(t)) * .about(TurkeyRig.chest, pitch)
            * .move(TurkeyRig.belly.x, TurkeyRig.belly.y) * .scale(1 + 0.75 * q, 1 - q)
            * .move(-TurkeyRig.belly.x, -TurkeyRig.belly.y)
        p["Body"] = B

        // The fan, on the back: drawn in for the crouch, open in the air,
        // and whipping after the body, most of all on the landing.
        let whip = 0.006 * (bob(t - 0.07) - bob(t)) + 0.16 * kick(u - 0.02, decay: 0.13, hz: 2.4) * fin
            + 0.06 * kick(t - crouch - 0.03, decay: 0.1, hz: 3)
        let flare = 1 + (-0.10 * ant + 0.07 * air(t) - 0.05 * squash + 0.12 * kick(u, decay: 0.14, hz: 2.0)) * fin
        p["Tail"] = B * fixing(TurkeyRig.fanLeft, TurkeyRig.fanRight, toward: CGPoint(x: 500, y: 150),
                               shear: whip, stretch: flare)

        // The head, on the neck.
        let neck = 1 + (0.04 * ant - 0.06 * squash + 0.04 * stretch - 0.08 * land) * fin
        let H = B * fixing(TurkeyRig.throat, TurkeyRig.nape, toward: TurkeyRig.eye,
                           shear: -thrust(t), stretch: neck)
        p["Head"] = H
        // The beak opens on the steps and gobbles once on the landing.
        let open = (env * pow(max(0, cos(psi - 1.2)), 2) * 0.8 + bump(u, at: 0.08, width: 0.06)) * fin
        p["Beak"] = H * fixing(TurkeyRig.beakTop, TurkeyRig.beakBase, toward: CGPoint(x: 90, y: 260),
                               shear: -0.14 * open)
        // The wattle trails the head: it swings back as the head goes
        // forward and catches up after it stops.
        let trail = max(-0.45, min(0.45, 2.5 * (thrust(t - 0.06) - thrust(t))))
        p["Wattle"] = H * fixing(TurkeyRig.beakBase, TurkeyRig.throat, toward: CGPoint(x: 60, y: 360),
                                 shear: trail, stretch: 1 + (0.06 * stretch - 0.08 * squash) * fin)
        // The closed eye squeezes in the crouch and on the landing, and
        // blinks once in the held pose.
        let squeeze = min(1, (0.5 * ant + 0.3 * land) * fin + bump(t, at: 1.32, width: 0.035))
        p["Eye"] = H * .move(TurkeyRig.eye.x, TurkeyRig.eye.y) * .scale(1 + 0.1 * squeeze, 1 - 0.75 * squeeze)
            * .move(-TurkeyRig.eye.x, -TurkeyRig.eye.y)
        p["Smile"] = H * .scaled(about: TurkeyRig.smile, 1 + (0.2 * open + 0.1 * ant) * fin)

        // **The legs, between his two drawings**: out to the running one
        // (the near leg reaching, the far leg pushed back) and back past the
        // standing one. The near leg stays the forward one, as he drew it,
        // so the two never cross into an X below the body. Thigh from the
        // hip, shin from the knee, toes from the ankle; forward is
        // clockwise, as the turkey faces left.
        for (side, phase, centre, swing) in [("L", phi, 22.0, 30.0), ("R", phi + .pi, -32.0, 32.0)] {
            let hip = side == "L" ? TurkeyRig.lHip : TurkeyRig.rHip
            let knee = side == "L" ? TurkeyRig.lKnee : TurkeyRig.rKnee
            let ankle = side == "L" ? TurkeyRig.lAnkle : TurkeyRig.rAnkle
            // The crouch and the landing fold both knees, so the feet stay
            // on the ground as the body comes down.
            let thigh = env * (centre + swing * sin(phase)) + (25 * ant + 20 * land) * fin
            // The knee folds hard as the leg swings through, gives as it lands.
            let through = max(0, cos(phase))
            let give = bump(wrap(phase - .pi / 2 - 0.3), at: 0, width: 0.4)
            let bend = -env * (70 * pow(through, 1.5) + 12 * give) - (50 * ant + 40 * land) * fin
            // The toes stay near level, curl down on the push-off and lift
            // before they land.
            let push = bump(wrap(phase - 3 * .pi / 2 - 0.35), at: 0, width: 0.55)
            let reach = bump(wrap(phase - .pi / 2 + 0.25), at: 0, width: 0.55)
            let toes = -0.85 * (thigh + bend) + env * (-35 * push + 18 * reach)
                - 25 * bump(t, at: crouch + 0.02, width: 0.04)

            let h = B.apply(hip)
            let T = Mat.move(h.x, h.y) * .turn(thigh) * .move(-hip.x, -hip.y)
            let k = T.apply(knee)
            let S = Mat.move(k.x, k.y) * .turn(thigh + bend) * .move(-knee.x, -knee.y)
            let a = S.apply(ankle)
            p[side + "Thigh"] = T
            p[side + "Shin"] = S
            p[side + "Foot"] = .move(a.x, a.y) * .turn(thigh + bend + toes) * .move(-ankle.x, -ankle.y)
        }
        return p
    }
}
