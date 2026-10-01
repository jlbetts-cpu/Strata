import SwiftUI

/// A run of unnamed same-colour blocks, drawn once as one object.
///
/// Everything that makes a block look like a block happens here exactly once
/// for the whole run: one outline, one frosted band at the bottom, one shadow.
/// Its member blocks draw nothing at all — that is the point. Suppressing those
/// things per block and hiding the parts that land on a seam gets close but
/// never clean, because each suppression leaves an edge behind and four of them
/// stacked is what produced the stray pixels and half-lines.
///
/// It is laid out over the whole grid and positions itself through the path, so
/// there is no frame to keep in sync with the blocks underneath.
struct MergedGroupView: View {
    let group: MergeGroup
    let cellSize: CGFloat
    let gridWidth: CGFloat
    let gridHeight: CGFloat
    /// Everything the block's look is made of, scaled together.
    ///
    /// The corner radius, the rim and the shadow are absolute values tuned
    /// against the tower's ~86.5pt cell. Drawing the same absolutes at the
    /// Insights chart's 34pt cell is not the tower at a smaller size, it is a
    /// different block: a 12pt radius becomes 35% of the side, so a square
    /// reads as a pill, and the shadow ends up bigger than the thing casting
    /// it. Anywhere the cell is not the tower's, pass the ratio.
    var styleScale: CGFloat = 1

    /// The rim eases off in dark mode, so the run has to know the appearance
    /// for the same reason a single block does.
    @Environment(\.colorScheme) private var colorScheme

    /// And the lamp over the tower, for the same reason again. A merged run is
    /// ONE body, so it takes one aim — worked out from the centre of the whole
    /// run rather than from any member — which is what keeps its single glow and
    /// its single rim agreeing with each other. See `BlockLight`.
    @Environment(\.blockLight) private var blockLight

    private var aim: BlockAim {
        guard let blockLight,
              let minC = group.cells.map(\.column).min(),
              let maxC = group.cells.map(\.column).max(),
              let minR = group.cells.map(\.row).min(),
              let maxR = group.cells.map(\.row).max()
        else { return .overhead }
        return blockLight.aim(centreColumn: CGFloat(minC + maxC + 1) / 2,
                              centreRow: CGFloat(minR + maxR + 1) / 2)
    }

    private var style: CategoryStyle { group.category.style }

    private var shape: MergedShape {
        MergedShape(
            cells: group.cells,
            cellSize: cellSize,
            spacing: GridConstants.spacing,
            gridHeight: gridHeight,
            cornerRadius: GridConstants.blockCornerRadius * styleScale
        )
    }

    /// **The run's own rectangle, in the grid's coordinates.**
    ///
    /// The same arithmetic `MergedShape.rect(for:)` uses, inset by half the gap
    /// the way that shape's polygon is, so this lands exactly on the real block
    /// bounds: a cell occupies `(column * pitch, gridHeight - row * pitch -
    /// cellSize)` at `cellSize` square.
    ///
    /// It is the bounding box, so an L-shaped run gets a rectangle slightly
    /// bigger than itself. That is right for a gradient — the light belongs to
    /// the whole body — and the mask takes care of the rest.
    private var runBounds: CGRect {
        let pitch = cellSize + GridConstants.spacing
        guard let minC = group.cells.map(\.column).min(),
              let maxC = group.cells.map(\.column).max(),
              let minR = group.cells.map(\.row).min(),
              let maxR = group.cells.map(\.row).max()
        else { return CGRect(x: 0, y: 0, width: cellSize, height: cellSize) }
        let x = CGFloat(minC) * pitch
        let width = CGFloat(maxC - minC) * pitch + cellSize
        let y = gridHeight - CGFloat(maxR) * pitch - cellSize
        let height = CGFloat(maxR - minR) * pitch + cellSize
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// The band belongs to the bottom of the SHAPE, not the bottom of each
    /// block in it. Anchored to the lowest row the group occupies and given one
    /// block's height, so a five-block column frosts once, at the floor.
    private var bandHeight: CGFloat { cellSize }

    private var bandTop: CGFloat {
        let pitch = cellSize + GridConstants.spacing
        let bottom = gridHeight - CGFloat(group.bottomRow) * pitch
        return bottom - bandHeight
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Lit from inside, like every other coloured surface in the app
            // now. A merged run is one body, so the glow is sized to the whole
            // run rather than per member — which is the point of merging.
            //
            // **AND IT HAS TO BE SIZED TO THE RUN, WHICH IT WAS NOT.**
            //
            // This was a `GeometryReader` handing `geo.size` to the gradient,
            // and a `GeometryReader` here reports the WHOLE GRID: this view is
            // laid out over the entire tower and positions itself through the
            // path. So every merged run in the tower was showing its own slice
            // of one gradient centred on the middle of the tower and half the
            // tower tall — bright in the middle of the screen, drained to
            // near-white everywhere else.
            //
            // That is the owner's "splotch in the middle", and it is also his
            // "the bottom isn't even curved any more": a run at the foot of the
            // tower was sitting at the far end of that gradient, so its colour
            // came out close enough to the page's own near-white that its
            // rounded corners had nothing left to read against.
            //
            // The fill is drawn in the RUN's own rect now and masked by the
            // path, so the glow is the size and shape of the thing it is in.
            Rectangle()
                .fill(EtherealFill.fill(style.baseColor, aim: aim))
                .frame(width: runBounds.width, height: runBounds.height)
                .position(x: runBounds.midX, y: runBounds.midY)
                .mask { shape }

            // Frosted band, clipped to the shape so it never spills into the
            // notches of an irregular run.
            //
            // `BlockWash` is the band a single block draws. It was a second
            // copy of the same gradient here; one object, one definition.
            BlockWash()
                .frame(height: bandHeight)
                .offset(y: bandTop)
                .clipShape(shape)

            // The rim is drawn INSIDE the silhouette, the way
            // `BlockSurface.strokeBorder` draws it.
            //
            // `stroke` centres the line on the path, so 0.7pt of white hung
            // outside the run, over the 4pt gutter, making it 1.4pt wider and
            // taller than the blocks it replaces. `MergedShape` promises the
            // opposite in its own doc comment: "a merged run is exactly as wide
            // as the blocks it replaces". `MergedShape` is only `Shape`, not
            // `InsettableShape`, so `strokeBorder` is unavailable; a
            // double-width stroke clipped to the shape is the same edge.
            shape
                .stroke(
                    BlockRim.gradient(in: colorScheme, aim: aim),
                    lineWidth: GridConstants.blockRimWidth * styleScale * 2
                )
                .clipShape(shape)
        }
        .frame(width: gridWidth, height: gridHeight, alignment: .topLeading)
        .compositingGroup()
        .shadow(
            color: .black.opacity(GridConstants.blockShadowOpacity),
            radius: GridConstants.blockShadowRadius * styleScale,
            x: 0,
            y: GridConstants.blockShadowY * styleScale
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
