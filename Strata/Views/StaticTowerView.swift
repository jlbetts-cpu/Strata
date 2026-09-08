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
    /// The width the tower is drawn into. Explicit rather than measured,
    /// because the view also has to REPORT its height — and a `GeometryReader`
    /// cannot tell its parent how tall it wants to be.
    let width: CGFloat
    /// Cap, so three blocks do not become billboards.
    var maxCell: CGFloat = 82
    /// Tapping a block. The share card has nowhere to go, so it is optional.
    var onTapBlock: ((PlacedBlock) -> Void)? = nil

    private var rows: Int { blocks.reduce(0) { max($0, $1.row + $1.rowSpan) } }

    private var cell: CGFloat {
        let columns = CGFloat(GridConstants.columnCount)
        let byWidth = (width - (columns - 1) * GridConstants.spacing) / columns
        return min(byWidth, maxCell)
    }

    var body: some View {
        Group {
            let columns = CGFloat(GridConstants.columnCount)
            let spacing = GridConstants.spacing
            let cell = self.cell
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
                            isCovered: coveredIDs.contains(block.id),
                            // Through the block's OWN tap hook, not a gesture
                            // layered over it. `FlippableBlockView` recognises
                            // its tap with `simultaneousGesture`, and a child
                            // gesture takes the touch before a parent's
                            // `.onTapGesture` ever sees it — so the outer one
                            // silently never fired.
                            onTap: { onTapBlock?(block) }
                        )
                        .frame(width: f.width, height: f.height)
                        .offset(x: f.minX, y: gridH - f.minY - f.height)
                    }
                }
                .frame(width: gridW, height: gridH)
            }
            .frame(width: width, alignment: .center)
        }
        .frame(width: width, height: towerHeight)
    }

    /// Measured from the cell the view will actually draw at, not from the
    /// cap. Using `maxCell` here reserved 500pt a row for a tower drawn at 88,
    /// which left the day screen mostly empty below a small tower.
    private var towerHeight: CGFloat {
        rows > 0 ? CGFloat(rows) * cell + CGFloat(rows - 1) * GridConstants.spacing : 0
    }

    /// What of the tower reaches the water: the bottom row, as colour and width.
 }
