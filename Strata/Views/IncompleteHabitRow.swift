import SwiftUI

struct IncompleteHabitRow: View {
    let habit: Habit
    let onComplete: () -> Void

    @State private var holdProgress: Double = 0

    private let holdDuration: Double = 0.6

    private var style: CategoryStyle {
        habit.category.style
    }

    var body: some View {
        HStack(spacing: 12) {
            // Block preview
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(style.gradient.opacity(0.3))
                    .frame(width: 36, height: 36)

                // Hold progress fill
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(style.gradient)
                    .frame(width: 36, height: 36)
                    .mask(alignment: .bottom) {
                        Rectangle()
                            .frame(height: 36 * holdProgress)
                    }

                // Size indicator
                Text(sizeText)
                    .font(Typography.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(style.text.opacity(holdProgress > 0.5 ? 1 : 0.5))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.title)
                    .font(Typography.bodyMedium)
                    .fontWeight(.medium)

                if let time = habit.scheduledTime {
                    Text(time)
                        .font(Typography.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Circle()
                .fill(style.gradientBottom)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: holdDuration, perform: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            onComplete()
            withAnimation(.easeOut(duration: 0.3)) { holdProgress = 0 }
        }, onPressingChanged: { pressing in
            if pressing {
                withAnimation(.linear(duration: holdDuration)) { holdProgress = 1.0 }
            } else {
                withAnimation(.easeOut(duration: 0.2)) { holdProgress = 0 }
            }
        })
    }

    private var sizeText: String {
        switch habit.blockSize {
        case .small: return "1"
        case .medium: return "2"
        case .hard: return "4"
        }
    }
}
