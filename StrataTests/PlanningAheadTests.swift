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
    /// no iCloud schema has to be deployed. A build from before reads it as
    /// no weekdays, which is a plain one-off.
    @Test("the day is kept in the field that already exists")
    func dayRidesInTheRepeatField() {
        let line = PlanItem(text: "Laundry", day: "2026-10-12")
        #expect(line.repeatDaysRaw == "d:2026-10-12")
        #expect(line.repeatDays.isEmpty)
        // As a build from before this reads it.
        let oldReading = Set(line.repeatDaysRaw.split(separator: ",").compactMap { Int($0) })
        #expect(oldReading.isEmpty)
        // A repeat still round trips, and turning it off leaves a one-off.
        line.repeatDays = [2, 4]
        #expect(line.repeatDaysRaw == "2,4" && line.day == nil && line.repeats)
        line.repeatDays = []
        #expect(!line.repeats && line.day != nil)
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

    @Test("the sweep gives old lines a day, clears done ones, and lets go after two weeks")
    func sweep() throws {
        let container = try ModelContainer(for: PlanItem.self, configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let undated = PlanItem(text: "Undated"); context.insert(undated)
        let doneYesterday = PlanItem(text: "Done", day: name(-1)); doneYesterday.completedAt = day(-1)
        context.insert(doneYesterday)
        let recent = PlanItem(text: "Three days back", day: name(-3)); context.insert(recent)
        let stale = PlanItem(text: "Long gone", day: name(-PlanItem.keptAfterItsDay - 1)); context.insert(stale)
        let repeatDone = PlanItem(text: "Walk"); repeatDone.repeatDays = PlanScope.everyDay
        repeatDone.completedAt = day(-1); context.insert(repeatDone)
        try context.save()
        PlanItem.sweep(context: context, now: today, calendar: calendar)
        let left = try context.fetch(FetchDescriptor<PlanItem>())
        #expect(Set(left.map(\.text)) == ["Undated", "Three days back", "Walk"])
        #expect(left.first { $0.text == "Undated" }?.day == name(0), "today's from here, then its own day's")
        #expect(left.first { $0.text == "Walk" }?.completedAt == nil)
        #expect(left.first { $0.text == "Three days back" }?.isEarlier(than: today) == true, "kept, waiting, unmarked")
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

    @Test("the row of days reads Today, Tomorrow, then the days by name")
    func scopeWords() {
        #expect(PlanScope.all.count == 8)
        #expect(PlanScope.day(0).title(from: today, calendar: calendar) == "Today")
        #expect(PlanScope.day(1).title(from: today, calendar: calendar) == "Tomorrow")
        #expect(PlanScope.day(2).title(from: today, calendar: calendar) == "Mon")
        #expect(PlanScope.day(2).spoken(from: today, calendar: calendar) == "for Monday")
        #expect(WhenRow.title(nil) == "Now" && WhenRow.title(.day(0)) == "Later")
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
        #expect(body.contains("PlannedOutlines("))
        #expect(!body.contains("PlacedBlock(") && !body.contains("buildTower"))
        let outline = SourceSweep.code(try SourceSweep.read("Strata/Views/PlannedBlocks.swift"))
        // No colour, rim, band or shadow: the slot's own glass.
        #expect(outline.contains(".glassSlot(cornerRadius:"))
        for mark in ["BlockSurface", "styleFor", ".shadow(", "category.style", "EtherealFill"] {
            #expect(!outline.contains(mark), "\(mark) would make an outline a block")
        }
    }
}
