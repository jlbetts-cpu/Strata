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

    /// Monday-first, matching the week the rest of the app groups by.
    private var weekdayOrder: [Int] { [2, 3, 4, 5, 6, 7, 1] }

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

                Section {
                    Toggle(isOn: Binding(
                        get: { item.repeats },
                        set: { on in
                            // Turning it on with no days chosen would be a
                            // repeat that never repeats. Weekdays is the
                            // commonest answer and the easiest to correct.
                            item.repeatDays = on ? [2, 3, 4, 5, 6] : []
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
                // `repeatDays` to [2, 3, 4, 5, 6] — Monday to Friday, not
                // every day — so "daily" would describe something the control
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
        HStack(spacing: GridConstants.spacing) {
            ForEach(weekdayOrder, id: \.self) { day in
                let on = item.repeatDays.contains(day)
                Button {
                    var set = item.repeatDays
                    if on { set.remove(day) } else { set.insert(day) }
                    item.repeatDays = set
                    HapticsEngine.lightTap()
                } label: {
                    Text(letter(for: day))
                        // `sectionLabel` is the token, not a weight bolted on to
                        // the body rung: section 2 of
                        // `docs/design-system-future.md` names this style for
                        // "section headings and index labels", and a weekday
                        // initial in a chip is an index label. Not uppercased or
                        // kerned here, because the locale already gives the
                        // initial and one letter has nothing to kern.
                        //
                        // It moved 13 -> 15 with the token on 2026-10-01. The
                        // chip is 44pt and a single letter is about 10pt wide at
                        // 15, so the seven of them still fit across the page.
                        .font(Typography.sectionLabel)
                        .foregroundStyle(on ? .white : AppColors.inkTertiary)
                        // 44, not 38: seven of them still fit across the
                        // page, and a day you have to aim at is a day you set
                        // by accident.
                        // **At most 44 wide, not exactly 44** (design review,
                        // 2026-10-02). Seven fixed 44s and six 4pt gutters are
                        // 332pt, and a grouped Form row on a 402pt phone offers
                        // 334: two points of room, and on a 375pt SE about 307,
                        // so the row ran 25pt past its card. Capped rather than
                        // fixed, every chip is still 44 on this phone and they
                        // share what there is on a smaller one, keeping the
                        // 44pt height that makes them a target.
                        .frame(maxWidth: Self.tapTarget)
                        .frame(height: Self.tapTarget)
                        .background {
                            Self.dayShape
                                .fill(on ? item.category.style.baseColor : GridConstants.fillWell)
                        }
                        .overlay {
                            Self.dayShape
                                .strokeBorder(on ? .clear : GridConstants.fillHairline,
                                              lineWidth: GridConstants.strokeThin)
                        }
                        .contentShape(Rectangle())
                }
                // The app's press. `PressResponse.press` had zero call sites
                // and this is one of the controls its own doc argues for: a chip
                // with no background to shift under it, where the dim is the
                // answer and the scale is what sells it.
                .buttonStyle(.press)
                .accessibilityLabel(calendar.weekdaySymbols[day - 1])
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
        }
        .animation(GridConstants.motionSnappy, value: item.repeatDaysRaw)
        .frame(maxWidth: .infinity, alignment: .leading)
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

    /// One shape for a day chip's fill and its edge, off the block ladder, since
    /// a chip that can hold a block's colour is drawn with a block's corner. It
    /// was written out twice with the same arguments, which is how two copies of
    /// one radius start to disagree.
    private static var dayShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: GridConstants.blockCornerRadius(forCell: tapTarget),
                         style: .continuous)
    }

    /// The weekday's own initial, from the locale rather than a hard-coded
    /// "MTWTFSS" — which is wrong in most languages and ambiguous in English.
    private func letter(for day: Int) -> String {
        let symbols = calendar.veryShortWeekdaySymbols
        return symbols.indices.contains(day - 1) ? symbols[day - 1] : "?"
    }

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
            try? modelContext.save()
            dismiss()
        } label: {
            Text("Done").sheetAction()
        }
        .buttonStyle(.pressWord)
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
