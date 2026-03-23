import SwiftUI
import SwiftData

struct HabitEditView: View {
    @Bindable var habit: Habit
    let allHabits: [Habit]
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    @ScaledMetric(relativeTo: .body) private var circleSize: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var hitTarget: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var strokeSize: CGFloat = 40
    @ScaledMetric(relativeTo: .body) private var dayCircleSize: CGFloat = 36

    private var gentle: Animation { reduceMotion ? GridConstants.motionReduced : GridConstants.gentleReveal }
    private var isAccessibilitySize: Bool { typeSize.isAccessibilitySize }

    @State private var title: String = ""
    @State private var selectedCategory: HabitCategory = .health
    @State private var selectedSize: BlockSize = .small
    @State private var selectedDays: Set<DayCode> = Set(DayCode.allCases)
    @State private var isOneTime: Bool = false
    @State private var scheduledDate: Date = Date()
    @State private var useTimePicker: Bool = false
    @State private var scheduledTime: Date = Date()
    @State private var graceDays: Int = 1
    @State private var showDeleteConfirm: Bool = false

    private let categories = HabitCategory.allCases

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Block preview at top
                    HStack {
                        Spacer()
                        MiniBlockPreview(
                            category: selectedCategory,
                            blockSize: selectedSize,
                            title: title.isEmpty ? "Preview" : title
                        )
                        .frame(width: 100, height: 100)
                        .animation(gentle, value: selectedSize)
                        .animation(gentle, value: selectedCategory)
                        Spacer()
                    }

                    // Title
                    TextField("Habit name", text: $title)
                        .font(Typography.bodyLarge)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    // Type toggle
                    HStack(spacing: 0) {
                        togglePill("Recurring", selected: !isOneTime) {
                            withAnimation(GridConstants.toggleSwitch) { isOneTime = false }
                            HapticsEngine.tick()
                        }
                        togglePill("One-Time", selected: isOneTime) {
                            withAnimation(GridConstants.toggleSwitch) { isOneTime = true }
                            HapticsEngine.tick()
                        }
                    }
                    .padding(4)
                    .background(Color.primary.opacity(0.06), in: .capsule)

                    // Effort picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Effort")
                            .font(Typography.bodySmall)
                            .foregroundStyle(.secondary)

