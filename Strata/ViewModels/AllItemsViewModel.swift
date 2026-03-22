import Foundation
import SwiftUI
import SwiftData

enum ItemFilter: String, CaseIterable {
    case all = "All"
    case habits = "Habits"
    case tasks = "Tasks"
}

@Observable @MainActor
final class AllItemsViewModel {

    // MARK: - Filter

    var filter: ItemFilter = .all

    // MARK: - Quick-Add State

    var quickAddTitle: String = ""
    var quickAddIsTask: Bool = false
    var quickAddCategory: HabitCategory = .health
    var quickAddBlockSize: BlockSize = .small
    var quickAddDays: Set<DayCode> = Set(DayCode.allCases)
    var quickAddScheduledDate: Date = Date()
    var quickAddUseTime: Bool = false
    var quickAddTime: Date = Date()
    var isDetailsExpanded: Bool = false

    // MARK: - Edit State

    var editingHabit: Habit? = nil

    // MARK: - Smart Suggestion

    var suggestedCategory: HabitCategory? {
        CategorySuggestionEngine.suggest(for: quickAddTitle)
    }

    var suggestedSize: BlockSize? {
        CategorySuggestionEngine.suggestSize(for: quickAddTitle)
    }

    var effectiveCategory: HabitCategory {
        suggestedCategory ?? quickAddCategory
    }

    var effectiveSize: BlockSize {
        suggestedSize ?? quickAddBlockSize
    }

    // MARK: - Counts

    func habitCount(from habits: [Habit]) -> Int {
        habits.filter { !$0.isTodo }.count
    }

    func taskCount(from habits: [Habit]) -> Int {
        habits.filter { $0.isTodo }.count
    }

    // MARK: - Filtered Data

    func filteredHabits(from habits: [Habit]) -> [Habit] {
        habits
            .filter { !$0.isTodo }
            .sorted { a, b in
                if a.category.rawValue != b.category.rawValue {
                    return a.category.rawValue < b.category.rawValue
                }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
    }

    func filteredTasks(from habits: [Habit]) -> [Habit] {
        habits
            .filter { $0.isTodo }
            .sorted { a, b in
                if let dateA = a.scheduledDate, let dateB = b.scheduledDate {
                    if dateA != dateB { return dateA < dateB }
                }
                return a.createdAt < b.createdAt
            }
    }

    // MARK: - Schedule Description

    func scheduleDescription(for habit: Habit) -> String {
        if habit.isTodo {
            guard let dateStr = habit.scheduledDate else { return "No date" }
            let today = TimelineViewModel.dateString(from: Date())
            if dateStr == today { return "Today" }

            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            let tomorrowStr = TimelineViewModel.dateString(from: tomorrow)
            if dateStr == tomorrowStr { return "Tomorrow" }

            return formatShortDate(dateStr)
        }

        let freq = habit.frequency
        if freq.count == DayCode.allCases.count { return "Daily" }
        if freq.isEmpty { return "No days" }

        let weekdays: Set<DayCode> = [.mo, .tu, .we, .th, .fr]
        if Set(freq) == weekdays { return "Weekdays" }

        let weekends: Set<DayCode> = [.sa, .su]
        if Set(freq) == weekends { return "Weekends" }

        return freq.map(\.rawValue).joined(separator: " ")
    }

    func isOverdue(_ habit: Habit) -> Bool {
        guard habit.isTodo, let dateStr = habit.scheduledDate else { return false }
        let today = TimelineViewModel.dateString(from: Date())
        return dateStr < today
    }

    private func formatShortDate(_ dateStr: String) -> String {
        let parts = dateStr.split(separator: "-")
        guard parts.count == 3,
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return dateStr }

        let monthNames = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
                          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        guard month >= 1, month <= 12 else { return dateStr }
        return "\(monthNames[month]) \(day)"
    }

    // MARK: - Quick Add

    func commitQuickAdd(context: ModelContext, tower: Tower?) {
        let trimmed = quickAddTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        var timeStr: String? = nil
        if quickAddUseTime {
            let cal = Calendar.current
            let h = cal.component(.hour, from: quickAddTime)
            let m = cal.component(.minute, from: quickAddTime)
            timeStr = String(format: "%02d:%02d", h, m)
        }

        let habit = Habit(
            title: trimmed,
            category: effectiveCategory,
            blockSize: effectiveSize,
            frequency: quickAddIsTask ? [] : Array(quickAddDays),
            scheduledTime: timeStr,
            isTodo: quickAddIsTask,
            scheduledDate: quickAddIsTask ? TimelineViewModel.dateString(from: quickAddScheduledDate) : nil
        )
        habit.tower = tower

        context.insert(habit)
        try? context.save()

        HapticsEngine.snap()
        resetQuickAdd()
    }

    func resetQuickAdd() {
        quickAddTitle = ""
        quickAddIsTask = false
        quickAddCategory = .health
        quickAddBlockSize = .small
        quickAddDays = Set(DayCode.allCases)
        quickAddScheduledDate = Date()
        quickAddUseTime = false
        quickAddTime = Date()
        isDetailsExpanded = false
    }
}
