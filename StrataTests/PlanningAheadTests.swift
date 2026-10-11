import Foundation
import SwiftData
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
