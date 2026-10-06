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
/// **Then one sheet with two tabs** (the owner, 2026-10-05, on seeing the
/// merged page: "everything looks a bit weird"). His choice: still one button
/// on Wins, a Plan tab and a Journal tab under the title, each with its own
/// Suggest, opening on the tab used last.
///
/// Pinned here: the plan never reaches the saved note, the Wins header has
/// one button where it had two, which tabs a day offers and which it opens
/// on, that each tab has its own Suggest, and the switch's plain words.
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

    /// **And a plan line written on the Plan tab never reaches the Journal.**
    /// Re-asked for the tabs (2026-10-05): the two tabs share one sheet and
    /// one save, so the save is driven with a plan line whose words are also
    /// the note's neighbour, and the Plan tab's body is swept for any write
    /// to the entry at all.
    @Test("the Plan tab never writes the journal entry, and a plan line never lands in the note")
    func planTabNeverWritesTheNote() throws {
        let ctx = try context()
        ctx.insert(PlanItem(text: "Book the dentist", order: 0))
        try ctx.save()
        DaySheet.keep(note: "Quiet morning", symbol: nil, for: "2026-10-05", context: ctx)
        DaySheet.keep(note: "Quiet morning, then the park", symbol: nil, for: "2026-10-05", context: ctx)
        let entry = try #require(DayNotes.entry(for: "2026-10-05", context: ctx))
        #expect(entry.note == "Quiet morning, then the park")
        #expect(!(entry.note ?? "").contains("Book the dentist"), "a plan line leaked into the journal entry")

        let text = SourceSweep.code(try MorningSource.read("Views/DaySheet.swift"))
        let plan = try #require(text.components(separatedBy: "private var planTab: some View {").dropFirst().first)
        let body = plan.components(separatedBy: "private var journalTab: some View {").first ?? ""
        #expect(!body.isEmpty)
        for write in ["save()", "keep(note:", "DayNotes."] {
            #expect(!body.contains(write), "the Plan tab writes the journal entry through \(write)")
        }
    }

    // MARK: - Which tabs a day offers

    /// Was "today shows the plan and the note; a past day shows only the
    /// note" (`DayParts`), re-aimed at the tabs. Plan lines are
    /// forward-looking: the overnight sweep deletes a finished one-off and
    /// unticks a repeat (`PlanItem.sweep`), so a past day keeps no record of
    /// what was planned. The simplest honest sheet for a past day is the
    /// Journal alone, with no switch, as it was before the tabs.
    @Test("Wins offers Plan and Journal with a switch; a past day is the Journal alone, with none")
    func pastDaysShowJournalOnly() throws {
        #expect(DayTabSet.wins.tabs == [.plan, .journal])
        #expect(DayTabSet.wins.showsSwitch)
        #expect(DayTabSet.pastDay.tabs == [.journal])
        #expect(!DayTabSet.pastDay.showsSwitch, "a past day shows the Plan and Journal switch")
        // Whatever the last tab was, a past day opens on its Journal.
        #expect(DayTabSet.pastDay.opening(.plan) == .journal)
        #expect(DayTabSet.pastDay.opening(.journal) == .journal)
        #expect(DayTabSet.wins.opening(.journal) == .journal)

        // Both past-day pages reach the sheet through `JournalButton`, and it
        // asks for the past day's set, never the Wins one.
        let sheet = try MorningSource.read("Views/DaySheet.swift")
        let button = try #require(sheet.components(separatedBy: "struct JournalButton: View {").dropFirst().first)
        let open = button.components(separatedBy: "struct JournalToolbarItem").first ?? ""
        #expect(open.contains("DaySheet(dateString: dateString, tabs: .pastDay)"))
        #expect(!open.contains(".wins"), "a past day's journal opens with the Plan tab")
        let page = try MorningSource.read("Views/DayAlbumDetailView.swift")
        #expect(page.contains("JournalToolbarItem("), "a past day no longer opens its journal through the button")
        #expect(!page.contains("DaySheet("), "a past day builds the day's sheet itself")
        // A crew's day has no journal at all (the owner, 2026-10-06: "that
        // shouldnt be there at all only in memories").
        let crewDay = SourceSweep.code(try MorningSource.read("Views/Crews/CrewDayView.swift"))
        #expect(!crewDay.contains("JournalToolbarItem("), "a crew's day shows your journal button again")
        #expect(!crewDay.contains("DaySheet("))
    }

    /// Was "a locked journal keeps the note out and still opens the plan",
    /// re-aimed: Lock Journal guards the Journal tab, never the Plan. A
    /// refused Face ID on the way in opens the Plan tab instead.
    @Test("a locked Journal opens the sheet on the Plan; the Plan never asks")
    func lockedJournalOpensThePlan() throws {
        #expect(DayTabs.opening(stored: "journal", journalMayOpen: false) == .plan)
        #expect(DayTabs.opening(stored: "journal", journalMayOpen: true) == .journal)
        #expect(DayTabs.opening(stored: "plan", journalMayOpen: false) == .plan)
        // Structurally: the switch asks the lock for the Journal only.
        let text = SourceSweep.code(try MorningSource.read("Views/DaySheet.swift"))
        let choose = try #require(text.components(separatedBy: "private func choose(").dropFirst().first)
        let fn = choose.components(separatedBy: "private func show(").first ?? ""
        // Only a Journal that is still hidden waits on the lock; everything
        // else switches at once, so a later tap cannot be overtaken by an
        // unlock answering late (2026-10-05).
        #expect(fn.contains("guard next == .journal, JournalLock.shared.hidesWriting else {"))
        #expect(fn.contains("ticket == choices"),
                "a Journal unlock that answers after a later tap overrides it")
        #expect(fn.components(separatedBy: "JournalLock.shared.unlock()").count - 1 == 1,
                "the switch asks for Face ID somewhere other than the Journal")
        let main = SourceSweep.code(try MorningSource.read("Views/MainAppView.swift"))
        let openDay = try #require(main.components(separatedBy: "private func openDay() {").dropFirst().first)
        #expect(openDay.contains("wants == .journal ? await JournalLock.shared.unlock() : true"),
                "the Plan tab waits on Face ID")
    }

    // MARK: - The tab used last

    /// "From Wins, the sheet opens on the tab used last (`@AppStorage`,
    /// default Plan)." The round trip through real defaults, and the source
    /// check that the sheet and Wins share the one key.
    @Test("the sheet opens on the tab used last, and on the Plan the first time")
    func tabPersists() throws {
        let suite = "DaySheetTests.tabPersists.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(DayTabs.last(in: defaults) == .plan, "the first open is not the Plan")
        DayTabs.remember(.journal, in: defaults)
        #expect(DayTabs.last(in: defaults) == .journal)
        DayTabs.remember(.plan, in: defaults)
        #expect(DayTabs.last(in: defaults) == .plan)
        // Something unreadable stored there is the Plan, never a crash.
        defaults.set("diary", forKey: DayTabs.defaultsKey)
        #expect(DayTabs.last(in: defaults) == .plan)
        #expect(DayTabs.stored(nil) == .plan)

        let sheet = SourceSweep.code(try MorningSource.read("Views/DaySheet.swift"))
        #expect(sheet.contains("@AppStorage(DayTabs.defaultsKey) private var lastTab = DayTab.plan.rawValue"))
        let show = try #require(sheet.components(separatedBy: "private func show(").dropFirst().first)
        #expect((show.components(separatedBy: "private var planTab: some View {").first ?? "").contains("lastTab = next.rawValue"),
                "a switch is not remembered")
        let main = SourceSweep.code(try MorningSource.read("Views/MainAppView.swift"))
        #expect(main.contains("@AppStorage(DayTabs.defaultsKey) private var lastDayTab = DayTab.plan.rawValue"))
        #expect(main.contains("tabs: .wins, opening: dayOpeningTab"))
    }

    // MARK: - Each tab has its own Suggest

    /// Was "Suggest serves the part that last had focus" (`SuggestTarget`).
    /// The owner, 2026-10-05: each tab has its own Suggest, and the focus
    /// switching is gone because nothing is left to switch between.
    @Test("each tab has its own Suggest, and the focus-switching is gone")
    func eachTabHasItsOwnSuggest() throws {
        let text = SourceSweep.code(try MorningSource.read("Views/DaySheet.swift"))
        #expect(!text.contains("SuggestTarget"), "the focus-switching Suggest is back")
        #expect(!text.contains("switch suggestTarget"))
        let plan = try #require(text.components(separatedBy: "private var planTab: some View {").dropFirst().first)
        let planBody = plan.components(separatedBy: "private var journalTab: some View {").first ?? ""
        #expect(planBody.contains("PlanSuggestionsView("), "the Plan tab lost its Suggest")
        #expect(!planBody.contains("journalSuggest"), "the journal's Suggest is on the Plan tab")
        let foot = try #require(text.components(separatedBy: "private var journalFoot: some View {").dropFirst().first)
        let footBody = foot.components(separatedBy: "private var todaysLines").first ?? ""
        #expect(footBody.contains("journalSuggest"))
        #expect(footBody.contains("systemName: \"pencil\""), "the pen left the Journal's foot")
        #expect(!footBody.contains("PlanSuggestionsView"), "the plan's Suggest is on the Journal tab")
    }

    @Test("a past day's Suggest only ever asks the journal question")
    func pastDaySuggestsTheQuestion() {
        // The Plan tab, and with it the plan's Suggest, is not on a past day.
        #expect(!DayTabSet.pastDay.tabs.contains(.plan))
    }

    @Test("each tab draws one Suggest control, never two")
    func oneSuggest() throws {
        let text = SourceSweep.code(try MorningSource.read("Views/DaySheet.swift"))
        #expect(text.components(separatedBy: "Label(\"Suggest\"").count - 1 <= 1,
                "the journal draws its own Suggest more than once")
        #expect(text.components(separatedBy: "PlanSuggestionsView(").count - 1 == 1,
                "the plan's Suggest is drawn more than once")
    }

    // MARK: - The switch

    /// **Two plain words, side by side, centred** (the owner, 2026-10-05):
    /// the chosen one in ink at the heading weight, the other faint; no
    /// capsule, no glass, no segmented control; a cross-fade on the motion
    /// tokens and a light haptic; 44pt targets; a tab bar for VoiceOver.
    @Test("the switch is two plain words: no capsule, no glass, no segmented control")
    func switchIsTwoWords() throws {
        #expect(DayTab.allCases.map(\.title) == ["Plan", "Journal"])
        let text = SourceSweep.code(try MorningSource.read("Views/DaySheet.swift"))
        let start = try #require(text.components(separatedBy: "private var tabSwitch: some View {").dropFirst().first)
        let body = start.components(separatedBy: "private func choose(").first ?? ""
        for chrome in ["Capsule", "glass", "Glass", "Picker", ".segmented", "background(", "Divider", "Rectangle().fill"] {
            #expect(!body.contains(chrome), "the switch draws \(chrome)")
        }
        #expect(body.contains("chosen ? AppColors.inkPrimary : AppColors.inkTertiary"))
        // Both words the title's size and weight since the tabs became the
        // title (2026-10-05: "the tabs i feel like look a little off"); only
        // the ink says which is chosen.
        #expect(body.contains(".font(Typography.headerMedium)"),
                "the two words are no longer one size and weight")
        #expect(!body.contains("chosen ? Typography."),
                "the chosen word changes size or weight again")
        #expect(body.contains("minWidth: Self.tapTarget, minHeight: Self.tapTarget"))
        #expect(body.contains(".isTabBar"))
        #expect(body.contains(".isSelected"))
        let show = try #require(text.components(separatedBy: "private func show(").dropFirst().first)
        let fn = show.components(separatedBy: "private var planTab: some View {").first ?? ""
        #expect(fn.contains("withAnimation(GridConstants.crossFade)"))
        #expect(fn.contains("HapticsEngine.tick()"))
    }

    @Test("the switch sweep catches a capsule behind the words")
    func switchSweepCanFail() {
        // The injection: a segmented look the sweep above must refuse.
        let bad = ".background(Capsule().fill(AppColors.quietFill))"
        #expect(bad.contains("Capsule") && bad.contains("background("))
    }

    /// Top left is the Journal's emoji, and nothing on the Plan: the ＋ the
    /// owner asked for on 2026-10-05 ("just have the + button on the top
    /// left") became the Plan's bar at the foot on 2026-10-06, when he picked
    /// "Composer for both" from the crew chat's design. Two ways to start a
    /// line would be one too many.
    @Test("top left is the Journal's emoji, and the Plan adds from its bar")
    func leadingButtonPerTab() throws {
        let text = SourceSweep.code(try MorningSource.read("Views/DaySheet.swift"))
        #expect(text.contains("DaySheetToolbar(leading: leadingButton, done: done)"))
        let leading = try #require(text.components(separatedBy: "private var leadingButton: some View {").dropFirst().first)
        let fn = leading.components(separatedBy: "private var emojiButton").first ?? ""
        #expect(fn.contains("case .journal: emojiButton"))
        #expect(fn.contains("case .plan: EmptyView()"))
        #expect(!fn.contains("systemName: \"plus\""), "the ＋ is back beside the Plan's bar")
        #expect(!text.contains("planAdds"), "a second way to start a plan line is back")
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
