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

    /// Brightest along the top, exactly as a single block's rim is — but
    /// measured across the whole run, which is what makes a tall group read as
    /// one lit object rather than a column of separately lit ones.
    private var rim: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .white, location: 0.0),
                .init(color: .white.opacity(GridConstants.blockRimFalloff), location: 0.55),
                .init(color: .white.opacity(GridConstants.blockRimFalloff), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
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
            shape.fill(style.baseColor)

            // Frosted band, clipped to the shape so it never spills into the
            // notches of an irregular run.
            LinearGradient(
                stops: [
                    .init(color: .clear, location: GridConstants.blockBandStart),
                    .init(color: .white.opacity(GridConstants.blockScrimOpacity), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: bandHeight)
            .offset(y: bandTop)
            .clipShape(shape)

            shape.stroke(rim, lineWidth: GridConstants.blockRimWidth * styleScale)
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
