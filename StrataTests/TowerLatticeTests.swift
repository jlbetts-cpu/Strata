import Testing
import SwiftUI
@testable import Strata

/// **The lattice has to be the tower's own grid, not a pattern that looks
/// like it.**
///
/// The owner asked for structure behind the blocks that helps somebody
/// understand the tower. It only does that while every cell is exactly where
/// a block would land; a lattice a few points out of step is a second grid on
/// the page, which is worse than none. Screenshots do not catch four points,
/// and the numbers do.
@Suite("The tower's lattice")
struct TowerLatticeTests {

    private let cell: CGFloat = 86
    private let spacing = GridConstants.spacing
    private var columns: Int { GridConstants.columnCount }

    private func shape() -> TowerLatticeShape {
        TowerLatticeShape(cellSize: cell, spacing: spacing, columns: columns)
    }

    /// Blocks are placed with `blockFrame`, then flipped so row 0 is on the
    /// ground. A lattice cell has to land on the same rectangle.
    ///
    /// **Proven able to fail**: measuring the lattice down from the top
    /// instead of up from the bottom moves every cell by the remainder of
    /// the height over the pitch, and this goes red at any height that is not
    /// a whole number of rows.
    @Test("Every cell is where a block would land")
    func cellsSitOnTheBlockGrid() {
        // A height that is deliberately NOT a whole number of rows.
        let height: CGFloat = 517
        let rect = CGRect(x: 0, y: 0, width: GridConstants.gridWidth(cellSize: cell), height: height)
        let rects = shape().cellRects(in: rect)
        #expect(!rects.isEmpty)

        for (index, cellRect) in rects.enumerated() {
            let column = index % columns
            let row = index / columns
            let frame = GridConstants.blockFrame(column: column, row: 0,
                                                 columnSpan: 1, rowSpan: 1, cellSize: cell)
            #expect(abs(cellRect.minX - frame.minX) < 0.01,
                    "column \(column) starts at \(cellRect.minX), a block starts at \(frame.minX)")
            // Row 0 sits on the ground, row 1 one pitch above it, and so on.
            let expectedBottom = height - CGFloat(row) * (cell + spacing)
            #expect(abs(cellRect.maxY - expectedBottom) < 0.01,
                    "row \(row) ends at \(cellRect.maxY) rather than \(expectedBottom)")
            #expect(abs(cellRect.width - cell) < 0.01)
            #expect(abs(cellRect.height - cell) < 0.01)
        }
    }

    /// The lattice is exactly as wide as the tower, so its right-hand column
    /// ends on the same margin the blocks do rather than a gutter short of it.
    @Test("The lattice is the tower's width, to the point")
    func theLatticeIsTheTowersWidth() {
        let width = GridConstants.gridWidth(cellSize: cell)
        let rect = CGRect(x: 0, y: 0, width: width, height: 400)
        let rects = shape().cellRects(in: rect)
        let right = rects.map(\.maxX).max() ?? 0
        #expect(abs(right - width) < 0.01,
                "the lattice reaches \(right) and the tower reaches \(width)")
    }

    /// A field of cells at the token's own strength was a checkerboard when
    /// it was photographed. This pins the decision, not the taste: whatever
    /// the number becomes, it stays under half of `quietFill`.
    @Test("An empty cell stays quieter than a well")
    func theLatticeStaysQuiet() {
        #expect(TowerLattice.strength > 0, "an invisible lattice is not a lattice")
        #expect(TowerLattice.strength <= 0.5,
                "at \(TowerLattice.strength) of quietFill the cells compete with the blocks")
    }

    /// Nothing is drawn for a tower that has not been measured yet, rather
    /// than a divide by zero or an endless row of cells.
    @Test("An unmeasured tower draws nothing")
    func zeroSizeDrawsNothing() {
        let empty = TowerLatticeShape(cellSize: 0, spacing: spacing, columns: columns)
        #expect(empty.cellRects(in: CGRect(x: 0, y: 0, width: 300, height: 300)).isEmpty)
    }
}
