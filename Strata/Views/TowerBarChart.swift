import SwiftUI

/// The towers, side by side.
///
/// A bar chart whose bars are the towers themselves. A plain bar says how many
/// wins a day had; this says that AND what they were and how they stacked,
/// using the same packing, the same four columns and the same six colours as
/// the real thing. Nothing has to be learned twice, and there is no legend,
/// because the chart is made of the objects it is counting.
///
/// **No photos, no titles, no rims at this size.** A block face is unreadable
/// at 8pt wide and the detail turns a row of towers into noise; what survives
/// the shrink is height and colour, which is what a chart is for. The blocks
/// keep their real footprint, so a Deep block is visibly four cells and a day
/// of three Deep blocks stands taller than a day of six Quick ones — which is
/// true, and which a count alone would get wrong.
struct TowerBarChart: View {

    struct Column: Identifiable {
        let id: String
        /// What goes under the bar: "M", "12", "Sep".
        let label: String
        /// Highlighted — today, this week, this month.
        let isCurrent: Bool
        let blocks: [MiniBlock]

        var winCount: Int { blocks.count }
        var rows: Int { blocks.map { $0.row + $0.rowSpan }.max() ?? 0 }
        /// The blocks resolved into merged runs, so the bar is the shape the
        /// tower actually was rather than a pile of separate squares.
        var runs: [MiniTowerPacker.Run] { MiniTowerPacker.runs(in: blocks) }
    }

    struct MiniBlock: Identifiable {
        let id: UUID
        let column: Int
        let row: Int
        let columnSpan: Int
        let rowSpan: Int
        let colour: Color
    }

    let columns: [Column]
    /// The tallest column across the whole chart, so every bar is drawn to the
    /// same scale and their heights can be compared by eye.
    let maxRows: Int

    /// How tall the tallest bar is allowed to be.
    ///
    /// The cell size is solved for rather than fixed, so the chart fills the
    /// room it is given: a day with three wins and a day with fifteen both
    /// produce a bar that reaches the top of the frame, and the comparison
    /// between COLUMNS still holds because they all share one scale. A fixed
    /// cell made the whole chart small whenever the busiest day was quiet.
    var maxBarHeight: CGFloat = 300

    /// Never bigger than this, or two wins become a poster.
    private let maxCell: CGFloat = 34
    private let minCell: CGFloat = 8
    private let gapRatio: CGFloat = 0.17
    private let columnGap: CGFloat = 20

    private var cell: CGFloat {
        let rows = CGFloat(max(maxRows, 1))
        // height = rows * cell + (rows - 1) * cell * gapRatio
        let solved = maxBarHeight / (rows + (rows - 1) * gapRatio)
        return min(max(solved, minCell), maxCell)
    }

    private var gap: CGFloat { cell * gapRatio }

    private var barWidth: CGFloat {
        CGFloat(GridConstants.columnCount) * cell + CGFloat(GridConstants.columnCount - 1) * gap
    }

    private func height(forRows rows: Int) -> CGFloat {
        guard rows > 0 else { return 0 }
        return CGFloat(rows) * cell + CGFloat(rows - 1) * gap
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: columnGap) {
                ForEach(columns) { column in
                    VStack(spacing: 12) {
                        // Every bar reserves the full height, so they share a
                        // baseline and the empty space above a short one is
                        // part of the reading.
                        ZStack(alignment: .bottomLeading) {
                            Color.clear
                                .frame(width: barWidth, height: height(forRows: max(maxRows, 1)))

                            if column.blocks.isEmpty {
                                // A day with nothing is not a gap in the chart.
                                // It is a day with nothing, and it should be
                                // possible to see that it was one.
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(AppColors.warmBlack.opacity(0.06))
                                    .frame(width: barWidth, height: cell)
                            }

                            // Merged runs, exactly as the tower draws them.
                            //
                            // A day of five green wins is ONE shape on the
                            // tower, so a chart that draws it as five squares
                            // is a chart of different days than the ones you
                            // lived. `MergedShape` is the same shape type the
                            // tower uses, at a smaller cell size — the runs
                            // even keep their notches.
                            ForEach(Array(column.runs.enumerated()), id: \.offset) { _, run in
                                MergedShape(
                                    cells: run.cells,
                                    cellSize: cell,
                                    spacing: gap,
                                    gridHeight: height(forRows: column.rows),
                                    cornerRadius: cell * 0.20
                                )
                                .fill(run.colour)
                                .frame(width: barWidth, height: height(forRows: column.rows), alignment: .bottomLeading)
                            }
                        }
                        .frame(width: barWidth, alignment: .bottomLeading)

                        Text(column.label)
                            .font(Typography.caption)
                            .foregroundStyle(.primary.opacity(column.isCurrent ? 0.75 : 0.32))
                            .frame(width: barWidth)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(column.label): \(column.winCount) wins")
                }
            }
            .padding(.horizontal, GridConstants.horizontalPadding)
            .padding(.vertical, 10)
        }
        // Opens showing the most recent period, which is the one you came to
        // look at — a chart of your own history that starts at the beginning
        // is a chart you have to scroll before it says anything.
        //
        // `.topTrailing`, not `.trailing`. A UnitPoint carries BOTH axes and
        // `.trailing` is (1, 0.5), so the vertical half of it was applying to
        // the page's own scroll view and opening Insights halfway down —
        // past the count, the streak and the chart it was meant to be
        // anchoring. The x is what this needs; the y has to be 0.
        .defaultScrollAnchor(.topTrailing)
    }
}

