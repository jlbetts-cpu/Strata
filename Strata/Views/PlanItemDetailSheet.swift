import SwiftUI
import SwiftData

/// One plan line, opened: what it says, what colour it will be, and the days
/// it comes back on.
///
/// Reminders puts this behind an info button and so does this, for the same
/// reason: the list is for writing, and anything that competes with typing
/// belongs off the list. What is NOT here is everything a to-do app usually
/// adds next — due dates, times, priorities, notes, subtasks, lists. A plan
/// line is a block you have not built yet; the only fact about it that the
/// text cannot carry is which days it comes round.
///
/// **And the one thing you can do to it that is not a property of it**, which is
/// delete it. That used to be a trash glyph in the leading toolbar slot, where
/// every other sheet in the app puts Cancel, and it deleted on one press with no
/// confirmation; it is a `Form` row at the foot of the sheet now, in the shape
/// Settings and Profile already give a destructive row, and it asks first. See
/// `deleteRow`, and `docs/consistency-audit.md` §1.5.
struct PlanItemDetailSheet: View {
    @Bindable var item: PlanItem

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// **A plan line's delete confirms, like four of the app's other six**
    /// (2026-10-01, `docs/consistency-audit.md` §1.5). It used to commit and
    /// dismiss on one press.
    @State private var confirmingDelete = false

    private let calendar = Calendar.current
    /// The day a one-off had before Repeats was switched on in this
    /// sitting, so switching it off again puts the line back where it was.
    @State private var dayBefore: String?
    /// The words and the repeat this sheet opened on, for `PlanRename`.
    @State private var nameBefore: String
    @State private var repeatedBefore: Bool
    /// Done, on a repeating line whose words changed: today, or every time.
    @State private var askingScope = false

    /// **Read as the sheet is made**, not when a toolbar button appears
    /// (found by review, 2026-10-13): had that never fired, Done would
    /// never have asked, and said nothing about it.
    init(item: PlanItem) {
        self.item = item
        _nameBefore = State(initialValue: item.text)
        _repeatedBefore = State(initialValue: item.repeats)
    }

    /// Whether leaving now has a question to answer first (`PlanRename`).
    private var asksScope: Bool {
        let today = Date()
        return PlanRename.asks(repeated: repeatedBefore, repeats: item.repeats, before: nameBefore, now: item.text,
                               onToday: item.isOpen(on: today, calendar: calendar, today: today)
                                   && !PlanSkips.isSkipped(item, on: today),
                               isCrewPlan: GroupPlanBook.crew(forPlanItem: item.id) != nil)
    }

