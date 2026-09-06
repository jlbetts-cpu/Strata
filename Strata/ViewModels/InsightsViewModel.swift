import Foundation
import SwiftData
import SwiftUI

// MARK: - Range

enum InsightsRange: String, CaseIterable, Identifiable {
    case week
    case month
    case quarter

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .week:    return 7
        case .month:   return 30
        case .quarter: return 90
        }
    }

    /// Segmented control label
    var label: String {
        switch self {
        case .week:    return "7D"
        case .month:   return "30D"
        case .quarter: return "90D"
        }
    }

    /// Spoken / prose form
    var longLabel: String {
        switch self {
        case .week:    return "last 7 days"
        case .month:   return "last 30 days"
        case .quarter: return "last 90 days"
        }
    }
}

// MARK: - Day Mark (positive-only vocabulary)

/// How a single habit-day resolved.
///
/// Deliberately has no `missed` case. An unresolved scheduled day is `.open` —
/// the app's reinforcement model is positive-only (see coordination.md, Tower
/// principles: no streaks-as-loss, no shame signaling).
enum DayMark {
    case completed
    case skipped        // handled, not failed (Zeigarnik 1927 — closure)
    case open           // scheduled, not resolved
    case unscheduled    // rest day, or before the habit existed
}

// MARK: - Aggregates

/// One cell of the momentum heatmap. `id` is the date string, not a UUID —
/// stable identity across rebuilds (avoids the DayProgressData churn noted as T11).
struct InsightsDay: Identifiable {
    let id: String
    let date: Date
    let completed: Int
    let skipped: Int
    let scheduled: Int
    let isToday: Bool

    /// Completed / scheduled. 0 when nothing was scheduled.
    var completionRate: Double {
        guard scheduled > 0 else { return 0 }
        return Double(completed) / Double(scheduled)
    }
}

/// Per-habit momentum row.
struct HabitMomentum: Identifiable {
    let id: UUID
    let title: String
    let category: HabitCategory
    /// Consecutive resolved days, grace-aware. From StreakViewModel.
    let currentRun: Int
    let completed: Int
    let scheduled: Int
    /// Trailing 7 days, oldest first — positive-only strip.
    let recent: [DayMark]

    var rate: Double {
        guard scheduled > 0 else { return 0 }
        return Double(completed) / Double(scheduled)
    }
}

/// Completions grouped by category.
struct CategoryTotal: Identifiable {
    let id: String
    let category: HabitCategory
    let completed: Int
    /// Fraction of the largest category's total — drives bar width.
    var share: Double
}

/// Completion rate bucketed by weekday.
struct WeekdayRhythm: Identifiable {
    let id: String
    let label: String
    let completed: Int
    let scheduled: Int

    var rate: Double {
        guard scheduled > 0 else { return 0 }
        return Double(completed) / Double(scheduled)
    }
}

// MARK: - View Model

/// Aggregates habit history for the Insights tab.
///
/// All work happens in `rebuild(habits:logs:range:)` — never in a view body.
/// One pass builds the log index, then day/habit/category aggregates read it in
/// O(1). Budget: <50ms for 3,000 logs + 100 habits (brand.md performance standards).
@Observable
final class InsightsViewModel {

    // Outputs
    private(set) var days: [InsightsDay] = []
    private(set) var habitMomentum: [HabitMomentum] = []
    private(set) var categoryTotals: [CategoryTotal] = []
    private(set) var weekdayRhythm: [WeekdayRhythm] = []

    // Headline numbers
    private(set) var totalCompleted: Int = 0
    private(set) var totalSkipped: Int = 0
    private(set) var totalScheduled: Int = 0
    private(set) var activeDayCount: Int = 0
    private(set) var bestWeekday: WeekdayRhythm?
    private(set) var hasAnyHabits: Bool = false

    private let streakEngine = StreakViewModel()

    /// Completed + skipped / scheduled — the honest "closed the loop" number.
    var handledRate: Double {
        guard totalScheduled > 0 else { return 0 }
        return Double(totalCompleted + totalSkipped) / Double(totalScheduled)
    }

    // MARK: - Rebuild

