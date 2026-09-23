import SwiftUI

/// **The surface the tower is built on.**
///
/// The owner, 2026-09-23: "the blocks right now, they don't feel like they
/// fit when there is a bunch of images, like they just don't fit well inside
/// of there when they are mixed, it looks a bit odd. I think the easy fix
/// would be to add structure to the background, like a grid of some sort that
/// helps structure the screen. But I don't want it to look cheap, it has to
/// be like if Apple designed it: minimal, clean. And really help the user
/// understand."
///
/// **What the problem actually is.** A tower of flat colours is a composition
/// somebody chose; the same tower with photographs in half the slots is two
/// kinds of object on one page, and the photographs bring their own colour,
/// their own contrast and their own edges. Nothing on the page says the two
/// belong to the same system, so the mixed tower reads as a collage.
///
/// **So this is not wallpaper, it is the grid the blocks land in.** Same cell
/// size, same 4pt gutter, same corner radius, anchored to the same bottom row.
/// A block does not sit ON the pattern, it FILLS one of these cells, and the
/// empty ones carry on above it. That is the part that teaches: you can see
/// the slots, so you can see that a small win takes one and a big one takes
/// four, and a photograph is just a slot with a picture in it.
///
/// **Why cells and not lines.** A ruled lattice of hairlines is graph paper:
/// it is a second geometry laid over the first, its lines land in the
/// gutters, and at this contrast hairlines alias into a grey haze on a
/// scrolling view. Filled cells are the app's own shape at the app's own
/// radius, they have no sub-pixel edge to shimmer, and the 4pt gutter stays
/// the gutter rather than becoming a drawn line.
///
/// **It fades upward** so the screen is grounded rather than caged. Strongest
/// under the tower, gone well before the top of the viewport, which is also
/// what keeps it from reading as an empty state waiting to be filled in.
struct TowerLattice: View {
    /// The tower's cell, which is `colW` at the call site: the same number
    /// every block is measured with.
    var cellSize: CGFloat
    /// How tall the tower's own grid is, so the lattice knows where the
    /// content ends and its own overhang begins.
    var contentHeight: CGFloat
    var spacing: CGFloat = GridConstants.spacing
    var columns: Int = GridConstants.columnCount

    /// **How far above the tower the lattice carries on, in rows.**
    ///
    /// It was a whole viewport, and photographed that was the failure he
    /// warned about: a checkerboard from the tab bar to the status bar, at
    /// one strength, with the fade finishing off screen above. The lattice
    /// is a surface the tower stands on, not a backdrop the app lives in, so
    /// it reaches a few rows past the top block and is gone.
    static let rowsAbove = 3

    /// **How much ink an empty cell gets, as a share of `quietFill`.**
    ///
    /// `AppColors.quietFill` is the app's "empty cell" token at 6% ink, which
    /// is right for ONE well on a page and too strong for a field of them:
    /// at 6% the lattice reads as a checkerboard and competes with the
    /// blocks. Rendered and looked at rather than reasoned about.
    /// **Photographed at 0.55 and it was a checkerboard**, which is exactly
    /// the cheap he asked this not to be. The cells have to be findable and
    /// then forgotten: enough that the tower reads as built into something,
    /// not enough to count them without looking for them.
    static let strength: Double = 0.34

    private var pitch: CGFloat { cellSize + spacing }
    private var overhang: CGFloat { CGFloat(Self.rowsAbove) * pitch }
    private var height: CGFloat { max(contentHeight, 1) + overhang }

    var body: some View {
        TowerLatticeShape(cellSize: cellSize, spacing: spacing, columns: columns)
            .fill(AppColors.quietFill.opacity(Self.strength))
            .frame(height: height)
            .mask {
                // **The fade is spent on the overhang, not on the whole
                // height.** As a share of the lattice it finished above the
                // top of the screen and every visible cell came out at full
                // strength. In points it always lands where the tower ends:
                // clear at the top, full by the time it reaches the block.
                LinearGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: min(overhang / height, 1)),
                    .init(color: .black, location: 1)
                ], startPoint: .top, endPoint: .bottom)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Every cell of the tower's grid, from the bottom row upward.
///
/// **Bottom anchored, because the tower is.** A block's frame comes from
/// `GridConstants.blockFrame(column:row:...)` and is then flipped so row 0
/// sits on the ground; the lattice is built the same way round, from
/// `rect.maxY` up, so the ground row of cells is exactly the ground row of
/// blocks whatever the height happens to be. Measuring down from the top
/// would put the two half a gutter out of step at any height that is not a
/// whole number of rows.
struct TowerLatticeShape: Shape {
    var cellSize: CGFloat
    var spacing: CGFloat
    var columns: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = GridConstants.blockCornerRadius(forCell: cellSize)
        for cell in cellRects(in: rect) {
            path.addRoundedRect(in: cell,
                                cornerSize: CGSize(width: radius, height: radius),
                                style: .continuous)
        }
        return path
    }

    /// **Where every cell is, as numbers rather than as a drawn path.**
    ///
    /// Separate from `path(in:)` so a test can hold it against
    /// `GridConstants.blockFrame`, which is the only thing that makes this
    /// safe: a lattice a few points out of step with the blocks is worse
    /// than no lattice, and it is the kind of wrong nobody notices in a
    /// screenshot until the day a cell size changes.
    func cellRects(in rect: CGRect) -> [CGRect] {
        guard cellSize > 0, columns > 0 else { return [] }
        let pitch = cellSize + spacing
        var rects: [CGRect] = []
        var top = rect.maxY - cellSize
        // One row past the top edge, so a cell that is only half on screen is
        // still drawn rather than stopping in a straight line of its own.
        while top > rect.minY - pitch {
            for column in 0..<columns {
                let x = rect.minX + CGFloat(column) * pitch
                rects.append(CGRect(x: x, y: top, width: cellSize, height: cellSize))
            }
            top -= pitch
        }
        return rects
    }
}
