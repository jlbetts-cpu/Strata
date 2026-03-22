import SwiftUI
import SwiftData

struct ScheduleTimelineView: View {
    let weekData: [DayProgressData]
    @Binding var selectedDate: Date
    let incompleteHabits: [Habit]
    let isViewingToday: Bool
    let isViewingPast: Bool
    let onComplete: (Habit) -> Void
    let onSkip: (Habit) -> Void
    let onAddHabit: (String?) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Timeline zoom
    @AppStorage("timelinePixelsPerMinute") private var pixelsPerMinute: Double = 2.0
    @GestureState private var magnifyBy: CGFloat = 1.0

    // Drag-to-reschedule
    @State private var draggingHabitID: UUID? = nil
    @State private var dragYOffset: CGFloat = 0

    // Now indicator pulse
    @State private var nowPulse: Bool = false

    // Constants — smart time range (6AM-11PM, extended if habits outside)
    private var timelineStartHour: Int {
        let earliest = incompleteHabits.compactMap { TimelineViewModel.effectiveHour(for: $0) }.min() ?? 6.0
        return min(6, Int(earliest))
    }
    private var timelineEndHour: Int {
        let latest = incompleteHabits.compactMap { TimelineViewModel.effectiveHour(for: $0) }.max() ?? 23.0
        return max(23, Int(latest) + 1)
    }
    private let gutterWidth: CGFloat = GridConstants.timelineGutterWidth
    private let cornerRadius: CGFloat = GridConstants.cornerRadius

    // Time-of-day section boundaries
    private let sections: [(hour: Int, label: String, icon: String)] = [
        (6, "MORNING", "sunrise.fill"),
        (12, "AFTERNOON", "sun.max.fill"),
        (18, "EVENING", "moon.stars.fill"),
    ]

    /// Effective scale factor (live during gesture, baked after)
    private var effectiveScale: CGFloat { pixelsPerMinute * magnifyBy }

