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

                Section {
                    colours
                } header: {
                    FormSectionLabel("Colour")
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
                    .tint(AppColors.switchOn)

                    if item.repeats { days }
                } footer: {
                    Text(item.repeats
                         ? "Comes back on these days. Ticking it off keeps it until the day turns."
                         : "A one-off. It clears once the day it was finished is over.")
                }
            }
            .scrollContentBackground(.hidden)
            .background { WarmBackground().ignoresSafeArea() }
            .sheetTitle("Line", drawn: false)
            .toolbar { detailToolbar }
        }
        // Half height first, because this sheet is four controls. `AddWinSheet`
        // and `PlanSheet` are `[.large]` and say why; a detail sheet is the one
        // shape in the family that is allowed to be shorter than the page it
        // came from.
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // The same ground the other two sheets declare, so the sheet's own
        // material is the app's page and never the system's frosted glass.
        .presentationBackground { WarmBackground().ignoresSafeArea() }
    }

    // MARK: - Colour

    /// The block it becomes. Shown as blocks, because that is what they are —
    /// a row of swatches would be a picture of a colour, and this is a picture
    /// of the thing.
    private var colours: some View {
        // 4pt, the grid's gutter, as the win sheet's swatches now are. The 2
        // was a sixth spacing value for the same kind of row.
        HStack(spacing: GridConstants.spacing) {
            ForEach(HabitCategory.selectable, id: \.self) { category in
                Button {
                    item.categoryRaw = category.rawValue
                    HapticsEngine.lightTap()
                } label: {
                    BlockSurface(
                        cornerRadius: GridConstants.blockCornerRadius(forCell: Self.swatchSide),
                        scale: Self.swatchSide / GridConstants.blockReferenceCell
                    ) {
                        category.style.baseColor
                    }
                    .frame(width: Self.swatchSide, height: Self.swatchSide)
                    .overlay {
                        if item.category == category {
                            Image(systemName: "checkmark")
                                .font(Typography.headerSmall)
                                .foregroundStyle(.white)
                        }
                    }
                    .scaleEffect(item.category == category ? 1.0 : 0.86)
                    .animation(GridConstants.motionSnappy, value: item.category)
                    // The block stays 34pt; what you can hit is 44. A swatch
                    // sized to its own artwork is a swatch you have to aim at.
                    .frame(width: Self.tapTarget, height: Self.tapTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(describing: category))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, GridConstants.spacing)
    }

    // MARK: - Days

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
                        // the body rung: the two resolve to the same font, and
                        // section 2 of `docs/design-system-future.md` names this
                        // style for "section headings and index labels". A
                        // weekday initial in a chip is an index label. Not
                        // uppercased or kerned here, because the locale already
                        // gives the initial and one letter has nothing to kern.
                        .font(Typography.sectionLabel)
                        .foregroundStyle(on ? .white : AppColors.inkTertiary)
                        // 44, not 38: seven of them still fit across the
                        // page, and a day you have to aim at is a day you set
                        // by accident.
                        .frame(width: Self.tapTarget, height: Self.tapTarget)
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
                .buttonStyle(.plain)
                .accessibilityLabel(calendar.weekdaySymbols[day - 1])
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
        }
        .animation(GridConstants.motionSnappy, value: item.repeatDaysRaw)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, GridConstants.spacing)
    }

    /// The HIG's minimum target, measured not declared. Both rows of controls on
    /// this sheet are this box, whatever their artwork measures.
    private static let tapTarget: CGFloat = 44

    /// A colour swatch's own artwork, the same 34 the win sheet's circles are.
    /// It was typed three times in one expression, once as a radius, once as a
    /// scale and once as a frame.
    private static let swatchSide: CGFloat = 34

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
    @ToolbarContentBuilder
    private var detailToolbar: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarTrailing) { detailDoneButton }
                .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .topBarLeading) { detailDeleteButton }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarTrailing) { detailDoneButton }
            ToolbarItem(placement: .topBarLeading) { detailDeleteButton }
        }
    }

    private var detailDoneButton: some View {
        Button {
            HapticsEngine.lightTap()
            try? modelContext.save()
            dismiss()
        } label: {
            Text("Done").font(Typography.headerSmall)
        }
        .foregroundStyle(AppColors.accentWarm)
    }

    private var detailDeleteButton: some View {
        Button(role: .destructive) {
            HapticsEngine.warning()
            modelContext.delete(item)
            StoreReset.commitDelete("deleting a plan line", context: modelContext)
            dismiss()
        } label: {
            Image(systemName: "trash")
                .iconSize(GridConstants.iconToolbar, relativeTo: .body, weight: .medium)
        }
        .accessibilityLabel("Delete this line")
    }
}
