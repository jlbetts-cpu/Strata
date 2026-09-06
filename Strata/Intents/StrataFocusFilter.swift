import AppIntents

struct StrataFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "Filter Habits"
    static var description = IntentDescription("Show only habits from a specific category during this Focus.")

    @Parameter(title: "Category")
    var category: CategoryAppEnum?

    var displayRepresentation: DisplayRepresentation {
        if let category {
            return .init(title: "Show \(category.localizedStringResource) habits",
                         image: .init(systemName: "line.3.horizontal.decrease.circle.fill"))
        }
        return .init(title: "Show all habits",
                     image: .init(systemName: "line.3.horizontal.decrease.circle"))
    }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults.standard
        if let category {
            defaults.set(category.rawValue, forKey: "focusFilterCategory")
        } else {
            defaults.removeObject(forKey: "focusFilterCategory")
        }
        return .result()
    }
}
