import Foundation
import SwiftData

/// One line of a plan: something you mean to do.
///
/// The app records what you already did, and that is deliberate — a win is
/// past tense and the tower is a record, not a to-do list. This is the one
/// concession to planning in advance, kept to the smallest thing that helps:
/// a line of text, the days it comes back on, and whether it is done yet.
///
/// It is **not** a `Habit`. A habit with `isTodo` goes through
/// `QuickWinService`'s signature, appears in the tower's queries and gets
/// counted — which would put things you have NOT done on a tower whose whole
/// claim is that everything on it happened. A plan item has no `HabitLog`, so
/// nothing can place it.
///
/// Checking one off does not complete it here. It opens the add sheet with
/// the title already written, because the win still needs a size and a
/// colour — and because a block gets dropped, not ticked.
@Model
final class PlanItem {
    var id: UUID = UUID()
    var text: String = ""
    /// Position in the list. Rewritten in full on reorder, never partially: a
    /// half-written order sorts the untouched rows against the moved ones.
    var order: Int = 0
    var createdAt: Date = Date()
    /// When it was checked off, or nil. A completed line **stays on the list
    /// for the rest of the day** — the plan is also the record of what you got
    /// through, and clearing it the instant you finish something throws that
    /// away.
    var completedAt: Date?
    /// The colour its block wears once checked, and the colour the win takes.
    /// Decided when the line is written rather than when it is completed, so
    /// the plan looks like the tower it is going to be.
    var categoryRaw: String = HabitCategory.health.rawValue
    /// Weekdays it comes back on, 1 = Sunday through 7 = Saturday, as
    /// `Calendar.component(.weekday:)` numbers them. Empty means a one-off.
    ///
    /// Stored as a sorted comma-joined string rather than `[Int]`: SwiftData
    /// can hold an array of `Int`, but it cannot be used inside a
    /// `#Predicate`, and this is a field the sweep has to filter on.
    var repeatDaysRaw: String = ""

    var category: HabitCategory {
        HabitCategory(rawValue: categoryRaw) ?? .unlabeled
    }

    var isDone: Bool { completedAt != nil }
    var repeats: Bool { !repeatDaysRaw.isEmpty }

    var repeatDays: Set<Int> {
        get { Set(repeatDaysRaw.split(separator: ",").compactMap { Int($0) }) }
        set { repeatDaysRaw = newValue.sorted().map(String.init).joined(separator: ",") }
    }

    init(text: String = "", order: Int = 0, category: HabitCategory = .health) {
        self.id = UUID()
        self.text = text
        self.order = order
        self.createdAt = Date()
        self.categoryRaw = category.rawValue
    }

    /// Whether this line belongs on today's list.
    ///
    /// A one-off always does, until the day it was completed is over. A
    /// repeating line belongs on the days it repeats on — and on any day it
    /// was completed, so that ticking something off on a day it was not due
    /// does not make it vanish under your finger.
    func belongs(on date: Date, calendar: Calendar) -> Bool {
        guard repeats else { return true }
        if let done = completedAt, calendar.isDate(done, inSameDayAs: date) { return true }
        return repeatDays.contains(calendar.component(.weekday, from: date))
    }

    /// A human reading of the repeat, for the row's subtitle.
    func repeatSummary(calendar: Calendar) -> String? {
        guard repeats else { return nil }
        let days = repeatDays.sorted()
        if days.count == 7 { return "Every day" }
        if days == [2, 3, 4, 5, 6] { return "Weekdays" }
        if days == [1, 7] { return "Weekends" }
        let symbols = calendar.shortWeekdaySymbols
        return days.compactMap { symbols.indices.contains($0 - 1) ? symbols[$0 - 1] : nil }
            .joined(separator: " ")
    }

    // MARK: - The day turning

    /// Clears yesterday off the plan.
    ///
    /// Run once at launch. A completed **one-off** is finished, so it goes. A
    /// completed **repeating** line comes back unchecked, because that is what
    /// repeating means. Anything still unfinished is left exactly where it is:
    /// deciding for somebody that an unfinished plan expires overnight is the
    /// kind of tidying that loses work.
    static func sweep(context: ModelContext, now: Date = Date(),
                      calendar: Calendar = .current) {
        guard let items = try? context.fetch(FetchDescriptor<PlanItem>()) else { return }
        var changed = false
        for item in items {
            guard let done = item.completedAt else { continue }
            guard !calendar.isDate(done, inSameDayAs: now) else { continue }
            if item.repeats {
                item.completedAt = nil
            } else {
                context.delete(item)
            }
            changed = true
        }
        if changed { try? context.save() }
    }
}
