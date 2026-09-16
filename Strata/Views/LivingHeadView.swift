import SwiftUI
import UIKit

/// **A head, alive: the one engine every head plays in.**
///
/// The owner's black-and-white head is the standard (owner, 2026-09-16: "make
/// sure the custom head is up to the same standards, animations, movements
/// and the way it moves"). It used to have an engine of its own; now it is one
/// more `HeadRig` (`HeadRig.creatorRig`) and plays here beside every made
/// head, from the same `HeadDirector`, so the two cannot drift apart again.
///
/// - **Idle beats are data** (`HeadBeat`, `HeadDirector.resolve`), played by
///   the same `apply` that plays a tap's take (`HeadTake`). The creator's mix:
///   about a third of beats turn the head in 3D (a 16° turn, a 5° glance with
///   the eyes leading), a look down at the words, a tilt, a smile now and then.
/// - **Eye contact, bounded.** On an expressive head the eyes rest on you for
///   1.2 to 2.6 seconds, never more than `headContactMax` (3s), and then look
///   away on purpose; the next fixation after contact is always somewhere
///   else, at least `headStareFloor` out. A calm head, a take, a kept sticker
///   and Reduce Motion never rest on you. The eyes hold still between
///   fixations, with only tiny micro-saccades, rather than fidgeting.
/// - **The crunch blink.** The lids snap shut as the head squashes 7 to 9%,
///   it gives some back a step later, and opens a step or two after that; one
///   time in four it blinks again. A calm head's lids close and nothing else
///   moves. A blink runs on whichever face shows, if that face has shut eyes.
/// - **Faces pop or morph.** A face in `rig.popsIn` (the creator's grin and
///   wink; a made face whose silhouette matches neutral's) swaps in one
///   transaction. Anything else morphs: the old face fades OUT over the new
///   one, which is at full opacity underneath the whole time (CLAUDE.md, a
///   crossfade must never reveal what is under it), removed on the fade's own
///   completion. Brows are always a hard swap. Back to calm goes through a
///   blink: the lids close on the old face and open on neutral.
/// - **Each face carries its own irises**, so they go with it. A shut face has
///   none: a drawn lid with a live iris on it reads as broken.
/// - **It sleeps when nobody can see it**: backgrounded, or scrolled or panned
///   off screen. The loops stop, the float stops, and on waking the first beat
///   waits a full rest rather than arriving in a burst.
///
/// Reduce Motion holds it still, eyes resting to one side; a greeting and a
/// take are a change of face and nothing else.
struct LivingHeadView: View {
    enum Liveliness { case calm, expressive }

    let rig: HeadRig
    /// The head's own height, crown to chin. Centred by its face, not its
    /// file, so every head — made or bundled — sits in the middle.
    let side: CGFloat
    var liveliness: Liveliness = .calm
    /// Brows, then a wink (or a smile) when it first appears.
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
    /// Where something on the page lies, -1...1 each way: a turn looks there.
    /// On the thank-you page, the photograph. Nil turns either way.
    var lookTarget: CGPoint? = nil
    /// DEBUG: the name this head's lines carry under `-strataHeadTrace`.
    var traceID: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var expression: HeadRig.Expression = .neutral
    /// The face being morphed away from, fading out on top of the new one.
    @State private var outgoing: HeadRig.Expression?
    @State private var incoming: Double = 1
    @State private var shut = false
    @State private var squash: CGFloat = 1
    /// Where the eyes rest between beats: on you, or somewhere that is not.
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
    /// The resting point is on you. A take moves it away before it starts.
    @State private var restIsContact = false
    /// Its frame is at least a fifth on screen.
    @State private var onScreen = true
    /// The director and what the loops remember across a pause. A reference,
    /// so drawing a beat does not invalidate the view.
    @State private var life = LifeBox()
    #if DEBUG
    /// `-strataHeadTake`: takes played without a finger, for screenshots.
    @State private var debugPlayed: HeadTake.Played?
    #endif

    private final class LifeBox {
        var director: HeadDirector?
        var key: String = ""
        var greeted = false
        var lived = false
    }

    private struct LoopKey: Hashable {
        let reduceMotion: Bool
        let awake: Bool
    }

