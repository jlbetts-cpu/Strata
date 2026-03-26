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
    @State private var durationMinutes: Int = 15
    @State private var selectedHealthKitType: HealthKitHabitType? = nil
    @State private var healthKitThreshold: Double = 0
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(HealthKitService.self) private var healthKitService

    @ScaledMetric(relativeTo: .body) private var circleSize: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var hitTarget: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var strokeSize: CGFloat = 40
    @ScaledMetric(relativeTo: .body) private var dayCircleSize: CGFloat = 32

    private var isAccessibilitySize: Bool { typeSize.isAccessibilitySize }
    private let categories = HabitCategory.allCases

    var body: some View {
        NavigationStack {
        Form {
            // Section 1: Basics
            Section {
                Picker("Type", selection: $isOneTime) {
                    Text("Recurring").tag(false)
                    Text("One-Time").tag(true)
                }
                .pickerStyle(.segmented)
                .onChange(of: isOneTime) { _, _ in HapticsEngine.tick() }

                TextField("Title", text: $title)
            }

            // Section 2: Category — horizontal capsule pills
            Section("Category") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { cat in
                            Button {
                                withAnimation(GridConstants.crossFade) { selectedCategory = cat }
                                HapticsEngine.tick()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: cat.iconName)
                                        .font(.system(size: 12, weight: .medium))
                                    Text(cat.rawValue.capitalized)
                                        .font(Typography.bodySmall)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    selectedCategory == cat
                                        ? cat.style.baseColor
                                        : Color.primary.opacity(0.06),
                                    in: Capsule()
                                )
                                .foregroundStyle(selectedCategory == cat ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(cat.rawValue)
                            .accessibilityAddTraits(selectedCategory == cat ? .isSelected : [])
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 0))
            }

            // Section 3: Effort — segmented picker (Kahneman 2011: effort ≠ time)
            Section("Effort") {
                Picker("Effort", selection: $selectedSize) {
                    ForEach([BlockSize.small, .medium, .hard], id: \.self) { size in
                        Text(size.effortLabel).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedSize) { _, newSize in
                    HapticsEngine.tick()
                    durationMinutes = Int(newSize.durationMinutes) // Auto-suggest, user can override
                }

                // Subtle preview — shows what block you're building
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(selectedCategory.style.gradient)
                        .frame(
                            width: CGFloat(selectedSize.columnSpan) * 20,
                            height: CGFloat(selectedSize.rowSpan) * 20
                        )
                        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                        .animation(GridConstants.motionSmooth, value: selectedSize)
                        .animation(GridConstants.motionSmooth, value: selectedCategory)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            // Section 4: Duration (decoupled from effort — Kahneman 2011)
            Section("Duration") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach([15, 30, 45, 60, 90, 120], id: \.self) { mins in
                            Button {
                                durationMinutes = mins
                                HapticsEngine.tick()
                            } label: {
                                Text(formatDuration(mins))
                                    .font(Typography.bodySmall)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        durationMinutes == mins
                                            ? selectedCategory.style.baseColor
                                            : Color.primary.opacity(0.06),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(durationMinutes == mins ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 0))

                Stepper(formatDuration(durationMinutes), value: $durationMinutes, in: 5...180, step: 5)
                    .onChange(of: durationMinutes) { _, _ in HapticsEngine.tick() }
            }

            // Section 5: Schedule
            if isOneTime {
                Section("Date") {
                    DatePicker("Date", selection: $scheduledDate, displayedComponents: .date)
                }
            } else {
                Section("Schedule") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(DayCode.allCases, id: \.self) { day in
                                let isSelected = selectedDays.contains(day)
                                Button {
                                    if isSelected { selectedDays.remove(day) }
                                    else { selectedDays.insert(day) }
                                    HapticsEngine.tick()
                                } label: {
                                    Text(day.rawValue)
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .frame(width: 36, height: 36)
                                        .background(
                                            isSelected ? selectedCategory.style.baseColor : Color.primary.opacity(0.06),
                                            in: Circle()
                                        )
                                        .foregroundStyle(isSelected ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 0))
                }
            }

            // Section 5: Time
            Section {
                Toggle("Set time", isOn: $useTimePicker)
                    .tint(selectedCategory.style.baseColor)
                    .onChange(of: useTimePicker) { _, _ in HapticsEngine.tick() }
                if useTimePicker {
                    DatePicker("Time", selection: $scheduledTime, displayedComponents: .hourAndMinute)
                }
            }

            // Section 6: Grace period (recurring only)
            if !isOneTime {
                Section {
                    Stepper("\(graceDays) day\(graceDays == 1 ? "" : "s") grace",
                            value: $graceDays, in: 0...7)
                } footer: {
                    Text("Days you can miss without breaking your streak")
                }
            }

            // Section 7: HealthKit (Health + Mindfulness only)
            if !isOneTime && (selectedCategory == .health || selectedCategory == .mindfulness) {
                Section {
                    HStack {
                        Image(systemName: "heart.circle")
                            .foregroundStyle(AppColors.healthGreen)
                        Text("Auto-Verify")
                        Spacer()
                        if healthKitService.isAvailable {
                            Picker("Type", selection: $selectedHealthKitType) {
                                Text("None").tag(HealthKitHabitType?.none)
                                ForEach(availableHealthKitTypes, id: \.rawValue) { type in
                                    Text(type.displayName).tag(Optional(type))
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    if let type = selectedHealthKitType, !type.thresholdPresets.isEmpty {
                        Picker("Threshold", selection: $healthKitThreshold) {
                            ForEach(type.thresholdPresets, id: \.value) { preset in
                                Text(preset.label).tag(preset.value)
                            }
                        }
                    }
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("Automatically verify completion from Apple Health data")
                }
            }
        }
        .navigationTitle("Add")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    HapticsEngine.lightTap()
                    isPresented = false
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { createHabit() }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
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

    // MARK: - Available HealthKit Types

    private var availableHealthKitTypes: [HealthKitHabitType] {
        switch selectedCategory {
        case .health:
            return [.stepCount, .workout, .workoutRunning, .workoutWalking,
                    .workoutCycling, .workoutSwimming, .workoutStrength, .workoutHIIT]
        case .mindfulness:
            return [.mindfulSession, .workoutYoga]
        default:
            return []
        }
    }

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

    // MARK: - Create

    private func formatDuration(_ mins: Int) -> String {
        if mins < 60 { return "\(mins)m" }
        let h = mins / 60
        let m = mins % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
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

        // Custom duration (decoupled from effort)
        let defaultDuration = Int(selectedSize.durationMinutes)
        if durationMinutes != defaultDuration {
            habit.customDurationMinutes = durationMinutes
        }

        // HealthKit auto-verify configuration
        if let hkType = selectedHealthKitType {
            habit.healthKitType = hkType.rawValue
            habit.healthKitThreshold = healthKitThreshold
            // Request HealthKit access for this type
            Task {
                _ = await healthKitService.requestAccess(for: hkType)
            }
        }

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

// MARK: - Flow Layout (wrapping horizontal chips)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
