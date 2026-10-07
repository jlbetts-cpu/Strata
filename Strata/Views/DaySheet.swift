import PencilKit
import SwiftUI
import SwiftData

// MARK: - The button

/// **The journal's glyph, in one place.**
///
/// The spec asked for `book.closed`, filled when the day has a note. The
/// owner, on seeing it (2026-10-05): the glyph is HOLLOW, never filled, and
/// the book is off the app's theme. He then chose `text.alignleft`, at the
/// default weight. It is the glyph in a past day's corner; the Wins header
/// carries the whole day's sheet, Plan and Journal tabs, under `DayIcon`.
enum JournalIcon {
    static let name = "text.alignleft"
}

/// **The day's sheet, from Wins: one glass button, `checklist`** (the
/// owner's pick, 2026-10-05). It replaced the Journal and Plan pair when the
/// two became one sheet, now with a Plan tab and a Journal tab: one sheet,
/// one way in.
enum DayIcon {
    static let name = "checklist"
}

/// **The day's journal, one press from the day.** A glass button with
/// `JournalIcon.name` on it, hollow whether or not the day has a note (the
/// owner, 2026-10-05). VoiceOver still hears "Written" on a day that has one.
///
/// It stands in the top-right corner of a past day (a day's album, a crew's
/// day). It owns its sheet, the day's sheet (`DaySheet`) with the Journal tab
/// only and no switch, and it asks `JournalLock` first: with Lock Journal on,
/// a note opens only after Face ID or the passcode, once a session. On Wins
/// the day's sheet opens from `DayIcon` instead, with both tabs.
///
/// **Always there, never asking.** No badge and no reminder: once a week
/// beat three times a week in the research the spec cites, so the journal is
/// available and never requested.
///
/// **One dot, on a day's own page only** (the owner, 2026-10-05). On a past
/// day the glyph stays hollow and a tiny ink dot sits beside it when that day
/// has a note: the same dot the calendar puts in the emoji's corner, saying a
/// note is there, never asking for one. Not on Wins, where Crews is the only
/// thing that ever carries a dot (`JournalMark.buttonShowsDot`). Hidden while
/// Lock Journal is locked, as the emoji are.
struct JournalButton: View {
    let dateString: String
    /// True on a day's page, where a written day shows its dot.
    var marksNote: Bool = false

    @Query private var entries: [MoodLog]
    @State private var isOpen = false
    @AppStorage(JournalLock.defaultsKey) private var lockOn = false

    init(dateString: String, marksNote: Bool = false) {
        self.dateString = dateString
        self.marksNote = marksNote
        _entries = Query(filter: #Predicate<MoodLog> { $0.dateString == dateString })
    }

    private var hasNote: Bool { entries.contains(where: \.hasContent) }

    var body: some View {
        GlassIconButton(
            systemName: JournalIcon.name,
            onPage: true,
            accessibilityLabel: "Journal"
        ) {
            open()
        }
        // Inside the disc, up and to the right of the lines, so it reads as
        // part of the glyph ("written") rather than as a notification badge
        // on the glass's edge, which is what Crews' dot is.
        .overlay(alignment: .topTrailing) {
            if JournalMark.buttonShowsDot(hasNote: hasNote,
                                          hidden: lockOn && !JournalLock.shared.isUnlocked,
                                          onDayPage: marksNote) {
                JournalDot(ink: AppColors.inkPrimary)
                    // Clear of the glyph's top line by about 3pt, measured
                    // off the built button: at 10 and 7 it touched the
                    // line's end and read as a pin on it.
                    .padding(.top, 5)
                    .padding(.trailing, 5)
                    .transition(.opacity)
            }
        }
        // Not while Lock Journal is locked: "Written" is a fact about the
        // note, and the lock is for the note (the cohesion pass, 2026-10-05).
        .accessibilityValue(hasNote && !(lockOn && !JournalLock.shared.isUnlocked) ? "Written" : "")
        .sheet(isPresented: $isOpen) {
            // **A past day is the Journal alone, with no switch.** Plan lines
            // look forward: the overnight sweep deletes a finished one-off and
            // unticks a repeat (`PlanItem.sweep`), so the model keeps no
            // record of what a past day planned, and a Plan tab here would
            // show today's list under another day's title (`DayTabSet`).
            DaySheet(dateString: dateString, tabs: .pastDay)
        }
        #if DEBUG
        // `-strataOpenJournal day` on a past day (with `-strataOpenDay`).
        // `today` is the Wins header's, which `MainAppView` answers. A header
        // button is the one thing a screenshot script cannot press.
        .task {
            guard DebugHarness.openJournal == "day",
                  dateString != DateUtils.dateString(from: Date()) else { return }
            try? await Task.sleep(for: .milliseconds(900))
            open()
        }
        #endif
    }

    private func open() {
        Task {
            guard await JournalLock.shared.unlock() else { return }
            isOpen = true
        }
    }
}

/// The button in a navigation bar's trailing slot, for a pushed page.
///
/// Without the system's own glass behind it, for the reason `DaySheet`'s
/// toolbar records: a toolbar item on iOS 26 gets a capsule of its own, and a
/// glass button inside a glass capsule is two materials stacked.
struct JournalToolbarItem: ToolbarContent {
    let dateString: String

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarTrailing) { JournalButton(dateString: dateString, marksNote: true) }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarTrailing) { JournalButton(dateString: dateString, marksNote: true) }
        }
    }
}

