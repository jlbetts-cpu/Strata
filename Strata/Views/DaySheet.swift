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
/// carries the whole day's page under `DayIcon` since the two became one.
enum JournalIcon {
    static let name = "text.alignleft"
}

/// **The day's page, from Wins: one glass button, `checklist`** (the
/// owner's pick, 2026-10-05). It replaced the Journal and Plan pair when the
/// two sheets became one page: one page, one way in.
enum DayIcon {
    static let name = "checklist"
}

/// **The day's journal, one press from the day.** A glass button with
/// `JournalIcon.name` on it, hollow whether or not the day has a note (the
/// owner, 2026-10-05). VoiceOver still hears "Written" on a day that has one.
///
/// It stands in the top-right corner of a past day (a day's album, a crew's
/// day). It owns its sheet, the day's page (`DaySheet`) with the note part
/// only, and it asks `JournalLock` first: with Lock Journal on, a note opens
/// only after Face ID or the passcode, once a session. On Wins the day's page
/// opens from `DayIcon` instead, plan and note together.
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
            // **A past day is the note alone.** Plan lines look forward: the
            // overnight sweep deletes a finished one-off and unticks a repeat
            // (`PlanItem.sweep`), so the model keeps no record of what a past
            // day planned, and a plan part here would show today's list under
            // another day's title.
            DaySheet(dateString: dateString, parts: DayParts(plan: false, note: true))
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

// MARK: - Which parts a day shows

/// **What the day's page holds.** Today: the plan, then the note. A past day:
/// the note alone, because the model keeps no past plan (`PlanItem.sweep`).
/// With Lock Journal on and Face ID refused, the note is left out and the
/// plan still opens: the lock is for the note, and the plan was never behind
/// it.
struct DayParts: Equatable {
    var plan: Bool
    var note: Bool

    static func forDay(isToday: Bool, noteOpen: Bool) -> DayParts {
        DayParts(plan: isToday, note: noteOpen)
    }
}

/// The two parts of the page, for whichever had focus last.
enum DayPart: Equatable { case plan, note }

/// **One Suggest, serving the part you are in.** In the plan it offers plan
/// lines (`PlanSuggestionsView`); in the note it asks the journal's question
/// (`JournalQuestions`). Which part is decided by the field that last had
/// focus, and kept when focus goes, so the control does not change under
/// you as the keyboard comes down. The page opens on its first part.
enum SuggestTarget {
    static func initial(parts: DayParts) -> DayPart {
        parts.plan ? .plan : .note
    }

    static func after(focus: DayPart?, current: DayPart, parts: DayParts) -> DayPart {
        switch focus {
        case .plan? where parts.plan: return .plan
        case .note? where parts.note: return .note
        default: return current
        }
    }
}

// MARK: - The sheet

/// **The day, on one page: what you mean to do, then what happened**
/// (owner-approved, 2026-10-05: "the plan and journal screen could probably
/// be merged like a place where you can jot down the day while also planning
/// the day there uis are pretty similar... the plan stuff obviously wouldnt
/// show up in the final journal entry").
///
/// The chrome both sheets already shared: a large detent, the drag
/// indicator, the page's own ground as the sheet's material, the day as the
/// title (`DayTitle`), the emoji's glass top left and Done top right. Then
/// the plan's lines exactly as the Plan sheet drew them (`PlanLines`), a
/// quiet gap of space and no rule, and the note: the words, the faded
/// question, the sketch.
///
/// **The plan never reaches the note.** What is saved as the day's entry
/// (`MoodLog.note`) is the note's words and nothing else; `keep` is the one
/// write and it is handed the note alone (`DaySheetTests`).
///
/// **One Suggest at the foot**, for whichever part you are in
/// (`SuggestTarget`). In the note it shares the foot with the pen, which
/// opens the full-screen sketch editor (`JournalSketchEditor`).
///
/// **What it does not have**, each from the journal spec's "Do not build":
/// no streak, no reminder, no summary, no mood chart, no template, no tool
/// picker. The emoji is the day's symbol, not a score, so it has no scale.
struct DaySheet: View {
    let dateString: String
    let parts: DayParts
    /// A plan line's block pressed: the caller opens the add sheet.
    var onComplete: (PlanItem) -> Void = { _ in }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // The plan.
    @Query(sort: \PlanItem.order) private var allItems: [PlanItem]
    @Query private var habits: [Habit]
    @State private var planFocus: UUID?

    // The note.
    @State private var text = ""
    @State private var symbol: String?
    @State private var loaded = false
    @State private var picking = false
    /// Suggest's question: the placeholder on an empty note, a faded line
    /// under written words. Written into the note only when that line is
    /// tapped, and then only the question (`JournalSuggestInsert`).
    @State private var question: String?
    /// The caret, so a tapped question can put it after the heading it wrote.
    @State private var selection: TextSelection?
    @State private var asked: [String] = []
    @State private var thinking = false
    @FocusState private var writing: Bool
    /// The day's sketch, by file name (`MoodLog.sketchFileName`).
    @State private var sketchName: String?
    /// The full-screen editor is up, on `sketchAtOpen`.
    @State private var sketching = false
    @State private var sketchAtOpen = PKDrawing()

