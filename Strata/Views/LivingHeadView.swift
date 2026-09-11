import SwiftUI
import UIKit

/// A head, alive.
///
/// The portfolio's head is the reference (`hero-engine.js`) and its numbers
/// are used here: the 8fps blink, the saccade-and-fixation wander, the
/// micro-saccades, and its beats — the glance, the tilt, the brow, the
/// eyebrow flash, the People's Eyebrow, the side-eye, the eye roll, the
/// double take and the unimpressed slow blink. On top of that:
///
/// - **It never looks straight at you.** Between beats the eyes settle on a
///   point 45–90% of the way out from the middle, move on every second or so,
///   and never dead ahead (the portfolio's own rule: "idle wander never looks
///   dead-center"). Tiny micro-saccades keep them from locking still. A face
///   whose eyes rest on yours is a face that stares, and staring is what
///   makes a face creepy.
/// - **Faces morph rather than cut.** A smile fades in over the neutral face,
///   which is held at full opacity underneath the whole time — two layers
///   fading against each other composite to less than opaque (CLAUDE.md).
///   Brows are a hard swap, as in the portfolio, because a brow flash is
///   220ms and a fade would never arrive.
/// - **Irises survive a change of face**, drawn once over whichever face is
///   showing, gliding between their places on each.
/// - **Two levels of life.** `.calm` in chrome — a header button, a map
///   marker — glances, side-eyes and brow flashes, and nothing that moves the
///   head. `.expressive` where the head is the subject of the page — Profile's
///   picture, the maker's preview — everything, plus a slow float.
///
/// Reduce Motion holds it still, eyes resting to one side.
struct LivingHeadView: View {
    enum Liveliness { case calm, expressive }

    let rig: HeadRig
    /// The head's own height, crown to chin. Centred by its face, not its
    /// file, so every head — made or bundled — sits in the middle.
    let side: CGFloat
    var liveliness: Liveliness = .calm
    /// A brow flash and a smile when it first appears.
    var greets = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expression: HeadRig.Expression = .neutral
    /// The face being morphed away from, held opaque underneath.
    @State private var outgoing: HeadRig.Expression?
    @State private var incoming: Double = 1
    @State private var shut = false
    @State private var squash: CGFloat = 1
    /// Where the eyes rest between beats. Never the middle.
    @State private var rest = CGPoint(x: 0.55, y: 0.12)
    /// Fixational micro-saccades, added on top.
    @State private var micro: CGPoint = .zero
    /// Where a beat sends the eyes, and how much of the resting point is kept
    /// underneath it (a side-eye replaces it; a tilt keeps it).
    @State private var beatGaze: CGPoint = .zero
    @State private var restShare: CGFloat = 1
    @State private var yaw: Double = 0
    @State private var roll: Double = 0
    @State private var lean: CGFloat = 0
    @State private var dip: CGFloat = 0
    @State private var floatA = false
    @State private var floatB = false
    @State private var busy = false
    @State private var lastBeat: Beat?

    /// The portfolio's clock. A posterised snap reads as a blink; a fade reads
    /// as eyes slowly closing.
    private static let step: Duration = .milliseconds(125)
    /// Past about 20° a flat photograph stops reading as a head.
    private static let maxYaw: Double = 12

