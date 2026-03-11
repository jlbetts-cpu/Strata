import Foundation
import SwiftData
import SwiftUI

@Observable
final class HabitManagerViewModel {
    var modelContext: ModelContext?

    // MARK: - Create Habit

    func createHabit(
        title: String,
        category: HabitCategory,
        blockSize: BlockSize = .small,
        frequency: [DayCode] = DayCode.allCases,
        scheduledTime: String? = nil,
        graceDays: Int = 1,
        timeOfDay: TimeOfDay? = .anytime,
        isTodo: Bool = false,
        scheduledDate: String? = nil
    ) {
        guard let context = modelContext else { return }

        let habit = Habit(
            title: title,
            category: category,
            blockSize: blockSize,
            frequency: frequency,
            scheduledTime: scheduledTime,
            graceDays: graceDays,
            timeOfDay: timeOfDay
        )
        habit.isTodo = isTodo
        habit.scheduledDate = scheduledDate

        context.insert(habit)
        try? context.save()
    }

    // MARK: - Delete Habit

    func deleteHabit(_ habit: Habit) {
        guard let context = modelContext else { return }
        context.delete(habit)
        try? context.save()
    }

    // MARK: - Update Habit

    func updateHabit(
        _ habit: Habit,
        title: String? = nil,
        category: HabitCategory? = nil,
        blockSize: BlockSize? = nil,
        frequency: [DayCode]? = nil,
        scheduledTime: String? = nil,
        graceDays: Int? = nil,
        timeOfDay: TimeOfDay? = nil
    ) {
        if let title { habit.title = title }
        if let category { habit.category = category }
        if let blockSize { habit.blockSize = blockSize }
        if let frequency { habit.frequency = frequency }
        if let scheduledTime { habit.scheduledTime = scheduledTime }
        if let graceDays { habit.graceDays = graceDays }
        if let timeOfDay { habit.timeOfDay = timeOfDay }

        try? modelContext?.save()
    }

    // MARK: - Demo Data

    func insertDemoData() {
        guard let context = modelContext else { return }

        let demoHabits: [(String, HabitCategory, BlockSize)] = [
            ("Drink Water", .social, .small),
            ("Call a Friend", .social, .small),
            ("Meditate", .mindfulness, .small),
            ("Read 30 mins", .focus, .small),
            ("Morning Exercise", .health, .medium),
            ("Deep Work Session", .work, .hard),
            ("Gym", .health, .hard),
            ("Sketch", .creativity, .medium),
        ]

        let calendar = Calendar.current

        for (title, category, size) in demoHabits {
            let habit = Habit(
                title: title,
                category: category,
                blockSize: size
            )
            context.insert(habit)

            // Add varied completed logs for the past few days
            let daysBack = Int.random(in: 2...5)
            for dayOffset in 1...daysBack {
                // Skip some days randomly for variety
                if Bool.random() && dayOffset > 1 { continue }

                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
                let dateStr = TimelineViewModel.dateString(from: date)
                let log = HabitLog(habit: habit, dateString: dateStr, completed: true)
                log.markCompleted()
                log.completedAt = calendar.date(
                    byAdding: .hour,
                    value: -Int.random(in: 1...12),
                    to: date
                )
                log.xpCollected = true
                context.insert(log)
            }
        }

        try? context.save()
    }
}
