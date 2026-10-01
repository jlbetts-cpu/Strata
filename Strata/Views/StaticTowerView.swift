import SwiftUI
import SwiftData

/// A tower, drawn from blocks, outside the tower tab.
///
/// Extracted from `ShareTowerCard` so the share card and the History day
/// screen render the same tower, and as of 2026-10-01 the share card actually
/// calls it, instead of keeping the copy it was extracted from. It draws the
/// real `FlippableBlockView` and
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
    ///
    /// **It is also how a caller fits by HEIGHT.** This view sizes off the width
    /// because it has to report its own height, so a caller with a fixed box,
    /// like `ShareTowerCard` with its 640pt of story, works out the cell its
    /// height allows and passes `min(that, 82)`. `cell` then resolves to
    /// `min(byWidth, byHeight, 82)` without this view needing to know about it.
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
            // **0.147 and NOT `GridConstants.blockCornerRadius(forCell:)`, which
            // is the opposite of what it looks like.**
            //
            // The token's effective ratio is 12 / 86.5 = 0.1387, so at the share
            // card's capped 82pt cell it gives 11.38 against this 12.05. The
            // 0.68pt gap is not the interesting number. `MergedGroupView` draws
            // a merged run at `blockCornerRadius * styleScale`, and both of its
            // callers leave `styleScale` at 1, so a run is a FLAT 12 at every
            // cell size. At 82 this literal puts a single block at 12.05 against
            // that 12, which is why it is 0.147: it is the value that makes a
            // single block and the run beside it the same shape on the card the
            // ratio was chosen for. Moving it to the token would put singles at
            // 11.38 beside runs at 12 and open a 0.62pt mismatch inside one
            // tower where there is none today.
            //
            // 14.7% is also the source ratio, not a guess: Figma Apollo's 40px
            // radius on a 272px block, which `GridConstants.blockCornerRadius`
            // records and then rounds 12.72 down to 12.
            //
            // **The real divergence is elsewhere and is the owner's call.** The
            // LIVE tower passes `GridConstants.cornerRadius`, a flat 8, so at its
            // 82pt cell a single block is 8 while the merged run it stands next
            // to is 12, and the same block on this view is 12.05. Three values
            // for one object. Unifying them changes how the Wins tab looks and
            // cannot be judged from a diff.
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

}