    var body: some View {
        let canvas = side / rig.contentHeight
        let centring = (0.5 - (rig.chin - rig.contentHeight / 2)) * canvas
        let floats = liveliness == .expressive && !reduceMotion
        ZStack {
            if let outgoing {
                artwork(outgoing)
            }
            artwork(expression)
                .opacity(incoming)
            irises(canvas: canvas)
        }
        .frame(width: canvas, height: canvas)
        .offset(y: centring)
        .scaleEffect(x: 1, y: squash, anchor: .bottom)
        .rotation3DEffect(.degrees(yaw), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
        .rotationEffect(.degrees(roll + (floats ? (floatA ? 0.6 : -0.6) : 0)), anchor: .bottom)
        .offset(x: lean + (floats ? (floatA ? 1 : -1) * side * 0.012 : 0),
                y: dip + (floats ? (floatB ? 1 : -1) * side * 0.01 : 0))
        .frame(width: side, height: side)
        .accessibilityHidden(true)
        .onAppear {
            guard floats else { return }
            // Two periods that never line up, so the drift never reads as a
            // metronome — the portfolio floats the same way.
            withAnimation(GridConstants.headFloatX) { floatA = true }
            withAnimation(GridConstants.headFloatY) { floatB = true }
        }
        .task(id: reduceMotion) { await blinkWhileIdle() }
        .task(id: reduceMotion) { await wanderWhileIdle() }
        .task(id: reduceMotion) { await microSaccades() }
        .task(id: reduceMotion) { await beatWhileIdle() }
    }

    // MARK: - Drawing

    private var gaze: CGPoint {
        CGPoint(x: min(max(rest.x * restShare + micro.x + beatGaze.x, -1), 1),
                y: min(max(rest.y * restShare + micro.y + beatGaze.y, -1), 1))
    }

    private func artwork(_ face: HeadRig.Expression) -> some View {
        let showsShut = shut && face == .neutral && rig.shut != nil
        return Image(uiImage: showsShut ? rig.shut! : rig.face(face).image)
            .resizable()
            .interpolation(.high)
    }

    /// A shut face has no iris. A drawn lid with a live iris sitting on it
    /// does not read as a blink; it reads as broken.
    private func irises(canvas: CGFloat) -> some View {
        let isShut = shut && expression == .neutral && rig.shut != nil
        let eyes = isShut ? [] : rig.face(expression).eyes
        let gaze = gaze
        return ZStack {
            ForEach(Array(eyes.enumerated()), id: \.offset) { _, eye in
                IrisLayer(eye: eye, canvas: canvas, gaze: gaze)
                    .transition(.opacity)
            }
        }
        .frame(width: canvas, height: canvas)
        .animation(GridConstants.motionSnappy, value: expression)
        .allowsHitTesting(false)
    }

    // MARK: - Eyes at rest

    /// The portfolio's saccade-and-fixation wander: a new resting point every
    /// 650–1800ms, 45–90% of the way out, flattened vertically. Calm heads
    /// wander more slowly.
    private func wanderWhileIdle() async {
        guard !reduceMotion else {
            rest = CGPoint(x: 0.5, y: 0.1)
            return
        }
        while !Task.isCancelled {
            let wait = liveliness == .expressive ? Int.random(in: 650...1800) : Int.random(in: 1500...4000)
            try? await Task.sleep(for: .milliseconds(wait))
            guard !Task.isCancelled else { return }
            guard restShare > 0.5 else { continue }
            let angle = Double.random(in: 0..<(2 * .pi))
            let radius = Double.random(in: 0.45...0.9)
            withAnimation(GridConstants.eyeSaccade) {
                rest = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius * 0.62 - 0.04)
            }
        }
    }

