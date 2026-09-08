import SwiftUI

/// A day's tower, small.
///
/// Extracted from `TowerBarChart` so the chart's bars and an album's cover are
/// the same code. They are the same object — one day, packed and merged — and
/// two copies of that drawing would drift the first time either changed.
///
/// It draws through `MergedGroupView`, the tower's own view, at a `styleScale`
/// derived from the cell. A day of five green wins is ONE shape on the tower,
/// so anything that draws it as five squares is showing a day you did not
/// live; and the rim, band and shadow are absolutes tuned to an 86.5pt cell,
/// so they have to come down together or a square reads as a pill.
struct MiniTowerView: View {
    let blocks: [TowerBarChart.MiniBlock]
    let cell: CGFloat
    let gap: CGFloat
    /// Rows of empty space to reserve above the tower, so several of these
    /// share a baseline. Pass the tallest day in the set.
    let reservedRows: Int
    var showsEmptyTrack = true

    private var rows: Int { blocks.map { $0.row + $0.rowSpan }.max() ?? 0 }
    private var runs: [MiniTowerPacker.Run] { MiniTowerPacker.runs(in: blocks) }

    private var width: CGFloat {
        CGFloat(GridConstants.columnCount) * cell + CGFloat(GridConstants.columnCount - 1) * gap
    }
    private func height(forRows n: Int) -> CGFloat {
        n > 0 ? CGFloat(n) * cell + CGFloat(n - 1) * gap : 0
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear
                .frame(width: width, height: height(forRows: max(reservedRows, 1)))

            if blocks.isEmpty && showsEmptyTrack {
                // A day with nothing is not a gap. It is a day with nothing,
                // and it should be possible to see that it was one.
                RoundedRectangle(
                    cornerRadius: GridConstants.blockCornerRadius(forCell: cell),
                    style: .continuous
                )
                .fill(AppColors.warmBlack.opacity(0.06))
                .frame(width: width, height: cell)
            }

            ForEach(Array(runs.enumerated()), id: \.offset) { _, run in
                MergedGroupView(
                    group: MergeGroup(
                        id: UUID(),
                        category: run.category,
                        cells: run.cells,
                        memberIDs: [],
                        bottomRow: run.bottomRow
                    ),
                    cellSize: cell,
                    gridWidth: width,
                    gridHeight: height(forRows: rows),
                    styleScale: cell / GridConstants.blockReferenceCell
                )
            }
        }
        .frame(width: width, alignment: .bottomLeading)
    }
}
