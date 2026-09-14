import SwiftUI

/// A replay, playing.
///
/// Time is the only state. Tap skips to the close, press and hold pauses,
/// and neither can put anything out of step because nothing is animating:
/// every frame is `ReplayFrame` at the clock's `t`.
///
/// **Gestures, and why the close button is never a skip.** The close button
/// is a SIBLING of the player in the ZStack, drawn above it, not a child of
/// the view that carries the gestures. A touch is hit-tested to the frontmost
/// view under it, and only gestures on that view and its ancestors take part,
/// so a touch on the button never reaches the tap or the hold at all.
/// `ReplayGestureTests` presses all three.
///
/// The controls under the close (Share, Save Video) are different: they are
/// children of the player. A child `Button` takes precedence over the
/// parent's `onTapGesture`, so a tap on one should be the button's and not a
/// skip; but the hold is SIMULTANEOUS, so holding a control would also pause.
/// Nothing in this task can press a control that does not exist yet: the
/// tasks that add them must add a UI test that tapping one does not skip.
/// Before the close arrives `ReplayFrame` turns their hit testing off, so a
/// tap there falls through to the skip.
struct ReplayView: View {
    let replay: Replay
    var isSample = false
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale
    /// One `now` for the whole replay. The header's range is worded against
    /// it, and a fresh `Date()` per frame could reword it mid-play at
    /// midnight.
    @State private var now = Date()
    @State private var images: ReplayImages?
    @State private var clock = ReplayClock()
    @State private var feedback = ReplayFeedback()
    /// Set once `t` reaches the end, so the timeline stops asking for frames
    /// of a picture that no longer changes.
    @State private var finished = false
    @GestureState private var holding = false
    #if DEBUG
    @State private var cadence = ReplayCadence()
    #endif

    var body: some View {
        // Two readers. The outer one keeps the safe area, so its insets are
        // the real status bar, Dynamic Island and home indicator. A reader
        // that itself ignores the safe area reports zero insets: photographed
        // that way, the header sat under the status bar. The inner one
        // ignores it, so its size is the whole screen, which the replay's
        // lines are fractions of.
        GeometryReader { safe in
            let insets = safe.safeAreaInsets
            GeometryReader { geo in
                let script = ReplayScript(replay: replay, metrics: .standard(frame: geo.size),
                                          reduceMotion: reduceMotion)
                ZStack(alignment: .topTrailing) {
                    if let images {
                        player(script: script, images: images, insets: insets)
                    } else {
                        WarmBackground()
                    }
                    // From the first frame, loaded or not: leaving never waits
                    // on the animation.
                    GlassIconButton(systemName: "xmark", accessibilityLabel: "Close", action: onClose)
                        .padding(.trailing, GridConstants.horizontalPadding)
                        .padding(.top, insets.top + GridConstants.gapTight)
                }
                .task(id: script.metrics.cell) { await prepare(cell: script.metrics.cell) }
            }
            .ignoresSafeArea()
        }
        .statusBarHidden(false)
    }

    private func player(script: ReplayScript, images: ReplayImages, insets: EdgeInsets) -> some View {
        TimelineView(.animation(paused: finished || clock.isPaused || clock.isFrozen)) { context in
            let t = clock.time(at: context.date, duration: script.duration)
            ReplayFrame(script: script, images: images, t: t, now: now,
                        showsSampleBadge: isSample,
                        controls: AnyView(controls(script: script)),
                        topInset: insets.top, bottomInset: insets.bottom)
                .onChange(of: t) { old, new in
                    feedback.play(script, from: old, to: new)
                    #if DEBUG
                    if DebugHarness.probesReplay { cadence.record(script.phase(at: new), finished: new >= script.duration) }
                    #endif
                    if new >= script.duration { finished = true }
                }
                #if DEBUG
                .overlay(alignment: .topLeading) {
                    if DebugHarness.probesReplay { probe(script: script, t: t) }
                }
                #endif
        }
        .contentShape(Rectangle())
        .onTapGesture { clock.skip(to: script.closeStart) }
        .simultaneousGesture(hold)
        .onChange(of: holding) { _, isHolding in
            if isHolding { clock.pause() } else { clock.resume() }
        }
    }

    /// Press and hold: a long press SEQUENCED before a zero-distance drag, so
    /// it stays held for as long as the finger is down after the delay, and
    /// `@GestureState` resets it however the touch ends, cancellation
    /// included. A replay cannot be left paused by an interrupted press.
    ///
    /// A bare `onLongPressGesture(pressing:)` reports touch-down at once, so
    /// every tap would freeze the picture before skipping, and it reports
    /// the press over when the delay is met rather than when the finger
    /// lifts.
    ///
    /// **Simultaneous with the tap, not exclusive before it.**
    /// `hold.exclusively(before: TapGesture())` read correctly and never
    /// skipped: `ReplayGestureTests.testTapSkipsToTheClose` pressed it and the
    /// clock ran on from 1.66s to 2.90s. A release after a hold does not also
    /// count as a tap; `testHoldPausesAndReleaseResumes` checks that too.
    private var hold: some Gesture {
        LongPressGesture(minimumDuration: GridConstants.replayHoldToPause)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($holding) { value, state, _ in
                if case .second(true, _) = value { state = true }
            }
    }

