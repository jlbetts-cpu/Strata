import SwiftUI

/// Drawing a block's size out of a control, with the finger.
///
/// Press, pull sideways for a wide block, pull up for a tall one. This lived
/// inside `NextSlotButton` as three private functions and was the only place
/// in the app where a size could be expressed as a gesture — which meant the
/// camera, the other thing you press to make a win, could only ever produce a
/// 1x1.
///
/// It is a value type with no view in it so both controls can share one
/// answer, and so the thresholds can be tested at the boundary rather than
/// inferred from a screenshot.
///
/// **The direction you drag is the direction the block grows.** Sideways
/// widens it; up makes it tall. That is not a mapping to learn, because the
/// sizes are literally those shapes: `medium` is 2x1 and `hard` is 2x2, so
/// pulling sideways makes the wide one and pulling up adds the height.
enum BlockSizeDraw {

    /// The size a drag has committed to, with a deadband on the way back.
    ///
    /// Growing takes a full `slotStep`; shrinking gives one back only after
    /// coming `slotStepHysteresis` further, so a finger resting on a threshold
    /// does not flicker between two sizes on the tremors of a real hand.
    /// Measured in points from where the finger went down: 46 to grow, 34 to
    /// shrink.
    ///
    /// - Parameters:
    ///   - lateral: absolute horizontal distance. Left and right are the same
    ///     gesture — the block grows to the right either way, because it grows
    ///     into the tower's grid and the grid does not care which hand you use.
    ///   - up: upward distance only. **A downward drag contributes nothing**,
    ///     which is why the caller passes `max(-translation.height, 0)` rather
    ///     than an absolute value: down is not a direction a block grows.
    ///   - current: the size the gesture is already showing. The deadband is
    ///     relative to it, so this is a state machine and not a pure map from
    ///     distance to size.
    static func size(lateral: CGFloat, up: CGFloat, from current: BlockSize) -> BlockSize {
        let step = GridConstants.slotStep
        let back = GridConstants.slotStepHysteresis
        // The direction has to be DECISIVE, not merely present. Reaching the
        // upward threshold while pulling mostly sideways used to give the tall
        // block, so a wide pull that drifted upward produced a shape you did
        // not ask for and could not predict. Past 45 degrees it is an upward
        // drag; below it, a sideways one.
        let goingUp = up > lateral

        switch current {
        case .small:
            if goingUp && up >= step { return .hard }
            return lateral >= step ? .medium : .small
        case .medium:
            if goingUp && up >= step { return .hard }
            return lateral >= step - back ? .medium : .small
        case .hard:
            // Holding it tall does not demand you keep winning the argument
            // about direction — only that the height is still being asked for.
            if up >= step - back { return .hard }
            return lateral >= step - back ? .medium : .small
        }
    }

    /// Resistance past the last stop on an axis.
    ///
    /// Each axis has exactly one meaningful step, so the limit is one step.
    /// Dragging beyond it has nowhere to go: stopping dead reads as the
    /// gesture breaking, while giving back progressively less reads as having
    /// reached the end of something real. `docs/apple-design.md` §9.
    static func resisted(_ distance: CGFloat) -> CGFloat {
        let limit = GridConstants.slotStep
        guard distance > limit else { return distance }
        return limit + GridConstants.rubberband(
            overshoot: distance - limit,
            dimension: GridConstants.slotStep
        )
    }

    /// Both axes of a translation, resisted, ready for `size(lateral:up:from:)`.
    ///
    /// One function so no caller can forget that down is not a direction.
    static func axes(translation: CGSize) -> (lateral: CGFloat, up: CGFloat) {
        (resisted(abs(translation.width)),
         resisted(max(-translation.height, 0)))
    }
}
