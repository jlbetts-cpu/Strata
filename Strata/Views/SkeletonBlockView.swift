import SwiftUI

/// A cell the tower has not filled yet.
///
/// **It does not breathe.** It carried `.shimmer()`, a 1.1s `repeatForever`
/// pulse between 0.03 and 0.09 of ink on top of this 0.10 fill. Three things
/// are wrong with that: the design language says nothing loops and nothing
/// animates because a screen appeared; the skeleton is only on screen for about
/// half a second (a 100ms grace and a 300ms hold in `MainAppView`), so a 1.1s
/// cycle never reads as a breath, only as the grid darkening just before the
/// blocks arrive; and it darkened the handover itself, muddying each block's
/// colour as it faded in over the top.
///
/// What is left says the true thing without moving: a block's shape, at a
/// block's corner, in quiet ink. The tower is not here yet.
struct SkeletonBlockView: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: GridConstants.blockCornerRadius, style: .continuous)
            // Adaptive, like everything else that stands on the page: a
            // fixed warm black was a dark smudge on the dark ground.
            .fill(AppColors.slotInk.opacity(0.10))
            .frame(width: width, height: height)
            // No second `clipShape`. It was clipping the shimmer's overlay to
            // the corner; the fill is already the shape.
            .accessibilityHidden(true)
    }
}