    /// Share arrives in Task 9 and Save Video in Task 11. The row already
    /// reserves their height, so the close is laid out, and bounded above the
    /// home indicator, at the size it will have once they are in it.
    private func controls(script: ReplayScript) -> some View {
        HStack(spacing: GridConstants.gapItem) { EmptyView() }
            .frame(height: GlassIconButton.defaultSide)
    }

    private func prepare(cell: CGFloat) async {
        #if DEBUG
        if let frozen = DebugHarness.replayAt { clock.freeze(at: frozen) }
        #endif
        async let loaded = ReplayImages.load(replay, width: cell * displayScale)
        // While the photographs decode, not on the first landing: starting
        // the engine there held that frame for 400ms. The yield lets the load
        // hand its decodes to their own tasks before this takes the main
        // actor for the engine.
        await Task.yield()
        SoundEngine.prepare()
        images = await loaded
        clock.start()
    }

    #if DEBUG
    /// The clock, readable by a UI test: a press cannot be verified by
    /// looking at a picture that is supposed to stop moving.
    private func probe(script: ReplayScript, t: Double) -> some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityElement()
            .accessibilityIdentifier("replayProbe")
            .accessibilityLabel(String(format: "%.3f %.3f %.3f", t, script.closeStart, script.duration))
    }
    #endif
}

/// Wall-clock time into the replay, with pause and skip.
@Observable
final class ReplayClock {
    private var startedAt: Date?
    private var pausedAt: Date?
    private var offset: Double = 0
    private var frozen: Double?

    var isPaused: Bool { pausedAt != nil }
    var isFrozen: Bool { frozen != nil }

    func start() { if startedAt == nil { startedAt = Date() } }
    func freeze(at t: Double) { frozen = t }

    func time(at date: Date, duration: Double) -> Double {
        if let frozen { return frozen }
        guard let startedAt else { return 0 }
        let end = pausedAt ?? date
        return min(duration, max(0, end.timeIntervalSince(startedAt) + offset))
    }

    func pause() { if startedAt != nil, pausedAt == nil { pausedAt = Date() } }

    func resume() {
        guard let p = pausedAt, let s = startedAt else { return }
        startedAt = s.addingTimeInterval(Date().timeIntervalSince(p))
        pausedAt = nil
    }

    /// Forward only: a tap during the close changes nothing.
    func skip(to t: Double) {
        guard let s = startedAt else { return }
        let now = pausedAt ?? Date()
        let current = now.timeIntervalSince(s) + offset
        if current < t { offset += t - current }
    }
}

/// Haptics and sound for the landings a frame has passed.
///
/// Rate-limited to `replayFeedbackPerSecond`, so a busy month is a patter and
/// not noise. A skip passes many landings at once and plays none of them.
final class ReplayFeedback {
    private var recent: [Double] = []
    private var danced = false

    func play(_ script: ReplayScript, from old: Double, to new: Double) {
        guard new > old, new - old <= GridConstants.replaySkipGap else { return } // a skip is silent
        for landing in script.landings where landing.time > old && landing.time <= new {
            recent.removeAll { new - $0 >= 1 }
            guard recent.count < GridConstants.replayFeedbackPerSecond else { continue }
            recent.append(new)
            if landing.mass >= 3 { HapticsEngine.squish(mass: landing.mass) } else { HapticsEngine.tick() }
            SoundEngine.blockImpact(mass: landing.mass, column: landing.column,
                                    gain: GridConstants.replayImpactGain)
        }
        if !danced, old < script.danceStart, new >= script.danceStart {
            danced = true
            HapticsEngine.success()
        }
    }
}

#if DEBUG
/// How evenly the live replay was drawn, phase by phase: the gap between one
/// evaluated frame and the next. A recording of the simulator drops frames of
/// its own, so a film alone cannot say whether the app kept up.
final class ReplayCadence {
    private var last: CFTimeInterval?
    private var gaps: [ReplayScript.Phase: [Double]] = [:]
    private var reported = false

    func record(_ phase: ReplayScript.Phase, finished: Bool) {
        let now = CACurrentMediaTime()
        if let last { gaps[phase, default: []].append(now - last) }
        last = now
        guard finished, !reported else { return }
        reported = true
        for (phase, g) in gaps.sorted(by: { "\($0.key)" < "\($1.key)" }) where !g.isEmpty {
            let s = g.sorted()
            func pct(_ p: Double) -> Double { s[min(s.count - 1, Int(Double(s.count) * p))] * 1000 }
            print(String(format: "[REPLAY-CADENCE] %@ frames %d p50 %.1fms p90 %.1fms p99 %.1fms max %.1fms over25ms %d over50ms %d",
                         "\(phase)", s.count, pct(0.5), pct(0.9), pct(0.99), s.last! * 1000,
                         s.filter { $0 > 0.025 }.count, s.filter { $0 > 0.05 }.count))
        }
    }
}
#endif