    /// The portfolio's micro-saccades: a tiny dart, a hold, another dart. Only
    /// where the head is big enough for them to be seen.
    private func microSaccades() async {
        guard !reduceMotion, liveliness == .expressive else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(Int.random(in: 340...1540)))
            guard !Task.isCancelled else { return }
            withAnimation(GridConstants.eyeSaccade) {
                micro = CGPoint(x: CGFloat.random(in: -0.12...0.12), y: CGFloat.random(in: -0.085...0.085))
            }
        }
    }

    // MARK: - Blinking

    private func blinkWhileIdle() async {
        guard !reduceMotion, rig.shut != nil else {
            shut = false
            return
        }
        while !Task.isCancelled {
            // People blink every three to five seconds, irregularly.
            try? await Task.sleep(for: .milliseconds(Int.random(in: 2600...5800)))
            guard !Task.isCancelled else { return }
            // The watchdog. No beat holds a face for more than about two
            // seconds, so a face other than neutral with no beat running is a
            // face that was left behind. Bring it home, irises and all.
            if !busy, expression != .neutral || outgoing != nil || shut {
                #if DEBUG
                NSLog("[strata-head] watchdog brought back a face left at \(expression) (outgoing \(String(describing: outgoing)), shut \(shut))")
                #endif
                settleImmediately()
                continue
            }
            guard !busy, expression == .neutral else { continue }
            await blink()
            // About one time in four, again straight after.
            if Double.random(in: 0..<1) < 0.24 {
                try? await Task.sleep(for: Self.step)
                await blink()
            }
        }
    }

    private func blink() async {
        shut = true
        if liveliness == .expressive { squash = CGFloat.random(in: 0.93...0.95) }
        try? await Task.sleep(for: Self.step * Int.random(in: 2...3))
        shut = false
        squash = 1
    }

    /// The unimpressed blink: the lids stay down for five steps.
    private func slowBlink() async {
        guard rig.shut != nil else { return }
        shut = true
        if liveliness == .expressive { squash = 0.9 }
        try? await Task.sleep(for: Self.step)
        if liveliness == .expressive { squash = 0.93 }
        try? await Task.sleep(for: Self.step * 4)
        shut = false
        squash = 1
    }

    // MARK: - Beats

    private enum Beat {
        case glance, tilt, brow, browFlash, peoplesEyebrow, sideEye, eyeRoll, doubleTake,
             slowBlink, smile, surprise, wink, turn
    }

    private func beatWhileIdle() async {
        // A clean face every time the loops start. They restart whenever
        // Reduce Motion changes, and a restart in the middle of a smile left
        // the face on the smile — which has no drawn irises — with nothing
        // left to bring it back. That is the class of bug behind the
        // portfolio's irises going missing and not returning.
        settleImmediately()
        guard !reduceMotion else { return }
        if greets {
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            await perform(.browFlash)
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await perform(.smile)
        }
        while !Task.isCancelled {
            // The portfolio's gap between beats: 4.5–11s. Calm heads wait longer.
            let rest = liveliness == .expressive
                ? Int.random(in: 3000...7500)
                : Int.random(in: 7000...14000)
            try? await Task.sleep(for: .milliseconds(rest))
            guard !Task.isCancelled else { return }
            guard !busy else { continue }
            await perform(nextBeat())
        }
    }

    /// Weighted, never the same beat twice running, and only beats this head
    /// has the faces for.
    private func nextBeat() -> Beat {
        let weights: [(Beat, Double)]
        switch liveliness {
        case .calm:
            weights = [(.glance, 0.4), (.sideEye, 0.3), (.browFlash, 0.3)]
        case .expressive:
            weights = [(.glance, 0.13), (.smile, 0.12), (.tilt, 0.09), (.brow, 0.09),
                       (.sideEye, 0.09), (.doubleTake, 0.08), (.surprise, 0.07), (.eyeRoll, 0.07),
                       (.peoplesEyebrow, 0.07), (.slowBlink, 0.07), (.browFlash, 0.05),
                       (.turn, 0.04), (.wink, 0.03)]
        }
        let pool = weights.filter { beat, _ in beat != lastBeat && canPerform(beat) }
        guard !pool.isEmpty else { return .glance }
        var roll = Double.random(in: 0..<pool.reduce(0) { $0 + $1.1 })
        for (beat, weight) in pool {
            if roll < weight { return beat }
            roll -= weight
        }
        return pool[0].0
    }

    private func canPerform(_ beat: Beat) -> Bool {
        switch beat {
        case .smile:                                     return rig.has(.smile)
        case .surprise:                                  return rig.has(.surprised)
        case .wink:                                      return rig.has(.wink)
        case .brow, .browFlash, .peoplesEyebrow, .doubleTake: return rig.has(.browsUp)
        case .slowBlink:                                 return rig.shut != nil
        default:                                         return true
        }
    }

    private func perform(_ beat: Beat) async {
        busy = true
        lastBeat = beat
        let dir: CGFloat = Bool.random() ? 1 : -1
        switch beat {
        case .glance:
            // A curious look to one side and back.
            look(CGPoint(x: dir * 0.75, y: -0.1))
            pose(roll: Double(dir) * 1.1)
            await pause(800)
            release()
            pose()
            await pause(350)
        case .tilt:
            // A slight tilt of the head; the eyes keep resting where they were.
            pose(roll: Double(dir) * 3)
            await pause(1100)
            pose()
            await pause(400)
        case .brow:
            // Brows up through the middle of the beat, eyes lifting a touch.
            look(CGPoint(x: 0, y: -0.15), keepingRest: true)
            await pause(230)
            swap(to: .browsUp)
            await pause(480)
            swap(to: .neutral)
            release()
            await pause(230)
        case .browFlash:
            // Eibl-Eibesfeldt's greeting: a ~220ms brow raise.
            swap(to: .browsUp)
            await pause(220)
            swap(to: .neutral)
        case .peoplesEyebrow:
            // The head cocks, the brows go up — and the eyes look off to the
            // side rather than holding a level stare.
            pose(roll: Double(dir) * 4.6, dip: side * 0.02)
            await pause(240)
            swap(to: .browsUp)
            look(CGPoint(x: -dir * 0.55, y: 0.05))
            await pause(1290)
            swap(to: .neutral)
            release()
            pose()
            await pause(170)
        case .sideEye:
            // Deadpan: the eyes dart, the head does not move. That's the joke.
            look(CGPoint(x: dir * 0.9, y: 0.05))
            await pause(1050)
            release()
            await pause(270)
        case .eyeRoll:
            // A full arc over the top, the head tipping with it.
            for index in 0...8 {
                let angle = Double(index) / 8 * .pi
                look(CGPoint(x: cos(angle) * -0.8 * Double(dir), y: -sin(angle) * 0.95))
                pose(roll: sin(angle) * 2.2 * Double(dir))
                await pause(125)
            }
            release()
            pose()
            // Sometimes amused with itself afterwards.
            if rig.has(.smile), Double.random(in: 0..<1) < 0.4 {
                await pause(150)
                await morph(to: .smile)
                await pause(700)
                await settleThroughBlink()
            }
        case .doubleTake:
            // Drift away, SNAP back, brows up.
            withAnimation(GridConstants.naturalSettle) {
                beatGaze = CGPoint(x: dir * 0.8, y: 0)
                restShare = 0
            }
            pose(roll: Double(dir) * 1.6)
            await pause(570)
            withAnimation(GridConstants.tapPopSpring) {
                beatGaze = CGPoint(x: -dir * 0.35, y: -0.05)
            }
            pose()
            await pause(110)
            swap(to: .browsUp)
            await pause(560)
            swap(to: .neutral)
            release()
        case .slowBlink:
            // Unimpressed: eyes drop a touch, the lids come down slowly.
            look(CGPoint(x: 0, y: 0.25), keepingRest: true)
            await pause(420)
            await slowBlink()
            await pause(300)
            release()
        case .smile:
            await morph(to: .smile)
            pose(roll: Double(dir) * 2)
            await pause(Int.random(in: 1300...2000))
            pose()
            await settleThroughBlink()
        case .surprise:
            // Something caught its eye: a little lift of the head, the
            // surprised face, eyes off to one side — then back through a blink.
            look(CGPoint(x: dir * 0.6, y: -0.2))
            pose(roll: Double(dir) * -1.5, dip: -side * 0.02)
            await morph(to: .surprised)
            await pause(Int.random(in: 700...1000))
            pose()
            await settleThroughBlink()
            release()
        case .wink:
            pose(roll: Double(dir) * 4)
            await morph(to: .wink)
            await pause(650)
            pose()
            await morph(to: .neutral)
        case .turn:
            // Eyes first, a blink half the time, then the head.
            look(CGPoint(x: dir, y: -0.1))
            await pause(90)
            if rig.shut != nil, Double.random(in: 0..<1) < 0.5 {
                Task { await blink() }
            }
            pose(yaw: Double(dir) * Self.maxYaw, roll: Double(dir) * 2, lean: dir * side * 0.03)
            await pause(350)
            look(CGPoint(x: dir * 0.4, y: -0.05))
            await pause(Int.random(in: 1000...1600))
            release()
            await pause(90)
            pose()
            await pause(450)
        }
        busy = false
    }

    // MARK: - Faces

    /// Neutral, open, unposed, with nothing left over from a beat.
    private func settleImmediately() {
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            outgoing = nil
            incoming = 1
            expression = .neutral
            shut = false
            squash = 1
            beatGaze = .zero
            restShare = 1
            yaw = 0
            roll = 0
            lean = 0
            dip = 0
            busy = false
        }
    }

    /// A hard swap, for brows: the portfolio swaps its brow picture outright,
    /// and a 220ms flash with a fade on it would never be seen.
    private func swap(to next: HeadRig.Expression) {
        guard next == .neutral || rig.has(next) else { return }
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            outgoing = nil
            incoming = 1
            expression = next
        }
    }

    /// The new face fades in over the old one, which stays solid underneath
    /// until it is covered; a slight squash sells it as one head moving.
    private func morph(to next: HeadRig.Expression) async {
        guard next != expression, next == .neutral || rig.has(next) else { return }
        guard !reduceMotion else {
            expression = next
            return
        }
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            outgoing = expression
            incoming = 0
        }
        expression = next
        withAnimation(GridConstants.headMorph) { incoming = 1 }
        if liveliness == .expressive {
            withAnimation(GridConstants.tapSquashSpring) { squash = 0.975 }
        }
        try? await Task.sleep(for: .milliseconds(160))
        withAnimation(GridConstants.naturalSettle) { squash = 1 }
        withTransaction(instant) { outgoing = nil }
    }

    /// Back to neutral behind a blink — the lids close on the smile and open
    /// on the neutral face, so the change itself is never seen.
    private func settleThroughBlink() async {
        guard rig.shut != nil, !reduceMotion else {
            await morph(to: .neutral)
            return
        }
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            outgoing = nil
            incoming = 1
            expression = .neutral
            shut = true
        }
        if liveliness == .expressive { squash = 0.94 }
        try? await Task.sleep(for: Self.step * 2)
        shut = false
        squash = 1
    }

    // MARK: - Movement

    /// Sends the eyes somewhere for a beat. Saccades are the fastest movement
    /// a body makes, so the eyes land before the head has started.
    private func look(_ point: CGPoint, keepingRest: Bool = false) {
        withAnimation(GridConstants.eyeSaccade) {
            beatGaze = point
            restShare = keepingRest ? 1 : 0
        }
    }

    /// Hands the eyes back to their resting point.
    private func release() {
        withAnimation(GridConstants.eyeSaccade) {
            beatGaze = .zero
            restShare = 1
        }
    }

    private func pose(yaw y: Double = 0, roll r: Double = 0, lean l: CGFloat = 0, dip d: CGFloat = 0) {
        guard liveliness == .expressive else { return }
        withAnimation(GridConstants.headTurn) {
            yaw = y
            roll = r
            lean = l
            dip = d
        }
    }

    private func pause(_ milliseconds: Int) async {
        try? await Task.sleep(for: .milliseconds(milliseconds))
    }
}

