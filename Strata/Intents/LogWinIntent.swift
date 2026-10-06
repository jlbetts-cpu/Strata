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
        // Before the dependency: a store that did not open is never
        // registered, and a win logged into nothing must not be reported as
        // logged.
        try StoreUnavailableIntentError.check()
        let logged = try Self.log(name: name, size: .small, in: modelContainer)
        let dialog: IntentDialog = logged.title.map { "Logged \($0). That's \(logged.today) today." }
            ?? "Logged. That's \(logged.today) today."
        return .result(dialog: dialog) {
            WinLoggedSnippet(title: logged.title, colour: logged.colour, today: logged.today)
        }
    }

    /// One win onto today's tower, as the tap makes it: Siri's path, and the
    /// controls' and the Log widget's (`QuickLogIntent`).
    ///
    /// `afterWin` is the reminders' half of what the app does after a win
    /// (`keepRemindersRight`), a parameter only so a test can see it run.
    @MainActor
    static func log(name: String?, size: BlockSize, in container: ModelContainer,
                    afterWin: @MainActor (ModelContext) -> Void = LogWinIntent.keepRemindersRight)
        throws -> (title: String?, colour: HabitCategory, today: Int) {
        let context = ModelContext(container)
        let tower = activeTower(in: context)
        let win = try QuickWinService.logWin(title: name ?? QuickWinService.untitled, size: size,
                                             context: context, tower: tower)
        WidgetReloader.reload()
        afterWin(context)
        // A win said to Siri goes where the last one went, as a one-tap win
        // does (crews, spec 2.6).
        if let log = (win.habit.logs ?? []).first(where: { $0.id == win.logID }) {
            CrewSync.post(log)
        }
        let named = win.habit.title == QuickWinService.untitled ? nil : win.habit.title
        return (named, win.habit.displayCategory, TodaysWins.count(in: context))
    }

    /// **A win logged outside the app keeps the reminders right** (the
    /// cohesion pass, 2026-10-05). The app does this after every win
    /// (`MainAppView.refreshData`): today's reminder is taken back, because
    /// it has nothing left to say, and the evening's past win is decided
    /// again, because it only ever comes on a day with a win of its own. A
    /// win from the Lock Screen, Control Center, the widget or Siri did
    /// neither, so the reminder still came at 7pm to a day that had a win,
    /// and the past win never came at all unless the app was opened later.
    @MainActor
    static func keepRemindersRight(_ context: ModelContext) {
        DailyReminder.skipToday()
        Task { @MainActor in await PastWinReminder.schedule(context: context) }
    }

    /// The controls' and the Log widget's sizes, as the tower's.
    static func blockSize(_ size: QuickLogSize) -> BlockSize {
        switch size {
        case .quick: .small
        case .regular: .medium
        case .deep: .hard
        }
    }

    /// The tower the app has open, by the same stored id `TowerManager` uses.
    static func activeTower(in context: ModelContext) -> Tower? {
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
        // "No wins yet today" over a store that could not be read would be a
        // lie about somebody's day.
        try StoreUnavailableIntentError.check()
        let context = ModelContext(modelContainer)
        let wins = TodaysWins.list(in: context)
        guard !wins.isEmpty else {
            // The owner's empty-state voice (2026-10-05), in place of "No
            // wins yet today." over "Nothing on today's tower yet": the
            // same absence said twice, as a count.
            return .result(dialog: "Quiet here. Yet.") {
                IntentMessageSnippet(message: "Quiet here. Yet.")
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
