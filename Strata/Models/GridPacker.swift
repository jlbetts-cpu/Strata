import Foundation

/// The tower's packing rule, with nothing of the tower in it.
///
/// Lifted verbatim out of `MiniTowerPacker`, where it was private, because it
/// now has two callers — the day tower and the month tower — and it is the one
/// function that must stay identical between them. A month whose blocks settle
/// by different rules than the tower's stops looking like the same object.
enum GridPacker {

    /// The same scan the tower uses: from the foundation up, first position
    /// that fits, marking the cells as it goes. Append-only, so a block never
    /// displaces one already placed.
    ///
    /// Note that this is deliberately **not** monotonic in call order: a 2×2
    /// leaves a 1×1 hole beside it that a later, smaller block drops into. The
    /// month tower's day numerals exist because of this — position alone does
    /// not tell you which day a block is.
    static func firstFit(
        columnSpan: Int,
        rowSpan: Int,
        grid: inout [[Bool]]
    ) -> (column: Int, row: Int)? {
        let cols = GridConstants.columnCount
        let maxStart = cols - columnSpan
        guard maxStart >= 0 else { return nil }

        var row = 0
        while row < 400 {
            while grid.count < row + rowSpan {
                grid.append(Array(repeating: false, count: cols))
            }
            for col in 0...maxStart {
                var fits = true
                outer: for r in row..<(row + rowSpan) {
                    for c in col..<(col + columnSpan) where grid[r][c] {
                        fits = false
                        break outer
                    }
                }
                if fits {
                    for r in row..<(row + rowSpan) {
                        for c in col..<(col + columnSpan) { grid[r][c] = true }
                    }
                    return (col, row)
                }
            }
            row += 1
        }
        return nil
    }
}
