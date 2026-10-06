import SwiftUI
import SwiftData

/// The plan: what you mean to do, written as blocks-to-be.
///
/// Deliberately the smallest thing that helps. It is a page of bullet points,
/// the way Notes is a page of bullet points — type a line, press return, type
/// another, backspace an empty one away. Everything this app has removed was
/// removed for claiming more structure than anyone wanted to give it, so there
/// is no due date, no priority, no folder and no list-of-lists. There is a
/// repeat, because "the days I do this" is the one thing a plan genuinely
/// needs and the one thing you cannot write in the text.
///
/// **The bullet is a block.** Empty it is an outline, which is the tower's own
/// word for "nothing here yet". Checked it is the real thing, in colour, with
/// a tick. A plan is a picture of the tower you are about to build.
///
/// **A finished line stays until the day turns.** Clearing it the moment you
/// tick it throws away the other half of what this page is for — seeing what
/// you got through. `PlanItem.sweep` does the clearing at the next launch on a
/// new day.
///
/// **The plan is the Plan tab of the day's sheet, not a sheet of its own**
/// (the owner, 2026-10-05: one sheet with two tabs, Plan and Journal, after
/// an evening as one mixed page). `DaySheet` holds the chrome, the title, the
/// switch, Done and the plan's Suggest; this is the lines exactly as the Plan
/// sheet drew them, with their checkboxes, swipe to delete, the long-press
/// menu, repeats, sizes and colours. What moved: the ＋ that stood top left
/// (a line is added by "Add to the plan", by return, or by the tap under the
/// last line), and the tail, which was every point of page left under the
/// list and is one row deep now.
struct PlanLines: View {
    @Environment(\.modelContext) private var modelContext

    /// The line being typed in, shared with the sheet so switching to the
    /// Journal can put the keyboard away.
    @Binding var focused: UUID?

    /// Bumped by the sheet's ＋ (top left on the Plan tab); each change starts
    /// a line at the end.
    var addRequests: Int = 0

    /// Called with the line when its block is pressed. The caller opens the
    /// add sheet; the line is ticked at once, and the tick is kept only once
    /// a win is actually saved, so backing out of that sheet does not spend it.
    var onComplete: (PlanItem) -> Void

    @Query(sort: \PlanItem.order) private var allItems: [PlanItem]
    @Query private var habits: [Habit]
    @State private var detail: PlanItem?
    /// The line whose Delete is showing, if one is. One at a time, as Mail
    /// and Reminders do: opening another closes it.
    @State private var swiped: UUID?

    /// A hairline is `1 / displayScale` (`docs/design-system-future.md` section
    /// 6), which is one device pixel however dense the screen is.
    @Environment(\.displayScale) private var displayScale

    private let calendar = Calendar.current

    // MARK: - The row's geometry
    //
    // **One arithmetic, not two.** The row's leading margin, the empty state's
    // and the separator's inset were three hand-written sums of the same
    // numbers (`horizontalPadding - 11`, `horizontalPadding + 24 + 14`), which
    // is how the separator ended up starting one point off where the text does.
    // Derived from the bullet and its target, so they cannot drift apart.

    /// `PlanBullet`'s own side, which is its default.
    private static let bulletSide: CGFloat = 24
    /// The HIG's minimum target, measured not declared. Every control on this
    /// sheet is this box, whatever its glyph measures.
    private static let tapTarget: CGFloat = 44
    /// What the target adds around the bullet, which the row's margin gives back
    /// so the glyph still lands on the page margin.
    ///
    /// **Derived, and it moves the page one point.** It was written as a literal
    /// 11, which is right for a 22pt bullet and the bullet is 24, so the glyph
    /// sat at 15 while every other page margin in the app is 16. The comment on
    /// the row already claimed it "stays exactly where it was on the page"; now
    /// it does.
    private static let bulletInset: CGFloat = (tapTarget - bulletSide) / 2
    /// Where a line's text starts, and therefore where a separator does. Comes
    /// out at 54, which is what the separator's hand-written sum said.
    private static let textLeading: CGFloat =
        GridConstants.horizontalPadding - bulletInset + tapTarget + GridConstants.spacing
    /// The tap-to-write space under the last line: **one row deep** since the
    /// day became one page (2026-10-05), and kept when the page became two
    /// tabs the same evening. It was 160, and on a short list it took every
    /// point of page that was left; the space under the list is the place the
    /// next line lands, with "Add to the plan" in it. See `content`.
    ///
    /// Not `private`: `SheetRoomTests` checks it is still there.
    static let tailHeight: CGFloat = tapTarget + GridConstants.spacing * 2

