import Testing
@testable import Strata

/// The packing rule itself, tested where it lives rather than through either
/// of the two towers that call it. If this drifts, the month stops looking
/// like the tower and nothing else would say so.
struct GridPackerTests {

    private func fit(_ size: BlockSize, _ grid: inout [[Bool]]) -> (column: Int, row: Int)? {
        GridPacker.firstFit(columnSpan: size.columnSpan, rowSpan: size.rowSpan, grid: &grid)
    }

    @Test func theFirstBlockLandsAtTheOrigin() {
        var grid: [[Bool]] = []
        let pos = fit(.small, &grid)
        #expect(pos?.column == 0)
        #expect(pos?.row == 0)
    }

    @Test func blocksFillARowLeftToRightBeforeStartingTheNext() {
        var grid: [[Bool]] = []
        let placed = (0..<5).compactMap { _ in fit(.small, &grid) }
        #expect(placed.map(\.column) == [0, 1, 2, 3, 0])
        #expect(placed.map(\.row) == [0, 0, 0, 0, 1])
    }

    @Test func aWideBlockThatDoesNotFitTheRemainderStartsANewRow() {
        var grid: [[Bool]] = []
        _ = fit(.small, &grid)          // (0,0)
        _ = fit(.small, &grid)          // (1,0)
        _ = fit(.small, &grid)          // (2,0)
        let wide = fit(.medium, &grid)  // needs two columns; only column 3 is free
        #expect(wide?.row == 1)
        #expect(wide?.column == 0)
    }

    /// Append-only: a block already placed is never displaced, so the hole a
    /// wide block leaves behind stays available to a later small one.
    @Test func aLaterSmallBlockBackfillsAnEarlierHole() {
        var grid: [[Bool]] = []
        _ = fit(.small, &grid)          // (0,0)
        _ = fit(.small, &grid)          // (1,0)
        _ = fit(.small, &grid)          // (2,0)
        _ = fit(.medium, &grid)         // (0,1) — skipped the gap at column 3
        let backfill = fit(.small, &grid)
        #expect(backfill?.column == 3)
        #expect(backfill?.row == 0)
    }

    @Test func aTwoByTwoOccupiesFourCells() {
        var grid: [[Bool]] = []
        _ = fit(.hard, &grid)
        #expect(grid.count >= 2)
        #expect(grid[0][0] && grid[0][1] && grid[1][0] && grid[1][1])
        #expect(!grid[0][2] && !grid[1][2])
    }

    @Test func aBlockWiderThanTheGridIsRefusedRatherThanClipped() {
        var grid: [[Bool]] = []
        let pos = GridPacker.firstFit(
            columnSpan: GridConstants.columnCount + 1,
            rowSpan: 1,
            grid: &grid
        )
        #expect(pos == nil)
    }

    @Test func theGridGrowsToHoldWhatItIsGiven() {
        var grid: [[Bool]] = []
        for _ in 0..<12 { _ = fit(.small, &grid) }
        #expect(grid.count == 3)
        #expect(grid.allSatisfy { $0.count == GridConstants.columnCount })
    }
}
