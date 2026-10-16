import SwiftUI
import UIKit

/// **A pan that begins only one way** (the interaction audit, 2026-10-15):
/// down, to close a photograph as Photos and Instagram do; right, to reply
/// to a chat line as Messages does. UIKit's, as `PlanSwipe`'s is, because a
/// SwiftUI drag on scroll content takes the scroll with it: this one refuses
/// to begin unless the finger is going its way, so a page swiped sideways
/// still pages and a thread dragged up still scrolls.
struct OneWayPan: UIGestureRecognizerRepresentable {
    enum Way { case down, right }

    let way: Way
    /// Whether it may begin now (a zoomed photograph pans instead).
    var allows: () -> Bool = { true }
    /// How far along its way the finger has gone, never less than nothing.
    var changed: (CGFloat) -> Void
    /// How far it went, and how fast it was going, when it let go.
    var ended: (_ distance: CGFloat, _ speed: CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        context.coordinator.way = way
        context.coordinator.allows = allows
        return pan
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        context.coordinator.allows = allows
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let moved = recognizer.translation(in: recognizer.view)
        let speed = recognizer.velocity(in: recognizer.view)
        let along = way == .down ? moved.y : moved.x
        switch recognizer.state {
        case .changed:
            changed(max(0, along))
        case .ended, .cancelled, .failed:
            ended(max(0, along), way == .down ? speed.y : speed.x)
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var way: Way = .down
        var allows: () -> Bool = { true }

        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard allows(), let pan = recognizer as? UIPanGestureRecognizer else { return false }
            let v = pan.velocity(in: pan.view)
            switch way {
            case .down: return v.y > 0 && v.y > abs(v.x) * 1.3
            case .right: return v.x > 0 && v.x > abs(v.y) * 1.5
            }
        }
    }
}

/// **Swipe a chat line right to reply**, as Messages and Instagram do (the
/// interaction audit, 2026-10-15): the line follows the finger a little, a
/// reply arrow comes up beside it, and past the mark it ticks; let go there
/// and the line is quoted over the field. Its own state, so a line being
/// pulled redraws only itself, never the thread.
struct SwipeToReply: ViewModifier {
    let reply: () -> Void

    @State private var pull: CGFloat = 0
    @State private var armed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let mark: CGFloat = 56

    /// The line follows less the further it goes, to no more than 64.
    static func give(_ distance: CGFloat) -> CGFloat {
        64 * (1 - 1 / (distance / 64 + 1))
    }

    func body(content: Content) -> some View {
        content
            .offset(x: pull)
            .overlay(alignment: .leading) {
                Image(systemName: "arrowshape.turn.up.left")
                    .iconSize(GridConstants.iconToolbar, relativeTo: .body, weight: .medium)
                    .foregroundStyle(AppColors.inkSecondary)
                    .scaleEffect(armed ? 1 : 0.8)
                    .opacity(Double(max(0, min(1, (pull - 8) / 24))))
                    .offset(x: pull - 32)
                    .accessibilityHidden(true)
            }
            .gesture(OneWayPan(way: .right, changed: { distance in
                pull = Self.give(distance)
                let past = distance > Self.mark
                if past != armed {
                    armed = past
                    if past { HapticsEngine.tick() }
                }
            }, ended: { distance, _ in
                if distance > Self.mark { reply() }
                withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy) {
                    pull = 0
                    armed = false
                }
            }))
    }
}
