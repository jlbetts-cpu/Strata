import SwiftUI

struct TowerNextUpPill: View {
    let habitTitle: String
    let category: HabitCategory
    let onTap: () -> Void

    @ScaledMetric(relativeTo: .caption) private var iconSize: CGFloat = GridConstants.iconMedium
    @ScaledMetric(relativeTo: .caption2) private var chevronSize: CGFloat = GridConstants.iconChevron

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: category.iconName)
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundStyle(category.style.baseColor)
                Text("Next: \(habitTitle)")
                    .font(Typography.caption)
                    .foregroundStyle(.primary.opacity(0.7))
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: chevronSize, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
