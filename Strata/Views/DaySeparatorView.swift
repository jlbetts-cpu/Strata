import SwiftUI

struct DaySeparator: Identifiable {
    let id: String // dateString
    let displayLabel: String
    let blockCount: Int
    let isPerfectDay: Bool
    let gridRow: Int // row where separator sits (between previous day's top and this day's bottom)
}

struct DaySeparatorView: View {
    let separator: DaySeparator
    let gridWidth: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            Text(separator.displayLabel)
                .font(Typography.caption2)
                .foregroundStyle(.primary.opacity(0.3))
            Rectangle()
                .fill(separator.isPerfectDay
                    ? GridConstants.patinaGold.opacity(0.3)
                    : Color.primary.opacity(0.08))
                .frame(height: 0.5)
            Text("\(separator.blockCount)")
                .font(Typography.caption2)
                .foregroundStyle(.primary.opacity(0.2))
            if separator.isPerfectDay {
                Image(systemName: "star.fill")
                    .iconSize(8, relativeTo: .caption2)
                    .foregroundStyle(GridConstants.patinaGold.opacity(0.5))
            }
        }
        .frame(width: gridWidth)
        .padding(.vertical, 4)
    }
}
