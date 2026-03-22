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

    private let categories = HabitCategory.allCases

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(spacing: 12) {
                Circle()
                    .fill(item.habit.category.style.baseColor)
                    .frame(width: 12, height: 12)
                    .animation(.easeInOut(duration: 0.2), value: item.habit.category)

                Text(item.habit.title)
                    .font(Typography.bodyLarge)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                Text(schedule)
                    .font(Typography.caption)
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
            .contentShape(Rectangle())
            .onTapGesture { onTapOptions() }

            // Expanded inline options
            if isExpanded {
                expandedOptions
                    .transition(.opacity)
                    .padding(.leading, CGFloat(item.indentLevel) * 16)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.habit.title), \(item.habit.category.rawValue), \(schedule)")
    }

    // MARK: - Expanded Options

    @ViewBuilder
    private var expandedOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category circles
            HStack(spacing: 4) {
                ForEach(categories, id: \.self) { cat in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            onUpdateCategory(cat)
                        }
                    } label: {
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
                                .stroke(Color.primary, lineWidth: item.habit.category == cat ? 2 : 0)
                                .frame(width: 40, height: 40)
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
                    .accessibilityLabel(cat.rawValue)
                    .accessibilityAddTraits(item.habit.category == cat ? .isSelected : [])
                }
            }

            // Effort pills
            HStack(spacing: 8) {
                effortPill("Easy", detail: "15m", size: .small)
                effortPill("Med", detail: "30m", size: .medium)
                effortPill("Hard", detail: "60m", size: .hard)
            }

            // Day picker (only for recurring)
            if !item.habit.isTodo {
                HStack(spacing: 0) {
                    ForEach(DayCode.allCases, id: \.self) { day in
                        let isSelected = item.habit.frequency.contains(day)
                        Button {
                            var days = Set(item.habit.frequency)
                            if isSelected { days.remove(day) } else { days.insert(day) }
                            onUpdateDays(days)
                        } label: {
                            Text(day.rawValue)
                                .font(Typography.caption)
                                .foregroundStyle(isSelected ? .white : Color.primary)
                                .frame(width: 28, height: 28)
                                .background(
                                    isSelected ? item.habit.category.style.baseColor : Color.primary.opacity(0.06),
                                    in: Circle()
                                )
                        }
                        .buttonStyle(.plain)
                        .frame(width: 40, height: 40)
                        .contentShape(Circle())
                        .accessibilityLabel(fullDayName(day))
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }

            // Type toggle + Delete
            HStack {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        onToggleTodo()
                    }
                } label: {
                    Text(item.habit.isTodo ? "One-time" : "Recurring")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.habit.isTodo ? "One-time task" : "Recurring habit")
                .accessibilityHint("Tap to toggle between recurring and one-time")

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
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Effort Pill

    private func effortPill(_ label: String, detail: String, size: BlockSize) -> some View {
        let isSelected = item.habit.blockSize == size
        return HStack(spacing: 4) {
            Text(label)
                .font(Typography.caption)
                .fontWeight(isSelected ? .semibold : .regular)
            Text(detail)
                .font(Typography.caption)
        }
        .foregroundStyle(isSelected ? .white : Color.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            isSelected ? item.habit.category.style.baseColor : Color.primary.opacity(0.06),
            in: Capsule()
        )
        .accessibilityLabel("\(label) effort, \(detail)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                onUpdateSize(size)
            }
        }
    }

    // MARK: - Helpers

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