// MARK: - The two tabs

/// **The day's sheet has two tabs, Plan and Journal** (the owner, 2026-10-05,
/// on seeing the merged page: "everything looks a bit weird"; his choice was
/// one sheet with two tabs rather than one mixed page). Still one button on
/// Wins (`DayIcon`); the switch is two plain words under the title.
enum DayTab: String, CaseIterable, Equatable {
    case plan, journal

    var title: String {
        switch self {
        case .plan: "Plan"
        case .journal: "Journal"
        }
    }
}

/// **Which tabs a sheet offers.** From Wins, both, with the switch. A past
/// day (`DayAlbumDetailView`, `CrewDayView`) is the Journal alone and shows
/// no switch: plan lines look forward, the overnight sweep deletes a finished
/// one-off and unticks a repeat (`PlanItem.sweep`), so the model keeps no
/// record of what a past day planned, and a Plan tab there would show
/// today's list under another day's title.
struct DayTabSet: Equatable {
    let tabs: [DayTab]

    var showsSwitch: Bool { tabs.count > 1 }

    /// The tab a sheet with this set opens on, given the one asked for: a
    /// past day's set has only the Journal, so it opens there whatever is
    /// asked.
    func opening(_ wanted: DayTab) -> DayTab {
        tabs.contains(wanted) ? wanted : (tabs.first ?? .journal)
    }

    static let wins = DayTabSet(tabs: [.plan, .journal])
    static let pastDay = DayTabSet(tabs: [.journal])
}

/// **The sheet opens on the tab used last** (`@AppStorage`, default Plan).
///
/// Lock Journal guards the Journal and never the Plan: when the last tab was
/// the Journal and Face ID is refused, the sheet opens on the Plan instead,
/// and the stored choice is left alone so the next open asks again.
enum DayTabs {
    /// The `@AppStorage` key `MainAppView` reads and `DaySheet` writes.
    nonisolated static let defaultsKey = "daySheetTab"

    /// The stored tab, Plan when nothing (or nothing readable) is stored.
    static func stored(_ raw: String?) -> DayTab {
        raw.flatMap(DayTab.init(rawValue:)) ?? .plan
    }

    /// The tab a sheet from Wins opens on.
    static func opening(stored raw: String?, journalMayOpen: Bool) -> DayTab {
        let tab = stored(raw)
        return tab == .journal && !journalMayOpen ? .plan : tab
    }

    /// The same two steps against any defaults, for the tests: what
    /// `@AppStorage(defaultsKey)` writes on a switch and reads at the next open.
    static func remember(_ tab: DayTab, in defaults: UserDefaults) {
        defaults.set(tab.rawValue, forKey: defaultsKey)
    }

    static func last(in defaults: UserDefaults) -> DayTab {
        stored(defaults.string(forKey: defaultsKey))
    }
}

// MARK: - The sheet

/// **The day, in one sheet with two tabs: Plan and Journal** (the owner,
/// 2026-10-05). It was one mixed page for an evening, the plan stacked over
/// the note with one Suggest serving whichever had focus; on seeing it he
/// said "everything looks a bit weird" and chose two tabs.
///
/// The chrome both tabs share: a large detent, the drag indicator, the
/// page's own ground as the sheet's material, the day as the title
/// (`DayTitle`), Done top right. Under the title, the switch: two plain
/// words, the chosen one in ink at the heading weight, the other faint. No
/// capsule, no glass, no segmented control.
///
/// - **Plan** is the plan exactly as the Plan screen was (`PlanLines`): the
///   checkboxes, swipe to delete, the long-press menu, "Add to the plan",
///   and the plan's own Suggest at the foot (`PlanSuggestionsView`). The top
///   left corner is empty.
/// - **Journal** is the journal as it was: the emoji's glass top left, the
///   note with the faded question under it and the sketch right under the
///   note, the journal's Suggest and the pen at the foot.
///
/// **The plan never reaches the note.** What is saved as the day's entry
/// (`MoodLog.note`) is the note's words and nothing else; `keep` is the one
/// write and it is handed the note alone (`DaySheetTests`).
///
/// **What it does not have**, each from the journal spec's "Do not build":
/// no streak, no reminder, no summary, no mood chart, no template, no tool
/// picker. The emoji is the day's symbol, not a score, so it has no scale.
struct DaySheet: View {
    let dateString: String
    let tabSet: DayTabSet
    /// A plan line's block pressed: the caller opens the add sheet.
    var onComplete: (PlanItem) -> Void = { _ in }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The tab on screen, and the one remembered for the next open from Wins.
    @State private var tab: DayTab
    @AppStorage(DayTabs.defaultsKey) private var lastTab = DayTab.plan.rawValue