    private var profile: HeadLife { liveliness == .calm ? .calm : .expressive }
    private var awake: Bool { scenePhase == .active && onScreen }
    private var step: Duration { .seconds(GridConstants.headStep) }

    var body: some View {
        let canvas = side / rig.contentHeight
        let centring = (0.5 - (rig.chin - rig.contentHeight / 2)) * canvas
        let floats = profile.floats && !reduceMotion
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
        .onGeometryChange(for: Bool.self) { proxy in
            Self.isOnScreen(proxy.frame(in: .global))
        } action: { visible in
            onScreen = visible
        }
        .onChange(of: awake && floats, initial: true) { _, floating in
            // Two periods that never line up, so the drift never reads as a
            // metronome. Stopped outright while asleep: a repeatForever keeps
            // the head redrawing every frame for as long as it runs.
            if floating {
                withAnimation(GridConstants.headFloatX) { floatA = true }
                withAnimation(GridConstants.headFloatY) { floatB = true }
            } else {
                var instant = Transaction()
                instant.disablesAnimations = true
                withTransaction(instant) {
                    floatA = false
                    floatB = false
                }
            }
        }
        .onChange(of: awake) { _, isAwake in
            #if DEBUG
            HeadTrace.log(traceID, "awake \(isAwake)")
            #endif
            // Asleep, nothing is left half done: a take in flight is left to
            // finish, and a kept sticker face stays.
            if !isAwake, !taking, heldFace == nil { settleImmediately() }
        }
        .task(id: LoopKey(reduceMotion: reduceMotion, awake: awake)) { await liveWhileIdle() }
        .task(id: LoopKey(reduceMotion: reduceMotion, awake: awake)) { await eyesWhileIdle() }
        .task(id: LoopKey(reduceMotion: reduceMotion, awake: awake)) { await blinkWhileIdle() }
        .task(id: held) {
            heldFace = held
            // A head playing takes wears the faces its takes give it.
            guard take == nil else { return }
            await wear(held)
        }
        .task(id: playing) { await play(playing) }
        #if DEBUG
        .task { await debugTakes() }
        .onChange(of: gaze, initial: true) { _, g in
            HeadTrace.log(traceID, "gaze \(HeadTrace.number(g.x)) \(HeadTrace.number(g.y))")
        }
        .onChange(of: [yaw, roll, Double(lean / max(side, 1)), Double(dip / max(side, 1))]) { _, p in
            HeadTrace.log(traceID, "pose \(p.map(HeadTrace.number).joined(separator: " "))")
        }
        .onChange(of: [shut ? 1 : 0, Double(squash)]) { _, l in
            HeadTrace.log(traceID, "lids \(Int(l[0])) \(HeadTrace.number(l[1]))")
        }
        .onChange(of: expression) { _, e in HeadTrace.log(traceID, "face \(e.rawValue)") }
        #endif
    }

