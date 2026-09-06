import SwiftUI
import SwiftData

struct PlanItemRow: View {
    let item: PlanItem
    let isExpanded: Bool
    let schedule: String
    let subtasks: [PlanItem]
    let onTapOptions: () -> Void
    let onUpdateTitle: (String) -> Void
    let onDelete: () -> Void
    let onUpdateCategory: (HabitCategory) -> Void
    let onUpdateSize: (BlockSize) -> Void
    let onUpdateDays: (Set<DayCode>) -> Void
    let onUpdateFrequencyPreset: (String) -> Void
    let onUpdateTime: (String?) -> Void
    let onAddSubTask: () -> Void
    let onDeleteSubTask: (Habit) -> Void
    let onToggleSubTask: (Habit) -> Void
    let scheduledSiblings: [Habit]
    let suggestedSlot: String?
    let isCompletedToday: Bool
    let isSkippedToday: Bool
    @FocusState.Binding var editingItemID: UUID?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.switchTab) private var switchTab

    @ScaledMetric(relativeTo: .body) private var rowPadH: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var rowPadV: CGFloat = 16
    @ScaledMetric(relativeTo: .footnote) private var pillPadH: CGFloat = 12
    @ScaledMetric(relativeTo: .footnote) private var pillPadV: CGFloat = 6
    @ScaledMetric(relativeTo: .body) private var iconFrameWidth: CGFloat = 28

    @State private var editText: String = ""
    @State private var showTimePicker: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var showGlimpse: Bool = false

    private var gentle: Animation { reduceMotion ? GridConstants.motionReduced : GridConstants.motionGentle }
    private var smooth: Animation { reduceMotion ? GridConstants.motionReduced : GridConstants.motionSmooth }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row — 3 zones: icon (expand), title (edit), metadata (expand)
            HStack(spacing: 12) {
                // Category icon — naked SF Symbol (Apple Reminders pattern)
                if !isExpanded {
                    Button(action: onTapOptions) {
                        ZStack(alignment: .bottomTrailing) {
                            Image(systemName: item.habit.category.iconName)
                                .font(.headline)
                                .foregroundStyle(item.habit.category.style.baseColor)
                            // Status badges (Carver & Scheier 1998 — feedback loop)
                            if isCompletedToday {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(AppColors.healthGreen)
                                    .offset(x: 4, y: 4)
                            } else if isSkippedToday {
                                Image(systemName: "minus.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .offset(x: 4, y: 4)
                            } else if item.habit.isInProgress {
                                Image(systemName: "play.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                    .offset(x: 4, y: 4)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .animation(GridConstants.crossFade, value: item.habit.category)
                    .accessibilityLabel("\(item.habit.category.rawValue) category, tap to expand details")
                }

                // Title — always editable
                TextField("Habit name", text: $editText)
                    .font(Typography.bodyLarge)
                    .fontWeight(.semibold)
                    .foregroundStyle(isCompletedToday ? .secondary : .primary)
                    .strikethrough(isCompletedToday, color: .secondary)
                    .lineLimit(1)
                    .focused($editingItemID, equals: item.id)
                    .onSubmit {
                        onUpdateTitle(editText)
                        editingItemID = nil
                    }
                    .onChange(of: item.habit.title, initial: true) { _, newTitle in
                        editText = newTitle
                    }

                Spacer()

                // Metadata → tap to expand
                Button(action: onTapOptions) {
                    HStack(spacing: 8) {
                        Image(systemName: item.habit.isTodo ? "list.number" : "arrow.trianglehead.2.clockwise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(schedule)
                            .font(Typography.bodySmall)
                            .foregroundStyle(.secondary)
                        // Subtask progress badge (Miller 1956 — surface without expanding)
                        if !subtasks.isEmpty {
                            Text("\(subtasks.filter { $0.habit.isStepCompleted }.count)/\(subtasks.count)")
                                .font(Typography.caption)
                                .foregroundStyle(.tertiary)
                        }
                        // Today availability badge (Barkley 1997 — explicit time cue)
                        if !item.habit.isTodo && item.habit.frequency.contains(
                            DayCode.from(weekday: Calendar.current.component(.weekday, from: Date.now))
                        ) && !isCompletedToday {
                            Image(systemName: "sun.min.fill")
                                .font(.caption2)
                                .foregroundStyle(AppColors.healthGreen)
                        }
                        Image(systemName: "chevron.down")
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .animation(smooth, value: isExpanded)
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
            .padding(.horizontal, rowPadH)
            .padding(.vertical, rowPadV)

            // Expanded: Things 3 lightweight card
            if isExpanded {
                expandedCard
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
        // Left-edge accent (orange when in progress — Kanban convention)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(item.habit.isInProgress ? Color.orange : item.habit.category.style.baseColor)
                .frame(width: 4)
                .padding(.vertical, 8)
        }
        .opacity(isExpanded ? 1.0 : (isCompletedToday ? 0.5 : (isSkippedToday ? 0.7 : 1.0)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isCompletedToday ? "Done: " : isSkippedToday ? "Skipped: " : "")\(item.habit.title), \(item.habit.category.rawValue), \(schedule)")
        .onChange(of: isExpanded) { _, newVal in
            if !newVal { showTimePicker = false }
        }
        // Swipe delete removed here — defined in PlanPageView.itemRow() to avoid duplicate
        .confirmationDialog("Delete \(item.habit.title)?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                HapticsEngine.snap()
                onDelete()
            }
        }
    }

    // MARK: - Expanded Card (Reminders-Style Form Rows — NNGroup 2025)

    // MARK: - Expanded Card — "Inside the Block"

    @ViewBuilder
    private var expandedCard: some View {
        VStack(spacing: 16) {
            // ZONE 1: Time Hero — the soul of the block
            timeHeroSection

            // ZONE 2: Metadata Pills — the block's DNA
            compactPillRow
                .padding(.horizontal, rowPadH)

            // Time Picker (expanded below hero)
            if showTimePicker {
                timePickerContent
                    .padding(.horizontal, rowPadH)
            }

            // ZONE 3: Steps + Actions — the block's interior
            VStack(spacing: 0) {
                subtaskSection

                formSeparator

                // Cross-tab navigation
                if isCompletedToday || isSkippedToday || !item.habit.isTodo {
                    if let switchTab {
                        Button {
                            switchTab(.today)
                            HapticsEngine.lightTap()
                        } label: {
                            HStack {
                                Image(systemName: isCompletedToday ? "checkmark.circle" : "arrow.right.circle")
                                    .font(.body)
                                    .foregroundStyle(isCompletedToday ? AppColors.healthGreen : .secondary)
                                    .frame(width: iconFrameWidth)
                                Text(isCompletedToday ? "Done today" : isSkippedToday ? "Took a pass" : "View in Today")
                                    .font(Typography.bodyMedium)
                                    .foregroundStyle(isCompletedToday ? AppColors.healthGreen : .secondary)
                                Spacer()
                            }
                            .padding(.horizontal, rowPadH)
                            .padding(.vertical, rowPadV)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isCompletedToday ? "Completed today" : "View in Today tab")
                        formSeparator
                    }
                }

                // Save for later — visible affordance for to-do reuse (IxDF: never gesture-only)
                if item.habit.isTodo && !item.habit.isSaved {
                    formSeparator
                    Button {
                        item.habit.isSaved = true
                        try? item.habit.modelContext?.save()
                        HapticsEngine.lightTap()
                    } label: {
                        HStack {
                            Image(systemName: "bookmark")
                                .font(.body)
                                .foregroundStyle(.blue)
                                .frame(width: iconFrameWidth)
                            Text("Keep for later")
                                .font(Typography.bodyMedium)
                                .foregroundStyle(.blue)
                            Spacer()
                        }
                        .padding(.horizontal, rowPadH)
                        .padding(.vertical, rowPadV)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Save this task for reuse later")
                }
            }
        }
        .padding(.vertical, 16)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous)
        )
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        .padding(.horizontal, rowPadH)
        .padding(.bottom, rowPadV)
    }

    // MARK: - Zone 1: Time Hero — "When do I do this?"

    @ViewBuilder
    private var timeHeroSection: some View {
        Button {
            withAnimation(gentle) { showTimePicker.toggle() }
            HapticsEngine.tick()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                if let time = item.habit.scheduledTime {
                    // Duration pairing — ADHD time blindness scaffold (Barkley 1997)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(BlockTimeFormatter.format12Hour(time))
                            .font(.system(.title2, design: .rounded, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("· \(formatDuration(item.habit.effectiveDurationMinutes))")
                            .font(.system(.title3, design: .rounded, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("When works for you?")
                        .font(.system(.title3, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Text(frequencyLabel)
                    .font(Typography.bodySmall)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, rowPadH)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                item.habit.category.style.baseColor.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Time Picker Content (expanded below hero)

    @ViewBuilder
    private var timePickerContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // "Show schedule" toggle
            if !scheduledSiblings.isEmpty {
                Button {
                    withAnimation(smooth) { showGlimpse.toggle() }
                    HapticsEngine.lightTap()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: showGlimpse ? "eye.slash" : "eye")
                            .font(.body)
                            .foregroundStyle(item.habit.category.style.baseColor)
                            .frame(width: iconFrameWidth)
                        Text(showGlimpse ? "Hide schedule" : "Show schedule")
                            .font(Typography.bodySmall)
                            .foregroundStyle(item.habit.category.style.baseColor)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showGlimpse ? "Hide other habits at this time" : "Show other habits at this time")

                if showGlimpse {
                    timelineGlimpseStrip
                }
            }

            // Suggestion pill
            if let slot = suggestedSlot {
                Button {
                    onUpdateTime(slot)
                    HapticsEngine.snap()
                    withAnimation(gentle) { showTimePicker = false }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                        Text("Next open: \(BlockTimeFormatter.format12Hour(slot))")
                            .font(Typography.bodySmall)
                    }
                    .foregroundStyle(item.habit.category.style.baseColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(item.habit.category.style.baseColor.opacity(0.15), in: Capsule())
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .accessibilityLabel("Set time to \(BlockTimeFormatter.format12Hour(slot))")
            }

            // DatePicker + Clear
            HStack {
                DatePicker(
                    "",
                    selection: Binding(
                        get: {
                            guard let timeStr = item.habit.scheduledTime else { return Date.now }
                            let parts = timeStr.split(separator: ":")
                            guard let h = Int(parts.first ?? ""), let m = Int(parts.last ?? "") else { return Date.now }
                            var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date.now)
                            comps.hour = h; comps.minute = m
                            return Calendar.current.date(from: comps) ?? Date.now
                        },
                        set: { newDate in
                            let cal = Calendar.current
                            onUpdateTime(String(format: "%02d:%02d", cal.component(.hour, from: newDate), cal.component(.minute, from: newDate)))
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .accessibilityLabel("Scheduled time")

                if item.habit.scheduledTime != nil {
                    Button {
                        onUpdateTime(nil)
                        HapticsEngine.tick()
                        withAnimation(gentle) { showTimePicker = false }
                    } label: {
                        Text("Remove time")
                            .font(Typography.bodySmall)
                            .foregroundStyle(AppColors.warmRed)
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                }
            }
        }
    }

    // MARK: - Form Separator (visible on .thinMaterial in both modes)


    private var formSeparator: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.1))
            .frame(height: 0.5)
            .padding(.leading, 44) // indent past icon column (Apple Reminders pattern)
    }

    // MARK: - Form Rows (Reminders-Style: icon + label + value)

    @ViewBuilder
    private var categoryFormRow: some View {
        Menu {
            ForEach(HabitCategory.selectable, id: \.self) { cat in
                Button {
                    onUpdateCategory(cat)
                    HapticsEngine.tick()
                } label: {
                    Label(categoryLabel(cat), systemImage: cat.iconName)
                }
            }
        } label: {
            HStack {
                Image(systemName: "tag.fill")
                    .font(.body)
                    .foregroundStyle(item.habit.category.style.baseColor)
                    .frame(width: iconFrameWidth)
                Text("Type")
                    .font(Typography.bodyMedium)
                    .foregroundStyle(.primary)
                Spacer()
                Text(categoryLabel(item.habit.category))
                    .font(Typography.bodySmall)
                    .foregroundStyle(item.habit.category.style.baseColor)
            }
            .padding(.horizontal, rowPadH)
            .padding(.vertical, rowPadV)
        }
        .tint(.primary)
        .accessibilityLabel("Category: \(item.habit.category.rawValue)")
    }

    @ViewBuilder
    private var effortFormRow: some View {
        Menu {
            Button { onUpdateSize(.small); HapticsEngine.tick() } label: { Text("Easy · 15m") }
            Button { onUpdateSize(.medium); HapticsEngine.tick() } label: { Text("Medium · 30m") }
            Button { onUpdateSize(.hard); HapticsEngine.tick() } label: { Text("Hard · 60m") }
        } label: {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.body)
                    .foregroundStyle(item.habit.category.style.baseColor)
                    .frame(width: iconFrameWidth)
                Text("Size")
                    .font(Typography.bodyMedium)
                    .foregroundStyle(.primary)
                Spacer()
                Text(effortLabel(item.habit.blockSize))
                    .font(Typography.bodySmall)
                    .foregroundStyle(item.habit.category.style.baseColor)
            }
            .padding(.horizontal, rowPadH)
            .padding(.vertical, rowPadV)
        }
        .tint(.primary)
        .accessibilityLabel("Effort: \(item.habit.blockSize.rawValue)")
    }

    @ViewBuilder
    private var frequencyFormRow: some View {
        Menu {
            Button { onUpdateFrequencyPreset("daily"); HapticsEngine.tick() } label: { Text("Daily") }
            Button { onUpdateFrequencyPreset("weekdays"); HapticsEngine.tick() } label: { Text("Weekdays") }
            Button { onUpdateFrequencyPreset("weekends"); HapticsEngine.tick() } label: { Text("Weekends") }
            Divider()
            Button { onUpdateFrequencyPreset("today"); HapticsEngine.tick() } label: { Text("Once (Today)") }
            Button { onUpdateFrequencyPreset("tomorrow"); HapticsEngine.tick() } label: { Text("Once (Tomorrow)") }
        } label: {
            HStack {
                Image(systemName: "calendar")
                    .font(.body)
                    .foregroundStyle(item.habit.category.style.baseColor)
                    .frame(width: iconFrameWidth)
                Text("Days")
                    .font(Typography.bodyMedium)
                    .foregroundStyle(.primary)
                Spacer()
                Text(frequencyLabel)
                    .font(Typography.bodySmall)
                    .foregroundStyle(item.habit.category.style.baseColor)
            }
            .padding(.horizontal, rowPadH)
            .padding(.vertical, rowPadV)
        }
        .tint(.primary)
        .accessibilityLabel("Frequency: \(frequencyLabel)")
    }

    // MARK: - Compact Pill Row (kept for reference, replaced by form rows above)

    @ViewBuilder
    private var compactPillRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Group 1: What — Category + Effort
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(HabitCategory.selectable, id: \.self) { cat in
                        Button {
                            onUpdateCategory(cat)
                            HapticsEngine.tick()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: cat.iconName)
                                    .font(Typography.caption)
                                Text(cat.rawValue.capitalized)
                                    .font(Typography.bodySmall)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                item.habit.category == cat
                                    ? cat.style.baseColor
                                    : GridConstants.fillTrack,
                                in: Capsule()
                            )
                            .foregroundStyle(item.habit.category == cat ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Effort — segmented picker (matches Add screen)
            Picker("Effort", selection: Binding(
                get: { item.habit.blockSize },
                set: { onUpdateSize($0); HapticsEngine.tick() }
            )) {
                ForEach([BlockSize.small, .medium, .hard], id: \.self) { size in
                    Text(size.effortLabel).tag(size)
                }
            }
            .pickerStyle(.segmented)

            Divider().opacity(0.3)

            // Group 2: When — Duration + Schedule
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([15, 30, 45, 60, 90, 120], id: \.self) { mins in
                        Button {
                            item.habit.customDurationMinutes = mins
                            try? modelContext.save()
                            HapticsEngine.tick()
                        } label: {
                            Text(formatDuration(mins))
                                .font(Typography.bodySmall)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    item.habit.effectiveDurationMinutes == mins
                                        ? item.habit.category.style.baseColor
                                        : GridConstants.fillTrack,
                                    in: Capsule()
                                )
                                .foregroundStyle(item.habit.effectiveDurationMinutes == mins ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Stepper(
                formatDuration(item.habit.effectiveDurationMinutes),
                value: Binding(
                    get: { item.habit.effectiveDurationMinutes },
                    set: { item.habit.customDurationMinutes = $0; try? modelContext.save() }
                ),
                in: 5...180, step: 5
            )
            .font(Typography.bodySmall)

            // Day schedule — inline circles (recurring only)
            if !item.habit.isTodo {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(DayCode.allCases, id: \.self) { day in
                            let isSelected = item.habit.frequency.contains(day)
                            Button {
                                var days = Set(item.habit.frequency)
                                if isSelected { days.remove(day) } else { days.insert(day) }
                                item.habit.frequency = Array(days)
                                try? modelContext.save()
                                HapticsEngine.tick()
                            } label: {
                                Text(day.rawValue)
                                    .font(Typography.bodySmall)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        isSelected ? item.habit.category.style.baseColor : GridConstants.fillTrack,
                                        in: Circle()
                                    )
                                    .foregroundStyle(isSelected ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(day.rawValue), \(isSelected ? "selected" : "not selected")")
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                }
            }

            Divider().opacity(0.3)

            // Group 3: Settings — Grace + Type
            if !item.habit.isTodo {
                Stepper(
                    "\(item.habit.graceDays)-day forgiveness window",
                    value: Binding(
                        get: { item.habit.graceDays },
                        set: { item.habit.graceDays = $0; try? modelContext.save() }
                    ),
                    in: 0...7
                )
                .font(Typography.bodySmall)
                .help("Days you can skip without resetting your streak")
            }

            // Routine ↔ To-Do toggle
            Toggle("One-time (not recurring)", isOn: Binding(
                get: { item.habit.isTodo },
                set: { newVal in
                    item.habit.isTodo = newVal
                    if newVal {
                        item.habit.frequencyRawValues = []
                        item.habit.scheduledDate = TimelineViewModel.dateString(from: Date())
                    } else {
                        item.habit.scheduledDate = nil
                        item.habit.frequencyRawValues = DayCode.allCases.map(\.rawValue)
                    }
                    try? modelContext.save()
                }
            ))
            .font(Typography.bodySmall)
            .tint(item.habit.category.style.baseColor)
        }
    }

    // MARK: - Time Row

    @ViewBuilder
    private var timeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(gentle) { showTimePicker.toggle() }
                HapticsEngine.tick()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(item.habit.scheduledTime != nil
                         ? BlockTimeFormatter.format12Hour(item.habit.scheduledTime!)
                         : "Anytime")
                        .font(Typography.bodySmall)
                }
                .foregroundStyle(item.habit.scheduledTime != nil ? .primary : .tertiary)
            }
            .buttonStyle(.plain)

            if showTimePicker {
                // Timeline Glimpse — behind toggle to reduce visual noise (Gestalt Proximity)
                if !scheduledSiblings.isEmpty {
                    Button {
                        withAnimation(smooth) { showGlimpse.toggle() }
                        HapticsEngine.lightTap()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: showGlimpse ? "eye.slash" : "eye")
                                .font(.body)
                                .foregroundStyle(item.habit.category.style.baseColor)
                                .frame(width: iconFrameWidth)
                            Text(showGlimpse ? "Hide schedule" : "Show schedule")
                                .font(Typography.bodySmall)
                                .foregroundStyle(item.habit.category.style.baseColor)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)

                    if showGlimpse {
                        timelineGlimpseStrip
                    }
                }

                // Suggestion pill — one-tap scheduling (Fitts' Law)
                if let slot = suggestedSlot {
                    Button {
                        onUpdateTime(slot)
                        HapticsEngine.snap()
                        withAnimation(gentle) { showTimePicker = false }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.caption)
                            Text("Next open: \(BlockTimeFormatter.format12Hour(slot))")
                                .font(Typography.bodySmall)
                        }
                        .foregroundStyle(item.habit.category.style.baseColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(item.habit.category.style.baseColor.opacity(0.15), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Set time to \(BlockTimeFormatter.format12Hour(slot))")
                }

                HStack {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: {
                                guard let timeStr = item.habit.scheduledTime else { return Date.now }
                                let parts = timeStr.split(separator: ":")
                                guard let h = Int(parts.first ?? ""), let m = Int(parts.last ?? "") else { return Date.now }
                                var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date.now)
                                comps.hour = h; comps.minute = m
                                return Calendar.current.date(from: comps) ?? Date.now
                            },
                            set: { newDate in
                                let cal = Calendar.current
                                onUpdateTime(String(format: "%02d:%02d", cal.component(.hour, from: newDate), cal.component(.minute, from: newDate)))
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .accessibilityLabel("Scheduled time")

                    if item.habit.scheduledTime != nil {
                        Button {
                            onUpdateTime(nil)
                            HapticsEngine.tick()
                            withAnimation(gentle) { showTimePicker = false }
                        } label: {
                            Text("Remove time")
                                .font(Typography.bodySmall)
                                .foregroundStyle(AppColors.warmRed)
                        }
                        .buttonStyle(.plain)
                        .frame(minHeight: 44)
                    }
                }
            }
        }
    }

    // MARK: - Timeline Glimpse Strip (Time Blindness scaffold — Barkley 1997)

    private let glimpseHourStart = 6
    private let glimpseHourEnd = 23
    private let glimpseSegmentWidth: CGFloat = 17

    @ViewBuilder
    private var timelineGlimpseStrip: some View {
        let totalHours = glimpseHourEnd - glimpseHourStart
        let totalWidth = CGFloat(totalHours) * glimpseSegmentWidth

        VStack(alignment: .leading, spacing: 4) {
            // Hour markers
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(GridConstants.fillWell)
                    .frame(width: totalWidth, height: 24)

                // Occupied slots
                ForEach(scheduledSiblings, id: \.id) { sibling in
                    if let hour = TimelineViewModel.effectiveHour(for: sibling) {
                        let x = (hour - Double(glimpseHourStart)) * Double(glimpseSegmentWidth)
                        let w = sibling.blockSize.durationMinutes / 60.0 * Double(glimpseSegmentWidth)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(sibling.category.style.baseColor)
                            .overlay {
                                if CGFloat(w) >= 12 {
                                    Image(systemName: sibling.category.iconName)
                                        .font(Typography.miniBlockIcon.weight(.bold))
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                            }
                            .frame(width: max(4, CGFloat(w)), height: 18)
                            .offset(x: CGFloat(x))
                    }
                }

                // Proposed slot (current habit)
                if item.habit.scheduledTime != nil,
                   let hour = TimelineViewModel.effectiveHour(for: item.habit) {
                    let x = (hour - Double(glimpseHourStart)) * Double(glimpseSegmentWidth)
                    let w = item.habit.blockSize.durationMinutes / 60.0 * Double(glimpseSegmentWidth)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(item.habit.category.style.baseColor.opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(item.habit.category.style.baseColor, lineWidth: 1.5)
                        )
                        .overlay {
                            if CGFloat(w) >= 12 {
                                Image(systemName: item.habit.category.iconName)
                                    .font(Typography.miniBlockIcon.weight(.bold))
                                    .foregroundStyle(item.habit.category.style.baseColor.opacity(0.6))
                            }
                        }
                        .frame(width: max(4, CGFloat(w)), height: 18)
                        .offset(x: CGFloat(x))
                }

                // Hour labels (6a, 12p, 6p)
                ForEach([6, 12, 18], id: \.self) { hour in
                    let label = hour == 12 ? "12p" : (hour < 12 ? "\(hour)a" : "\(hour - 12)p")
                    Text(label)
                        .font(Typography.caption)
                        .foregroundStyle(.primary.opacity(0.5))
                        .offset(x: CGFloat(hour - glimpseHourStart) * glimpseSegmentWidth - 6, y: 14)
                }
            }
            .frame(width: totalWidth, height: 36, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("Day schedule: \(scheduledSiblings.count) habits scheduled")
    }

    // MARK: - Subtask Section

    @ViewBuilder
    private var subtaskSection: some View {
        if !subtasks.isEmpty || isExpanded {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(subtasks) { subtask in
                    HStack(spacing: 8) {
                        Button {
                            onToggleSubTask(subtask.habit)
                            HapticsEngine.tick()
                        } label: {
                            Image(systemName: subtask.habit.isStepCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.caption)
                                .foregroundStyle(subtask.habit.isStepCompleted ? item.habit.category.style.baseColor : Color(.tertiaryLabel))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(subtask.habit.title), \(subtask.habit.isStepCompleted ? "completed" : "incomplete")")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAddTraits(subtask.habit.isStepCompleted ? .isSelected : [])
                        // Always-editable subtask (Apple Notes pattern)
                        TextField("Step", text: Binding(
                            get: { subtask.habit.title },
                            set: { subtask.habit.title = $0 }
                        ))
                        .font(Typography.bodySmall)
                        .strikethrough(subtask.habit.isStepCompleted, color: .secondary)
                        .foregroundStyle(subtask.habit.isStepCompleted ? .tertiary : .secondary)
                        .focused($editingItemID, equals: subtask.id)
                        Spacer()
                    }
                    .frame(minHeight: 44) // Apple HIG: 44pt minimum touch target
                    .padding(.leading, 8)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            HapticsEngine.snap()
                            onDeleteSubTask(subtask.habit)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }

                // "+ Add step" — full form row pattern (Fix 4: Fitts' Law)
                Button {
                    onAddSubTask()
                    HapticsEngine.snap()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                            .font(.body)
                            .foregroundStyle(item.habit.category.style.baseColor)
                            .frame(width: iconFrameWidth)
                        Text("Add another step")
                            .font(Typography.bodySmall)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, rowPadH)
                    .padding(.vertical, rowPadV)
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
        }
    }

    // MARK: - Labels

    private func categoryLabel(_ cat: HabitCategory) -> String {
        switch cat {
        case .health: return "Health"
        case .work: return "Work"
        case .creativity: return "Create"
        case .focus: return "Focus"
        case .social: return "Social"
        case .mindfulness: return "Mind"
        case .unlabeled:   return "Unlabeled"
        }
    }

    private func effortLabel(_ size: BlockSize) -> String {
        size.effortLabel
    }

    private func formatDuration(_ mins: Int) -> String {
        if mins < 60 { return "\(mins)m" }
        let h = mins / 60
        let m = mins % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    private var frequencyLabel: String {
        if item.habit.isTodo { return "Once" }
        let freq = item.habit.frequency
        if freq.count == DayCode.allCases.count { return "Daily" }
        let weekdays: Set<DayCode> = [.mo, .tu, .we, .th, .fr]
        if Set(freq) == weekdays { return "Weekdays" }
        let weekends: Set<DayCode> = [.sa, .su]
        if Set(freq) == weekends { return "Weekends" }
        if freq.isEmpty { return "Unscheduled" }
        return freq.map(\.rawValue).joined(separator: " ")
    }
}
