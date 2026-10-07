import Testing
import Foundation
@testable import Strata

/// **The day's strip, printed by the goal crest** (the owner, 2026-10-06).
@Suite("Day strip")
struct DayStripTests {
    @Test("a booth prints four frames at most, and a strip's date is the day's name")
    func shape() {
        #expect(DayStrip.most == 4)
        #expect(!DayStripView.date("2026-10-06").contains("2026"))
        #expect(!DayStripView.date("2026-10-06").contains("\u{2014}"))
    }

    @Test("three papers: white, warm, ink, the ink one printed in the page's colour")
    func papers() {
        #expect(StripPaper.allCases.map(\.rawValue) == ["white", "warm", "ink"])
        #expect(StripPaper.ink.type != StripPaper.white.type)
    }

    @Test("the crest's caption becomes the printer, and the page prints once a day at the goal")
    func wired() throws {
        let ring = SourceSweep.code(try SourceSweep.read("Strata/Views/GoalRing.swift"))
        #expect(ring.contains("printer: printerOpen ? Self.printerWidth : nil"))
        #expect(ring.contains(".background(alignment: .top) { stripOut }"), "the paper comes out of the slot, under the glass")
        let main = SourceSweep.code(try SourceSweep.read("Strata/Views/MainAppView.swift"))
        #expect(main.contains("DailyGoal.reached(from: old, to: new, goal: dailyGoal), stripPrintedDay != today"))
        let strip = SourceSweep.code(try SourceSweep.read("Strata/Views/DayStrip.swift"))
        #expect(!strip.contains(".shadow("), "paper separates with a hairline, as chrome does")
    }
}
