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
/// - **Faces morph rather than cut.** The old face fades out over the new
///   one, which is at full opacity underneath the whole time: two layers
///   fading against each other composite to less than opaque (CLAUDE.md).
///   It used to be the other way up, the new face fading in over the old,
///   and when the old layer went before the fade had drawn (the main thread
///   late, measured in the simulator) the head vanished and left an iris
///   floating in the picture. With the opaque layer underneath, a late fade
///   can only ever show the old face a moment too long.
///   Brows are a hard swap, as in the portfolio, because a brow flash is
///   220ms and a fade would never arrive.
/// - **Each face carries its own irises**, so they cross-fade with it. They
///   used to be one layer over whichever face showed, gliding between faces,
///   and that layer could outlive the fade: an iris left on a wink's shut lid.
///   Across a creator's or a made head's faces the eyes sit within about a
///   hundredth of the canvas of each other, so there was little to glide.
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
    /// **A face to wear and keep.** Nil is the normal head, which lives on its
    /// own: idles, blinks and plays its beats. Set, it morphs there and stays,
    /// because something outside has chosen that face — tapping the sticker on
    /// a photograph, where what you are looking at is what gets saved into the
    /// picture.
    var held: HeadRig.Expression?
    /// **A take to play now** (`HeadTake`): a tap's expression. A new nonce
    /// plays it and interrupts whatever is playing, so a second tap switches
    /// at once.
    var take: HeadTake.Played? = nil
    /// Keep the take's face when its hold ends, rather than going back to
    /// calm. The sticker: what is on the review is what is saved.
    var keepsTake = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expression: HeadRig.Expression = .neutral
    /// The face being morphed away from, fading out on top of the new one.
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
    /// A take is playing. Idle beats and the watchdog stand aside.
    @State private var taking = false
    /// Bumped by every take, so a beat or take that has been overtaken knows
    /// to stop rather than finish on top of the new one.
    @State private var generation = 0
    /// Bumped by every morph, so a superseded morph does not clear the layer
    /// a newer one is fading over.
    @State private var morphToken = 0
    /// `held`, as state. **The idle loops must read this, not `held`**: they
    /// are long-running tasks, and a task reads the view value it started
    /// with, so `held` in there stays nil for ever. Measured on the review:
    /// the watchdog took a kept grin back to neutral a moment after the sticker
    /// was told to keep it, while the photo would have saved the grin.
    @State private var heldFace: HeadRig.Expression?
    /// The last take actually played. A view that goes away and comes back
    /// keeps its state, and `.task(id:)` runs again on the same take: without
    /// this it would replay a tap nobody made.
    @State private var lastPlayed: HeadTake.Played?
    /// A kept take has left the eyes somewhere (`HeadTake.stillGaze`), which is
    /// what its photograph shows. Idle beats and the wander leave them there.
    @State private var gazeHeld = false
    #if DEBUG
    /// `-strataHeadTake`: takes played without a finger, for screenshots.
    @State private var debugPlayed: HeadTake.Played?
    #endif

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
            artwork(expression)
            irises(of: expression, canvas: canvas)
            // Each face carries its own irises, so the old face's go with it:
            // a single iris layer on top outlived the fade in the simulator and
            // left an iris sitting on a wink's shut lid.
            if let outgoing {
                ZStack {
                    artwork(outgoing)
                    irises(of: outgoing, canvas: canvas)
                }
                .opacity(1 - incoming)
            }
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
        .task(id: held) {
            heldFace = held
            // A head playing takes wears the faces its takes give it.
            guard take == nil else { return }
            await wear(held)
        }
        .task(id: playing) { await play(playing) }
        #if DEBUG
        .task { await debugTakes() }
        #endif
    }

    private var playing: HeadTake.Played? {
        #if DEBUG
        return take ?? debugPlayed
        #else
        return take
        #endif
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
    private func irises(of face: HeadRig.Expression, canvas: CGFloat) -> some View {
        let isShut = shut && face == .neutral && rig.shut != nil
        let eyes = isShut ? [] : rig.face(face).eyes
        let gaze = gaze
        return ZStack {
            ForEach(Array(eyes.enumerated()), id: \.offset) { _, eye in
                IrisLayer(eye: eye, canvas: canvas, gaze: gaze)
            }
        }
        .frame(width: canvas, height: canvas)
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
            guard restShare > 0.5, !gazeHeld else { continue }
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
            // The watchdog. No idle beat holds a face for more than about two
            // seconds and a take marks itself, so a face other than neutral
            // with nothing running is a face that was left behind. Bring it home, irises and all.
            if !busy, !taking, heldFace == nil, expression != .neutral || outgoing != nil || shut {
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
        let mine = generation
        shut = true
        if liveliness == .expressive { squash = CGFloat.random(in: 0.93...0.95) }
        try? await Task.sleep(for: Self.step * Int.random(in: 2...3))
        // A take that started while the lids were down owns them now.
        guard generation == mine, !Task.isCancelled else { return }
        shut = false
        squash = 1
    }

    /// The unimpressed blink: the lids stay down for five steps.
    private func slowBlink() async {
        guard rig.shut != nil else { return }
        let mine = generation
        shut = true
        if liveliness == .expressive { squash = 0.9 }
        try? await Task.sleep(for: Self.step)
        guard generation == mine, !Task.isCancelled else { return }
        if liveliness == .expressive { squash = 0.93 }
        try? await Task.sleep(for: Self.step * 4)
        guard generation == mine, !Task.isCancelled else { return }
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
        // Not over a take: a tap in the first moment of a page starts one, and
        // this loop restarts whenever Reduce Motion changes.
        if !taking { settleImmediately() }
        guard !reduceMotion else { return }
        if greets {
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            guard !taking else {
                #if DEBUG
                NSLog("[strata-head] greeting stood aside for a take")
                #endif
                return
            }
            await perform(.browFlash)
            try? await Task.sleep(for: .milliseconds(250))
            // **A tap wins over the hello.** The greeting used to carry on
            // through a take: it read the take's generation as its own, put its
            // own faces on over it and cleared `busy` mid-take.
            guard !Task.isCancelled else { return }
            guard !taking else {
                #if DEBUG
                NSLog("[strata-head] greeting stood aside for a take")
                #endif
                return
            }
            await perform(.smile)
        }
        while !Task.isCancelled {
            // The portfolio's gap between beats: 4.5–11s. Calm heads wait longer.
            let rest = liveliness == .expressive
                ? Int.random(in: 3000...7500)
                : Int.random(in: 7000...14000)
            try? await Task.sleep(for: .milliseconds(rest))
            guard !Task.isCancelled else { return }
            // A head that has been told which face to wear is not idle.
            // A head wearing a kept face, or looking where a kept take left
            // it, is not idle: a beat would undo what its photograph shows.
            guard !busy, !taking, heldFace == nil, !gazeHeld else { continue }
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
        // A tap's take overtakes a beat: no beat starts over one, every pause
        // checks it is still this beat's turn, and a beat that was overtaken
        // leaves `busy` to the take.
        guard !taking else { return }
        let mine = generation
        busy = true
        lastBeat = beat
        let dir: CGFloat = Bool.random() ? 1 : -1
        switch beat {
        case .glance:
            // A curious look to one side and back.
            look(CGPoint(x: dir * 0.75, y: -0.1))
            pose(roll: Double(dir) * 1.1)
            guard await beatPause(800, mine) else { return }
            release()
            pose()
            guard await beatPause(350, mine) else { return }
        case .tilt:
            // A slight tilt of the head; the eyes keep resting where they were.
            pose(roll: Double(dir) * 3)
            guard await beatPause(1100, mine) else { return }
            pose()
            guard await beatPause(400, mine) else { return }
        case .brow:
            // Brows up through the middle of the beat, eyes lifting a touch.
            look(CGPoint(x: 0, y: -0.15), keepingRest: true)
            guard await beatPause(230, mine) else { return }
            swap(to: .browsUp)
            guard await beatPause(480, mine) else { return }
            swap(to: .neutral)
            release()
            guard await beatPause(230, mine) else { return }
        case .browFlash:
            // Eibl-Eibesfeldt's greeting: a ~220ms brow raise.
            swap(to: .browsUp)
            guard await beatPause(220, mine) else { return }
            swap(to: .neutral)
        case .peoplesEyebrow:
            // The head cocks, the brows go up — and the eyes look off to the
            // side rather than holding a level stare.
            pose(roll: Double(dir) * 4.6, dip: side * 0.02)
            guard await beatPause(240, mine) else { return }
            swap(to: .browsUp)
            look(CGPoint(x: -dir * 0.55, y: 0.05))
            guard await beatPause(1290, mine) else { return }
            swap(to: .neutral)
            release()
            pose()
            guard await beatPause(170, mine) else { return }
        case .sideEye:
            // Deadpan: the eyes dart, the head does not move. That's the joke.
            look(CGPoint(x: dir * 0.9, y: 0.05))
            guard await beatPause(1050, mine) else { return }
            release()
            guard await beatPause(270, mine) else { return }
        case .eyeRoll:
            // A full arc over the top, the head tipping with it.
            for index in 0...8 {
                let angle = Double(index) / 8 * .pi
                look(CGPoint(x: cos(angle) * -0.8 * Double(dir), y: -sin(angle) * 0.95))
                pose(roll: sin(angle) * 2.2 * Double(dir))
                guard await beatPause(125, mine) else { return }
            }
            release()
            pose()
            // Sometimes amused with itself afterwards.
            if rig.has(.smile), Double.random(in: 0..<1) < 0.4 {
                guard await beatPause(150, mine) else { return }
                await morph(to: .smile)
                guard generation == mine, !Task.isCancelled else { return }
                guard await beatPause(700, mine) else { return }
                await settleThroughBlink()
                guard generation == mine, !Task.isCancelled else { return }
            }
        case .doubleTake:
            // Drift away, SNAP back, brows up.
            withAnimation(GridConstants.naturalSettle) {
                beatGaze = CGPoint(x: dir * 0.8, y: 0)
                restShare = 0
            }
            pose(roll: Double(dir) * 1.6)
            guard await beatPause(570, mine) else { return }
            withAnimation(GridConstants.tapPopSpring) {
                beatGaze = CGPoint(x: -dir * 0.35, y: -0.05)
            }
            pose()
            guard await beatPause(110, mine) else { return }
            swap(to: .browsUp)
            guard await beatPause(560, mine) else { return }
            swap(to: .neutral)
            release()
        case .slowBlink:
            // Unimpressed: eyes drop a touch, the lids come down slowly.
            look(CGPoint(x: 0, y: 0.25), keepingRest: true)
            guard await beatPause(420, mine) else { return }
            await slowBlink()
            guard generation == mine, !Task.isCancelled else { return }
            guard await beatPause(300, mine) else { return }
            release()
        case .smile:
            await morph(to: .smile)
            guard generation == mine, !Task.isCancelled else { return }
            pose(roll: Double(dir) * 2)
            guard await beatPause(Int.random(in: 1300...2000), mine) else { return }
            pose()
            await settleThroughBlink()
            guard generation == mine, !Task.isCancelled else { return }
        case .surprise:
            // Something caught its eye: a little lift of the head, the
            // surprised face, eyes off to one side — then back through a blink.
            look(CGPoint(x: dir * 0.6, y: -0.2))
            pose(roll: Double(dir) * -1.5, dip: -side * 0.02)
            await morph(to: .surprised)
            guard generation == mine, !Task.isCancelled else { return }
            guard await beatPause(Int.random(in: 700...1000), mine) else { return }
            pose()
            await settleThroughBlink()
            guard generation == mine, !Task.isCancelled else { return }
            release()
        case .wink:
            pose(roll: Double(dir) * 4)
            await morph(to: .wink)
            guard generation == mine, !Task.isCancelled else { return }
            guard await beatPause(650, mine) else { return }
            pose()
            await morph(to: .neutral)
            guard generation == mine, !Task.isCancelled else { return }
        case .turn:
            // Eyes first, a blink half the time, then the head.
            look(CGPoint(x: dir, y: -0.1))
            guard await beatPause(90, mine) else { return }
            if rig.shut != nil, Double.random(in: 0..<1) < 0.5 {
                Task { await blink() }
            }
            pose(yaw: Double(dir) * Self.maxYaw, roll: Double(dir) * 2, lean: dir * side * 0.03)
            guard await beatPause(350, mine) else { return }
            look(CGPoint(x: dir * 0.4, y: -0.05))
            guard await beatPause(Int.random(in: 1000...1600), mine) else { return }
            release()
            guard await beatPause(90, mine) else { return }
            pose()
            guard await beatPause(450, mine) else { return }
        }
        if generation == mine { busy = false }
    }

    // MARK: - Takes

    /// **Plays a tap's expression** (`HeadTake`) to the end of its hold, then
    /// eases back to calm, or keeps its face under `keepsTake`.
    ///
    /// Run from `.task(id:)`, so a new take cancels this one, and every sleep
    /// here THROWS: an interrupted take stops dead. A swallowed cancellation
    /// would run the rest of the old take on top of the new one.
    private func play(_ played: HeadTake.Played?) async {
        guard let played, played != lastPlayed else { return }
        lastPlayed = played
        let take = HeadTake.take(played.id)
        generation &+= 1
        taking = true
        busy = true
        gazeHeld = false
        let start = ContinuousClock.now
        var instant = Transaction()
        instant.disablesAnimations = true
        // Whatever the last take or beat left on the lids goes. Its face and
        // pose are animated over by this one.
        withTransaction(instant) {
            shut = false
            squash = 1
        }
        #if DEBUG
        NSLog("[strata-head] play \(take.id.rawValue) dir \(played.direction) hold \(take.hold)")
        #endif
        if reduceMotion {
            // Reduce Motion: the face, and nothing that moves.
            swap(to: rig.has(take.face) ? take.face : .neutral)
            do { try await Task.sleep(until: start + .seconds(take.hold), clock: .continuous) } catch {
                finishTake(played)
                return
            }
            if !keepsTake { swap(to: .neutral) }
            finishTake(played)
            return
        }
        release()
        pose(invited: true)
        // A take that does not open on a face starts from calm: a gaze cue on
        // a kept grin, whose eyes are the photograph's own, would do nothing.
        let opensOnFace = take.cues.contains { cue in
            if case .face = cue.step { return cue.at <= 0.1 }
            return false
        }
        if !opensOnFace, expression != .neutral, let token = beginMorph(to: .neutral, squashes: false) {
            scheduleEndMorph(token)
        }
        // The whole take, ease-back included, is `HeadTake.schedule`, so the
        // timing the tests read is the timing that runs here.
        for moment in take.schedule(direction: played.direction) {
            do { try await Task.sleep(until: start + .seconds(moment.at), clock: .continuous) } catch {
                // Cancelled: by a newer take, which owns everything now, or by
                // the view going away, which must not leave `taking` set.
                finishTake(played)
                return
            }
            switch moment.event {
            case let .cue(step):
                apply(step)
            case .easeBack:
                await easeBack(take, direction: played.direction)
            }
        }
        guard !Task.isCancelled else {
            finishTake(played)
            return
        }
        finishTake(played)
    }

    /// The end of a take's hold: the head goes back to calm, and the face with
    /// it unless the sticker is keeping it. A kept take also keeps the eyes
    /// where it left them, because that is what its photograph shows.
    private func easeBack(_ take: HeadTake, direction: Double) async {
        if keepsTake, let gaze = take.stillGaze(direction: direction) {
            gazeHeld = true
            withAnimation(GridConstants.eyeSaccade) {
                beatGaze = gaze
                restShare = 0
            }
        } else {
            release()
        }
        pose(invited: true, animation: GridConstants.headTakeEaseBack)
        withAnimation(GridConstants.naturalSettle) { squash = 1 }
        shut = false
        if keepsTake {
            // What it ends on is what the sticker saves (`HeadTake.endFace`).
            let end = take.endFace(has: rig.has)
            if expression != end { await morph(to: end) }
        } else if expression == .wink {
            await morph(to: .neutral)
        } else if expression != .neutral {
            await settleThroughBlink()
        }
    }

    /// This take is over. **Keyed on the take, not on `generation`.** A second
    /// tap sets `lastPlayed` and cancels this task before its own `play` has
    /// bumped `generation`, so a generation check let the cancelled take clear
    /// `taking` and `busy` for a hop, and an idle beat could start in the gap.
    private func finishTake(_ played: HeadTake.Played) {
        guard lastPlayed == played else { return }
        taking = false
        busy = false
    }

    /// One cue of a take. Nothing here waits, so a cue never delays the next.
    private func apply(_ step: HeadTake.Step) {
        switch step {
        case let .face(next):
            if next == .browsUp || (next == .neutral && expression == .browsUp) {
                // Brows are a hard swap, as in the idle beats.
                swap(to: next)
            } else if let token = beginMorph(to: next) {
                scheduleEndMorph(token)
            }
        case let .look(x, y, keepsRest, speed):
            let animation: Animation
            switch speed {
            case .saccade: animation = GridConstants.eyeSaccade
            case .drift: animation = GridConstants.naturalSettle
            case .snap: animation = GridConstants.tapPopSpring
            }
            withAnimation(animation) {
                beatGaze = CGPoint(x: x, y: y)
                restShare = keepsRest ? 1 : 0
            }
        case .release:
            release()
        case let .pose(yaw, roll, lean, dip, motion):
            let animation: Animation
            switch motion {
            case .turn: animation = GridConstants.headTurn
            case .nod: animation = GridConstants.headNod
            case .droop: animation = GridConstants.headTakeEaseBack
            }
            pose(yaw: min(max(yaw, -Self.maxYaw), Self.maxYaw), roll: roll,
                 lean: CGFloat(lean) * side, dip: CGFloat(dip) * side,
                 invited: true, animation: animation)
        case let .lids(closed):
            guard rig.shut != nil else { return }
            shut = closed
            squash = closed ? 0.94 : 1
        case .bounce:
            withAnimation(GridConstants.tapSquashSpring) { squash = 0.975 }
            let mine = generation
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(160))
                guard generation == mine else { return }
                withAnimation(GridConstants.naturalSettle) { squash = 1 }
            }
        }
    }

    private func scheduleEndMorph(_ token: Int) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(160))
            endMorph(token)
        }
    }

    #if DEBUG
    /// `-strataHeadTake cycle|grin|laugh|...`: plays this head's takes in
    /// catalogue order (or the one named) on an expressive head, each logged
    /// as `[strata-head] take <id>`, so every one can be photographed at its
    /// hold without a finger. The sticker drives its own (`HeadStickerOverlay`).
    private func debugTakes() async {
        guard let wanted = DebugHarness.headTake, liveliness == .expressive, take == nil else { return }
        try? await Task.sleep(for: .seconds(DebugHarness.headTakeDelay))
        var nonce = 0
        while !Task.isCancelled {
            let pool = HeadTake.available(faces: rig.takeFaces, hasShut: rig.shut != nil, reduceMotion: reduceMotion)
            let list = wanted == "cycle" ? pool : pool.filter { $0.id.rawValue.lowercased() == wanted }
            guard !list.isEmpty else { return }
            for next in list {
                nonce += 1
                debugPlayed = HeadTake.Played(id: next.id, direction: nonce % 2 == 0 ? -1 : 1, nonce: nonce)
                NSLog("[strata-head] take \(next.id.rawValue) hold \(next.hold)")
                try? await Task.sleep(for: .seconds(next.hold + 1.2))
                guard !Task.isCancelled else { return }
            }
        }
    }
    #endif

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
            // A kept take's gaze goes too, or the wander and the beats stay
            // switched off for the life of a sticker whose take was
            // interrupted by Reduce Motion changing.
            gazeHeld = false
        }
    }

    /// Puts on the face it has been given, or takes it off again.
    private func wear(_ face: HeadRig.Expression?) async {
        guard let face else {
            // Only undo a held face. On first appearance there is nothing to
            // undo, and morphing to neutral here would cut a greeting short.
            if expression != .neutral { await morph(to: .neutral) }
            return
        }
        await morph(to: face)
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

    /// The old face fades out over the new one, which is solid underneath
    /// from the start; a slight squash sells it as one head moving.
    private func morph(to next: HeadRig.Expression) async {
        guard let token = beginMorph(to: next) else { return }
        try? await Task.sleep(for: .milliseconds(160))
        endMorph(token)
    }

    /// The first half of a morph: the new face starts fading in. Nil when
    /// there is nothing to fade (same face, a face this head lacks, or Reduce
    /// Motion, which changes it outright).
    private func beginMorph(to next: HeadRig.Expression, squashes: Bool = true) -> Int? {
        guard next != expression, next == .neutral || rig.has(next) else { return nil }
        guard !reduceMotion else {
            expression = next
            return nil
        }
        morphToken &+= 1
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            outgoing = expression
            incoming = 0
        }
        expression = next
        let token = morphToken
        // The old face's layer goes when its fade has finished, not on a
        // timer, so it never cuts off part way through.
        withAnimation(GridConstants.headMorph, completionCriteria: .logicallyComplete) {
            incoming = 1
        } completion: {
            guard token == morphToken else { return }
            withTransaction(instant) { outgoing = nil }
        }
        if liveliness == .expressive, squashes {
            withAnimation(GridConstants.tapSquashSpring) { squash = 0.975 }
        }
        return token
    }

    /// The second half: the squash settles. (The old face underneath is
    /// taken away by the fade's own completion.) A morph overtaken by a newer
    /// one leaves that one alone.
    private func endMorph(_ token: Int) {
        guard token == morphToken else { return }
        withAnimation(GridConstants.naturalSettle) { squash = 1 }
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
        let mine = generation
        if liveliness == .expressive { squash = 0.94 }
        try? await Task.sleep(for: Self.step * 2)
        // Overtaken by a new take, which has already opened the eyes on
        // its own face: leave it alone.
        guard generation == mine, !Task.isCancelled else { return }
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

    /// Moves the head. Only an expressive head moves on its own; a calm one
    /// in chrome moves only when it is `invited` to, by a tap.
    private func pose(yaw y: Double = 0, roll r: Double = 0, lean l: CGFloat = 0, dip d: CGFloat = 0,
                      invited: Bool = false, animation: Animation = GridConstants.headTurn) {
        guard liveliness == .expressive || invited else { return }
        withAnimation(animation) {
            yaw = y
            roll = r
            lean = l
            dip = d
        }
    }

    /// An idle beat's pause. False when the beat should stop: its task was
    /// cancelled, or a take started while it slept.
    private func beatPause(_ milliseconds: Int, _ mine: Int) async -> Bool {
        try? await Task.sleep(for: .milliseconds(milliseconds))
        return !Task.isCancelled && generation == mine
    }
}

