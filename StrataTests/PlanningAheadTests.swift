import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import Strata

/// **Planning ahead** (the owner, 2026-10-10: "let users plan wins ahead,
/// today or days/a week out ... planned wins appear in the tower as empty
/// lattice blocks ... a user should be able to plan their entire next day in
/// under 15 seconds").
@MainActor
@Suite("Planning ahead")
struct PlanningAheadTests {
    let calendar = Calendar.current
    let today = DateUtils.date(from: "2026-10-10")!   // a Saturday

    func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: today)! }
    func name(_ offset: Int) -> String { DateUtils.dateString(from: day(offset)) }

    // MARK: A line has a day

    @Test("a one-off belongs to its own day and no other")
    func oneOffBelongsToItsDay() {
        let line = PlanItem(text: "Email the professor", day: name(1))
        #expect(line.day == name(1))
        #expect(!line.repeats, "a day is not a repeat")
        #expect(!line.belongs(on: today, calendar: calendar, today: today))
        #expect(line.belongs(on: day(1), calendar: calendar, today: today))
        #expect(!line.belongs(on: day(2), calendar: calendar, today: today))
    }

    /// No new stored field: the day rides in the field the weekdays use, so
    /// no iCloud schema has to be deployed.
    @Test("the day is kept in the field that already exists")
    func dayRidesInTheRepeatField() {
        let line = PlanItem(text: "Laundry", day: "2026-10-12")   // a Monday
        #expect(line.repeatDaysRaw == "2,d:2026-10-12")
        #expect(line.day == "2026-10-12")
        #expect(line.repeatDays.isEmpty && !line.repeats, "to this build it is a day, not a repeat")
        // A repeat still round trips, and turning it off leaves a one-off.
        line.repeatDays = [2, 4]
        #expect(line.repeatDaysRaw == "2,4" && line.day == nil && line.repeats)
        line.repeatDays = []
        #expect(!line.repeats && line.day != nil)
        // Clearing the weekdays of a line that has a day keeps its day.
        let dated = PlanItem(text: "Gym", day: "2026-10-14")
        dated.repeatDays = []
        #expect(dated.day == "2026-10-14")
    }

    /// **A phone not yet updated still shows the line, on its day.** That
    /// build's own rules, written out here as they stand in it: any text in
    /// the field is a repeat, on the weekdays it can read as numbers. A bare
    /// `d:...` was therefore a line on no day at all (found by review: the
    /// first version's test checked only that no number was read, and so
    /// passed while proving the opposite of what it said).
    @Test("a build from before reads the line as due on its own weekday")
    func olderBuildsStillShowIt() {
        func oldRepeats(_ raw: String) -> Bool { !raw.isEmpty }
        func oldBelongs(_ raw: String, on date: Date) -> Bool {
            guard oldRepeats(raw) else { return true }
            let days = Set(raw.split(separator: ",").compactMap { Int($0) })
            return days.contains(calendar.component(.weekday, from: date))
        }
        let monday = DateUtils.date(from: "2026-10-12")!
        let line = PlanItem(text: "Laundry", day: "2026-10-12")
        #expect(oldBelongs(line.repeatDaysRaw, on: monday), "shown on the day it is for")
        #expect(!oldBelongs(line.repeatDaysRaw, on: day(1)), "and not on a Sunday")
        // What the first version wrote, and why it was changed.
        #expect(!oldBelongs("d:2026-10-12", on: monday))
    }

    @Test("a line from before lines had a day is today's")
    func undatedIsTodays() {
        let line = PlanItem(text: "Old line")
        #expect(line.day == nil)
        #expect(line.belongs(on: today, calendar: calendar, today: today))
        #expect(!line.belongs(on: day(1), calendar: calendar, today: today))
    }

    @Test("a repeating line is open again each day it is due")
    func repeatsOpenEachDay() {
        let line = PlanItem(text: "Morning walk")
        line.repeatDays = PlanScope.everyDay
        #expect(line.isOpen(on: today, calendar: calendar, today: today))
        line.completedAt = today.addingTimeInterval(3600)
        #expect(!line.isOpen(on: today, calendar: calendar, today: today), "done today")
        #expect(line.belongs(on: today, calendar: calendar, today: today), "and still on today's list, ticked")
        #expect(line.isOpen(on: day(1), calendar: calendar, today: day(1)), "open again tomorrow, with no sweep")
        let weekdays = PlanItem(text: "Send the invoice")
        weekdays.repeatDays = [2, 3, 4, 5, 6]
        #expect(!weekdays.isOpen(on: today, calendar: calendar, today: today), "Saturday")
        #expect(weekdays.isOpen(on: day(2), calendar: calendar, today: today), "Monday")
    }

    // MARK: What was not done

    @Test("yesterday's undone line is earlier, never today's, and never marked")
    func undoneIsEarlier() {
        let line = PlanItem(text: "Return the library book", day: name(-1))
        #expect(line.isEarlier(than: today))
        #expect(!line.belongs(on: today, calendar: calendar, today: today), "a new day starts with its own plan")
        #expect(PlanScope.day(0).lines([line], today: today, calendar: calendar).isEmpty)
        #expect(PlanScope.earlier([line], today: today).map(\.text) == ["Return the library book"])
        #expect(PlannedSlots.open([line], on: today, calendar: calendar).isEmpty, "and no outline on today's tower")
        // Today's and tomorrow's are not earlier; nor is a repeat, ever.
        #expect(!PlanItem(text: "x", day: name(0)).isEarlier(than: today))
        #expect(!PlanItem(text: "x", day: name(1)).isEarlier(than: today))
        let walk = PlanItem(text: "Walk"); walk.repeatDays = [1]
        #expect(!walk.isEarlier(than: today))
    }

    @Test("the sweep gives old lines a day and clears done ones; nothing unfinished is ever deleted")
    func sweep() throws {
        let container = try ModelContainer(for: PlanItem.self, configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let undated = PlanItem(text: "Undated"); context.insert(undated)
        let doneYesterday = PlanItem(text: "Done", day: name(-1)); doneYesterday.completedAt = day(-1)
        context.insert(doneYesterday)
        let recent = PlanItem(text: "Three days back", day: name(-3)); context.insert(recent)
        let old = PlanItem(text: "Two months back", day: name(-60)); context.insert(old)
        let repeatDone = PlanItem(text: "Walk"); repeatDone.repeatDays = PlanScope.everyDay
        repeatDone.completedAt = day(-1); context.insert(repeatDone)
        try context.save()
        PlanItem.sweep(context: context, now: today, calendar: calendar)
        let left = try context.fetch(FetchDescriptor<PlanItem>())
        #expect(Set(left.map(\.text)) == ["Undated", "Three days back", "Two months back", "Walk"])
        #expect(left.first { $0.text == "Undated" }?.day == name(0), "today's from here, then its own day's")
        #expect(left.first { $0.text == "Walk" }?.completedAt == nil)
        #expect(left.first { $0.text == "Two months back" }?.isEarlier(than: today) == true,
                "kept, waiting, unmarked: a plan is never thrown away for you")
    }

    @Test("a box is ticked only on the day the line was done")
    func tickedOnItsDay() {
        let walk = PlanItem(text: "Walk"); walk.repeatDays = PlanScope.everyDay
        walk.completedAt = today.addingTimeInterval(3600)
        #expect(walk.isTicked(on: today, calendar: calendar))
        #expect(!walk.isTicked(on: day(1), calendar: calendar), "done today is not done tomorrow")
        #expect(!PlanItem(text: "Open").isTicked(on: today, calendar: calendar))
        // Tomorrow's page lists it, unticked: pressing it there must never
        // be read as undoing today's.
        #expect(PlanScope.day(1).lines([walk], today: today, calendar: calendar).count == 1)
        let lines = SourceSweep.code((try? SourceSweep.read("Strata/Views/PlanLines.swift")) ?? "")
        #expect(lines.contains("guard scope == .day(0) else {"), "only today's page does things")
    }

    @Test("Not Today moves a one-off to tomorrow; a repeat is skipped for the day and can be put back")
    func notToday() {
        let walk = PlanItem(text: "Walk"); walk.repeatDays = PlanScope.everyDay
        #expect(PlannedSlots.open([walk], on: today, calendar: calendar).count == 1)
        PlanSkips.skip(walk.id, on: today)
        #expect(PlannedSlots.open([walk], on: today, calendar: calendar).isEmpty)
        #expect(PlanScope.day(0).lines([walk], today: today, calendar: calendar).isEmpty, "the plan and the tower agree")
        #expect(PlannedSlots.open([walk], on: day(1), calendar: calendar).count == 1, "back on its next day")
        PlanSkips.unskip(walk.id, on: today)
        #expect(PlannedSlots.open([walk], on: today, calendar: calendar).count == 1)
    }

    // MARK: Writing a plan as fast as a note

    @Test("a pasted list is a line each, bullets off")
    func pastedList() {
        let pasted = "- Email the professor\n\u{2022} Laundry\n\n1. Gym with Sam\n2) Call Mum\n[ ] Read\n  * Stretch  \n12. Twelve"
        #expect(DayComposing.planLines(in: pasted)
                == ["Email the professor", "Laundry", "Gym with Sam", "Call Mum", "Read", "Stretch", "Twelve"])
        // A line that only looks like a number is left alone.
        #expect(DayComposing.planLines(in: "5k run") == ["5k run"])
        #expect(DayComposing.planLines(in: "2026 budget") == ["2026 budget"])
        #expect(DayComposing.planLines(in: "   \n\n") == [])
    }

    @Test("lines are added for the day chosen, in order, and repeating ones repeat")
    func addForADay() throws {
        let container = try ModelContainer(for: PlanItem.self, Habit.self, HabitLog.self,
                                           configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let made = DayComposing.addPlanLines("Email the professor\nLaundry", after: [], habits: [], context: context,
                                             day: day(1))
        #expect(made.map(\.text) == ["Email the professor", "Laundry"])
        #expect(made.allSatisfy { $0.day == name(1) && !$0.repeats })
        #expect(made[0].order < made[1].order)
        let habit = DayComposing.addPlanLines("Morning walk", after: made, habits: [], context: context,
                                              repeatDays: PlanScope.everyDay)
        #expect(habit.first?.repeats == true && habit.first?.day == nil)
        let all = try context.fetch(FetchDescriptor<PlanItem>())
        #expect(PlanScope.day(1).lines(all, today: today, calendar: calendar).map(\.text).sorted()
                == ["Email the professor", "Laundry", "Morning walk"])
        #expect(PlanScope.repeating.lines(all, today: today, calendar: calendar).map(\.text) == ["Morning walk"])
        #expect(PlanScope.day(0).lines(all, today: today, calendar: calendar).map(\.text) == ["Morning walk"])
    }

    /// The owner, 2026-10-11: "what if you want to select something that
    /// repeats on monday wednesday friday there is no option for that".
    @Test("a line planned for Monday, Wednesday and Friday is due on those days and no other")
    func someDays() throws {
        let container = try ModelContainer(for: PlanItem.self, Habit.self, HabitLog.self,
                                           configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let made = DayComposing.addPlanLines("Gym", after: [], habits: [], context: context, repeatDays: [2, 4, 6])
        let gym = try #require(made.first)
        #expect(gym.repeats && gym.day == nil)
        #expect(gym.repeatSummary(calendar: calendar) == "Mon Wed Fri")
        #expect(PlanScope.repeating.lines(made, today: today, calendar: calendar).map(\.text) == ["Gym"])
        // A whole week from today: on the page, and on the tower, on those
        // three days alone.
        for offset in 0..<7 {
            let date = day(offset)
            let due = [2, 4, 6].contains(calendar.component(.weekday, from: date))
            #expect(gym.belongs(on: date, calendar: calendar, today: today) == due)
            #expect(PlannedSlots.open(made, on: date, calendar: calendar).isEmpty == !due)
        }
    }

    /// The chips are where the line is written, and what they hold is what
    /// the line gets, in all three places a repeating line is made.
    @Test("the days chosen under Repeating reach the line, wherever it is written")
    func chosenDaysReachTheLine() throws {
        let sheet = SourceSweep.code(try SourceSweep.read("Strata/Views/DaySheet.swift"))
        #expect(sheet.contains("WeekdayChips(days: $repeatDays)"))
        #expect(sheet.contains("repeatDays: planScope == .repeating ? repeatDays : []"))
        #expect(sheet.contains("repeatDays: repeatDays)"), "the plan's own lines are told the days")
        let lines = SourceSweep.code(try SourceSweep.read("Strata/Views/PlanLines.swift"))
        #expect(lines.contains("line.repeatDays = repeatDays.isEmpty ? PlanScope.everyDay : repeatDays"))
        let add = SourceSweep.code(try SourceSweep.read("Strata/Views/AddWinSheet.swift"))
        #expect(add.contains("WeekdayChips(days: $planDays)"))
        #expect(add.contains("repeatDays: scope == .repeating ? planDays : []"))
        // Never no day at all: the last one on cannot be pressed off.
        let chips = SourceSweep.code(try SourceSweep.read("Strata/Views/PlanScope.swift"))
        #expect(chips.contains("if on, days.count == 1"))
    }

    // MARK: Found by the read of 2026-10-11

    @Test("a win ticks the line open today, never another day's with the same words")
    func ticksTodaysLine() {
        let thursday = PlanItem(text: "Study", order: 0, day: name(5))
        let todays = PlanItem(text: "study ", order: 1, day: name(0))
        #expect(DayComposing.onPlan("Study", in: [thursday, todays], on: today, calendar: calendar) === todays)
        // Done today already: there is nothing of today's to tick, and
        // Thursday's is left for Thursday.
        todays.completedAt = today
        #expect(DayComposing.onPlan("Study", in: [thursday, todays], on: today, calendar: calendar) == nil)
        // In the plan's order when two of today's share the words.
        let first = PlanItem(text: "Study", order: 0, day: name(0))
        let second = PlanItem(text: "Study", order: 3, day: name(0))
        #expect(DayComposing.onPlan("Study", in: [second, first], on: today, calendar: calendar) === first)
        // A repeating line ticked on a day gone by, in an app open since,
        // is open today and is found.
        let walk = PlanItem(text: "Walk", order: 0); walk.repeatDays = PlanScope.everyDay
        walk.completedAt = day(-1)
        #expect(DayComposing.onPlan("Walk", in: [walk], on: today, calendar: calendar) === walk)
        // One whose day went by: doing it now is doing it.
        let late = PlanItem(text: "Laundry", order: 0, day: name(-2))
        #expect(DayComposing.onPlan("Laundry", in: [late], on: today, calendar: calendar) === late)
    }

    @Test("only a repeating line can be skipped for a day")
    func skipIsARepeats() {
        let suite = "skip-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let line = PlanItem(text: "Gym", order: 0); line.repeatDays = PlanScope.everyDay
        PlanSkips.skip(line.id, on: Date(), defaults: defaults)
        #expect(PlanSkips.isSkipped(line, on: Date(), defaults: defaults))
        // Made a one-off in its own sheet: it is today's, and shown today.
        line.repeatDays = []
        #expect(!line.repeats && line.day == DateUtils.dateString(from: Date()))
        #expect(!PlanSkips.isSkipped(line, on: Date(), defaults: defaults))
    }

    @Test("a repeat switched off does not keep a tick from a day gone by")
    func repeatOffDropsAnOldTick() {
        let line = PlanItem(text: "Gym", order: 0); line.repeatDays = [2, 4, 6]
        line.completedAt = Calendar.current.date(byAdding: .day, value: -2, to: Date())
        line.repeatDays = []
        #expect(line.completedAt == nil, "or it is a one-off done on no day, shown nowhere, and swept")
        #expect(line.isOpen(on: Date(), calendar: .current))
        let doneToday = PlanItem(text: "Read", order: 1); doneToday.repeatDays = [2, 4, 6]
        let now = Date(); doneToday.completedAt = now
        doneToday.repeatDays = []
        #expect(doneToday.completedAt == now, "today's tick is today's")
    }

    @Test("a tick still waiting for its win at launch is taken back, unless the win is there")
    func pendingTickIsSettled() throws {
        let container = try ModelContainer(for: PlanItem.self, Habit.self, HabitLog.self,
                                           configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let suite = "tick-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let line = PlanItem(text: "Call the landlord", order: 0, day: DateUtils.dateString(from: Date()))
        line.completedAt = Date()
        context.insert(line)
        try context.save()
        // Nothing waiting: nothing is touched.
        PlanTickPending.settle(context: context, defaults: defaults)
        #expect(line.completedAt != nil)
        // The app closed with the add sheet up: no win was made.
        PlanTickPending.hold(line.id, defaults: defaults)
        PlanTickPending.settle(context: context, defaults: defaults)
        #expect(line.completedAt == nil)
        #expect(defaults.string(forKey: PlanTickPending.key) == nil, "settled once")
        // The win was saved and only the note was left behind.
        line.completedAt = Date()
        let win = Habit(title: "Call the landlord", category: .health)
        win.planItemID = line.id
        context.insert(win)
        try context.save()
        PlanTickPending.hold(line.id, defaults: defaults)
        PlanTickPending.settle(context: context, defaults: defaults)
        #expect(line.completedAt != nil)
    }

    @Test("a win that ticks a line by name remembers the line")
    func winRemembersTheLine() throws {
        let container = try ModelContainer(for: PlanItem.self, Habit.self, HabitLog.self,
                                           configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let line = PlanItem(text: "Gym", order: 0, day: DateUtils.dateString(from: Date()))
        let later = PlanItem(text: "Gym", order: 1, day: DateUtils.dateString(from: Date().addingTimeInterval(3 * 86_400)))
        let win = Habit(title: "Gym", category: .health)
        context.insert(line); context.insert(later); context.insert(win)
        #expect(WinIdeas.tickPlanLine(named: "gym", context: context, win: win) == line.id)
        #expect(win.planItemID == line.id)
        #expect(line.completedAt != nil && later.completedAt == nil, "the later day's line waits for its day")
        // Nothing of today's left with those words: nothing is ticked.
        #expect(WinIdeas.tickPlanLine(named: "Gym", context: context) == nil)
        #expect(later.completedAt == nil)
        // Made from a line: told which, and nothing is ticked by name.
        let other = PlanItem(text: "Read", order: 2, day: DateUtils.dateString(from: Date()))
        let twin = PlanItem(text: "Read", order: 3, day: DateUtils.dateString(from: Date()))
        let read = Habit(title: "Read", category: .health)
        context.insert(other); context.insert(twin); context.insert(read)
        WinIdeas.winMade(read, from: twin.id, named: "Read", context: context)
        #expect(read.planItemID == twin.id)
        #expect(other.completedAt == nil && twin.completedAt == nil, "the caller ticks the line it opened")
    }

    @Test("Do It Too brings a line whose day went by to today")
    func doItTooBringsItToToday() throws {
        let container = try ModelContainer(for: PlanItem.self, Habit.self, HabitLog.self,
                                           configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let past = DateUtils.dateString(from: Date().addingTimeInterval(-2 * 86_400))
        let late = PlanItem(text: "Morning run", order: 0, day: past)
        context.insert(late)
        try context.save()
        let line = DayComposing.doItToo("Morning run", colour: .health, size: .small, context: context)
        #expect(line === late && late.day == DateUtils.dateString(from: Date()))
        #expect(try context.fetch(FetchDescriptor<PlanItem>()).count == 1)
    }

    @Test("the review's fixes are where the code is")
    func reviewFixesArePinned() throws {
        let add = SourceSweep.code(try SourceSweep.read("Strata/Views/AddWinSheet.swift"))
        let made = try #require(add.range(of: "WinIdeas.winMade(win.habit, from: plannedLine, named: title, context: modelContext)"))
        let attach = try #require(add.range(of: "guard await attach(photo, to: log) else {"))
        #expect(made.lowerBound < attach.lowerBound, "the plan hears of the win before a photo can fail")
        #expect(add.contains("&& (isPlanning || (photo == nil && doodle == nil))"),
                "a sheet holding a picture is not offered a day; one whose picture was removed is")
        let main = SourceSweep.code(try SourceSweep.read("Strata/Views/MainAppView.swift"))
        // Through `planned` since 2026-10-13 (a crew's tower presses the
        // same boxes): the guard is the same, in one place.
        #expect(main.contains("onCamera: { planned(nil, $0, .camera) }"))
        #expect(main.contains("case .camera: if stillThere(item), !alreadyWon(item) { capturingPlan = item }"))
        #expect(main.contains("plannedLine: draft.planItemID"))
        #expect(main.contains("PlanTickPending.hold(item.id)"))
        let settle = try #require(main.range(of: "PlanTickPending.settle(context: modelContext)"))
        let sweep = try #require(main.range(of: "PlanItem.sweep(context: modelContext)"))
        #expect(settle.lowerBound < sweep.lowerBound, "before the sweep reads the tick as done")
        let sheet = SourceSweep.code(try SourceSweep.read("Strata/Views/PlanItemDetailSheet.swift"))
        // The line's sheet draws the app's one weekday chip, which is where
        // the last day is refused (2026-10-11, one chip in three places).
        #expect(sheet.contains("WeekdayChips(days: Binding(get: { item.repeatDays }, set: { item.repeatDays = $0 }),"))
        #expect(!sheet.contains("veryShortWeekdaySymbols"), "no second drawing of the seven days")
        #expect(sheet.contains("item.repeatDays = [calendar.component(.weekday, from: date)]"),
                "Repeats on keeps the line on the day it had")
        #expect(!sheet.contains("on ? [2, 3, 4, 5, 6] : []"))
    }

    /// The owner, 2026-10-11: the `+` block "feels out of place next to the
    /// check mark block when they should look the same", and "the checkmark
    /// block font and weight should be the same as the other blocks".
    @Test("the slot and a planned win are one pane, and an outline's words are a block's")
    func onePane() throws {
        // No line in dark (the owner, 2026-10-11: "why in dark mode is there
        // an outline on everything"): the dark pane is lifted in its glass.
        #expect(SlotPane.edge(.dark) == 0 && SlotPane.edge(.light) > 0)
        // And no hue of its own: the page's glass, as the buttons beside
        // it are ("a different hue from the other liquid glass elements").
        let recipe = SourceSweep.code(try SourceSweep.read("Strata/Views/SlotGlass.swift"))
        #expect(recipe.contains("if dark { return .regular.tint(.black.opacity(pageInk + 0.06 * t)).interactive() }"))
        #expect(!recipe.contains(".white.opacity("))
        let glass = SourceSweep.code(try SourceSweep.read("Strata/Views/SlotGlass.swift"))
        #expect(glass.contains("GlassRecipe.slot(thickness: thickness, dark: scheme == .dark)"))
        let slot = SourceSweep.code(try SourceSweep.read("Strata/Views/NextSlotButton.swift"))
        #expect(slot.contains("let base = SlotPane.edge(scheme)"))
        #expect(slot.contains("AppColors.slotInk.opacity(isDown ? base * 2 : 0)"), "no recess at rest; it answers a press")
        let outline = SourceSweep.code(try SourceSweep.read("Strata/Views/PlannedBlocks.swift"))
        #expect(outline.contains("AppColors.slotInk.opacity(SlotPane.edge(scheme))"))
        #expect(!outline.contains(".opacity(0.82)"), "not dimmed behind the slot")
        // The title's own lines (the time beside the box wears the same
        // face, quieter, since 2026-10-11).
        #expect(outline.contains("Text(title)\n                    .font(BlockContentOverlay.titleFont)\n                    .foregroundStyle(AppColors.inkPrimary)"),
                "the block's face at full strength, not the secondary grey")
    }

    @Test("a line's own sheet can move it to another day")
    func dayFromTheLine() {
        #expect(PlanScope.of(day: name(0), today: today, calendar: calendar) == .day(0))
        #expect(PlanScope.of(day: name(3), today: today, calendar: calendar) == .day(3))
        #expect(PlanScope.of(day: name(-2), today: today, calendar: calendar) == nil, "a day gone by is none of the row's")
        #expect(PlanScope.of(day: name(9), today: today, calendar: calendar) == nil)
        #expect(PlanScope.of(day: nil, today: today, calendar: calendar) == nil)
        #expect(PlanScope.days.count == 7 && !PlanScope.days.contains(.repeating))
    }

    @Test("the row of days reads Today, Tomorrow, then the days by name")
    func scopeWords() {
        #expect(PlanScope.all.count == 8)
        #expect(PlanScope.day(0).title(from: today, calendar: calendar) == "Today")
        #expect(PlanScope.day(1).title(from: today, calendar: calendar) == "Tomorrow")
        #expect(PlanScope.day(2).title(from: today, calendar: calendar) == "Mon")
        #expect(PlanScope.day(2).spoken(from: today, calendar: calendar) == "for Monday")
        #expect(WhenRow.title(nil) == "Now" && WhenRow.title(.day(0)) == "Later")
    }

    @Test("deleting an old win does not untick today's")
    func untickOnlyItsOwnDay() throws {
        let container = try ModelContainer(for: PlanItem.self, configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let walk = PlanItem(text: "Walk"); walk.repeatDays = PlanScope.everyDay
        walk.completedAt = today
        context.insert(walk)
        try context.save()
        // Last week's win from the same line is deleted.
        PlanItem.untick(planItemID: walk.id, madeOn: day(-7), context: context, calendar: calendar)
        #expect(walk.completedAt != nil, "today's tick is today's win's")
        // Today's own win is deleted: the tick goes with it.
        PlanItem.untick(planItemID: walk.id, madeOn: today.addingTimeInterval(60), context: context, calendar: calendar)
        #expect(walk.completedAt == nil)
    }

    // MARK: The day's one cue

    /// One cue a day stays the rule. The one that was going anyway says
    /// what the day's plan is, in names, never a number.
    @Test("the day's reminder carries the day's plan")
    func reminderKnowsThePlan() {
        #expect(DailyReminder.body(planned: []) == DailyReminder.body)
        #expect(DailyReminder.body(planned: ["Morning walk", " Laundry "]) == "Today: Morning walk, Laundry")
        let many = DailyReminder.body(planned: ["A", "B", "C", "D", "E"])
        #expect(many == "Today: A, B, C", "the first three, and no count of the rest")
        for word in ["miss", "forgot", "overdue", "only", "streak", "\u{2014}"] {
            #expect(!many.lowercased().contains(word))
        }
        let hasNumber = many.contains { $0.isNumber }
        #expect(!hasNumber)

        let walk = PlanItem(text: "Morning walk", order: 0); walk.repeatDays = PlanScope.everyDay
        walk.completedAt = today   // done today: not in today's cue, back tomorrow
        let email = PlanItem(text: "Email the professor", order: 1, day: name(1))
        let earlier = PlanItem(text: "Return the book", order: 2, day: name(-1))
        let planned = DailyReminder.plannedByDay([email, walk, earlier], from: today, calendar: calendar)
        #expect(planned[name(0)] == nil, "nothing open today")
        #expect(planned[name(1)] == ["Morning walk", "Email the professor"])
        #expect(planned[name(2)] == ["Morning walk"])
        #expect(planned.values.allSatisfy { !$0.contains("Return the book") }, "what went by is not brought up")
    }

    // MARK: In a backup

    /// The plan was never in a backup. With routines living in it, a lost
    /// phone lost every one.
    @Test("the plan goes into a backup and comes back once")
    func backupRoundTrip() throws {
        let open = PlanItem(text: "Email the professor", order: 1, category: .work, day: name(1))
        let routine = PlanItem(text: "Morning walk", order: 0, category: .health)
        routine.repeatDays = PlanScope.everyDay
        routine.completedAt = today   // done today, and still a routine
        let finished = PlanItem(text: "Done and gone", order: 2, day: name(0)); finished.completedAt = today
        let blank = PlanItem(text: "  ", order: 3, day: name(0))
        let exported = BackupExport.planLines([open, routine, finished, blank])
        #expect(exported.map(\.text) == ["Morning walk", "Email the professor"], "in the plan's order, nothing finished or blank")
        #expect(exported[0].when == routine.repeatDaysRaw && exported[1].when == open.repeatDaysRaw)

        // Through the file's own coding.
        let data = try JSONEncoder().encode(exported)
        let read = try JSONDecoder().decode([BackupArchive.ExportPlanLine].self, from: data)
        #expect(read == exported)

        // Onto a phone with nothing: both. Onto one that has them: none.
        #expect(BackupRestore.planLinesMissing(read, from: []).count == 2)
        #expect(BackupRestore.planLinesMissing(read, from: [open, routine]).isEmpty)
        // Typed again on the new phone, a different id: still not doubled.
        let retyped = PlanItem(text: "morning walk"); retyped.repeatDays = PlanScope.everyDay
        #expect(BackupRestore.planLinesMissing(read, from: [retyped]).map(\.text) == ["Email the professor"])
        // The same line twice in a file is one line.
        #expect(BackupRestore.planLinesMissing(read + read, from: []).count == 2)

        // A backup from before the plan was in it still opens.
        let old = Data(#"{"exportDate":0,"appVersion":"1","habits":[],"logs":[]}"#.utf8)
        let document = try JSONDecoder().decode(BackupArchive.Document.self, from: old)
        #expect(document.plan == nil)
    }

    // MARK: Outlines on the tower

    @Test("outlines queue behind the slot, a cell each, in the plan's order")
    func outlinesAfterTheSlot() {
        // Three blocks on the bottom row: Quick, Quick, Regular. The slot is
        // the first cell of the second row.
        let grid = [[true, true, true, true]]
        let cells = PlannedSlots.cells(count: 3, grid: grid, slot: (0, 1), slotSize: .small)
        #expect(cells.map(\.column) == [1, 2, 3] && cells.allSatisfy { $0.row == 1 })
        // The slot drawn out to a Regular: the outlines step along.
        let wide = PlannedSlots.cells(count: 3, grid: grid, slot: (0, 1), slotSize: .medium)
        #expect(wide.map(\.column) == [2, 3, 0] && wide.map(\.row) == [1, 1, 2])
        // An empty tower: slot in the corner, outlines beside it.
        let empty = PlannedSlots.cells(count: 2, grid: [], slot: (0, 0), slotSize: .small)
        #expect(empty.map(\.column) == [1, 2] && empty.allSatisfy { $0.row == 0 })
        // A hole beside a Deep block is filled, as the tower itself would.
        let holed = [[true, true, false, false], [true, true, false, false]]
        let inHoles = PlannedSlots.cells(count: 3, grid: holed, slot: (2, 0), slotSize: .small)
        #expect(inHoles.first! == (3, 0))
        #expect(PlannedSlots.rows(cells) == 2)
    }

    @Test("never more than two rows of outlines, however long the plan")
    func capped() {
        let cells = PlannedSlots.cells(count: 30, grid: [], slot: (0, 0), slotSize: .small)
        #expect(cells.count == PlannedSlots.most)
        #expect(PlannedSlots.cells(count: 0, grid: [], slot: (0, 0), slotSize: .small).isEmpty)
    }

    @Test("only what is open today stands on the tower")
    func onlyTodaysOpenLines() {
        let done = PlanItem(text: "Done", order: 0, day: name(0)); done.completedAt = today
        let open = PlanItem(text: "Open", order: 2, day: name(0))
        let first = PlanItem(text: "First", order: 1, day: name(0))
        let tomorrow = PlanItem(text: "Tomorrow's", order: 3, day: name(1))
        let blank = PlanItem(text: "  ", order: 4, day: name(0))
        let skipped = PlanItem(text: "Skipped walk", order: 5); skipped.repeatDays = PlanScope.everyDay
        PlanSkips.skip(skipped.id, on: today)
        defer { PlanSkips.unskip(skipped.id, on: today) }
        let lines = PlannedSlots.open([done, open, first, tomorrow, blank, skipped], on: today, calendar: calendar)
        #expect(lines.map(\.text) == ["First", "Open"])
        #expect(!PlanSkips.isSkipped(skipped.id, on: day(1)), "skipped for a day, not for good")
    }

    /// The goal and its dance count wins. An outline is not one, and must
    /// never be handed to the tower as a block.
    @Test("a planned win is never a block")
    func neverABlock() throws {
        let main = SourceSweep.code(try SourceSweep.read("Strata/Views/MainAppView.swift"))
        let layer = try #require(main.components(separatedBy: "private func plannedLayer").dropFirst().first)
        let body = layer.components(separatedBy: "private func emptyTowerSlot").first ?? ""
        #expect(body.contains("PlannedLayer("))
        #expect(!body.contains("PlacedBlock(") && !body.contains("buildTower"))
        let outline = SourceSweep.code(try SourceSweep.read("Strata/Views/PlannedBlocks.swift"))
        // No colour, rim, band or shadow: the slot's own glass.
        #expect(outline.contains(".glassSlot(cornerRadius:"))
        for mark in ["BlockSurface", "styleFor", ".shadow(", "category.style", "EtherealFill"] {
            #expect(!outline.contains(mark), "\(mark) would make an outline a block")
        }
    }
}
