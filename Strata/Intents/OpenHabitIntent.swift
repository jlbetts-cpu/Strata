import AppIntents

struct OpenHabitIntent: OpenIntent {
    static var title: LocalizedStringResource = "Open Win"

    @Parameter(title: "Win")
    var target: HabitEntity

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
