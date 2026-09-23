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
struct PlanSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Called with the line when its block is pressed. The caller opens the
    /// add sheet; the line is ticked at once, and the tick is kept only once
    /// a win is actually saved, so backing out of that sheet does not spend it.
    var onComplete: (PlanItem) -> Void

    @Query(sort: \PlanItem.order) private var allItems: [PlanItem]
    @Query private var habits: [Habit]
    @State private var focused: UUID?
    @State private var detail: PlanItem?

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
    /// The tap-to-write space under the last line. Deep enough to be the
    /// obvious place to aim at rather than a strip you find by accident.
    private static let tailHeight: CGFloat = 160

    /// Today's list: everything one-off, plus the repeats due today.
    private var items: [PlanItem] {
        allItems.filter { $0.belongs(on: Date(), calendar: calendar) }
    }

    var body: some View {
        NavigationStack {
            content
                .sheetTitle("Plan", drawn: true)
                .toolbar { planToolbar }
                .sheet(item: $detail) { item in
                    PlanItemDetailSheet(item: item)
                }
        }
        // **Full height, and stated.** It was unstated, which happens to give
        // the same thing, and unstated is how two sheets end up differing
        // without anybody choosing.
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        // The page's own ground, as the sheet's material rather than as a layer
        // inside it. `AddWinSheet` records why: through the default frosted
        // glass the tower's colours bleed up behind the controls, and a frosted
        // surface is the block's material, not a sheet's. This was a
        // `WarmBackground` in a `ZStack`, which covers the content area and
        // leaves the sheet's own material to the system.
        .presentationBackground { WarmBackground().ignoresSafeArea() }
    }

    /// **The same bare glyphs every other screen has.**
    ///
    /// These two were plain `ToolbarItem`s, so on iOS 26 they kept the glass
    /// capsule the system puts behind every toolbar item — which the rest of
    /// the app strips deliberately (see the Toolbars note in `MainAppView`). Two
    /// consequences, and the owner hit both: the plan did not look like the
    /// screens either side of it, and the capsule rendered BLACK against this
    /// sheet's warm ground when it was jostled mid-gesture — "i bumped into
    /// the screen tweaking and the apple glass plan button turned black."
    ///
    /// Typed `ToolbarContent` rather than an inline `.toolbar`, because that
    /// is where the availability gate can live:
    /// `ToolbarContentBuilder` supports `if #available` through
    /// `buildLimitedAvailability`, and an inline one does not.
    @ToolbarContentBuilder
    private var planToolbar: some ToolbarContent {
        // **Done on the right, like every other sheet.** It was on the left,
        // with the plus on the right; Profile, Settings and the win sheet all
        // confirm top-right, so the plan was the one screen where a thumb
        // reaching for Done found a plus. The owner's call (2026-09-13).
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarLeading) { addButton }
                .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .topBarTrailing) { doneButton }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarLeading) { addButton }
            ToolbarItem(placement: .topBarTrailing) { doneButton }
        }
    }

    private var doneButton: some View {
        Button {
            HapticsEngine.lightTap()
            tidy()
            dismiss()
        } label: {
            // **44pt of target, whatever the glyph measures.** Audited from
            // the accessibility tree: Done came out 68x36 and the plus 35x36,
            // both under Apple's minimum — and this is the screen the owner
            // had already called "really easy to miss click". A toolbar button
            // is sized by its label unless it is told otherwise.
            Text("Done")
                .font(Typography.headerSmall)
                .frame(minWidth: Self.tapTarget, minHeight: Self.tapTarget)
                .contentShape(Rectangle())
        }
        .foregroundStyle(AppColors.accentWarm)
    }

    private var addButton: some View {
        Button { addLine() } label: {
            Image(systemName: "plus")
                .iconSize(GridConstants.iconToolbar, relativeTo: .body, weight: .medium)
                .foregroundStyle(AppColors.accentWarm)
                .frame(width: Self.tapTarget, height: Self.tapTarget)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Add a line")
    }

    @ViewBuilder
    private var content: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(items) { item in
                    row(item)
                    // **A hairline in ink, not a `Divider`.** Section 6: chrome
                    // separates with a hairline and with translucency, and a
                    // hairline is `1 / displayScale` in ink at low alpha, never
                    // a grey line. `Divider` draws the platform's separator
                    // colour at the platform's weight, which is the one grey
                    // this page had.
                    Rectangle()
                        .fill(AppColors.quietFill)
                        .frame(height: 1 / displayScale)
                        .padding(.leading, Self.textLeading)
                        .padding(.trailing, GridConstants.horizontalPadding)
                }

                if items.isEmpty { hint }

                // Pressing the empty space below the list starts a new line,
                // which is what a page of bullets does. Without it the only
                // way to add is the button in the corner, and the corner is
                // not where anyone looks when they are writing.
                Color.clear
                    .frame(height: Self.tailHeight)
                    .contentShape(Rectangle())
                    .onTapGesture { addLine() }
                    .accessibilityLabel("Add a line")
                    .accessibilityAddTraits(.isButton)
            }
            .padding(.top, GridConstants.gapTight)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    /// What the page looks like before anything is written on it.
    ///
    /// **Show the line, not a notice.** It was two pieces of grey type in the
    /// corner, which tells you the page is empty — something you can already
    /// see — and gives your hand nothing to aim at. A page of bullets that is
    /// waiting can show one waiting bullet: the same row the real lines use,
    /// ghosted, with the invitation beside it. Tapping anywhere here starts
    /// writing, which is what the empty space below already did and what
    /// nobody could tell.
    private var hint: some View {
        VStack(alignment: .leading, spacing: GridConstants.gapItem) {
            HStack(spacing: GridConstants.spacing) {
                // **A block, not a circle.** This is a ghost of the bullet
                // beside a real line, and that bullet is a BLOCK — the whole
                // point of the plan is that a line becomes one. A dotted
                // circle is a ghost of something the app does not have: "why
                // is there a circle dotted when it should be a square."
                //
                // Same corner rule as the real one, off the same cell size, so
                // the outline is the exact silhouette of what will land in it.
                // **`bulletSide`, not 22.** The comment above is the test and
                // the outline failed it: the bullet that lands here is 24, so a
                // 22pt ghost was the silhouette of nothing, two points off the
                // real one and a point off the page margin with it.
                RoundedRectangle(
                    cornerRadius: GridConstants.blockCornerRadius(forCell: Self.bulletSide),
                    style: .continuous)
                    .strokeBorder(AppColors.slotInk.opacity(0.40),
                                  style: StrokeStyle(lineWidth: GridConstants.strokeDefault,
                                                     dash: [GridConstants.ghostBlockDashLength]))
                    .frame(width: Self.bulletSide, height: Self.bulletSide)
                    .frame(width: Self.tapTarget, height: Self.tapTarget)
                // `radiusMark`, the ladder's rung for a tiny mark. The 3 was
                // a fourth radius for a thing the ladder already answers.
                RoundedRectangle(cornerRadius: GridConstants.radiusMark, style: .continuous)
                    .fill(AppColors.slotInk.opacity(0.10))
                    .frame(width: 150, height: 11)
            }

            Text("Write what you mean to do, then press its block when you have.")
                .font(Typography.bodySmall)
                .foregroundStyle(AppColors.inkSecondary)
                .padding(.leading, GridConstants.gapItem)
        }
        .padding(.leading, GridConstants.horizontalPadding - Self.bulletInset)
        .padding(.trailing, GridConstants.horizontalPadding)
        .padding(.top, GridConstants.gapWide)
        .contentShape(Rectangle())
        .onTapGesture { addLine() }
        .accessibilityElement()
        .accessibilityLabel("Write what you mean to do")
        .accessibilityAddTraits(.isButton)
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
            .buttonStyle(.plain)
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
                    Text(summary)
                        .font(Typography.caption2)
                        .foregroundStyle(AppColors.inkQuiet)
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
                .buttonStyle(.plain)
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
        // A context menu, not `.swipeActions`.
        //
        // Swipe actions only exist inside a `List`, and this is a
        // `LazyVStack` — so the swipe-to-delete that was here did nothing at
        // all. A long press works in any container, and it is also what keeps
        // both actions reachable on the rows whose info button is not drawn:
        // VoiceOver surfaces a context menu as custom actions, so nothing is
        // hidden behind having to focus the line first.
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
        tidy()
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
        modelContext.delete(item)
        StoreReset.commitDelete("deleting a plan line", context: modelContext)
    }

    /// Drops blank lines. An empty bullet you walked away from was never an
    /// item — the one you are still typing in is left alone.
    private func tidy() {
        for item in allItems
        where item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && item.id != focused {
            modelContext.delete(item)
        }
        StoreReset.commitDelete("dropping blank plan lines", context: modelContext)
    }
}
