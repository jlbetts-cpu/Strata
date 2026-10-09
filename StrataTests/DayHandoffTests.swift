import Foundation
import Testing
@testable import Strata

/// Yesterday goes into Memories once, and only when it had a win
/// (`DayHandoff`, `tasks/unification-log.md` §3).
@Suite("Day hand-off")
struct DayHandoffTests {
    @Test("a new day after a day with wins hands yesterday off")
    func plays() {
        #expect(DayHandoff.due(today: "2026-10-09", lastDecided: "2026-10-08",
                               yesterday: "2026-10-08", yesterdayHadWins: true) == "2026-10-08")
        #expect(DayHandoff.due(today: "2026-10-09", lastDecided: nil,
                               yesterday: "2026-10-08", yesterdayHadWins: true) == "2026-10-08")
    }

    @Test("once a day")
    func once() {
        #expect(DayHandoff.due(today: "2026-10-09", lastDecided: "2026-10-09",
                               yesterday: "2026-10-08", yesterdayHadWins: true) == nil)
    }

    @Test("nothing is said about a quiet day")
    func quiet() {
        #expect(DayHandoff.due(today: "2026-10-09", lastDecided: "2026-10-08",
                               yesterday: "2026-10-08", yesterdayHadWins: false) == nil)
    }
}
