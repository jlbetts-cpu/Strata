import AppIntents

/// What Siri, Spotlight and the Shortcuts app offer. Said in the app's own
/// words: a win is logged, and the tower is today's.
struct StrataShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogWinIntent(),
            phrases: [
                "Log a win in \(.applicationName)",
                "Add a win to \(.applicationName)",
                "I did something in \(.applicationName)"
            ],
            shortTitle: "Log a Win",
            systemImageName: "plus.square.fill"
        )
        AppShortcut(
            intent: ShowTodaysWinsIntent(),
            phrases: [
                "Show my wins in \(.applicationName)",
                "How many wins today in \(.applicationName)"
            ],
            shortTitle: "Today's Wins",
            systemImageName: "square.stack.fill"
        )
    }
}
