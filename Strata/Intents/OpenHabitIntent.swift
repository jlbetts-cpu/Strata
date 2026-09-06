import AppIntents

struct OpenHabitIntent: OpenIntent {
    static var title: LocalizedStringResource = "Open Habit"

    @Parameter(title: "Habit")
    var target: HabitEntity

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
