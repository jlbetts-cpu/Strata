import SwiftUI

struct SkeletonBlockView: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: GridConstants.blockCornerRadius, style: .continuous)
            .fill(Color(hex: 0x403D39).opacity(0.12))
            .frame(width: width, height: height)
            .shimmer()
            .clipShape(RoundedRectangle(cornerRadius: GridConstants.blockCornerRadius, style: .continuous))
            .accessibilityHidden(true)
    }
}
