import Testing
import CoreGraphics
@testable import Strata

/// The thresholds you draw a block's size through.
///
/// These were inferred from screenshots for as long as the maths lived inside
/// `NextSlotButton`, where nothing could reach it. They are the reason the
/// camera shutter and the tower's slot can now be trusted to agree: both call
/// `BlockSizeDraw`, and a change to either has to break one of these first.
@Suite("Drawing a block's size")
struct BlockSizeDrawTests {

    private let step = GridConstants.slotStep               // 46
    private let back = GridConstants.slotStepHysteresis     // 12

    // MARK: - Growing

    @Test("a still finger is one cell")
    func stillIsSmall() {
        #expect(BlockSizeDraw.size(lateral: 0, up: 0, from: .small) == .small)
    }

    @Test("sideways commits to medium at a full step, and not a point before")
    func lateralThreshold() {
        #expect(BlockSizeDraw.size(lateral: step - 0.5, up: 0, from: .small) == .small)
        #expect(BlockSizeDraw.size(lateral: step, up: 0, from: .small) == .medium)
    }

    @Test("up commits to hard at a full step, and not a point before")
    func upwardThreshold() {
        #expect(BlockSizeDraw.size(lateral: 0, up: step - 0.5, from: .small) == .small)
        #expect(BlockSizeDraw.size(lateral: 0, up: step, from: .small) == .hard)
    }

    /// The whole point of drawing rather than picking: one gesture reaches the
    /// biggest block. If this fails, `hard` is only reachable by dragging
    /// sideways first, which nobody would discover.
    @Test("hard is reachable from small in one gesture")
    func hardInOneGesture() {
        #expect(BlockSizeDraw.size(lateral: 0, up: step * 2, from: .small) == .hard)
    }

    // MARK: - Direction

    /// A wide pull that drifts upward used to produce the tall block — a shape
    /// you did not ask for and could not predict.
    @Test("direction must be decisive, not merely present")
    func decisiveDirection() {
        // Both axes past the step, but mostly sideways.
        #expect(BlockSizeDraw.size(lateral: step + 20, up: step, from: .small) == .medium)
        // Mostly upward.
        #expect(BlockSizeDraw.size(lateral: step, up: step + 20, from: .small) == .hard)
    }

    @Test("exactly 45 degrees is a sideways drag, not an upward one")
    func fortyFiveDegreesIsLateral() {
        // `goingUp` is `up > lateral`, so a tie is lateral. Stated as a test
        // because a tie is where a tremor lands and it must not flicker.
        #expect(BlockSizeDraw.size(lateral: step, up: step, from: .small) == .medium)
    }

    @Test("dragging down grows nothing")
    func downwardIsInert() {
        let axes = BlockSizeDraw.axes(translation: CGSize(width: 0, height: 200))
        #expect(axes.up == 0)
        #expect(BlockSizeDraw.size(lateral: axes.lateral, up: axes.up, from: .small) == .small)
    }

    @Test("left and right are the same gesture")
    func lateralIsSymmetric() {
        let right = BlockSizeDraw.axes(translation: CGSize(width: step, height: 0))
        let left = BlockSizeDraw.axes(translation: CGSize(width: -step, height: 0))
        #expect(right.lateral == left.lateral)
    }

    // MARK: - The deadband

    /// Growth commits at 46 and shrink at 34. A finger resting on a threshold
    /// must not flicker between two sizes on the tremors of a real hand.
    @Test("medium survives until a full hysteresis back")
    func shrinkDeadband() {
        #expect(BlockSizeDraw.size(lateral: step - back, up: 0, from: .medium) == .medium)
        #expect(BlockSizeDraw.size(lateral: step - back - 0.5, up: 0, from: .medium) == .small)
    }

    @Test("hard survives until a full hysteresis back")
    func hardShrinkDeadband() {
        #expect(BlockSizeDraw.size(lateral: 0, up: step - back, from: .hard) == .hard)
        #expect(BlockSizeDraw.size(lateral: 0, up: step - back - 0.5, from: .hard) == .small)
    }

    /// Holding it tall does not demand you keep winning the argument about
    /// direction — only that the height is still being asked for.
    @Test("hard holds on height alone, even while mostly sideways")
    func hardHoldsOnHeight() {
        #expect(BlockSizeDraw.size(lateral: step * 3, up: step, from: .hard) == .hard)
    }

    @Test("coming down off hard lands on medium when the width is still held")
    func hardToMedium() {
        #expect(BlockSizeDraw.size(lateral: step, up: 0, from: .hard) == .medium)
    }

    // MARK: - Resistance

    @Test("inside the last stop, a drag tracks the finger exactly")
    func oneToOneInsideTheStop() {
        #expect(BlockSizeDraw.resisted(0) == 0)
        #expect(BlockSizeDraw.resisted(step) == step)
        #expect(BlockSizeDraw.resisted(step - 1) == step - 1)
    }

    /// Past the stop it must keep moving — stopping dead reads as the gesture
    /// breaking — but give back progressively less. `apple-design.md` §9.
    @Test("past the last stop, resistance gives back less and less")
    func rubberbandsPastTheStop() {
        let a = BlockSizeDraw.resisted(step + 40)
        let b = BlockSizeDraw.resisted(step + 80)
        #expect(a > step)                 // still moving
        #expect(a < step + 40)            // but resisted
        #expect(b > a)                    // monotonic
        #expect(b - a < 40)               // and flattening
    }
}
