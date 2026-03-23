import SwiftUI
import SwiftData

struct NewHabitMenu: View {
    @Binding var isPresented: Bool
    let modelContext: ModelContext
    let onCreated: () -> Void
    var prefillTime: String? = nil
    var tower: Tower? = nil

    @State private var isOneTime = false
    @State private var title = ""
    @State private var selectedCategory: HabitCategory = .health
    @State private var selectedSize: BlockSize = .small
    @State private var selectedDays: Set<DayCode> = Set(DayCode.allCases)
    @State private var scheduledDate = Date()
    @State private var useTimePicker = false
    @State private var scheduledTime = Date()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var typeSize

    @ScaledMetric(relativeTo: .body) private var circleSize: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var hitTarget: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var strokeSize: CGFloat = 40
    @ScaledMetric(relativeTo: .body) private var dayCircleSize: CGFloat = 36

    private var isAccessibilitySize: Bool { typeSize.isAccessibilitySize }
    private let categories = HabitCategory.allCases

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            // Toggle: One-Time Task / Recurring Habit
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

            // Title
            TextField("Habit name", text: $title)
                .font(Typography.bodyLarge)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Category colors
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

            // Duration pills
            VStack(alignment: .leading, spacing: 8) {
                Text("Duration")
                    .font(Typography.bodySmall)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    durationPill("15 min", size: .small)
                    durationPill("30 min", size: .medium)
                    durationPill("60 min", size: .hard)
                }
            }

            // Schedule
            if isOneTime {
                DatePicker("Date", selection: $scheduledDate, displayedComponents: .date)
                    .font(Typography.bodyMedium)
            } else {
                // Day-of-week picker
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
                        }
                    }
                }
            }

            // Optional time picker
            Toggle(isOn: $useTimePicker) {
                Text("Set time")
                    .font(Typography.bodyMedium)
            }
            .tint(selectedCategory.style.baseColor)
            .onChange(of: useTimePicker) { _, _ in HapticsEngine.tick() }

            if useTimePicker {
                DatePicker("Time", selection: $scheduledTime, displayedComponents: .hourAndMinute)
                    .font(Typography.bodyMedium)
            }

            // Create button
            Button {
                createHabit()
            } label: {
                Text("Create")
                    .font(Typography.blockTitle)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        selectedCategory.style.baseColor,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            }
            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(title.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
        }
        .padding(20)
        }
        .onAppear {
            if let prefill = prefillTime {
                useTimePicker = true
                let parts = prefill.split(separator: ":")
                if let h = Int(parts.first ?? ""), let m = Int(parts.last ?? "") {
                    var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                    comps.hour = h
                    comps.minute = m
                    if let date = Calendar.current.date(from: comps) {
                        scheduledTime = date
                    }
                }
            }
        }
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

    private func durationPill(_ label: String, size: BlockSize) -> some View {
        let isSelected = selectedSize == size
        return Text(label)
            .font(Typography.bodySmall)
            .foregroundStyle(isSelected ? .white : Color.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                isSelected ? selectedCategory.style.baseColor : Color.primary.opacity(0.06),
                in: .capsule
            )
            .onTapGesture {
                withAnimation(GridConstants.crossFade) { selectedSize = size }
                HapticsEngine.tick()
            }
    }

    // MARK: - Create

    private func createHabit() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        var timeStr: String? = nil
        if useTimePicker {
            let cal = Calendar.current
            let h = cal.component(.hour, from: scheduledTime)
            let m = cal.component(.minute, from: scheduledTime)
            timeStr = String(format: "%02d:%02d", h, m)
        }

        let habit = Habit(
            title: trimmed,
            category: selectedCategory,
            blockSize: selectedSize,
            frequency: isOneTime ? [] : Array(selectedDays),
            scheduledTime: timeStr,
            isTodo: isOneTime,
            scheduledDate: isOneTime ? TimelineViewModel.dateString(from: scheduledDate) : nil
        )

        habit.tower = tower
        modelContext.insert(habit)
        try? modelContext.save()

        HapticsEngine.snap()
        onCreated()

        withAnimation(GridConstants.toggleSwitch) {
            isPresented = false
        }
    }
}
