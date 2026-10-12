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
    /// first line that carries it. This field is already in the schema.
    ///
    /// **Written with its weekday in front, `3,d:2026-10-13`, for a build
    /// from before this** (found by review). That build takes any text here
    /// for a repeat and shows a line only on the weekdays it can read, so a
    /// bare `d:...` was a line on no day at all: hidden on a phone not yet
    /// updated. With the weekday in front that phone shows it on its own
    /// day (and, being an older build, takes it for a weekly repeat until it
    /// is done). This build reads the `d:` and ignores the number.
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
            guard day == nil else { return [] }
            return Set(repeatDaysRaw.split(separator: ",").compactMap { Int($0) })
        }
        set {
            // Turning a repeat off leaves a one-off for today; it never
            // wipes the day of a line that had one and was not repeating.
            if newValue.isEmpty {
                if repeats {
                    // A tick from a day gone by is that day's: the sweep
                    // clears it at launch, and in an app open since then it
                    // was still there. Left on what is now a one-off, the
                    // line was done on no day, shown nowhere, and cleared
                    // off the plan overnight (found by review, 2026-10-11).
                    if let done = completedAt, !Calendar.current.isDateInToday(done) { completedAt = nil }
                    day = DateUtils.dateString(from: Date())
                }
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
            repeatDaysRaw.split(separator: ",").first { $0.hasPrefix(Self.dayPrefix) }
                .map { String($0.dropFirst(Self.dayPrefix.count)) }
        }
        set { repeatDaysRaw = newValue.map(Self.raw(forDay:)) ?? "" }
    }

    /// A day as the field holds it: its weekday for a build from before,
    /// then the day itself.
    static func raw(forDay day: String) -> String {
        guard let date = DateUtils.date(from: day) else { return dayPrefix + day }
        return "\(DateUtils.keyCalendar().component(.weekday, from: date)),\(dayPrefix)\(day)"
    }

    init(text: String = "", order: Int = 0, category: HabitCategory = .health, day: String? = nil) {
        self.id = UUID()
        self.text = text
        self.order = order
        self.createdAt = Date()
        self.categoryRaw = category.rawValue
        if let day { self.repeatDaysRaw = Self.raw(forDay: day) }
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
    /// today's lines, where one press brings them to today and a swipe lets
    /// one go. Never marked, never counted (`docs/planning.md`: every
    /// planner that rolls leftovers forward grows a backlog that then has to
    /// be cleaned, and a "missed" mark is the app criticising you).
    ///
    /// **And never deleted for you.** For a few hours it was let go two
    /// weeks after its day; the rule this type has always had is the right
    /// one ("deciding for somebody that an unfinished plan expires overnight
    /// is the kind of tidying that loses work"), and a person's existing
    /// plan, given a day by the update, would have been gone a fortnight
    /// later with nothing said (found by review).
    func isEarlier(than today: Date = Date()) -> Bool {
        guard completedAt == nil, !repeats, let day else { return false }
        return day < DateUtils.dateString(from: today)
    }

    /// Ticked on this day: what a line's box shows on that day's page. A
    /// repeating line done today is not done tomorrow.
    func isTicked(on date: Date, calendar: Calendar) -> Bool {
        completedAt.map { calendar.isDate($0, inSameDayAs: date) } ?? false
    }

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
    /// repeating means. Anything still unfinished is kept: deciding for
    /// somebody that an unfinished plan expires overnight is the kind of
    /// tidying that loses work. (Since lines have days it is kept under
    /// Earlier rather than in today's list; see `isEarlier`.)
    /// Put a line back to unfinished, because the block it became is gone.
    ///
    /// A tick on the plan means "this turned into a block". Deleting the block
    /// has to be able to undo it, or the plan quietly keeps a claim the tower
    /// no longer supports. Called from every path that deletes a win.
    ///
    /// **Only the tick that win made** (`madeOn`, 2026-10-10). A repeating
    /// line is ticked afresh each day, by a different win each time. Deleting
    /// last week's win used to clear whatever tick the line had, which now
    /// would put today's finished outline back on the tower.
    static func untick(planItemID id: UUID?, madeOn: Date? = nil, context: ModelContext,
                       calendar: Calendar = .current) {
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
        if let madeOn, let done = item?.completedAt, !calendar.isDate(done, inSameDayAs: madeOn) { return }
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
        for item in items {
            // A one-off from before lines had a day has been today's every
            // day; from here it is today's, and then it is its own.
            if item.repeatDaysRaw.isEmpty, item.completedAt == nil {
                item.day = todayString
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

    /// Whether this line is off the day's tower and list. **Only a line
    /// that repeats can be** (found by review, 2026-10-11): skipped for
    /// today and then made a one-off in its own sheet, a line was today's
    /// and hidden from today, in no list and on no tower until tomorrow.
    static func isSkipped(_ item: PlanItem, on date: Date, defaults: UserDefaults = .standard) -> Bool {
        item.repeats && isSkipped(item.id, on: date, defaults: defaults)
    }
}

// MARK: - A tick waiting for its win

/// **The plan's box is ticked before the win exists** (`PlanLines.complete`),
/// so the press has an answer, and the add sheet closing without a win takes
/// the tick back. That taking back was in memory only: with the app closed
/// from the add sheet, the line stayed ticked with no win behind it, and a
/// one-off was then cleared off the plan overnight as done (found by review,
/// 2026-10-11). The line waiting is written down, and the next launch puts
/// it back before the sweep reads it.
enum PlanTickPending {
    static let key = "plan.tickAwaitingWin"

    static func hold(_ id: UUID, defaults: UserDefaults = .standard) {
        defaults.set(id.uuidString, forKey: key)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }

    /// At launch: a tick still waiting never got its win, unless a win that
    /// names the line is there after all.
    @MainActor
    static func settle(context: ModelContext, defaults: UserDefaults = .standard) {
        guard let id = defaults.string(forKey: key).flatMap(UUID.init(uuidString:)) else { return }
        defaults.removeObject(forKey: key)
        guard let line = try? context.fetch(FetchDescriptor<PlanItem>(predicate: #Predicate { $0.id == id })).first,
              let done = line.completedAt else { return }
        let wins = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        let calendar = Calendar.current
        guard !wins.contains(where: { $0.planItemID == id && calendar.isDate($0.createdAt, inSameDayAs: done) }) else { return }
        line.completedAt = nil
        try? context.save()
    }
}

// MARK: - A time, written into the line

/// **"Gym @ 2"** (the owner, 2026-10-11: "if you were able to time
/// allocate, like gym @ 2 or something like that, make sure it is super
/// simple and optional").
///
/// The time is the words. Nothing is set anywhere: you type "Gym @ 2" where
/// you type any plan, the app reads the end of the line, and shows that it
/// understood ("2 PM" under the line and on its outline). To change it,
/// change the words. A line with no time is exactly as it was.
///
/// **Kept in the text on purpose.** A time of its own would be a new field
/// on the model, which needs the iCloud schema deployed by hand before any
/// phone can save one. In the words, it already syncs, is already in
/// backups, already shows in the day's reminder ("Today: Gym @ 2"), and a
/// phone on an older build simply shows what was typed.
///
/// What is read: `@ 2`, `@2:30`, `@ 14:00`, `@ 9am`, and the same after
/// "at". With no am or pm, 1 to 6 is the afternoon and 7 to 11 the morning,
/// which is what a person planning their day means by "@ 2" and "@ 9".
nonisolated enum PlanTime {
    struct Found: Equatable {
        /// The line without its time: what the win is called.
        var title: String
        /// Minutes after midnight.
        var minutes: Int
    }

    private static let pattern = try? NSRegularExpression(
        pattern: #"\s*(?:@|\bat)\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm|a|p)?\s*$"#, options: [.caseInsensitive])

    static func parse(_ text: String) -> Found? {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let pattern, let match = pattern.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let whole = Range(match.range, in: line),
              let hourRange = Range(match.range(at: 1), in: line), var hour = Int(line[hourRange]) else { return nil }
        let minute = Range(match.range(at: 2), in: line).flatMap { Int(line[$0]) } ?? 0
        let half = Range(match.range(at: 3), in: line).map { line[$0].lowercased() }
        guard minute < 60 else { return nil }
        if let half {
            guard (1...12).contains(hour) else { return nil }
            if half.hasPrefix("p"), hour < 12 { hour += 12 }
            if half.hasPrefix("a"), hour == 12 { hour = 0 }
        } else {
            guard hour < 24 else { return nil }
            // "@ 2" is two in the afternoon; "@ 9" is nine in the morning.
            if (1...6).contains(hour) { hour += 12 }
        }
        let title = String(line[..<whole.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        // A time alone is not a plan with a time; it is just what was typed.
        guard !title.isEmpty else { return nil }
        return Found(title: title, minutes: hour * 60 + minute)
    }

    /// What the win is called: the line without its time.
    static func title(_ text: String) -> String {
        parse(text)?.title ?? text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// "2 PM", "2:30 PM", or the 24 hour form where the phone uses it.
    static func label(_ minutes: Int, calendar: Calendar = .current, locale: Locale = .current) -> String {
        var parts = DateComponents()
        parts.year = 2026; parts.month = 1; parts.day = 1
        parts.hour = minutes / 60; parts.minute = minutes % 60
        guard let date = calendar.date(from: parts) else { return "" }
        let style = minutes % 60 == 0 ? Date.FormatStyle.dateTime.hour() : Date.FormatStyle.dateTime.hour().minute()
        var styled = style
        styled.locale = locale
        styled.timeZone = calendar.timeZone
        return date.formatted(styled)
    }

    /// The time a line carries, as it is shown, or nil.
    static func label(for text: String) -> String? {
        parse(text).map { label($0.minutes) }
    }
}
