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
        // `ColourSwatch.inset`, and it was `AddWinSheet.swatchInset`. The
        // swatch became a shared component and took its three sizes with it;
        // the sheet keeps aliases for them and the inset was not one. **This
        // one line held the whole test target uncompilable for over an hour**,
        // which stops every suite in the repo rather than one — repaired here
        // by another worker rather than left, since a gate that cannot build is
        // a gate nobody can run. The arithmetic is unchanged and the constant is
        // the same number in its new home.
        #expect(ringedAir == ColourSwatch.inset)
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

    /// `PlanLines`'s source (the Plan sheet's lines, the first part of the
    /// day's page since 2026-10-05), for the one assertion that is about structure
    /// rather than a number. `#filePath` is this test file, so the view is
    /// found relative to it rather than from a working directory a test runner
    /// does not promise.
    private var planSheetPath: String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Strata/Views/PlanLines.swift").path
    }

    // MARK: - 11c, the air between things rather than after them

    /// **The empty plan is the written plan with one ghost row in it.**
    ///
    /// Both of the tests that were here are deleted with `emptyFieldShares`.
    /// They pinned the invitation to the field's golden section and checked
    /// that the floor it left was still deeper than `tailHeight` — good tests
    /// of a composition that was wrong, which is the thing worth recording:
    /// neither of them could have caught what was actually broken, because what
    /// was broken was what the invitation IS. It is row one, not a figure in a
    /// field, and it has to stand where the first real line lands. The owner:
    /// "I noticed you added the space way down for the plan even though it was
    /// supposed to show the bullet point."
    ///
    /// What replaces them is a test that the two states agree, which is the
    /// property that was actually violated.
    @Test("The empty page and the written page are the same page")
    func bothStatesAreOnePage() {
        // The tail is written once, outside the `lines.isEmpty` branch, so an
        // empty plan is one row over the same tap-to-write field a written one
        // has. It used to belong to the list alone, and that is how the same
        // emptiness came to be an affordance in one state and a check 11c
        // failure in the other.
        //
        // Read off the source, because the thing being asserted is structural:
        // a branch cannot have its own copy of this.
        let source = try! String(contentsOfFile: planSheetPath, encoding: .utf8)
        // The tail is one row deep since the day became one page
        // (2026-10-05), and the same height on an empty day and a written
        // one: since the owner's "just have the + button on the top left"
        // (2026-10-05) neither state draws words, so there is no branch left
        // for the two to drift apart in. The ＋ adds; the tail is a silent
        // place to tap.
        let tails = source.components(separatedBy: ".frame(height: Self.tailHeight)").count - 1
        #expect(tails == 1,
                "the tap-to-write tail is written \(tails) times; two copies is how the two states drift")
        #expect(!source.contains("if lines.isEmpty"),
                "the empty day has a branch of its own again; the ＋ top left is the only invitation")
        #expect(!source.contains("Text(\"Add to the plan\")"),
                "the \"Add to the plan\" words are back; the owner asked for the ＋ instead")
    }

    @Test("A plan keeps its tail, because lines flow downward")
    func aPlanIsNotCentred() {
        // A list that floated in the middle of the sheet would move every time
        // a line was added, which is the one thing a page you are typing on
        // must not do. **And the empty page is that page with one row in it**,
        // so centring the invitation moves it too — which is exactly what was
        // tried and reverted on 2026-10-01. Stated here because it is the
        // obvious next "fix" somebody will try, and it was tried.
        #expect(PlanLines.tailHeight > 0)
        let source = try! String(contentsOfFile: planSheetPath, encoding: .utf8)
        // The DECLARATION, not the word: the deletion note in that file names
        // the token so the next person finds the reasoning, and a sweep that
        // cannot tell a mention from a declaration fails on its own gravestone.
        #expect(!source.contains("static let emptyFieldShares"),
                "the empty page has a composition of its own again, which is how the invitation left row one")
    }
}
