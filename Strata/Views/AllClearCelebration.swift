import SwiftUI

/// Canvas-based confetti particle system for the "All done!" celebration.
/// Uses the user's ACTUAL completed category colors (Self-Relevance Effect, Rogers et al. 1977).
struct AllClearCelebration: View {
    @Binding var isActive: Bool
    var completedCategories: [HabitCategory] = HabitCategory.selectable

    // Decorative confetti — hidden from VoiceOver

    @State private var startTime: Date?

    // #47: Shape variety — rectangles 40%, circles 30%, strips 30%
    private enum ParticleShape {
        case rectangle, circle, strip
    }

    private struct Particle {
        let color: Color
        let angle: Double     // radians
        let velocity: Double  // pt/s
        let size: CGFloat
        let rotation: Double  // tumble speed (radians/s)
        let shape: ParticleShape
    }

    private var particles: [Particle] {
        let colors = completedCategories.map(\.style.baseColor)
        guard !colors.isEmpty else { return [] }
        var result: [Particle] = []
        for color in colors {
            for i in 0..<4 {
                // #47: Varied shapes — rectangles, circles, strips
                let shape: ParticleShape = switch i % 10 {
                case 0...3: .rectangle   // 40%
                case 4...6: .circle      // 30%
                default: .strip          // 30%
                }
                result.append(Particle(
                    color: color,
                    angle: Double.random(in: 0...(2 * .pi)),
                    velocity: Double.random(in: 60...150),
                    size: CGFloat.random(in: 4...8),
                    rotation: Double.random(in: -6...6),
                    shape: shape
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

                // #46: Confetti gravity — 60pt/s² downward + horizontal damping
                let gravity: Double = 60.0
                let horizontalDamping: Double = 0.95

                for particle in particles {
                    let distance = particle.velocity * elapsed
                    // #46: Apply gravity and horizontal damping
                    let hDamp = pow(horizontalDamping, elapsed * 10)
                    let x = center.x + cos(particle.angle) * distance * hDamp
                    let y = center.y + sin(particle.angle) * distance + 0.5 * gravity * elapsed * elapsed
                    let opacity = max(0, 1.0 - progress)
                    let tumble = particle.rotation * elapsed

                    // #47: Shape-specific rendering
                    let rect: CGRect
                    switch particle.shape {
                    case .rectangle:
                        rect = CGRect(x: x - particle.size / 2, y: y - particle.size / 2,
                                     width: particle.size, height: particle.size * 0.6)
                    case .circle:
                        rect = CGRect(x: x - particle.size / 2, y: y - particle.size / 2,
                                     width: particle.size, height: particle.size)
                    case .strip:
                        rect = CGRect(x: x - particle.size * 0.2, y: y - particle.size,
                                     width: particle.size * 0.4, height: particle.size * 2)
                    }

                    context.opacity = opacity
                    context.rotate(by: .radians(tumble))
                    switch particle.shape {
                    case .circle:
                        context.fill(Circle().path(in: rect), with: .color(particle.color))
                    default:
                        context.fill(RoundedRectangle(cornerRadius: 1).path(in: rect), with: .color(particle.color))
                    }
                    context.rotate(by: .radians(-tumble))
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .onAppear {
            startTime = Date()
            // #134: Celebration alternative for VoiceOver
            if UIAccessibility.isVoiceOverRunning {
                UIAccessibility.post(notification: .announcement, argument: "Every win logged today.")
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(Int(GridConstants.confettiDuration * 1000)))
                isActive = false
            }
        }
    }
}