    // **`emptyFieldShares` (8 : 5) is deleted** (2026-10-01), four hours after
    // it was added. It put the invitation on the field's golden section, which
    // is the right answer to "where does one object sit in an empty field" and
    // the wrong question: the invitation is not an object in a field, it is row
    // one. See the note in `content`.
    //
    // The part worth keeping is the method rather than the number. Three
    // positions were built and photographed and compared side by side rather
    // than argued about, and the one that measured best (2 : 1, which passed
    // check 11c with room to spare) was the one that looked worst, reading as
    // the invitation having FALLEN to the bottom of the sheet. It shipped for
    // exactly one build. The one that shipped for four hours measured best of
    // the three and was still wrong for a reason no measurement in this file
    // could have caught.

    /// Today's list: everything one-off, plus the repeats due today.
    private var items: [PlanItem] {
        allItems.filter { $0.belongs(on: Date(), calendar: calendar) }
    }

    var body: some View {
        content
            .onChange(of: addRequests) { withAnimation(GridConstants.motionSnappy) { addLine() } }
            .sheet(item: $detail) { item in
                PlanItemDetailSheet(item: item)
            }
            // **The line detail, which is otherwise behind a tap** and so
            // had never been photographed. `-strataOpenSheet planline` raises
            // the day's page from `MainAppView` and opens the first line's
            // detail here. On the main actor after a beat, because `items`
            // reads the fetch and a sheet presented from inside the same
            // runloop turn as its parent does not appear.
            #if DEBUG
            // `-strataPlanSwipe 1` opens the first line's Delete, which is
            // behind a swipe nothing here can make.
            .task {
                guard DebugHarness.argument("-strataPlanSwipe") == "1" else { return }
                try? await Task.sleep(for: .milliseconds(900))
                withAnimation(GridConstants.motionSnappy) { swiped = items.first?.id }
            }
            .task {
                guard DebugHarness.openSheet == "planline",
                      let first = items.first else { return }
                try? await Task.sleep(nanoseconds: 700_000_000)
                detail = first
            }
            #endif
    }

    // **The sheet's chrome went to `DaySheet`** (2026-10-05): the large
    // detent stated, the drag indicator, the page's own ground as the sheet's
    // material (through the default frosted glass the tower's colours bled up
    // behind the controls), and the bar's bare glyphs with no system capsule
    // behind them (on iOS 26 a plain `ToolbarItem` kept a capsule that went
    // BLACK against the warm ground when jostled: "i bumped into the screen
    // tweaking and the apple glass plan button turned black"). The ＋ that
    // lived in that bar is gone with it; see the note on the type.

    @ViewBuilder
    private var content: some View {
        // Read once. `items` filters `allItems` on every access, and the
        // separator below has to ask how many there are.
        let lines = items
        VStack(alignment: .leading, spacing: 0) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(lines) { item in
                    row(item)
                    // **Between two lines, never after the last one.**
                    //
                    // The hairline was drawn in the `ForEach` body with the
                    // row, so five lines got five separators where five lines
                    // have four boundaries. A separator is a statement about
                    // two things; drawn against one it is a rule across the
                    // page.
                    //
                    // Compared by id rather than by an enumerated index, so
                    // the `ForEach` stays keyed on identity: keyed on position
                    // instead, the focused line's `UITextField` would be
                    // re-identified every time a line above it was added or
                    // backspaced away, which is how a caret ends up jumping
                    // rows.
                    // No hairline between lines: space does it (the owner,
                    // 2026-10-05: "it should be more clean... more minimal").
                }
            }

