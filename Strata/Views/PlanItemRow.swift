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
    let scheduledSiblings: [Habit]
    let suggestedSlot: String?
    let isCompletedToday: Bool
    let isSkippedToday: Bool
    @FocusState.Binding var editingItemID: UUID?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.switchTab) private var switchTab

    @ScaledMetric(relativeTo: .body) private var rowPadH: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var rowPadV: CGFloat = 12
    @ScaledMetric(relativeTo: .footnote) private var pillPadH: CGFloat = 10
    @ScaledMetric(relativeTo: .footnote) private var pillPadV: CGFloat = 6

    @State private var editText: String = ""
    @State private var showTimePicker: Bool = false
    @State private var showDetailedMetadata: Bool = false
    @State private var showDeleteConfirm: Bool = false

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
                            // Completion badge (Carver & Scheier 1998 — feedback loop)
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
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .animation(GridConstants.crossFade, value: item.habit.category)
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
                    HStack(spacing: 6) {
                        Image(systemName: item.habit.isTodo ? "list.number" : "arrow.trianglehead.2.clockwise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(schedule)
                            .font(Typography.bodySmall)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .animation(gentle, value: isExpanded)
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
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
        // Left-edge category accent
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(item.habit.category.style.baseColor)
                .frame(width: 4)
                .padding(.vertical, 8)
        }
        .opacity(isCompletedToday ? 0.6 : (isSkippedToday ? 0.7 : 1.0))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isCompletedToday ? "Done: " : isSkippedToday ? "Skipped: " : "")\(item.habit.title), \(item.habit.category.rawValue), \(schedule)")
        .onChange(of: isExpanded) { _, newVal in
            if newVal { showDetailedMetadata = false }
        }
    }

    // MARK: - Expanded Card (Things 3 Inspired)

    @ViewBuilder
    private var expandedCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Block preview — visual bridge to Tower (Endowed Progress Effect — Nunes & Dreze 2006)
            blockPreviewSection

            // Phase 1: Smart summary (always visible) — Progressive Disclosure (Nielsen 2006)
            smartSummaryRow

            // Phase 2: Full pill row — revealed on tap (Hick's Law: defer choices)
            if showDetailedMetadata {
                compactPillRow
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }

            // Time row
            timeRow

            // Subtasks (if any exist or user wants to add)
            subtaskSection

            // Cross-tab navigation (Pirolli & Card 1999 — information scent)
            if isCompletedToday || isSkippedToday || !item.habit.isTodo {
                if let switchTab {
                    Button {
                        switchTab(.today)
                        HapticsEngine.lightTap()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isCompletedToday ? "checkmark.circle" : "arrow.right.circle")
                                .font(.caption)
                            Text(isCompletedToday ? "Done today" : isSkippedToday ? "Skipped today" : "View in Today")
                                .font(Typography.caption)
                        }
                        .foregroundStyle(isCompletedToday ? AppColors.healthGreen : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isCompletedToday ? "Completed today, view in Today tab" : "View this habit in Today tab")
                }
            }

            // Delete
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Text("Delete")
                    .font(Typography.bodySmall)
                    .foregroundStyle(AppColors.warmRed)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete \(item.habit.title)")
            .confirmationDialog("Delete \(item.habit.title)?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    HapticsEngine.snap()
                    onDelete()
                }
            }
        }
        .padding(rowPadH)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous)
        )
        .overlay(alignment: .top) {
            item.habit.category.style.baseColor.opacity(0.15)
                .frame(height: 1)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: GridConstants.cornerRadius,
                        topTrailingRadius: GridConstants.cornerRadius
                    )
                )
        }
        .padding(.horizontal, rowPadH)
        .padding(.bottom, rowPadV)
    }

    // MARK: - Block Preview (Visual Bridge to Tower)

    @ViewBuilder
    private var blockPreviewSection: some View {
        MiniBlockPreview(
            category: item.habit.category,
            blockSize: item.habit.blockSize,
            title: item.habit.title
        )
        .frame(minHeight: 80)
        .frame(maxWidth: .infinity)
        .animation(GridConstants.crossFade, value: item.habit.blockSize)
        .animation(GridConstants.crossFade, value: item.habit.category)
    }

    // MARK: - Smart Summary (Phase 1 — Progressive Disclosure)

    @ViewBuilder
    private var smartSummaryRow: some View {
        Button {
            withAnimation(gentle) { showDetailedMetadata.toggle() }
            HapticsEngine.lightTap()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: item.habit.category.iconName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(item.habit.category.style.baseColor)
                Text("\(categoryLabel(item.habit.category)) — \(effortLabel(item.habit.blockSize)) — \(frequencyLabel)")
                    .font(Typography.bodySmall)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: showDetailedMetadata ? "chevron.up" : "pencil")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.06), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Customize: \(categoryLabel(item.habit.category)), \(effortLabel(item.habit.blockSize)), \(frequencyLabel)")
        .accessibilityHint(showDetailedMetadata ? "Collapse options" : "Tap to customize category, effort, and frequency")
    }

    // MARK: - Compact Pill Row (Category + Effort + Frequency as Menu pickers)

    @ViewBuilder
    private var compactPillRow: some View {
        HStack(spacing: 8) {
            // Category menu
            Menu {
                ForEach(HabitCategory.allCases, id: \.self) { cat in
                    Button {
                        onUpdateCategory(cat)
                        HapticsEngine.tick()
                    } label: {
                        Label(categoryLabel(cat), systemImage: cat.iconName)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: item.habit.category.iconName)
                        .font(.caption.weight(.medium))
                    Text(categoryLabel(item.habit.category))
                        .font(Typography.bodySmall)
                        .fontWeight(.medium)
                }
                .foregroundStyle(item.habit.category.style.baseColor)
                .padding(.horizontal, pillPadH)
                .padding(.vertical, pillPadV)
                .background(item.habit.category.style.baseColor.opacity(0.12), in: Capsule())
            }
            .accessibilityLabel("Category: \(item.habit.category.rawValue)")

            // Effort menu
            Menu {
                Button { onUpdateSize(.small); HapticsEngine.tick() } label: { Text("Easy · 15m") }
                Button { onUpdateSize(.medium); HapticsEngine.tick() } label: { Text("Medium · 30m") }
                Button { onUpdateSize(.hard); HapticsEngine.tick() } label: { Text("Hard · 60m") }
            } label: {
                Text(effortLabel(item.habit.blockSize))
                    .font(Typography.bodySmall)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, pillPadH)
                    .padding(.vertical, pillPadV)
                    .background(Color.primary.opacity(0.06), in: Capsule())
                    .overlay(Capsule().stroke(item.habit.category.style.baseColor.opacity(0.2), lineWidth: 1))
            }
            .accessibilityLabel("Effort: \(item.habit.blockSize.rawValue)")

            // Frequency menu
            Menu {
                Button { onUpdateFrequencyPreset("daily"); HapticsEngine.tick() } label: { Text("Daily") }
                Button { onUpdateFrequencyPreset("weekdays"); HapticsEngine.tick() } label: { Text("Weekdays") }
                Button { onUpdateFrequencyPreset("weekends"); HapticsEngine.tick() } label: { Text("Weekends") }
                Divider()
                Button { onUpdateFrequencyPreset("today"); HapticsEngine.tick() } label: { Text("Once (Today)") }
                Button { onUpdateFrequencyPreset("tomorrow"); HapticsEngine.tick() } label: { Text("Once (Tomorrow)") }
            } label: {
                Text(frequencyLabel)
                    .font(Typography.bodySmall)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, pillPadH)
                    .padding(.vertical, pillPadV)
                    .background(Color.primary.opacity(0.06), in: Capsule())
                    .overlay(Capsule().stroke(item.habit.category.style.baseColor.opacity(0.2), lineWidth: 1))
            }
            .accessibilityLabel("Frequency: \(frequencyLabel)")

            Spacer()
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
                         : "No time set")
                        .font(Typography.bodySmall)
                }
                .foregroundStyle(item.habit.scheduledTime != nil ? .primary : .tertiary)
            }
            .buttonStyle(.plain)

            if showTimePicker {
                // Timeline Glimpse — schedule context (Spatial Contiguity — Mayer 2001)
                if !scheduledSiblings.isEmpty {
                    timelineGlimpseStrip
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
                                .font(.caption2)
                            Text("Next open: \(BlockTimeFormatter.format12Hour(slot))")
                                .font(Typography.caption)
                        }
                        .foregroundStyle(item.habit.category.style.baseColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(item.habit.category.style.baseColor.opacity(0.12), in: Capsule())
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

                    if item.habit.scheduledTime != nil {
                        Button {
                            onUpdateTime(nil)
                            HapticsEngine.tick()
                            withAnimation(gentle) { showTimePicker = false }
                        } label: {
                            Text("Clear")
                                .font(Typography.caption)
                                .foregroundStyle(AppColors.warmRed)
                        }
                        .buttonStyle(.plain)
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
                    .fill(Color.primary.opacity(0.04))
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
                        .font(Typography.caption2)
                        .foregroundStyle(.primary.opacity(0.35))
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
                        Image(systemName: "circle")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        // Always-editable subtask (Apple Notes pattern)
                        TextField("Step", text: Binding(
                            get: { subtask.habit.title },
                            set: { subtask.habit.title = $0; try? subtask.habit.modelContext?.save() }
                        ))
                        .font(Typography.bodySmall)
                        .foregroundStyle(.secondary)
                        .focused($editingItemID, equals: subtask.id)
                        Spacer()
                    }
                    .frame(minHeight: 36) // Clear hit area for tap-to-edit
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

                // "+ Add step" ghost row
                Button {
                    onAddSubTask()
                    HapticsEngine.snap()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.caption2)
                        Text("Add step")
                            .font(Typography.caption)
                    }
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 8)
                }
                .buttonStyle(.plain)
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
        }
    }

    private func effortLabel(_ size: BlockSize) -> String {
        switch size {
        case .small: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }

    private var frequencyLabel: String {
        if item.habit.isTodo { return "Once" }
        let freq = item.habit.frequency
        if freq.count == DayCode.allCases.count { return "Daily" }
        let weekdays: Set<DayCode> = [.mo, .tu, .we, .th, .fr]
        if Set(freq) == weekdays { return "Weekdays" }
        let weekends: Set<DayCode> = [.sa, .su]
        if Set(freq) == weekends { return "Weekends" }
        if freq.isEmpty { return "No days" }
        return freq.map(\.rawValue).joined(separator: " ")
    }
}
