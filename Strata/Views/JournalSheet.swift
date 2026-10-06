import SwiftUI
import SwiftData

// MARK: - The button

/// **The journal's glyph, in one place.**
///
/// The spec asked for `book.closed`, filled when the day has a note. The
/// owner, on seeing it (2026-10-05): the glyph is HOLLOW, never filled, and
/// the book is off the app's theme. He then chose `text.alignleft`, at the
/// default weight, so it sits beside the Plan button's `checklist` as one
/// pair of lines. One constant: it is the glyph on the Wins tab and in a
/// past day's corner alike.
enum JournalIcon {
    static let name = "text.alignleft"
}

/// **The day's journal, one press from the day.** A glass button with
/// `JournalIcon.name` on it, hollow whether or not the day has a note (the
/// owner, 2026-10-05). VoiceOver still hears "Written" on a day that has one.
///
/// It stands beside the Plan button on the Wins tab and in the top-right
/// corner of a past day. It owns its sheet, so both places open the same
/// thing the same way, and it asks `JournalLock` first: with Lock Journal on,
/// a note opens only after Face ID or the passcode, once a session.
///
/// **Always there, never asking.** No badge, no dot, no reminder: once a week
/// beat three times a week in the research the spec cites, so the journal is
/// available and never requested.
struct JournalButton: View {
    let dateString: String

    @Query private var entries: [MoodLog]
    @State private var isOpen = false
    @AppStorage(JournalLock.defaultsKey) private var lockOn = false

    init(dateString: String) {
        self.dateString = dateString
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
        // Not while Lock Journal is locked: "Written" is a fact about the
        // note, and the lock is for the note (the cohesion pass, 2026-10-05).
        .accessibilityValue(hasNote && !(lockOn && !JournalLock.shared.isUnlocked) ? "Written" : "")
        .sheet(isPresented: $isOpen) {
            JournalSheet(dateString: dateString)
        }
        #if DEBUG
        // `-strataOpenJournal today` on the Wins tab, `-strataOpenJournal day`
        // on a past day (with `-strataOpenDay`). A header button is the one
        // thing a screenshot script cannot press.
        .task {
            guard let which = DebugHarness.openJournal else { return }
            let isToday = dateString == DateUtils.dateString(from: Date())
            guard (which == "day") != isToday else { return }
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
/// Without the system's own glass behind it, for the reason `PlanSheet`'s
/// toolbar records: a toolbar item on iOS 26 gets a capsule of its own, and a
/// glass button inside a glass capsule is two materials stacked.
struct JournalToolbarItem: ToolbarContent {
    let dateString: String

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarTrailing) { JournalButton(dateString: dateString) }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarTrailing) { JournalButton(dateString: dateString) }
        }
    }
}

// MARK: - The sheet

/// **The day's note: an emoji, the words, and one question if you want it.**
///
/// The Plan sheet's shape, on purpose (spec section 2: "It is the Plan
/// sheet's shape: a large detent and the same chrome"): full height, the drag
/// indicator, the page's own ground as the sheet's material, Done top right
/// in `sheetAction`, and Suggest standing at the foot of the page where the
/// plan's does.
///
/// **What it does not have**, each from the spec's "Do not build": no streak,
/// no reminder, no summary, no mood chart, no template, no tool picker. The
/// emoji is the day's symbol, not a score, so it has no scale.
///
/// **The sketch goes under the words.** `MoodLog.sketchFileName` is the seam,
/// and `sketchSlot` below is where the strip and the finished sketch land.
struct JournalSheet: View {
    let dateString: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var text = ""
    @State private var symbol: String?
    @State private var loaded = false
    @State private var picking = false
    /// Suggest's question, shown as the placeholder. Never inserted.
    @State private var question: String?
    @State private var asked: [String] = []
    @State private var thinking = false
    @FocusState private var writing: Bool

    private static let tapTarget: CGFloat = 44

    private var isToday: Bool { dateString == DateUtils.dateString(from: Date()) }

    /// "Today", "Yesterday", or the day: "Sunday 5 October". `DayTitle`, so
    /// the sheet names the day exactly as the page under it does.
    private var title: String { DayTitle.title(forKey: dateString) }

    /// The owner's words for an empty note. A past day was not "today".
    private var invitation: String {
        isToday ? "What happened today?" : "What happened that day?"
    }

    private var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            page
                // The title centred and alone (the owner, 2026-10-05), set as
                // every sheet that names data rather than itself is.
                .sheetTitle(title, drawn: false)
                .toolbar { JournalSheetToolbar(emoji: emojiButton, done: done) }
        }
        // Full height, stated, the drag indicator, and the page's own ground:
        // the Plan sheet's three lines, for the reasons written there.
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground { WarmBackground().ignoresSafeArea() }
        .task {
            load()
            JournalQuestions.prewarm()
            #if DEBUG
            if DebugHarness.journalAsks { ask() }
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
        .onDisappear { save() }
    }

    // MARK: - The page

    private var page: some View {
        VStack(alignment: .leading, spacing: 0) {
            editor
            sketchSlot
        }
        .padding(.top, GridConstants.gapTight)
        // Suggest stands at the foot of the page, where the plan's stands
        // (`PlanSuggestionsView`). Only while the note is empty: the question
        // is the placeholder, and a written note has no placeholder to show.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isEmpty { suggest }
        }
        .animation(reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy, value: isEmpty)
    }

    /// The words. The whole page below the title is the editor, so a tap
    /// anywhere on it starts writing.
    private var editor: some View {
        TextEditor(text: $text)
            .font(Typography.bodyLarge)
            .foregroundStyle(AppColors.inkPrimary)
            .scrollContentBackground(.hidden)
            .focused($writing)
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
            .animation(reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy, value: question)
            .accessibilityLabel("Note")
            .accessibilityHint(isEmpty ? (question ?? invitation) : "")
            .padding(.horizontal, GridConstants.horizontalPadding - 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// **Where the sketch lands.** The next part of the spec: a pen button
    /// opens a one-pen strip here, inside the note, and the finished sketch
    /// shows here under the words, a tap editing it. It reads and writes
    /// `MoodLog.sketchFileName`. Empty until then.
    @ViewBuilder
    private var sketchSlot: some View {
        EmptyView()
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

    // MARK: - Suggest

    /// One quiet word at the foot of the page, as on the plan. It asks for
    /// one question and shows it as the placeholder; pressed again, another.
    private var suggest: some View {
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

    // MARK: - Done, and keeping it

    private func done() {
        HapticsEngine.lightTap()
        save()
        dismiss()
    }

    private func load() {
        guard !loaded else { return }
        let entry = DayNotes.entry(for: dateString, context: modelContext)
        text = entry?.note ?? ""
        symbol = entry?.symbol
        loaded = true
    }

    private func save() {
        guard loaded else { return }
        DayNotes.save(note: text, symbol: symbol, for: dateString, context: modelContext)
    }
}

/// The sheet's bar: the emoji top left, Done top right. The title is
/// `sheetTitle`'s, in the middle.
///
/// Typed `ToolbarContent`, as `PlanSheet`'s is, so the availability gate for
/// `sharedBackgroundVisibility` can live in it: the emoji button brings its
/// own glass, and inside the system's toolbar capsule it would be glass on
/// glass.
private struct JournalSheetToolbar<Emoji: View>: ToolbarContent {
    let emoji: Emoji
    let done: () -> Void

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarLeading) { emoji }
                .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .topBarTrailing) { doneButton }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarLeading) { emoji }
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
