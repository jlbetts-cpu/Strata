import Foundation
import SwiftData
import SwiftUI

@Observable
final class TimelineViewModel {
    var modelContext: ModelContext?
    private(set) var todaysHabits: [Habit] = []
    private(set) var completedToday: [HabitLog] = []
    private(set) var incompleteToday: [Habit] = []
    private(set) var skippedHabitIDs: Set<UUID> = [] // rebuilt from persisted logs

    var currentDateString: String {
        Self.dateString(from: Date())
    }

    private static let dateStringFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dateString(from date: Date) -> String {
        dateStringFormatter.string(from: date)
    }

    // MARK: - Load Today's Data

    func loadToday(habits: [Habit], logs: [HabitLog]) {
        let today = DayCode.today()
        let dateStr = currentDateString

        // Filter habits scheduled for today
        let scheduled = habits.filter { habit in
            if habit.isTodo {
                return habit.scheduledDate == dateStr
            }
            return habit.frequency.contains(today)
        }

        todaysHabits = scheduled

        // Separate completed vs incomplete
        let todayLogs = logs.filter { $0.dateString == dateStr && $0.completed }
        let completedHabitIDs = Set(todayLogs.compactMap { $0.habit?.id })

        // Rebuild skipped set from persisted logs
        let skippedLogs = logs.filter { $0.dateString == dateStr && $0.skipped }
        skippedHabitIDs = Set(skippedLogs.compactMap { $0.habit?.id })

        completedToday = todayLogs
        incompleteToday = scheduled.filter {
            !completedHabitIDs.contains($0.id) && !skippedHabitIDs.contains($0.id)
        }
    }

    // MARK: - Complete a Habit

    func completeHabit(_ habit: Habit) {
        guard let context = modelContext else { return }

        let dateStr = currentDateString

        // Check if log already exists
        let habitID = habit.id
        let descriptor = FetchDescriptor<HabitLog>(
            predicate: #Predicate { log in
                log.dateString == dateStr && log.habit?.id == habitID
            }
        )

        if let existing = try? context.fetch(descriptor).first {
            existing.markCompleted()
        } else {
            let log = HabitLog(habit: habit, dateString: dateStr, completed: true)
            log.markCompleted()
            context.insert(log)
        }

        try? context.save()
    }

    // MARK: - Skip a Habit

    func skipHabit(_ habit: Habit) {
        guard let context = modelContext else { return }
        skippedHabitIDs.insert(habit.id)

        let dateStr = currentDateString
        let habitID = habit.id
        let descriptor = FetchDescriptor<HabitLog>(
            predicate: #Predicate { log in
                log.dateString == dateStr && log.habit?.id == habitID
            }
        )

        if let existing = try? context.fetch(descriptor).first {
            existing.skipped = true
        } else {
            let log = HabitLog(habit: habit, dateString: dateStr)
            log.skipped = true
            context.insert(log)
        }
        try? context.save()
    }

    // MARK: - Undo Completion

    func undoCompletion(_ habit: Habit) {
        guard let context = modelContext else { return }

        let dateStr = currentDateString
        let habitID = habit.id
        let descriptor = FetchDescriptor<HabitLog>(
            predicate: #Predicate { log in
                log.dateString == dateStr && log.habit?.id == habitID
            }
        )

        if let existing = try? context.fetch(descriptor).first {
            existing.markIncomplete()
            try? context.save()
        }
    }

    // MARK: - Undo Skip

    func undoSkip(_ habit: Habit) {
        guard let context = modelContext else { return }
        skippedHabitIDs.remove(habit.id)

        let dateStr = currentDateString
        let habitID = habit.id
        let descriptor = FetchDescriptor<HabitLog>(
            predicate: #Predicate { log in
                log.dateString == dateStr && log.habit?.id == habitID
            }
        )

        if let existing = try? context.fetch(descriptor).first {
            existing.skipped = false
            try? context.save()
        }
    }

    // MARK: - Time-Gated Visibility

    /// Resolves a habit's scheduled hour as a fractional value (e.g. 14.5 for 14:30).
    static func effectiveHour(for habit: Habit) -> Double? {
        if let timeStr = habit.scheduledTime {
            let parts = timeStr.split(separator: ":")
            guard !parts.isEmpty, let h = Double(parts[0]) else { return nil }
            let m = parts.count > 1 ? (Double(parts[1]) ?? 0) / 60.0 : 0
            return h + m
        }
        if let tod = habit.timeOfDay {
            switch tod {
            case .morning: return 8.0
            case .afternoon: return 13.0
            case .evening: return 18.0
            case .anytime: return 10.0
            }
        }
        return nil
    }

    /// Incomplete habits for tower display — all incomplete habits stay visible.
    var incompleteWithinHour: [Habit] {
        incompleteToday
    }

    // MARK: - Completion Progress

    var completionRate: Double {
        guard !todaysHabits.isEmpty else { return 0 }
        return Double(completedToday.count) / Double(todaysHabits.count)
    }

    // MARK: - Tower Vitality (Peripheral Pulse — Proposal C)

    /// Rolling vitality score (0.0 = dormant, 0.5 = neutral, 1.0 = thriving)
    /// Based on today's completion rate. Tower Claude can use this for ambient visual treatment.
    /// - 0.0-0.3: dormant (desaturated, still, "resting")
    /// - 0.3-0.7: neutral (standard appearance)
    /// - 0.7-1.0: thriving (warm, breathing, alive)
    var towerVitality: Double {
        completionRate
    }
}
