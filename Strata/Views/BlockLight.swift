import SwiftUI

/// **One light over the whole tower, and every block is lit by it.**
///
/// The owner, 2026-09-30: "I like that the blocks are reacting to the same
/// outer light. Like, they don't all need the same light around the corners —
/// depending on where they are, the light shall hit them differently."
///
/// Up to here every block was lit identically: the inner glow sat dead centre
/// in each one, and the rim was brightest along the top edge whatever the block
/// was or where it stood. That is a per-block decoration, and it is the thing
/// that makes a stack of coloured rectangles read as a sheet of stickers — each
/// is lit as though it were the only object on the page, so the page has no
/// light in it at all.
///
/// **A tower lit by one source is a tower in a place.** A block in the bottom
/// left catches the light on its upper-right corner; one directly under the
/// lamp catches it straight on; one up at the crown is close enough that the
/// angle is steep. Nothing about this is a per-block decision — there is one
/// lamp and the geometry does the rest, which is why it reads as real.
///
/// Everything here is in GRID CELLS rather than points, so it is the same at
/// every screen size and a block only has to know what it already knows: its
/// column, its row and its spans.
struct BlockLight: Equatable {
    /// Columns from the grid's left edge. Half a column left of centre, because
    /// the light in this app has always come from slightly left of above —
    /// `BlockRim`, the slot, the companion's contact shadow.
    var column: CGFloat
    /// Rows above the ground row. Above the top of the tower, so the whole
    /// stack is lit from outside itself.
    var row: CGFloat

    /// **Where the lamp hangs for a tower of a given height.**
    ///
    /// It rises with the tower rather than sitting at a fixed height, because a
    /// fixed lamp would mean a tall tower's crown was lit from the side while
    /// its foot was lit from above — the angles would swing further the more
    /// wins there were, so the same block would be lit differently tomorrow.
    /// Held a constant distance above the crown, the picture is stable and the
    /// spread across the tower stays the same whatever it has grown to.
    static func over(rows: Int, columns: Int = GridConstants.columnCount) -> BlockLight {
        BlockLight(column: CGFloat(columns) / 2 - 0.5,
                   row: CGFloat(max(rows, 1)) + 3.5)
    }

    /// **How far a block's inner glow slides toward the light**, as a share of
    /// the block. A quarter is enough to see across a tower and small enough
    /// that no single block looks as though its gradient has slipped.
    static let coreTravel: CGFloat = 0.18

    /// How this light falls on one block.
    ///
    /// `column`/`row` are the block's own, in the same grid. The returned aim is
    /// in UnitPoint space — y DOWN, the way SwiftUI has it, which is the one
    /// place this has to flip.
    func aim(column: Int, row: Int, columnSpan: Int, rowSpan: Int) -> BlockAim {
        aim(centreColumn: CGFloat(column) + CGFloat(columnSpan) / 2,
            centreRow: CGFloat(row) + CGFloat(rowSpan) / 2)
    }

    func aim(centreColumn: CGFloat, centreRow: CGFloat) -> BlockAim {
        let dx = column - centreColumn
        let dy = row - centreRow
        let length = max(sqrt(dx * dx + dy * dy), 0.0001)
        // Unit vector pointing AT the lamp, in grid space (y up).
        let ux = dx / length
        let uy = dy / length
        return BlockAim(
            // The glow slides toward the light. UnitPoint's y runs down, so the
            // vertical component is negated.
            core: UnitPoint(x: 0.5 + ux * Self.coreTravel,
                            y: 0.5 - uy * Self.coreTravel),
            // The rim is brightest on the edge facing the lamp and quietest on
            // the one facing away, which is the whole of "the light hits them
            // differently": two blocks either side of centre carry their
            // highlight on opposite corners.
            lit: UnitPoint(x: 0.5 + ux * 0.5, y: 0.5 - uy * 0.5),
            shaded: UnitPoint(x: 0.5 - ux * 0.5, y: 0.5 + uy * 0.5)
        )
    }
}

/// What one light does to one block: where its glow sits, and which way its rim
/// runs.
struct BlockAim: Equatable {
    var core: UnitPoint
    var lit: UnitPoint
    var shaded: UnitPoint

    /// **For anything that is not standing in the tower** — a chip in the
    /// picker, a bullet in the plan, a block in a replay frame. Those are
    /// objects on their own, not part of a lit stack, so they get the light
    /// straight from above, which is what every one of them had before there
    /// was a lamp at all.
    static let overhead = BlockAim(core: UnitPoint(x: 0.46, y: 0.5),
                                   lit: .top, shaded: .bottom)
}

private struct BlockLightKey: EnvironmentKey {
    /// Nothing until a tower sets one. A block that is not in a tower is lit
    /// from above, the way it always was.
    static let defaultValue: BlockLight? = nil
}

extension EnvironmentValues {
    /// The lamp over the tower this block is standing in, if it is in one.
    var blockLight: BlockLight? {
        get { self[BlockLightKey.self] }
        set { self[BlockLightKey.self] = newValue }
    }
}