    /// At least a fifth of the head's frame is inside the screen. A frame with
    /// no area (not laid out yet) counts as seen, so a head is never put to
    /// sleep by a guess.
    private static func isOnScreen(_ frame: CGRect) -> Bool {
        let area = frame.width * frame.height
        guard area > 0 else { return true }
        let seen = frame.intersection(UIScreen.main.bounds)
        guard !seen.isNull else { return false }
        return seen.width * seen.height >= area * 0.2
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

    private func showsShut(_ face: HeadRig.Expression) -> UIImage? {
        shut ? rig.shut(on: face) : nil
    }

    private func artwork(_ face: HeadRig.Expression) -> some View {
        Image(uiImage: showsShut(face) ?? rig.face(face).image)
            .resizable()
            .interpolation(.high)
    }

    /// A shut face has no iris. A drawn lid with a live iris sitting on it
    /// does not read as a blink; it reads as broken.
    private func irises(of face: HeadRig.Expression, canvas: CGFloat) -> some View {
        let eyes = showsShut(face) != nil ? [] : rig.face(face).eyes
        let gaze = gaze
        return ZStack {
            ForEach(Array(eyes.enumerated()), id: \.offset) { _, eye in
                IrisLayer(eye: eye, canvas: canvas, gaze: gaze)
            }
        }
        .frame(width: canvas, height: canvas)
        .allowsHitTesting(false)
    }

    // MARK: - The director

    /// The same seed gives the same life on any head (`-strataHeadSeed`).
    private var director: HeadDirector {
        get {
            let key = "\(liveliness)|\(rig.expressions)|\(rig.shutFaces.map(\.rawValue).sorted())|\(String(describing: lookTarget))"
            if let director = life.director, life.key == key { return director }
            #if DEBUG
            let seed = DebugHarness.headSeed
            let forced = DebugHarness.headBeat
            #else
            let seed: UInt64? = nil
            let forced: HeadBeat.ID? = nil
            #endif
            let made = HeadDirector(life: profile, faces: rig.takeFaces, shutFaces: rig.shutFaces,
                                    lookTarget: lookTarget, seed: seed, forced: forced)
            life.director = made
            life.key = key
            return made
        }
        nonmutating set { life.director = newValue }
    }

    // MARK: - Eyes at rest

    /// **Fixations, and micro-saccades on top.** Each fixation is the
    /// director's: on you for at most three seconds (expressive only), or
    /// somewhere that is not you. Sleeps until whichever is due first.
    private func eyesWhileIdle() async {
        guard !reduceMotion else {
            rest = CGPoint(x: 0.5, y: 0.1)
            restIsContact = false
            return
        }
        guard awake else { return }
        let clock = ContinuousClock()
        var nextFixation = clock.now
        var nextMicro: ContinuousClock.Instant? = director.nextMicro().map { clock.now + .seconds($0.after) }
        while !Task.isCancelled {
            let wake = min(nextFixation, nextMicro ?? nextFixation)
            try? await Task.sleep(until: wake, clock: .continuous)
            guard !Task.isCancelled else { return }
            if clock.now >= nextFixation {
                // A take, or a sticker's kept look, never gets eye contact.
                let fixation = director.nextFixation(allowContact: !taking && !gazeHeld && heldFace == nil)
                nextFixation = clock.now + .seconds(fixation.hold)
                if !gazeHeld {
                    if restShare > 0.5 {
                        withAnimation(GridConstants.eyeSaccade) { rest = fixation.gaze }
                    } else {
                        // Hidden under a beat's look: move it without a spring,
                        // so contact never outlasts its hold underneath either.
                        var instant = Transaction()
                        instant.disablesAnimations = true
                        withTransaction(instant) { rest = fixation.gaze }
                    }
                    restIsContact = fixation.contact
                }
                #if DEBUG
                HeadTrace.log(traceID, "fix \(fixation.contact ? 1 : 0) \(HeadTrace.number(fixation.hold))")
                #endif
            }
            if let due = nextMicro, clock.now >= due, let next = director.nextMicro() {
                withAnimation(GridConstants.eyeSaccade) { micro = next.offset }
                nextMicro = clock.now + .seconds(next.after)
            }
        }
    }

    // MARK: - Blinking

    private func blinkWhileIdle() async {
        guard !reduceMotion, !rig.shutFaces.isEmpty else {
            shut = false
            return
        }
        guard awake else { return }
        while !Task.isCancelled {
            let blink = director.nextBlink()
            try? await Task.sleep(for: .seconds(blink.gap))
            guard !Task.isCancelled else { return }
            // The watchdog. No idle beat holds a face for more than about two
            // seconds and a take marks itself, so a face other than neutral
            // with nothing running is a face that was left behind. Bring it
            // home, irises and all.
            if !busy, !taking, heldFace == nil, expression != .neutral || outgoing != nil || shut {
                #if DEBUG
                NSLog("[strata-head] watchdog brought back a face left at \(expression) (outgoing \(String(describing: outgoing)), shut \(shut))")
                #endif
                settleImmediately()
                continue
            }
            // The creator blinks through a glance or a turn, not through a
            // take or a face held for a photograph.
            guard !taking, heldFace == nil, !shut, outgoing == nil, expression == .neutral,
                  rig.shut(on: .neutral) != nil else { continue }
            await crunchBlink(depth: blink.depth, steps: blink.steps, double: blink.double)
        }
    }

    /// **The creator's blink.** Shut with a crunch, give a little back a step
    /// later, open a step or two after that; `double` blinks again at once.
    private func crunchBlink(depth: Double, steps: Int, double: Bool) async {
        let mine = generation
        let squashes = depth < 1
        #if DEBUG
        HeadTrace.log(traceID, "blink \(HeadTrace.number(depth))")
        #endif
        shut = true
        if squashes { squash = depth }
        try? await Task.sleep(for: step)
        // A take that started while the lids were down owns them now.
        guard generation == mine, !Task.isCancelled else { return }
        if squashes { squash = depth + GridConstants.headBlinkRelease }
        try? await Task.sleep(for: step * steps)
        guard generation == mine, !Task.isCancelled else { return }
        if double {
            shut = false
            squash = 1
            try? await Task.sleep(for: step)
            guard generation == mine, !Task.isCancelled else { return }
            shut = true
            if squashes { squash = 0.92 }
            try? await Task.sleep(for: step)
            guard generation == mine, !Task.isCancelled else { return }
            if squashes { squash = 0.95 }
            try? await Task.sleep(for: step)
            guard generation == mine, !Task.isCancelled else { return }
        }
        shut = false
        squash = 1
    }

    // MARK: - Beats

    /// The hello, then a beat every rest. **A tap wins over all of it**: no
    /// beat starts over a take, and every moment checks it is still its turn.
    private func liveWhileIdle() async {
        // A clean face every time the loops start. They restart whenever
        // Reduce Motion changes or the head wakes, and a restart in the middle
        // of a smile left the face on the smile — which has no drawn irises —
        // with nothing left to bring it back. Not over a take: a tap in the
        // first moment of a page starts one.
        if !taking { settleImmediately() }
        guard awake else { return }
        if reduceMotion {
            // Reduce Motion: the hello is a change of face and nothing else.
            guard greets, !life.greeted, rig.has(.wink) else { return }
            life.greeted = true
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled, !taking else { return }
            swap(to: .wink)
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled, !taking else { return }
            swap(to: .neutral)
            return
        }
        var wait: Double
        if greets, !life.greeted {
            life.greeted = true
            let hello = director.greeting()
            await perform(hello, named: "hello")
            guard !Task.isCancelled else { return }
            wait = max(0.4, profile.firstBeatAfterHello - (hello.last?.at ?? 0))
        } else if !life.lived {
            wait = profile.firstBeat
        } else {
            // Waking: a full rest, not a burst of beats.
            wait = director.nextRest()
        }
        life.lived = true
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            // A head wearing a kept face, or looking where a kept take left
            // it, is not idle: a beat would undo what its photograph shows.
            if !busy, !taking, heldFace == nil, !gazeHeld {
                let next = director.nextBeat()
                await perform(director.resolve(next.id, direction: next.direction), named: next.id.rawValue)
            }
            wait = director.nextRest()
        }
    }

