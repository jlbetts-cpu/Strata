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

    /// Progressive disclosure. Every question in this sheet except the title
    /// and the category is about *when* or *how much*, and every one of them
    /// has a working default, so none of them needs to be on screen to add a
    /// habit. Opened by the person who wants them, not by the form.
    @State private var whenExpanded = false
    @State private var detailsExpanded = false
    @FocusState private var titleFocused: Bool
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(HealthKitService.self) private var healthKitService

    @ScaledMetric(relativeTo: .body) private var circleSize: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var hitTarget: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var strokeSize: CGFloat = 40
    @ScaledMetric(relativeTo: .body) private var dayCircleSize: CGFloat = 32

    private var isAccessibilitySize: Bool { typeSize.isAccessibilitySize }
    private let categories = HabitCategory.selectable

    var body: some View {
        NavigationStack {
        Form {
            // The two questions that cannot be defaulted.
            Section {
                TextField("What are you scheduling?", text: $title)
                    .font(Typography.bodyLarge)
                    .submitLabel(.done)
                    .focused($titleFocused)
            }

            // Section 2: Category — horizontal capsule pills
            Section("Category") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { cat in
                            categoryChip(cat)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            // MARK: - When
            //
            // Everything here has a working default — every day, no set time —
            // so the sheet does not have to ask before it can be submitted. The
            // header states what those defaults currently say, so opening it is
            // a choice rather than a check.
            Section {
                DisclosureGroup(isExpanded: $whenExpanded) {
                    Picker("Repeats", selection: $isOneTime) {
                        Text("Recurring").tag(false)
                        Text("One-Time").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: isOneTime) { _, _ in HapticsEngine.tick() }

                    if isOneTime {
                        DatePicker("Date", selection: $scheduledDate, displayedComponents: .date)
                    } else {
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
                                                isSelected ? selectedCategory.style.baseColor : GridConstants.fillTrack,
                                                in: Circle()
                                            )
                                            .foregroundStyle(isSelected ? .white : .primary)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(day.rawValue)
                                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                                }
                            }
                        }
                    }

                    Toggle("Set time", isOn: $useTimePicker)
                        .tint(selectedCategory.style.baseColor)
                        .onChange(of: useTimePicker) { _, _ in HapticsEngine.tick() }
                    if useTimePicker {
                        DatePicker("Time", selection: $scheduledTime, displayedComponents: .hourAndMinute)
                    }
                } label: {
                    disclosureLabel("When", value: whenSummary)
                }
            }

            // MARK: - Details
            //
            // Effort, duration, grace and Apple Health. All defaulted, none of
            // them the reason anyone opened this sheet.
            Section {
                DisclosureGroup(isExpanded: $detailsExpanded) {
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

                    // Duration, decoupled from effort (Kahneman 2011)
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
                                                : GridConstants.fillTrack,
                                            in: Capsule()
                                        )
                                        .foregroundStyle(durationMinutes == mins ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Stepper(formatDuration(durationMinutes), value: $durationMinutes, in: 5...180, step: 5)
                        .onChange(of: durationMinutes) { _, _ in HapticsEngine.tick() }

                    if !isOneTime {
                        Stepper("^[\(graceDays) day](inflect: true) grace",
                                value: $graceDays, in: 0...7)
                    }

                    if !isOneTime && (selectedCategory == .health || selectedCategory == .mindfulness) {
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
                    }
                } label: {
                    disclosureLabel("Details", value: detailsSummary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background { WarmBackground().ignoresSafeArea() }
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
            titleFocused = true
            if let prefill = prefillTime {
                // Arrived from a tapped time slot, so "when" is already decided
                // and worth showing rather than hiding behind the disclosure.
                whenExpanded = true
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

    /// Extracted from the Form body: `iconName` becoming optional pushed that
    /// expression past the type-checker's limit.
    private func categoryChip(_ cat: HabitCategory) -> some View {
        let isSelected = selectedCategory == cat
        return Button {
            withAnimation(GridConstants.crossFade) { selectedCategory = cat }
            HapticsEngine.tick()
        } label: {
            HStack(spacing: 6) {
                if let icon = cat.iconName {
                    Image(systemName: icon)
                        .iconSize(12, relativeTo: .footnote, weight: .medium)
                }
                Text(cat.rawValue.capitalized)
                    .font(Typography.bodySmall)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? cat.style.baseColor : GridConstants.fillTrack, in: Capsule())
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(cat.rawValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Disclosure summaries

    /// A collapsed group has to say what it is currently holding, or hiding it
    /// is just hiding it.
    private func disclosureLabel(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .font(Typography.bodySmall)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var whenSummary: String {
        var parts: [String] = []
        if isOneTime {
            parts.append(scheduledDate.formatted(.dateTime.month(.abbreviated).day()))
        } else if selectedDays.count == DayCode.allCases.count {
            parts.append("Every day")
        } else if selectedDays == [.mo, .tu, .we, .th, .fr] {
            parts.append("Weekdays")
        } else if selectedDays.isEmpty {
            parts.append("No days")
        } else {
            parts.append(DayCode.allCases.filter { selectedDays.contains($0) }
                .map(\.rawValue).joined(separator: " "))
        }
        if useTimePicker {
            parts.append(scheduledTime.formatted(date: .omitted, time: .shortened))
        }
        return parts.joined(separator: ", ")
    }

    private var detailsSummary: String {
        var parts = [selectedSize.effortLabel, formatDuration(durationMinutes)]
        if selectedHealthKitType != nil { parts.append("Auto-verify") }
        return parts.joined(separator: ", ")
    }

    // MARK: - Sub-views

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
                .fill(Color.primary.opacity(0.02))
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
