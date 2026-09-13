import AppIntents
import SwiftUI
import SwiftData

/// **Log a win, by voice.** The app's one tap, from Siri or a Shortcut.
///
/// This replaces "Complete Habit" and "Skip Habit". Both acted on recurring,
/// scheduled habits, and nothing in the app has been able to create one since
/// the tower became the record of the day: `createHabit` has no callers. So
/// they offered nothing to complete and nothing to skip, to everybody. A win
/// is logged, not completed, and there is no such thing as skipping one.
///
/// It goes through `QuickWinService.logWin`, the same path as the tap, so a
/// win from Siri is the same object as a win from the app: one-time, wearing
/// the colour the tower has least of, and with no category nobody chose.
struct LogWinIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a Win"
    static var description = IntentDescription("Add a win to today's tower.")
    static var openAppWhenRun = false

    /// Optional, because a win does not need a name. A nameless block shows no
    /// text at all.
    @Parameter(title: "Name", requestValueDialog: "What did you do?")
    var name: String?

    @Dependency private var modelContainer: ModelContainer

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView & ProvidesDialog {
        let context = ModelContext(modelContainer)
        let tower = Self.activeTower(in: context)
        let win = try QuickWinService.logWin(title: name ?? QuickWinService.untitled,
                                             context: context, tower: tower)
        WidgetReloader.reload()

        let today = TodaysWins.count(in: context)
        let named = win.habit.title == QuickWinService.untitled ? nil : win.habit.title
        let dialog: IntentDialog = named.map { "Logged \($0). That's \(today) today." }
            ?? "Logged. That's \(today) today."
        return .result(dialog: dialog) {
            WinLoggedSnippet(title: named, colour: win.habit.displayCategory, today: today)
        }
    }

    /// The tower the app has open, by the same stored id `TowerManager` uses.
    private static func activeTower(in context: ModelContext) -> Tower? {
        let towers = (try? context.fetch(FetchDescriptor<Tower>(sortBy: [SortDescriptor(\.order)]))) ?? []
        if let stored = UserDefaults.standard.string(forKey: "activeTowerID").flatMap(UUID.init(uuidString:)),
           let match = towers.first(where: { $0.id == stored }) {
            return match
        }
        return towers.first
    }
}

/// **How many wins today, and what they were.**
///
/// Replaces "Show Today's Habits", which listed habits scheduled for today and
/// so answered "No habits scheduled for today" to everyone.
struct ShowTodaysWinsIntent: AppIntent {
    static var title: LocalizedStringResource = "Today's Wins"
    static var description = IntentDescription("See what's on today's tower.")
    static var openAppWhenRun = false

    @Dependency private var modelContainer: ModelContainer

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView & ProvidesDialog {
        let context = ModelContext(modelContainer)
        let wins = TodaysWins.list(in: context)
        guard !wins.isEmpty else {
            return .result(dialog: "No wins yet today.") {
                IntentMessageSnippet(message: "Nothing on today's tower yet")
            }
        }
        let dialog: IntentDialog = wins.count == 1 ? "One win today." : "\(wins.count) wins today."
        return .result(dialog: dialog) {
            TodaysWinsSnippet(wins: wins)
        }
    }
}

/// Today's wins as Siri reads them: completed logs dated today, newest first.
enum TodaysWins {
    struct Win: Identifiable {
        let id: UUID
        let title: String?
        let colour: HabitCategory
    }

    @MainActor
    static func list(in context: ModelContext) -> [Win] {
        let today = DateUtils.dateString(from: Date())
        let logs = (try? context.fetch(FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.dateString == today && $0.completed }))) ?? []
        return logs
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            .compactMap { log in
                guard let habit = log.habit else { return nil }
                return Win(id: log.id,
                           title: habit.title == QuickWinService.untitled ? nil : habit.title,
                           colour: habit.displayCategory)
            }
    }

    @MainActor
    static func count(in context: ModelContext) -> Int { list(in: context).count }
}
