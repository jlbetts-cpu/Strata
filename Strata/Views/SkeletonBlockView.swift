import SwiftUI

struct SkeletonBlockView: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: GridConstants.blockCornerRadius, style: .continuous)
            // Adaptive, like everything else that stands on the page: a
            // fixed warm black was a dark smudge on the dark ground.
            .fill(AppColors.slotInk.opacity(0.10))
            .frame(width: width, height: height)
            .shimmer()
            .clipShape(RoundedRectangle(cornerRadius: GridConstants.blockCornerRadius, style: .continuous))
            .accessibilityHidden(true)
    }
}
