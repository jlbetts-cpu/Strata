import SwiftUI

struct CompletedHabitRow: View {
    let habit: Habit
    let log: HabitLog
    let onUndo: () -> Void

    private var style: CategoryStyle {
        habit.category.style
    }

    var body: some View {
        HStack(spacing: 12) {
            // Completed block indicator
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(style.gradient)
                    .frame(width: 36, height: 36)

                Image(systemName: "checkmark")
                    .font(Typography.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.title)
                    .font(Typography.bodyMedium)
                    .fontWeight(.medium)

                if let completedAt = log.completedAt {
                    Text(completedAt, style: .time)
                        .font(Typography.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Undo button
            Button(action: onUndo) {
                Image(systemName: "arrow.uturn.backward")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