// MARK: - Tap

/// **An expressive head you can tap for an expression** (`HeadTake`), where
/// the head is the subject of the page: the maker's preview, where somebody
/// who just made a head tries it, and onboarding's head page. A shuffled deck,
/// so the same take never comes twice running; a new tap switches at once;
/// the face goes back to calm when the hold ends.
struct TappableHead: View {
    let rig: HeadRig
    let side: CGFloat
    var greets = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var deck = HeadTakeDeck()
    @State private var played: HeadTake.Played?

    var body: some View {
        LivingHeadView(rig: rig, side: side, liveliness: .expressive, greets: greets, take: played)
            .contentShape(Rectangle())
            .onTapGesture {
                let available = HeadTake.available(faces: rig.takeFaces, hasShut: rig.shut != nil,
                                                   reduceMotion: reduceMotion)
                guard let next = deck.next(from: available) else { return }
                HapticsEngine.lightTap()
                played = HeadTake.Played(id: next.id, direction: Bool.random() ? 1 : -1,
                                         nonce: (played?.nonce ?? 0) + 1)
            }
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
    /// The face it is wearing. What was on screen is what gets drawn into the
    /// photograph.
    var expression: HeadRig.Expression = .neutral
    /// Where the eyes look. A tapped take can leave them somewhere (a side-eye,
    /// a look away while thinking), and the photograph then matches what was on
    /// the review. See `HeadTake.stillGaze`.
    var gaze: CGPoint = HeadStill.restingGaze

    /// Resting, a little to one side. Never straight at you.
    static let restingGaze = CGPoint(x: 0.35, y: 0.08)

    var body: some View {
        let canvas = side / rig.contentHeight
        let centring = (0.5 - (rig.chin - rig.contentHeight / 2)) * canvas
        let face = rig.face(expression)
        ZStack {
            Image(uiImage: face.image)
                .resizable()
                .interpolation(.high)
            ZStack {
                ForEach(Array(face.eyes.enumerated()), id: \.offset) { _, eye in
                    IrisLayer(eye: eye, canvas: canvas, gaze: gaze)
                }
            }
            .frame(width: canvas, height: canvas)
        }
        .frame(width: canvas, height: canvas)
        .offset(y: centring)
        .frame(width: canvas, height: canvas)
    }
}
