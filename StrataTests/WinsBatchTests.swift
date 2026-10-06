import Testing
import Foundation
import SwiftData
import SwiftUI
@testable import Strata

/// **The Wins batch, 2026-10-05**: the header pair, the journal's dot, Suggest
/// after writing, swipe to delete on the plan, the first-win invite and an
/// onboarding that ends on a real win. The logic of each, pinned here; the
/// look of each is in the screenshots the batch was checked against.
@MainActor
@Suite("Wins batch")
struct WinsBatchTests {

    // MARK: - 1. The header

    /// **Mine on the left, the crew on the right** (owner-approved,
    /// 2026-10-05). Journal then Plan, one glass pair, top left; Crews alone,
    /// top right. Why the right: the HIG puts what must stay available at the
    /// trailing end, Instagram and Strava put the chat and notification
    /// entry points top right, and a right thumb reaches the top right more
    /// easily than the top left (Hoober).
    @Test("Journal and Plan lead as one pair, Crews stands alone at the trailing end")
    func headerOrder() throws {
        let text = try MorningSource.read("Views/MainAppView.swift")
        let header = text.components(separatedBy: "private var towerHeader: some View {").last ?? ""
        let row = header.components(separatedBy: ".accessibilityElement(children: .contain)").first ?? ""
        let journal = try #require(row.range(of: "JournalButton("))
        let plan = try #require(row.range(of: "headerPlan"))
        let spacer = try #require(row.range(of: "Spacer(minLength: 0)"))
        let crews = try #require(row.range(of: "CrewsButton"))
        #expect(journal.lowerBound < plan.lowerBound, "Journal is the far left, Plan inner")
        #expect(plan.lowerBound < spacer.lowerBound, "the pair leads the row")
        #expect(spacer.lowerBound < crews.lowerBound, "Crews is alone at the trailing end")
        #expect(row.contains("HeaderGlassPair"), "the pair is one glass group")
    }

    /// The pair shares one `GlassEffectContainer`, and its blend distance is
    /// under the gap between the two discs, so they never fuse into the
    /// peanut a group made of them on 2026-10-02.
    @Test("the glass pair never fuses: blend distance under the gap")
    func pairDoesNotFuse() {
        #expect(HeaderGlassPair<EmptyView>.blend < HeaderGlassPair<EmptyView>.gap)
        #expect(HeaderGlassPair<EmptyView>.gap == GridConstants.gapTight)
    }

    // MARK: - 2. The journal's mark

    @Test("an emoji shows the emoji and nothing else")
    func emojiAlone() {
        #expect(JournalMark.forDay(symbol: "🌊", written: true) == .emoji("🌊"))
        #expect(JournalMark.forDay(symbol: "🌊", written: false) == .emoji("🌊"))
    }

    @Test("a note with no emoji is a dot in the emoji's corner")
    func noteIsADot() {
        #expect(JournalMark.forDay(symbol: nil, written: true) == .dot)
        #expect(JournalMark.forDay(symbol: "", written: true) == .dot, "an empty emoji is no emoji")
    }

    @Test("nothing written is nothing drawn")
    func nothingIsNothing() {
        #expect(JournalMark.forDay(symbol: nil, written: false) == .none)
    }

    @Test("Lock Journal hides the dot the way it hides the emoji")
    func lockHidesBoth() {
        #expect(JournalMark.forDay(symbol: nil, written: true, hidden: true) == .none)
        #expect(JournalMark.forDay(symbol: "🔥", written: true, hidden: true) == .none)
    }

