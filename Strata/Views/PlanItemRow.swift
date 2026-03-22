import SwiftUI

struct PlanItemRow: View {
    let item: PlanItem
    let isExpanded: Bool
    let schedule: String
    let onTapOptions: () -> Void
    let onDelete: () -> Void
    let onUpdateCategory: (HabitCategory) -> Void
    let onUpdateSize: (BlockSize) -> Void
    let onUpdateDays: (Set<DayCode>) -> Void
    let onToggleTodo: () -> Void
    let onUpdateTime: (String?) -> Void

    private let categories = HabitCategory.allCases

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            Button(action: onTapOptions) {
                HStack(spacing: 12) {
                    // Category icon circle (NN/g: color+icon = 37% faster scanning)
                    ZStack {
                        Circle()
                            .fill(item.habit.category.style.baseColor)
                            .frame(width: 20, height: 20)
                        Image(systemName: item.habit.category.iconName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .animation(.easeInOut(duration: 0.2), value: item.habit.category)

                    Text(item.habit.title)
                        .font(Typography.bodyLarge)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    Text(schedule)
                        .font(Typography.bodySmall)
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.quaternary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isExpanded)
                        .accessibilityHidden(true)
                }
                .padding(.leading, CGFloat(item.indentLevel) * 16)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            // Expanded options (spacing-only hierarchy, no dividers — Gestalt Proximity)
            if isExpanded {
                expandedOptions
                    .transition(.opacity)
                    .padding(.leading, CGFloat(item.indentLevel) * 16)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.habit.title), \(item.habit.category.rawValue), \(schedule)")
    }

    // MARK: - Expanded Options (24pt spacing between labeled sections)

    @ViewBuilder
    private var expandedOptions: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Category
            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(Typography.bodySmall)
                    .foregroundStyle(.secondary)
                categoryPicker
            }

            // Effort
            VStack(alignment: .leading, spacing: 8) {
                Text("Effort")
                    .font(Typography.bodySmall)
                    .foregroundStyle(.secondary)
                effortPicker
            }

