import SwiftUI
import UIKit

/// **Swipe a plan line to delete it** (2026-10-05).
///
/// `.swipeActions` is what was asked for, and it only exists inside a `List`;
/// the plan is a `LazyVStack` in a `ScrollView` (its page, its tail and its
/// row-one invitation are all LOCKED, `docs/design.md`), which is exactly why
/// the swipe that was here once did nothing at all and became a context menu.
/// So the swipe is drawn here, to the platform's own rules: left reveals
/// Delete, a long swipe deletes outright, a short one springs back, and a
/// swipe right closes it.
///
/// **The gesture is UIKit's, and only ever horizontal.** CLAUDE.md measured a
/// SwiftUI drag on scroll content taking the scroll with it (0.0pt over a
/// whole fling on the tower). A `UIPanGestureRecognizer` whose delegate
/// refuses to begin unless the movement is mostly sideways never touches a
/// vertical scroll: a vertical drag fails it at once and the page scrolls.
///
/// **Delete is the kit's red WORD, not a red slab.** The owner settled that
/// for the edit sheet on 2026-10-02 ("Red word": the pill measured 3.96:1 in
/// dark, the word 5.73:1), and a filled red panel is the same pill at a
/// different size.
nonisolated enum PlanSwipe {
    /// How far an open row stands to the left: the Delete word and its air.
    static let revealWidth: CGFloat = 88
    /// Past this share of the row, letting go deletes.
    static let deleteShare: CGFloat = 0.55
    /// A flick at this speed (pt/s) opens or closes whatever the distance.
    static let flick: CGFloat = 600

    enum Outcome: Equatable { case closed, open, delete }

    /// Where the row stands for a finger's translation. Left freely; right of
    /// its rest only a little, rubber-banded, never a hard stop.
    static func offset(translation: CGFloat, wasOpen: Bool) -> CGFloat {
        let raw = (wasOpen ? -revealWidth : 0) + translation
        guard raw > 0 else { return raw }
        return 8 * (1 - 1 / (raw / 40 + 1))
    }

    static func outcome(translation: CGFloat, velocity: CGFloat,
                        rowWidth: CGFloat, wasOpen: Bool) -> Outcome {
        let position = (wasOpen ? -revealWidth : 0) + translation
        if position <= -rowWidth * deleteShare { return .delete }
        if velocity >= flick { return .closed }
        if velocity <= -flick { return .open }
        return position < -revealWidth / 2 ? .open : .closed
    }
}

/// The swipe on one row. The caller owns which row is open, so opening one
/// closes any other, the way Mail and Reminders behave.
struct PlanSwipeToDelete: ViewModifier {
    let isOpen: Bool
    var setOpen: (Bool) -> Void
    var onDelete: () -> Void

    @State private var drag: CGFloat?
    @State private var width: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var offset: CGFloat {
        if let drag { return PlanSwipe.offset(translation: drag, wasOpen: isOpen) }
        return isOpen ? -PlanSwipe.revealWidth : 0
    }

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .background(alignment: .trailing) {
                // Only as wide as the row has moved, so nothing of it shows
                // on a row at rest.
                // The caller's delete makes the haptic.
                Button {
                    onDelete()
                } label: {
                    Text("Delete")
                        .font(Typography.headerSmall)
                        .foregroundStyle(AppColors.destructiveInk)
                        .lineLimit(1)
                        .fixedSize()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressWord)
                .frame(width: max(0, -offset))
                .opacity(min(1, max(0, -offset) / (PlanSwipe.revealWidth * 0.6)))
                .clipped()
                .accessibilityHidden(true)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .gesture(SidewaysPan(
                changed: { drag = $0 },
                ended: { translation, velocity in
                    let outcome = PlanSwipe.outcome(translation: translation, velocity: velocity,
                                                    rowWidth: max(width, 1), wasOpen: isOpen)
                    if outcome == .delete {
                        drag = nil
                        onDelete()
                        return
                    }
                    withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy) {
                        drag = nil
                        setOpen(outcome == .open)
                    }
                }))
            // VoiceOver and Switch Control reach it without a swipe.
            .accessibilityAction(named: "Delete") { onDelete() }
    }
}

/// A pan that begins only when the finger is moving more sideways than up or
/// down, so a vertical scroll is never taken.
private struct SidewaysPan: UIGestureRecognizerRepresentable {
    var changed: (CGFloat) -> Void
    var ended: (_ translation: CGFloat, _ velocity: CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let x = recognizer.translation(in: recognizer.view).x
        switch recognizer.state {
        case .changed:
            changed(x)
        case .ended, .cancelled, .failed:
            ended(x, recognizer.velocity(in: recognizer.view).x)
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return false }
            let v = pan.velocity(in: pan.view)
            return abs(v.x) > abs(v.y) * 1.2
        }
    }
}
