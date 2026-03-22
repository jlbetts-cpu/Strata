import SwiftUI

struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                if reduceMotion {
                    Color.white.opacity(0.08)
                } else {
                    TimelineView(.animation) { timeline in
                        let phase = timeline.date.timeIntervalSinceReferenceDate
                            .truncatingRemainder(dividingBy: 1.5) / 1.5
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: max(0, phase - 0.15)),
                                .init(color: .white.opacity(0.20), location: phase),
                                .init(color: .clear, location: min(1, phase + 0.15))
                            ],
                            startPoint: UnitPoint(x: -0.2, y: 0),
                            endPoint: UnitPoint(x: 1.2, y: 0.35)
                        )
                    }
                }
            }
            .allowsHitTesting(false)
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
