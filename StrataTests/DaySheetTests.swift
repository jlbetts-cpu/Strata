import Testing
import Foundation
import SwiftData
import SwiftUI
@testable import Strata

/// **One page for the day** (owner-approved, 2026-10-05): "the plan and
/// journal screen could probably be merged like a place where you can jot
/// down the day while also planning the day there uis are pretty similar...
/// the plan stuff obviously wouldnt show up in the final journal entry."
///
/// Pinned here: the plan never reaches the saved note, the Wins header has
/// one button where it had two, which parts a day shows, which part Suggest
/// serves, and the thinner pen.
@MainActor
@Suite("The day's page")
struct DaySheetTests {

    private func context() throws -> ModelContext {
        ModelContext(try ModelContainer(for: Habit.self, HabitLog.self, MoodLog.self, Tower.self, PlanItem.self,
                                        configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    // MARK: - The plan stays out of the note

    /// "the plan stuff obviously wouldnt show up in the final journal entry".
    /// The page writes the note through `DaySheet.keep`, and what lands in
    /// `MoodLog.note` is the note's words and nothing of the plan's.
    @Test("saving the day's page writes only the note: no plan line reaches the entry")
    func planStaysOutOfTheNote() throws {
        let ctx = try context()
        let lines = ["Run the loop", "Send the invoice"]
        for (i, text) in lines.enumerated() {
            ctx.insert(PlanItem(text: text, order: i))
        }
        try ctx.save()
        DaySheet.keep(note: "Long walk by the river", symbol: "🌊", for: "2026-10-05", context: ctx)
        let entry = try #require(DayNotes.entry(for: "2026-10-05", context: ctx))
        #expect(entry.note == "Long walk by the river")
        for line in lines {
            #expect(!(entry.note ?? "").contains(line), "a plan line leaked into the journal entry")
        }
        // The plan is still the plan: nothing was moved or copied out of it.
        #expect(try ctx.fetchCount(FetchDescriptor<PlanItem>()) == lines.count)
    }

    @Test("a day with plan lines and no note writes no journal entry at all")
    func aPlanAloneIsNoEntry() throws {
        let ctx = try context()
        ctx.insert(PlanItem(text: "Call the landlord", order: 0))
        try ctx.save()
        DaySheet.keep(note: "", symbol: nil, for: "2026-10-05", context: ctx)
        #expect(try ctx.fetchCount(FetchDescriptor<MoodLog>()) == 0,
                "planning a day must not make that day look written")
    }

    /// And structurally: the page's save reads the note, never the plan. A
    /// sweep of the function body, so a future "include the plan" cannot slip
    /// in through a helper the test above does not drive.
    @Test("the page's save never reads the plan")
    func saveDoesNotReadThePlan() throws {
        let text = try MorningSource.read("Views/DaySheet.swift")
        let body = try #require(text.components(separatedBy: "static func keep(").dropFirst().first)
        let fn = body.components(separatedBy: "\n    }").first ?? ""
        #expect(fn.contains("DayNotes.save("))
        #expect(!fn.contains("PlanItem"), "the note's save reads the plan")
        #expect(!fn.contains(".text"), "the note's save reads a plan line's text")
    }

    @Test("the sweep catches a save that copies the plan in")
    func saveSweepCanFail() {
        // The injection: what the sweep above must refuse.
        let bad = "note: (items.map { $0.text } + [note]).joined()"
        #expect(bad.contains(".text"))
    }

    // MARK: - Which parts a day shows

    /// Plan lines are forward-looking: the overnight sweep deletes a finished
    /// one-off and unticks a repeat (`PlanItem.sweep`), so a past day keeps no
    /// record of what was planned. The simplest honest page for a past day
    /// is the note alone.
    @Test("today shows the plan and the note; a past day shows only the note")
    func parts() {
        #expect(DayParts.forDay(isToday: true, noteOpen: true) == DayParts(plan: true, note: true))
        #expect(DayParts.forDay(isToday: false, noteOpen: true) == DayParts(plan: false, note: true))
    }

    /// Lock Journal guards the note, not the plan: a refused Face ID on Wins
    /// still opens the day's plan, with the note left out.
    @Test("a locked journal keeps the note out and still opens the plan")
    func lockedNote() {
        #expect(DayParts.forDay(isToday: true, noteOpen: false) == DayParts(plan: true, note: false))
        #expect(DayParts.forDay(isToday: false, noteOpen: false) == DayParts(plan: false, note: false))
    }

    // MARK: - One Suggest, serving the part you are in

    @Test("Suggest serves the part that last had focus")
    func suggestFollowsFocus() {
        let both = DayParts(plan: true, note: true)
        #expect(SuggestTarget.initial(parts: both) == .plan, "the plan is first on the page")
        #expect(SuggestTarget.after(focus: .note, current: .plan, parts: both) == .note)
        #expect(SuggestTarget.after(focus: .plan, current: .note, parts: both) == .plan)
        // Losing focus keeps the last part, so the button does not flicker
        // while the keyboard goes down.
        #expect(SuggestTarget.after(focus: nil, current: .note, parts: both) == .note)
    }

    @Test("a past day's Suggest only ever asks the journal question")
    func pastDaySuggestsTheQuestion() {
        let note = DayParts(plan: false, note: true)
        #expect(SuggestTarget.initial(parts: note) == .note)
        #expect(SuggestTarget.after(focus: .plan, current: .note, parts: note) == .note)
        let plan = DayParts(plan: true, note: false)
        #expect(SuggestTarget.initial(parts: plan) == .plan)
        #expect(SuggestTarget.after(focus: .note, current: .plan, parts: plan) == .plan)
    }

    @Test("the page draws one Suggest control, never two")
    func oneSuggest() throws {
        let text = SourceSweep.code(try MorningSource.read("Views/DaySheet.swift"))
        #expect(text.components(separatedBy: "Label(\"Suggest\"").count - 1 <= 1,
                "the day's page draws its own Suggest more than once")
        // The plan's Suggest and the journal's are chosen between in one
        // switch, never stacked.
        #expect(text.contains("switch suggestTarget"))
    }

    // MARK: - The Wins header: one button where there were two

    /// **One glass button, top left, `checklist`** (the owner's pick,
    /// 2026-10-05), replacing the Journal and Plan pair, because they are one
    /// page now. Crews stays alone at the trailing end, for the three reasons
    /// `WinsBatchTests.headerOrder` records.
    @Test("the Wins header leads with one day button and Crews trails alone")
    func oneHeaderButton() throws {
        let text = try MorningSource.read("Views/MainAppView.swift")
        let header = text.components(separatedBy: "private var towerHeader: some View {").last ?? ""
        let row = header.components(separatedBy: ".accessibilityElement(children: .contain)").first ?? ""
        let day = try #require(row.range(of: "headerDay"))
        let spacer = try #require(row.range(of: "Spacer(minLength: 0)"))
        let crews = try #require(row.range(of: "CrewsButton"))
        #expect(day.lowerBound < spacer.lowerBound && spacer.lowerBound < crews.lowerBound)
        #expect(!row.contains("HeaderGlassPair"), "the pair is back: the day is one page and one button")
        #expect(!row.contains("JournalButton("), "a second button for the journal is back on Wins")
        #expect(!row.contains("headerPlan"), "a second button for the plan is back on Wins")
        let button = header.components(separatedBy: "private var headerDay: some View {").dropFirst().first ?? ""
        #expect(button.contains("systemName: DayIcon.name"))
        #expect(DayIcon.name == "checklist", "the owner's pick for the day's button")
    }
}
