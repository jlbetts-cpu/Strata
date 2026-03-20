import SwiftUI

struct WeekStripView: View {
    let selectedDate: Date
    let completedDates: Set<String>
    let onSelectDate: (Date) -> Void

    private let calendar = Calendar.current
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    private var weekDates: [Date] {
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(weekDates.enumerated()), id: \.offset) { index, date in
                dayButton(index: index, date: date)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func dayButton(index: Int, date: Date) -> some View {
        let dayNum = calendar.component(.day, from: date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let dateStr = TimelineViewModel.dateString(from: date)
        let isCompleted = completedDates.contains(dateStr)
        let isPast = date < calendar.startOfDay(for: Date()) && !calendar.isDateInToday(date)
        let isFuture = date > Date() && !calendar.isDateInToday(date)

        return Button {
            onSelectDate(date)
        } label: {
            VStack(spacing: 6) {
                Text(dayLabels[index])
                    .font(Typography.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.secondary)
                    .opacity(isFuture ? 0.5 : 1.0)

                ZStack {
                    // Background
                    Circle()
                        .fill(isSelected ? AppColors.accentWarm : Color.clear)
                        .frame(width: 36, height: 36)

                    // Day number
                    Text("\(dayNum)")
                        .font(Typography.bodyMedium)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .opacity(isFuture ? 0.4 : 1.0)

                    // Completion ring
                    if isCompleted && !isSelected {
                        Circle()
                            .stroke(HabitCategory.health.style.gradientBottom, lineWidth: 2.5)
                            .frame(width: 36, height: 36)

                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(HabitCategory.health.style.gradientBottom)
                            .offset(x: 12, y: -12)
                    } else if isPast && !isCompleted && !isSelected {
                        Circle()
                            .stroke(Color.primary.opacity(0.1), lineWidth: 2)
                            .frame(width: 36, height: 36)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}
