import Foundation
import SwiftData

/// Logging a win in one tap.
///
/// A win is something you already did. There is nothing to schedule and often
/// nothing worth naming in the moment, so the add sheet — which asks only
/// questions about the future — is the wrong instrument entirely.
///
/// The schema already has the right shape: a one-time task (`isTodo`) dated
/// today, completed on arrival. A win is that, entered from the other end.
///
/// It cannot be a log with no habit: `PlacedBlock` requires a non-optional
/// `Habit` and `TowerViewModel` skips any log without one, so such a win would
/// silently never appear as a block — the opposite of the point.
enum QuickWinService {

    /// Title a win carries until it is named.
    static let untitled = "Win"

    /// A win is identifiable after the fact by this signature: a one-time task
    /// belonging to no weekday. Used for counting today's wins without adding a
    /// field to the schema.
    static func isWin(_ habit: Habit) -> Bool {
        habit.isTodo && habit.frequencyRawValues.isEmpty
    }

    /// A colour for a win nobody has categorised yet.
    ///
    /// It used to be a neutral grey, on the principle that colour is for
    /// categories you chose. In practice that made the block that claims the
    /// least also the only one that did not belong to the page. A win now
    /// arrives wearing one of the six, and the block's card is where that guess
    /// gets corrected. Being wrong and fixable beats being colourless.
    ///
    /// **Least-used, not random.** True randomness clusters: six colours drawn
    /// independently will hand you the same one five times often enough to
    /// notice, and a tower that comes out mostly pink looks like a bug rather
    /// than like chance. Picking the colour the tower currently has least of
    /// spreads them without anyone having to think about it, and ties break
    /// randomly so it is not a predictable rotation either.
    static func spontaneousCategory(existing: [Habit]) -> HabitCategory {
        var counts: [HabitCategory: Int] = [:]
        for cat in HabitCategory.selectable { counts[cat] = 0 }
        for habit in existing {
            let shown = habit.displayCategory
            if counts[shown] != nil { counts[shown]! += 1 }
        }
        let fewest = counts.values.min() ?? 0
        let leastUsed = counts.filter { $0.value == fewest }.map(\.key)
        return leastUsed.randomElement() ?? .health
    }

    /// Creates a completed one-time habit for today and returns it, so the
    /// caller can hand it to the tower's drop cascade.
    @discardableResult
    static func logWin(
        title: String = untitled,
        category: HabitCategory = .unlabeled,
        size: BlockSize = .small,
        context: ModelContext,
        tower: Tower?
    ) throws -> Habit {
        let today = DateUtils.dateString(from: Date())
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)

        let habit = Habit(
            title: trimmed.isEmpty ? untitled : trimmed,
            category: category,
            blockSize: size,
            frequency: [],          // one-time: it belongs to no weekday
            isTodo: true,
            scheduledDate: today
        )
        habit.tower = tower
        // Unlabeled, so it draws no icon — but carrying a colour, so it still
        // looks like part of the tower. Two facts, stored separately.
        if category == .unlabeled {
            let siblings = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
            habit.spontaneousCategoryRaw = spontaneousCategory(existing: siblings).rawValue
        }
        context.insert(habit)

        let log = HabitLog(habit: habit, dateString: today, completed: true)
        log.markCompleted()
        context.insert(log)

        try context.save()
        return habit
    }
}
