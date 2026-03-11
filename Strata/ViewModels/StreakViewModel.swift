import Foundation

@Observable
final class StreakViewModel {

    enum DangerLevel: String {
        case none
        case medium   // 3-6 days
        case high     // 7-13 days
        case critical // 14+ days
    }

    // MARK: - Calculate Streak for a Habit

    func calculateStreak(for habit: Habit, logs: [HabitLog]) -> Int {
        let grace = habit.graceDays
        let calendar = Calendar.current
        let sortedLogs = logs
            .filter { $0.habit?.id == habit.id }
            .reduce(into: [String: HabitLog]()) { dict, log in
                dict[log.dateString] = log
            }

        var streak = 0
        var missedInARow = 0
        var currentDate = Date()

        // Walk backwards up to 365 days
        for _ in 0..<365 {
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            let dateStr = TimelineViewModel.dateString(from: currentDate)
            let weekday = calendar.component(.weekday, from: currentDate)
            let dayCode = DayCode.from(weekday: weekday)

            // Skip rest days
            if !habit.isTodo && !habit.frequency.contains(dayCode) {
                continue
            }

            if let log = sortedLogs[dateStr], log.completed {
                streak += 1
                missedInARow = 0
            } else {
                missedInARow += 1
                if missedInARow > grace {
                    break
                }
            }
        }

        return streak
    }

    // MARK: - Danger Level

    func dangerLevel(for streak: Int) -> DangerLevel {
        switch streak {
        case 14...: return .critical
        case 7..<14: return .high
        case 3..<7: return .medium
        default: return .none
        }
    }

    // MARK: - Bulk Streak Calculation

    func calculateAllStreaks(habits: [Habit], logs: [HabitLog]) -> [UUID: Int] {
        var streaks: [UUID: Int] = [:]
        for habit in habits {
            streaks[habit.id] = calculateStreak(for: habit, logs: logs)
        }
        return streaks
    }
}
