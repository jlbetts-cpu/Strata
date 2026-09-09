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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { tidy(); dismiss() }
                        .font(Typography.headerSmall)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { addLine() } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .accessibilityLabel("Add a line")
                }
            }
            .sheet(item: $detail) { item in
                PlanItemDetailSheet(item: item)
            }
        }
        .presentationDragIndicator(.visible)
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
            .padding(.top, 8)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var hint: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nothing planned")
                .font(Typography.headerMedium)
                .foregroundStyle(.primary.opacity(0.6))
            Text("Write what you mean to do. Press its block when you have.")
                .font(Typography.bodySmall)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, GridConstants.horizontalPadding)
        .padding(.top, 28)
    }

    // MARK: - A line

    private func row(_ item: PlanItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Button {
                complete(item)
            } label: {
                PlanBullet(category: item.category, isDone: item.isDone)
                    // A tap target the size of the glyph is not a tap target.
                    .padding(11)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(-11)
            .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 5 }
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
                        .foregroundStyle(.primary.opacity(0.35))
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
                Button { detail = item } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(.primary.opacity(0.34))
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Options for \(item.text)")
                .transition(.opacity)
            }
        }
        .padding(.horizontal, GridConstants.horizontalPadding)
        .padding(.vertical, 13)
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
        modelContext.delete(item)
        try? modelContext.save()
        focused = previous?.id
    }

    private func delete(_ item: PlanItem) {
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
