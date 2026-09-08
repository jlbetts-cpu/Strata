import SwiftUI

/// What travels under the finger during a rearrange.
///
/// A small, plain copy of the block rather than the block itself. The real one
/// carries a photo, a title and — if it is part of a merged run — no surface of
/// its own at all, so lifting it literally would sometimes lift something
/// invisible. This is always a block, at a size a thumb does not cover.
struct BlockDragPreview: View {
    let block: PlacedBlock
    let side: CGFloat

    private var size: CGFloat { min(max(side * 0.7, 44), 72) }

    var body: some View {
        RoundedRectangle(
            cornerRadius: GridConstants.blockCornerRadius(forCell: size),
            style: .continuous
        )
        .fill(block.habit.displayCategory.style.baseColor)
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(
                cornerRadius: GridConstants.blockCornerRadius(forCell: size),
                style: .continuous
            )
            .stroke(.white.opacity(0.9), lineWidth: GridConstants.blockRimWidth)
        }
    }
}