    /// Current hour for temporal dimming
    private var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }

    /// Progress for selected date from weekData
    private var selectedDayProgress: DayProgressData? {
        weekData.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    // Zoom snap feedback
    @State private var showZoomPill: Bool = false
    @State private var zoomPillLabel: String = "2x"
    @State private var zoomDismissTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            WeekProgressStrip(weekData: weekData, selectedDate: $selectedDate)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

            // Completion progress bar
            if let dayProgress = selectedDayProgress, dayProgress.completionRate > 0 {
                HStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.06))
                                .frame(height: 3)

                            Capsule()
                                .fill(AppColors.healthGreen)
                                .frame(width: geo.size.width * dayProgress.completionRate, height: 3)
                                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: dayProgress.completionRate)
                        }
                    }
                    .frame(height: 3)

                    Text("\(Int(dayProgress.completionRate * 100))%")
                        .font(Typography.caption2)
                        .foregroundStyle(Color.primary.opacity(0.4))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }

            // Styled divider (warm, subtle)
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 0.5)

            ZStack {
                timelineScrollView

                // Zoom level pill overlay
                if showZoomPill {
                    Text(zoomPillLabel)
                        .font(Typography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.primary.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
        }
        .background { WarmBackground().ignoresSafeArea() }
    }

    // MARK: - Timeline Scroll View

    private var timelineScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                let totalMinutes: CGFloat = CGFloat(timelineEndHour - timelineStartHour) * 60
                let totalHeight = totalMinutes * effectiveScale

                ZStack(alignment: .topLeading) {
                    // Background hour grid with sections
                    hourGrid

                    // Task blocks or empty state
                    if incompleteHabits.isEmpty {
                        emptyState
                            .offset(y: CGFloat(max(timelineStartHour, min(timelineEndHour, currentHour)) - timelineStartHour) * 60.0 * effectiveScale - 40)
                    } else {
                        habitBlocks
                    }

                    // Current time indicator — only when viewing today
                    if isViewingToday {
                        nowIndicator
                            .id("NowLine")
                    }
                }
                .frame(height: totalHeight)
                .padding(.trailing, 24)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
            .gesture(
                MagnificationGesture()
                    .updating($magnifyBy) { value, state, _ in
                        state = value
                    }
                    .onEnded { value in
                        let raw = pixelsPerMinute * value
                        // Snap to nearest level: 1.0, 2.0, 4.0
                        let snapped: Double
                        if raw < 1.5 { snapped = 1.0 }
                        else if raw < 3.0 { snapped = 2.0 }
                        else { snapped = 4.0 }
                        pixelsPerMinute = snapped
                        HapticsEngine.tick()
                        showZoomPill(label: "\(Int(snapped))x")
                    }
            )
            .onAppear {
                if isViewingToday {
                    proxy.scrollTo("NowLine", anchor: .center)
                }
            }
        }
    }

    // MARK: - Hour Grid with Sections

    private var hourGrid: some View {
        ForEach(timelineStartHour...timelineEndHour, id: \.self) { hour in
            let y = CGFloat(hour - timelineStartHour) * 60.0 * effectiveScale
            let isSectionBoundary = sections.contains { $0.hour == hour }
            let isPast = hour < currentHour
            let isCurrent = hour == currentHour

            let labelOpacity: Double = {
                if isCurrent { return 0.8 }
                if isSectionBoundary { return isPast ? 0.3 : 0.6 }
                return isPast ? 0.15 : 0.25
            }()
            let lineOpacity: Double = isPast ? 0.03 : (isSectionBoundary ? 0.08 : 0.05)
            let section = sections.first(where: { $0.hour == hour })

            HStack(spacing: 0) {
                // Gutter: section label stacked above hour
                VStack(alignment: .trailing, spacing: 2) {
                    if let section {
                        HStack(spacing: 4) {
                            Image(systemName: section.icon)
                                .font(.system(size: 8, weight: .medium))
                            Text(section.label)
                                .font(Typography.caption2)
                                .tracking(0.5)
                        }
                        .foregroundStyle(Color.primary.opacity(isPast ? 0.15 : 0.3))
                    }

                    Text(formatHour(hour))
                        .font(isSectionBoundary || isCurrent ? Typography.caption : Typography.caption2)
                        .fontWeight(isCurrent ? .bold : .regular)
                        .foregroundStyle(
                            isCurrent ? AppColors.warmRed : Color.primary.opacity(labelOpacity)
                        )
                }
                .frame(width: gutterWidth, alignment: .trailing)
                .padding(.trailing, 8)

                // Grid line
                Rectangle()
                    .fill(Color.primary.opacity(lineOpacity))
                    .frame(height: isSectionBoundary ? 0.67 : 0.33)
            }
            .id(hour)
            .offset(y: y - 6)
        }
    }

    // MARK: - Habit Blocks

    private var habitBlocks: some View {
        ForEach(Array(incompleteHabits.enumerated()), id: \.element.id) { idx, habit in
            let minutesFromStart = minutesFromStartOfDay(for: habit)
            let y = minutesFromStart * effectiveScale
            let durationMins = habit.blockSize.durationMinutes
            let h = max(durationMins * effectiveScale, 56) // 56pt min (research)
            let isDragging = draggingHabitID == habit.id
            let extraY = isDragging ? dragYOffset : 0

            HStack(spacing: 0) {
                Color.clear
                    .frame(width: gutterWidth + 12)

                if isViewingPast {
                    TimelineHabitRow(
                        habit: habit,
                        rowHeight: h,
                        cornerRadius: cornerRadius,
                        onComplete: { _ in },
                        onSkip: { _ in }
                    )
                    .opacity(0.5)
                } else {
                    TimelineHabitRow(
                        habit: habit,
                        rowHeight: h,
                        cornerRadius: cornerRadius,
                        onComplete: { completedHabit in
                            onComplete(completedHabit)
                        },
                        onSkip: { skippedHabit in
                            onSkip(skippedHabit)
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 16)
            .offset(y: y + extraY)
            .scaleEffect(isDragging ? 1.04 : 1.0)
            .shadow(
                color: isDragging ? Color.black.opacity(GridConstants.adaptiveShadowOpacity(0.18, colorScheme: colorScheme)) : .clear,
                radius: isDragging ? 12 : 0, y: isDragging ? 4 : 0
            )
            .zIndex(isDragging ? 100 : Double(idx))
            .gesture(
                LongPressGesture(minimumDuration: 0.2)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onChanged { value in
                        guard !isViewingPast else { return }
                        switch value {
                        case .second(true, let drag):
                            if draggingHabitID != habit.id {
                                draggingHabitID = habit.id
                                let gen = UIImpactFeedbackGenerator(style: .light)
                                gen.impactOccurred()
                            }
                            dragYOffset = drag?.translation.height ?? 0
                        default:
                            break
                        }
                    }
                    .onEnded { value in
                        guard !isViewingPast else { return }
                        guard draggingHabitID == habit.id else { return }
                        let finalY = minutesFromStartOfDay(for: habit) * effectiveScale + dragYOffset
                        let newTime = timeFromY(finalY)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            habit.scheduledTime = newTime
                            draggingHabitID = nil
                            dragYOffset = 0
                        }
                        try? modelContext.save()
                        let gen = UIImpactFeedbackGenerator(style: .medium)
                        gen.impactOccurred()
                    }
            )
        }
    }

    // MARK: - Now Indicator (redesigned)

    private var nowIndicator: some View {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let totalMinutes = CGFloat((hour - timelineStartHour) * 60 + minute)
        let y = totalMinutes * effectiveScale

        let warmRed = AppColors.warmRed

        return HStack(spacing: 0) {
            // Time label in gutter
            Text(BlockTimeFormatter.format12Hour(now))
                .font(Typography.caption2)
                .fontWeight(.bold)
                .foregroundStyle(warmRed)
                .frame(width: gutterWidth, alignment: .trailing)
                .padding(.trailing, 8)

            // Dot with glow
            Circle()
                .fill(warmRed)
                .frame(width: 8, height: 8)
                .shadow(color: warmRed.opacity(0.3), radius: 6)
                .scaleEffect(nowPulse ? 1.15 : 1.0)

            // Line
            Rectangle()
                .fill(warmRed)
                .frame(height: 1.5)
        }
        .frame(height: 8)
        .offset(y: y - 4)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                nowPulse = true
            }
        }
    }

    // MARK: - Stash Animation

    // MARK: - Timeline Helpers

    private func formatHour(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let period = hour < 12 ? "AM" : "PM"
        return "\(h) \(period)"
    }

    /// Minutes from the start of the timeline for a given habit.
    private func minutesFromStartOfDay(for habit: Habit) -> CGFloat {
        let hour = TimelineViewModel.effectiveHour(for: habit) ?? 10.0
        return CGFloat((hour - Double(timelineStartHour)) * 60.0)
    }

    /// Convert a Y position back to a "HH:mm" string, snapped to 5-min intervals.
    private func timeFromY(_ y: CGFloat) -> String {
        let totalMinutes = Double(y) / Double(effectiveScale) + Double(timelineStartHour) * 60.0
        let clamped = max(0, min(Double(timelineEndHour) * 60.0 - 15, totalMinutes))
        let snapped = (Int(round(clamped)) / 5) * 5
        let h = snapped / 60
        let m = snapped % 60
        return String(format: "%02d:%02d", h, m)
    }

    // MARK: - Empty State

    /// Day name for display (e.g. "Monday")
    private var selectedDayName: String {
        selectedDate.formatted(.dateTime.weekday(.wide))
    }

    private var emptyState: some View {
        let hasCompleted = selectedDayProgress.map { $0.completionRate > 0 } ?? false

        return VStack(spacing: 16) {
            if isViewingPast {
                if hasCompleted {
                    pastAllDoneState
                } else {
                    pastEmptyState
                }
            } else if isViewingToday {
                if hasCompleted {
                    allDoneState
                } else {
                    fullEmptyState
                }
            } else {
                // Future
                futureEmptyState
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var allDoneState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(AppColors.healthGreen.opacity(0.6))

            Text("All done for today!")
                .font(Typography.headerMedium)
                .foregroundStyle(Color.primary)
        }
    }

    private var pastAllDoneState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(AppColors.healthGreen.opacity(0.6))

            Text("All completed on \(selectedDayName)")
                .font(Typography.headerMedium)
                .foregroundStyle(Color.primary)
        }
    }

    private var pastEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color.primary.opacity(0.2))

            Text("No habits scheduled")
                .font(Typography.headerMedium)
                .foregroundStyle(Color.primary)
        }
    }

    private var futureEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color.primary.opacity(0.2))

            Text("No habits scheduled")
                .font(Typography.headerMedium)
                .foregroundStyle(Color.primary)

            Text("Add habits for \(selectedDayName)")
                .font(Typography.bodyMedium)
                .foregroundStyle(Color.primary.opacity(0.4))
        }
    }

    private var fullEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 40, weight: .light))
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

    // MARK: - Zoom Pill

    private func showZoomPill(label: String) {
        zoomPillLabel = label
        withAnimation(.easeOut(duration: 0.15)) {
            showZoomPill = true
        }
        zoomDismissTask?.cancel()
        zoomDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            withAnimation(.easeIn(duration: 0.3)) {
                showZoomPill = false
            }
        }
    }
}
