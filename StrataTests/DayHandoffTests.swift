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

    @Test("the tower is taken from the top, a piece at a time")
    func topFirst() {
        let low = MergeGroup(id: UUID(), category: .unlabeled, cells: [GridCell(column: 0, row: 0), GridCell(column: 1, row: 0)],
                             memberIDs: [], bottomRow: 0)
        let high = MergeGroup(id: UUID(), category: .unlabeled, cells: [GridCell(column: 2, row: 2)], memberIDs: [], bottomRow: 2)
        let pieces = TowerPieces(blocks: [], groups: [low, high], cell: 80, gridW: 340, gridH: 260)
        #expect(pieces.count == 2)
        #expect(pieces.turn(of: high.id) == 0)
        #expect(pieces.turn(of: low.id) == 1)
    }

    @Test("one at a time, and a big day stays near five seconds")
    func flight() {
        #expect(DayHandoffLayer.flight(pieces: 3) == DayHandoffLayer.flightLongest)
        #expect(DayHandoffLayer.flight(pieces: 60) == DayHandoffLayer.flightShortest)
        let twelve = DayHandoffLayer.flight(pieces: 12)
        #expect(abs(Double(12) * (twelve + DayHandoffLayer.landing) - 5) < 0.01)
    }
}
