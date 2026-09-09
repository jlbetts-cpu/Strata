import Foundation
import Testing
@testable import Strata

/// The month tower's two rules: how a win count becomes a block size, and how
/// those blocks settle into the grid.
///
/// Both are pure value functions, so unlike the gesture work they can be
/// covered exactly rather than inferred from screenshots.
struct MonthTowerTests {

    private func day(_ n: Int, wins: Int, _ category: HabitCategory = .health) -> MonthTower.Day {
        MonthTower.Day(
            dateString: String(format: "2026-09-%02d", n),
            dayOfMonth: n,
            winCount: wins,
            category: category
        )
    }

    // MARK: - Sizing

    @Test func aQuietDayIsASmallBlock() {
        #expect(MonthTower.size(forWinCount: 1) == .small)
        #expect(MonthTower.size(forWinCount: 2) == .small)
    }

    @Test func anOrdinaryDayIsAMediumBlock() {
        #expect(MonthTower.size(forWinCount: 3) == .medium)
        #expect(MonthTower.size(forWinCount: 6) == .medium)
    }

    @Test func aBigDayIsAHardBlock() {
        #expect(MonthTower.size(forWinCount: 7) == .hard)
        #expect(MonthTower.size(forWinCount: 40) == .hard)
    }

    /// The two cuts, stated as the boundaries they are. If either moves, this
    /// is the test that should have to be edited deliberately.
    @Test func theBoundariesAreAtThreeAndSeven() {
        #expect(MonthTower.size(forWinCount: 2) != MonthTower.size(forWinCount: 3))
        #expect(MonthTower.size(forWinCount: 6) != MonthTower.size(forWinCount: 7))
    }

    /// A day with no wins produces no block, but the function must still be
    /// total — it is called from a packer, not from a guard.
    @Test func zeroAndNegativeCountsDoNotTrap() {
        #expect(MonthTower.size(forWinCount: 0) == .small)
        #expect(MonthTower.size(forWinCount: -1) == .small)
    }

    // MARK: - Dominant category

    @Test func theDayWearsItsMostFrequentCategory() {
        let now = Date()
        let votes: [(category: HabitCategory, at: Date)] = [
            (.health, now),
            (.work, now.addingTimeInterval(60)),
            (.work, now.addingTimeInterval(120))
        ]
        #expect(MonthTower.dominantCategory(votes) == .work)
    }

    @Test func aTieBreaksToWhatTheDayStartedAs() {
        let now = Date()
        let votes: [(category: HabitCategory, at: Date)] = [
            (.work, now.addingTimeInterval(600)),
            (.health, now),
            (.work, now.addingTimeInterval(900)),
            (.health, now.addingTimeInterval(1200))
        ]
        // Two each; health was logged first.
        #expect(MonthTower.dominantCategory(votes) == .health)
    }

    @Test func noVotesIsUnlabeled() {
        #expect(MonthTower.dominantCategory([]) == .unlabeled)
    }

    // MARK: - Packing

    @Test func aMonthWithNoWinsPacksToNothing() {
        let packed = MonthTower.pack([])
        #expect(packed.blocks.isEmpty)
        #expect(packed.rows == 0)
        #expect(packed.isEmpty)
    }

    @Test func everyDayGetsExactlyOneBlock() {
        let days = (1...20).map { day($0, wins: $0 % 9) }
        let packed = MonthTower.pack(days)
        #expect(packed.blocks.count == days.count)
        #expect(Set(packed.blocks.map(\.dateString)).count == days.count)
    }

    @Test func fourSmallDaysFillOneRow() {
        let packed = MonthTower.pack((1...4).map { day($0, wins: 1) })
        #expect(packed.rows == 1)
        #expect(Set(packed.blocks.map(\.column)) == [0, 1, 2, 3])
    }

    @Test func daysArePackedOldestFirstRegardlessOfInputOrder() {
        let days = [day(3, wins: 1), day(1, wins: 1), day(2, wins: 1)]
        let packed = MonthTower.pack(days)
        let byColumn = packed.blocks.sorted { ($0.row, $0.column) < ($1.row, $1.column) }
        #expect(byColumn.map(\.dayOfMonth) == [1, 2, 3])
    }

    @Test func noTwoBlocksOverlap() {
        let days = (1...31).map { day($0, wins: ($0 * 7) % 11) }
        let packed = MonthTower.pack(days)
        var occupied = Set<GridCell>()
        for block in packed.blocks {
            for r in block.row..<(block.row + block.rowSpan) {
                for c in block.column..<(block.column + block.columnSpan) {
                    let cell = GridCell(column: c, row: r)
                    #expect(!occupied.contains(cell))
                    occupied.insert(cell)
                }
            }
        }
    }

    @Test func everyBlockStaysInsideTheFourColumns() {
        let days = (1...31).map { day($0, wins: ($0 * 5) % 13) }
        for block in MonthTower.pack(days).blocks {
            #expect(block.column >= 0)
            #expect(block.column + block.columnSpan <= GridConstants.columnCount)
        }
    }

    @Test func rowCountCoversTheTallestBlock() {
        let packed = MonthTower.pack((1...31).map { day($0, wins: ($0 * 3) % 10) })
        let deepest = packed.blocks.map { $0.row + $0.rowSpan }.max() ?? 0
        #expect(packed.rows == deepest)
    }

    /// The reason the blocks carry day numerals: first-fit is not monotonic.
    /// A 2×2 leaves a 1×1 hole beside it that a *later* day drops into, so
    /// reading order does not follow date order. Asserted rather than assumed,
    /// because the numeral is a deliberate exception to "a block with no name
    /// shows no text".
    @Test func packingOrderIsNotReadingOrder() {
        // Day 1 is a 2×2; day 2 is a 1×1 and lands beside it, in the same row.
        let packed = MonthTower.pack([day(1, wins: 8), day(2, wins: 1)])
        let first = packed.blocks.first { $0.dayOfMonth == 1 }!
        let second = packed.blocks.first { $0.dayOfMonth == 2 }!
        #expect(first.rowSpan == 2)
        #expect(second.row == first.row)
        #expect(second.column > first.column)
    }
}
