import SwiftUI

/// Canvas-based confetti particle system for the "All done!" celebration.
/// Uses the user's ACTUAL completed category colors (Self-Relevance Effect, Rogers et al. 1977).
struct AllClearCelebration: View {
    @Binding var isActive: Bool
    var completedCategories: [HabitCategory] = HabitCategory.allCases

    @State private var startTime: Date?

    private struct Particle {
        let color: Color
        let angle: Double     // radians
        let velocity: Double  // pt/s
        let size: CGFloat
    }

    private var particles: [Particle] {
        let colors = completedCategories.map(\.style.baseColor)
        guard !colors.isEmpty else { return [] }
        var result: [Particle] = []
        // 4 particles per unique category color
        for color in colors {
            for _ in 0..<4 {
                result.append(Particle(
                    color: color,
                    angle: Double.random(in: 0...(2 * .pi)),
                    velocity: Double.random(in: 80...200),
                    size: CGFloat.random(in: 4...8)
                ))
            }
        }
        return result
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = startTime.map { timeline.date.timeIntervalSince($0) } ?? 0

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let duration = GridConstants.confettiDuration
                let progress = min(elapsed / duration, 1.0)

                for particle in particles {
                    let distance = particle.velocity * elapsed
                    let x = center.x + cos(particle.angle) * distance
                    let y = center.y + sin(particle.angle) * distance - 30 * elapsed // slight upward bias
                    let opacity = max(0, 1.0 - progress)

                    let rect = CGRect(
                        x: x - particle.size / 2,
                        y: y - particle.size / 2,
                        width: particle.size,
                        height: particle.size
                    )
                    context.opacity = opacity
                    context.fill(
                        Circle().path(in: rect),
                        with: .color(particle.color)
                    )
                }
            }
            .allowsHitTesting(false)
        }
        .onAppear {
            startTime = Date()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(Int(GridConstants.confettiDuration * 1000)))
                isActive = false
            }
        }
    }
}