// MARK: - Eyes

/// One iris, placed in its eye and clipped to the lids.
private struct IrisLayer: View {
    let eye: HeadRig.Eye
    let canvas: CGFloat
    let gaze: CGPoint

    var body: some View {
        let width = eye.rx * 2 * canvas
        let height = eye.ry * 2 * canvas
        // The portfolio's faces were calibrated with a narrow ellipse and a
        // 0.6 iris. A measured opening runs corner to corner: an iris is about
        // half of that, and never shorter than the opening is tall, so the
        // lids overlap it top and bottom the way real ones do. At a flat half
        // it looked small on every face whose contour ran wide (measured on
        // thirteen faces).
        let diameter = eye.outline == nil
            ? width * 0.6
            : min(max(width * 0.5, height * 1.25), width * 0.62)
        let along = gaze.x * max((width - diameter) / 2, 0) * 0.8
        let across = gaze.y * height * 0.2
        let cosine = CGFloat(cos(eye.angle)), sine = CGFloat(sin(eye.angle))
        let centre = CGPoint(x: eye.x * canvas + along * cosine - across * sine,
                             y: eye.y * canvas + along * sine + across * cosine)
        IrisDisc(colour: eye.iris, diameter: diameter)
            .position(centre)
            .frame(width: canvas, height: canvas)
            .clipShape(EyeOpening(eye: eye))
    }
}

