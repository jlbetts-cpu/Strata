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
    /// add sheet; the line is marked done only once a win is actually saved,
    /// so backing out of that sheet does not spend it.
    var onComplete: (PlanItem) -> Void

    @Query(sort: \PlanItem.order) private var allItems: [PlanItem]
    @Query private var habits: [Habit]
    @State private var focused: UUID?
    @State private var detail: PlanItem?

    private let calendar = Calendar.current

    /// Today's list: everything one-off, plus the repeats due today.
    private var items: [PlanItem] {
        allItems.filter { $0.belongs(on: Date(), calendar: calendar) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackground().ignoresSafeArea()
                content
            }
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { planToolbar }
            .sheet(item: $detail) { item in
                PlanItemDetailSheet(item: item)
            }
        }
        .presentationDragIndicator(.visible)
    }

    /// **The same bare glyphs every other screen has.**
    ///
    /// These two were plain `ToolbarItem`s, so on iOS 26 they kept the glass
    /// capsule the system puts behind every toolbar item — which the rest of
    /// the app strips deliberately (see `MainAppView.todayToolbar`). Two
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
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarLeading) { doneButton }
                .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .topBarTrailing) { addButton }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarLeading) { doneButton }
            ToolbarItem(placement: .topBarTrailing) { addButton }
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
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .foregroundStyle(AppColors.accentWarm)
    }

    private var addButton: some View {
        Button { addLine() } label: {
            Image(systemName: "plus")
                .iconSize(GridConstants.iconToolbar, relativeTo: .body, weight: .medium)
                .foregroundStyle(AppColors.accentWarm)
                .frame(width: 44, height: 44)
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
                    Divider()
                        .padding(.leading, GridConstants.horizontalPadding + 24 + 14)
                        .padding(.trailing, GridConstants.horizontalPadding)
                }

                if items.isEmpty { hint }

                // Pressing the empty space below the list starts a new line,
                // which is what a page of bullets does. Without it the only
                // way to add is the button in the corner, and the corner is
                // not where anyone looks when they are writing.
                Color.clear
                    .frame(height: max(160, 44))
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
                RoundedRectangle(
                    cornerRadius: GridConstants.blockCornerRadius(forCell: 22),
                    style: .continuous)
                    .strokeBorder(AppColors.slotInk.opacity(0.40),
                                  style: StrokeStyle(lineWidth: 1.5,
                                                     dash: [GridConstants.ghostBlockDashLength]))
                    .frame(width: 22, height: 22)
                    .frame(width: 44, height: 44)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(AppColors.slotInk.opacity(0.10))
                    .frame(width: 150, height: 11)
            }

            Text("Write what you mean to do, then press its block when you have.")
                .font(Typography.bodySmall)
                .foregroundStyle(AppColors.inkSecondary)
                .padding(.leading, GridConstants.gapItem)
        }
        .padding(.leading, GridConstants.horizontalPadding - 11)
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
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
                        .font(Typography.bodyLarge)
                        .foregroundStyle(AppColors.inkQuiet)
                        // 44pt, the HIG minimum. The glyph plus 8pt of padding
                        // came to 33, which is a control you have to aim at.
                        .frame(width: 44, height: 44)
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
        .padding(.leading, GridConstants.horizontalPadding - 11)
        .padding(.trailing, GridConstants.horizontalPadding)
        .padding(.vertical, 6)
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
        // Checked NOW, not when the win saves. Pressing the block is the act
        // of finishing the line; the add sheet that follows is an offer to
        // also put it on the tower, and it has a Cancel button for a reason.
        // Making the tick wait on that would leave the commonest gesture in
        // the sheet with no visible result until two screens later.
        //
        // Nothing is lost by being wrong: pressing a finished line unchecks
        // it again.
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
        try? modelContext.save()
        focused = previous?.id
    }

    private func delete(_ item: PlanItem) {
        HapticsEngine.tick()
        if focused == item.id { focused = nil }
        modelContext.delete(item)
        try? modelContext.save()
    }

    /// Drops blank lines. An empty bullet you walked away from was never an
    /// item — the one you are still typing in is left alone.
    private func tidy() {
        for item in allItems
        where item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && item.id != focused {
            modelContext.delete(item)
        }
        try? modelContext.save()
    }
}