    func rebuild(habits: [Habit], logs: [HabitLog], range: InsightsRange) {
        hasAnyHabits = !habits.isEmpty

        guard !habits.isEmpty else {
            days = []
            habitMomentum = []
            categoryTotals = []
            weekdayRhythm = []
            totalCompleted = 0
            totalSkipped = 0
            totalScheduled = 0
            activeDayCount = 0
            bestWeekday = nil
            return
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayStr = TimelineViewModel.dateString(from: today)

        // Single pass: index logs by "habitID|date" for O(1) lookup, and by habit
        // so StreakViewModel filters a short array instead of the whole history.
        var logIndex: [String: HabitLog] = [:]
        var logsByHabit: [UUID: [HabitLog]] = [:]
        logIndex.reserveCapacity(logs.count)
        for log in logs {
            guard let habitID = log.habit?.id else { continue }
            logIndex["\(habitID.uuidString)|\(log.dateString)"] = log
            logsByHabit[habitID, default: []].append(log)
        }

        // Walk the window oldest -> newest.
        var dayBuckets: [InsightsDay] = []
        dayBuckets.reserveCapacity(range.days)

        var categoryCounts: [HabitCategory: Int] = [:]
        var weekdayCompleted: [Int: Int] = [:]
        var weekdayScheduled: [Int: Int] = [:]
        var perHabitCompleted: [UUID: Int] = [:]
        var perHabitScheduled: [UUID: Int] = [:]
        var perHabitRecent: [UUID: [DayMark]] = [:]

        var rangeCompleted = 0
        var rangeSkipped = 0
        var rangeScheduled = 0
        var activeDays = 0

        // Trailing 7 days feed the per-habit strip regardless of selected range.
        let stripCutoff = calendar.date(byAdding: .day, value: -6, to: today) ?? today

        for offset in stride(from: range.days - 1, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let dateStr = TimelineViewModel.dateString(from: date)
            let weekday = calendar.component(.weekday, from: date)
            let dayCode = DayCode.from(weekday: weekday)
            let inStrip = date >= stripCutoff

            var dayCompleted = 0
            var daySkipped = 0
            var dayScheduled = 0

            for habit in habits {
                guard wasScheduled(habit, on: date, dateStr: dateStr, dayCode: dayCode, calendar: calendar) else {
                    if inStrip { perHabitRecent[habit.id, default: []].append(.unscheduled) }
                    continue
                }

                dayScheduled += 1
                perHabitScheduled[habit.id, default: 0] += 1
                weekdayScheduled[weekday, default: 0] += 1

                let log = logIndex["\(habit.id.uuidString)|\(dateStr)"]
                let mark: DayMark
                if let log, log.completed {
                    mark = .completed
                    dayCompleted += 1
                    perHabitCompleted[habit.id, default: 0] += 1
                    weekdayCompleted[weekday, default: 0] += 1
                    categoryCounts[habit.category, default: 0] += 1
                } else if let log, log.skipped {
                    mark = .skipped
                    daySkipped += 1
                } else {
                    mark = .open
                }

                if inStrip { perHabitRecent[habit.id, default: []].append(mark) }
            }

            rangeCompleted += dayCompleted
            rangeSkipped += daySkipped
            rangeScheduled += dayScheduled
            if dayCompleted > 0 { activeDays += 1 }

            dayBuckets.append(
                InsightsDay(
                    id: dateStr,
                    date: date,
                    completed: dayCompleted,
                    skipped: daySkipped,
                    scheduled: dayScheduled,
                    isToday: dateStr == todayStr
                )
            )
        }

        days = dayBuckets
        totalCompleted = rangeCompleted
        totalSkipped = rangeSkipped
        totalScheduled = rangeScheduled
        activeDayCount = activeDays

        // Per-habit momentum, sorted by longest active run.
        habitMomentum = habits.map { habit in
            HabitMomentum(
                id: habit.id,
                title: habit.title,
                category: habit.category,
                currentRun: currentRun(for: habit, logs: logsByHabit[habit.id] ?? [], todayStr: todayStr, logIndex: logIndex),
                completed: perHabitCompleted[habit.id] ?? 0,
                scheduled: perHabitScheduled[habit.id] ?? 0,
                recent: perHabitRecent[habit.id] ?? []
            )
        }
        .sorted { lhs, rhs in
            if lhs.currentRun != rhs.currentRun { return lhs.currentRun > rhs.currentRun }
            if lhs.completed != rhs.completed { return lhs.completed > rhs.completed }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }

        // Category balance — share is relative to the biggest category, so the
        // top bar always reads full width.
        let maxCategory = categoryCounts.values.max() ?? 0
        categoryTotals = HabitCategory.allCases.compactMap { category in
            let count = categoryCounts[category] ?? 0
            guard count > 0 else { return nil }
            return CategoryTotal(
                id: category.rawValue,
                category: category,
                completed: count,
                share: maxCategory > 0 ? Double(count) / Double(maxCategory) : 0
            )
        }
        .sorted { $0.completed > $1.completed }

        // Weekday rhythm, Sunday-first to match DayCode.
        let symbols = calendar.shortWeekdaySymbols
        weekdayRhythm = (1...7).map { weekday in
            WeekdayRhythm(
                id: "wd-\(weekday)",
                label: symbols.indices.contains(weekday - 1) ? symbols[weekday - 1] : "",
                completed: weekdayCompleted[weekday] ?? 0,
                scheduled: weekdayScheduled[weekday] ?? 0
            )
        }

        // Only call a day "best" once there is enough of it to mean anything.
        bestWeekday = weekdayRhythm
            .filter { $0.scheduled >= 2 && $0.completed > 0 }
            .max { $0.rate < $1.rate }
    }

    // MARK: - Helpers

    /// Was this habit on the hook for `date`?
    ///
    /// Days before the habit was created never count. Without this a habit added
    /// yesterday reads as 3% complete over 90 days — an accidental shame signal.
    private func wasScheduled(
        _ habit: Habit,
        on date: Date,
        dateStr: String,
        dayCode: DayCode,
        calendar: Calendar
    ) -> Bool {
        guard date >= calendar.startOfDay(for: habit.createdAt) else { return false }
        if habit.isTodo { return habit.scheduledDate == dateStr }
        return habit.frequency.contains(dayCode)
    }

    /// Current run in days, grace-aware.
    ///
    /// `StreakViewModel.calculateStreak` starts at yesterday — today is never
    /// counted, so a habit completed this morning would show no movement. Today's
    /// completion is added here rather than changing StreakViewModel's semantics,
    /// which other screens may come to rely on.
    private func currentRun(
        for habit: Habit,
        logs: [HabitLog],
        todayStr: String,
        logIndex: [String: HabitLog]
    ) -> Int {
        let historical = streakEngine.calculateStreak(for: habit, logs: logs)
        let completedToday = logIndex["\(habit.id.uuidString)|\(todayStr)"]?.completed ?? false
        return historical + (completedToday ? 1 : 0)
    }
}
