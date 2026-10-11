import Foundation
import SwiftData

/// One line of a plan: something you mean to do.
///
/// The app records what you already did, and that is deliberate — a win is
/// past tense and the tower is a record, not a to-do list. This is the one
/// concession to planning in advance, kept to the smallest thing that helps:
/// a line of text, the days it comes back on, and whether it is done yet.
///
/// **Since 2026-10-10 a line has a day and today's open lines stand on the
/// tower**, as clear outlines behind the slot (`PlannedSlots`,
/// `docs/planning.md`). The paragraph above still holds where it matters:
/// an outline is not a block, takes no colour and is never counted.
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
    /// **When it is for.** Weekdays it comes back on, 1 = Sunday through
    /// 7 = Saturday, as `Calendar.component(.weekday:)` numbers them; or,
    /// for a one-off, the one day it is planned for, written `d:2026-10-12`
    /// (`day`). Empty is a one-off from before lines had a day, which is
    /// today's until the sweep gives it one.
    ///
    /// Stored as a sorted comma-joined string rather than `[Int]`: SwiftData
    /// can hold an array of `Int`, but it cannot be used inside a
    /// `#Predicate`, and this is a field the sweep has to filter on.
    ///
    /// **The day rides in this field, and that is on purpose** (2026-10-10,
    /// planning ahead). A new stored field needs the iCloud schema deployed
    /// from the console before any phone on a TestFlight or App Store build
    /// can save one, and until it is, the whole store's sync stalls on the
    /// first line that carries it. This field is already in the schema. A
    /// build from before reads `d:...` as no weekdays at all, which is a
    /// plain one-off: the line still shows and still ticks.
    var repeatDaysRaw: String = ""
    /// The size its block opens at once checked. Small unless a suggestion
    /// sized it (`PlanSuggestions`); the add sheet can still change it.
    var sizeRaw: String = BlockSize.small.rawValue

    var category: HabitCategory {
        HabitCategory(rawValue: categoryRaw) ?? .unlabeled
    }

    var size: BlockSize {
        get { BlockSize(rawValue: sizeRaw) ?? .small }
        set { sizeRaw = newValue.rawValue }
    }

    var isDone: Bool { completedAt != nil }
    var repeats: Bool { !repeatDays.isEmpty }

    static let dayPrefix = "d:"

    var repeatDays: Set<Int> {
        get {
            guard !repeatDaysRaw.hasPrefix(Self.dayPrefix) else { return [] }
            return Set(repeatDaysRaw.split(separator: ",").compactMap { Int($0) })
        }
        set {
            // Turning a repeat off leaves a one-off for today; it never
            // wipes the day of a line that had one and was not repeating.
            if newValue.isEmpty {
                if repeats { day = DateUtils.dateString(from: Date()) }
                return
            }
            repeatDaysRaw = newValue.sorted().map(String.init).joined(separator: ",")
        }
    }

    /// **The one day a one-off is planned for**, `yyyy-MM-dd` as a win's own
    /// day is written (`DateUtils.dateString`). Nil for a repeating line,
    /// and for a one-off from before lines had a day.
    var day: String? {
        get {
            guard repeatDaysRaw.hasPrefix(Self.dayPrefix) else { return nil }
            return String(repeatDaysRaw.dropFirst(Self.dayPrefix.count))
        }
        set { repeatDaysRaw = newValue.map { Self.dayPrefix + $0 } ?? "" }
    }

    init(text: String = "", order: Int = 0, category: HabitCategory = .health, day: String? = nil) {
        self.id = UUID()
        self.text = text
        self.order = order
        self.createdAt = Date()
        self.categoryRaw = category.rawValue
        if let day { self.repeatDaysRaw = Self.dayPrefix + day }
    }

    /// Whether this line belongs on today's list.
    ///
    /// A one-off always does, until the day it was completed is over. A
    /// repeating line belongs on the days it repeats on — and on any day it
    /// was completed, so that ticking something off on a day it was not due
    /// does not make it vanish under your finger.
    ///
    /// **A one-off belongs to its own day** (2026-10-10). It used to belong
    /// to today, every day, until it was done, because a line had no day.
    /// Planning tomorrow needs it to wait for tomorrow, and a day's plan that
    /// was not finished no longer follows you into the next day's list (see
    /// `isEarlier`).
    func belongs(on date: Date, calendar: Calendar, today: Date = Date()) -> Bool {
        if let done = completedAt, calendar.isDate(done, inSameDayAs: date) { return true }
        if repeats { return repeatDays.contains(calendar.component(.weekday, from: date)) }
        // Done on another day than this: that day's, not this one's.
        guard completedAt == nil else { return false }
        if let day { return day == DateUtils.dateString(from: date) }
        return calendar.isDate(date, inSameDayAs: today)
    }

    /// **Still to do on this day**: it belongs here and was not done here.
    /// What the tower draws an outline for, and what the plan lists unticked.
    func isOpen(on date: Date, calendar: Calendar, today: Date = Date()) -> Bool {
        guard belongs(on: date, calendar: calendar, today: today) else { return false }
        guard let done = completedAt else { return true }
        return !calendar.isDate(done, inSameDayAs: date)
    }

    /// **A one-off whose day went by without it.** It is not on today's
    /// tower and not in today's list: a new day starts with what you planned
    /// for it, not with what yesterday left. It waits in the plan, under
    /// today's lines, where one press brings it to today and a swipe lets it
    /// go. Never marked, never counted (the research in `docs/planning.md`:
    /// every planner that rolls leftovers forward grows a backlog that then
    /// has to be cleaned, and a "missed" mark is the app criticising you).
    func isEarlier(than today: Date = Date()) -> Bool {
        guard completedAt == nil, !repeats, let day else { return false }
        return day < DateUtils.dateString(from: today)
    }

    /// How long a one-off waits after its day before it is let go.
    static let keptAfterItsDay = 14

    /// A human reading of the repeat, for the row's subtitle.
    func repeatSummary(calendar: Calendar) -> String? {
        Self.repeatSummary(repeatDays, calendar: calendar)
    }

    /// The same reading for days that are not a line yet: a suggestion's.
    static func repeatSummary(_ repeatDays: Set<Int>, calendar: Calendar) -> String? {
        guard !repeatDays.isEmpty else { return nil }
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
    /// Put a line back to unfinished, because the block it became is gone.
    ///
    /// A tick on the plan means "this turned into a block". Deleting the block
    /// has to be able to undo it, or the plan quietly keeps a claim the tower
    /// no longer supports. Called from every path that deletes a win.
    static func untick(planItemID id: UUID?, context: ModelContext) {
        guard let id else { return }
        let descriptor = FetchDescriptor<PlanItem>(predicate: #Predicate { $0.id == id })
        let item: PlanItem?
        do {
            item = try context.fetch(descriptor).first
        } catch {
            // Logged, not swallowed: a failed fetch here leaves a plan line
            // ticked for a block that no longer exists.
            NSLog("[strata-plan] could not find the plan line to untick: \(error)")
            return
        }
        item?.completedAt = nil
    }

    static func sweep(context: ModelContext, now: Date = Date(),
                      calendar: Calendar = .current) {
        let items: [PlanItem]
        do {
            items = try context.fetch(FetchDescriptor<PlanItem>())
        } catch {
            NSLog("[strata-plan] the overnight sweep could not read the plan: \(error)")
            return
        }
        var changed = false
        let todayString = DateUtils.dateString(from: now)
        let cutoff = calendar.date(byAdding: .day, value: -Self.keptAfterItsDay, to: now)
            .map(DateUtils.dateString(from:)) ?? ""
        for item in items {
            // A one-off from before lines had a day has been today's every
            // day; from here it is today's, and then it is its own.
            if item.repeatDaysRaw.isEmpty, item.completedAt == nil {
                item.day = todayString
                changed = true
                continue
            }
            // One whose day went by two weeks ago, untouched: let go.
            if item.completedAt == nil, let day = item.day, day < cutoff {
                context.delete(item)
                changed = true
                continue
            }
            guard let done = item.completedAt else { continue }
            guard !calendar.isDate(done, inSameDayAs: now) else { continue }
            if item.repeats {
                item.completedAt = nil
            } else {
                context.delete(item)
            }
            changed = true
        }
        if changed { StoreReset.commitDelete("the overnight plan sweep", context: context) }
    }
}

// MARK: - Deleting a line

extension PlanItem {
    /// **One line off the plan**, object by object and logged rather than
    /// `try?`'d (CLAUDE.md, "A batch delete that deletes nothing"). The path
    /// the context menu's Delete always took, and now the swipe's too.
    static func remove(_ item: PlanItem, context: ModelContext) {
        context.delete(item)
        StoreReset.commitDelete("deleting a plan line", context: context)
    }

    /// **Whether a repeating line can lose one day and keep the rest.** It
    /// cannot: a line is one row with the weekdays it comes back on, and there
    /// is nothing to record "not this Tuesday" in. So a swipe on a repeating
    /// line deletes the line, with no "just this one or the repeat" question,
    /// because offering a choice the model cannot keep would be a lie. Adding
    /// it means a per-day exception on the model first.
    static let supportsSingleOccurrenceDelete = false
}

// MARK: - Skipped for a day

/// **A repeating line, skipped for one day.** The line is one row with the
/// weekdays it comes back on (`supportsSingleOccurrenceDelete`), so "not
/// this Tuesday" is kept beside it: on this phone, by day, and forgotten a
/// week on. Nothing is counted and nothing is marked: the outline is not on
/// that day's tower, and the line is back on its next day.
enum PlanSkips {
    private static let key = "plan.skipped"

    private static func entry(_ id: UUID, _ date: Date) -> String {
        "\(DateUtils.dateString(from: date))|\(id.uuidString)"
    }

    static func skip(_ id: UUID, on date: Date, defaults: UserDefaults = .standard) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: date).map(DateUtils.dateString(from:)) ?? ""
        var kept = (defaults.stringArray(forKey: key) ?? []).filter { $0 >= cutoff }
        let new = entry(id, date)
        if !kept.contains(new) { kept.append(new) }
        defaults.set(kept, forKey: key)
    }

    static func unskip(_ id: UUID, on date: Date, defaults: UserDefaults = .standard) {
        defaults.set((defaults.stringArray(forKey: key) ?? []).filter { $0 != entry(id, date) }, forKey: key)
    }

    static func isSkipped(_ id: UUID, on date: Date, defaults: UserDefaults = .standard) -> Bool {
        (defaults.stringArray(forKey: key) ?? []).contains(entry(id, date))
    }
}