    /// Monday-first, matching the week the rest of the app groups by.

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // **"What do you mean to do?" diverges from the add
                    // sheet's "What did you do?" by one word, and that is
                    // correct** (`docs/copy-audit.md` number 20, flagged so
                    // nobody tidies it into a match). A plan is the future and
                    // a win is the past; the tense is the whole difference
                    // between the two screens. It is also rarely seen — you
                    // arrive at this sheet from a line you already typed.
                    //
                    // **The two fixes `AddWinSheet.nameField` already carries,
                    // which this field did not** (2026-10-01, from the owner's
                    // "make sure screens are consistent"). They are the same
                    // two faults, measured there and never applied here:
                    //
                    // - A bare `TextField`'s own placeholder renders
                    //   (190, 190, 192) on a (247, 247, 247) page, which is
                    //   **1.73:1** — under even the 3:1 a plain UI element is
                    //   held to, let alone the 4.5 of the sentence it stands in
                    //   for. A `prompt` is the only way to colour it without
                    //   rebuilding the field, and `inkQuiet` is the token for a
                    //   placeholder and measures 3.3:1.
                    // - With no `foregroundStyle` the TEXT falls through to
                    //   `UIColor.label`, which is pure (0, 0, 0) on light and
                    //   pure (255, 255, 255) on dark: 18.91:1 where every other
                    //   ink in this app is `inkPrimary` at 13.81. That one is
                    //   seen every time, since you arrive here from a line you
                    //   have already written.
                    TextField(
                        "What do you mean to do?",
                        text: $item.text,
                        // `inkTertiary`, not `inkQuiet`: the add sheet's
                        // prompt measured 3.35:1 in `inkQuiet` against the 4.5
                        // a sentence is held to (design review, 2026-10-02).
                        prompt: Text("What do you mean to do?")
                            .foregroundStyle(AppColors.inkTertiary),
                        axis: .vertical
                    )
                        .font(Typography.bodyLarge)
                        .foregroundStyle(AppColors.inkPrimary)
                }

                Section {
                    // **One component, two sheets** (2026-10-01,
                    // `docs/consistency-audit.md` §1.1, and the owner's own
                    // instance of it: "I see the colour on the plan isnt the
                    // same as the wins edit sheet with the icons and stuff").
                    //
                    // This was a private `BlockSurface` build that differed from
                    // the add sheet's row on four axes at once — rounded square
                    // against circle, no glyph against six, a white checkmark
                    // and a 0.86 scale against a ring. Every one of those
                    // arguments, and which way each went, is on `ColourSwatch`.
                    //
                    // **The `FormSectionLabel("Colour")` went with the change,
                    // not independently of it.** The argument that used to stand
                    // here was sound for what was drawn: "the add sheet's discs
                    // sit directly above the block they colour, so pressing one
                    // demonstrates what the row sets ... nothing here
                    // demonstrates anything. Cut a label when the screen
                    // performs it; keep it when the screen only states it." With
                    // the glyphs on, each chip names its own category, so the
                    // row is no longer six anonymous pastels — it states what it
                    // is, and the heading became the same fact a third time
                    // after the colour and the symbol. The word is kept for
                    // VoiceOver on the row's own accessibility container.
                    ColourSwatchRow(category: Binding(
                        get: { item.category },
                        set: { item.categoryRaw = $0.rawValue }
                    ))
                    // The row is 44pt boxes; this is the air between the card's
                    // own edge and them, which the `Form` does not give a bare
                    // control. `spacing`, the grid's gutter, as it was.
                    .padding(.vertical, GridConstants.spacing)
                }

                // **Which day it is for**, when it is for one (2026-10-10):
                // the row of days the plan has, so a line can be moved from
                // where it is edited. A day off the row (one gone by, or
                // more than a week on) shows none chosen until one is.
                // Not on a line already done: it is today's by having been
                // done today, and a day chosen here would show nothing.
                if !item.repeats, item.completedAt == nil {
                    Section {
                        PlanScopeRow(scope: Binding(
                            // A line from before lines had days is today's.
                            get: { PlanScope.of(day: item.day) ?? (item.day == nil ? .day(0) : .day(-1)) },
                            set: { chosen in
                                if let date = chosen.date() { item.day = DateUtils.dateString(from: date) }
                            }
                        ), choices: PlanScope.days, margin: 0)
                        .listRowInsets(EdgeInsets(top: 0, leading: GridConstants.gapTight, bottom: 0,
                                                  trailing: GridConstants.gapTight))
                    }
                }

                Section {
                    Toggle(isOn: Binding(
                        get: { item.repeats },
                        set: { on in
                            // **On, it repeats on the day it is already
                            // on** (found by review, 2026-10-11). It became
                            // Monday to Friday whatever day it had, so a
                            // line planned for Saturday left Saturday the
                            // moment the switch was pressed, and one for
                            // today left today's tower at a weekend. The
                            // chips are directly under the switch for more.
                            // **Off, it goes back to the day it had**, when
                            // this sheet is what took it off that day and
                            // the day has not gone by; otherwise today, as
                            // it always did.
                            if on {
                                dayBefore = item.day
                                let date = item.day.flatMap { DateUtils.date(from: $0) } ?? Date()
                                item.repeatDays = [calendar.component(.weekday, from: date)]
                            } else {
                                item.repeatDays = []
                                if let dayBefore, dayBefore >= DateUtils.dateString(from: Date()) {
                                    item.day = dayBefore
                                }
                                dayBefore = nil
                            }
                        }
                    )) {
                        Label {
                            // The app's ink, not `UIColor.label`: unstyled, this
                            // one word measured pure (0, 0, 0) on light and
                            // (255, 255, 255) on dark off the built sheet, the
                            // only pure ink on it (design review, 2026-10-02).
                            Text("Repeats")
                                .foregroundStyle(AppColors.inkPrimary)
                        } icon: {
                            // **`SettingsIcon`, the app's one form glyph**
                            // (2026-10-01, `docs/consistency-audit.md` §1.10 —
                            // "the icons and stuff" half of the owner's own
                            // sentence, on the sheet he was looking at).
                            //
                            // Three `Form`s in the app. Two drew every row glyph
                            // through this component, whose 32pt box is what
                            // lifts a row over 44pt, and the third had one glyph
                            // and drew it by hand: at the `Label`'s own fixed
                            // size, so it did not grow with the user's text size,
                            // in `accentWarm` — a near-black, three steps darker
                            // than every other glyph in the app.
                            SettingsIcon(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                    // **`AppColors.switchTrack`, the app's one ON track**
                    // (2026-10-01, `docs/consistency-audit.md` §1.3). This was
                    // `switchOn`, the blue the owner removed by name, and it was
                    // one of the eleven switches the app tinted two different
                    // ways. The audit's own verdict was `inkPrimary`; the token's
                    // doc is the measurement that overrules it — ink in dark mode
                    // composites to rgb(237) and reads **1.17:1** against a
                    // switch's white thumb, which is the "white on white just
                    // looks like a pill" fault the owner already reported once.
                    .tint(AppColors.switchTrack)

                    if item.repeats { days }
                }

                // **THE FOOTER IS DELETED** (2026-10-01, `docs/copy-audit.md`
                // number 3 — the worst copy ratio in the app, 32 of this
                // sheet's 36 words cuttable).
                //
                // It read "Comes back on these days. Ticking it off keeps it
                // until the day turns." or "A one-off. It clears once the day
                // it was finished is over.": 25 words explaining the two
                // states of ONE switch, on a sheet whose entire content is a
                // text field, a colour row and that switch. The switch's own
                // label is the fact, and when it is on the seven day chips
                // directly under it say which days, which "these days" does
                // not.
                //
                // **The audit's own suggestion was to make the row read
                // `Repeats` / `Repeats daily`, and that is NOT taken, because
                // it would be untrue.** Turning the switch on sets
                // `repeatDays` to the one weekday the line is on, not every
                // day, so "daily" would describe something the control
                // does not do. `Repeats` is true in both states, and what it
                // repeats on is drawn rather than written.
                //
                // The one genuinely non-obvious fact in there, that a ticked
                // line stays until the day turns, is not lost and was in the
                // wrong place: it is true of EVERY line on the plan, repeating
                // or not, so it belongs to the plan and not to this switch.
                // `PlanLines`'s own type documentation carries it.

                Section { deleteRow }
            }
            .scrollContentBackground(.hidden)
            .background { WarmBackground().ignoresSafeArea() }
            .sheetTitle("Line", drawn: false)
            .toolbar { detailToolbar }
        }
        // Half height first, because this sheet is four controls. `AddWinSheet`
        // and `PlanLines` are `[.large]` and say why; a detail sheet is the one
        // shape in the family that is allowed to be shorter than the page it
        // came from.
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // **The question cannot be walked past** (found by review,
        // 2026-10-13): the words are written straight onto the line, so a
        // swipe down kept the new name for every day without asking. While
        // there is something to ask, the sheet leaves by Done.
        .interactiveDismissDisabled(asksScope)
        // The same ground the other two sheets declare, so the sheet's own
        // material is the app's page and never the system's frosted glass.
        .presentationBackground { WarmBackground().ignoresSafeArea() }
    }

    // MARK: - Days

    /// **The day chips fill rather than ring, and that is declared rather than
    /// drifted** (2026-10-01, `docs/consistency-audit.md` §3.2).
    ///
    /// The audit counted ten answers to "this is selected" and this is one of
    /// them. It is the only MULTI-select in the app: six colour chips are one of
    /// six, where seven days are any of seven, and a ring that can be on all
    /// seven at once is a row of outlines rather than a state. A filled chip
    /// reads as on/off at a glance across a row, which is why every calendar and
    /// reminder app draws it this way. **The colour row next to it is the one
    /// that had to collapse onto the ring**, and it has.
    ///
    /// What it fills WITH is the line's own category colour, so the two controls
    /// on this sheet are linked: pressing a colour above changes the seven chips
    /// below, which is the sheet saying out loud that a repeat is a block of that
    /// colour coming back.
    private var days: some View {
        // The app's one weekday chip (`WeekdayChips`), in the line's colour.
        // It was drawn here by hand from the same numbers, and came out a
        // different shape from the one under the add sheet's name.
        WeekdayChips(days: Binding(get: { item.repeatDays }, set: { item.repeatDays = $0 }),
                     tint: item.category.style.baseColor)
            .padding(.vertical, GridConstants.spacing)
    }

    /// The HIG's minimum target, measured not declared. Every control on this
    /// sheet is this box, whatever its artwork measures.
    ///
    /// **"Both rows" was the old wording and it was the bug** (2026-10-01).
    /// The colour row and the day row each carried this; the TOOLBAR did not,
    /// so Done and the trash were sized by their own labels. `PlanLines`, which
    /// is the sheet this one opens from, has the audit on it: read off the
    /// accessibility tree a toolbar Done came out 68x36 and a toolbar plus
    /// 35x36, both under the minimum, on the screen the owner had already
    /// called "really easy to miss click". The fix was applied there and never
    /// here.
    private static let tapTarget: CGFloat = 44

    /// See the Toolbars note in `MainAppView` — iOS 26's glass capsule behind every
    /// toolbar item, stripped so these read as bare glyphs like the rest of
    /// the app. One of three screens that had been missed.
    /// **The leading slot is EMPTY, and that is the fix** (2026-10-01,
    /// `docs/consistency-audit.md` §1.5).
    ///
    /// It held a trash glyph that deleted the line, committed and dismissed in
    /// one press — from the position every other sheet in the app uses to back
    /// out of itself. `AddWinSheet` puts Cancel there and `PlanLines`, which is
    /// the sheet directly behind this one, puts ＋ there. A thumb that has
    /// learned either of those finds a delete with no confirmation.
    ///
    /// **And it cannot become Cancel**, which is the obvious symmetry: this
    /// sheet edits a `@Bindable` model object in place, so there is nothing to
    /// cancel — the change is already made, and Done only saves the context. One
    /// empty slot and a confirm, which is exactly what Profile does for the same
    /// reason.
    @ToolbarContentBuilder
    private var detailToolbar: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarTrailing) { detailDoneButton }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarTrailing) { detailDoneButton }
        }
    }

    /// `SheetActionLabel`, which is the ink, the tier and the 44pt box that six
    /// sheets each answered their own way. See `SheetAction.swift`.
    private var detailDoneButton: some View {
        Button {
            HapticsEngine.lightTap()
            if asksScope {
                askingScope = true
            } else {
                try? modelContext.save()
                dismiss()
            }
        } label: {
            Text("Done").sheetAction()
        }
        .buttonStyle(.pressWord)
        // Hung on the button: iOS 26 draws a dialog from the view it hangs
        // on, and from a whole sheet it can fail to appear (`CrewTowerView`).
        .confirmationDialog("This one repeats", isPresented: $askingScope, titleVisibility: .visible) {
            Button("Just Today") {
                PlanRename.justToday(item, before: nameBefore, context: modelContext)
                dismiss()
            }
            Button("Every Time") {
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    /// **The delete, in the shape the app's other two `Form` deletes already
    /// have** (2026-10-01, `docs/consistency-audit.md` §1.5 and §3.3).
    ///
    /// §3.3 counted six shapes of destructive action, three reds and two with no
    /// confirmation. This was one of the two unconfirmed ones. What it becomes is
    /// not a seventh shape: Settings' Reset All Data and Profile's Delete head are
    /// both a `Form` row with `Button(role: .destructive)`, a `SettingsIcon` in
    /// `warmRed` and the word in `warmRed` too, and both confirm. This sheet is a
    /// `Form`, so it gets the `Form` shape. **The shape follows the container**,
    /// which is a rule rather than a tie-break, and it is why `AddWinSheet`'s
    /// delete is the platform's `.bordered` button instead: that sheet is a
    /// `ScrollView`.
    ///
    /// **One red on the row, not two**, which is the fix both of those rows
    /// carry in their own words: the destructive role tints the WORD the system's
    /// #FF3B30, four points off the glyph's red, so the glyph and the word beside
    /// it were two reds on one line.
    ///
    /// **And the red is `AddWinSheet.destructiveTint`, not `AppColors.warmRed`,
    /// which is where this row leaves its two siblings — on a measurement.**
    /// Matching them was the plan, and then the ink was sampled off the built
    /// sheet against the `Form` card it actually stands on, rgb(228) in light:
    ///
    /// |  | light card | dark card |
    /// |---|---|---|
    /// | `warmRed` #E85D4A | **2.71:1** | 4.05:1 |
    /// | the system's #FF3B30 | **2.79:1** | — |
    /// | `destructiveTint` | **5.65:1** | **4.60:1** |
    ///
    /// A 17pt word is held to 4.5 and a shape to 3. `warmRed` misses both ends of
    /// that on the light page, so Settings' Reset All Data and Profile's Delete
    /// head are **both shipping a destructive word at 2.71:1 right now** — two
    /// rows in files this pass does not own, and the one number in this table that
    /// needs somebody's attention more than this row did.
    ///
    /// `destructiveTint` is the app's one MEASURED destructive ink, it carries a
    /// `userInterfaceStyle` branch where `warmRed` is a fixed hex, and its own doc
    /// is four paragraphs of the arithmetic that chose both values. **It wants to
    /// be `AppColors.destructiveInk`** and live in the palette rather than on a
    /// sheet; `CategoryColors.swift` was held by another worker for this whole
    /// session, so it is read through its owner here and the move is a rename.
    private var deleteRow: some View {
        Button(role: .destructive) {
            HapticsEngine.lightTap()
            confirmingDelete = true
        } label: {
            Label {
                Text("Delete Line").foregroundStyle(AddWinSheet.destructiveTint)
            } icon: {
                SettingsIcon(systemName: "trash", tint: AddWinSheet.destructiveTint)
            }
        }
        .confirmationDialog("Delete this line?",
                            isPresented: $confirmingDelete,
                            titleVisibility: .visible) {
            Button("Delete Line", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) { }
        } message: {
            // **Short, because what it destroys is small.** Reset All Data's
            // message runs to 23 words because it empties the store; this takes
            // away a line you have not built yet, so the sentence is the one fact
            // the title does not already carry: that it does not come back.
            Text("It will not come back.")
        }
    }

    private func delete() {
        HapticsEngine.warning()
        modelContext.delete(item)
        StoreReset.commitDelete("deleting a plan line", context: modelContext)
        dismiss()
    }
}
