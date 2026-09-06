import Foundation
import SwiftUI
import SwiftData

struct PlanItem: Identifiable, Equatable {
    let id: UUID
    let habit: Habit
    let schedule: String // Pre-computed (avoids per-render date parsing)

    static func == (lhs: PlanItem, rhs: PlanItem) -> Bool {
        lhs.id == rhs.id
    }
}

enum SortMode: String, CaseIterable {
    case recent   // createdAt descending
    case category // grouped by category, then recency
    case oldest   // createdAt ascending
}

enum PlanViewMode: String, CaseIterable {
    case routines = "Routines"
    case todos = "To-Dos"
}

struct SmartViewOverride: Codable {
    var icon: String
    var colorHex: String
}

struct PlanSection: Identifiable {
    let id: String
    let title: String
    let icon: String
    let colorHex: String?
    let items: [PlanItem]
    let folderID: UUID?
    let isUserCreated: Bool
    let isPermanent: Bool

    /// System section (auto-grouped)
    init(id: String, title: String, icon: String, items: [PlanItem], isPermanent: Bool = false, colorHex: String? = nil) {
        self.id = id
        self.title = title
        self.icon = icon
        self.colorHex = colorHex
        self.items = items
        self.folderID = nil
        self.isUserCreated = false
        self.isPermanent = isPermanent
    }

    /// User-created folder section
    init(folder: PlanFolder, items: [PlanItem]) {
        self.id = "folder-\(folder.id.uuidString)"
        self.title = folder.name
        self.icon = folder.icon
        self.colorHex = folder.colorHex
        self.items = items
        self.folderID = folder.id
        self.isUserCreated = true
        self.isPermanent = false
    }
}

@Observable @MainActor
final class PlanPageViewModel {

    // MARK: - State

    var newItemText: String = ""
    var expandedItemID: UUID? = nil
    var sortMode: SortMode = .recent
    var nextIsTask: Bool = false
    private var _cachedMaxSortOrder: Int?

    // MARK: - Smart Suggestion (cached — debounced from view)

    var cachedCategory: HabitCategory = .health

    var effectiveCategory: HabitCategory { cachedCategory }

    var suggestedColor: Color {
        cachedCategory.style.baseColor
    }

    // MARK: - Grouped Sections (temporal + type)

