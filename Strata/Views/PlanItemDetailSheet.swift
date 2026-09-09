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
struct PlanItemDetailSheet: View {
    @Bindable var item: PlanItem

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let calendar = Calendar.current

    /// Monday-first, matching the week the rest of the app groups by.
    private var weekdayOrder: [Int] { [2, 3, 4, 5, 6, 7, 1] }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What do you mean to do?", text: $item.text, axis: .vertical)
                        .font(Typography.bodyLarge)
                }

                Section("Colour") {
                    colours
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
                            Text("Repeats")
                        } icon: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundStyle(AppColors.accentWarm)
                        }
                    }
                    .tint(AppColors.accentWarm)

                    if item.repeats { days }
                } footer: {
                    Text(item.repeats
                         ? "Comes back on these days. Ticking it off keeps it until the day turns."
                         : "A one-off. It clears once the day it was finished is over.")
                }
            }
            .scrollContentBackground(.hidden)
            .background { WarmBackground().ignoresSafeArea() }
            .navigationTitle("Line")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { try? modelContext.save(); dismiss() }
                        .font(Typography.headerSmall)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .destructive) {
                        modelContext.delete(item)
                        try? modelContext.save()
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Delete this line")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Colour

    /// The block it becomes. Shown as blocks, because that is what they are —
    /// a row of swatches would be a picture of a colour, and this is a picture
    /// of the thing.
    private var colours: some View {
        HStack(spacing: 2) {
            ForEach(HabitCategory.selectable, id: \.self) { category in
                Button {
                    item.categoryRaw = category.rawValue
                    HapticsEngine.lightTap()
                } label: {
                    BlockSurface(
                        cornerRadius: GridConstants.blockCornerRadius(forCell: 34),
                        scale: 34 / GridConstants.blockReferenceCell
                    ) {
                        category.style.baseColor
                    }
                    .frame(width: 34, height: 34)
                    .overlay {
                        if item.category == category {
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    }
                    .scaleEffect(item.category == category ? 1.0 : 0.86)
                    .animation(GridConstants.motionSnappy, value: item.category)
                    // The block stays 34pt; what you can hit is 44. A swatch
                    // sized to its own artwork is a swatch you have to aim at.
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(describing: category))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    // MARK: - Days

    private var days: some View {
        HStack(spacing: 4) {
            ForEach(weekdayOrder, id: \.self) { day in
                let on = item.repeatDays.contains(day)
                Button {
                    var set = item.repeatDays
                    if on { set.remove(day) } else { set.insert(day) }
                    item.repeatDays = set
                    HapticsEngine.lightTap()
                } label: {
                    Text(letter(for: day))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(on ? .white : .primary.opacity(0.55))
                        // 44, not 38: seven of them still fit across the
                        // page, and a day you have to aim at is a day you set
                        // by accident.
                        .frame(width: 44, height: 44)
                        .background {
                            RoundedRectangle(cornerRadius: GridConstants.blockCornerRadius(forCell: 44),
                                             style: .continuous)
                                .fill(on ? item.category.style.baseColor : GridConstants.fillWell)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: GridConstants.blockCornerRadius(forCell: 44),
                                             style: .continuous)
                                .strokeBorder(on ? .clear : GridConstants.fillHairline, lineWidth: 1)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(calendar.weekdaySymbols[day - 1])
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
        }
        .animation(GridConstants.motionSnappy, value: item.repeatDaysRaw)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    /// The weekday's own initial, from the locale rather than a hard-coded
    /// "MTWTFSS" — which is wrong in most languages and ambiguous in English.
    private func letter(for day: Int) -> String {
        let symbols = calendar.veryShortWeekdaySymbols
        return symbols.indices.contains(day - 1) ? symbols[day - 1] : "?"
    }
}
