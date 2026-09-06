import Foundation

@Observable
final class FocusFilterService {
    private let defaults = UserDefaults.standard

    var activeCategory: HabitCategory? {
        guard let raw = defaults.string(forKey: "focusFilterCategory") else { return nil }
        return HabitCategory(rawValue: raw)
    }

    /// Force re-read (call on scenePhase == .active)
    func refresh() {
        // Reading defaults triggers @Observable notification
        _ = activeCategory
    }
}