    @State private var suggestTarget: DayPart

    private static let tapTarget: CGFloat = 44
    /// **The quiet gap between the plan and the note**: space, never a rule
    /// (the owner: "we dont use lines we use space throughout the app").
    /// `gapSection`, the ladder's step between two groups, under the plan's
    /// one-row tail.
    static let quietGap: CGFloat = GridConstants.gapSection

    init(dateString: String, parts: DayParts, onComplete: @escaping (PlanItem) -> Void = { _ in }) {
        self.dateString = dateString
        self.parts = parts
        self.onComplete = onComplete
        _suggestTarget = State(initialValue: SuggestTarget.initial(parts: parts))
    }

    private var isToday: Bool { dateString == DateUtils.dateString(from: Date()) }

    /// "Today", "Yesterday", or the day: "Sunday 5 October". `DayTitle`, so
    /// the sheet names the day exactly as the page under it does.
    private var title: String { DayTitle.title(forKey: dateString) }

    /// The owner's words for an empty note. A past day was not "today".
    private var invitation: String {
        isToday ? "What happened today?" : "What happened that day?"
    }

    private var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private var motion: Animation { reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy }

    var body: some View {
        NavigationStack {
            page
                // The title centred and alone (the owner, 2026-10-05), set as
                // every sheet that names data rather than itself is.
                .sheetTitle(title, drawn: false)
                .toolbar { DaySheetToolbar(emoji: emojiButton, showsEmoji: parts.note, done: done) }
        }
        // Full height, stated; the drag indicator; the page's own ground as
        // the sheet's material. Through the default frosted glass the
        // tower's colours bled up behind the controls (`AddWinSheet`).
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground { WarmBackground().ignoresSafeArea() }
        .fullScreenCover(isPresented: $sketching) {
            JournalSketchEditor(title: title, drawing: sketchAtOpen) { drawing, canvas in
                keepSketch(drawing, canvas: canvas)
            }
        }
        .task {
            load()
            guard parts.note else { return }
            JournalQuestions.prewarm()
            #if DEBUG
            if DebugHarness.journalAsks { retarget(.note); ask() }
            // `-strataJournalInsert 1`, with `-strataJournalAsk`: taps the
            // question line once it has come, which nothing here can tap.
            if DebugHarness.argument("-strataJournalInsert") == "1" {
                for _ in 0..<40 where question == nil {
                    try? await Task.sleep(for: .milliseconds(250))
                }
                try? await Task.sleep(for: .seconds(1.5))
                if let question { insert(question) }
            }
            if let sketch = DebugHarness.journalSketch {
                try? await Task.sleep(for: .milliseconds(600))
                if sketchName == nil {
                    // The editor's canvas on this phone: the page's width at
                    // the 2:3 shape, the pen scaled as the editor scales it.
                    let w = UIScreen.main.bounds.width - GridConstants.horizontalPadding * 2
                    let canvas = CGSize(width: w, height: w / JournalSketchEditor.aspect)
                    let pen = InkPen.width(onCanvasOfHeight: canvas.height, shownAt: JournalSketches.shownHeight)
                    keepSketch(InkSamples.sunOverHill(in: canvas, width: pen), canvas: canvas)
                }
                if sketch == "open" { openEditor() }
            }
            #endif
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
            if parts.plan { PlanLines.tidy(allItems, keeping: nil, context: modelContext) }
        }
    }

    // MARK: - The page