    // The plan.
    @Query(sort: \PlanItem.order) private var allItems: [PlanItem]
    @Query private var habits: [Habit]
    @State private var planFocus: UUID?
    /// What is being typed in the Plan's bar (`DayComposer`). It shares the
    /// lines' focus: the bar owns the keyboard when `planFocus` is its id.
    @State private var planDraft = ""
    @State private var planComposerID = UUID()
    /// Counts tab choices; see `choose`.
    @State private var choices = 0

    // The journal.
    @State private var text = ""
    @State private var symbol: String?
    @State private var loaded = false
    @State private var picking = false
    /// The mark's picker (`StickerPicker`) is open.
    @State private var choosingMark = false
    /// New Sticker's photos, opened once the popover has gone.
    @State private var choosingPhoto = false
    /// Suggest's question: the placeholder on an empty note, a faded line
    /// under written words. Written into the note only when that line is
    /// tapped, and then only the question (`JournalSuggestInsert`).
    @State private var question: String?
    /// The caret, so a tapped question can put it after the heading it wrote.
    @State private var selection: TextSelection?
    @State private var asked: [String] = []
    @State private var thinking = false
    @FocusState private var writing: Bool
    /// What is being typed in the Journal's bar, before it joins the note.
    @State private var journalDraft = ""
    @FocusState private var journalComposing: Bool
    /// The day's sketch, by file name (`MoodLog.sketchFileName`).
    @State private var sketchName: String?
    /// The full-screen editor is up, on `sketchAtOpen`.
    @State private var sketching = false
    @State private var sketchAtOpen = PKDrawing()
    /// Its stickers (`JournalSketches.stickers`).
    @State private var sketchStickersAtOpen: [InkSticker] = []
    #if DEBUG
    @State private var journalHarnessRan = false
    #endif

    private static let tapTarget: CGFloat = 44

    /// `opening` is the tab to show first; a past day's set has only the
    /// Journal, so it opens there whatever is passed.
    init(dateString: String, tabs: DayTabSet, opening: DayTab = .plan,
         onComplete: @escaping (PlanItem) -> Void = { _ in }) {
        self.dateString = dateString
        self.tabSet = tabs
        self.onComplete = onComplete
        _tab = State(initialValue: tabs.opening(opening))
    }

    private var isToday: Bool { dateString == DateUtils.dateString(from: Date()) }

    /// "Today", "Yesterday", or the day: "Sunday 5 October". `DayTitle`, so
    /// the sheet names the day exactly as the page under it does.
    private var title: String { DayTitle.title(forKey: dateString) }

    /// The Journal bar's words (the owner's, 2026-10-06). A past day was not
    /// "today".
    private var invitation: String {
        isToday ? "Write about today" : "Write about that day"
    }

    private var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private var motion: Animation { reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy }

    var body: some View {
        NavigationStack {
            page
                // New Sticker's photos and its lift, hung on the page: the
                // mark's button is in the bar, and a cover cannot rise from
                // a bar item (`StickerMaking`).
                .stickerMaking(isPresented: $choosingPhoto) { made in
                    symbol = made
                    save()
                }
                // **The tabs ARE the title** on Wins (the owner, 2026-10-05:
                // "the tabs i feel like look a little off"): a bold "Today"
                // over a bold "Plan" was two headings, so the switch takes the
                // title's place. A past day has no switch and keeps its date.
                // A past day's bar: "Yesterday / Sunday" in two tones
                // (`DayTitle.twoTone`, the owner's pick, 2026-10-06).
                .modifier(DayTitleOrTabs(title: DayTitle.twoTone(forKey: dateString),
                                         tabs: tabSet.showsSwitch ? AnyView(tabSwitch) : nil))
                // Top left is the tab's own button: the emoji on the Journal,
                // ＋ on the Plan (the owner, 2026-10-05: "why does there need
                // to be the add to plan just have the + button on the top
                // left").
                .toolbar { DaySheetToolbar(leading: leadingButton, done: done) }
        }
        // Full height, stated; the drag indicator; the page's own ground as
        // the sheet's material. Through the default frosted glass the
        // tower's colours bled up behind the controls (`AddWinSheet`).
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground { WarmBackground().ignoresSafeArea() }
        .fullScreenCover(isPresented: $sketching) {
            JournalSketchEditor(title: title, drawing: sketchAtOpen, stickers: sketchStickersAtOpen) { drawn in
                keepSketch(drawn)
            }
        }
        // Saved a beat after typing stops, so a note survives the app being
        // closed mid-sentence, and once more on the way out.
        .task(id: text) {
            guard loaded else { return }
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            save()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { save() }
        }
        .onDisappear {
            save()
            if tabSet.tabs.contains(.plan) { PlanLines.tidy(allItems, keeping: nil, context: modelContext) }
        }
    }

