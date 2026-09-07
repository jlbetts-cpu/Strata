import SwiftUI

/// Today, as a checklist.
///
/// This replaces the timeline and the Plan tab. Both were built around
/// arranging the day; the owner's actual habit tracking happens in a
/// spreadsheet, which does none of that and works — one row per thing, a box,
/// and a tick. What that spreadsheet has and the timeline did not is that
/// nothing is between you and the tick.
///
/// So: rows, hairlines, and a checkbox. **Ticking a row drops a block on the
/// tower** — that is the whole loop, and it is why this screen exists at all
/// rather than being a list you maintain.
///
/// Deliberately not here: durations, drag-to-reschedule, a sandbox, a
/// verb-based split, anything that arranges. Scheduling is a field on an item,
/// not a place you go.
///
/// **No cards.** A white rim, a frosted band and a blurred edge say "you built
/// this and it is standing on something", which is a block's claim to make.
/// Rows are separated by a hairline and nothing else — same as the spreadsheet,
/// and it keeps the blocks the only objects in the app with edges.
struct ChecklistView: View {

    let habits: [Habit]
    let completedHabitIDs: Set<UUID>
    let skippedHabitIDs: Set<UUID>
    let events: [CalendarAnchor]
    /// The tower anything added here belongs to.
    let tower: Tower?
    let onComplete: (Habit) -> Void
    let onUndo: (Habit) -> Void
    /// Called after something is added, so the tower can rebuild.
    let onAdded: () -> Void

    /// Owned here rather than passed down: `MainAppView.body` is at the type
    /// checker's ceiling, and a sheet this screen presents about its own rows
    /// has no reason to live up there.
    @State private var editing: Habit?
    @State private var adding = false

    @Environment(\.modelContext) private var modelContext

    private let hPad: CGFloat = 20

    // MARK: - Sections

    /// Things you keep doing. Recurring, so they are the spine of the day.
    private var recurring: [Habit] {
        habits
            .filter { !$0.isTodo && !QuickWinService.isWin($0) }
            .sorted(by: Self.byTimeThenTitle)
    }

    /// Things that belong to today only.
    ///
    /// Wins are excluded: a win is something you already did, logged straight
    /// onto the tower, and it is not an intention for the day.
    private var oneOffs: [Habit] {
        habits
            .filter { $0.isTodo && !QuickWinService.isWin($0) }
            .sorted(by: Self.byTimeThenTitle)
    }

    private static func byTimeThenTitle(_ a: Habit, _ b: Habit) -> Bool {
        let ha = TimelineViewModel.effectiveHour(for: a)
        let hb = TimelineViewModel.effectiveHour(for: b)
        switch (ha, hb) {
        case let (x?, y?): return x == y ? a.title < b.title : x < y
        case (nil, _?):    return false   // untimed sinks below timed
        case (_?, nil):    return true
        default:           return a.title < b.title
        }
    }