/// Packs logs into the tower's grid, without any of the tower's state.
///
/// `TowerViewModel.buildTower` does this already, but it also computes merge
/// groups, milestones, day separators, reflections and drop animations, and it
/// writes all of them to the view model that drives the live tower. The chart
/// needs the geometry and nothing else, twenty or thirty times over, so it gets
/// its own pure copy of the one part it uses.
enum MiniTowerPacker {

    /// A run of adjacent same-colour cells, drawn as one shape.
    struct Run {
        let cells: Set<GridCell>
        let colour: Color
    }

    /// Groups packed blocks into merged runs by colour and adjacency.
    ///
    /// The same rule the tower uses — touching cells of one colour are one
    /// object — run over the chart's own packing rather than over
    /// `PlacedBlock`s, because the chart never builds those. A block that
    /// touches nothing comes back as a run of one, which `MergedShape` draws
    /// as an ordinary rounded rectangle, so there is no second code path for
    /// the unmerged case.
    static func runs(in blocks: [TowerBarChart.MiniBlock]) -> [Run] {
        var owner: [GridCell: Color] = [:]
        for block in blocks {
            for r in block.row..<(block.row + block.rowSpan) {
                for c in block.column..<(block.column + block.columnSpan) {
                    owner[GridCell(column: c, row: r)] = block.colour
                }
            }
        }

        var seen = Set<GridCell>()
        var out: [Run] = []
        for cell in owner.keys.sorted(by: { ($0.row, $0.column) < ($1.row, $1.column) }) {
            guard !seen.contains(cell), let colour = owner[cell] else { continue }
            // Flood fill across sides only. Diagonals do not touch, and two
            // blocks meeting at a corner are two blocks.
            var group: Set<GridCell> = []
            var stack = [cell]
            while let current = stack.popLast() {
                guard !group.contains(current), owner[current] == colour else { continue }
                group.insert(current)
                seen.insert(current)
                stack.append(contentsOf: [
                    GridCell(column: current.column - 1, row: current.row),
                    GridCell(column: current.column + 1, row: current.row),
                    GridCell(column: current.column, row: current.row - 1),
                    GridCell(column: current.column, row: current.row + 1)
                ])
            }
            out.append(Run(cells: group, colour: colour))
        }
        return out
    }

    static func pack(_ logs: [HabitLog]) -> [TowerBarChart.MiniBlock] {
        var grid: [[Bool]] = []
        var out: [TowerBarChart.MiniBlock] = []

        let eligible = logs
            .filter { ($0.completed || $0.skipped) && $0.habit != nil }
            .sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }

        for log in eligible {
            guard let habit = log.habit else { continue }
            let size = habit.blockSize
            guard let pos = firstFit(
                columnSpan: size.columnSpan,
                rowSpan: size.rowSpan,
                grid: &grid
            ) else { continue }
            out.append(TowerBarChart.MiniBlock(
                id: log.id,
                column: pos.column,
                row: pos.row,
                columnSpan: size.columnSpan,
                rowSpan: size.rowSpan,
                colour: habit.displayCategory.style.baseColor
            ))
        }
        return out
    }

    /// The same scan the tower uses: from the foundation up, first position
    /// that fits, marking the cells as it goes. Append-only, so a block never
    /// displaces one already placed.
    private static func firstFit(
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