/// An iris, its pupil, and a catchlight that stays where the light is.
private struct IrisDisc: View {
    let colour: HeadRig.RGB?
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(EllipticalGradient(stops: stops, center: .center,
                                         startRadiusFraction: 0, endRadiusFraction: 0.5))
            Circle()
                .fill(Color.black)
                .frame(width: diameter * 0.46, height: diameter * 0.46)
            Circle()
                .fill(EllipticalGradient(colors: [.white.opacity(0.95), .white.opacity(0)],
                                         center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5))
                .frame(width: diameter * 0.3, height: diameter * 0.3)
                .offset(x: -diameter * 0.16, y: -diameter * 0.18)
        }
        .frame(width: diameter, height: diameter)
    }

    /// The portfolio's iris (`index.html`, `.iris`) when there is no colour to
    /// go on; otherwise the person's own, deepened at the pupil and the rim.
    private var stops: [Gradient.Stop] {
        guard let colour else {
            return [
                .init(color: Color(white: 0.02), location: 0),
                .init(color: Color(white: 0.03), location: 0.25),
                .init(color: Color(white: 0.10), location: 0.39),
                .init(color: Color(red: 0.035, green: 0.043, blue: 0.141), location: 0.57),
                .init(color: Color(white: 0.09), location: 0.72),
                .init(color: Color(white: 0.04), location: 0.88),
                .init(color: Color(white: 0.01), location: 1)
            ]
        }
        let deep = colour.scaled(0.45).color, mid = colour.scaled(0.9).color
        return [
            .init(color: deep, location: 0),
            .init(color: deep, location: 0.3),
            .init(color: mid, location: 0.62),
            .init(color: deep, location: 0.88),
            .init(color: Color(white: 0.02), location: 1)
        ]
    }
}