    private var page: some View {
        // **One scroll for the whole day.** The page is held to at least the
        // viewport's height so the note's tail takes whatever the lines and
        // the words leave, and a tap anywhere under the note writes in it.
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if parts.plan {
                        PlanLines(focused: $planFocus, onComplete: onComplete)
                    }
                    if parts.plan && parts.note {
                        Color.clear
                            .frame(height: Self.quietGap)
                            .accessibilityHidden(true)
                    }
                    if parts.note { note }
                }
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        }
        .onChange(of: planFocus) { _, id in if id != nil { retarget(.plan) } }
        .onChange(of: writing) { _, now in if now { retarget(.note) } }
        // Starting to write under a placeholder question answers it: the
        // question has done its job and does not follow you down the page.
        .onChange(of: isEmpty) { was, now in
            if was && !now { question = nil }
        }
        .animation(motion, value: isEmpty)
        .animation(motion, value: question)
        .animation(motion, value: suggestTarget)
    }

    private func retarget(_ focus: DayPart) {
        suggestTarget = SuggestTarget.after(focus: focus, current: suggestTarget, parts: parts)
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
            editor
            if let question, !isEmpty {
                questionLine(question)
                    .padding(.horizontal, GridConstants.horizontalPadding)
                    .transition(.opacity)
            }
            sketch
            Color.clear
                .frame(minHeight: Self.tapTarget, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { writing = true }
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
                if isEmpty {
                    // The placeholder, or Suggest's question in its place. It
                    // is drawn over the editor and never typed into it.
                    Text(question ?? invitation)
                        .font(Typography.bodyLarge)
                        .foregroundStyle(AppColors.inkTertiary)
                        // The text view's own inset, so the placeholder sits
                        // exactly where the first letter will.
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .id(question ?? invitation)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel("Note")
            .accessibilityHint(isEmpty ? (question ?? invitation) : "")
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

    // MARK: - The foot of the page

    /// **One Suggest, for the part you are in** (`SuggestTarget`). The plan's
    /// is `PlanSuggestionsView`, on a phone with Apple's model; the note's is
    /// the journal question, offered everywhere (the fixed list answers
    /// without the model), with the pen at the trailing edge, because the
    /// sketch is the note's. Switching parts closes any plan suggestions
    /// still showing: they are about the plan, and you have gone to write.
    @ViewBuilder
    private var footer: some View {
        switch suggestTarget {
        case .plan:
            if parts.plan && PlanSuggestions.isAvailable {
                PlanSuggestionsView(
                    context: { shown in
                        PlanLines.suggestionContext(lines: todaysLines, habits: habits, alreadyShown: shown)
                    },
                    keep: { PlanLines.keep($0, after: allItems, context: modelContext) },
                    unkeep: { PlanLines.unkeep($0, from: allItems, context: modelContext) })
                .transition(.opacity)
            }
        case .note:
            if parts.note {
                ZStack {
                    journalSuggest
                    HStack {
                        Spacer(minLength: 0)
                        GlassIconButton(systemName: "pencil", onPage: true,
                                        accessibilityLabel: sketchName == nil ? "Sketch" : "Edit Sketch") {
                            openEditor()
                        }
                    }
                    .padding(.horizontal, GridConstants.horizontalPadding)
                    .padding(.bottom, GridConstants.gapTight)
                }
                .transition(.opacity)
            }
        }
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
        .padding(.bottom, GridConstants.gapTight)
        .accessibilityHint("Shows a question about your day")
    }

    private func ask() {
        HapticsEngine.lightTap()
        thinking = true
        let context = JournalQuestionContext(
            wins: JournalQuestionContext.winTitles(on: dateString, context: modelContext),
            alreadyAsked: asked, isToday: isToday,
            company: JournalQuestionContext.company(on: dateString, context: modelContext))
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
        guard parts.note else { return }
        writing = false
        sketchAtOpen = sketchName.flatMap { JournalSketches.drawing(for: $0) } ?? PKDrawing()
        sketching = true
    }

    /// Writes the editor's drawing, if it changed, at the scale it will be
    /// shown at. Rubbed out completely, the sketch goes. Opened and closed
    /// with nothing done, nothing is written, so a sketch whose strokes are
    /// not on this phone (made on another one) is never replaced by the empty
    /// canvas it opened as.
    private func keepSketch(_ drawing: PKDrawing, canvas: CGSize) {
        guard loaded, drawing.dataRepresentation() != sketchAtOpen.dataRepresentation() else { return }
        let name = JournalSketches.save(drawing, width: canvas.width, day: dateString,
                                        replacing: sketchName,
                                        shownScale: JournalSketches.shownScale(canvasHeight: canvas.height))
        sketchName = name
        sketchAtOpen = drawing
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
    private var emojiButton: some View {
        Button {
            HapticsEngine.lightTap()
            picking = true
        } label: {
            ZStack {
                if let symbol {
                    Text(symbol)
                        .font(Typography.headerMedium)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                } else {
                    Image(systemName: "face.smiling")
                        .iconSize(GridConstants.iconToolbar, relativeTo: .body, weight: .medium)
                        .foregroundStyle(AppColors.inkSecondary)
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
        // `.pressSurface`, as the crew reaction panel's glass buttons take: the
        // disc gives under a finger rather than dimming.
        .buttonStyle(.pressSurface)
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
        .accessibilityLabel(symbol.map { "The day's emoji, \($0)" } ?? "Add an emoji for the day")
        .accessibilityHint(symbol == nil ? "" : "Choose the same one again to remove it")
    }

    // MARK: - Done, and keeping it

    private func done() {
        HapticsEngine.lightTap()
        save()
        if parts.plan { PlanLines.tidy(allItems, keeping: planFocus, context: modelContext) }
        dismiss()
    }

    private func load() {
        guard !loaded, parts.note else { return }
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

/// The sheet's bar: the emoji top left, Done top right. The title is
/// `sheetTitle`'s, in the middle.
///
/// Typed `ToolbarContent`, so the availability gate for
/// `sharedBackgroundVisibility` can live in it: the emoji button brings its
/// own glass, and inside the system's toolbar capsule it would be glass on
/// glass. The emoji is the note's, so with the note left out (Lock Journal,
/// refused) the corner is empty.
private struct DaySheetToolbar<Emoji: View>: ToolbarContent {
    let emoji: Emoji
    let showsEmoji: Bool
    let done: () -> Void

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            if showsEmoji {
                ToolbarItem(placement: .topBarLeading) { emoji }
                    .sharedBackgroundVisibility(.hidden)
            }
            ToolbarItem(placement: .topBarTrailing) { doneButton }
                .sharedBackgroundVisibility(.hidden)
        } else {
            if showsEmoji {
                ToolbarItem(placement: .topBarLeading) { emoji }
            }
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
