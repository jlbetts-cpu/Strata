import AppIntents

struct StrataShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CompleteHabitIntent(),
            phrases: [
                "Complete \(\.$habit) in \(.applicationName)",
                "Mark \(\.$habit) done in \(.applicationName)",
                "Finish \(\.$habit) in \(.applicationName)"
            ],
            shortTitle: "Complete Habit",
            systemImageName: "checkmark.circle.fill"
        )
        AppShortcut(
            intent: SkipHabitIntent(),
            phrases: [
                "Skip \(\.$habit) in \(.applicationName)"
            ],
            shortTitle: "Skip Habit",
            systemImageName: "forward.fill"
        )
        AppShortcut(
            intent: ShowTodaysHabitsIntent(),
            phrases: [
                "Show my habits in \(.applicationName)",
                "What's left in \(.applicationName)"
            ],
            shortTitle: "Today's Habits",
            systemImageName: "list.bullet"
        )
        AppShortcut(
            intent: LogMoodIntent(),
            phrases: [
                "Log my mood in \(.applicationName)"
            ],
            shortTitle: "Log Mood",
            systemImageName: "face.smiling"
        )
    }
}
