import SwiftUI

struct SkeletonBlockView: View {
    let width: CGFloat
    let height: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        RoundedRectangle(cornerRadius: GridConstants.blockCornerRadius, style: .continuous)
            .fill(
                colorScheme == .dark
                    ? Color(hex: 0x403D39).opacity(0.4)
                    : Color(hex: 0x403D39).opacity(0.12)
            )
            .frame(width: width, height: height)
            .shimmer()
            .clipShape(RoundedRectangle(cornerRadius: GridConstants.blockCornerRadius, style: .continuous))
            .accessibilityHidden(true)
    }
}