    private var tickable: [Habit] { recurring + oneOffs }
    private var doneCount: Int { tickable.filter { completedHabitIDs.contains($0.id) }.count }

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if tickable.isEmpty && events.isEmpty {
                    emptyState
                } else {
                    section("Habits", recurring)
                    section("Today", oneOffs, trailing: addButton)
                    scheduledSection
                }
            }
            .padding(.bottom, 28)
        }
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .sheet(item: $editing) { habit in
            HabitDetailSheet(habit: habit, selectedDate: Date())
        }
        .sheet(isPresented: $adding) {
            AddThingSheet(
                modelContext: modelContext,
                tower: tower,
                onAdded: { _ in onAdded() }
            )
        }
    }

    /// The same shape as the tower's header: one numeral, and what it counts.
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(doneCount)")
                .font(.system(size: 40, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.85))
                .contentTransition(.numericText())
            Text(tickable.isEmpty ? "to do" : "of \(tickable.count) done")
                .font(Typography.bodyMedium)
                .foregroundStyle(.primary.opacity(0.35))
            Spacer(minLength: 0)
        }
        .animation(GridConstants.motionSmooth, value: doneCount)
        .accessibilityElement(children: .combine)
        .padding(.horizontal, hPad)
        .padding(.top, 4)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private func section(_ title: String,
                         _ items: [Habit],
                         trailing: (some View)? = EmptyView?.none) -> some View {
        if !items.isEmpty || title == "Today" {
            HStack(spacing: 0) {
                Text(title)
                    .font(Typography.caption)
                    .foregroundStyle(.primary.opacity(0.32))
                Spacer(minLength: 0)
                trailing
            }
            .padding(.horizontal, hPad)
            .padding(.top, 18)
            .padding(.bottom, 6)

            ForEach(items) { habit in
                ChecklistRow(
                    habit: habit,
                    isDone: completedHabitIDs.contains(habit.id),
                    isSkipped: skippedHabitIDs.contains(habit.id),
                    hPad: hPad,
                    onToggle: {
                        if completedHabitIDs.contains(habit.id) { onUndo(habit) }
                        else { onComplete(habit) }
                    },
                    onOpen: { editing = habit }
                )
                if habit.id != items.last?.id { rowDivider }
            }
        }
    }

    private var addButton: some View {
        Button {
            HapticsEngine.lightTap()
            adding = true
        } label: {
            Image(systemName: "plus")
                .iconSize(GridConstants.iconAction, relativeTo: .caption, weight: .semibold)
                .foregroundStyle(.primary.opacity(0.40))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add something for today")
    }

    /// Real calendar events. Shown, never tickable — they are the shape of the
    /// day, not a claim about it. Ticking someone else's meeting would mean
    /// nothing, and putting a box next to it would invite it.
    @ViewBuilder
    private var scheduledSection: some View {
        let timed = events.filter { !$0.isAllDay }.sorted { $0.startDate < $1.startDate }
        if !timed.isEmpty {
            Text("Scheduled")
                .font(Typography.caption)
                .foregroundStyle(.primary.opacity(0.32))
                .padding(.horizontal, hPad)
                .padding(.top, 18)
                .padding(.bottom, 6)

            ForEach(timed, id: \.id) { event in
                HStack(spacing: 12) {
                    Text(event.startDate, format: .dateTime.hour().minute())
                        .font(Typography.bodySmall)
                        .monospacedDigit()
                        .foregroundStyle(.primary.opacity(0.40))
                        .frame(width: 58, alignment: .leading)
                    Text(event.title)
                        .font(Typography.bodyMedium)
                        .foregroundStyle(.primary.opacity(0.55))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, hPad)
                .padding(.vertical, 11)
                if event.id != timed.last?.id { rowDivider }
            }
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(.primary.opacity(0.06))
            .frame(height: 0.5)
            .padding(.leading, hPad + 34)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("Nothing on today.")
                .font(Typography.headerMedium)
                .foregroundStyle(.primary.opacity(0.6))
            Text("Add something you want to get done,\nor just log it on the tower when you do.")
                .font(Typography.bodySmall)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                HapticsEngine.lightTap()
                adding = true
            } label: {
                Text("Add something")
                    .font(Typography.bodyMedium)
                    .foregroundStyle(.primary.opacity(0.75))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(
                        Capsule(style: .continuous)
                            .fill(AppColors.warmBlack.opacity(0.05))
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

/// One line: a box, a name, and the time if it has one.
private struct ChecklistRow: View {
    let habit: Habit
    let isDone: Bool
    let isSkipped: Bool
    let hPad: CGFloat
    let onToggle: () -> Void
    let onOpen: () -> Void

    private var tint: Color { habit.displayCategory.style.baseColor }

    var body: some View {
        HStack(spacing: 12) {
            // The box carries the category colour, so the checklist is made of
            // the same six colours the tower is built from and needs no legend.
            Button(action: {
                HapticsEngine.lightTap()
                onToggle()
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isDone ? tint : Color.clear)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(
                            isDone ? Color.clear : AppColors.warmBlack.opacity(0.22),
                            lineWidth: 1.5
                        )
                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .animation(GridConstants.tapPopSpring, value: isDone)

            Text(habit.title)
                .font(Typography.bodyMedium)
                .foregroundStyle(.primary.opacity(isDone ? 0.32 : (isSkipped ? 0.28 : 0.85)))
                .strikethrough(isSkipped, color: .primary.opacity(0.28))
                .lineLimit(1)

            Spacer(minLength: 8)

            if let time = habit.scheduledTime {
                Text(time)
                    .font(Typography.caption)
                    .monospacedDigit()
                    .foregroundStyle(.primary.opacity(0.30))
            }
        }
        .padding(.horizontal, hPad)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(habit.title)
        .accessibilityValue(isDone ? "Done" : "Not done")
        .accessibilityAddTraits(.isButton)
    }
}