            // Schedule (recurring only)
            if !item.habit.isTodo {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Schedule")
                        .font(Typography.bodySmall)
                        .foregroundStyle(.secondary)
                    dayPicker
                }
            }

            // Time
            VStack(alignment: .leading, spacing: 8) {
                Text("Time")
                    .font(Typography.bodySmall)
                    .foregroundStyle(.secondary)
                timePicker
            }

            // Actions (no label)
            actionsRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Category Picker (with labels)

    @ViewBuilder
    private var categoryPicker: some View {
        HStack(spacing: 0) {
            ForEach(categories, id: \.self) { cat in
                let isSelected = item.habit.category == cat
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        onUpdateCategory(cat)
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(cat.style.baseColor)
                                .frame(width: 36, height: 36)
                            Image(systemName: cat.iconName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .overlay(
                            Circle()
                                .stroke(Color.primary, lineWidth: isSelected ? 2 : 0)
                                .frame(width: 40, height: 40)
                        )
                        Text(categoryLabel(cat))
                            .font(Typography.caption)
                            .foregroundStyle(isSelected ? .primary : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(cat.rawValue)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    // MARK: - Effort Picker (block shapes, equal width)

    @ViewBuilder
    private var effortPicker: some View {
        HStack(spacing: 8) {
            effortPill("Easy", detail: "15m", size: .small)
            effortPill("Medium", detail: "30m", size: .medium)
            effortPill("Hard", detail: "60m", size: .hard)
        }
    }

    // MARK: - Day Picker (equal spacing)

    @ViewBuilder
    private var dayPicker: some View {
        HStack(spacing: 0) {
            ForEach(DayCode.allCases, id: \.self) { day in
                let isSelected = item.habit.frequency.contains(day)
                Button {
                    var days = Set(item.habit.frequency)
                    if isSelected { days.remove(day) } else { days.insert(day) }
                    onUpdateDays(days)
                } label: {
                    Text(day.rawValue)
                        .font(Typography.bodySmall)
                        .foregroundStyle(isSelected ? .white : Color.primary)
                        .frame(width: 32, height: 32)
                        .background(
                            isSelected ? item.habit.category.style.baseColor : Color.primary.opacity(0.06),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(fullDayName(day))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    // MARK: - Time Picker

    @ViewBuilder
    private var timePicker: some View {
        let hasTime = item.habit.scheduledTime != nil

        Toggle(isOn: Binding(
            get: { hasTime },
            set: { newValue in
                if newValue {
                    // Default to 9:00 AM
                    onUpdateTime("09:00")
                } else {
                    onUpdateTime(nil)
                }
            }
        )) {
            Text("Set time")
                .font(Typography.bodyMedium)
        }
        .tint(item.habit.category.style.baseColor)

        if let timeStr = item.habit.scheduledTime {
            DatePicker(
                "",
                selection: Binding(
                    get: {
                        let parts = timeStr.split(separator: ":")
                        guard let h = Int(parts.first ?? ""), let m = Int(parts.last ?? "") else { return Date.now }
                        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date.now)
                        comps.hour = h
                        comps.minute = m
                        return Calendar.current.date(from: comps) ?? Date.now
                    },
                    set: { newDate in
                        let cal = Calendar.current
                        let h = cal.component(.hour, from: newDate)
                        let m = cal.component(.minute, from: newDate)
                        onUpdateTime(String(format: "%02d:%02d", h, m))
                    }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
        }
    }

    // MARK: - Actions Row

    @ViewBuilder
    private var actionsRow: some View {
        HStack {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    onToggleTodo()
                }
            } label: {
                Text(item.habit.isTodo ? "One-time" : "Recurring")
                    .font(Typography.bodySmall)
                    .foregroundStyle(item.habit.isTodo ? .secondary : item.habit.category.style.baseColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        item.habit.isTodo ? Color.primary.opacity(0.06) : item.habit.category.style.baseColor.opacity(0.12),
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.habit.isTodo ? "One-time task" : "Recurring habit")
            .accessibilityHint("Tap to toggle")

            Spacer()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.warmRed)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete \(item.habit.title)")
        }
    }

    // MARK: - Effort Pill (block shape, equal width)

    private func effortPill(_ label: String, detail: String, size: BlockSize) -> some View {
        let isSelected = item.habit.blockSize == size
        let color = isSelected ? item.habit.category.style.baseColor : Color.primary.opacity(0.15)

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                onUpdateSize(size)
            }
        } label: {
            VStack(spacing: 4) {
                blockShape(for: size, color: color)
                Text(label)
                    .font(Typography.bodySmall)
                    .fontWeight(isSelected ? .semibold : .regular)
                Text(detail)
                    .font(Typography.caption)
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isSelected ? color.opacity(0.12) : Color.primary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) effort, \(detail)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Block Shape

    @ViewBuilder
    private func blockShape(for size: BlockSize, color: Color) -> some View {
        switch size {
        case .small:
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color).frame(width: 20, height: 20)
        case .medium:
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color).frame(width: 28, height: 20)
        case .hard:
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color).frame(width: 28, height: 28)
        }
    }

    // MARK: - Helpers

    private func categoryLabel(_ cat: HabitCategory) -> String {
        switch cat {
        case .health: return "Health"
        case .work: return "Work"
        case .creativity: return "Create"
        case .focus: return "Focus"
        case .social: return "Social"
        case .mindfulness: return "Mind"
        }
    }

    private func fullDayName(_ day: DayCode) -> String {
        switch day {
        case .su: return "Sunday"
        case .mo: return "Monday"
        case .tu: return "Tuesday"
        case .we: return "Wednesday"
        case .th: return "Thursday"
        case .fr: return "Friday"
        case .sa: return "Saturday"
        }
    }
}
