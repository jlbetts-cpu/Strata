import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppIntents

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
    var onboarding: OnboardingState? = nil
    // debugTower removed — debug tools in Settings only
    var cachedStreaks: [UUID: Int] = [:]
    var healthKitProgress: [UUID: Double] = [:]
    var verifiedHabitIDs: Set<UUID> = []
    var calendarEvents: [CalendarAnchor] = []
    @Binding var deepLinkHabitID: UUID?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.switchTab) private var switchTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(FocusFilterService.self) private var focusFilterService

    @AppStorage("habitCompletionCount") private var completionCount: Int = 0
    @AppStorage("todayViewMode") private var viewMode: TodayViewMode = .list

    @State private var showScheduleSuggestion: Bool = false
    @State private var suggestedTime: String = ""
    @State private var habitToSchedule: Habit? = nil
    @State private var unscheduledCollapsed: Bool = false
    @AppStorage("hasCompletedFirstHabit") private var hasCompletedFirstHabit: Bool = false
    @AppStorage("hasSeenHealthKitVerification") private var hasSeenHealthKitVerification: Bool = false
    @State private var draggingChipID: UUID? = nil
    @State private var isDropTargeted: Bool = false
    @State private var hoverInsertionIndex: Int? = nil
    @State private var hoverTimeLabel: String? = nil
    @State private var rowFrames: [UUID: CGRect] = [:]
    @State private var recomputeTask: Task<Void, Never>?
    @State private var cachedCurrentHour: Int = Calendar.current.component(.hour, from: Date())
    @State private var cachedCurrentMinute: Int = Calendar.current.component(.minute, from: Date())
    @State private var cachedNowFraction: Double = {
        let h = Calendar.current.component(.hour, from: Date())
        let m = Calendar.current.component(.minute, from: Date())
        return Double(h) + Double(m) / 60.0
    }()
    @State private var cachedNextUpID: UUID? = nil


    private let cornerRadius: CGFloat = GridConstants.cornerRadius

    // MARK: - Cached Habit Lists

    @State private var scheduledHabits: [Habit] = []
    @State private var unscheduledHabits: [Habit] = []
    @State private var effectiveHours: [UUID: Double] = [:]
    @State private var remainingCount: Int = 0
    @State private var cachedHeroDate: String = ""
    @State private var sortedRowMidpoints: [(id: UUID, midY: CGFloat)] = []
    @State private var detailHabit: Habit? = nil
    @State private var counterFlash: Bool = false
    @State private var showCompletionToast: Bool = false
    @State private var hasPlayedAllClearToday: Bool = false
    @State private var showAllClearConfetti: Bool = false
    @State private var rowsRevealed: Bool = false
    @State private var staggerTask: Task<Void, Never>?
    @State private var isForwardNavigation: Bool = true
    @State private var showManualTimePicker: Bool = false
    @State private var manualScheduleTime: Date = Date()

    private func recomputeHabitLists() {
        // Pre-compute effectiveHour dictionary (avoid O(n log n) string parsing in sort)
        effectiveHours = Dictionary(uniqueKeysWithValues:
            allHabits.compactMap { habit -> (UUID, Double)? in
                guard let hour = TimelineViewModel.effectiveHour(for: habit) else { return nil }
                return (habit.id, hour)
            }
        )
        scheduledHabits = allHabits
            .filter { $0.scheduledTime != nil }
            .sorted { (effectiveHours[$0.id] ?? 0) < (effectiveHours[$1.id] ?? 0) }
        unscheduledHabits = allHabits
            .filter { $0.scheduledTime == nil }
            .sorted { $0.sortOrder < $1.sortOrder }

        // Cache remaining count (avoid O(n) per frame during animation)
        let all = scheduledHabits + unscheduledHabits
        remainingCount = all.filter { !completedHabitIDs.contains($0.id) && !skippedHabitIDs.contains($0.id) }.count

        // Cache time values (Fix 5: avoid repeated Calendar lookups)
        cachedCurrentHour = Calendar.current.component(.hour, from: Date())
        cachedCurrentMinute = Calendar.current.component(.minute, from: Date())
        cachedNowFraction = Double(cachedCurrentHour) + Double(cachedCurrentMinute) / 60.0

        // Cache nextUpHabitID — skip verified-ready habits (they don't need prompting)
        if isViewingToday {
            cachedNextUpID = scheduledHabits.first { habit in
                !completedHabitIDs.contains(habit.id) &&
                !skippedHabitIDs.contains(habit.id) &&
                !verifiedHabitIDs.contains(habit.id) &&
                (TimelineViewModel.effectiveHour(for: habit) ?? 0) >= cachedNowFraction - 0.5
            }?.id
        } else {
            cachedNextUpID = nil
        }
    }

    /// Debounced recompute — coalesces double-fires from allHabits + completedHabitIDs changing in same cycle
    private func scheduleRecompute() {
        recomputeTask?.cancel()
        recomputeTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(16))
            guard !Task.isCancelled else { return }
            recomputeHabitLists()
        }
    }

    /// Progress for selected date
    private var selectedDayProgress: DayProgressData? {
        weekData.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    /// Date for hero header — cached to avoid .formatted() on every body eval
    private var heroDate: String { cachedHeroDate.isEmpty ? selectedDate.formatted(.dateTime.month(.wide).day()) : cachedHeroDate }

    var body: some View {
        ScrollViewReader { scrollProxy in
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    // The date moved to the navigation title, which was
                    // saying "Today" while this said "September 6" — two labels
                    // for one thing, an inch apart. "Return to today" now lives
                    // on the week strip, which is where the dates are.
                    TodayViewModePicker(selection: $viewMode)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, GridConstants.horizontalPadding)
                    .padding(.top, 12)

                    WeekProgressStrip(weekData: weekData, selectedDate: $selectedDate)
                        .padding(.horizontal, GridConstants.horizontalPadding)
                        .padding(.bottom, 4)

                    // Week average removed — rings already communicate this visually
                }

                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 0.5)

                // Focus Filter banner
                if let focusCategory = focusFilterService.activeCategory {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(Typography.caption)
                        Text("Focus: \(focusCategory.rawValue.capitalized) only")
                            .font(Typography.caption)
                    }
                    .foregroundStyle(focusCategory.style.baseColor)
                    .padding(.horizontal, GridConstants.horizontalPadding)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(focusCategory.style.baseColor.opacity(0.15))
                }

                // Siri tip removed per user feedback

                // Daily schedule
                if !unscheduledHabits.isEmpty {
                    unscheduledSection
                }

                if viewMode == .list {
                    scheduledSection
                        .id(selectedDate)
                        .transition(.asymmetric(
                            insertion: .move(edge: isForwardNavigation ? .trailing : .leading).combined(with: .opacity),
                            removal: .move(edge: isForwardNavigation ? .leading : .trailing).combined(with: .opacity)
                        ))
                        .animation(reduceMotion ? .none : GridConstants.motionSmooth, value: selectedDate)
                        .onDrop(of: [.text], delegate: makeDropDelegate())
                        .coordinateSpace(name: "timeline")
                        .onPreferenceChange(RowFramePreference.self) { frames in
                            rowFrames = frames
                        }
                } else {
                    TimelineGridView(
                        scheduledHabits: scheduledHabits,
                        calendarEvents: calendarEvents,
                        completedHabitIDs: completedHabitIDs,
                        skippedHabitIDs: skippedHabitIDs,
                        cachedNowFraction: cachedNowFraction,
                        onComplete: onComplete,
                        onSkip: onSkip,
                        onUndo: onUndo,
                        onUndoSkip: onUndoSkip,
                        cachedStreaks: cachedStreaks,
                        healthKitProgress: healthKitProgress,
                        verifiedHabitIDs: verifiedHabitIDs
                    )
                    .id(selectedDate)
                    .transition(.opacity)
                }

                if allHabits.isEmpty {
                    fullEmptyState
                        .padding(.top, 80)
                }
            }
            .padding(.bottom, 100)
            .animation(reduceMotion ? .none : GridConstants.crossFade, value: selectedDate)
        }
        .background { WarmBackground().ignoresSafeArea() }
        .onChange(of: viewMode) { _, newMode in
            if newMode == .timeline {
                let currentHour = Int(cachedNowFraction)
                withAnimation { scrollProxy.scrollTo("hour-\(currentHour)", anchor: .center) }
            }
        }
        } // ScrollViewReader
        .overlay(alignment: .bottom) {
            if showCompletionToast {
                Text("Block added to your tower \(Image(systemName: "arrow.up.right"))")
                    .font(Typography.bodySmall)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 120)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
                    .accessibilityLabel("Block added to your tower")
            }
        }
        .onAppear {
            recomputeHabitLists()
            cachedHeroDate = selectedDate.formatted(.dateTime.month(.wide).day())
            // Onboarding: show hold hint when first habit appears
            if let onb = onboarding, !onb.hasSeenHoldHint, !scheduledHabits.isEmpty {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(1500))
                    if !onb.hasSeenHoldHint {
                        onb.hasSeenHoldHint = true
                        onb.showHint(.hold, duration: 5)
                    }
                }
            }
        }
        .onChange(of: allHabits) { scheduleRecompute() }
        .onChange(of: completedHabitIDs) {
            recomputeHabitLists() // Immediate — no debounce (Card 1991: <100ms)
            completionCount = completedHabitIDs.count
        }
        .onChange(of: selectedDate) { oldDate, newDate in
            isForwardNavigation = newDate > oldDate
            hasPlayedAllClearToday = false
            showAllClearConfetti = false
            // Reset row stagger for cascade entrance
            rowsRevealed = false
            staggerTask?.cancel()
            staggerTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                rowsRevealed = true
            }
            scheduleRecompute()
            cachedHeroDate = selectedDate.formatted(.dateTime.month(.wide).day())
            showScheduleSuggestion = false
            habitToSchedule = nil
            suggestedTime = ""
        }
        .onAppear {
            staggerTask?.cancel()
            staggerTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                rowsRevealed = true
            }
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
            Button("Pick a different time...") {
                showManualTimePicker = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showManualTimePicker) {
            if let habit = habitToSchedule {
                NavigationStack {
                    DatePicker("Schedule time", selection: $manualScheduleTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .navigationTitle("Pick a time")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    let cal = Calendar.current
                                    let h = cal.component(.hour, from: manualScheduleTime)
                                    let m = cal.component(.minute, from: manualScheduleTime)
                                    habit.scheduledTime = String(format: "%02d:%02d", h, m)
                                    try? modelContext.save()
                                    HapticsEngine.snap()
                                    showManualTimePicker = false
                                    habitToSchedule = nil
                                }
                            }
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { showManualTimePicker = false }
                            }
                        }
                }
                .presentationDetents([.medium])
            }
        }
        .sheet(item: $detailHabit) { habit in
            HabitDetailSheet(habit: habit, selectedDate: selectedDate)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: deepLinkHabitID) { _, newID in
            guard let habitID = newID else { return }
            if let habit = allHabits.first(where: { $0.id == habitID }) {
                detailHabit = habit
            }
            deepLinkHabitID = nil
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

                    Text(unscheduledCollapsed ? "\(unscheduledHabits.count) habits · tap to expand" : "(\(unscheduledHabits.count))")
                        .font(Typography.caption)
                        .foregroundStyle(Color.primary.opacity(0.35))

                    Spacer()

                    Image(systemName: unscheduledCollapsed ? "chevron.right" : "chevron.down")
                        .font(Typography.caption2)
                        .foregroundStyle(Color.primary.opacity(0.35))
                }
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .padding(.horizontal, GridConstants.horizontalPadding)

            if !unscheduledCollapsed {
                // Horizontal scroll chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(unscheduledHabits, id: \.id) { habit in
                            unscheduledChip(habit: habit)
                                .padding(.vertical, 4) // Prevent rotated corners from clipping
                        }
                    }
                    .padding(.horizontal, GridConstants.horizontalPadding)
                }
            }
        }
        .padding(.vertical, 12)
        .onAppear {
            // Smart collapse: reduce Hick's Law choice paralysis (Hick 1952)
            if unscheduledHabits.count > 5 {
                unscheduledCollapsed = true
            }
        }
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

        return HStack(spacing: 8) {
            // Content first (reading order — left to right)
            if let icon = habit.category.iconName {
                Image(systemName: icon)
                    .font(Typography.caption)
                    .foregroundStyle(isCompleted ? .white.opacity(0.7) : style.baseColor)
            }

            Text(habit.title)
                .font(Typography.bodySmall)
                .foregroundStyle(isCompleted ? .white : Color.primary)
                .lineLimit(1)

            Spacer()

            // Check circle — RIGHT side, matches scheduled rows (Fitts 1954, Nielsen 1994)
            Button {
                if isCompleted {
                    HapticsEngine.tick()
                    onUndo(habit)
                } else {
                    HapticsEngine.snap()
                    SoundEngine.completionTone(category: habit.category)
                    hasCompletedFirstHabit = true
                    onComplete(habit)
                }
            } label: {
                ZStack {
                    // Category colour, not white: the incomplete chip is a
                    // white card now, and a white ring on it is invisible.
                    Circle()
                        .stroke(style.baseColor.opacity(0.55), lineWidth: GridConstants.strokeMedium)
                        .frame(width: GridConstants.checkCircleSize, height: GridConstants.checkCircleSize)
                        .opacity(isCompleted ? 0.0 : 1.0)

                    if isCompleted {
                        Circle()
                            .fill(Color.white)
                            .frame(width: GridConstants.checkCircleSize, height: GridConstants.checkCircleSize)

                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(style.baseColor)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            if isCompleted {
                RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous)
                    .fill(style.baseColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous)
                            .stroke(style.baseColor.opacity(0.3), lineWidth: GridConstants.strokeDefault)
                    )
            } else {
                // Was Color.primary.opacity(0.08) — a grey darker than the page.
                BlockGhostSurface(
                    category: habit.category,
                    cornerRadius: GridConstants.cornerRadius,
                    scale: 0.85
                )
            }
        }
        // Tap chip body to schedule (with time choice)
        .onTapGesture {
            guard !isCompleted else { return }
            HapticsEngine.tick()
            habitToSchedule = habit
            suggestOpenSlot(for: habit)
        }
        .frame(minHeight: 44)
        .rotationEffect(sandboxRotation(for: habit.id))
        .accessibilityLabel("\(habit.title), \(habit.category.rawValue), unscheduled")
        .accessibilityHint("Tap circle to complete, or tap chip to schedule")
        .accessibilityAction(named: "Complete") { onComplete(habit) }
    }

    // MARK: - Calendar Ghost Event Block

    private func calendarGhostBlock(event: CalendarAnchor) -> some View {
        let eventColor = Color(red: event.colorRed, green: event.colorGreen, blue: event.colorBlue)

        return HStack(alignment: .top, spacing: 0) {
            // Time label (matches habit row layout)
            Text(event.timeString)
                .font(Typography.caption2)
                .foregroundStyle(Color.primary.opacity(0.35))
                .frame(width: 56, alignment: .trailing)
                .padding(.trailing, 12)
                .padding(.top, 10)

            // Ghost block
            HStack(spacing: 8) {
                Circle()
                    .fill(eventColor)
                    .frame(width: 6, height: 6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(Typography.caption)
                        .foregroundStyle(Color.primary.opacity(0.6))
                        .lineLimit(1)

                    Text("\(event.timeString) – \(event.endTimeString)")
                        .font(Typography.caption2)
                        .foregroundStyle(Color.primary.opacity(0.4))
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous)
                    .fill(AppColors.ghostBase)
            )
            .overlay(
                RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous)
                    .stroke(eventColor.opacity(0.5), lineWidth: GridConstants.strokeDefault)
            )
            .opacity(0.6)
            .allowsHitTesting(false)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .accessibilityLabel("Calendar event: \(event.title)")
    }

    // MARK: - All-Day Events Banner

    @ViewBuilder
    private var allDayEventsBanner: some View {
        let allDay = calendarEvents.filter(\.isAllDay)
        if !allDay.isEmpty {
            HStack(spacing: 6) {
                ForEach(allDay.prefix(3)) { event in
                    Circle()
                        .fill(Color(red: event.colorRed, green: event.colorGreen, blue: event.colorBlue))
                        .frame(width: 6, height: 6)
                }
                Text("\(allDay.count) all-day event\(allDay.count == 1 ? "" : "s")")
                    .font(Typography.caption2)
                    .foregroundStyle(Color.primary.opacity(0.3))
            }
            .padding(.horizontal, GridConstants.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .accessibilityLabel("\(allDay.count) all-day events")
        }
    }

    // MARK: - Interleaved Timeline Items

    /// Builds a merged list of habits and calendar events sorted by time
    private var interleavedCalendarEvents: [CalendarAnchor] {
        calendarEvents.filter { !$0.isAllDay }
    }

    // MARK: - Scheduled Section (flat list with time labels)

    private var scheduledSection: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            // All-day events ambient line
            allDayEventsBanner

            if !scheduledHabits.isEmpty {
                // Momentum progress for escalation (Hull's Goal Gradient)
                let completionProgress = allHabits.isEmpty ? 0.0 :
                    Double(completedHabitIDs.count) / Double(allHabits.count)

                // Remaining = ALL habits (scheduled + unscheduled) neither completed nor skipped
                let remaining = remainingCount
                if remaining > 0 {
                    // The "N of M done" label is gone: the week strip's ring
                    // encodes it, and so does the list underneath. Three ways of
                    // saying one number on one screen. The celebration hung off
                    // this label's onChange, so it hangs here instead.
                    Color.clear
                        .frame(height: 0)
                        .accessibilityHidden(true)
                        .onChange(of: remainingCount) { old, new in
                            guard new < old else { return }
                            counterFlash = true
                            // Show completion toast (Norman 2004: cross-modal bridge)
                            withAnimation(GridConstants.gentleReveal) { showCompletionToast = true }
                            // All-clear celebration (Kahneman 1993: Peak-End Rule)
                            if new == 0 && !allHabits.isEmpty && !hasPlayedAllClearToday {
                                hasPlayedAllClearToday = true
                                HapticsEngine.reward()
                                SoundEngine.allClearChime()
                                withAnimation(GridConstants.celebrationBurst) { showAllClearConfetti = true }
                            }
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(400))
                                withAnimation(GridConstants.motionSnappy) { counterFlash = false }
                                try? await Task.sleep(for: .milliseconds(1100))
                                withAnimation(GridConstants.crossFade) { showCompletionToast = false }
                            }
                        }

                    // Progress bar removed (user feedback: redundant with week strip)
                } else {
                    // All clear — minimal (emotion via confetti + haptic, not words)
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(Typography.headerSmall)
                            .foregroundStyle(AppColors.healthGreen)
                        Text("All clear!")
                            .font(Typography.brandCardTitle)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .overlay {
                        if showAllClearConfetti {
                            AllClearCelebration(
                                isActive: $showAllClearConfetti,
                                completedCategories: Array(Set(
                                    allHabits.filter { completedHabitIDs.contains($0.id) }.map(\.category)
                                ))
                            )
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                // Past day compassion (Dodson 2005: RSD protection, Lazarus 1991: reframing)
                if !isViewingToday && isViewingPast && !allHabits.isEmpty {
                    let pct = Double(completedHabitIDs.count) / Double(max(allHabits.count, 1))
                    HStack(spacing: 6) {
                        Image(systemName: pct > 0.8 ? "hand.thumbsup.fill" : "heart.fill")
                            .font(Typography.caption2)
                            .foregroundStyle(pct > 0.8 ? AppColors.healthGreen : Color.primary.opacity(0.4))
                        Text(pct > 0.8 ? "Strong day!" : pct > 0.3 ? "You showed up." : "Rest day. That's healthy.")
                            .font(Typography.caption)
                            .foregroundStyle(Color.primary.opacity(0.5))
                    }
                    .padding(.horizontal, GridConstants.horizontalPadding)
                    .padding(.vertical, 8)
                }

                // Calendar ghost events before first habit
                let timedEvents = interleavedCalendarEvents
                let firstHabitHour = scheduledHabits.first.flatMap { TimelineViewModel.effectiveHour(for: $0) } ?? 24
                ForEach(timedEvents.filter { event in
                    let cal = Calendar.current
                    let h = Double(cal.component(.hour, from: event.startDate)) + Double(cal.component(.minute, from: event.startDate)) / 60.0
                    return h < firstHabitHour
                }) { event in
                    calendarGhostBlock(event: event)
                }

                // Habit rows with time labels
                // Pre-build index dictionary (O(n) once, instead of O(n²) inside ForEach)
                let indexByID = Dictionary(uniqueKeysWithValues: scheduledHabits.enumerated().map { ($1.id, $0) })
                // Verified indices for staggered cascade (60ms per row — Material Design stagger research)
                let verifiedScheduledIndices: [UUID: Int] = {
                    var dict: [UUID: Int] = [:]
                    var idx = 0
                    for h in scheduledHabits where verifiedHabitIDs.contains(h.id)
                        && !completedHabitIDs.contains(h.id) {
                        dict[h.id] = idx; idx += 1
                    }
                    return dict
                }()
                ForEach(scheduledHabits, id: \.id) { habit in
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
                    let isNextUp = habit.id == cachedNextUpID

                    HStack(alignment: .top, spacing: 0) {
                        // Time label + "NEXT" badge
                        VStack(spacing: 2) {
                            // "NEXT" badge on the first incomplete habit
                            if isNextUp && isViewingToday {
                                VStack(spacing: 2) {
                                    Text("NEXT")
                                        .font(Typography.caption2)
                                        .fontWeight(.bold)
                                        .tracking(0.5)
                                        .foregroundStyle(AppColors.warmRed)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(AppColors.warmRed.opacity(0.15), in: Capsule())
                                        .accessibilityLabel("Next up")

                                    // Countdown (Posner 1980: attentional cueing)
                                    if let effectiveHour = TimelineViewModel.effectiveHour(for: habit) {
                                        let minutesUntil = Int((effectiveHour - cachedNowFraction) * 60)
                                        if minutesUntil > 0 && minutesUntil < 120 {
                                            Text("in \(minutesUntil)m")
                                                .font(Typography.caption2)
                                                .foregroundStyle(AppColors.warmRed.opacity(0.6))
                                        }
                                    }
                                }
                            }

                            if let time = habit.scheduledTime {
                                Text(BlockTimeFormatter.format12Hour(time))
                                    .font(isNow || isNextUp ? Typography.caption : Typography.caption2)
                                    .fontWeight(isNow || isNextUp ? .bold : .regular)
                                    .foregroundStyle(isNow ? AppColors.warmRed : Color.primary.opacity(isNextUp ? 0.85 : 0.7))
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
                            isAlreadySkipped: isSkipped,
                            photoFileName: habit.logs.first { $0.dateString == TimelineViewModel.dateString(from: selectedDate) }?.imageFileName,
                            completionProgress: completionProgress,
                            currentStreak: cachedStreaks[habit.id] ?? 0,
                            healthKitProgress: healthKitProgress[habit.id] ?? 0,
                            isHealthKitVerified: verifiedHabitIDs.contains(habit.id),
                            verificationDelay: Double(verifiedScheduledIndices[habit.id] ?? 0) * 0.06,
                            isFirstEverVerification: !hasSeenHealthKitVerification && verifiedHabitIDs.contains(habit.id)
                        )
                        .opacity(isViewingPast && !isCompleted && !isSkipped ? 0.5 : 1.0)
                    }
                    // Cross-tab navigation: Edit in Plan (Pirolli & Card 1999 — information scent)
                    .contextMenu {
                        Button {
                            HapticsEngine.lightTap()
                            detailHabit = habit
                        } label: {
                            Label("View Details", systemImage: "info.circle")
                        }
                        Button {
                            HapticsEngine.lightTap()
                            switchTab?(.tower)
                        } label: {
                            Label("View in Tower", systemImage: "square.stack.3d.up")
                        }
                        Button {
                            HapticsEngine.lightTap()
                            switchTab?(.insights)
                        } label: {
                            Label("View Streak", systemImage: "flame")
                        }
                        if let onEdit = onEditInPlan {
                            Button {
                                HapticsEngine.lightTap()
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
                        let myIndex = indexByID[habit.id] ?? 0
                        return myIndex >= hover ? CGFloat(44) : CGFloat(0)
                    }())
                    .animation(reduceMotion ? .none : GridConstants.motionSmooth, value: hoverInsertionIndex)
                    // Staggered row entrance (Shapiro 2015 — anticipatory design)
                    .opacity(rowsRevealed ? 1 : 0)
                    .offset(y: rowsRevealed ? 0 : GridConstants.entranceOffset)
                    .animation(
                        reduceMotion ? .none :
                        GridConstants.gentleReveal.delay(min(Double(indexByID[habit.id] ?? 0) * GridConstants.staggerInterval, GridConstants.staggerMax)),
                        value: rowsRevealed
                    )
                    // Next-up ambient glow (Posner 1980 — attentional cueing)
                    .overlay {
                        if isNextUp && isViewingToday && !reduceMotion {
                            TimelineView(.animation(minimumInterval: 0.1, paused: false)) { timeline in
                                let t = timeline.date.timeIntervalSinceReferenceDate
                                let breath = sin(t / GridConstants.ambientGlowCycle * 2 * .pi)
                                let glowOpacity = 0.10 + breath * GridConstants.ambientGlowIntensity

                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                    .stroke(habit.category.style.baseColor.opacity(glowOpacity), lineWidth: GridConstants.strokeMedium)
                                    .padding(.horizontal, 16)
                                    .allowsHitTesting(false)
                            }
                        }
                    }

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
                            RoundedRectangle(cornerRadius: GridConstants.cornerRadiusSmall)
                                .stroke(AppColors.healthGreen.opacity(0.4), style: StrokeStyle(lineWidth: GridConstants.strokeMedium, dash: [6, 4]))
                                .frame(height: 4)
                        }
                        .padding(.horizontal, 16)
                        .transition(.opacity)
                    }

                    // Onboarding: hold-to-complete hint on first incomplete habit
                    if isNextUp && isViewingToday && onboarding?.activeHint == .hold {
                        OnboardingHintView(text: "Hold to finish →")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 4)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }

                    // Calendar ghost events between this habit and the next
                    let myIdx = indexByID[habit.id] ?? 0
                    let myEndHour: Double = {
                        let h = effectiveHours[habit.id] ?? 0
                        return h + habit.blockSize.durationMinutes / 60.0
                    }()
                    let nextHabitHour: Double = {
                        if myIdx + 1 < scheduledHabits.count {
                            return effectiveHours[scheduledHabits[myIdx + 1].id] ?? 24
                        }
                        return 24
                    }()
                    ForEach(timedEvents.filter { event in
                        let cal = Calendar.current
                        let h = Double(cal.component(.hour, from: event.startDate)) + Double(cal.component(.minute, from: event.startDate)) / 60.0
                        return h >= myEndHour && h < nextHabitHour
                    }) { event in
                        calendarGhostBlock(event: event)
                    }
                }
            } else if unscheduledHabits.isEmpty {
                // No habits at all — handled by fullEmptyState
            } else {
                // All habits are unscheduled
                VStack(spacing: 12) {
                    Text("Nothing scheduled yet")
                        .font(Typography.bodyMedium)
                        .foregroundStyle(Color.primary.opacity(0.6))

                    Text("Tap any habit above to add it here")
                        .font(Typography.caption)
                        .foregroundStyle(Color.primary.opacity(0.6))

                    Image(systemName: "arrow.up")
                        .font(Typography.bodySmall)
                        .foregroundStyle(Color.primary.opacity(0.6))
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
        let duration = habit.blockSize.durationMinutes / 60.0
        return cachedNowFraction >= hour && cachedNowFraction < hour + duration
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
        // Include calendar events as busy ranges
        for event in calendarEvents where !event.isAllDay {
            if let range = event.busyRange {
                busyRanges.append(range)
            }
        }
        busyRanges.sort { $0.start < $1.start }

        let nowMinutes = cachedCurrentHour * 60 + cachedCurrentMinute
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
        let h = min(22, cachedCurrentHour + 1)
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
        // Include calendar events as busy ranges
        for event in calendarEvents where !event.isAllDay {
            if let range = event.busyRange {
                busyRanges.append(range)
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
        let nowMinutes = cachedCurrentHour * 60 + cachedCurrentMinute
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
            let h = min(22, cachedCurrentHour + 1)
            suggestedTime = String(format: "%02d:00", h)
            habitToSchedule = habit
            showScheduleSuggestion = true
        }
    }

    // MARK: - Empty State

    private var fullEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(Typography.appTitle)
                .foregroundStyle(Color.primary.opacity(0.2))

            Text("Ready to build?")
                .font(Typography.headerMedium)
                .foregroundStyle(Color.primary)

            Text("Add your first habit to start")
                .font(Typography.bodyMedium)
                .foregroundStyle(Color.primary.opacity(0.6))

            Button {
                onAddHabit(nil)
            } label: {
                Text("Add Habit")
                    .font(Typography.headerSmall)
                    .foregroundStyle(.white)
                    .padding(.horizontal, GridConstants.horizontalPadding)
                    .padding(.vertical, 10)
                    .background(AppColors.accentWarm, in: Capsule())
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Week Summary View

    // Week view removed — weekly analytics belong in Insights tab (Nielsen 1994 Heuristic #8)

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

    // Debug tools moved to Settings
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
