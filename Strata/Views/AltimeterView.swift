import SwiftUI

// MARK: - Tower Scrubber View (floating glass pill)

struct TowerScrubberView: View {
    let towerContentHeight: CGFloat
    let scrollOffset: CGFloat
    let viewportHeight: CGFloat
    let heightMeters: Double
    let topInset: CGFloat
    let onScrub: (CGFloat) -> Void

    @State private var isScrubbing = false
    @State private var scrubFraction: CGFloat = 0

    private let pillWidth: CGFloat = 36
    private let pillHeight: CGFloat = 40
    private let bottomPadding: CGFloat = 48

    private var trackHeight: CGFloat {
        viewportHeight - topInset - bottomPadding
    }

    /// Scroll fraction computed from external scroll offset
    private var scrollFraction: CGFloat {
        guard towerContentHeight > viewportHeight else { return 0 }
        let maxOffset = viewportHeight - towerContentHeight
        let fraction = 1.0 - (scrollOffset / maxOffset)
        return min(1, max(0, fraction))
    }

    private var effectiveFraction: CGFloat {
        isScrubbing ? scrubFraction : scrollFraction
    }

    private var pillOffset: CGFloat {
        effectiveFraction * (trackHeight - pillHeight)
    }

    private var meterLabel: String {
        if heightMeters < 1 { return "0m" }
        if heightMeters >= 1000 {
            return String(format: "%.1fkm", heightMeters / 1000)
        }
        return "\(Int(heightMeters))m"
    }

    var body: some View {
        ZStack(alignment: .top) {
            Text(meterLabel)
                .font(Typography.bodySmall)
                .foregroundStyle(Color.primary)
                .frame(width: pillWidth, height: pillHeight)
                .background(Color(.systemBackground).opacity(0.3))
                .glassEffect(.regular, in: .capsule)
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
                .offset(y: pillOffset)
                .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.8), value: pillOffset)
        }
        .frame(width: pillWidth, height: trackHeight)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    isScrubbing = true
                    let fraction = min(1, max(0, drag.location.y / trackHeight))
                    let oldFraction = scrubFraction
                    scrubFraction = fraction
                    // Tick haptic on meaningful scrub movement
                    if abs(fraction - oldFraction) > 0.02 {
                        HapticsEngine.tick()
                    }
                    onScrub(fraction)
                }
                .onEnded { _ in
                    isScrubbing = false
                }
        )
    }
}
