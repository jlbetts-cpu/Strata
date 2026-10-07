import SwiftUI

// MARK: - A drawing thrown onto a crew tower (2026-10-07)
//
// `TossPhysics` falls it at `dropGravity`: one tower, one g. These are the
// rest of its motion, named with every other curve. In their own file only
// because `GridConstants.swift` was being edited by another session the day
// they were added; they are the token vocabulary all the same.
extension GridConstants {
    /// A drawing's longest side on the tower, in points: seeded per drawing
    /// inside this, so two are never quite the same size.
    static let tossSide: ClosedRange<CGFloat> = 90...110
    /// Reduce Motion: a drawing appears where it would have landed.
    static let tossAppear = Animation.easeOut(duration: 0.3)
    /// A held drawing lifting off the tower before it flies.
    static var tossLift: Animation { calm(Animation.spring(response: 0.22, dampingFraction: 0.7)) }
    /// Into the bubble: quick, slowing as it goes in, as a head's flight into
    /// the same bubble does (`CrewHeadArena`).
    static let tossTuck = Animation.spring(duration: 0.42, bounce: 0.08)
    /// Live arrivals one after another, never all at once, in seconds.
    static let tossStagger: Double = 0.45
    /// The count on the bubble taking one more.
    static var tossCount: Animation { elasticPop }
}
