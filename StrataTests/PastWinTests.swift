import Testing
import Foundation
@testable import Strata

/// The past win under the Memories calendar and in the evening notification.
@Suite("Past win")
struct PastWinTests {
    let calendar = Calendar(identifier: .gregorian)
    let today = DateUtils.date(from: "2026-10-05")!

    func c(_ title: String, _ day: String) -> PastWin.Candidate { .init(title: title, dateString: day) }

    @Test func theSameDateAYearBackComesFirst() {
        let pick = PastWin.pick(from: [c("Old run", "2026-01-02"), c("Morning run", "2025-10-05")],
                                today: today, calendar: calendar)
        #expect(pick?.line == "A year ago today: Morning run")
        #expect(pick?.dateString == "2025-10-05")
    }

    @Test func otherwiseAnOrdinaryWinFourWeeksOldOrMore() {
        let pick = PastWin.pick(from: [c("Last week", "2026-09-30"), c("Called Mum", "2026-03-04")],
                                today: today, calendar: calendar)
        #expect(pick?.title == "Called Mum")
        #expect(pick?.when == "March 4")
    }

    @Test func nothingNamelessAndNothingRecent() {
        #expect(PastWin.pick(from: [c(QuickWinService.untitled, "2025-10-05"), c("", "2026-01-01"),
                                    c("Yesterday", "2026-10-04")], today: today, calendar: calendar) == nil)
    }

    @Test func theSameWinAllDay() {
        let many = (1...20).map { c("Win \($0)", "2026-0\($0 % 9 + 1)-01") }
        let morning = PastWin.pick(from: many, today: today, calendar: calendar)
        let evening = PastWin.pick(from: many.shuffled(), today: today.addingTimeInterval(3600 * 10), calendar: calendar)
        #expect(morning == evening)
    }
}
