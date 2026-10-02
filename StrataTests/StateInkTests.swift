import SwiftUI
import Testing
@testable import Strata

/// **Check 12: a screen is rated in every state it can be in, and nothing
/// carrying information may sit under 4 levels of its ground in any of them.**
///
/// `EmptyStateInkTests` holds `MonthCalendarCell.wellInk(filled:)`, which was
/// the first component written to that rule. These two were found by
/// photographing the same screens in the states that rule is about, and they
/// are held here for the same reason: each one satisfies one of the owner's two
/// instructions in a way that must not break the other.
@Suite("A day that has not happened yet")
struct FutureDayInkTests {

    /// The light page is 247 and `slotInk` is rgb(64, 61, 57), so an ink of `a`
    /// lands `a * (247 - 64)` levels below the page. Levels, because levels are
    /// what an eye resolves and opacity is not. Same arithmetic as
    /// `EmptyStateInkTests`, deliberately.
    private func levels(_ ink: Double) -> Double { ink * (247 - 64) }

    /// The well's own full-month step, and the rim's. Both are the values that
    /// shipped before the ramp existed, and the tests below pin that they still
    /// render on a full month.
    private let wellStep = 0.45
    private let rimStep = 0.533

    /// **The state the owner signed off on 2026-09-30 must render to the
    /// pixel.** It is the whole reason `futureStep` takes the full-month value
    /// as an argument instead of owning one.
    @Test("a full month steps back exactly as far as it always did")
    func fullMonthUnchanged() {
        #expect(MonthCalendarCell.futureStep(filled: 1, full: wellStep) == wellStep)
        #expect(MonthCalendarCell.futureStep(filled: 0.45, full: wellStep) == wellStep)
        let rim = 0.75 * MonthCalendarCell.futureStep(filled: 1, full: rimStep)
        #expect(abs(rim - 0.4) < 0.001,
                "the rim renders at \(rim) on a full month, and it shipped at 0.4")
    }

    /// The defect this was written for: on 1 October with nothing logged, every
    /// day but one is a future day, so a step tuned for the tail of a month was
    /// being applied to the whole page.
    @Test("a bare month's future days clear the 4-level floor")
    func bareMonthReads() {
        let ink = MonthCalendarCell.wellInk(filled: 0)
            * MonthCalendarCell.futureStep(filled: 0, full: wellStep)
        #expect(levels(ink) >= 5,
                "a bare month draws thirty of its thirty-one cells at \(levels(ink)) levels, which is the screen he could not see")
    }

    /// And the other end of it. The only thing marking today on a bare month is
    /// that its cell is the one that did not step back, so the step may shorten
    /// but it may never close.
    @Test("today is still a different weight from a day that has not come")
    func todayStaysMarked() {
        let today = MonthCalendarCell.wellInk(filled: 0)
        let future = today * MonthCalendarCell.futureStep(filled: 0, full: wellStep)
        let ratio = today / future
        #expect(ratio >= 1.34,
                "today is \(ratio)x a future day on a bare month, and 1.33 is one rung of this app's own ladder")
    }

    /// Monotone and continuous: a month filling up must not step.
    ///
    /// **It shortens as the month fills, and the first version of this test
    /// asserted the opposite** (fixed 2026-10-01). The direction follows from
    /// what the number is for: on a bare month the grid is the only thing on the
    /// page, so a day that has not come round yet still has to be part of it and
    /// steps back only to `stepBare` (0.72). On a full month the colour carries
    /// the page and a future day can get further out of the way, down to
    /// `wellStep`. A test written in the wrong direction passes for a while on a
    /// constant and fails the moment the constant becomes a function, which is
    /// what happened here.
    @Test("the step only ever shortens as the month fills")
    func monotone() {
        var last = Double.infinity
        for i in 0...100 {
            let step = MonthCalendarCell.futureStep(filled: Double(i) / 100, full: wellStep)
            #expect(step <= last + 1e-9, "the step went back the other way at \(Double(i) / 100) full")
            last = step
        }
        #expect(MonthCalendarCell.futureStep(filled: 0, full: wellStep)
                > MonthCalendarCell.futureStep(filled: 1, full: wellStep),
                "a future day on a bare month has to stand closer to the grid than one on a full month")
    }

    /// `filled` is a ratio of two counts and a month can report more wins than
    /// days if one lands at midnight.
    @Test("out of range is clamped rather than extrapolated")
    func clamped() {
        #expect(MonthCalendarCell.futureStep(filled: -1, full: wellStep)
                == MonthCalendarCell.futureStep(filled: 0, full: wellStep))
        #expect(MonthCalendarCell.futureStep(filled: 4, full: wellStep)
                == MonthCalendarCell.futureStep(filled: 1, full: wellStep))
    }
}

/// **A ring round the only option is not structure, it is decoration that looks
/// like structure.**
///
/// The owner, 2026-09-30: "make sure we aren't using any unnecessary greyscale
/// elements, it should be fairly minimal." Photographed with one head, the
/// chosen ring is the loudest mark in the section (4.0:1 light, 5.0:1 dark) and
/// there is no second head for that head to have been chosen instead of.
@Suite("The head picker's chosen ring")
struct HeadPickerRingTests {

    @Test("one head gets no ring, because there is nothing to choose between")
    func oneHead() {
        #expect(HeadPickerRow.ringInk(isChosen: true, entries: 1) == 0)
    }

    @Test("two heads get the ring back on the chosen one")
    func twoHeads() {
        #expect(HeadPickerRow.ringInk(isChosen: true, entries: 2) == 0.55)
        #expect(HeadPickerRow.ringInk(isChosen: false, entries: 2) == 0)
    }

    /// The empty roster draws no tiles at all, so this is unreachable rather
    /// than wrong; it is pinned so the rule cannot be read as "fewer than two".
    @Test("no heads is no ring")
    func noHeads() {
        #expect(HeadPickerRow.ringInk(isChosen: true, entries: 0) == 0)
    }
}
