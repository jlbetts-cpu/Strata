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
/// **As long as October's dance** (`Dance.length`, about 1.2s with its
/// landing): three steps, left, right, left, the last one smaller, and a
/// settle onto both feet as he drew it.
///
/// - **The legs bend.** Each is three pieces, thigh, shin and toes, hung
///   from the hip. The knee folds back as the leg swings through, gives a
///   little on the footfall, and the toes curl down on the push-off and lift
///   before they land.
/// - **The body squashes on each footfall** and bobs up between, leaning a
///   little into the run.
/// - **The head thrusts forward a beat behind the step**, as a bird's does,
///   the beak opens a little on it, and the wattle swings after the head.
/// - **The fan sways with the hips and flares** on the settle; the closed
///   eye squeezes once mid-run and again, softly, as he stops.
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

enum TurkeyRun {
    /// October's length, so the two months' drawings take the same time.
    static var length: Double { Dance.length }
    static var duration: Double { Dance.duration(play: 1) }
    /// One and a half strides: three footfalls, left, right, left.
    static let strides = 1.5

    static func smooth(_ x: Double) -> Double { Dance.smooth(x) }

    /// An angle brought into -pi...pi, for a bump around one point of the stride.
    static func wrap(_ x: Double) -> Double {
        let r = (x + .pi).truncatingRemainder(dividingBy: 2 * .pi)
        return (r < 0 ? r + 2 * .pi : r) - .pi
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

    static func pose(at t: Double) -> [String: Mat] {
        // Standing as he drew him, before and after.
        guard t > 0, t < length else { return [:] }
        let env = smooth(t / 0.12) * (1 - smooth((t - (length - 0.32)) / 0.32))
        let phi = 2 * .pi * strides * t / length
        // 1 on each footfall (the leading leg at its reach), -1 between.
        func step(_ lag: Double) -> Double { cos(2 * phi - .pi - lag) }
        // The settle: both feet down, a last give, over the final 0.3s.
        let s = min(max((t - (length - 0.30)) / 0.30, 0), 1)
        let land = pow(sin(.pi * s), 2)

        var p: [String: Mat] = [:]

        // The body: down and squashed just after each footfall, up between,
        // leaning a little into the run.
        let squash = env * pow(max(0, step(0.5)), 2) + 0.6 * land
        let bob = 6 * env * step(0.4) + 4 * land
        let pitch = env * (-2.5 + 1.2 * sin(2 * phi - .pi - 1.0))
        let B = Mat.move(0, bob) * .about(TurkeyRig.chest, pitch)
            * .move(TurkeyRig.belly.x, TurkeyRig.belly.y) * .scale(1 + 0.03 * squash, 1 - 0.04 * squash)
            * .move(-TurkeyRig.belly.x, -TurkeyRig.belly.y)
        p["Body"] = B

        // The fan, on the back: it sways with the hips and draws in on each
        // footfall and opens out between; on the settle it flares and comes back
        // to his drawing.
        p["Tail"] = B * fixing(TurkeyRig.fanLeft, TurkeyRig.fanRight, toward: CGPoint(x: 500, y: 150),
                               shear: env * 0.07 * sin(phi - 0.6),
                               stretch: 1 - 0.05 * env * step(0.8) + 0.1 * land)

        // The head, on the neck: forward a beat after the footfall, back as
        // the next leg reaches, the neck giving under it as it lands.
        let thrust = env * (0.035 + 0.055 * step(1.0)) + 0.05 * land
        let H = B * fixing(TurkeyRig.throat, TurkeyRig.nape, toward: TurkeyRig.eye,
                           shear: -thrust, stretch: 1 - 0.03 * env * max(0, step(0.7)) - 0.025 * land)
        p["Head"] = H
        // The beak opens a little as the head goes forward.
        let open = env * pow(max(0, step(1.6)), 2) + 0.5 * land
        p["Beak"] = H * fixing(TurkeyRig.beakTop, TurkeyRig.beakBase, toward: CGPoint(x: 90, y: 260),
                               shear: -0.11 * open)
        // The wattle hangs between the beak and the throat and swings after
        // the head, and once more as he stops.
        let swing = env * 0.22 * sin(2 * phi - .pi - 2.2) + 0.2 * sin(2 * .pi * s) * (1 - s)
        p["Wattle"] = H * fixing(TurkeyRig.beakBase, TurkeyRig.throat, toward: CGPoint(x: 60, y: 360),
                                 shear: swing, stretch: 1 + 0.06 * env * cos(2 * phi - .pi - 2.2))
        // The closed eye squeezes once mid-run, and softly as he stops.
        let squeeze = env * exp(-pow((t - 0.42) / 0.045, 2)) + 0.4 * land
        p["Eye"] = H * .move(TurkeyRig.eye.x, TurkeyRig.eye.y) * .scale(1 + 0.08 * squeeze, 1 - 0.5 * squeeze)
            * .move(-TurkeyRig.eye.x, -TurkeyRig.eye.y)
        p["Smile"] = H * .scaled(about: TurkeyRig.smile, 1 + 0.15 * open)

        // The legs: thigh from the hip, shin from the knee, toes from the
        // ankle. Forward is clockwise, as the turkey faces left.
        // **Between his two drawings**: out to the running one (the near leg
        // reaching, the far leg pushed back) and back past the standing one
        // (the feet gathered under him, a little the other way). The near
        // leg stays the forward one, as he drew it, so the two never cross
        // into an X below the body; swinging both legs the same way did.
        for (side, phase, centre, swing) in [("L", phi, 14.0, 20.0), ("R", phi + .pi, -24.0, 22.0)] {
            let hip = side == "L" ? TurkeyRig.lHip : TurkeyRig.rHip
            let knee = side == "L" ? TurkeyRig.lKnee : TurkeyRig.rKnee
            let ankle = side == "L" ? TurkeyRig.lAnkle : TurkeyRig.rAnkle
            let thigh = env * (centre + swing * sin(phase))
            // The knee folds back as the leg swings through, gives as it lands.
            let through = max(0, cos(phase))
            let give = exp(-pow(wrap(phase - .pi / 2 - 0.3), 2) / 0.15)
            let bend = -env * (40 * pow(through, 1.5) + 7 * give) - 8 * land
            // The toes stay near level, curl down on the push-off and lift
            // before they land.
            let push = exp(-pow(wrap(phase - 3 * .pi / 2 - 0.35), 2) / 0.3)
            let reach = exp(-pow(wrap(phase - .pi / 2 + 0.25), 2) / 0.3)
            let toes = -0.8 * (thigh + bend) + env * (-24 * push + 12 * reach)

            let T = Mat.move(B.apply(hip).x, B.apply(hip).y) * .turn(thigh) * .move(-hip.x, -hip.y)
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
