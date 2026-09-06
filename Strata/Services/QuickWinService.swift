import Foundation
import SwiftData

/// Logging a win in one tap.
///
/// A win is a thing you already did — there is nothing to schedule and often
/// nothing worth naming in the moment. The schema already has the right shape
/// for that: a one-time task (`isTodo`) dated today, completed on arrival. So a
/// win is not a new concept, it is the existing one entered from the other end —
/// completed first, described later or never.
///
/// The title is deliberately allowed to stay generic. `PlacedBlock` requires a
/// non-optional `Habit` and `TowerViewModel` skips any log without one, so a
/// truly habit-less log would never appear as a block — it would silently
/// vanish, which is the opposite of the point.
enum QuickWinService {

    /// Default title for an unnamed win. Kept short so it reads on a 1x1 block.
    static let untitled = "Win"

    /// Creates a completed one-time habit for today and returns it, so the
    /// caller can hand it to the tower's drop cascade.
    ///
    /// Does NOT save if the context write fails — the caller sees the throw and
    /// can leave the UI unchanged rather than showing a block that is not there.
    @discardableResult
    static func logWin(
        title: String = untitled,
        category: HabitCategory,
        size: BlockSize = .small,
        context: ModelContext,
        tower: Tower?
    ) throws -> Habit {
        let today = TimelineViewModel.dateString(from: Date())
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
        context.insert(habit)

        let log = HabitLog(habit: habit, dateString: today, completed: true)
        log.markCompleted()
        context.insert(log)

        try context.save()
        return habit
    }
}