    func groupedSections(
        from habits: [Habit],
        folders: [PlanFolder] = [],
        viewMode: PlanViewMode = .routines,
        overrides: [String: SmartViewOverride] = [:],
        completedIDs: Set<UUID> = []
    ) -> [PlanSection] {
        var sections: [PlanSection] = []

        func toItems(_ list: [Habit]) -> [PlanItem] {
            let sorted: [Habit]
            switch sortMode {
            case .recent:
                sorted = list.sorted { $0.createdAt > $1.createdAt }
            case .oldest:
                sorted = list.sorted { $0.createdAt < $1.createdAt }
            case .category:
                sorted = list.sorted { a, b in
                    if a.category.rawValue != b.category.rawValue {
                        return a.category.rawValue < b.category.rawValue
                    }
                    return a.createdAt > b.createdAt
                }
            }
            return sorted.map { PlanItem(id: $0.id, habit: $0, schedule: scheduleDescription(for: $0)) }
        }

        // Smart View defaults with user overrides applied
        let todayIcon = overrides["today"]?.icon ?? "star.fill"
        let todayColor = overrides["today"]?.colorHex
        let tomorrowIcon = overrides["tomorrow"]?.icon ?? "sunrise.fill"
        let tomorrowColor = overrides["tomorrow"]?.colorHex
        let inboxIcon = overrides["inbox"]?.icon ?? "tray.and.arrow.down.fill"
        let inboxColor = overrides["inbox"]?.colorHex

        let todayStr = TimelineViewModel.dateString(from: Date.now)
        let tomorrowDate = Calendar.current.date(byAdding: .day, value: 1, to: Date.now)!
        let tomorrowStr = TimelineViewModel.dateString(from: tomorrowDate)
        let todayDayCode = DayCode.from(weekday: Calendar.current.component(.weekday, from: Date.now))
        let tomorrowDayCode = DayCode.from(weekday: Calendar.current.component(.weekday, from: tomorrowDate))

        // Override icons for Next 7 Days
        let next7Icon = overrides["next7"]?.icon ?? "calendar"
        let next7Color = overrides["next7"]?.colorHex

        switch viewMode {
        case .routines:
            let routines = habits.filter { !$0.isTodo && $0.parentHabitID == nil }

            // Today (permanent — all habits active today)
            let todayRoutines = routines.filter { $0.frequency.contains(todayDayCode) }
            sections.append(PlanSection(id: "today", title: "Today", icon: todayIcon, items: toItems(todayRoutines), isPermanent: true, colorHex: todayColor))

            // Tomorrow (permanent)
            let tomorrowRoutines = routines.filter { $0.frequency.contains(tomorrowDayCode) }
            sections.append(PlanSection(id: "tomorrow", title: "Tomorrow", icon: tomorrowIcon, items: toItems(tomorrowRoutines), isPermanent: true, colorHex: tomorrowColor))

            // Next 7 Days (permanent — habits active in days 2-7, NOT already in Today/Tomorrow)
            let next7DayCodes: Set<DayCode> = Set((2...7).compactMap { offset in
                guard let date = Calendar.current.date(byAdding: .day, value: offset, to: Date.now) else { return nil }
                return DayCode.from(weekday: Calendar.current.component(.weekday, from: date))
            })
            let next7Routines = routines.filter { habit in
                !habit.frequency.isEmpty &&
                habit.frequency.contains(where: { next7DayCodes.contains($0) }) &&
                !habit.frequency.contains(todayDayCode) &&
                !habit.frequency.contains(tomorrowDayCode)
            }
            sections.append(PlanSection(id: "next7", title: "Next 7 Days", icon: next7Icon, items: toItems(next7Routines), isPermanent: true, colorHex: next7Color))

            // Inbox (permanent — TIGHTENED: timeless + unfoldered only. GTD Allen 2001)
            let inbox = routines.filter { $0.planFolder == nil && $0.scheduledTime == nil }
            sections.append(PlanSection(id: "inbox", title: "Inbox", icon: inboxIcon, items: toItems(inbox), isPermanent: true, colorHex: inboxColor))

            // Custom Folders
            let sortedFolders = folders.sorted { $0.sortOrder < $1.sortOrder }
            for folder in sortedFolders {
                let folderHabits = routines.filter { $0.planFolder?.id == folder.id }
                sections.append(PlanSection(folder: folder, items: toItems(folderHabits)))
            }

        case .todos:
            let tasks = habits.filter { $0.isTodo && $0.parentHabitID == nil && !$0.isSaved }

            // Today (permanent — due today OR dateless, NOT in progress)
            // Completed to-dos stay visible with strikethrough (like routines)
            let todayTasks = tasks.filter {
                ($0.scheduledDate == todayStr || $0.scheduledDate == nil) &&
                !$0.isInProgress
            }
            sections.append(PlanSection(id: "today", title: "Today", icon: todayIcon, items: toItems(todayTasks), isPermanent: true, colorHex: todayColor))

            // In Progress (permanent — Kanban "Doing" column. Barkley: externalized commitment)
            let inProgress = tasks.filter { $0.isInProgress && !completedIDs.contains($0.id) }
            sections.append(PlanSection(id: "inprogress", title: "In Progress", icon: "arrow.triangle.2.circlepath", items: toItems(inProgress), isPermanent: true))

            // "Done" section removed — completed to-dos stay in their original sections with strikethrough

            // Tomorrow (permanent)
            let tomorrowTasks = tasks.filter {
                $0.scheduledDate == tomorrowStr && !$0.isInProgress
            }
            sections.append(PlanSection(id: "tomorrow", title: "Tomorrow", icon: tomorrowIcon, items: toItems(tomorrowTasks), isPermanent: true, colorHex: tomorrowColor))

            // Next 7 Days (permanent — days 2-7)
            let day2 = Calendar.current.date(byAdding: .day, value: 2, to: Date.now)!
            let day7 = Calendar.current.date(byAdding: .day, value: 7, to: Date.now)!
            let day2Str = TimelineViewModel.dateString(from: day2)
            let day7Str = TimelineViewModel.dateString(from: day7)
            let next7Tasks = tasks.filter {
                guard let d = $0.scheduledDate else { return false }
                return d >= day2Str && d <= day7Str && !$0.isInProgress
            }
            sections.append(PlanSection(id: "next7", title: "Next 7 Days", icon: next7Icon, items: toItems(next7Tasks), isPermanent: true, colorHex: next7Color))

            // Overdue (past-due, not completed)
            let overdue = tasks.filter {
                guard let d = $0.scheduledDate else { return false }
                return d < todayStr && !$0.isInProgress && !completedIDs.contains($0.id)
            }
            if !overdue.isEmpty {
                sections.append(PlanSection(id: "overdue", title: "Waiting for You", icon: "clock.badge", items: toItems(overdue)))
            }

            // Upcoming (> 7 days)
            let upcoming = tasks.filter {
                guard let d = $0.scheduledDate else { return false }
                return d > day7Str && !$0.isInProgress
            }
            if !upcoming.isEmpty {
                sections.append(PlanSection(id: "upcoming", title: "Upcoming", icon: "calendar.badge.clock", items: toItems(upcoming)))
            }

            // Saved — dormant to-dos for reuse (GTD Someday/Maybe)
            let allTodos = habits.filter { $0.isTodo && $0.parentHabitID == nil }
            let saved = allTodos.filter { $0.isSaved }
            sections.append(PlanSection(id: "saved", title: "Saved", icon: "bookmark.fill", items: toItems(saved), isPermanent: true))
        }

        return sections
    }

