import SwiftUI
import UIKit

/// **A finger is down, until it lifts** (the stories standard, rule 1): told
/// when a touch lands and when it lifts or is taken by something else, and
/// never in the way of anything. A SwiftUI drag from no distance did the same
/// job and won over the story's swipe down to close (filmed, 2026-10-17);
/// this one recognises alongside every other gesture and cancels no touch.
///
/// **And the tap, from the same touch**: a SwiftUI tap beside it made it wait
/// for the tap to fail, so the hold only began when the finger lifted
/// (measured, 2026-10-17). One recogniser, one answer: a quick touch that did
/// not travel is a tap, at where it landed.
struct TouchHeld: UIGestureRecognizerRepresentable {
    let changed: (Bool) -> Void
    var tapped: ((CGPoint) -> Void)? = nil
    /// Under this, a touch is a tap.
    static let tapLength: TimeInterval = 0.3

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let press = UILongPressGestureRecognizer()
        press.minimumPressDuration = 0
        // A swipe across or down is the pager's or the close's; the hold
        // ends as the finger travels, and they take it from there.
        press.allowableMovement = 24
        press.cancelsTouchesInView = false
        press.delaysTouchesBegan = false
        press.delaysTouchesEnded = false
        press.delegate = context.coordinator
        return press
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .began:
            context.coordinator.landed = Date()
            changed(true)
        case .ended:
            changed(false)
            if let landed = context.coordinator.landed, Date().timeIntervalSince(landed) < Self.tapLength {
                tapped?(context.converter.localLocation)
            }
            context.coordinator.landed = nil
        case .cancelled, .failed:
            context.coordinator.landed = nil
            changed(false)
        default: break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var landed: Date?

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    }
}