            // **No words, one ＋** (the owner, 2026-10-05: "why does there
            // need to be the add to plan just have the + button on the top
            // left"). The "Add to the plan" row and the empty day's hint are
            // gone; the ＋ in the sheet's top left adds a line. The tail stays
            // as a silent place to tap, one row deep under the list and the
            // same on an empty day, written once so the two states agree.
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: Self.tailHeight)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(GridConstants.motionSnappy) { addLine() } }
            .accessibilityElement()
            .accessibilityLabel("Add a line")
            .accessibilityAddTraits(.isButton)
        }
        .padding(.top, GridConstants.gapTight)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Suggestions

    /// What the model is told: today's lines and the wins it has to go on.
    static func suggestionContext(lines: [PlanItem], habits: [Habit],
                                  alreadyShown: [String]) -> PlanSuggestionContext {
        PlanSuggestionContext.make(plan: lines.map(\.text),
                                   wins: habits.map { ($0.title, $0.category, $0.createdAt) },
                                   alreadyShown: alreadyShown)
    }

    /// A checked suggestion becomes a line at the end of the plan, in its
    /// colour, at its size, with its repeat.
    static func keep(_ suggestion: PlanSuggestion, after all: [PlanItem], context: ModelContext) -> UUID {
        let position = (all.last?.order ?? -1) + 1
        let line = PlanItem(text: suggestion.title, order: position, category: suggestion.category)
        line.size = suggestion.size
        line.repeatDays = suggestion.repeatDays
        context.insert(line)
        try? context.save()
        return line.id
    }

    static func unkeep(_ id: UUID, from all: [PlanItem], context: ModelContext) {
        guard let line = all.first(where: { $0.id == id }) else { return }
        context.delete(line)
        StoreReset.commitDelete("taking back a suggested plan line", context: context)
    }

    // MARK: - A line

    private func row(_ item: PlanItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: GridConstants.spacing) {
            Button {
                complete(item)
            } label: {
                PlanBullet(category: item.category, isDone: item.isDone)
                    // **A real 44pt frame, not padding cancelled by negative
                    // padding.**
                    //
                    // It used to be `.padding(11)` for the target and
                    // `.padding(-11)` to take the space back — which shrinks
                    // the LAYOUT and leaves the hit area where it was, eleven
                    // points out on every side. So the left edge of the text
                    // was standing on the bullet's target, and tapping there
                    // to edit a line COMPLETED it instead. The owner: "the
                    // plan screen is really easy to miss click or something
                    // not work."
                    //
                    // Same family as the month tower's `.offset` and the photo
                    // well's unbounded image: in SwiftUI what a view occupies
                    // and what it can be touched through are two different
                    // rectangles, and only the second one catches fingers.
                    .frame(width: Self.tapTarget, height: Self.tapTarget)
                    .contentShape(Rectangle())
            }
            // The app's press. `PressResponse.press` had no call sites at all
            // and this is a bare-glyph control on a page with no background to
            // shift, which is the class its doc argues for.
            .buttonStyle(.press)
            // The bullet has no text in it, so it has no baseline of its own to
            // align on. This puts one where the glyph's own middle is: measured
            // from the box's bottom, not derived, because where a 17pt line's
            // baseline sits inside its line box is the font's business.
            .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 27 }
            .accessibilityLabel(item.isDone
                                ? "\(item.text), done"
                                : "Log \(item.text.isEmpty ? "this line" : item.text) as a win")

            VStack(alignment: .leading, spacing: 2) {
                PlanTextField(
                    text: Binding(get: { item.text }, set: { item.text = $0 }),
                    placeholder: "",
                    focused: $focused,
                    id: item.id,
                    isDone: item.isDone,
                    onReturn: { addLine(after: item) },
                    onBackspaceWhenEmpty: { backspace(item) }
                )
                if let summary = item.repeatSummary(calendar: calendar) {
                    // **`screenSubtitle`, 15 Medium, and it was 13 Regular**
                    // (2026-10-01, the type pass). A repeat summary is the
                    // quiet line under a line you wrote, and the quiet is the
                    // ink rather than two points of size.
                    //
                    // **`inkTertiary`, and it was `inkQuiet`** (design review,
                    // 2026-10-02). "Every weekday" is a sentence somebody
                    // reads, and `inkQuiet`'s own doc says never a sentence, a
                    // count or a subtitle: it composites to 3.35:1 on the light
                    // sheet, measured on the identical ink one line up in the
                    // add sheet's prompt, against the 4.5 a 15pt word is held
                    // to. `inkTertiary` is the caption ink and clears it at
                    // about 4.7, and it is still two clear steps under the
                    // line it sits beneath (14.3:1).
                    //
                    // Still costs nothing in layout, which is the number that
                    // had to be rechecked: a row's height is set by the
                    // bullet's 44pt box, and a 17pt line (20.3pt of line box)
                    // plus the 2 plus a 15pt subheadline (20.0) comes to 42.3,
                    // so the row is still 44 either way.
                    Text(summary)
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(AppColors.inkTertiary)
                }
            }

            // The way in, the way Reminders does it — and, like Reminders,
            // only on the line you are actually on.
            //
            // Drawn on every row it was six identical glyphs down the right
            // edge of a page whose whole job is to look like somewhere you
            // write. On the focused row it is one control, next to the thing
            // it acts on, and the rest of the list is text.
            //
            // It stays in the accessibility tree either way: hiding a control
            // from VoiceOver because it is visually quiet would make the
            // repeat settings unreachable without sighted aim.
            if focused == item.id {
                Button { HapticsEngine.lightTap(); detail = item } label: {
                    Image(systemName: "info.circle")
                        // The same icon token the plus and the trash beside it
                        // use, so the three controls on this sheet are one size
                        // rather than two.
                        .iconSize(GridConstants.iconToolbar, relativeTo: .body, weight: .medium)
                        .foregroundStyle(AppColors.inkQuiet)
                        // 44pt, the HIG minimum. The glyph plus 8pt of padding
                        // came to 33, which is a control you have to aim at.
                        .frame(width: Self.tapTarget, height: Self.tapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.press)
                .accessibilityLabel("Options for \(item.text)")
                .transition(.opacity)
            }
        }
        // The bullet's 44pt box already carries its own air, so the row's
        // leading margin gives back what the box added — the glyph stays
        // exactly where it was on the page.
        .padding(.leading, GridConstants.horizontalPadding - Self.bulletInset)
        .padding(.trailing, GridConstants.horizontalPadding)
        // 4pt, the grid's gutter. The bullet's 44pt box already carries 10pt of
        // air above and below a 24pt glyph, so the 6 this was added a fifth
        // number to a row whose every other measure comes from the ladder.
        .padding(.vertical, GridConstants.spacing)
        .contentShape(Rectangle())
        .animation(GridConstants.motionSnappy, value: focused)
        // **Swipe left to delete** (2026-10-05). `.swipeActions` only exists
        // inside a `List` and this is a `LazyVStack`, which is why the one
        // that was here once did nothing; `PlanSwipeToDelete` draws the
        // platform's swipe on any row and argues its case. Delete goes
        // through `PlanItem.remove`, the one delete path. A repeating line
        // goes whole, with no "just this one" question:
        // `PlanItem.supportsSingleOccurrenceDelete` says why. No undo: the
        // app has no undo for a delete to join.
        .modifier(PlanSwipeToDelete(
            isOpen: swiped == item.id,
            setOpen: { swiped = $0 ? item.id : (swiped == item.id ? nil : swiped) },
            onDelete: { withAnimation(GridConstants.motionSnappy) { delete(item) } }))
        // And the context menu stays: a long press works in any container,
        // and it is also what keeps both actions reachable on the rows whose
        // info button is not drawn. VoiceOver surfaces a context menu as
        // custom actions, so nothing is hidden behind having to focus the
        // line first.
        .contextMenu {
            Button { detail = item } label: {
                Label("Options", systemImage: "info.circle")
            }
            Button(role: .destructive) { delete(item) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Editing

    private func complete(_ item: PlanItem) {
        guard !item.isDone else {
            // Pressing a finished line puts it back. Nothing here is
            // irreversible, and a tick you cannot undo is a trap.
            item.completedAt = nil
            try? modelContext.save()
            HapticsEngine.lightTap()
            return
        }
        // Checked NOW, not when the win saves: making the tick wait would
        // leave the commonest gesture in the sheet with no visible result
        // until two screens later. It is optimistic, though. Closing the add
        // sheet without saving takes it back (`MainAppView.tickAwaitingWin`),
        // so the plan never claims a block the tower does not have.
        item.completedAt = Date()
        try? modelContext.save()
        HapticsEngine.success()
        Self.tidy(allItems, keeping: focused, context: modelContext)
        onComplete(item)
    }

    /// A new line wears the colour the tower currently has least of, which is
    /// how a win with no category picks one — so a plan reads like the tower
    /// it will become rather than like a list of one colour.
    private func addLine(after item: PlanItem? = nil) {
        // In the function, not at the three call sites that reach it — the
        // plus button, the empty state and the tap below the last line all
        // make the same thing happen and should all feel the same.
        HapticsEngine.tick()
        let colour = QuickWinService.spontaneousCategory(existing: habits)
        let position = (item?.order ?? allItems.last?.order ?? -1) + 1
        for existing in allItems where existing.order >= position {
            existing.order += 1
        }
        let line = PlanItem(text: "", order: position, category: colour)
        modelContext.insert(line)
        try? modelContext.save()
        focused = line.id
    }

    /// Backspace on an empty line removes it and puts the caret on the end of
    /// the line above — the behaviour every bullet list has, and the reason
    /// this uses a `UITextField` at all.
    private func backspace(_ item: PlanItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let previous = index > 0 ? items[index - 1] : nil
        // Lighter than a deliberate delete: this fires while you are typing,
        // and a full tick on every backspace would be noise.
        HapticsEngine.lightTap()
        modelContext.delete(item)
        StoreReset.commitDelete("backspacing a plan line away", context: modelContext)
        focused = previous?.id
    }

    private func delete(_ item: PlanItem) {
        HapticsEngine.tick()
        if focused == item.id { focused = nil }
        if swiped == item.id { swiped = nil }
        PlanItem.remove(item, context: modelContext)
    }

    /// Drops blank lines. An empty bullet you walked away from was never an
    /// item — the one you are still typing in is left alone. The page calls
    /// it on Done and on the way out.
    static func tidy(_ all: [PlanItem], keeping focused: UUID?, context: ModelContext) {
        var dropped = false
        for item in all
        where item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && item.id != focused {
            context.delete(item)
            dropped = true
        }
        if dropped { StoreReset.commitDelete("dropping blank plan lines", context: context) }
    }
}
