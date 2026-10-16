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
/// The caller must supply `\.towerFilterMode`: the
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
    /// Whether a block has anywhere to go. A block that answers "no" draws no
    /// press at all, rather than pressing and then opening nothing. Declared
    /// before `onTapBlock` so the memberwise order reads predicate, then action.
    var canTapBlock: ((PlacedBlock) -> Bool)? = nil
    /// Tapping a block. The share card has nowhere to go, so it is optional.
    var onTapBlock: ((PlacedBlock) -> Void)? = nil

    private var rows: Int { blocks.reduce(0) { max($0, $1.row + $1.rowSpan) } }

    /// Yesterday's tower going into Memories a piece at a time (`DayHandoff`).
    @Environment(\.towerLeaving) private var leaving

    /// The block's tap, or nil when it has nowhere to go, so the block does
    /// not press (see `FlippableBlockView`'s gesture).
    private func tapAction(for block: PlacedBlock) -> (() -> Void)? {
        guard let onTapBlock, canTapBlock?(block) ?? true else { return nil }
        return { onTapBlock(block) }
    }

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

                    let pieces = TowerPieces(blocks: blocks, groups: mergeGroups, cell: cell, gridW: gridW, gridH: gridH)
                    ForEach(mergeGroups) { group in
                        MergedGroupView(group: group, cellSize: cell,
                                        gridWidth: gridW, gridHeight: gridH)
                            .modifier(pieces.hop(group.id, leaving: leaving, anchorInGrid: true))
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
                            onTap: tapAction(for: block)
                        )
                        .frame(width: f.width, height: f.height)
                        .modifier(pieces.hop(pieces.piece(of: block.id), leaving: leaving, anchorInGrid: false))
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

/// **Yesterday's tower, leaving a piece at a time** (the owner, 2026-10-16:
/// the blocks "jump off one by one into the Memories icon", which takes
/// them). Read by `StaticTowerView`; set by `DayHandoffLayer`.
struct TowerLeaving: Equatable {
    /// How many pieces have gone, top first.
    var gone: Int
    /// Where they go, from the tower's centre.
    var to: CGSize
}

extension EnvironmentValues {
    @Entry var towerLeaving: TowerLeaving? = nil
}

/// The tower as pieces: a merged run of one colour is one piece, every other
/// block its own; ordered from the top down, so the tower is taken from its
/// top as you would take it apart.
struct TowerPieces {
    /// Each piece's centre, from the grid's top left, and its order.
    private var centres: [UUID: CGPoint] = [:]
    /// Each piece's longer side, so it lands at the tab's size.
    private var sides: [UUID: CGFloat] = [:]
    private var order: [UUID: Int] = [:]
    private var owner: [UUID: UUID] = [:]
    private let gridSize: CGSize
    var count: Int { order.count }

    init(blocks: [PlacedBlock], groups: [MergeGroup], cell: CGFloat, gridW: CGFloat, gridH: CGFloat) {
        gridSize = CGSize(width: gridW, height: gridH)
        var tops: [(id: UUID, top: Int, column: Int)] = []
        for group in groups {
            let cols = group.cells.map(\.column), rows = group.cells.map(\.row)
            guard let c0 = cols.min(), let c1 = cols.max(), let r0 = rows.min(), let r1 = rows.max() else { continue }
            let f = GridConstants.blockFrame(column: c0, row: r0, columnSpan: c1 - c0 + 1, rowSpan: r1 - r0 + 1, cellSize: cell)
            centres[group.id] = CGPoint(x: f.midX, y: gridH - f.midY)
            sides[group.id] = max(f.width, f.height)
            tops.append((group.id, r1 + 1, c0))
            for member in group.memberIDs { owner[member] = group.id }
        }
        for block in blocks where owner[block.id] == nil {
            let f = GridConstants.blockFrame(column: block.column, row: block.row,
                                             columnSpan: block.columnSpan, rowSpan: block.rowSpan, cellSize: cell)
            centres[block.id] = CGPoint(x: f.midX, y: gridH - f.midY)
            sides[block.id] = max(f.width, f.height)
            tops.append((block.id, block.row + block.rowSpan, block.column))
        }
        for (i, piece) in tops.sorted(by: { $0.top != $1.top ? $0.top > $1.top : $0.column < $1.column }).enumerated() {
            order[piece.id] = i
        }
    }

    static func count(blocks: [PlacedBlock], groups: [MergeGroup]) -> Int {
        TowerPieces(blocks: blocks, groups: groups, cell: 1, gridW: 1, gridH: 1).count
    }

    func piece(of block: UUID) -> UUID { owner[block] ?? block }

    /// When a piece goes: 0 first.
    func turn(of piece: UUID) -> Int? { order[piece] }

    /// The hop for a piece: nothing while it stays; gone, an arc from where
    /// it stands to the target, shrinking into it.
    func hop(_ piece: UUID, leaving: TowerLeaving?, anchorInGrid: Bool) -> TowerHop {
        guard let leaving, let i = order[piece], let c = centres[piece] else {
            return TowerHop(progress: 0, delta: .zero, anchor: .center, endScale: 1)
        }
        let fromCentre = CGSize(width: c.x - gridSize.width / 2, height: c.y - gridSize.height / 2)
        let delta = CGSize(width: leaving.to.width - fromCentre.width, height: leaving.to.height - fromCentre.height)
        let anchor = anchorInGrid && gridSize.width > 0 && gridSize.height > 0
            ? UnitPoint(x: c.x / gridSize.width, y: c.y / gridSize.height) : .center
        // It lands about the size of the tab's picture, whatever its size.
        let endScale = min(1, TowerHop.landingSide / max(sides[piece] ?? 1, 1))
        return TowerHop(progress: i < leaving.gone ? 1 : 0, delta: delta, anchor: anchor, endScale: endScale)
    }
}

/// **A hop, then into the tab**: up a little first, as a thing jumps, then
/// along an arc to the target, shrinking to a dot and gone as it lands.
struct TowerHop: ViewModifier, Animatable {
    var progress: Double
    let delta: CGSize
    let anchor: UnitPoint
    let endScale: CGFloat
    static let lift: CGFloat = 56
    /// The tab picture's side: 28pt, less a little, so it goes into it.
    static let landingSide: CGFloat = 22

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let p = progress
        let arc = 4 * Self.lift * p * (1 - p)
        content
            .scaleEffect(1 - (1 - endScale) * p * p, anchor: anchor)
            .offset(x: delta.width * p, y: delta.height * p - arc)
            .opacity(p < 0.85 ? 1 : max(0, (1 - p) / 0.15))
            .zIndex(p > 0 ? 10 : 0)
    }
}
