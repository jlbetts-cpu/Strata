import SwiftUI

/// **A size drawn with a finger is chosen by resting on it** (the owner,
/// 2026-10-16: "It only commits after I've held still in the new size or spot
/// for a short moment, shown by a quiet fill ... with a soft haptic tick as it
/// fills and a firmer one when it locks in. Let go before it fills and the
/// block springs back").
///
/// The tower's rule, where blocks were resized by accident: the slot owns
/// one, tells it where the finger is and when the size changed, and draws
/// `fill` round its own edge. `locked` is the only thing that may let a
/// drawn size through. **Not the camera's shutter** (the owner, 2026-10-17:
/// "On the camera shutter it just makes the motion slow, because you're
/// already holding it down"), which is a plain drag again.
@MainActor
@Observable
final class HoldLock {
    /// How long the finger rests at one size before it is chosen. See the
    /// launch pass log, "Intentional drawing": past a reflex and a brush,
    /// inside the second that keeps a hold feeling like one action.
    static let rest: Double = 0.45
    /// How far a resting finger may wander and still be resting: the same
    /// allowance the crew hold gives (`BlockHold.slack`).
    static let slack: CGFloat = BlockHold.slack

    /// The edge filling round, 0 to 1. Animated linearly over `rest`.
    private(set) var fill: CGFloat = 0
    /// Filled: letting go now commits.
    private(set) var locked = false

    @ObservationIgnored private var run = 0
    @ObservationIgnored private var anchor: CGPoint = .zero
    @ObservationIgnored private var active = false

    /// The finger is down and drawing: the fill starts from empty.
    func begin(at point: CGPoint) {
        active = true
        anchor = point
        restart()
    }

    /// Where the finger is now. A new size, or a finger that has wandered
    /// off its resting place, starts the fill again.
    func moved(to point: CGPoint, sizeChanged: Bool) {
        guard active else { return }
        if sizeChanged || hypot(point.x - anchor.x, point.y - anchor.y) > Self.slack {
            anchor = point
            restart()
        }
    }

    /// The finger is up, or the touch was taken away. Returns whether it was
    /// locked when it went.
    @discardableResult
    func end() -> Bool {
        let was = locked
        active = false
        run += 1
        locked = false
        withAnimation(GridConstants.slotSnap) { fill = 0 }
        return was
    }

    private func restart() {
        run += 1
        let mine = run
        locked = false
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) { fill = 0 }
        withAnimation(.linear(duration: Self.rest)) { fill = 1 }
        Task { @MainActor [weak self] in
            // Two faint ticks on the way round, then the firm one.
            for _ in 0..<2 {
                try? await Task.sleep(for: .seconds(Self.rest / 3))
                guard let self, self.run == mine, self.active else { return }
                HapticsEngine.surface()
            }
            try? await Task.sleep(for: .seconds(Self.rest / 3))
            guard let self, self.run == mine, self.active else { return }
            self.locked = true
            HapticsEngine.snap()
        }
    }
}

/// The lock's fill, drawn round the edge of whatever is being drawn out.
/// Quiet: the shape's own edge, filled by degrees, never a ring or a badge.
struct HoldLockEdge<S: InsettableShape>: View {
    let shape: S
    let fill: CGFloat
    let color: Color
    var showing: Bool = true

    var body: some View {
        // **Nothing at all at zero**, not a zero-length trim: an empty trimmed
        // path has a null rect (origin at infinity), and inside a button that
        // reached the button's own accessibility frame. Measured: the slot's
        // frame came back as infinity and every walk that pressed it died.
        if showing, fill > 0 {
            shape.inset(by: GridConstants.strokeMedium / 2)
                .trim(from: 0, to: fill)
                .stroke(color, style: StrokeStyle(lineWidth: GridConstants.strokeMedium, lineCap: .round))
                .allowsHitTesting(false)
        }
    }
}
