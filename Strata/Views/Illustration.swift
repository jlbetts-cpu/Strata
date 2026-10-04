import SwiftUI

/// **One of the owner's drawings, with its line under it.** Nothing around
/// it: no card, no rim, the drawing and the words on the page itself (the
/// owner, 2026-10-03: "I dont like the illustration in the block try it just
/// blank"). The drawing is in the page's ink, so it follows dark mode; the
/// line is SF Pro, set small and close under it so the two read as one piece,
/// the way HeyTea sets theirs.
///
/// **And it can move, once** (the owner, 2026-10-03: "a little animation
/// would really make the app come to life"). A drawing with a `motion` is two
/// of his layers, the same size so they line up exactly, and the moving one
/// plays when the page opens and again on a tap. Once, not a loop: nothing in
/// this app loops (`SkeletonBlockView` has why), and he chose "once, then on
/// tap". Under Reduce Motion it is the still drawing. The timeline runs only
/// while a play is under way.
struct Illustration: View {
    let art: UIImage
    let line: String?
    /// The drawing's height at most; the width follows the drawing. It gives
    /// up to half of it on a small screen rather than crowd what is beside it
    /// (an iPhone SE has about 130pt above October's calendar).
    var height: CGFloat = 150
    var motion: IllustrationMotion? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// When the current play began; nil at rest.
    @State private var playedAt: Date?
    /// Plays since the page appeared: the first is the arrival.
    @State private var plays = 0
    /// Where each moving layer's ink is, as fractions of the drawing: what it
    /// tilts and squashes around (the crow's own feet, not the corner of the
    /// full-size layer it is drawn on, which swung it onto the sleeve), and
    /// where the eyes look from.
    @State private var inks: [CGRect] = []

