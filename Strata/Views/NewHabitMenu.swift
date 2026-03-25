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
    @State private var graceDays: Int = 2
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var typeSize

    @ScaledMetric(relativeTo: .body) private var circleSize: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var hitTarget: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var strokeSize: CGFloat = 40
    @ScaledMetric(relativeTo: .body) private var dayCircleSize: CGFloat = 32

    private var isAccessibilitySize: Bool { typeSize.isAccessibilitySize }
    private let categories = HabitCategory.allCases

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 20) {
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

            // Live block preview — after title so user sees feedback (Norton 2012 IKEA Effect)
            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous)
                    .fill(selectedCategory.style.gradient)
                    .frame(
                        width: CGFloat(selectedSize.columnSpan) * 28,
                        height: CGFloat(selectedSize.rowSpan) * 28
                    )
                    .overlay {
                        VStack(spacing: 2) {
                            Image(systemName: selectedCategory.iconName)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                            if !title.isEmpty {
                                Text(title)
                                    .font(Typography.caption2)
                                    .foregroundStyle(.white.opacity(0.8))
                                    .lineLimit(1)
                            }
                        }
                    }
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                    .animation(GridConstants.motionSmooth, value: selectedCategory)
                    .animation(GridConstants.motionSmooth, value: selectedSize)
                Spacer()
            }

            // Category — mini clay blocks (Lakoff & Johnson 1980 — visual metaphor continuity)
            sectionCard("Category") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: isAccessibilitySize ? 2 : 3), spacing: 12) {
                    ForEach(categories, id: \.self) { cat in
                        Button {
                            withAnimation(GridConstants.crossFade) { selectedCategory = cat }
                            HapticsEngine.tick()
                        } label: {
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(cat.style.gradient)
                                    .frame(width: circleSize, height: circleSize)
                                    .overlay {
                                        Image(systemName: cat.iconName)
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundStyle(.white)
                                    }
                                    .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                                Text(cat.rawValue.capitalized)
                                    .font(Typography.caption2)
                                    .foregroundStyle(selectedCategory == cat ? .primary : .secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 2)
                            .background {
                                if selectedCategory == cat {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(cat.style.baseColor.opacity(0.1))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(cat.rawValue)
                        .accessibilityAddTraits(selectedCategory == cat ? .isSelected : [])
                    }
                }
            }

            // Duration — block proportions (Treisman 1980 — pre-attentive processing)
            sectionCard("Duration") {
                HStack(spacing: 12) {
                    ForEach([BlockSize.small, .medium, .hard], id: \.self) { size in
                        Button {
                            withAnimation(GridConstants.crossFade) { selectedSize = size }
                            HapticsEngine.tick()
                        } label: {
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(selectedCategory.style.gradient)
                                    .frame(
                                        width: CGFloat(size.columnSpan) * 20,
                                        height: CGFloat(size.rowSpan) * 20
                                    )
                                Text(size.rawValue.capitalized)
                                    .font(Typography.caption2)
                                Text(size == .hard ? "1 hour" : "\(Int(size.durationMinutes)) min")
                                    .font(Typography.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .background {
                                if selectedSize == size {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedCategory.style.baseColor.opacity(0.1))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Schedule
            if isOneTime {
                sectionCard("Date") {
                    DatePicker("Date", selection: $scheduledDate, displayedComponents: .date)
                        .font(Typography.bodyMedium)
                }
            } else {
                sectionCard("Schedule") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
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
            sectionCard("Time") {
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
            }

            // Grace period (Gardner et al. 2012)
            if !isOneTime {
                sectionCard("Grace Period") {
                    Stepper("\(graceDays) day\(graceDays == 1 ? "" : "s")", value: $graceDays, in: 0...7)
                        .font(Typography.bodyMedium)
                    Text("Days you can miss without breaking your streak")
                        .font(Typography.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // "Stack it" button — looks like a block, verb matches tower metaphor
            Button {
                createHabit()
            } label: {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(.white.opacity(0.3))
                        .frame(width: 16, height: 16)
                    Text("Stack it")
                        .fontWeight(.semibold)
                }
                .font(Typography.blockTitle)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    selectedCategory.style.gradient,
                    in: RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous)
                )
                .shadow(color: selectedCategory.style.baseColor.opacity(0.3), radius: 8, y: 4)
            }
            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(title.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
        }
        .padding(20)
        }
        // Ambient category tint — sheet breathes with your choice
        .background {
            selectedCategory.style.baseColor.opacity(0.04)
                .ignoresSafeArea()
                .animation(GridConstants.motionSmooth, value: selectedCategory)
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

    // MARK: - Section Card (Wertheimer 1923 — Gestalt Proximity)

    private func sectionCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.04 : 0.02))
        )
    }

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
            scheduledDate: isOneTime ? TimelineViewModel.dateString(from: scheduledDate) : nil,
            graceDays: isOneTime ? 0 : graceDays
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