/// The eye's opening: its measured outline, or an ellipse for a face that was
/// calibrated as one.
private struct EyeOpening: Shape {
    let eye: HeadRig.Eye

    func path(in rect: CGRect) -> Path {
        if let outline = eye.outline, outline.count >= 3 {
            var path = Path()
            path.addLines(outline.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) })
            path.closeSubpath()
            return path
        }
        let rx = eye.rx * rect.width, ry = eye.ry * rect.height
        let centre = CGPoint(x: rect.minX + eye.x * rect.width, y: rect.minY + eye.y * rect.height)
        return Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
            .applying(CGAffineTransform(rotationAngle: eye.angle)
                .concatenating(CGAffineTransform(translationX: centre.x, y: centre.y)))
    }
}

// MARK: - Still

/// A head, still: neutral, eyes open and resting a little to one side, never
/// straight ahead. What a photograph gets when your head is added to it — a
/// picture cannot blink, and a sticker caught mid-blink or mid-grin is not the
/// face anybody chose.
///
/// Framed to its whole canvas, hair and all, so rendering it does not crop the
/// crown.
struct HeadStill: View {
    let rig: HeadRig
    /// The head's own height, crown to chin.
    let side: CGFloat

    static let gaze = CGPoint(x: 0.35, y: 0.08)

    var body: some View {
        let canvas = side / rig.contentHeight
        let centring = (0.5 - (rig.chin - rig.contentHeight / 2)) * canvas
        let face = rig.face(.neutral)
        ZStack {
            Image(uiImage: face.image)
                .resizable()
                .interpolation(.high)
            ZStack {
                ForEach(Array(face.eyes.enumerated()), id: \.offset) { _, eye in
                    IrisLayer(eye: eye, canvas: canvas, gaze: Self.gaze)
                }
            }
            .frame(width: canvas, height: canvas)
        }
        .frame(width: canvas, height: canvas)
        .offset(y: centring)
        .frame(width: canvas, height: canvas)
    }
}
