import SwiftUI

struct HabitItemRow: View {
    let habit: Habit
    let schedule: String

    var body: some View {
        HStack(spacing: 12) {
            blockSizeIndicator

            Text(habit.title)
                .font(Typography.bodyLarge)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            Text(schedule)
                .font(Typography.caption)
                .foregroundStyle(.secondary)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(habit.title), \(habit.category.rawValue), \(schedule)")
        .accessibilityHint("\(habit.blockSize.rawValue) effort")
    }

    @ViewBuilder
    private var blockSizeIndicator: some View {
        let color = habit.category.style.baseColor
        switch habit.blockSize {
        case .small:
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color)
                .frame(width: 16, height: 16)
        case .medium:
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color)
                .frame(width: 24, height: 16)
        case .hard:
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color)
                .frame(width: 24, height: 24)
        }
    }
}
