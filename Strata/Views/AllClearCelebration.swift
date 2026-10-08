import SwiftUI

/// The confetti that marks a perfect day, drawn in the colours of the wins that
/// made it one (the Self-Relevance Effect, Rogers et al. 1977: your own
/// categories, never a generic palette).
///
/// **Three things here were broken on screen, and all three were invisible in
/// the code.** Written down because each is a shape of bug this file invites:
///
/// 1. **The particles were a computed property, read inside the `Canvas` draw
///    closure.** `TimelineView(.animation)` redraws every frame, so every frame
///    built a brand new set with fresh random angles, speeds and sizes. Nothing
///    ever flew anywhere: it rendered as static noise jumping about over the
///    tower, which is not a celebration, it is a fault. A particle is an object
///    with a path through time, so the set is seeded ONCE and held in state.
/// 2. **`context.rotate(by:)` turns the context about its ORIGIN**, not about
///    the thing being drawn. The old code rotated the whole context, filled a
///    rect in absolute canvas coordinates, then rotated back, so a speck 250pt
///    from the corner was thrown hundreds of points away by its own tumble.
///    Each speck now gets its own layer, translated to its centre first, with
///    its rect built around the origin.
/// 3. **The shape variety could not fire.** It chose from `i % 10` while `i`
///    ran `0..<4`, so every particle was a rectangle and the "40% / 30% / 30%"
///    in the comment described code that was unreachable.
///
/// **The trailer's burst, from the crest** (2026-10-08, the owner: "the color of
/// the blocks should be every category color all the time also make the
/// confetti like the trailer where it shoots out"). Shot 5 of the launch film:
/// when the goal crest fills, fourteen blocks of every category colour shoot
/// out of it in a ring, tumble towards you, drift down and are gone in 1.6s.
/// The numbers below are that shot's, moved from its 420px phone to points.
///
/// **Blocks, not specks, and out of the tower** (2026-10-08, the owner: "i hit
/// the goal and the tower didnt dance or the block confetti come out"). The
/// burst was twelve 4 to 8pt specks drawn inside the grid's own frame, which
/// on a phone is nothing anyone sees. It is now small blocks, the block's own
/// shape and corner, in the day's colours, thrown up from the crown of the
/// tower and falling past it.
///
/// **Views on keyframes, not a Canvas on a TimelineView.** Measured on the
/// simulator the same day: the Canvas version appeared (its `onAppear` ran,
/// 42 particles seeded) and drew nothing, run after run, until an unrelated
/// overlay was put on it. Each block is now a shape with its own keyframed
/// path, which SwiftUI animates on the render server whatever else is on
/// screen. The rest of this note is the history of the Canvas's bugs.
///
/// **One shape now, deliberately**, which is rule 1 in
/// `docs/design-system-future.md` section 10: one size rather than three near
/// sizes. At 4 to 8pt a rectangle, a circle and a strip are the same speck, so
/// three of them were three answers to a question with no visible difference in
/// it. What the eye reads at this size is colour and tumble, and both are kept.
///
/// **Flagged for the owner rather than decided here.** Section 5 of the design
/// language says nothing runs over 0.7s and nothing animates because a state
/// appeared; `GridConstants.confettiDuration` is 2.0s on a state arriving.
/// Apple's *Principles of Great Design* puts it plainly: delight is the result
/// of getting the other principles right, "not confetti tacked on top". The
/// tower already has a jubilation wave for this exact moment, which is the
/// reaction happening where the thing happened. If the wave is the celebration,
/// this file should go rather than be tuned. That is his call, not ours, and
/// the call site is in `MainAppView`.
struct AllClearCelebration: View {
    @Binding var isActive: Bool
    /// What VoiceOver hears, since nothing here can be read.
    var announcement = "Today's goal, reached."

    /// The film's fourteen.
    private static let count = 14
    /// Every category's colour, always (his call): the burst is the app's
    /// whole palette, not the day's.
    private static let colours = HabitCategory.selectable.map(\.style.baseColor)

    var body: some View {
        ZStack {
            ForEach(0..<Self.count, id: \.self) { i in
                BurstBlock(index: i, count: Self.count,
                           colour: Self.colours[i % max(Self.colours.count, 1)])
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            if UIAccessibility.isVoiceOverRunning {
                UIAccessibility.post(notification: .announcement, argument: announcement)
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(Int(GridConstants.confettiDuration * 1000)))
                isActive = false
            }
        }
    }
}

/// One block of the burst, flown on the film's own curve: out on a cubic ease
/// over 0.9s, falling as it goes, tumbling towards the viewer, fading from 1.1s.
private struct BurstBlock: View {
    let index: Int
    let count: Int
    let colour: Color
    /// Flips once on screen: a keyframe animation runs when its trigger
    /// CHANGES, so a block born already launched would never move.
    @State private var launched = false

    /// The film's phone was 420px wide; this phone is about 402pt.
    private static let width: CGFloat = 402
    private static let flight: Double = 1.6

    private static func out3(_ x: Double) -> Double { 1 - pow(1 - min(max(x, 0), 1), 3) }

    var body: some View {
        let i = Double(index)
        let angle = i / Double(count) * 2 * .pi + 0.3
        let speed = 0.55 + Double((index * 37) % 10) / 22
        let side = Self.width * (0.05 + CGFloat((index * 13) % 5) / 140)
        let spinSign: Double = index.isMultiple(of: 2) ? -1 : 1
        RoundedRectangle(cornerRadius: side * 0.24, style: .continuous)
            .fill(colour)
            .frame(width: side, height: side)
            .keyframeAnimator(initialValue: 0.0, trigger: launched) { content, u in
                let reach = Self.out3(u / 0.9)
                let x = cos(angle) * speed * Self.width * 0.55 * reach
                let y = sin(angle) * speed * Self.width * 0.42 * reach + 250 * u * u
                // Coming towards you, as the film's translateZ did.
                let near = 1 + 0.55 * Self.out3(u / 0.7) * speed
                let fadeIn = min(u / 0.08, 1)
                let fadeOut = 1 - min(max((u - 1.1) / 0.5, 0), 1)
                content
                    .rotation3DEffect(.degrees(u * 300 + i * 40), axis: (x: 1, y: 0, z: 0))
                    .rotationEffect(.degrees(u * 200 * spinSign))
                    .scaleEffect(near)
                    .offset(x: x, y: y)
                    .opacity(launched ? fadeIn * fadeOut : 0)
            } keyframes: { _ in
                LinearKeyframe(Self.flight, duration: Self.flight)
            }
            .onAppear { launched = true }
    }
}
