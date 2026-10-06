import Foundation
import SwiftData

/// **Onboarding ends on your first win, and it is a real one** (owner-
/// approved, 2026-10-05).
///
/// The last page of the walkthrough is the tower's own slot: one tap and your
/// first block lands, with five examples of what counts as a win, any of
/// which fills in the title. That win is queued here when the page finishes
/// and logged by `MainAppView` through `QuickWinService.logWin` against the
/// active tower, the same path every one-tap win takes, and the app opens on
/// Wins with it standing there.
///
/// **It replaces the "Welcome" block** and keeps that block's argument
/// (endowed progress: a tower with one block on it asks you to continue,
/// not to begin; `StrataApp.finishOnboarding`). It keeps it better: the
/// welcome block was true because sitting through the walkthrough is a thing
/// you did, and this one is a thing you did today, named by you.
nonisolated enum OnboardingFirstWin {
    /// What counts as a win, said by example rather than by a sentence.
    static let examples = [
        "Made the bed", "Drank water", "Replied to that email", "Went outside", "Called someone",
    ]

    private static let titleKey = "onboarding.firstWin.title"
    private static let sizeKey = "onboarding.firstWin.size"
    private static let colourKey = "onboarding.firstWin.colour"

    static func queue(title: String, size: BlockSize, colour: HabitCategory,
                      defaults: UserDefaults = .standard) {
        defaults.set(title, forKey: titleKey)
        defaults.set(size.rawValue, forKey: sizeKey)
        defaults.set(colour.rawValue, forKey: colourKey)
    }

    static func isPending(defaults: UserDefaults = .standard) -> Bool {
        defaults.string(forKey: sizeKey) != nil
    }

    /// Logs the queued win, once. The queue is cleared BEFORE the write, so a
    /// failure can lose the first win but can never log it twice: a doubled
    /// first act is the one thing this must not do.
    @MainActor
    @discardableResult
    static func land(context: ModelContext, tower: Tower?,
                     defaults: UserDefaults = .standard) -> Habit? {
        guard let sizeRaw = defaults.string(forKey: sizeKey) else { return nil }
        let title = defaults.string(forKey: titleKey) ?? ""
        let colour = HabitCategory(rawValue: defaults.string(forKey: colourKey) ?? "") ?? .health
        for key in [titleKey, sizeKey, colourKey] { defaults.removeObject(forKey: key) }
        do {
            return try QuickWinService.logWin(
                title: title,
                category: .unlabeled,
                size: BlockSize(rawValue: sizeRaw) ?? .small,
                spontaneous: colour,
                context: context,
                tower: tower
            ).habit
        } catch {
            NSLog("[strata-onboarding] the first win did not save: \(error)")
            return nil
        }
    }
}
