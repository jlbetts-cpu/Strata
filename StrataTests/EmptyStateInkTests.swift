import SwiftUI
import Testing
@testable import Strata

/// **An empty screen has to be a screen.**
///
/// The owner, 2026-10-01: "make sure they look good in all the states and it
/// isnt like invisable like the memories looks good but you cant really see
/// anything half the time the empty state has to look just as good."
///
/// And the owner, 2026-09-30, about the same number from the other end: "make
/// sure we aren't using any unnecessary greyscale elements, it should be fairly
/// minimal." Both are the rule in `MonthCalendarCell.wellInk(filled:)`: the
/// structure carries the page exactly as much as the content does not. These
/// tests hold both ends, so moving the number to satisfy one of his
/// instructions fails on the other.
@Suite("Empty state ink")
struct EmptyStateInkTests {

    /// The light page is 247 and `slotInk` is rgb(64, 61, 57), so an ink of `a`
    /// lands `a * (247 - 64)` levels below the page. Returned as levels,
    /// because levels are what an eye resolves and opacity is not.
    private func levels(_ ink: Double) -> Double { ink * (247 - 64) }

    @Test("a month with nothing in it reads as a surface")
    func emptyReads() {
        let ink = MonthCalendarCell.wellInk(filled: 0)
        #expect(levels(ink) >= 7,
                "an empty month's cells are \(levels(ink)) levels below the page, which is a blank page with dates on it")
    }

    @Test("a month with wins in it gets out of their way")
    func fullWhispers() {
        let ink = MonthCalendarCell.wellInk(filled: 1)
        #expect(levels(ink) <= 4,
                "a full month's cells are \(levels(ink)) levels below the page, which is the grey field he cut on 2026-09-30")
    }

    /// Monotone and continuous: a month filling up must not step.
    @Test("it only ever gets quieter as the month fills")
    func monotone() {
        var last = Double.infinity
        for i in 0...100 {
            let ink = MonthCalendarCell.wellInk(filled: Double(i) / 100)
            #expect(ink <= last + 1e-9, "the ink went back up at \(Double(i) / 100) full")
            last = ink
        }
    }

    /// Clamped at both ends, because `filled` is a ratio of two counts and a
    /// month can report more wins than elapsed days if a win lands at midnight.
    @Test("out of range is clamped rather than extrapolated")
    func clamped() {
        #expect(MonthCalendarCell.wellInk(filled: -1) == MonthCalendarCell.wellInk(filled: 0))
        #expect(MonthCalendarCell.wellInk(filled: 4) == MonthCalendarCell.wellInk(filled: 1))
    }

    /// The crossing point is reached, not approached: by 45% full the ink is
    /// already the quiet value, so the whole range below it is spent on the
    /// sparse months that need the grid.
    @Test("a month with colour on every row is already the quiet end")
    func crossing() {
        #expect(MonthCalendarCell.wellInk(filled: 0.45) == MonthCalendarCell.wellInk(filled: 1))
        #expect(MonthCalendarCell.wellInk(filled: 0.2) > MonthCalendarCell.wellInk(filled: 0.45))
    }

    /// The case the owner was actually looking at: one win, on the first of the
    /// month. It has to read as a month, so it takes the empty end.
    @Test("one win in a month is still an empty month to the eye")
    func oneWin() {
        let ink = MonthCalendarCell.wellInk(filled: 1.0 / 31)
        #expect(levels(ink) >= 7,
                "one win out of thirty-one draws its cells at \(levels(ink)) levels, which is the screen he complained about")
    }
}
