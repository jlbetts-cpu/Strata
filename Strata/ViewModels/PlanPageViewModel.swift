import Foundation
import SwiftUI
import SwiftData

struct PlanItem: Identifiable {
    let id: UUID
    let habit: Habit
    let indentLevel: Int // 0 = top-level, 1 = sub-task
}

@Observable @MainActor
final class PlanPageViewModel {

    // MARK: - State

    var newItemText: String = ""
    var expandedItemID: UUID? = nil

    // MARK: - Smart Suggestion

    var suggestedCategory: HabitCategory? {
        CategorySuggestionEngine.suggest(for: newItemText)
    }

    var effectiveCategory: HabitCategory {
        suggestedCategory ?? .health
    }

    var suggestedColor: Color {
        effectiveCategory.style.baseColor
    }

    // MARK: - Ordered Items

    func orderedItems(from habits: [Habit]) -> [PlanItem] {
        let topLevel = habits
            .filter { $0.parentHabitID == nil }
            .sorted { $0.sortOrder < $1.sortOrder }

        var result: [PlanItem] = []
        for parent in topLevel {
            result.append(PlanItem(id: parent.id, habit: parent, indentLevel: 0))

            let children = habits
                .filter { $0.parentHabitID == parent.id }
                .sorted { $0.sortOrder < $1.sortOrder }
            for child in children {
                result.append(PlanItem(id: child.id, habit: child, indentLevel: 1))
            }
        }
        return result
    }

    // MARK: - Create

    func commitNewItem(context: ModelContext) {
        let trimmed = newItemText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let category = CategorySuggestionEngine.suggest(for: trimmed) ?? .health
        let size = CategorySuggestionEngine.suggestSize(for: trimmed) ?? .small

        // Calculate next sort order
        let descriptor = FetchDescriptor<Habit>(
            sortBy: [SortDescriptor(\.sortOrder, order: .reverse)]
        )
        let maxOrder = (try? context.fetch(descriptor).first?.sortOrder) ?? 0

        let habit = Habit(
            title: trimmed,
            category: category,
            blockSize: size,
            sortOrder: maxOrder + 1
        )
        context.insert(habit)
        try? context.save()

        HapticsEngine.snap()
        newItemText = ""
    }

    // MARK: - Indent / Outdent

    func indentItem(_ habit: Habit, allHabits: [Habit], context: ModelContext) {
        // Find the item directly above this one (at top level)
        let topLevel = allHabits
            .filter { $0.parentHabitID == nil && $0.id != habit.id }
            .sorted { $0.sortOrder < $1.sortOrder }

        guard let parentCandidate = topLevel.last(where: { $0.sortOrder < habit.sortOrder }) else { return }

        habit.parentHabitID = parentCandidate.id
        try? context.save()
    }

    func outdentItem(_ habit: Habit, context: ModelContext) {
        habit.parentHabitID = nil
        try? context.save()
    }

    // MARK: - Update

    func updateTitle(_ habit: Habit, to title: String, context: ModelContext) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        habit.title = trimmed
        try? context.save()
    }

    func updateCategory(_ habit: Habit, to category: HabitCategory, context: ModelContext) {
        habit.category = category
        try? context.save()
    }

    func updateSize(_ habit: Habit, to size: BlockSize, context: ModelContext) {
        habit.blockSize = size
        try? context.save()
    }

    func updateDays(_ habit: Habit, to days: Set<DayCode>, context: ModelContext) {
        habit.frequency = Array(days)
        try? context.save()
    }

    func toggleTodo(_ habit: Habit, context: ModelContext) {
        habit.isTodo.toggle()
        if habit.isTodo {
            habit.frequency = []
            habit.scheduledDate = TimelineViewModel.dateString(from: Date())
        } else {
            habit.frequency = DayCode.allCases
            habit.scheduledDate = nil
        }
        try? context.save()
    }

    // MARK: - Delete

    func deleteItem(_ habit: Habit, context: ModelContext) {
        for log in habit.logs {
            if let fileName = log.imageFileName {
                ImageManager.shared.deleteImage(fileName: fileName)
            }
        }
        context.delete(habit)
        try? context.save()
    }

    // MARK: - Schedule Description

    func scheduleDescription(for habit: Habit) -> String {
        if habit.isTodo {
            guard let dateStr = habit.scheduledDate else { return "One-time" }
            let today = TimelineViewModel.dateString(from: Date())
            if dateStr == today { return "Today" }
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            if TimelineViewModel.dateString(from: tomorrow) == dateStr { return "Tomorrow" }
            let parts = dateStr.split(separator: "-")
            guard parts.count == 3, let m = Int(parts[1]), let d = Int(parts[2]) else { return dateStr }
            let months = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
            return m >= 1 && m <= 12 ? "\(months[m]) \(d)" : dateStr
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
}