    // MARK: - The page

    /// The switch, fixed under the title, then the tab on screen. Each tab is
    /// its own scroll with its own foot, and the two cross-fade on the page's
    /// own ground: both tabs stand on the same `WarmBackground`, so the
    /// handover has nothing under it that must not show.
    private var page: some View {
        VStack(spacing: 0) {
            ZStack {
                switch tab {
                case .plan:
                    planTab.transition(.opacity)
                case .journal:
                    journalTab.transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    // MARK: - The switch

    /// **Two plain words, side by side, centred** (the owner, 2026-10-05).
    /// The chosen one in `inkPrimary` at the heading weight, the other in
    /// `inkTertiary` at the prose weight: the app's two weights, and no
    /// capsule, no glass and no segmented control behind either. Each word
    /// is a 44pt target. VoiceOver hears a tab bar with the chosen tab
    /// selected.
    private var tabSwitch: some View {
        HStack(spacing: GridConstants.gapTight) {
            ForEach(tabSet.tabs, id: \.self) { item in
                tabWord(item)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isTabBar)
    }

    private func tabWord(_ item: DayTab) -> some View {
        let chosen = item == tab
        return Button { choose(item) } label: {
            // **Both words the title's size and weight; only the ink moves**
            // (2026-10-05). A chosen word that grew and thickened made the
            // pair lopsided and nothing stood still.
            Text(item.title)
                .font(Typography.headerMedium)
                .foregroundStyle(chosen ? AppColors.inkPrimary : AppColors.inkTertiary)
                .padding(.horizontal, GridConstants.gapTight)
                .frame(minWidth: Self.tapTarget, minHeight: Self.tapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressWord)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(chosen ? [.isSelected] : [])
        .animation(GridConstants.crossFade, value: chosen)
    }

    /// The Journal asks `JournalLock` when it is chosen; the Plan never does.
    /// Refused, the sheet stays where it was.
    private func choose(_ next: DayTab) {
        // Every choice is numbered, so a Journal unlock that answers after a
        // later tap on Plan does not undo it: Plan, Journal, Plan in quick
        // succession ended on the Journal, because the unlock is async even
        // when the lock is off.
        choices += 1
        let ticket = choices
        guard next != tab else { return }
        guard next == .journal, JournalLock.shared.hidesWriting else {
            show(next)
            return
        }
        Task {
            guard await JournalLock.shared.unlock(), ticket == choices else { return }
            show(next)
        }
    }

    private func show(_ next: DayTab) {
        HapticsEngine.tick()
        // The keyboard goes with the tab it was typing in.
        writing = false
        if tab == .plan {
            planFocus = nil
            PlanLines.tidy(allItems, keeping: nil, context: modelContext)
        }
        withAnimation(GridConstants.crossFade) { tab = next }
        if tabSet.showsSwitch { lastTab = next.rawValue }
    }

    // MARK: - The Plan tab

    /// The plan exactly as the Plan screen drew it, and its own Suggest at the
    /// foot, on a phone with Apple's model.
    private var planTab: some View {
        ScrollView(.vertical, showsIndicators: false) {
            PlanLines(focused: $planFocus, onComplete: onComplete,
                      onStart: { planFocus = planComposerID })
                .frame(maxWidth: .infinity, alignment: .top)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if PlanSuggestions.isAvailable {
                    PlanSuggestionsView(
                        context: { shown in
                            PlanLines.suggestionContext(lines: todaysLines, habits: habits, alreadyShown: shown)
                        },
                        keep: { PlanLines.keep($0, after: allItems, context: modelContext) },
                        unkeep: { PlanLines.unkeep($0, from: allItems, context: modelContext) },
                        offersWord: planFocus != nil)
                }
                planComposer
            }
        }
    }

    /// **The chat's bar, for the plan** (the owner's pick, 2026-10-06,
    /// "Composer for both"): type a thing, send it, and it is the plan's next
    /// line. It replaced the ＋ top left. Return sends too, and the field
    /// stays up for the next line.
    private var planComposer: some View {
        DayComposer(canSend: DayComposing.hasWords(planDraft), onSend: { sendPlanLine(planDraft) }) {
            PlanTextField(text: $planDraft, placeholder: "Add to the plan",
                          focused: $planFocus, id: planComposerID, isDone: false,
                          onReturn: {}, returnKey: .send, onSend: sendPlanLine)
                // A `UITextField` takes all the height it is offered.
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Add to the plan")
        }
    }

    private func sendPlanLine(_ words: String) {
        planDraft = ""
        guard DayComposing.hasWords(words) else { return }
        HapticsEngine.tick()
        withAnimation(motion) {
            _ = DayComposing.addPlanLine(words, after: allItems, habits: habits, context: modelContext)
        }
    }

    // MARK: - The Journal tab

    /// **One scroll for the journal.** The page is held to at least the
    /// viewport's height so the note's tail takes whatever the words leave,
    /// and a tap anywhere under the note writes in it.
    private var journalTab: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                note
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) { journalFoot }
            // **An empty page says so, in the middle, as the chat does**
            // (the owner, 2026-10-06: "the journal should be like the chat
            // where it has that empty state message in the middle"; the
            // chat's is "Quiet here. Yet."). Gone the moment there is a word,
            // a question or a sketch, and never in the way of a tap.
            .overlay {
                if isEmpty && question == nil && sketchName == nil {
                    Text("Nothing written. Yet.")
                        .font(Typography.bodyLarge)
                        .foregroundStyle(AppColors.inkTertiary)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
        }
        // Starting to write under a placeholder question answers it: the
        // question has done its job and does not follow you down the page.
        .onChange(of: isEmpty) { was, now in
            if was && !now { question = nil }
        }
        .animation(motion, value: isEmpty)
        .animation(motion, value: question)
        .task { await journalShown() }
    }

    /// The note is read only once the Journal is on screen, which is only
    /// ever after Lock Journal has let it open.
    private func journalShown() async {
        load()
        JournalQuestions.prewarm()
        #if DEBUG
        guard !journalHarnessRan else { return }
        journalHarnessRan = true
        if DebugHarness.journalAsks { ask() }
        // `-strataJournalInsert 1`, with `-strataJournalAsk`: taps the
        // question line once it has come, which nothing here can tap.
        if DebugHarness.argument("-strataJournalInsert") == "1" {
            for _ in 0..<40 where question == nil {
                try? await Task.sleep(for: .milliseconds(250))
            }
            try? await Task.sleep(for: .seconds(1.5))
            if let question { insert(question) }
        }
        if DebugHarness.argument("-strataSticker") == "seed", StickerStore.name(in: symbol) == nil,
           let sample = StickerMaker.sample(), let name = StickerStore.shared.add(sample) {
            symbol = StickerStore.symbol(for: name)
            save()
        }
        if let sketch = DebugHarness.journalSketch {
            try? await Task.sleep(for: .milliseconds(600))
            if sketchName == nil {
                // The editor's canvas on this phone: the page's width at
                // the 2:3 shape, the pen scaled as the editor scales it.
                let w = UIScreen.main.bounds.width - GridConstants.horizontalPadding * 2
                let canvas = CGSize(width: w, height: w / JournalSketchEditor.aspect)
                let pen = InkPen.width
                keepSketch(InkDoodle(drawing: InkSamples.sunOverHill(in: canvas, width: pen), canvas: canvas))
            }
            if sketch == "open" { openEditor() }
        }
        #endif
    }

    /// The note: the words, the question under them, the sketch, and the
    /// rest of the page as the place to tap to write.
    ///
    /// **The question and the sketch follow the words; nothing is pinned to
    /// the foot** (the owner, 2026-10-05: "I dont really like how when you
    /// make the sketches everything drops down to the bottom like the
    /// sketch... it should be with the journal entry or right under the
    /// journal entry"). The flexible space is the LAST thing in the stack,
    /// under the sketch, so they sit on the note however short it is. Only
    /// Suggest and the pen stand at the foot (`footer`).
    private var note: some View {
        VStack(alignment: .leading, spacing: 0) {
            // **No photographs here** (the owner, 2026-10-06: "why is there
            // pictures in the journal tab I dont think i like that"). The row
            // of the day's photos came out; Suggest still asks about the
            // day's own wins, so the help to start remains without them.
            editor
            if let question, !isEmpty {
                questionLine(question)
                    .padding(.horizontal, GridConstants.horizontalPadding)
                    .transition(.opacity)
            }
            sketch
            // The spare page writes in the bar at the foot, as a chat's
            // does; the note itself still takes a tap to edit.
            Color.clear
                .frame(minHeight: Self.tapTarget, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { journalComposing = true }
                .accessibilityHidden(true)
        }
    }

    /// The words. They grow with what is written, inside the page's one
    /// scroll, rather than scrolling in a box of their own.
    private var editor: some View {
        TextEditor(text: $text, selection: $selection)
            .font(Typography.bodyLarge)
            .foregroundStyle(AppColors.inkPrimary)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .focused($writing)
            // One line's target and no more: the question and the sketch
            // follow the words directly, so a short note keeps its sketch
            // right under it (the owner, 2026-10-05: "it should be with the
            // journal entry or right under the journal entry"), and the
            // page's spare room is below them, where a tap still writes.
            .frame(minHeight: Self.tapTarget)
            .fixedSize(horizontal: false, vertical: true)
            .overlay(alignment: .topLeading) {
                if isEmpty, let question {
                    // Suggest's question, where the words will start. It is
                    // drawn over the editor and never typed into it. With no
                    // question the page is empty: the bar at the foot says
                    // where to write.
                    Text(question)
                        .font(Typography.bodyLarge)
                        .foregroundStyle(AppColors.inkTertiary)
                        // The text view's own inset, so the placeholder sits
                        // exactly where the first letter will.
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .id(question)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel("Note")
            .accessibilityHint(isEmpty ? (question ?? "") : "")
            .padding(.horizontal, GridConstants.horizontalPadding - 5)
    }

    /// **The question, faded, under what you wrote.** A tap writes it into
    /// the note as a heading line (the question, then a new line) and puts
    /// the caret after it, so the next thing you type answers it. It never
    /// writes an answer. "Another" at the foot of the page still cycles.
    private func questionLine(_ question: String) -> some View {
        Button { insert(question) } label: {
            Text(question)
                .font(Typography.bodyLarge)
                .foregroundStyle(AppColors.inkTertiary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: Self.tapTarget, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressWord)
        .id(question)
        .accessibilityLabel("Write in: \(question)")
        .accessibilityHint("Adds the question to your note, so you can answer it")
    }

    private func insert(_ question: String) {
        HapticsEngine.lightTap()
        let out = JournalSuggestInsert.inserting(question, into: text)
        text = out.text
        selection = TextSelection(insertionPoint: out.caret)
        self.question = nil
        writing = true
    }

    /// **The finished sketch, under the words, at the size it was written
    /// for** (`JournalSketches.shownHeight` for a whole canvas): its natural
    /// size, never stretched to the page's width. A tap opens its strokes in
    /// the full-screen editor; a hold offers Remove.
    @ViewBuilder
    private var sketch: some View {
        if let sketchName {
            Button { openEditor() } label: {
                InkImage(url: InkFiles.shared.url(sketchName), scale: JournalSketches.scale, natural: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.press)
            .contextMenu {
                Button("Remove", systemImage: "xmark", role: .destructive) { removeSketch() }
            }
            .accessibilityLabel("Sketch")
            .accessibilityHint("Opens it to draw on")
            .padding(.horizontal, GridConstants.horizontalPadding)
            .padding(.vertical, GridConstants.gapItem)
            .transition(.opacity)
        }
    }

    // MARK: - The Journal's foot

    /// The journal's own Suggest, offered everywhere (the fixed list answers
    /// without the model). The plan's Suggest is the Plan tab's.
    ///
    /// **The chat's bar** (the owner's pick, 2026-10-06, "Composer for
    /// both"): what is sent joins the note as its next paragraph. The pen
    /// stands where a chat keeps its attachment, and Suggest sits above.
    private var journalFoot: some View {
        VStack(spacing: 0) {
            // Only while the keyboard is up (the owner, 2026-10-06: "the
            // suggest should only pop up when the keyboard does").
            if writing || journalComposing {
                journalSuggest.transition(.opacity)
            }
            DayComposer(canSend: DayComposing.hasWords(journalDraft), onSend: sendParagraph) {
                TextField(invitation, text: $journalDraft, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($journalComposing)
            } leading: {
                GlassIconButton(systemName: "pencil", onPage: true,
                                accessibilityLabel: sketchName == nil ? "Sketch" : "Edit Sketch") {
                    openEditor()
                }
            }
        }
        .animation(motion, value: writing || journalComposing)
    }

    private func sendParagraph() {
        guard DayComposing.hasWords(journalDraft) else { return }
        HapticsEngine.lightTap()
        withAnimation(motion) { text = DayComposing.appending(journalDraft, to: text) }
        journalDraft = ""
    }

    private var todaysLines: [PlanItem] {
        allItems.filter { $0.belongs(on: Date(), calendar: .current) }
    }

    /// One quiet word at the foot of the page, as on the plan. It asks for
    /// one question and shows it as the placeholder; pressed again, another.
    private var journalSuggest: some View {
        Button { ask() } label: {
            Label(question == nil ? "Suggest" : "Another", systemImage: "sparkles")
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.inkSecondary)
                .frame(maxWidth: .infinity, minHeight: Self.tapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .disabled(thinking)
        .opacity(thinking ? 0.5 : 1)
        .accessibilityHint("Shows a question about your day")
    }

    /// `win`: the win a photograph in the row was pressed for, so the question
    /// is about that one. Nil asks about the day, as Suggest always has.
    private func ask(about win: String? = nil) {
        HapticsEngine.lightTap()
        thinking = true
        let context = JournalQuestionContext(
            wins: JournalQuestionContext.winTitles(on: dateString, context: modelContext),
            alreadyAsked: asked, isToday: isToday,
            company: JournalQuestionContext.company(on: dateString, context: modelContext),
            focus: win,
            moments: JournalQuestionContext.moments(on: dateString, context: modelContext))
        Task {
            let next = await JournalQuestions.next(context, using: JournalQuestions.questioner)
            question = next
            asked.append(next)
            thinking = false
            AccessibilityNotification.Announcement(next).post()
        }
    }

    // MARK: - The sketch

    private func openEditor() {
        guard tab == .journal else { return }
        writing = false
        sketchAtOpen = sketchName.flatMap { JournalSketches.drawing(for: $0) } ?? PKDrawing()
        sketchStickersAtOpen = sketchName.map { JournalSketches.stickers(for: $0) } ?? []
        sketching = true
    }

    /// Writes the editor's drawing, if it changed, at the scale it will be
    /// shown at. Rubbed out completely, the sketch goes. Opened and closed
    /// with nothing done, nothing is written, so a sketch whose strokes are
    /// not on this phone (made on another one) is never replaced by the empty
    /// canvas it opened as.
    private func keepSketch(_ drawn: InkDoodle) {
        guard loaded, drawn.drawing.dataRepresentation() != sketchAtOpen.dataRepresentation()
                || drawn.stickers != sketchStickersAtOpen else { return }
        let name = JournalSketches.save(drawn.drawing, stickers: drawn.stickers, width: drawn.canvas.width,
                                        day: dateString, replacing: sketchName,
                                        shownScale: JournalSketches.shownScale(canvasHeight: drawn.canvas.height))
        sketchName = name
        sketchAtOpen = drawn.drawing
        sketchStickersAtOpen = drawn.stickers
        DayNotes.setSketch(name, for: dateString, context: modelContext)
    }

    private func removeSketch() {
        guard let sketchName else { return }
        JournalSketches.remove(sketchName)
        self.sketchName = nil
        DayNotes.setSketch(nil, for: dateString, context: modelContext)
    }

    // MARK: - The emoji

    /// **The day's symbol, top left, and only if you want one.**
    ///
    /// The spec put a dashed circle beside the title. The owner, on seeing it
    /// (2026-10-05): a small Liquid Glass button in the top-left corner,
    /// completely optional, with the title left centred and alone. Empty, it
    /// is a quiet smiley on glass; chosen, it is the emoji on the same glass.
    /// A tap opens the system emoji keyboard through `EmojiField`, the same
    /// invisible field the crew reaction bar's "+" uses, and changes it at any
    /// time. Two ways to take it off: hold it for Remove, or pick the same
    /// emoji again.
    @ViewBuilder
    private var leadingButton: some View {
        switch tab {
        case .journal: emojiButton
        // The Plan's ＋ became its bar at the foot (`planComposer`).
        case .plan: EmptyView()
        }
    }

    private var emojiButton: some View {
        Button {
            HapticsEngine.lightTap()
            choosingMark = true
        } label: {
            ZStack {
                if let name = StickerStore.name(in: symbol), let image = StickerStore.shared.image(name) {
                    // One of your stickers (`StickerStore`), a touch bigger
                    // than the disc so it reads as stuck on.
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: Self.tapTarget - 6, height: Self.tapTarget - 6)
                        .rotationEffect(.degrees(-6))
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                } else if let symbol, StickerStore.name(in: symbol) == nil {
                    Text(symbol)
                        .font(Typography.headerMedium)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                } else {
                    // **The owner's smiley** (2026-10-06, `DoodleIcon`), the
                    // same drawing as the ink row's sticker button, because it
                    // opens the same stickers. Alone in its corner (the title
                    // is words, Done is a word), so no symbol stands beside it.
                    DoodleIcon(.sticker, size: GridConstants.iconToolbar, label: "Sticker")
                        // `GlassIconButton`'s ink, as the Plan's ＋ in this
                        // corner wears: switching tabs changed the glyph's ink.
                        .foregroundStyle(.primary)
                        .transition(.opacity)
                }
            }
            // `GlassIconLabel`'s own face: a 44pt disc of the page's glass.
            // Built here rather than through it because a chosen emoji is
            // text, not an SF Symbol.
            .frame(width: Self.tapTarget, height: Self.tapTarget)
            .glassCircle(onPage: true)
            .contentShape(Circle())
        }
        // `.plain`, as `GlassIconButton` is: the glass answers the finger
        // itself, and a scaling press on interactive glass cancels the tap on
        // a phone (`CrewReactions`, 2026-10-05). The Plan's ＋ in this same
        // corner is a `GlassIconButton`, so the two now press alike.
        .buttonStyle(.plain)
        .popover(isPresented: $choosingMark) {
            StickerPicker(current: symbol, onPick: { picked in
                symbol = picked == symbol ? nil : picked
                save()
                choosingMark = false
            }, onNewSticker: {
                choosingMark = false
                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    choosingPhoto = true
                }
            }, onEmoji: {
                choosingMark = false
                // The keyboard once the popover has gone: a field asked to
                // take focus under a closing popover does not.
                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    picking = true
                }
            })
            .presentationCompactAdaptation(.popover)
        }
        .overlay {
            EmojiField(isActive: $picking) { picked in
                // The same one again takes it off.
                symbol = picked == symbol ? nil : picked
                save()
            }
            .frame(width: 1, height: 1)
            .opacity(0.01)
        }
        .contextMenu {
            if symbol != nil {
                Button("Remove", systemImage: "xmark", role: .destructive) {
                    symbol = nil
                    save()
                }
            }
        }
        .animation(reduceMotion ? GridConstants.crossFade : GridConstants.elasticPop, value: symbol)
        .accessibilityLabel(symbol.map { "The day's mark, \(JournalMark.spoken($0))" } ?? "Add a sticker or emoji for the day")
        .accessibilityHint(symbol == nil ? "" : "Choose the same one again to remove it")
    }

    // MARK: - Done, and keeping it

    private func done() {
        HapticsEngine.lightTap()
        save()
        if tabSet.tabs.contains(.plan) { PlanLines.tidy(allItems, keeping: planFocus, context: modelContext) }
        dismiss()
    }

    private func load() {
        guard !loaded else { return }
        let entry = DayNotes.entry(for: dateString, context: modelContext)
        text = entry?.note ?? ""
        symbol = entry?.symbol
        sketchName = entry?.sketchFileName
        loaded = true
    }

    private func save() {
        guard loaded else { return }
        Self.keep(note: text, symbol: symbol, for: dateString, context: modelContext)
    }

    /// **The day's entry, written from the note alone.** The plan's lines are
    /// on the same page and never in here: "the plan stuff obviously wouldnt
    /// show up in the final journal entry". `DaySheetTests` drives it with a
    /// plan on the store and sweeps this body for any read of one.
    static func keep(note: String, symbol: String?, for dateString: String, context: ModelContext) {
        DayNotes.save(note: note, symbol: symbol, for: dateString, context: context)
    }
}

/// The sheet's bar: the tab's own button top left (the Journal's emoji, the
/// Plan's ＋), Done top right. The title is the tabs, in the middle.
///
/// Typed `ToolbarContent`, so the availability gate for
/// `sharedBackgroundVisibility` can live in it: the leading button brings its
/// own glass, and inside the system's toolbar capsule it would be glass on
/// glass.
private struct DaySheetToolbar<Leading: View>: ToolbarContent {
    let leading: Leading
    let done: () -> Void

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarLeading) { leading }
                .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .topBarTrailing) { doneButton }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarLeading) { leading }
            ToolbarItem(placement: .topBarTrailing) { doneButton }
        }
    }

    private var doneButton: some View {
        Button(action: done) {
            Text("Done").sheetAction()
        }
        .buttonStyle(.pressWord)
    }
}

/// The sheet's title, or, where there is a choice of tab, the switch standing
/// where the title would.
private struct DayTitleOrTabs: ViewModifier {
    let title: String
    let tabs: AnyView?

    func body(content: Content) -> some View {
        if let tabs {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if #available(iOS 26.0, *) {
                        ToolbarItem(placement: .principal) { tabs }
                            .sharedBackgroundVisibility(.hidden)
                    } else {
                        ToolbarItem(placement: .principal) { tabs }
                    }
                }
        } else {
            content.sheetTitle(title, drawn: false)
        }
    }
}