                        VStack(spacing: 8) {
                            effortPill("Easy", detail: "1x1 · 15m", size: .small)
                            effortPill("Medium", detail: "2x1 · 30m", size: .medium)
                            effortPill("Hard", detail: "2x2 · 60m", size: .hard)
                        }
                    }

                    // Category with icons
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(Typography.bodySmall)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: hitTarget), spacing: isAccessibilitySize ? 8 : 12)]) {
                            ForEach(categories, id: \.self) { cat in
                                Button {
                                    withAnimation(GridConstants.crossFade) { selectedCategory = cat }
                                    HapticsEngine.tick()
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(cat.style.baseColor)
                                            .frame(width: circleSize, height: circleSize)
                                        Image(systemName: cat.iconName)
                                            .font(Typography.bodySmall.weight(.medium))
                                            .foregroundStyle(.white.opacity(0.9))
                                    }
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: selectedCategory == cat ? 2.5 : 0)
                                            .frame(width: strokeSize, height: strokeSize)
                                    )
                                }
                                .buttonStyle(.plain)
                                .frame(width: hitTarget, height: hitTarget)
                                .contentShape(Circle())
                                .accessibilityLabel(cat.rawValue)
                                .accessibilityAddTraits(selectedCategory == cat ? .isSelected : [])
                            }
                        }
                    }

                    // Schedule
                    if isOneTime {
                        DatePicker("Date", selection: $scheduledDate, displayedComponents: .date)
                            .font(Typography.bodyMedium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Days")
                                .font(Typography.bodySmall)
                                .foregroundStyle(.secondary)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: hitTarget), spacing: isAccessibilitySize ? 8 : 8)]) {
                                ForEach(DayCode.allCases, id: \.self) { day in
                                    let isSelected = selectedDays.contains(day)
                                    Button {
                                        withAnimation(GridConstants.crossFade) {
                                            if isSelected {
                                                selectedDays.remove(day)
                                            } else {
                                                selectedDays.insert(day)
                                            }
                                        }
                                        HapticsEngine.tick()
                                    } label: {
                                        Text(day.rawValue)
                                            .font(Typography.bodySmall)
                                            .foregroundStyle(isSelected ? .white : Color.primary)
                                            .frame(width: dayCircleSize, height: dayCircleSize)
                                            .background(
                                                isSelected ? selectedCategory.style.baseColor : Color.primary.opacity(0.06),
                                                in: Circle()
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .frame(width: hitTarget, height: hitTarget)
                                    .contentShape(Circle())
                                    .accessibilityLabel(day.rawValue)
                                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                                }
                            }
                        }
                    }

                    // Time picker
                    Toggle(isOn: $useTimePicker) {
                        Text("Set time")
                            .font(Typography.bodyMedium)
                    }
                    .tint(selectedCategory.style.baseColor)
                    .onChange(of: useTimePicker) { _, _ in HapticsEngine.tick() }

                    if useTimePicker {
                        DatePicker("Time", selection: $scheduledTime, displayedComponents: .hourAndMinute)
                            .font(Typography.bodyMedium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // Grace days
                    if !isOneTime {
                        Stepper(value: $graceDays, in: 0...3) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Grace days: \(graceDays)")
                                    .font(Typography.bodyMedium)
                                Text("Allow \(graceDays) missed day\(graceDays == 1 ? "" : "s") before streak breaks")
                                    .font(Typography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Save button
                    Button { saveChanges() } label: {
                        Text("Save Changes")
                            .font(Typography.blockTitle)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                selectedCategory.style.baseColor,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(title.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)

                    // Delete button
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Text("Delete")
                            .font(Typography.bodyMedium)
                            .foregroundStyle(AppColors.warmRed)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                AppColors.warmRed.opacity(0.1),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(AppColors.warmRed.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .padding(20)
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(Typography.bodyLarge)
                }
            }
            .confirmationDialog("Delete this habit?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
            }
            .onAppear { loadHabit() }
        }
    }

    // MARK: - Load

    private func loadHabit() {
        title = habit.title
        selectedCategory = habit.category
        selectedSize = habit.blockSize
        isOneTime = habit.isTodo
        selectedDays = Set(habit.frequency)
        graceDays = habit.graceDays

        if let timeStr = habit.scheduledTime {
            useTimePicker = true
            let parts = timeStr.split(separator: ":")
            if let h = Int(parts.first ?? ""), let m = Int(parts.last ?? "") {
                var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                comps.hour = h
                comps.minute = m
                if let date = Calendar.current.date(from: comps) {
                    scheduledTime = date
                }
            }
        }

        if let dateStr = habit.scheduledDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: dateStr) {
                scheduledDate = date
            }
        }
    }

    // MARK: - Save

    private func saveChanges() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        habit.title = trimmed
        habit.category = selectedCategory
        habit.blockSize = selectedSize
        habit.isTodo = isOneTime
        habit.frequency = isOneTime ? [] : Array(selectedDays)
        habit.graceDays = graceDays

        if useTimePicker {
            let cal = Calendar.current
            let h = cal.component(.hour, from: scheduledTime)
            let m = cal.component(.minute, from: scheduledTime)
            habit.scheduledTime = String(format: "%02d:%02d", h, m)
        } else {
            habit.scheduledTime = nil
        }

        habit.scheduledDate = isOneTime ? TimelineViewModel.dateString(from: scheduledDate) : nil

        try? modelContext.save()
        HapticsEngine.snap()
        dismiss()
    }

    // MARK: - Sub-views

    private func togglePill(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Text(label)
            .font(Typography.bodySmall)
            .foregroundStyle(selected ? .white : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selected ? selectedCategory.style.baseColor : .clear, in: .capsule)
            .onTapGesture { action() }
    }

    private func effortPill(_ label: String, detail: String, size: BlockSize) -> some View {
        let isSelected = selectedSize == size
        return HStack(spacing: 6) {
            Text(label)
                .font(Typography.bodySmall)
                .fontWeight(isSelected ? .semibold : .regular)
            Text(detail)
                .font(Typography.caption)
        }
        .foregroundStyle(isSelected ? .white : Color.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isSelected ? selectedCategory.style.baseColor : Color.primary.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .onTapGesture {
            withAnimation(GridConstants.crossFade) { selectedSize = size }
            HapticsEngine.tick()
        }
    }
}
