import Testing
import SwiftUI
@testable import Strata

/// **Check 11 of `docs/screen-audit.md`, for the two sheets that failed it
/// worst, stated as arithmetic.**
///
/// The clauses themselves are measured off a capture with `tools/page-room.py`,
/// and nothing here replaces that — a number cannot see a screen. What a test
/// CAN hold is the thing a measurement discovers and then forgets: the
/// composition each sheet was rebuilt on, so that the next person to add a
/// control to one of them cannot quietly put the page back to having one
/// rhythm without a red test saying so.
///
/// Both sheets failed the same two clauses on 2026-10-01 and for the same
/// reason, which `docs/space.md` names: a page whose gaps all sit in the middle
/// has one spacing, and by the pure distance law (Kubovy, Holcombe and
/// Wagemans 1998) one spacing groups nothing, because proximity reads the
/// RATIO between competing distances and not their difference.
@Suite("The add sheet and the plan have room")
struct SheetRoomTests {

    /// The biggest step the spacing ladder itself takes: 8 → 12 and 16 → 24 are
    /// both 1.5. Anything at or under this is a rung, not a break.
    private let ladderStep: CGFloat = 1.5

    // MARK: - 11b, both ends of the ladder on one page

    @Test("A break is outside any step the ladder takes")
    func aBreakIsNotARung() {
        // This is why `gapPage` had to be added at all rather than
        // `gapSection` being used harder: 32 against a page of 24s is 1.33,
        // which IS the ladder's step, so it cannot read as a different kind of
        // thing however carefully it is placed.
        #expect(GridConstants.gapSection / GridConstants.gapWide <= ladderStep)
        #expect(GridConstants.gapPage / GridConstants.gapSection > ladderStep)
        #expect(GridConstants.gapPage / GridConstants.gapWide > ladderStep)
    }

    @Test("The add sheet's break clears check 11b's 48pt floor")
    func theBreakClearsTheFloor() {
        // 11b asks for at least one gap of 48pt or more. The add sheet's
        // between-group break and its floor are both `gapPage`, so the clause
        // is met by the token rather than by a number somebody chose for this
        // screen.
        #expect(GridConstants.gapPage >= 48)
    }

    @Test("The add sheet's tight end clears check 11b's 17pt ceiling")
    func theTightEndClearsTheCeiling() {
        // 11b also asks for at least one gap of 17pt or less, and the gap a
        // CAPTURE measures is the declared gap plus whatever empty box each
        // band carries: a measured band is ink, and the colour row's ink is a
        // 38pt selection ring inside a 44pt target.
        //
        // So the tight gap on this sheet — the colour row to the size picker,
        // which is `gapItem` because they are two items in one set — renders
        // as 12 plus that air. If the target or the artwork ever moves far
        // enough that the sum passes 17, the sheet loses the tight end of its
        // ladder and 11b fails with nothing on screen looking different.
        //
        // Both states are checked. A swatch with the selection ring on it is
        // 38 wide, which is what the add sheet always opens showing (15.0pt
        // measured); the worst case is a bare 34pt circle in the same box, and
        // that is the 17.0 that sits exactly on the clause's line.
        let ringedAir = (AddWinSheet.swatchTarget - AddWinSheet.selectionRingSide) / 2
        let bareAir = (AddWinSheet.swatchTarget - AddWinSheet.swatchSide) / 2
        #expect(ringedAir == AddWinSheet.swatchInset)
        #expect(GridConstants.gapItem + ringedAir <= 17)
        #expect(GridConstants.gapItem + bareAir <= 17)
    }

    @Test("The two ends of the add sheet's ladder are a different kind of thing")
    func theTwoEndsAreNotTheSameRung() {
        // The failing sheet had seven gaps between 10.3 and 33.3pt: a 3.2x
        // span, every value a plausible neighbour of the next. The rebuilt one
        // puts `gapTight` inside a group and `gapPage` between groups.
        let span = GridConstants.gapPage / GridConstants.gapTight
        #expect(span == 8)
    }

    // MARK: - 11c, the air between things rather than after them

    @Test("The empty plan stands on the field's golden section")
    func theEmptyPlanSplitsOnPhi() {
        // `PlanSheet.content` writes `pageSpace` this many times on each side
        // of the invitation, and flexible children of a `VStack` divide the
        // slack equally, so this ratio IS the composition.
        //
        // 8 : 5 is the Fibonacci pair nearest φ. Two things are checked rather
        // than the pair being named: that it approximates φ, and that it beats
        // the ladder's own biggest step, because a split at or under 1.5 leaves
        // the break above and the floor below reading as the same white and
        // 11c decided by a point or two.
        let shares = PlanSheet.emptyFieldShares
        let ratio = CGFloat(shares.above) / CGFloat(shares.below)
        #expect(ratio > ladderStep)
        #expect(abs(ratio - 1.6180339887) < 0.02)
    }

    @Test("The empty plan's floor is still deeper than the tap tail")
    func theEmptyPlanFloorIsStillATarget() {
        // The floor under the invitation is not only composition: it is the
        // tap-to-write space, and `tailHeight` is the depth the audit settled
        // on for that ("deep enough to be aimed at rather than found by
        // accident"). A split that bought a composition by making the target
        // shallower would be trading a real affordance for a measurement.
        //
        // 402x874: 781pt of usable band, less about 50 for the sheet's grabber
        // and toolbar, less the invitation's own row, which is the bullet's
        // 44pt box.
        let field: CGFloat = 781 - 50
        let invitation: CGFloat = 44
        let shares = PlanSheet.emptyFieldShares
        let floor = (field - invitation)
            * CGFloat(shares.below) / CGFloat(shares.above + shares.below)
        #expect(floor >= PlanSheet.tailHeight)
    }

    @Test("A written plan keeps its tail, because lines flow downward")
    func aWrittenPlanIsNotCentred() {
        // The shares apply to the EMPTY page only. A list that floated in the
        // middle of the sheet would move every time a line was added, which is
        // the one thing a page you are typing on must not do. Stated here
        // because it is the obvious next "fix" somebody will try.
        #expect(PlanSheet.tailHeight > 0)
        #expect(PlanSheet.emptyFieldShares.above > PlanSheet.emptyFieldShares.below)
    }
}
