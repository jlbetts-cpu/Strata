import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ScheduleTimelineView: View {
    let weekData: [DayProgressData]
    @Binding var selectedDate: Date
    let allHabits: [Habit]
    let completedHabitIDs: Set<UUID>
    let skippedHabitIDs: Set<UUID>
    let isViewingToday: Bool
    let isViewingPast: Bool
    let onComplete: (Habit) -> Void
    let onSkip: (Habit) -> Void
    let onUndo: (Habit) -> Void
    let onUndoSkip: (Habit) -> Void
    let onAddHabit: (String?) -> Void
    var onEditInPlan: ((Habit) -> Void)? = nil
    var towerBlockCount: Int = 0
    var debugTower: Tower? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showScheduleSuggestion: Bool = false
    @State private var suggestedTime: String = ""
    @State private var habitToSchedule: Habit? = nil
    @State private var unscheduledCollapsed: Bool = false
    @AppStorage("hasCompletedFirstHabit") private var hasCompletedFirstHabit: Bool = false
    @State private var viewMode: TimelineViewMode = .day
    @State private var draggingChipID: UUID? = nil
    @State private var isDropTargeted: Bool = false
    @State private var hoverInsertionIndex: Int? = nil
    @State private var hoverTimeLabel: String? = nil
    @State private var rowFrames: [UUID: CGRect] = [:]

    enum TimelineViewMode: String, CaseIterable {
        case day, week
    }

    private let cornerRadius: CGFloat = GridConstants.cornerRadius

    // MARK: - Cached Habit Lists

    @State private var scheduledHabits: [Habit] = []
    @State private var unscheduledHabits: [Habit] = []

    private func recomputeHabitLists() {
        scheduledHabits = allHabits
            .filter { $0.scheduledTime != nil }
            .sorted { (TimelineViewModel.effectiveHour(for: $0) ?? 0) < (TimelineViewModel.effectiveHour(for: $1) ?? 0) }
        unscheduledHabits = allHabits
            .filter { $0.scheduledTime == nil }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Progress for selected date
    private var selectedDayProgress: DayProgressData? {
        weekData.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    /// Current hour for "now" highlighting
    private var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }

    /// Date for hero header — "March 22"
    private var heroDate: String {
        selectedDate.formatted(.dateTime.month(.wide).day())
    }

    /// Vitality score (0.0–1.0) — ambient progress indicator (Goal Gradient Effect, Hull 1932)
    private var vitality: Double {
        let total = scheduledHabits.count + unscheduledHabits.count
        guard total > 0 else { return 0 }
        return Double(completedHabitIDs.count) / Double(total)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    // Date + Day/Week picker
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(heroDate)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.primary)
                                .onTapGesture {
                                    guard !isViewingToday else { return }
                                    withAnimation(GridConstants.motionSmooth) {
                                        selectedDate = Date()
                                    }
                                    HapticsEngine.tick()
                                }

                            // Ambient tower progress (cross-tab cognition — Sweller 1988)
                            if towerBlockCount > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "square.stack.fill")
                                        .font(.system(size: 10))
                                    Text("\(towerBlockCount) blocks")
                                        .font(Typography.caption2)
                                }
                                .foregroundStyle(Color.primary.opacity(0.3))
                            }
                        }

                        Spacer()

                        Picker("", selection: $viewMode) {
                            Text("Day").tag(TimelineViewMode.day)
                            Text("Wk").tag(TimelineViewMode.week)
                        }
                        .pickerStyle(.segmented)
                        .tint(AppColors.accentWarm)
                        .frame(width: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    WeekProgressStrip(weekData: weekData, selectedDate: $selectedDate)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }
                // Vitality tint — ambient progress (Goal Gradient Effect, Hull 1932)
                .background(
                    AppColors.healthGreen.opacity(vitality * 0.06)
                        .animation(GridConstants.progressFill, value: vitality)
                )

                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 0.5)

                // Content switches on viewMode
                if viewMode == .day {
                    // Day mode (current)
                    if !unscheduledHabits.isEmpty {
                        unscheduledSection
                    }

                    scheduledSection
                        .onDrop(of: [.text], delegate: makeDropDelegate())
                        .coordinateSpace(name: "timeline")
                        .onPreferenceChange(RowFramePreference.self) { frames in
                            rowFrames = frames
                        }

                    if allHabits.isEmpty {
                        fullEmptyState
                            .padding(.top, 80)
                    }
                } else {
                    // Week mode
                    weekSummaryView
                }
            }
            .padding(.bottom, 100)
            .animation(GridConstants.crossFade, value: selectedDate)
            .animation(GridConstants.motionSmooth, value: viewMode)
        }
        #if DEBUG
        .overlay(alignment: .topTrailing) { debugMenu }
        #endif
        .background { WarmBackground().ignoresSafeArea() }
        .onAppear { recomputeHabitLists() }
        .onChange(of: allHabits) { recomputeHabitLists() }
        .onChange(of: completedHabitIDs) { recomputeHabitLists() }
        .onChange(of: viewMode) { HapticsEngine.tick() }
        .onChange(of: selectedDate) { _, _ in
            recomputeHabitLists()
            // T10: Reset stale suggestion state on date change
            showScheduleSuggestion = false
            habitToSchedule = nil
            suggestedTime = ""
        }
        .confirmationDialog(
            "Schedule \(habitToSchedule?.title ?? "")",
            isPresented: $showScheduleSuggestion,
            titleVisibility: .visible
        ) {
            Button("Schedule for \(BlockTimeFormatter.format12Hour(suggestedTime))") {
                if let habit = habitToSchedule, !habit.isDeleted {
                    withAnimation(reduceMotion ? GridConstants.motionReduced : GridConstants.motionSmooth) {
                        habit.scheduledTime = suggestedTime
                        try? modelContext.save()
                    }
                }
            }
            // Removed misleading "Pick a different time" — only offer the suggested time or cancel
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Unscheduled Section (horizontal chips above timeline)

    private var unscheduledSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            Button {
                HapticsEngine.lightTap()
                withAnimation(reduceMotion ? GridConstants.motionReduced : GridConstants.motionGentle) {
                    unscheduledCollapsed.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text("UNSCHEDULED")
                        .font(Typography.caption)
                        .tracking(0.5)
                        .foregroundStyle(Color.primary.opacity(0.5))

                    Text("(\(unscheduledHabits.count))")
                        .font(Typography.caption)
                        .foregroundStyle(Color.primary.opacity(0.35))

                    Spacer()

                    Image(systemName: unscheduledCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.35))
                }
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .padding(.horizontal, 20)

            if !unscheduledCollapsed {
                // Horizontal scroll chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(unscheduledHabits) { habit in
                            unscheduledChip(habit: habit)
                                .padding(.vertical, 4) // Prevent rotated corners from clipping
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Sandbox Rotation (stable, deterministic)

    private func sandboxRotation(for id: UUID) -> Angle {
        let chars = Array(id.uuidString.utf8)
        let seed = chars.reduce(0) { ($0 &+ Int($1)) &* 31 }
        let normalized = Double(abs(seed) % 600) / 100.0 - 3.0 // ±3.0°
        return .degrees(normalized)
    }

    private func unscheduledChip(habit: Habit) -> some View {
        let style = habit.category.style
        let isCompleted = completedHabitIDs.contains(habit.id)
        let isDragging = draggingChipID == habit.id

        // Chip label (shared between drag and tap)
        let chipLabel = HStack(spacing: 6) {
            Image(systemName: habit.category.iconName)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(isCompleted ? .white.opacity(0.7) : style.baseColor)

            Text(habit.title)
                .font(Typography.bodySmall)
                .foregroundStyle(isCompleted ? .white : Color.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isCompleted ? style.baseColor : Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(style.baseColor.opacity(isCompleted ? 0.3 : 0.6), lineWidth: 1.5)
        )

        return chipLabel
            // Sandbox rotation: ±3° when loose, 0° when picked up
            .rotationEffect(isDragging ? .zero : sandboxRotation(for: habit.id))
            .scaleEffect(isDragging ? 1.06 : 1.0)
            .animation(GridConstants.naturalSettle, value: isDragging)
            // Primary: drag to schedule
            .onDrag {
                draggingChipID = habit.id
                HapticsEngine.snap()
                return NSItemProvider(object: habit.id.uuidString as NSString)
            }
            // Fallback: tap to suggest slot
            .onTapGesture {
                HapticsEngine.tick()
                suggestOpenSlot(for: habit)
            }
            .frame(minHeight: 44)
            .accessibilityHint("Drag to schedule, or tap for suggested time")
    }

    // MARK: - Scheduled Section (flat list with time labels)

    /// The next incomplete habit (for "Up Next" indicator)
    private var nextUpHabitID: UUID? {
        guard isViewingToday else { return nil }
        let now = Double(currentHour) + Double(Calendar.current.component(.minute, from: Date())) / 60.0
        return scheduledHabits.first { habit in
            !completedHabitIDs.contains(habit.id) &&
            !skippedHabitIDs.contains(habit.id) &&
            (TimelineViewModel.effectiveHour(for: habit) ?? 0) >= now - 0.5
        }?.id
    }

    private var scheduledSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !scheduledHabits.isEmpty {
                // Remaining = ALL habits (scheduled + unscheduled) neither completed nor skipped
                let allTodayHabits = scheduledHabits + unscheduledHabits
                let remaining = allTodayHabits.filter { !completedHabitIDs.contains($0.id) && !skippedHabitIDs.contains($0.id) }.count
                let allCompleted = allTodayHabits.allSatisfy { completedHabitIDs.contains($0.id) }
                if remaining > 0 {
                    Text("\(remaining) remaining")
                        .font(Typography.bodySmall)
                        .foregroundStyle(Color.primary.opacity(0.5))
                        .contentTransition(.numericText())
                        .animation(GridConstants.motionSmooth, value: remaining)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                } else if allCompleted {
                    // All completed (none just skipped) — celebratory
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(AppColors.healthGreen)
                        Text("All done!")
                            .font(Typography.bodySmall)
                            .foregroundStyle(AppColors.healthGreen.opacity(0.7))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    .transition(.scale.combined(with: .opacity))
                    .onAppear {
                        HapticsEngine.success()
                    }
                } else {
                    // Mix of completed + skipped — neutral closure
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.primary.opacity(0.4))
                        Text("All cleared")
                            .font(Typography.bodySmall)
                            .foregroundStyle(Color.primary.opacity(0.5))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    .transition(.scale.combined(with: .opacity))
                }

                // Habit rows with time labels
                ForEach(scheduledHabits) { habit in
                    let isCompleted = completedHabitIDs.contains(habit.id)
                    let isSkipped = skippedHabitIDs.contains(habit.id)
                    let blockHeight: CGFloat = {
                        switch habit.blockSize {
                        case .small: return 56
                        case .medium: return 72
                        case .hard: return 88
                        }
                    }()
                    let isNow = isCurrentHabit(habit)
                    let isNextUp = habit.id == nextUpHabitID

                    HStack(alignment: .top, spacing: 0) {
                        // Time label + "NEXT" badge
                        VStack(spacing: 2) {
                            // "NEXT" badge on the first incomplete habit
                            if isNextUp && isViewingToday {
                                Text("NEXT")
                                    .font(Typography.caption2)
                                    .fontWeight(.bold)
                                    .tracking(0.5)
                                    .foregroundStyle(AppColors.warmRed)
                            }

                            if let time = habit.scheduledTime {
                                Text(BlockTimeFormatter.format12Hour(time))
                                    .font(isNow || isNextUp ? Typography.caption : Typography.caption2)
                                    .fontWeight(isNow || isNextUp ? .bold : .regular)
                                    .foregroundStyle(isNow ? AppColors.warmRed : Color.primary.opacity(isNextUp ? 0.85 : 0.55))
                            }
                        }
                        .frame(width: 56, alignment: .trailing)
                        .padding(.trailing, 12)
                        .padding(.top, 4)

                        // Habit block
                        TimelineHabitRow(
                            habit: habit,
                            rowHeight: blockHeight,
                            cornerRadius: cornerRadius,
                            onComplete: { completedHabit in
                                hasCompletedFirstHabit = true
                                onComplete(completedHabit)
                            },
                            onSkip: { skippedHabit in
                                onSkip(skippedHabit)
                            },
                            onUndo: { habit in
                                onUndo(habit)
                            },
                            onUndoSkip: { habit in
                                onUndoSkip(habit)
                            },
                            isAlreadyCompleted: isCompleted,
                            isAlreadySkipped: isSkipped
                        )
                        .opacity(isViewingPast && !isCompleted && !isSkipped ? 0.5 : 1.0)
                    }
                    // Cross-tab navigation: Edit in Plan (Pirolli & Card 1999 — information scent)
                    .contextMenu {
                        if let onEdit = onEditInPlan {
                            Button {
                                onEdit(habit)
                            } label: {
                                Label("Edit in Plan", systemImage: "list.bullet.clipboard")
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    // Track frame for DropDelegate parting calculation
                    .background(GeometryReader { geo in
                        Color.clear.preference(key: RowFramePreference.self,
                            value: [habit.id: geo.frame(in: .named("timeline"))])
                    })
                    // Timeline Parting: push rows apart when chip hovers
                    .offset(y: {
                        guard let hover = hoverInsertionIndex else { return CGFloat(0) }
                        let sortedIDs = scheduledHabits.map(\.id)
                        let myIndex = sortedIDs.firstIndex(of: habit.id) ?? 0
                        return myIndex >= hover ? CGFloat(44) : CGFloat(0)
                    }())
                    .animation(GridConstants.motionSmooth, value: hoverInsertionIndex)

                    // Insertion indicator at hover point with time preview
                    if let hover = hoverInsertionIndex,
                       hover < scheduledHabits.count,
                       habit.id == scheduledHabits[hover].id {
                        HStack(spacing: 8) {
                            if let time = hoverTimeLabel {
                                Text(time)
                                    .font(Typography.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(AppColors.healthGreen)
                                    .frame(width: 56, alignment: .trailing)
                            }
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppColors.healthGreen.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                                .frame(height: 4)
                        }
                        .padding(.horizontal, 16)
                        .transition(.opacity)
                    }

                    // First-launch hint below the first incomplete habit
                    if isNextUp && isViewingToday && !hasCompletedFirstHabit {
                        Text("Swipe right to complete →")
                            .font(Typography.caption)
                            .foregroundStyle(Color.primary.opacity(0.35))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 4)
                            .transition(.opacity)
                    }
                }
            } else if unscheduledHabits.isEmpty {
                // No habits at all — handled by fullEmptyState
            } else {
                // All habits are unscheduled
                VStack(spacing: 12) {
                    Text("No scheduled habits")
                        .font(Typography.bodyMedium)
                        .foregroundStyle(Color.primary.opacity(0.3))

                    Text("Tap a flexible habit above to schedule it")
                        .font(Typography.caption)
                        .foregroundStyle(Color.primary.opacity(0.25))

                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.2))
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            }
        }
    }

    // MARK: - Current Habit Highlight

    private func isCurrentHabit(_ habit: Habit) -> Bool {
        guard !completedHabitIDs.contains(habit.id) else { return false }
        guard isViewingToday else { return false }
        guard let hour = TimelineViewModel.effectiveHour(for: habit) else { return false }
        let now = Double(currentHour) + Double(Calendar.current.component(.minute, from: Date())) / 60.0
        let duration = habit.blockSize.durationMinutes / 60.0
        return now >= hour && now < hour + duration
    }

    // MARK: - Suggest Open Slot

    /// Schedule a dropped habit using gap-finding logic (v1: next open slot, v2: positional)
    private func scheduleDroppedHabit(id: UUID) {
        guard let habit = allHabits.first(where: { $0.id == id }), !habit.isDeleted else { return }
        let time = findNextOpenSlotTime(for: habit)
        withAnimation(GridConstants.motionSmooth) {
            habit.scheduledTime = time
            try? modelContext.save()
        }
    }

    /// Find next open time slot for a habit (reused by both drop and dialog)
    private func findNextOpenSlotTime(for habit: Habit) -> String {
        let scheduled = scheduledHabits
        let duration = habit.blockSize.durationMinutes
        let dayStart = 6 * 60
        let dayEnd = 23 * 60

        var busyRanges: [(start: Int, end: Int)] = []
        for h in scheduled {
            if let hour = TimelineViewModel.effectiveHour(for: h) {
                let start = Int(hour * 60)
                let end = start + Int(h.blockSize.durationMinutes)
                busyRanges.append((start, end))
            }
        }
        busyRanges.sort { $0.start < $1.start }

        let nowMinutes = currentHour * 60 + Calendar.current.component(.minute, from: Date())
        var searchStart = dayStart

        for busy in busyRanges {
            if busy.start - searchStart >= Int(duration) && searchStart >= nowMinutes - 30 {
                let snapped = ((searchStart + 14) / 15) * 15
                return String(format: "%02d:%02d", snapped / 60, snapped % 60)
            }
            searchStart = max(searchStart, busy.end)
        }

        if dayEnd - searchStart >= Int(duration) {
            let snapped = ((searchStart + 14) / 15) * 15
            return String(format: "%02d:%02d", snapped / 60, snapped % 60)
        }

        // Fallback: next hour
        let h = min(22, currentHour + 1)
        return String(format: "%02d:00", h)
    }

    private func suggestOpenSlot(for habit: Habit) {
        let scheduled = scheduledHabits
        let duration = habit.blockSize.durationMinutes

        // Find gaps
        var slots: [(start: Int, end: Int)] = [] // in minutes from midnight
        let dayStart = 6 * 60 // 6 AM
        let dayEnd = 23 * 60 // 11 PM

        var busyRanges: [(start: Int, end: Int)] = []
        for h in scheduled {
            if let hour = TimelineViewModel.effectiveHour(for: h) {
                let start = Int(hour * 60)
                let end = start + Int(h.blockSize.durationMinutes)
                busyRanges.append((start, end))
            }
        }
        busyRanges.sort { $0.start < $1.start }

        // Find first gap that fits
        var searchStart = dayStart
        for busy in busyRanges {
            if busy.start - searchStart >= Int(duration) {
                slots.append((searchStart, busy.start))
            }
            searchStart = max(searchStart, busy.end)
        }
        if dayEnd - searchStart >= Int(duration) {
            slots.append((searchStart, dayEnd))
        }

        // Pick the best slot (prefer current time-of-day section)
        let nowMinutes = currentHour * 60 + Calendar.current.component(.minute, from: Date())
        let bestSlot = slots.first { $0.start >= nowMinutes } ?? slots.first

        if let slot = bestSlot {
            // Snap to 15-min intervals
            let snapped = ((slot.start + 14) / 15) * 15
            let h = snapped / 60
            let m = snapped % 60
            suggestedTime = String(format: "%02d:%02d", h, m)
            habitToSchedule = habit
            showScheduleSuggestion = true
        } else {
            // No gap found — just suggest next hour
            let h = min(22, currentHour + 1)
            suggestedTime = String(format: "%02d:00", h)
            habitToSchedule = habit
            showScheduleSuggestion = true
        }
    }

    // MARK: - Empty State

    private var fullEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.2))

            Text("Plan your day")
                .font(Typography.headerMedium)
                .foregroundStyle(Color.primary)

            Text("Add habits to start building your tower")
                .font(Typography.bodyMedium)
                .foregroundStyle(Color.primary.opacity(0.4))

            Button {
                onAddHabit(nil)
            } label: {
                Text("Add Habit")
                    .font(Typography.headerSmall)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppColors.accentWarm, in: Capsule())
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Week Summary View

    private var weekSummaryView: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 4) {
                ForEach(weekData) { day in
                    let isSelected = Calendar.current.isDate(day.date, inSameDayAs: selectedDate)

                    Button {
                        withAnimation(GridConstants.motionSmooth) {
                            selectedDate = day.date
                            viewMode = .day
                        }
                        HapticsEngine.tick()
                    } label: {
                        VStack(spacing: 4) {
                            // Habit matrix sparkline (chronologically sorted top→bottom)
                            if !day.habits.isEmpty {
                                habitMatrix(for: day)
                            } else if !day.isFuture {
                                Text("—")
                                    .font(Typography.caption2)
                                    .foregroundStyle(Color.primary.opacity(0.15))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(day.isToday ? AppColors.healthGreen.opacity(0.06) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }

    // MARK: - Habit Matrix (per-day blocks in week view)

    @ViewBuilder
    private func habitMatrix(for day: DayProgressData) -> some View {
        let columns = [GridItem(.adaptive(minimum: 16), spacing: 3)]
        LazyVGrid(columns: columns, spacing: 3) {
            ForEach(day.habits) { habit in
                let isDone = habit.isCompleted || habit.isSkipped
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isDone ? habit.category.style.baseColor : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(habit.category.style.baseColor.opacity(isDone ? 0 : 0.5), lineWidth: 1)
                    )
                    .frame(width: 16, height: 16)
                    .overlay {
                        Image(systemName: habit.category.iconName)
                            .font(.system(size: 8))
                            .foregroundStyle(isDone ? .white.opacity(0.8) : habit.category.style.baseColor.opacity(0.5))
                    }
            }
        }
    }

    // MARK: - Timeline Parting DropDelegate

    private func makeDropDelegate() -> TimelinePartingDropDelegate {
        TimelinePartingDropDelegate(
            scheduledHabits: scheduledHabits,
            rowFrames: rowFrames,
            hoverIndex: $hoverInsertionIndex,
            onDrop: { uuid, insertionIndex in
                scheduleDroppedHabitAtIndex(id: uuid, index: insertionIndex)
                draggingChipID = nil
                recomputeHabitLists() // CRITICAL: force immediate re-sort after in-place mutation
                HapticsEngine.success()
            },
            onHoverChanged: { index in
                hoverTimeLabel = index != nil ? computeTimeForIndex(index!) : nil
            },
            onExit: {
                hoverInsertionIndex = nil
                hoverTimeLabel = nil
                draggingChipID = nil // Safety: ensure rotation restores if drag exits without drop
            }
        )
    }

    /// Compute the time label that would be assigned at a given insertion index
    private func computeTimeForIndex(_ index: Int) -> String {
        let sorted = scheduledHabits
        var h: Int
        var m: Int

        if sorted.isEmpty {
            return BlockTimeFormatter.format12Hour("09:00")
        } else if index <= 0 {
            let firstHour = TimelineViewModel.effectiveHour(for: sorted[0]) ?? 9.0
            let newHour = max(6.0, firstHour - 0.5)
            h = Int(newHour)
            m = ((Int((newHour - Double(h)) * 60) + 14) / 15) * 15
        } else if index >= sorted.count {
            let lastHabit = sorted[sorted.count - 1]
            let lastHour = TimelineViewModel.effectiveHour(for: lastHabit) ?? 15.0
            let lastEnd = lastHour + lastHabit.blockSize.durationMinutes / 60.0
            h = Int(lastEnd)
            m = ((Int((lastEnd - Double(h)) * 60) + 14) / 15) * 15
        } else {
            let beforeHour = TimelineViewModel.effectiveHour(for: sorted[index - 1]) ?? 9.0
            let beforeEnd = beforeHour + sorted[index - 1].blockSize.durationMinutes / 60.0
            let afterHour = TimelineViewModel.effectiveHour(for: sorted[index]) ?? 12.0
            let midpoint = (beforeEnd + afterHour) / 2.0
            h = Int(midpoint)
            m = ((Int((midpoint - Double(h)) * 60) + 14) / 15) * 15
        }
        if m >= 60 { h += 1; m = 0 }
        return BlockTimeFormatter.format12Hour(String(format: "%02d:%02d", h, m))
    }

    private func scheduleDroppedHabitAtIndex(id: UUID, index: Int) {
        guard let habit = allHabits.first(where: { $0.id == id }), !habit.isDeleted else { return }

        // Interpolate time from insertion position
        let sorted = scheduledHabits
        var time: String

        if sorted.isEmpty {
            time = "09:00"
        } else if index <= 0 {
            // Before first habit
            let firstHour = TimelineViewModel.effectiveHour(for: sorted[0]) ?? 9.0
            let newHour = max(6.0, firstHour - 0.5)
            let h = Int(newHour)
            let m = Int((newHour - Double(h)) * 60)
            time = String(format: "%02d:%02d", h, ((m / 15) * 15))
        } else if index >= sorted.count {
            // After last habit
            let lastHabit = sorted[sorted.count - 1]
            let lastHour = TimelineViewModel.effectiveHour(for: lastHabit) ?? 15.0
            let lastEnd = lastHour + lastHabit.blockSize.durationMinutes / 60.0
            let h = Int(lastEnd)
            let m = Int((lastEnd - Double(h)) * 60)
            time = String(format: "%02d:%02d", h, ((m / 15) * 15))
        } else {
            // Between two habits — midpoint
            let beforeHour = TimelineViewModel.effectiveHour(for: sorted[index - 1]) ?? 9.0
            let beforeEnd = beforeHour + sorted[index - 1].blockSize.durationMinutes / 60.0
            let afterHour = TimelineViewModel.effectiveHour(for: sorted[index]) ?? 12.0
            let midpoint = (beforeEnd + afterHour) / 2.0
            let h = Int(midpoint)
            let m = Int((midpoint - Double(h)) * 60)
            time = String(format: "%02d:%02d", h, ((m / 15) * 15))
        }

        withAnimation(GridConstants.motionSmooth) {
            habit.scheduledTime = time
            try? modelContext.save()
        }
    }

    // MARK: - Debug

    #if DEBUG
    private var debugMenu: some View {
        Menu {
            Button("Add Scheduled Habit", systemImage: "plus") {
                injectDebugHabit(scheduled: true)
            }
            Button("Add Unscheduled Habit", systemImage: "plus.circle") {
                injectDebugHabit(scheduled: false)
            }
            Button("Remove Last Habit", systemImage: "minus") {
                removeLastDebugHabit()
            }
        } label: {
            Text("Debug")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.top, 8)
        .padding(.trailing, 16)
    }

    private func injectDebugHabit(scheduled: Bool) {
        let namesByCategory: [HabitCategory: [String]] = [
            .health:      ["Morning Run", "Drink Water", "Stretch", "Gym", "Walk 10k Steps", "Sleep by 11"],
            .work:        ["Deep Work", "Clear Inbox", "Stand-Up", "Code Review", "Ship Feature", "Write Docs"],
            .creativity:  ["Sketch", "Write 500 Words", "Play Guitar", "Photography", "Design Sprint", "Journaling"],
            .focus:       ["Read 30 Min", "No Phone Hour", "Pomodoro x4", "Study Session", "Meditate", "Plan Tomorrow"],
            .social:      ["Call a Friend", "Family Dinner", "Coffee Chat", "Send Thank You", "Team Lunch", "Game Night"],
            .mindfulness: ["Meditate", "Breathwork", "Gratitude Log", "Body Scan", "Yoga", "Nature Walk"]
        ]
        let category = HabitCategory.allCases.randomElement()!
        let title = namesByCategory[category]!.randomElement()!
        let size = BlockSize.allCases.randomElement()!

        let scheduledTime: String? = scheduled ? {
            let hour = Int.random(in: 6...21)
            let minute = [0, 15, 30, 45].randomElement()!
            return String(format: "%02d:%02d", hour, minute)
        }() : nil

        let habit = Habit(
            title: title,
            category: category,
            blockSize: size,
            frequency: [DayCode.today()],
            scheduledTime: scheduledTime
        )
        habit.tower = debugTower
        modelContext.insert(habit)
        try? modelContext.save()
    }

    private func removeLastDebugHabit() {
        guard let last = allHabits.sorted(by: { $0.createdAt > $1.createdAt }).first else { return }
        modelContext.delete(last)
        try? modelContext.save()
    }
    #endif
}

// MARK: - Timeline Parting Drop Delegate

struct TimelinePartingDropDelegate: DropDelegate {
    let scheduledHabits: [Habit]
    let rowFrames: [UUID: CGRect]
    @Binding var hoverIndex: Int?
    let onDrop: (UUID, Int) -> Void
    var onHoverChanged: ((Int?) -> Void)? = nil
    let onExit: () -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let y = info.location.y
        let sorted = scheduledHabits.compactMap { habit -> (habit: Habit, midY: CGFloat)? in
            guard let frame = rowFrames[habit.id] else { return nil }
            return (habit, frame.midY)
        }.sorted { $0.midY < $1.midY }

        var computedIndex = sorted.count
        for (i, item) in sorted.enumerated() {
            if y < item.midY {
                computedIndex = i
                break
            }
        }
        hoverIndex = computedIndex
        onHoverChanged?(computedIndex)
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [.text]).first else { return false }
        let insertAt = hoverIndex ?? scheduledHabits.count
        _ = provider.loadObject(ofClass: NSString.self) { string, _ in
            guard let uuidString = string as? String,
                  let uuid = UUID(uuidString: uuidString) else { return }
            Task { @MainActor in
                onDrop(uuid, insertAt)
            }
        }
        hoverIndex = nil
        return true
    }

    func dropExited(info: DropInfo) {
        hoverIndex = nil
        onExit()
    }
}

// MARK: - Row Frame Preference Key

struct RowFramePreference: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}
