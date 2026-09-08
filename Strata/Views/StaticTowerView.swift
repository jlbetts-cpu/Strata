import SwiftUI
import SwiftData

/// A tower, drawn from blocks, outside the tower tab.
///
/// Extracted from `ShareTowerCard` so the share card and the History day
/// screen render the same tower. It draws the real `FlippableBlockView` and
/// `MergedGroupView` — a second, simpler tower drawn beside the real one is
/// how you end up shipping a picture of the app that does not look like the
/// app.
///
/// The caller must supply `\.towerFilterMode` and `\.perfectDayDates`: the
/// block views read both, and outside the tower's own hierarchy there is
/// nothing to inherit them from.
struct StaticTowerView: View {
    let blocks: [PlacedBlock]
    let mergeGroups: [MergeGroup]
    let groupedIDs: Set<UUID>
    let coveredIDs: Set<UUID>
    let modelContext: ModelContext
    /// Cap, so three blocks do not become billboards.
    var maxCell: CGFloat = 82

    private var rows: Int { blocks.reduce(0) { max($0, $1.row + $1.rowSpan) } }

    var body: some View {
        GeometryReader { geo in
            let columns = CGFloat(GridConstants.columnCount)
            let spacing = GridConstants.spacing
            let byWidth = (geo.size.width - (columns - 1) * spacing) / columns
            let cell = min(byWidth, maxCell)
            let gridW = columns * cell + (columns - 1) * spacing
            let gridH = rows > 0 ? CGFloat(rows) * cell + CGFloat(rows - 1) * spacing : 0
            let radius = cell * 0.147

            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    Color.clear.frame(width: gridW, height: gridH)

                    ForEach(mergeGroups) { group in
                        MergedGroupView(group: group, cellSize: cell,
                                        gridWidth: gridW, gridHeight: gridH)
                    }

                    ForEach(blocks) { block in
                        let f = GridConstants.blockFrame(
                            column: block.column, row: block.row,
                            columnSpan: block.columnSpan, rowSpan: block.rowSpan,
                            cellSize: cell
                        )
                        FlippableBlockView(
                            block: block,
                            width: f.width,
                            height: f.height,
                            cornerRadius: radius,
                            modelContext: modelContext,
                            isGroupMember: groupedIDs.contains(block.id),
                            isCovered: coveredIDs.contains(block.id)
                        )
                        .frame(width: f.width, height: f.height)
                        .offset(x: f.minX, y: gridH - f.minY - f.height)
                    }
                }
                .frame(width: gridW, height: gridH)

                TowerReflection(
                    facets: facets(cell: cell),
                    impacts: [],
                    gridWidth: gridW,
                    cornerRadius: radius,
                    reduceMotion: true
                )
                .frame(width: gridW, height: TowerReflection.depth)
            }
            .frame(width: geo.size.width, alignment: .center)
        }
        .frame(height: towerHeight)
    }

    private var towerHeight: CGFloat {
        let cell = maxCell
        let h = rows > 0 ? CGFloat(rows) * cell + CGFloat(rows - 1) * GridConstants.spacing : 0
        return h + TowerReflection.depth
    }

    /// What of the tower reaches the water: the bottom row, as colour and width.
    private func facets(cell: CGFloat) -> [TowerReflection.Facet] {
        blocks.filter { $0.row == 0 }.map { block in
            let f = GridConstants.blockFrame(
                column: block.column, row: 0,
                columnSpan: block.columnSpan, rowSpan: 1, cellSize: cell
            )
            return TowerReflection.Facet(
                id: block.id, x: f.minX, width: f.width,
                color: block.habit.displayCategory.style.baseColor
            )
        }
    }
}