    var body: some View {
        VStack(spacing: GridConstants.gapItem) {
            drawing
                .frame(minHeight: height * 0.5, maxHeight: height)
                // Takes its room before the space around it does, so the
                // space shrinks first and the drawing only after.
                .layoutPriority(1)
            if let line {
                Text(line)
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .tracking(0.2)
                    .foregroundStyle(AppColors.inkPrimary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(line ?? "")
        .accessibilityHidden(line == nil)
    }

    @ViewBuilder
    private var drawing: some View {
        if let motion, !reduceMotion {
            TimelineView(.animation(paused: playedAt == nil)) { context in
                // Before the first play the moving layer is where the play
                // starts (the crow out of sight), so nothing jumps.
                let t = plays == 0 ? 0 : playedAt.map { context.date.timeIntervalSince($0) } ?? .infinity
                ZStack {
                    layer(art)
                        .modifier(motion.base(at: t, play: max(plays, 1)))
                    ForEach(Array(motion.layers.enumerated()), id: \.offset) { index, image in
                        layer(image)
                            // Its own small move first (the crow's head
                            // cocking on its neck), then the move it shares.
                            .modifier(motion.localPose(of: index, at: t, play: max(plays, 1), inks: inks))
                            .modifier(motion.pose(of: index, at: t, play: max(plays, 1), inks: inks))
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { play() }
            .onAppear {
                if inks.isEmpty { inks = motion.layers.map(IllustrationMotion.inkBounds) }
                plays = 0
                play()
            }
            .onDisappear { playedAt = nil }
        } else {
            ZStack {
                layer(art)
                if let motion {
                    // Still: the perched crow, never its flying frames.
                    ForEach(Array(motion.stillLayers.enumerated()), id: \.offset) { _, image in layer(image) }
                }
            }
        }
    }

    private func layer(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(AppColors.inkPrimary)
    }

    /// Starts a play unless one is under way, and lets the timeline rest
    /// when it is over.
    private func play() {
        guard let motion, playedAt == nil else { return }
        plays += 1
        let started = Date()
        playedAt = started
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(motion.duration(play: plays) + 0.05))
            if playedAt == started { playedAt = nil }
        }
    }
}

/// How a drawing moves: which of its layers moves, and how, as a pure
/// function of the seconds since the play began.
enum IllustrationMotion {
    /// October: the crow flies in and lands on the scarecrow's shoulder, and
    /// the scarecrow watches it come (the owner, 2026-10-03: "can the face
    /// actually react to the bird"): its eyes follow the crow a beat behind,
    /// as eyes do, its mouth rounds to an "oh" as the crow comes close and
    /// lands, and a moment later it looks back out at you. The first play is
    /// the arrival; a tap sends the crow off into the sky and back.
    ///
    /// **It flies on his drawings** (2026-10-03): two more crows he drew in
    /// place, wings down and wings spread, alternate as the wingbeats, with
    /// a two-frame blend at each change so the beat reads as motion, not as
    /// a flicker, and the body lifting on each downstroke. It glides in on
    /// spread wings, drops them to land, and is the perched crow from the
    /// touchdown; settled, it cocks its head (its own layer, on its neck).
    case crowLands(crow: UIImage, head: UIImage?, wingsDown: UIImage?, wingsOut: UIImage?,
                   eyes: UIImage?, mouth: UIImage?)
    /// Crews: the three friends hop together, and their cheer marks burst out.
    case cheer(marks: UIImage)

    enum Role { case crow, crowHead, crowDown, crowOut, eyes, mouth, marks }

    var roles: [(Role, UIImage)] {
        switch self {
        case .crowLands(let crow, let head, let down, let out, let eyes, let mouth):
            var list: [(Role, UIImage)] = [(.crow, crow)]
            if let head { list.append((.crowHead, head)) }
            if let down, let out { list += [(.crowDown, down), (.crowOut, out)] }
            if let eyes { list.append((.eyes, eyes)) }
            if let mouth { list.append((.mouth, mouth)) }
            return list
        case .cheer(let marks): return [(.marks, marks)]
        }
    }

    var layers: [UIImage] { roles.map(\.1) }
    var stillLayers: [UIImage] {
        roles.filter { $0.0 != .crowDown && $0.0 != .crowOut }.map(\.1)
    }
    private var flies: Bool { roles.contains { $0.0 == .crowOut } }

    func duration(play: Int) -> Double {
        switch self {
        case .crowLands: (play <= 1 ? Crow.arrive : Crow.away + Crow.arrive) + Face.tail
        case .cheer: Cheer.total
        }
    }

    /// The layer that stays: still for the crow, hopping for the friends.
    func base(at t: Double, play: Int) -> LayerPose {
        switch self {
        case .crowLands: .rest
        case .cheer: Cheer.friends(at: t)
        }
    }

    /// One moving layer's pose. `inks` are the layers' ink boxes, in the
    /// order of `layers`; until they are measured, everything rests.
    func pose(of index: Int, at t: Double, play: Int, inks: [CGRect]) -> LayerPose {
        guard inks.count == roles.count else { return .rest }
        let ink = inks[index]
        var pose: LayerPose
        switch roles[index].0 {
        case .crow, .crowHead, .crowDown, .crowOut:
            // One move for every drawing of the crow, about the perched
            // crow's own feet, so the frames stay on top of each other.
            pose = crow(at: t, play: play)
            pose.opacity *= frameWeight(roles[index].0, at: t, play: play)
            if let body = roles.firstIndex(where: { $0.0 == .crow }) {
                let box = inks[body]
                pose.anchor = pose.anchor == .bottom ? UnitPoint(x: box.midX, y: box.maxY)
                                                     : UnitPoint(x: box.midX, y: box.midY)
            }
            return pose
        case .marks:
            pose = Cheer.marks(at: t)
        case .eyes:
            guard let crowIndex = roles.firstIndex(where: { $0.0 == .crow }) else { return .rest }
            // Where the crow is a beat ago: eyes trail a moving thing.
            let lagged = crow(at: max(0, t - Face.lag), play: play)
            let crowBox = inks[crowIndex]
            pose = Face.eyes(looking: CGPoint(x: crowBox.midX + lagged.x, y: crowBox.midY + lagged.y),
                             from: CGPoint(x: ink.midX, y: ink.midY),
                             strength: Face.attention(at: t, play: play))
        case .mouth:
            pose = Face.mouth(at: t, play: play)
        }
        // Turn and squash around the layer's own ink: its middle, or its
        // foot when the pose says bottom.
        pose.anchor = pose.anchor == .bottom ? UnitPoint(x: ink.midX, y: ink.maxY)
                                             : UnitPoint(x: ink.midX, y: ink.midY)
        return pose
    }

    private func crow(at t: Double, play: Int) -> LayerPose {
        if play <= 1 { return Crow.arriving(at: t, flies: flies) }
        return t < Crow.away ? Crow.leaving(at: t, flies: flies) : Crow.arriving(at: t - Crow.away, flies: flies)
    }

    /// How much of each drawing of the crow shows: perched on the shoulder,
    /// the flying frames in the air.
    private func frameWeight(_ role: Role, at t: Double, play: Int) -> Double {
        guard flies else { return role == .crow || role == .crowHead ? 1 : 0 }
        let w: (perched: Double, down: Double, out: Double)
        if play <= 1 { w = Crow.frames(arrivingAt: t) }
        else if t < Crow.away { w = Crow.frames(leavingAt: t) }
        else { w = Crow.frames(arrivingAt: t - Crow.away) }
        switch role {
        case .crow, .crowHead: return w.perched
        case .crowDown: return w.down
        case .crowOut: return w.out
        default: return 1
        }
    }

    /// A layer's own small move inside the shared one: the crow's head
    /// cocking on its neck once it has settled.
    func localPose(of index: Int, at t: Double, play: Int, inks: [CGRect]) -> LayerPose {
        guard inks.count == roles.count, roles[index].0 == .crowHead else { return .rest }
        let landed = play <= 1 ? Crow.fly : Crow.away + Crow.fly
        let ink = inks[index]
        var pose = LayerPose.rest
        pose.rotation = Crow.headCock(at: t - landed)
        pose.anchor = UnitPoint(x: ink.midX, y: ink.maxY)
        return pose
    }

    // MARK: The face

    /// The scarecrow watching the crow.
    private enum Face {
        /// How far behind the crow the eyes are, in seconds.
        static let lag = 0.09
        /// How long after the crow lands the face holds, then looks back.
        static let hold = 0.6
        static let back = 0.6
        static let tail = hold + back

        /// How much the eyes are on the crow: they find it as it appears,
        /// stay on it until a moment after it lands, then drift back out.
        static func attention(at t: Double, play: Int) -> Double {
            let landed = play <= 1 ? Crow.arrive : Crow.away + Crow.arrive
            let find = smooth(t / 0.3)
            let release = smooth((t - landed - hold) / back)
            return find * (1 - release)
        }

        /// The dots shift toward the crow, a couple of points at most: a
        /// glance, not a rotation. Direction only; the distance is fixed.
        static func eyes(looking target: CGPoint, from eye: CGPoint, strength: Double) -> LayerPose {
            // In points' proportions: the drawing is two-thirds as wide as tall.
            let dx = (target.x - eye.x) * 0.667, dy = target.y - eye.y
            let length = max(sqrt(dx * dx + dy * dy), 0.0001)
            let reach = 0.0095 * strength
            return LayerPose(x: dx / length * reach / 0.667, y: dy / length * reach,
                             scaleX: 1, scaleY: 1, rotation: 0, opacity: 1, anchor: .center)
        }

        /// An "oh": rounds as the crow comes close, widest just after it
        /// lands, then softens back. A small one when it takes off.
        static func mouth(at t: Double, play: Int) -> LayerPose {
            var oh = bump(t, rise: Crow.fly * 0.55, peak: Crow.fly + 0.12, fall: Crow.fly + 0.85)
            if play > 1 {
                oh = 0.55 * bump(t, rise: 0, peak: Crow.crouch + 0.15, fall: 0.75)
                    + bump(t, rise: Crow.away + Crow.fly * 0.55, peak: Crow.away + Crow.fly + 0.12,
                           fall: Crow.away + Crow.fly + 0.85)
            }
            return LayerPose(x: 0, y: 0, scaleX: 1 + 0.16 * oh, scaleY: 1 + 0.32 * oh,
                             rotation: 0, opacity: 1, anchor: .center)
        }

        static func smooth(_ x: Double) -> Double {
            let u = min(max(x, 0), 1)
            return u * u * (3 - 2 * u)
        }

        /// 0 before `rise`, easing up to 1 at `peak`, easing down to 0 by `fall`.
        static func bump(_ t: Double, rise: Double, peak: Double, fall: Double) -> Double {
            if t <= rise || t >= fall { return 0 }
            return t < peak ? smooth((t - rise) / (peak - rise)) : 1 - smooth((t - peak) / (fall - peak))
        }
    }

    /// The box round a layer's ink, as fractions of the image, found once.
    static func inkBounds(of image: UIImage) -> CGRect {
        guard let cg = image.cgImage else { return CGRect(x: 0, y: 0, width: 1, height: 1) }
        let w = cg.width, h = cg.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var minX = w, minY = h, maxX = 0, maxY = 0
        for y in 0..<h {
            for x in 0..<w where pixels[(y * w + x) * 4 + 3] > 40 {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return CGRect(x: 0, y: 0, width: 1, height: 1) }
        return CGRect(x: Double(minX) / Double(w), y: Double(minY) / Double(h),
                      width: Double(maxX - minX) / Double(w), height: Double(maxY - minY) / Double(h))
    }

    // MARK: The crow

    /// Drawn the way a bird actually comes in (the owner, 2026-10-03: "really
    /// smooth and thought through not stiffy"): wingbeats that slow into a
    /// glide, a brake (the body tips back) just before the feet touch, and a
    /// landing that gives and springs, settling in two small wobbles. Every
    /// value is continuous across the phases, so nothing jumps.
    private enum Crow {
        static let fly = 1.25         // in the air
        static let settle = 0.55      // the springy touchdown
        static let arrive = fly + settle
        static let crouch = 0.14      // the anticipation before a take-off
        static let away = crouch + 0.95
        /// Wingbeats a second.
        static let beats = 3.4
        /// Where the flight starts, as a fraction of the drawing's size: up
        /// and off to the right, out of the drawing.
        static let from = CGPoint(x: 0.6, y: -0.55)

        /// The wing stroke: +1 wings spread, -1 wings down.
        static func stroke(_ t: Double) -> Double { cos(t * .pi * 2 * beats) }

        /// Which drawing shows as the crow comes in: beating, then a glide on
        /// spread wings, then wings down to land, then perched.
        static func frames(arrivingAt t: Double) -> (perched: Double, down: Double, out: Double) {
            if t >= fly {
                let p = smooth((t - fly) / 0.1)
                return (p, 1 - p, 0)
            }
            let u = max(t, 0) / fly
            var out = flap(stroke(t))
            out += (1 - out) * smooth((u - 0.55) / 0.12)     // into the glide
            out *= 1 - smooth((u - 0.84) / 0.1)               // wings down to land
            return (0, 1 - out, out)
        }

        /// Taking off: perched through the crouch, then beating hard.
        static func frames(leavingAt t: Double) -> (perched: Double, down: Double, out: Double) {
            if t < crouch { return (1, 0, 0) }
            let p = 1 - smooth((t - crouch) / 0.06)
            let out = flap(stroke(t - crouch))
            return (p, (1 - p) * (1 - out), (1 - p) * out)
        }

        /// The blend at each change of frame: two frames' worth, centred on
        /// the change, so the beat reads as motion rather than a flicker.
        static func flap(_ stroke: Double) -> Double { smooth((stroke + 0.28) / 0.56) }

        static func arriving(at t: Double, flies: Bool) -> LayerPose {
            if t >= arrive { return .rest }
            if t < fly {
                let u = t / fly
                // Fast in, slowing to the perch, along a curve that dips
                // under the straight line like a swoop.
                let e = IllustrationMotion.easeOut(u)
                let p = IllustrationMotion.curve(from: from, to: .zero, bend: CGPoint(x: 0.22, y: 0.08), at: e)
                let beating = 1 - smooth((u - 0.5) / 0.15)
                // The body rises as the wings come down, and sinks as they
                // lift: a quarter beat behind the stroke.
                let lift = -sin(t * .pi * 2 * beats) * 0.011 * beating
                // The brake: the body tips back over the last fifth.
                let brake = max(0, (u - 0.8) / 0.2)
                let tilt = -16 * (1 - e) + 14 * sin(brake * .pi / 2) * (1 - brake * 0.6)
                // Without the flying frames, the body squash stands in for wings.
                let squash = flies ? 0 : (stroke(t) + 1) * 0.5 * beating * 0.07
                return LayerPose(x: p.x, y: p.y + lift, scaleX: 1, scaleY: 1 - squash,
                                 rotation: tilt + 3 * sin(t * .pi * 2 * beats) * beating,
                                 opacity: min(1, t / 0.1), anchor: .center)
            }
            let s = t - fly
            let give = IllustrationMotion.springOut(s, frequency: 2.6, damping: 0.34) * 0.17
            let tilt = 14 * 0.4 * exp(-s * 9)
            return LayerPose(x: 0, y: 0, scaleX: 1 + give * 0.55, scaleY: 1 - give,
                             rotation: tilt, opacity: 1, anchor: .bottom)
        }

        static func leaving(at t: Double, flies: Bool) -> LayerPose {
            if t < crouch {
                let u = t / crouch
                let dip = sin(u * .pi / 2) * 0.12
                return LayerPose(x: 0, y: 0, scaleX: 1 + dip * 0.5, scaleY: 1 - dip,
                                 rotation: 0, opacity: 1, anchor: .bottom)
            }
            let u = min((t - crouch) / (away - crouch), 1)
            let e = IllustrationMotion.easeIn(u) * 0.7 + u * 0.3
            let p = IllustrationMotion.curve(from: .zero, to: CGPoint(x: -0.2, y: -0.65),
                                             bend: CGPoint(x: 0.28, y: -0.18), at: e)
            let release = 0.12 * exp(-(t - crouch) * 22)
            let lift = -sin((t - crouch) * .pi * 2 * beats) * 0.011
            let squash = flies ? 0 : (stroke(t - crouch) + 1) * 0.5 * 0.07
            return LayerPose(x: p.x, y: p.y + lift,
                             scaleX: 1 + release * 0.5, scaleY: 1 - squash - release,
                             rotation: 10 * e + 3 * sin((t - crouch) * .pi * 2 * beats),
                             opacity: 1 - max(0, (u - 0.85) / 0.15), anchor: .center)
        }

        /// Settled on the shoulder, the head cocks, as birds do: a tilt and
        /// back, then a smaller one the other way. `s` is seconds since the
        /// feet touched.
        static func headCock(at s: Double) -> Double {
            func ease(_ a: Double, _ b: Double, _ from: Double, _ to: Double) -> Double? {
                guard s >= a, s < b else { return nil }
                return from + (to - from) * smooth((s - a) / (b - a))
            }
            return ease(0.35, 0.6, 0, 11) ?? ease(0.6, 0.95, 11, 11) ?? ease(0.95, 1.25, 11, 0)
                ?? ease(1.25, 1.45, 0, -6) ?? ease(1.45, 1.7, -6, 0) ?? 0
        }

        static func smooth(_ x: Double) -> Double {
            let u = min(max(x, 0), 1)
            return u * u * (3 - 2 * u)
        }
    }

    // MARK: The cheer

    /// One hop, the way a body jumps: a crouch, a stretch on take-off, a
    /// gravity arc with its hang at the top, and a landing that squashes
    /// and springs. The cheer marks pop as the friends reach the top.
    private enum Cheer {
        static let crouch = 0.16
        static let air = 0.42
        static let land = 0.6
        static let total = crouch + air + land
        static let height = 0.09      // of the drawing's height

        static func friends(at t: Double) -> LayerPose {
            guard t > 0, t < total else { return .rest }
            if t < crouch {
                let u = t / crouch
                let dip = sin(u * .pi / 2) * 0.07
                return LayerPose(x: 0, y: 0, scaleX: 1 + dip * 0.5, scaleY: 1 - dip,
                                 rotation: 0, opacity: 1, anchor: .bottom)
            }
            if t < crouch + air {
                let u = (t - crouch) / air
                let lift = 4 * u * (1 - u) * height                 // a parabola: gravity
                // Stretched leaving the ground and arriving, round at the top.
                // (The crouch's 0.07 lets go over the first frames of the air.)
                let stretch = (1 - 4 * u * (1 - u)) * 0.06 - 0.13 * exp(-(t - crouch) * 20)
                return LayerPose(x: 0, y: -lift, scaleX: 1 - stretch * 0.5, scaleY: 1 + stretch,
                                 rotation: 0, opacity: 1, anchor: .bottom)
            }
            // Lands still stretched (0.06), and the stretch turns into the
            // squash and springs out: continuous with the last frame in the air.
            let s = t - crouch - air
            let y = 0.06 * IllustrationMotion.spring(s, frequency: 3.0, damping: 0.32)
                - 0.07 * IllustrationMotion.springOut(s, frequency: 3.0, damping: 0.32)
            return LayerPose(x: 0, y: 0, scaleX: 1 - y * 0.55, scaleY: 1 + y,
                             rotation: 0, opacity: 1, anchor: .bottom)
        }

        /// The marks: faint while the friends gather, then a springy pop at
        /// the top of the hop, settling as they land.
        static func marks(at t: Double) -> LayerPose {
            guard t > 0, t < total else { return .rest }
            let popAt = crouch + air * 0.35
            if t < popAt {
                let u = t / popAt
                return LayerPose(x: 0, y: 0, scaleX: 0.82, scaleY: 0.82,
                                 rotation: 0, opacity: 0.15 + 0.35 * u, anchor: .center)
            }
            let s = t - popAt
            let scale = 1 - 0.18 * IllustrationMotion.spring(s, frequency: 2.6, damping: 0.38)
            return LayerPose(x: 0, y: 0, scaleX: scale, scaleY: scale,
                             rotation: 0, opacity: min(1, 0.5 + s * 4), anchor: .center)
        }
    }

    // MARK: Curves

    static func easeOut(_ u: Double) -> Double { 1 - pow(1 - u, 3) }
    static func easeIn(_ u: Double) -> Double { u * u * u }
    static func easeOutBack(_ u: Double) -> Double {
        let c = 1.70158
        return 1 + (c + 1) * pow(u - 1, 3) + c * pow(u - 1, 2)
    }
    /// A damped spring released from 1 at t = 0, settling to 0: the give and
    /// wobble of a landing. `frequency` in wobbles a second, `damping` 0..1.
    static func spring(_ t: Double, frequency: Double, damping: Double) -> Double {
        let w = 2 * .pi * frequency
        return exp(-damping * w * t) * cos(w * sqrt(1 - damping * damping) * t)
    }
    /// The same spring set off from rest by a push: 0 at t = 0, out, back,
    /// settling to 0. What a landing's give looks like.
    static func springOut(_ t: Double, frequency: Double, damping: Double) -> Double {
        let w = 2 * .pi * frequency
        return exp(-damping * w * t) * sin(w * sqrt(1 - damping * damping) * t)
    }
    /// A quadratic curve through a control point bent off the straight line.
    static func curve(from a: CGPoint, to b: CGPoint, bend: CGPoint, at u: Double) -> CGPoint {
        let mid = CGPoint(x: (a.x + b.x) / 2 + bend.x, y: (a.y + b.y) / 2 + bend.y)
        let v = 1 - u
        return CGPoint(x: v * v * a.x + 2 * v * u * mid.x + u * u * b.x,
                       y: v * v * a.y + 2 * v * u * mid.y + u * u * b.y)
    }
}

/// Where a layer is at one instant, in fractions of the drawing's own size,
/// so it moves the same on every screen.
struct LayerPose: ViewModifier {
    var x: Double
    var y: Double
    var scaleX: Double
    var scaleY: Double
    var rotation: Double
    var opacity: Double
    var anchor: UnitPoint

    static let rest = LayerPose(x: 0, y: 0, scaleX: 1, scaleY: 1, rotation: 0, opacity: 1, anchor: .center)

    func body(content: Content) -> some View {
        let pose = self
        return content
            .visualEffect { view, proxy in
                view
                    .scaleEffect(x: pose.scaleX, y: pose.scaleY, anchor: pose.anchor)
                    .rotationEffect(.degrees(pose.rotation), anchor: pose.anchor)
                    .offset(x: pose.x * proxy.size.width, y: pose.y * proxy.size.height)
            }
            .opacity(pose.opacity)
    }
}