    /// **Plays a beat's moments** through the same `apply` a take uses. A
    /// beat that a take overtakes stops where it is and leaves `busy` to it.
    private func perform(_ moments: [HeadTake.Moment], named name: String) async {
        guard !taking else {
            #if DEBUG
            NSLog("[strata-head] \(name) stood aside for a take")
            #endif
            return
        }
        let mine = generation
        busy = true
        #if DEBUG
        HeadTrace.log(traceID, "beat \(name)")
        #endif
        let start = ContinuousClock.now
        for moment in moments {
            try? await Task.sleep(until: start + .seconds(moment.at), clock: .continuous)
            guard !Task.isCancelled, generation == mine else { return }
            if case let .cue(step) = moment.event { apply(step) }
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
        // pose are animated over by this one. A take never rests its eyes on
        // you, so a resting point on you goes too.
        withTransaction(instant) {
            shut = false
            squash = 1
            if restIsContact {
                rest = director.nextAway()
                restIsContact = false
            }
        }
        #if DEBUG
        NSLog("[strata-head] play \(take.id.rawValue) dir \(played.direction) hold \(take.hold)")
        HeadTrace.log(traceID, "take \(take.id.rawValue)")
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
            case .end:
                break
            }
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

    /// **One cue, for a take or a beat.** Nothing here waits, so a cue never
    /// delays the next.
    private func apply(_ step: HeadTake.Step) {
        switch step {
        case let .face(next):
            if next == .browsUp || (next == .neutral && expression == .browsUp) {
                // Brows are a hard swap: a 220ms flash with a fade on it would
                // never be seen.
                swap(to: next)
            } else if rig.popsIn.contains(next) || (next == .neutral && rig.popsIn.contains(expression)) {
                pop(to: next)
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
            pose(yaw: min(max(yaw, -profile.maxYaw), profile.maxYaw), roll: roll,
                 lean: CGFloat(lean) * side, dip: CGFloat(dip) * side,
                 invited: true, animation: animation)
        case let .lids(closed):
            guard rig.shut(on: expression) != nil else { return }
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
        case let .blink(depth, steps, double):
            guard rig.shut(on: expression) != nil, !shut else { return }
            let depth = profile.blinkDepth == nil ? 1 : depth
            Task { @MainActor in await crunchBlink(depth: depth, steps: steps, double: double) }
        case .settle:
            Task { @MainActor in await settleThroughBlink() }
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

    /// A hard swap, for brows and for Reduce Motion.
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

    /// **A face that pops straight in**, the creator's grin and wink: a blink
    /// on the way to a grin reads as hesitation. One transaction, so nothing
    /// translucent is ever on screen, and a small squash on an expressive head.
    private func pop(to next: HeadRig.Expression) {
        guard next != expression, next == .neutral || rig.has(next) else { return }
        swap(to: next)
        guard profile.morphSquash, !reduceMotion else { return }
        withAnimation(GridConstants.tapSquashSpring) { squash = 0.975 }
        let mine = generation
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(160))
            guard generation == mine, !shut else { return }
            withAnimation(GridConstants.naturalSettle) { squash = 1 }
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
        if profile.morphSquash, squashes {
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

    /// **Back to neutral behind a blink**, so the change itself is never seen.
    /// The creator's order: the lids close on the face being left, the face
    /// changes behind them, and they open on neutral. A face with no shut eyes
    /// of its own closes on neutral's instead; a wink, whose own eyes are the
    /// photograph's, and a head that cannot blink, morph.
    private func settleThroughBlink() async {
        let leaving = expression
        guard leaving != .neutral else { return }
        guard !reduceMotion, rig.shut(on: .neutral) != nil,
              leaving != .wink || rig.shut(on: .wink) != nil else {
            await morph(to: .neutral)
            return
        }
        let mine = generation
        let squashes = profile.blinkDepth != nil
        var instant = Transaction()
        instant.disablesAnimations = true
        if rig.shut(on: leaving) != nil {
            withTransaction(instant) {
                outgoing = nil
                incoming = 1
                shut = true
            }
            if squashes { squash = 0.92 }
            try? await Task.sleep(for: step)
            guard generation == mine, !Task.isCancelled else { return }
            withTransaction(instant) { expression = .neutral }
            if squashes { squash = 0.965 }
            try? await Task.sleep(for: step)
        } else {
            withTransaction(instant) {
                outgoing = nil
                incoming = 1
                expression = .neutral
                shut = true
            }
            if squashes { squash = 0.94 }
            try? await Task.sleep(for: step * 2)
        }
        // Overtaken by a new take, which has already opened the eyes on
        // its own face: leave it alone.
        guard generation == mine, !Task.isCancelled else { return }
        shut = false
        squash = 1
    }

    // MARK: - Movement

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
        guard profile.movesHead || invited else { return }
        withAnimation(animation) {
            yaw = y
            roll = r
            lean = l
            dip = d
        }
    }
}

// MARK: - Tap

/// **An expressive head you can tap for an expression** (`HeadTake`), where
/// the head is the subject of the page: the maker's preview, onboarding's head
/// page, and the thank-you page (`CreatorHead`). A shuffled deck, so the same
/// take never comes twice running; a new tap switches at once; the face goes
/// back to calm when the hold ends.
struct TappableHead: View {
    let rig: HeadRig
    let side: CGFloat
    var greets = false
    var lookTarget: CGPoint? = nil
    var traceID: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var deck = HeadTakeDeck()
    @State private var played: HeadTake.Played?

    var body: some View {
        LivingHeadView(rig: rig, side: side, liveliness: .expressive, greets: greets, take: played,
                       lookTarget: lookTarget, traceID: traceID)
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

/// One iris, placed in its eye and clipped to the lids, with a catchlight that
/// belongs to the light, not the eye: it stays put while the iris moves.
private struct IrisLayer: View {
    let eye: HeadRig.Eye
    let canvas: CGFloat
    let gaze: CGPoint

    var body: some View {
        let width = eye.rx * 2 * canvas
        let height = eye.ry * 2 * canvas
        // The portfolio's faces were calibrated with a narrow ellipse: an iris
        // 0.6 of its width and 1.05 of its height, travelling 16% of the eye
        // each way, exactly as the creator's head always drew. A measured
        // opening runs corner to corner: an iris is about half of that, and
        // never shorter than the opening is tall, so the lids overlap it top
        // and bottom the way real ones do (measured on thirteen faces).
        let calibrated = eye.outline == nil
        let irisWidth = calibrated ? width * 0.6 : min(max(width * 0.5, height * 1.25), width * 0.62)
        let irisHeight = calibrated ? height * 1.05 : irisWidth
        let along = calibrated ? gaze.x * width * 0.16 : gaze.x * max((width - irisWidth) / 2, 0) * 0.8
        let across = calibrated ? gaze.y * height * 0.16 : gaze.y * height * 0.2
        let cosine = CGFloat(cos(eye.angle)), sine = CGFloat(sin(eye.angle))
        let centre = CGPoint(x: eye.x * canvas + along * cosine - across * sine,
                             y: eye.y * canvas + along * sine + across * cosine)
        // Where the light sits: up and in from the middle of the eye.
        let lightX = calibrated ? -width * 0.08 : -irisWidth * 0.16
        let lightY = calibrated ? -height * 0.14 : -irisWidth * 0.18
        ZStack {
            IrisDisc(colour: eye.iris, width: irisWidth, height: irisHeight, calibrated: calibrated)
                .position(centre)
            Catchlight(width: calibrated ? width * 0.2 : irisWidth * 0.3,
                       height: calibrated ? height * 0.2 : irisWidth * 0.3,
                       calibrated: calibrated)
                .position(x: eye.x * canvas + lightX * cosine - lightY * sine,
                          y: eye.y * canvas + lightX * sine + lightY * cosine)
        }
        .frame(width: canvas, height: canvas)
        .clipShape(EyeOpening(eye: eye))
    }
}

/// An iris and its pupil.
private struct IrisDisc: View {
    let colour: HeadRig.RGB?
    let width: CGFloat
    let height: CGFloat
    let calibrated: Bool

    var body: some View {
        let pupil = CGFloat(calibrated ? GridConstants.headPupilCalibrated : GridConstants.headPupilMeasured)
        ZStack {
            if calibrated {
                Ellipse()
                    .fill(RadialGradient(stops: stops, center: .center, startRadius: 0,
                                         endRadius: hypot(width, height) / 2))
            } else {
                Ellipse()
                    .fill(EllipticalGradient(stops: stops, center: .center,
                                             startRadiusFraction: 0, endRadiusFraction: 0.5))
            }
            Ellipse()
                .fill(Color.black)
                .frame(width: width * pupil, height: height * pupil)
        }
        .frame(width: width, height: height)
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

/// The light in the eye. The portfolio's soft three-stop glint on a
/// calibrated eye; a plain fall-off on a measured one.
private struct Catchlight: View {
    let width: CGFloat
    let height: CGFloat
    let calibrated: Bool

    var body: some View {
        Group {
            if calibrated {
                Ellipse()
                    .fill(RadialGradient(stops: [
                        .init(color: .white.opacity(0.98), location: 0),
                        .init(color: .white.opacity(0.72), location: 0.24),
                        .init(color: .white.opacity(0), location: 0.6)
                    ], center: .center, startRadius: 0, endRadius: width / 2))
            } else {
                Ellipse()
                    .fill(EllipticalGradient(colors: [.white.opacity(0.95), .white.opacity(0)],
                                             center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5))
            }
        }
        .frame(width: width, height: height)
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