    func toggleInProgress(_ habit: Habit, context: ModelContext) {
        habit.isInProgress.toggle()
        try? context.save()
    }

    func completeForToday(_ habit: Habit, context: ModelContext) {
        let dateStr = TimelineViewModel.dateString(from: Date())
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

    func toggleSubTaskCompletion(_ habit: Habit, context: ModelContext) {
        habit.isStepCompleted.toggle()
        try? context.save()
    }

    func updateSuggestion(for text: String) {
        cachedCategory = CategorySuggestionEngine.suggest(for: text) ?? .health
    }

    // MARK: - Sort Order Cache

    private func nextSortOrder(context: ModelContext) -> Int {
        if let cached = _cachedMaxSortOrder {
            _cachedMaxSortOrder = cached + 1
            return cached + 1
        }
        var descriptor = FetchDescriptor<Habit>(
            sortBy: [SortDescriptor(\.sortOrder, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        let maxOrder = (try? context.fetch(descriptor).first?.sortOrder) ?? 0
        _cachedMaxSortOrder = maxOrder + 1
        return maxOrder + 1
    }

    // MARK: - Create

    @discardableResult
    func commitNewItem(context: ModelContext) -> UUID? {
        let trimmed = newItemText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Natural Language Parsing — detect time, frequency, dates, category
        let parsed = InputParser.parse(trimmed)
        let category = parsed.suggestedCategory ?? cachedCategory
        let size = CategorySuggestionEngine.suggestSize(for: parsed.title) ?? .small

        let maxOrder = nextSortOrder(context: context)

        let habit = Habit(
            title: parsed.title.isEmpty ? trimmed : parsed.title,
            category: category,
            blockSize: size,
            frequency: parsed.frequency ?? (parsed.isTask ? [] : DayCode.allCases),
            scheduledTime: parsed.scheduledTime,
            isTodo: parsed.isTask,
            scheduledDate: parsed.scheduledDate,
            sortOrder: maxOrder + 1
        )
        context.insert(habit)
        try? context.save()

        HapticsEngine.snap()
        newItemText = ""
        nextIsTask = false
        return habit.id
    }

    // MARK: - Contextual Create (Apple Reminders pattern)

    @discardableResult
    func commitInContext(title: String, sectionID: String, folderID: UUID? = nil, viewMode: PlanViewMode = .routines, context: ModelContext) -> UUID? {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // NLP parsing
        let parsed = InputParser.parse(trimmed)

        // Section-aware defaults (respects tab context — Norman 2013)
        let sectionDefaults = defaultsForSection(sectionID, viewMode: viewMode)
        let category = parsed.suggestedCategory ?? (CategorySuggestionEngine.suggest(for: parsed.title) ?? .health)
        let size = CategorySuggestionEngine.suggestSize(for: parsed.title) ?? .small

        let maxOrder = nextSortOrder(context: context)

        let habit = Habit(
            title: parsed.title.isEmpty ? trimmed : parsed.title,
            category: category,
            blockSize: size,
            frequency: parsed.frequency ?? sectionDefaults.frequency,
            scheduledTime: parsed.scheduledTime,
            isTodo: sectionDefaults.isTodo, // Tab determines type (Norman 2013: respect user's context)
            scheduledDate: parsed.scheduledDate ?? sectionDefaults.scheduledDate,
            sortOrder: maxOrder + 1
        )

        // Assign to folder if creating inside a user section
        if let folderID {
            let descriptor = FetchDescriptor<PlanFolder>(predicate: #Predicate { $0.id == folderID })
            if let folder = try? context.fetch(descriptor).first {
                habit.planFolder = folder
            }
        }

        context.insert(habit)
        try? context.save()

        HapticsEngine.snap()
        return habit.id
    }

    func defaultsForSection(_ sectionID: String, viewMode: PlanViewMode = .routines) -> (frequency: [DayCode], isTodo: Bool, scheduledDate: String?) {
        switch sectionID {
        case "today":
            if viewMode == .todos {
                return ([], true, TimelineViewModel.dateString(from: Date.now))
            } else {
                return ([DayCode.today()], false, nil) // Routine for today's day of week
            }
        case "tomorrow":
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date.now)!
            if viewMode == .todos {
                return ([], true, TimelineViewModel.dateString(from: tomorrow))
            } else {
                let weekday = Calendar.current.component(.weekday, from: tomorrow)
                return ([DayCode.from(weekday: weekday)], false, nil)
            }
        case "next7":
            // In routines mode: daily habit. In todos mode: task 3 days out.
            let day3 = Calendar.current.date(byAdding: .day, value: 3, to: Date.now)!
            return (DayCode.allCases, false, TimelineViewModel.dateString(from: day3))
        case "inbox":
            return (DayCode.allCases, false, nil)
        case "overdue":
            // Reschedule overdue to today
            return ([], true, TimelineViewModel.dateString(from: Date.now))
        case "daily":
            return (DayCode.allCases, false, nil)
        case "weekdays":
            return ([.mo, .tu, .we, .th, .fr], false, nil)
        case "weekends":
            return ([.sa, .su], false, nil)
        case "upcoming":
            let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date.now)!
            return ([], true, TimelineViewModel.dateString(from: nextWeek))
        default:
            return (DayCode.allCases, false, nil)
        }
    }

    // MARK: - Frequency Preset

    func applyFrequencyPreset(_ habit: Habit, preset: String, context: ModelContext) {
        switch preset {
        case "daily":
            habit.isTodo = false
            habit.frequency = DayCode.allCases
            habit.scheduledDate = nil
        case "weekdays":
            habit.isTodo = false
            habit.frequency = [.mo, .tu, .we, .th, .fr]
            habit.scheduledDate = nil
        case "weekends":
            habit.isTodo = false
            habit.frequency = [.sa, .su]
            habit.scheduledDate = nil
        case "today":
            habit.isTodo = true
            habit.frequency = []
            habit.scheduledDate = TimelineViewModel.dateString(from: Date.now)
        case "tomorrow":
            habit.isTodo = true
            habit.frequency = []
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date.now)!
            habit.scheduledDate = TimelineViewModel.dateString(from: tomorrow)
        default:
            break
        }
        try? context.save()
    }

    // MARK: - Schedule Context (Timeline Glimpse)

    /// Returns habits with a scheduledTime that are active on the given date.
    func scheduledHabitsForDate(_ date: Date, from allHabits: [Habit]) -> [Habit] {
        let dateStr = TimelineViewModel.dateString(from: date)
        let dayCode = DayCode.from(weekday: Calendar.current.component(.weekday, from: date))
        return allHabits.filter { habit in
            guard habit.scheduledTime != nil, habit.parentHabitID == nil else { return false }
            if habit.isTodo {
                return habit.scheduledDate == dateStr
            } else {
                return habit.frequency.contains(dayCode)
            }
        }.sorted { a, b in
            guard let aHour = TimelineViewModel.effectiveHour(for: a),
                  let bHour = TimelineViewModel.effectiveHour(for: b) else { return false }
            return aHour < bHour
        }
    }

    /// Finds the next open time slot that fits the given duration.
    /// Replicates gap-finding from ScheduleTimelineView:479-514.
    func findNextOpenSlot(excluding habitID: UUID, siblings: [Habit], duration: CGFloat) -> String? {
        let dayStart = 6 * 60
        let dayEnd = 23 * 60

        var busyRanges: [(start: Int, end: Int)] = []
        for h in siblings where h.id != habitID {
            if let hour = TimelineViewModel.effectiveHour(for: h) {
                let start = Int(hour * 60)
                let end = start + Int(h.blockSize.durationMinutes)
                busyRanges.append((start, end))
            }
        }
        busyRanges.sort { $0.start < $1.start }

        let nowMinutes = Calendar.current.component(.hour, from: Date()) * 60 +
                         Calendar.current.component(.minute, from: Date())
        var searchStart = dayStart

        for busy in busyRanges {
            if busy.start - searchStart >= Int(duration) && searchStart >= nowMinutes - 30 {
                let snapped = ((searchStart + 14) / 15) * 15
                return String(format: "%02d:%02d", snapped / 60, snapped % 60)
            }
            searchStart = max(searchStart, busy.end)
        }

        if dayEnd - searchStart >= Int(duration) {
            let snapped = ((searchStart + 14) / 15) * 15
            return String(format: "%02d:%02d", snapped / 60, snapped % 60)
        }

        return nil
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

    func updateTime(_ habit: Habit, to time: String?, context: ModelContext) {
        habit.scheduledTime = time
        try? context.save()
    }

    func toggleTodo(_ habit: Habit, context: ModelContext) {
        habit.isTodo.toggle()
        if habit.isTodo {
            habit.frequency = []
            habit.scheduledDate = TimelineViewModel.dateString(from: Date.now)
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
        _cachedMaxSortOrder = nil // Invalidate cache after deletion
    }

    // MARK: - Schedule Description

    func scheduleDescription(for habit: Habit) -> String {
        var base: String

        if habit.isTodo {
            guard let dateStr = habit.scheduledDate else { base = "One-time"; return appendTime(base, habit) }
            let today = TimelineViewModel.dateString(from: Date.now)
            if dateStr == today { base = "Today" }
            else {
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date.now)!
                if TimelineViewModel.dateString(from: tomorrow) == dateStr { base = "Tomorrow" }
                else {
                    let parts = dateStr.split(separator: "-")
                    if parts.count == 3, let m = Int(parts[1]), let d = Int(parts[2]) {
                        let months = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
                        base = m >= 1 && m <= 12 ? "\(months[m]) \(d)" : dateStr
                    } else {
                        base = dateStr
                    }
                }
            }
        } else {
            let freq = habit.frequency
            if freq.count == DayCode.allCases.count { base = "Daily" }
            else if freq.isEmpty { base = "No days" }
            else {
                let weekdays: Set<DayCode> = [.mo, .tu, .we, .th, .fr]
                if Set(freq) == weekdays { base = "Weekdays" }
                else {
                    let weekends: Set<DayCode> = [.sa, .su]
                    if Set(freq) == weekends { base = "Weekends" }
                    else { base = freq.map(\.rawValue).joined(separator: " ") }
                }
            }
        }

        return appendTime(base, habit)
    }

    private func appendTime(_ base: String, _ habit: Habit) -> String {
        guard let time = habit.scheduledTime else { return base }
        let formatted = BlockTimeFormatter.format12Hour(time)
        return "\(base) · \(formatted)"
    }
}
