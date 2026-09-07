import SwiftUI
import SwiftData

/// Adding something you want to do.
///
/// This replaces a form with a title field, a category picker, a recurring /
/// one-time segmented control, a date picker, a "set time" toggle, a time
/// picker, an effort picker, a HealthKit type picker and a threshold picker —
/// eleven controls to say "read a chapter".
///
/// It asks four things, in the order you actually know them, using the same
/// controls as the card you get when you tap a block: a name, a colour, a size,
/// and whether it comes back. **No time.** A time is a promise about when, and
/// nothing in this app does anything with that promise — the tower records
/// what you did, not when you said you would. Scheduling is a field on a thing,
/// not a reason to build a screen.
///
/// No cards, no wells: labels, controls, and space. The blocks are the only
/// objects in the app with edges.
struct AddThingSheet: View {

    let modelContext: ModelContext
    let tower: Tower?
    var onAdded: (Habit) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleFocused: Bool

    @State private var title = ""
    @State private var category: HabitCategory = .health
    @State private var size: BlockSize = .small
    @State private var repeats = false
    @State private var days: Set<DayCode> = Set(DayCode.allCases)

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    TextField("What do you want to do?", text: $title)
                        .font(Typography.headerMedium)
                        .focused($titleFocused)
                        .submitLabel(.done)
                        .onSubmit { save() }

                    field("Colour") { categoryControl }
                    field("Size") { sizeControl }
                    field("Repeat") { repeatControl }

                    if repeats {
                        dayControl
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .navigationTitle("Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { titleFocused = true }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // The page's own background, not the default translucent one. Through
        // frosted glass the tower's colours bleed up behind the controls and
        // the sheet reads as muddy — and a frosted surface is the block's
        // material, not a sheet's.
        .presentationBackground { WarmBackground().ignoresSafeArea() }
    }

    // MARK: - Pieces

    @ViewBuilder
    private func field(_ label: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(.primary.opacity(0.32))
            content()
        }
    }

    /// The same six circles as the block card, so the thing you are making
    /// looks like the thing it becomes.
    private var categoryControl: some View {
        HStack(spacing: 6) {
            ForEach(HabitCategory.selectable, id: \.self) { cat in
                let isSelected = category == cat
                Button {
                    HapticsEngine.tick()
                    withAnimation(GridConstants.motionSmooth) { category = cat }
                } label: {
                    ZStack {
                        Circle()
                            .fill(cat.style.baseColor)
                            .frame(width: 34, height: 34)
                        if let icon = cat.iconName {
                            Image(systemName: icon)
                                .iconSize(13, relativeTo: .footnote, weight: .semibold)
                                .foregroundStyle(.white)
                        }
                        if isSelected {
                            Circle()
                                .strokeBorder(.primary.opacity(0.75), lineWidth: 2)
                                .frame(width: 42, height: 42)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(cat.rawValue)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
    }

    private var sizeControl: some View {
        HStack(spacing: 6) {
            ForEach([BlockSize.small, .medium, .hard], id: \.self) { option in
                let isSelected = size == option
                Button {
                    HapticsEngine.tick()
                    withAnimation(GridConstants.motionSmooth) { size = option }
                } label: {
                    Text(option.effortLabel)
                        .font(Typography.bodySmall)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            isSelected ? AnyShapeStyle(category.style.baseColor)
                                       : AnyShapeStyle(GridConstants.fillTrack),
                            in: RoundedRectangle(cornerRadius: GridConstants.radiusControl, style: .continuous)
                        )
                        .foregroundStyle(isSelected ? .white : .primary)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private var repeatControl: some View {
        HStack(spacing: 6) {
            ForEach([false, true], id: \.self) { option in
                let isSelected = repeats == option
                Button {
                    HapticsEngine.tick()
                    withAnimation(GridConstants.motionSmooth) { repeats = option }
                } label: {
                    Text(option ? "Repeats" : "Just today")
                        .font(Typography.bodySmall)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            isSelected ? AnyShapeStyle(category.style.baseColor)
                                       : AnyShapeStyle(GridConstants.fillTrack),
                            in: RoundedRectangle(cornerRadius: GridConstants.radiusControl, style: .continuous)
                        )
                        .foregroundStyle(isSelected ? .white : .primary)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    /// Weekdays, in the order a week is read. Defaults to all seven, because
    /// something you are adding as a habit is usually something you mean to do.
    private var dayControl: some View {
        HStack(spacing: 5) {
            ForEach([DayCode.mo, .tu, .we, .th, .fr, .sa, .su], id: \.self) { day in
                let isOn = days.contains(day)
                Button {
                    HapticsEngine.tick()
                    withAnimation(GridConstants.motionSmooth) {
                        if isOn { days.remove(day) } else { days.insert(day) }
                    }
                } label: {
                    Text(String(day.rawValue.prefix(1)))
                        .font(Typography.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            isOn ? AnyShapeStyle(category.style.baseColor.opacity(0.85))
                                 : AnyShapeStyle(GridConstants.fillTrack),
                            in: RoundedRectangle(cornerRadius: GridConstants.radiusControl, style: .continuous)
                        )
                        .foregroundStyle(isOn ? .white : .primary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.rawValue)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }

    // MARK: - Save

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let today = DateUtils.dateString(from: Date())
        let habit = Habit(
            title: trimmed,
            category: category,
            blockSize: size,
            frequency: repeats ? Array(days) : [],
            isTodo: !repeats,
            scheduledDate: repeats ? nil : today
        )
        habit.tower = tower
        modelContext.insert(habit)
        try? modelContext.save()
        HapticsEngine.success()
        onAdded(habit)
        dismiss()
    }
}
