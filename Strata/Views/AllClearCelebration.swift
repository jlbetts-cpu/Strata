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

    /// Seeded once, on appear. Its being computed is what made the confetti
    /// noise: see bug 1 above.
    @State private var particles: [Particle] = []
    @State private var startTime: Date?

    private struct Particle {
        let color: Color
        /// Radians. Where it leaves the centre.
        let angle: Double
        /// Points per second.
        let velocity: Double
        let size: CGFloat
        /// Tumble, radians per second.
        let spin: Double
    }

    /// Four specks per colour, so the burst is the size of the day: one kind of
    /// win throws less than six kinds did.
    private static let perColor = 4

    private func seed() -> [Particle] {
        completedCategories.map(\.style.baseColor).flatMap { color in
            (0..<Self.perColor).map { _ in
                Particle(color: color,
                         angle: .random(in: 0...(2 * .pi)),
                         velocity: .random(in: 60...150),
                         size: .random(in: 4...8),
                         spin: .random(in: -6...6))
            }
        }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = startTime.map { timeline.date.timeIntervalSince($0) } ?? 0

            Canvas { context, size in
                let progress = min(elapsed / GridConstants.confettiDuration, 1.0)
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                // Constant acceleration, for the reason a block's fall is one
                // (CLAUDE.md, *The drop, and the dance*): things fall because
                // they fall. Sideways speed decays because a speck that light
                // is mostly air resistance.
                let gravity: Double = 60
                let sidewaysDecay = pow(0.95, elapsed * 10)
                let opacity = max(0, 1.0 - progress)

                for particle in particles {
                    let distance = particle.velocity * elapsed
                    let x = center.x + cos(particle.angle) * distance * sidewaysDecay
                    let y = center.y + sin(particle.angle) * distance
                        + 0.5 * gravity * elapsed * elapsed

                    // Its own layer, so the tumble turns the speck and not the
                    // canvas. See bug 2 above.
                    context.drawLayer { speck in
                        speck.opacity = opacity
                        speck.translateBy(x: x, y: y)
                        speck.rotate(by: .radians(particle.spin * elapsed))
                        let rect = CGRect(x: -particle.size / 2,
                                          y: -particle.size * 0.3,
                                          width: particle.size,
                                          height: particle.size * 0.6)
                        speck.fill(RoundedRectangle(cornerRadius: 1).path(in: rect),
                                   with: .color(particle.color))
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .onAppear {
            particles = seed()
            startTime = Date()
            // There is nothing here for VoiceOver to read, so the moment is
            // said rather than drawn.
            if UIAccessibility.isVoiceOverRunning {
                UIAccessibility.post(notification: .announcement,
                                     argument: "Every win logged today.")
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(Int(GridConstants.confettiDuration * 1000)))
                isActive = false
            }
        }
    }
}