    @Test("the journal button: a dot on a day's page with a note, never on Wins, never locked")
    func buttonDot() {
        #expect(JournalMark.buttonShowsDot(hasNote: true, hidden: false, onDayPage: true))
        #expect(!JournalMark.buttonShowsDot(hasNote: false, hidden: false, onDayPage: true))
        #expect(!JournalMark.buttonShowsDot(hasNote: true, hidden: true, onDayPage: true))
        #expect(!JournalMark.buttonShowsDot(hasNote: true, hidden: false, onDayPage: false),
                "only Crews carries a dot on the Wins header")
    }

    @Test("the calendar's mark comes from the seeded month, emoji days and note-only days apart")
    func calendarMarksFromTheStore() throws {
        let ctx = ModelContext(try ModelContainer(for: Habit.self, HabitLog.self, MoodLog.self, Tower.self,
                                                  configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        DayNotes.save(note: "Long walk", symbol: "🌊", for: "2026-10-05", context: ctx)
        DayNotes.save(note: "Just words", symbol: nil, for: "2026-10-06", context: ctx)
        let marks = DayNotes.marks(from: "2026-10-01", to: "2026-11-01", context: ctx)
        func mark(_ day: String) -> JournalMark {
            JournalMark.forDay(symbol: marks.symbols[day], written: marks.written.contains(day))
        }
        #expect(mark("2026-10-05") == .emoji("🌊"))
        #expect(mark("2026-10-06") == .dot)
        #expect(mark("2026-10-07") == .none)
    }

    // MARK: - 3. Suggest after writing

    @Test("on an empty note the question becomes the first line, and the caret follows it")
    func insertIntoEmpty() {
        let out = JournalSuggestInsert.inserting("What made today good?", into: "")
        #expect(out.text == "What made today good?\n")
        #expect(out.caret == out.text.endIndex)
    }

    @Test("under written words: a blank line, the question as a heading, a new line, the caret")
    func insertUnderText() {
        let out = JournalSuggestInsert.inserting("Who made today better?", into: "Long walk by the river.")
        #expect(out.text == "Long walk by the river.\n\nWho made today better?\n")
        #expect(out.caret == out.text.endIndex)
    }

    @Test("trailing blank lines are folded, so the heading never drifts down the page")
    func insertFoldsTrailingSpace() {
        let out = JournalSuggestInsert.inserting("What would you do again?", into: "Ran.\n\n\n  ")
        #expect(out.text == "Ran.\n\nWhat would you do again?\n")
    }

    @Test("it inserts the question and never an answer")
    func neverAnAnswer() {
        let note = "Finished the draft."
        let question = "What are you glad you did?"
        let out = JournalSuggestInsert.inserting(question, into: note)
        let added = String(out.text.dropFirst(note.count))
        #expect(added.trimmingCharacters(in: .whitespacesAndNewlines) == question)
        // The question is cut at its question mark before it ever gets here
        // (`JournalQuestionRules.clean`); an answer smuggled after one is
        // still not written.
        let smuggled = JournalSuggestInsert.inserting("What made today good? The walk.", into: note)
        #expect(!smuggled.text.contains("The walk"))
    }

    // MARK: - 4. Swipe to delete on the plan

    @Test("a short swipe springs back, a half swipe opens Delete, a long one deletes")
    func swipeOutcomes() {
        let width: CGFloat = 370
        #expect(PlanSwipe.outcome(translation: -20, velocity: 0, rowWidth: width, wasOpen: false) == .closed)
        #expect(PlanSwipe.outcome(translation: -60, velocity: 0, rowWidth: width, wasOpen: false) == .open)
        #expect(PlanSwipe.outcome(translation: -230, velocity: 0, rowWidth: width, wasOpen: false) == .delete)
        #expect(PlanSwipe.outcome(translation: -30, velocity: -900, rowWidth: width, wasOpen: false) == .open,
                "a flick opens it")
        #expect(PlanSwipe.outcome(translation: 60, velocity: 0, rowWidth: width, wasOpen: true) == .closed,
                "swiped back, it closes")
        #expect(PlanSwipe.outcome(translation: -10, velocity: 900, rowWidth: width, wasOpen: true) == .closed)
    }

    @Test("the row only moves left, and gives a little past its rest")
    func swipeOffset() {
        #expect(PlanSwipe.offset(translation: -50, wasOpen: false) == -50)
        #expect(PlanSwipe.offset(translation: 40, wasOpen: false) < 10, "rubber-banded to the right")
        #expect(PlanSwipe.offset(translation: 0, wasOpen: true) == -PlanSwipe.revealWidth)
    }

    @Test("deleting a line removes it from the store and leaves the rest in order")
    func deleteLine() throws {
        let ctx = ModelContext(try ModelContainer(for: PlanItem.self,
                                                  configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let a = PlanItem(text: "Call Mum", order: 0)
        let b = PlanItem(text: "Gym", order: 1)
        let c = PlanItem(text: "Read", order: 2)
        [a, b, c].forEach(ctx.insert)
        try ctx.save()
        PlanItem.remove(b, context: ctx)
        let left = try ctx.fetch(FetchDescriptor<PlanItem>(sortBy: [SortDescriptor(\.order)]))
        #expect(left.map(\.text) == ["Call Mum", "Read"])
    }

    /// **A repeating line goes whole.** `PlanItem` is one row with its days,
    /// and there is no per-day exception to hold "just this one", so the
    /// model does not support the choice the dialog would offer, and the
    /// batch's rule is then to just delete.
    @Test("a repeating line deletes outright: the model has no single occurrence to skip")
    func deleteRepeat() throws {
        let ctx = ModelContext(try ModelContainer(for: PlanItem.self,
                                                  configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let line = PlanItem(text: "Stretch", order: 0)
        line.repeatDays = [2, 3, 4, 5, 6]
        ctx.insert(line)
        try ctx.save()
        #expect(!PlanItem.supportsSingleOccurrenceDelete)
        PlanItem.remove(line, context: ctx)
        #expect(try ctx.fetchCount(FetchDescriptor<PlanItem>()) == 0)
    }

    // MARK: - 5. The first-win invite

    /// A scratch defaults suite, and its removal: the test host is the app,
    /// so a suite left behind is a file in the app's own Preferences.
    private func freshDefaults() -> (UserDefaults, () -> Void) {
        let name = "wins-batch-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return (d, { d.removePersistentDomain(forName: name) })
    }

    @Test("after the very first win, once, and only with crews on")
    func afterFirstWin() {
        let (d, done) = freshDefaults()
        defer { done() }
        #expect(!FirstWinInvite.shouldShow(.firstWin, winsEver: 1, crewsOn: false, age: .adult, defaults: d))
        #expect(!FirstWinInvite.shouldShow(.firstWin, winsEver: 2, crewsOn: true, age: .adult, defaults: d),
                "not a first win: an existing tower never sees it")
        #expect(FirstWinInvite.shouldShow(.firstWin, winsEver: 1, crewsOn: true, age: .adult, defaults: d))
        FirstWinInvite.markShown(.firstWin, defaults: d)
        #expect(!FirstWinInvite.shouldShow(.firstWin, winsEver: 1, crewsOn: true, age: .adult, defaults: d),
                "once")
    }

    @Test("once more after the first reaction received, then never again")
    func afterFirstReaction() {
        let (d, done) = freshDefaults()
        defer { done() }
        #expect(!FirstWinInvite.shouldShow(.firstReaction, crewsOn: true, age: .adult, defaults: d),
                "never before the first-win one")
        FirstWinInvite.markShown(.firstWin, defaults: d)
        #expect(FirstWinInvite.shouldShow(.firstReaction, crewsOn: true, age: .adult, defaults: d))
        FirstWinInvite.markShown(.firstReaction, defaults: d)
        #expect(!FirstWinInvite.shouldShow(.firstReaction, crewsOn: true, age: .adult, defaults: d))
        #expect(!FirstWinInvite.shouldShow(.firstWin, winsEver: 1, crewsOn: true, age: .adult, defaults: d))
    }

    @Test("never to under-13s")
    func neverUnderThirteen() {
        let (d, done) = freshDefaults()
        defer { done() }
        #expect(!FirstWinInvite.shouldShow(.firstWin, winsEver: 1, crewsOn: true, age: .under13, defaults: d))
        FirstWinInvite.markShown(.firstWin, defaults: d)
        #expect(!FirstWinInvite.shouldShow(.firstReaction, crewsOn: true, age: .under13, defaults: d))
        // Everyone else who can open crews may see it.
        for age in [CrewAge.unknown, .teen, .adult, .declined] {
            #expect(FirstWinInvite.shouldShow(.firstReaction, crewsOn: true, age: age, defaults: d))
        }
    }

    @Test("a reaction counts only when someone else reacted to a win you sent")
    func receivedReaction() {
        let me = UUID(), friend = UUID()
        let crew = CrewID.new()
        let mine = SharedWin.fixture(sender: me, crew: crew)
        let theirs = SharedWin.fixture(sender: friend, crew: crew)
        let wins = [crew: [mine, theirs]]
        func reaction(by who: UUID, to win: SharedWin) -> Reaction {
            Reaction(winID: win.winID, crewID: crew, profileID: who, emoji: "❤️", createdAt: Date())
        }
        #expect(!FirstWinInvite.hasReceivedReaction(wins: wins, reactions: [:], me: me))
        #expect(!FirstWinInvite.hasReceivedReaction(wins: wins, reactions: [crew: [reaction(by: me, to: mine)]], me: me),
                "your own reaction is not received")
        #expect(!FirstWinInvite.hasReceivedReaction(wins: wins, reactions: [crew: [reaction(by: me, to: theirs)]], me: me),
                "one you gave a friend is not received")
        #expect(FirstWinInvite.hasReceivedReaction(wins: wins, reactions: [crew: [reaction(by: friend, to: mine)]], me: me))
    }

    @Test("the prompt's words")
    func inviteWords() {
        #expect(FirstWinInvite.line == "Your win is up. Who else should see it?")
        #expect(!FirstWinInvite.line.contains("—") && !FirstWinInvite.line.contains("–"))
    }

    // MARK: - 6. Onboarding ends on a real win

    @Test("the example chips are the five, and a chip is a title")
    func chips() {
        #expect(OnboardingFirstWin.examples == [
            "Made the bed", "Drank water", "Replied to that email", "Went outside", "Called someone",
        ])
    }

    @Test("finishing onboarding logs the chosen win through the normal path, once")
    func finishesWithARealWin() throws {
        let (d, done) = freshDefaults()
        defer { done() }
        let container = try ModelContainer(for: Habit.self, HabitLog.self, Tower.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true,
                                                                              cloudKitDatabase: .none))
        let ctx = ModelContext(container)
        let tower = Tower(name: "Mine")
        ctx.insert(tower)
        try ctx.save()

        OnboardingFirstWin.queue(title: "Made the bed", size: .small, colour: .health, defaults: d)
        #expect(OnboardingFirstWin.isPending(defaults: d))
        let landed = try #require(OnboardingFirstWin.land(context: ctx, tower: tower, defaults: d))
        #expect(landed.title == "Made the bed")
        #expect(landed.tower?.id == tower.id, "on the active tower, where the Wins tab will show it")
        let logs = try ctx.fetch(FetchDescriptor<HabitLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.dateString == DateUtils.dateString(from: Date()))
        #expect(!OnboardingFirstWin.isPending(defaults: d))
        // Never twice: the app's first act, doubled, is the one thing this
        // must not do.
        #expect(OnboardingFirstWin.land(context: ctx, tower: tower, defaults: d) == nil)
        #expect(try ctx.fetchCount(FetchDescriptor<HabitLog>()) == 1)
    }

    @Test("a win with no words is a block with no words, never \"Welcome\"")
    func untitledFirstWin() throws {
        let (d, done) = freshDefaults()
        defer { done() }
        let ctx = ModelContext(try ModelContainer(for: Habit.self, HabitLog.self, Tower.self,
                                                  configurations: ModelConfiguration(isStoredInMemoryOnly: true,
                                                                                     cloudKitDatabase: .none)))
        OnboardingFirstWin.queue(title: "   ", size: .medium, colour: .work, defaults: d)
        let landed = try #require(OnboardingFirstWin.land(context: ctx, tower: nil, defaults: d))
        #expect(landed.title != "Welcome")
        #expect(landed.blockSize == .medium)
    }
}

extension SharedWin {
    /// A minimal shared win for the invite's reaction rule.
    static func fixture(sender: UUID, crew: CrewID) -> SharedWin {
        SharedWin(winID: UUID(), crewID: crew, senderProfileID: sender, crewDay: "2026-10-05",
                  title: "Ran", colour: .health, icon: .unlabeled, blockSize: .small, photo: nil,
                  cropX: nil, cropY: nil, createdAt: Date(), updatedAt: Date())
    }
}
