import Foundation
import SwiftData
import SwiftUI

@Observable @MainActor
final class InsightsViewModel {
    var selectedMonth: Date = Date()
    var selectedDay: Date? = nil
    var streaks: [(habit: Habit, streak: Int, bestStreak: Int)] = []
    var monthDays: [DayInsight] = []
    // MARK: - Day Insight Model

    struct DayInsight: Identifiable {
        let id = UUID()
        let date: Date
        let dayNumber: Int
        let isCurrentMonth: Bool
        let isFuture: Bool
        let isToday: Bool
        let completedCount: Int
        let skippedCount: Int
        let totalCount: Int
        let photoFileNames: [String]
        var hasPhoto: Bool { !photoFileNames.isEmpty }
        let habitStatuses: [HabitStatus]

        struct HabitStatus: Identifiable {
            let id: UUID
            let habit: Habit
            let isCompleted: Bool
            let isSkipped: Bool
            let photoFileName: String?
        }
    }

    // MARK: - Compute All Data

    func compute(habits: [Habit], logs: [HabitLog]) {
        computeStreaks(habits: habits, logs: logs)
        computeMonth(habits: habits, logs: logs)
    }

    // MARK: - Streaks

    private func computeStreaks(habits: [Habit], logs: [HabitLog]) {
        let streakVM = StreakViewModel()
        let currentStreaks = streakVM.calculateAllStreaks(habits: habits, logs: logs)

        // Best streaks: calculate by walking all logs per habit
        var bestStreaks: [UUID: Int] = [:]
        for habit in habits where !habit.isTodo {
            bestStreaks[habit.id] = calculateBestStreak(for: habit, logs: logs)
        }

        streaks = habits
            .filter { !$0.isTodo && $0.parentHabitID == nil }
            .map { habit in
                (habit: habit,
                 streak: currentStreaks[habit.id] ?? 0,
                 bestStreak: bestStreaks[habit.id] ?? 0)
            }
            .sorted { $0.streak > $1.streak }
    }

    private func calculateBestStreak(for habit: Habit, logs: [HabitLog]) -> Int {
        let habitLogs = logs
            .filter { $0.habit?.id == habit.id && $0.completed }
            .compactMap { $0.dateString }
            .sorted()

        guard !habitLogs.isEmpty else { return 0 }

        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var best = 1
        var current = 1
        let graceDays = habit.graceDays

        for i in 1..<habitLogs.count {
            guard let prev = formatter.date(from: habitLogs[i - 1]),
                  let curr = formatter.date(from: habitLogs[i]) else { continue }
            let gap = calendar.dateComponents([.day], from: prev, to: curr).day ?? 0
            if gap <= 1 + graceDays {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }
        return best
    }

    // MARK: - Month Grid

    func computeMonth(habits: [Habit], logs: [HabitLog]) {
        let calendar = Calendar.current
        let month = selectedMonth

        // Get first day of month and number of days
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return }
        let firstDay = monthInterval.start
        let daysInMonth = calendar.range(of: .day, in: .month, for: month)?.count ?? 30

        // First weekday offset (0 = Sunday in US locale)
        let firstWeekday = calendar.component(.weekday, from: firstDay) - 1

        // Build log index for this month
        let monthStr = TimelineViewModel.dateString(from: firstDay).prefix(7) // "2026-03"
        var logsByDate: [String: [HabitLog]] = [:]
        for log in logs where log.dateString.hasPrefix(String(monthStr)) {
            logsByDate[log.dateString, default: []].append(log)
        }

        // Build day insights
        var days: [DayInsight] = []

        // Leading empty days (before first of month)
        for _ in 0..<firstWeekday {
            days.append(DayInsight(
                date: firstDay, dayNumber: 0, isCurrentMonth: false,
                isFuture: false, isToday: false, completedCount: 0,
                skippedCount: 0, totalCount: 0,
                photoFileNames: [], habitStatuses: []
            ))
        }

        // Actual month days
        for dayOffset in 0..<daysInMonth {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: firstDay) else { continue }
            let dateStr = TimelineViewModel.dateString(from: date)
            let dayLogs = logsByDate[dateStr] ?? []
            let isToday = calendar.isDateInToday(date)
            let isFuture = date > Date() && !isToday

            // Get habits scheduled for this day
            let weekday = calendar.component(.weekday, from: date)
            let dayCode = DayCode.from(weekday: weekday)
            let scheduledHabits = habits.filter { habit in
                if habit.isTodo { return habit.scheduledDate == dateStr }
                return habit.frequency.contains(dayCode)
            }

            // Build per-habit statuses
            let statuses = scheduledHabits.map { habit -> DayInsight.HabitStatus in
                let log = dayLogs.first { $0.habit?.id == habit.id }
                return DayInsight.HabitStatus(
                    id: habit.id,
                    habit: habit,
                    isCompleted: log?.completed ?? false,
                    isSkipped: log?.skipped ?? false,
                    photoFileName: log?.imageFileName
                )
            }

            let completed = dayLogs.filter { $0.completed }.count
            let skipped = dayLogs.filter { $0.skipped }.count
            let photoFiles = dayLogs.compactMap(\.imageFileName)

            days.append(DayInsight(
                date: date,
                dayNumber: dayOffset + 1,
                isCurrentMonth: true,
                isFuture: isFuture,
                isToday: isToday,
                completedCount: completed,
                skippedCount: skipped,
                totalCount: scheduledHabits.count,
                photoFileNames: photoFiles,
                habitStatuses: statuses
            ))
        }

        monthDays = days
    }

    // MARK: - Month Navigation

    func previousMonth(habits: [Habit], logs: [HabitLog]) {
        let calendar = Calendar.current
        if let prev = calendar.date(byAdding: .month, value: -1, to: selectedMonth) {
            selectedMonth = prev
            selectedDay = nil
            computeMonth(habits: habits, logs: logs)
        }
    }

    func nextMonth(habits: [Habit], logs: [HabitLog]) {
        let calendar = Calendar.current
        if let next = calendar.date(byAdding: .month, value: 1, to: selectedMonth) {
            selectedMonth = next
            selectedDay = nil
            computeMonth(habits: habits, logs: logs)
        }
    }

    // MARK: - Month Title

    var monthTitle: String {
        selectedMonth.formatted(.dateTime.month(.wide).year())
    }

}
