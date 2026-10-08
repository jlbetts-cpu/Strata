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
    var completedCategories: [HabitCategory] = HabitCategory.selectable
    /// What VoiceOver hears, since nothing here can be read.
    var announcement = "Today's goal, reached."

    /// Seeded once, on appear.
    @State private var particles: [Particle] = []

    fileprivate struct Particle: Identifiable {
        let id: Int
        let color: Color
        /// Where it lands sideways by the end, in points.
        let drift: CGFloat
        /// How high it rises above the crown, in points.
        let rise: CGFloat
        /// The short side, in points.
        let side: CGFloat
        /// 1 for a quick block's square, 2 for a regular's bar.
        let span: CGFloat
        /// Turns over the whole flight, in radians.
        let turn: Double
    }

    /// About forty blocks whatever the day: a one-colour day throws as many as
    /// a six-colour one, split between its colours.
    private static let total = 42

    private func seed() -> [Particle] {
        let colours = completedCategories.map(\.style.baseColor)
        guard !colours.isEmpty else { return [] }
        return (0..<Self.total).map { i in
            Particle(id: i,
                     color: colours[i % colours.count],
                     drift: .random(in: -190...190),
                     rise: .random(in: 140...360),
                     side: .random(in: 7...11),
                     span: Bool.random() ? 1 : 2,
                     turn: .random(in: -9...9))
        }
    }

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                ConfettiBlock(particle: particle)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            particles = seed()
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

/// One block of the burst: up out of the crown, over, and down past it.
private struct ConfettiBlock: View {
    let particle: AllClearCelebration.Particle
    /// Flips once the block is on screen: a keyframe animation runs when its
    /// trigger CHANGES, so a block born already launched would never move.
    @State private var launched = false

    private struct Pose {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var angle: Double = 0
        var opacity: Double = 1
    }

    var body: some View {
        let w = particle.side * particle.span, h = particle.side
        let total = GridConstants.confettiDuration
        // A thrown thing spends about a third of its flight going up.
        let up = total * 0.32
        RoundedRectangle(cornerRadius: h * 0.147, style: .continuous)
            .fill(particle.color)
            .frame(width: w, height: h)
            .keyframeAnimator(initialValue: Pose(), trigger: launched) { content, pose in
                content
                    .rotationEffect(.radians(pose.angle))
                    .offset(x: pose.x, y: pose.y)
                    .opacity(pose.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.x) {
                    CubicKeyframe(particle.drift * 0.55, duration: up)
                    CubicKeyframe(particle.drift, duration: total - up)
                }
                // Decelerating to the top and accelerating down, which is
                // what gravity does; the fall ends well below the crown.
                KeyframeTrack(\.y) {
                    SpringKeyframe(-particle.rise, duration: up, spring: .smooth(duration: up * 1.6))
                    CubicKeyframe(particle.rise * 1.1, duration: total - up)
                }
                KeyframeTrack(\.angle) {
                    LinearKeyframe(particle.turn, duration: total)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(1, duration: total * 0.65)
                    LinearKeyframe(0, duration: total * 0.35)
                }
            }
            .opacity(launched ? 1 : 0)
            .onAppear { launched = true }
    }
}
