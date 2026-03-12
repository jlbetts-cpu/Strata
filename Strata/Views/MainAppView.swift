import SwiftUI
import SwiftData
import Combine

struct MainAppView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var habits: [Habit]
    @Query private var logs: [HabitLog]

    init() {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let weekStartString = TimelineViewModel.dateString(from: startOfWeek)
        _logs = Query(filter: #Predicate<HabitLog> { log in
            log.dateString >= weekStartString
        })
    }

    @State private var selectedTab: StrataTab = .tower
    @State private var towerVM = TowerViewModel()
    @State private var timelineVM = TimelineViewModel()
    @State private var habitManagerVM = HabitManagerViewModel()
    @State private var hasLoadedDemo = false
    @State private var headerExpanded: Bool = false
    @State private var hapticLightTrigger = 0
    @State private var hapticMediumTrigger = 0
    @State private var hapticHeavyTrigger = 0

    // Three-phase drop animation
    enum DropPhase { case falling, impact }
    @State private var dropPhases: [UUID: DropPhase] = [:]

    // Kinetic ripple: compression wave on impact
    @State private var ripplingBlockIDs: Set<UUID> = []
    @State private var rippleIntensity: [UUID: CGFloat] = [:]
    @State private var landedMassTier: Int = 1

    // Drop queue: habits completed in timeline, awaiting tower release
    @State private var pendingDrops: [Habit] = []

    // Timeline drag-to-reschedule
    @State private var draggingHabitID: UUID? = nil
    @State private var dragYOffset: CGFloat = 0

    // Daily Story carousel
    @State private var activeCarouselBlockID: UUID? = nil

    // Cached week completed dates
    @State private var weekCompletedDates: Set<String> = []

    // Tower scroll
    @State private var isScrolledPastTop = false
    @State private var scrollToDropID: UUID? = nil
    @State private var scrollToTopTrigger = 0
    @State private var towerScrollOffset: CGFloat = 0
    @State private var screenHeight: CGFloat = 0
    @State private var currentColW: CGFloat = 0

    // Timeline constants
    private let timelineStartHour = 0
    private let timelineEndHour = 23

    // Pinch-to-zoom timeline scale
    @State private var pixelsPerMinute: CGFloat = 2.0
    @GestureState private var magnifyBy: CGFloat = 1.0

    /// Effective scale factor (live during gesture, baked after)
    private var effectiveScale: CGFloat { pixelsPerMinute * magnifyBy }
    /// Height of one hour in points at current zoom
    private var hourHeight: CGFloat { 60.0 * effectiveScale }

    private let hPad: CGFloat = 20
    private let spacing: CGFloat = 4
    private let columns = 4
    private let cornerRadius: CGFloat = 8
    private let collapsedHeaderHeight: CGFloat = 74

    var body: some View {
        GeometryReader { geo in
            mainContent(geo: geo)
        }
        .background(Color(UIColor.systemBackground))
        .fullScreenCover(isPresented: carouselPresented) {
            DailyStoryCarousel(
                blocks: todaysPhotoBlocks,
                activeBlockID: $activeCarouselBlockID,
                modelContext: modelContext
            )
        }
        .sensoryFeedback(.impact(weight: .light), trigger: hapticLightTrigger)
        .sensoryFeedback(.impact(weight: .medium), trigger: hapticMediumTrigger)
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1.0), trigger: hapticHeavyTrigger)
        .onAppear(perform: setup)
        .onChange(of: habits.count) { refreshData() }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            refreshData()
        }
    }

    // MARK: - Main Content

    private func mainContent(geo: GeometryProxy) -> some View {
        let colW = floor(
            (geo.size.width - hPad * 2 - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        )

        let expandedWidth = geo.size.width - hPad * 2

        return ZStack(alignment: .topLeading) {
            towerContent(colW: colW, topInset: collapsedHeaderHeight, viewportHeight: geo.size.height)
                .ignoresSafeArea(.container, edges: .top)

            // Morphing date pill — top-left, stretches downward
            MorphingDatePill(
                dateLabel: visibleDateLabel,
                isExpanded: $headerExpanded,
                screenHeight: geo.size.height,
                expandedWidth: expandedWidth,
                weekData: weekData,
                timelineContent: { timelineScrollView }
            )
            .padding(.top, 8)
            .padding(.leading, hPad)

            // Plus button — top-right, independent
            FloatingPlusButton(onTap: generateTestBlock)
                .frame(maxWidth: .infinity, alignment: .topTrailing)
                .padding(.top, 8)
                .padding(.trailing, hPad)
        }
        .onChange(of: headerExpanded) { _, expanded in
            if expanded {
                scrollToTopTrigger += 1
            }
            if !expanded && !pendingDrops.isEmpty {
                Task { await cascadeDropPendingBlocks() }
            }
        }
        .onAppear {
            screenHeight = geo.size.height
            currentColW = colW
        }
        .onChange(of: geo.size.height) { _, h in screenHeight = h }
    }

    // MARK: - Dynamic Date Label

    private var visibleDateLabel: String {
        if headerExpanded {
            return Date().formatted(.dateTime.month(.wide).day())
        }

        guard !towerVM.placedBlocks.isEmpty else {
            return Date().formatted(.dateTime.month(.wide).day())
        }

        let rowCount = towerVM.totalRows
        guard rowCount > 0, currentColW > 0, screenHeight > 0 else {
            return Date().formatted(.dateTime.month(.wide).day())
        }

        let cellStride = currentColW + spacing
        let gridH = CGFloat(rowCount) * currentColW + CGFloat(rowCount - 1) * spacing

        // towerScrollOffset is the global minY of the content
        // Visible Y range in grid coords (flipped: row 0 at bottom)
        let contentTopY = towerScrollOffset
        let viewTop = collapsedHeaderHeight + 20
        let viewBottom = screenHeight

        let visibleTopInContent = viewTop - contentTopY
        let visibleBottomInContent = viewBottom - contentTopY

        // Convert visual Y to grid row (flipped)
        let topGridRow = max(0, Int((gridH - visibleBottomInContent) / cellStride))
        let bottomGridRow = min(rowCount - 1, Int((gridH - visibleTopInContent) / cellStride))

        let visibleBlocks = towerVM.placedBlocks.filter { block in
            block.row >= topGridRow && block.row <= bottomGridRow
        }

        let dateStrings = Set(visibleBlocks.map { $0.log.dateString })

        guard !dateStrings.isEmpty else {
            return Date().formatted(.dateTime.month(.wide).day())
        }

        let sorted = dateStrings.sorted()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        if sorted.count == 1, let date = formatter.date(from: sorted[0]) {
            return date.formatted(.dateTime.month(.wide).day())
        }

        if let first = formatter.date(from: sorted.first!),
           let last = formatter.date(from: sorted.last!) {
            let cal = Calendar.current
            let firstMonth = cal.component(.month, from: first)
            let lastMonth = cal.component(.month, from: last)

            if firstMonth == lastMonth {
                let monthName = first.formatted(.dateTime.month(.abbreviated))
                let d1 = cal.component(.day, from: first)
                let d2 = cal.component(.day, from: last)
                return "\(monthName) \(d1) – \(d2)"
            } else {
                let s1 = first.formatted(.dateTime.month(.abbreviated).day())
                let s2 = last.formatted(.dateTime.month(.abbreviated).day())
                return "\(s1) – \(s2)"
            }
        }

        return Date().formatted(.dateTime.month(.wide).day())
    }

    // MARK: - Week Progress Data

    private var weekData: [DayProgressData] {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let weekDates = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
        let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

        return weekDates.enumerated().map { index, date in
            let dayNum = calendar.component(.day, from: date)
            let isToday = calendar.isDateInToday(date)
            let isFuture = date > Date() && !isToday
            let dateStr = TimelineViewModel.dateString(from: date)
            let weekday = calendar.component(.weekday, from: date)
            let dayCode = DayCode.from(weekday: weekday)

            let scheduledForDay = habits.filter { habit in
                if habit.isTodo {
                    return habit.scheduledDate == dateStr
                }
                return habit.frequency.contains(dayCode)
            }
            let total = scheduledForDay.count
            let completed = logs.filter { $0.dateString == dateStr && $0.completed }.count
            let rate = total > 0 ? Double(completed) / Double(total) : 0

            return DayProgressData(
                dayLabel: dayLabels[index],
                dayNumber: dayNum,
                completionRate: rate,
                isToday: isToday,
                isFuture: isFuture
            )
        }
    }

    // MARK: - Setup

    private func setup() {
        timelineVM.modelContext = modelContext
        habitManagerVM.modelContext = modelContext
        refreshData()
    }

    private func refreshData() {
        timelineVM.loadToday(habits: habits, logs: logs)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            towerVM.buildTower(from: logs)
        }
        weekCompletedDates = Set(logs.filter { $0.completed }.map { $0.dateString })
    }

    private func triggerDropAnimation() {
        let newIDs = towerVM.newlyDroppedIDs
        guard !newIDs.isEmpty else { return }

        // Determine mass tier from the landed block
        let mass: Int
        if let landedID = newIDs.first,
           let block = towerVM.placedBlocks.first(where: { $0.id == landedID }) {
            mass = block.habit.blockSize.massTier
        } else {
            mass = 1
        }
        landedMassTier = mass

        // Mass-variable fall duration
        let fallDuration: Double = switch mass {
        case 1: 0.35
        case 2: 0.45
        default: 0.6
        }

        // Mass-variable settle spring
        let settleResponse: Double = switch mass {
        case 1: 0.3
        case 2: 0.45
        default: 0.6
        }
        let settleDamping: Double = switch mass {
        case 1: 0.6
        case 2: 0.7
        default: 0.8
        }

        // Phase 1: Set blocks to falling (offset -600)
        for id in newIDs {
            dropPhases[id] = .falling
        }

        // Phase 1→2: Animate the fall — heavier = slower
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            withAnimation(.easeIn(duration: fallDuration)) {
                for id in newIDs {
                    dropPhases[id] = .impact
                }
            }
        }

        // Phase 2: Impact — mass-variable haptic + ripple
        let impactTime = 0.02 + fallDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + impactTime) {
            // Fire mass-appropriate haptic
            switch mass {
            case 1: hapticLightTrigger += 1
            case 2: hapticMediumTrigger += 1
            default: hapticHeavyTrigger += 1
            }

            if let landedID = newIDs.first {
                triggerRipple(from: landedID, massTier: mass)
            }
        }

        // Phase 3: Settle — heavier blocks settle slower with more momentum
        DispatchQueue.main.asyncAfter(deadline: .now() + impactTime + 0.08) {
            withAnimation(.spring(response: settleResponse, dampingFraction: settleDamping)) {
                for id in newIDs {
                    dropPhases.removeValue(forKey: id)
                }
            }
        }
    }

    // MARK: - Kinetic Ripple

    private func triggerRipple(from landedID: UUID, massTier: Int) {
        guard let landedBlock = towerVM.placedBlocks.first(where: { $0.id == landedID }) else { return }
        let landedRow = landedBlock.row

        let massMultiplier = CGFloat(massTier)

        // Only ripple the nearest 2 tiers to limit timer/state explosion
        let blocksBelow = towerVM.placedBlocks.filter { block in
            block.id != landedID && block.row < landedRow && (landedRow - block.row) <= 2
        }

        guard !blocksBelow.isEmpty else { return }

        var tiers: [Int: [PlacedBlock]] = [:]
        for block in blocksBelow {
            let distance = landedRow - block.row
            tiers[distance, default: []].append(block)
        }

        for (distance, tierBlocks) in tiers {
            let delay = Double(distance) * 0.05
            let intensity = massMultiplier / max(1, CGFloat(distance) * 0.5)
            let tierIDs = tierBlocks.map(\.id)

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // Batch: single state mutation for the whole tier
                for id in tierIDs {
                    self.rippleIntensity[id] = intensity
                }
                withAnimation(.spring(response: 0.10, dampingFraction: 0.3)) {
                    self.ripplingBlockIDs.formUnion(tierIDs)
                }

                // Rebound
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                        for id in tierIDs {
                            self.ripplingBlockIDs.remove(id)
                            self.rippleIntensity.removeValue(forKey: id)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Time-Scaled Timeline

    /// The current hour (clamped to timeline range) used as scroll anchor ID.
    private var currentHourAnchor: Int {
        let hour = Calendar.current.component(.hour, from: Date())
        return max(timelineStartHour, min(timelineEndHour, hour))
    }

    private let gutterWidth: CGFloat = 55

    private var timelineScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                let totalMinutes: CGFloat = CGFloat(timelineEndHour - timelineStartHour) * 60
                let totalHeight = totalMinutes * effectiveScale

                ZStack(alignment: .topLeading) {
                    // Background hour grid
                    ForEach(timelineStartHour...timelineEndHour, id: \.self) { hour in
                        let y = CGFloat(hour - timelineStartHour) * 60.0 * effectiveScale

                        HStack(spacing: 0) {
                            Text(formatHour(hour))
                                .font(.caption2.bold())
                                .foregroundStyle(Color.primary.opacity(0.6))
                                .frame(width: gutterWidth, alignment: .trailing)
                                .padding(.trailing, 12)

                            Rectangle()
                                .fill(Color.primary.opacity(0.08))
                                .frame(height: 0.5)
                        }
                        .id(hour)
                        .offset(y: y - 6)
                    }

                    // Task blocks — duration-sized, time-positioned
                    ForEach(incompleteForTimeline, id: \.id) { habit in
                        let minutesFromStart = minutesFromStartOfDay(for: habit)
                        let y = minutesFromStart * effectiveScale
                        let durationMins = habit.blockSize.durationMinutes
                        let h = max(durationMins * effectiveScale, 28) // min tap target
                        let isDragging = draggingHabitID == habit.id
                        let extraY = isDragging ? dragYOffset : 0

                        HStack(spacing: 0) {
                            Color.clear
                                .frame(width: gutterWidth + 12)

                            TimelineHabitRow(
                                habit: habit,
                                rowHeight: h,
                                cornerRadius: cornerRadius,
                                onComplete: { completedHabit in
                                    pendingDrops.append(completedHabit)
                                    processTimelineDrop()
                                },
                                onSkip: { skippedHabit in
                                    skipHabit(skippedHabit)
                                }
                            )
                        }
                        .offset(y: y + extraY)
                        .scaleEffect(isDragging ? 1.04 : 1.0)
                        .shadow(
                            color: isDragging ? Color.black.opacity(0.18) : .clear,
                            radius: isDragging ? 12 : 0, y: isDragging ? 4 : 0
                        )
                        .zIndex(isDragging ? 100 : 0)
                        .gesture(
                            LongPressGesture(minimumDuration: 0.2)
                                .sequenced(before: DragGesture(minimumDistance: 0))
                                .onChanged { value in
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

                    // Current time indicator
                    nowIndicator
                        .id("NowLine")
                }
                .frame(height: totalHeight)
                .padding(.trailing, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .gesture(
                MagnificationGesture()
                    .updating($magnifyBy) { value, state, _ in
                        state = value
                    }
                    .onEnded { value in
                        let newScale = pixelsPerMinute * value
                        pixelsPerMinute = min(max(newScale, 1.0), 5.0)
                    }
            )
            .onAppear {
                proxy.scrollTo("NowLine", anchor: .center)
            }
            .onChange(of: headerExpanded) { _, expanded in
                if expanded {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("NowLine", anchor: .center)
                    }
                }
            }
        }
    }

    private var incompleteForTimeline: [Habit] {
        let completedIDs = Set(timelineVM.completedToday.compactMap { $0.habit?.id })
        let pendingIDs = Set(pendingDrops.map(\.id))
        let skippedIDs = timelineVM.skippedHabitIDs
        return timelineVM.todaysHabits.filter { habit in
            !completedIDs.contains(habit.id) && !pendingIDs.contains(habit.id) && !skippedIDs.contains(habit.id)
        }
    }

    private var nowIndicator: some View {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let totalMinutes = CGFloat((hour - timelineStartHour) * 60 + minute)
        let y = totalMinutes * effectiveScale

        return HStack(spacing: 0) {
            Color.clear
                .frame(width: gutterWidth + 8)

            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)

            Rectangle()
                .fill(Color.red)
                .frame(height: 1.5)
        }
        .offset(y: y - 4)
    }

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

    private func timelineY(for habit: Habit) -> CGFloat {
        minutesFromStartOfDay(for: habit) * effectiveScale
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

    // MARK: - Cascade Release (Async Sequential)

    @MainActor
    private func cascadeDropPendingBlocks() async {
        let habits = pendingDrops
        pendingDrops = []

        // Complete all habits first in one batch
        for habit in habits {
            timelineVM.completeHabit(habit)
        }

        // Single rebuild + one drop animation for the whole batch
        refreshData()
        triggerDropAnimation()
    }

    // MARK: - Scroll Offset Tracking

    private struct ScrollOffsetPreferenceKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }

    // MARK: - Tower Content

    /// Flips a grid-space frame so row 0 is at the visual bottom.
    private func flippedY(for f: CGRect, gridH: CGFloat) -> CGFloat {
        gridH - f.minY - f.height
    }

    private func towerContent(colW: CGFloat, topInset: CGFloat, viewportHeight: CGFloat) -> some View {
        let gridW = CGFloat(columns) * colW + CGFloat(columns - 1) * spacing
        let rowCount = towerVM.totalRows
        let gridH = rowCount > 0
            ? CGFloat(rowCount) * colW + CGFloat(rowCount - 1) * spacing
            : 0

        return ZStack(alignment: .trailing) {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        // Top anchor for FAB scroll
                        Color.clear.frame(height: 1)
                            .id("TowerTop")

                        Color.clear
                            .frame(width: gridW, height: max(gridH, 1))

                        ForEach(towerVM.placedBlocks) { block in
                            let f = GridConstants.blockFrame(
                                column: block.column, row: block.row,
                                columnSpan: block.columnSpan, rowSpan: block.rowSpan,
                                cellSize: colW
                            )
                            let phase = dropPhases[block.id]
                            let isAnimating = phase != nil
                            let isNew = isAnimating || towerVM.newlyDroppedIDs.contains(block.id)

                            animatedBlock(block: block, frame: f, phase: phase, isNew: isNew)
                                .id(block.id)
                                .offset(x: f.minX, y: flippedY(for: f, gridH: gridH))
                                .zIndex(isAnimating ? 100 : Double(block.row + 1))
                        }

                    }
                    .padding(.horizontal, hPad)
                    .padding(.bottom, 48)
                    .padding(.top, collapsedHeaderHeight + 20)
                    .background(
                        GeometryReader { contentGeo in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: contentGeo.frame(in: .global).minY
                            )
                        }
                    )
                }
                .defaultScrollAnchor(.bottom)
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                    towerScrollOffset = offset
                    isScrolledPastTop = offset < -50
                }
                .onChange(of: scrollToDropID) {
                    if let id = scrollToDropID {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                        scrollToDropID = nil
                    }
                }
                .onChange(of: scrollToTopTrigger) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        proxy.scrollTo("TowerTop", anchor: .top)
                    }
                }
            }

            // Tower scrubber — scroll indicator + fast scrub
            TowerScrubberView(
                towerContentHeight: gridH,
                scrollOffset: towerScrollOffset,
                viewportHeight: viewportHeight,
                heightMeters: towerVM.altimeterHeight,
                topInset: 44,
                onScrub: { fraction in
                    let targetRow = Int(fraction * CGFloat(max(1, towerVM.totalRows)))
                    if let block = towerVM.placedBlocks.first(where: { $0.row >= targetRow }) {
                        scrollToDropID = block.id
                    }
                }
            )
            .opacity(towerVM.totalRows > 0 ? 1 : 0)
            .scaleEffect(towerVM.totalRows > 0 ? 1 : 0.8)
            .animation(.easeOut(duration: 0.3), value: towerVM.totalRows > 0)
            .padding(.trailing, 12)
        }
        .padding(.top, topInset)
    }

    // MARK: - Ghost Slot

    private func ghostSlot(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .frame(width: width, height: height)
    }

    // MARK: - Animated Block Wrapper

    private func animatedBlock(
        block: PlacedBlock,
        frame f: CGRect,
        phase: DropPhase?,
        isNew: Bool
    ) -> some View {
        let dropOffset: CGFloat = switch phase {
        case .falling: -600
        case .impact: 4
        case .none: 0
        }

        let impactMass = CGFloat(block.habit.blockSize.massTier)
        let impactScaleX: CGFloat = phase == .impact ? 1.0 + 0.01 * impactMass : 1.0
        let impactScaleY: CGFloat = phase == .impact ? 1.0 - 0.015 * impactMass : 1.0

        let isRippling = ripplingBlockIDs.contains(block.id)
        let ri = rippleIntensity[block.id] ?? 1.0
        let rippleScaleX: CGFloat = isRippling ? 1.0 + 0.02 * ri : 1.0
        let rippleScaleY: CGFloat = isRippling ? 1.0 - 0.06 * ri : 1.0
        let rippleOffsetY: CGFloat = isRippling ? 2 * ri : 0

        return ZStack {
            if isNew {
                ghostSlot(width: f.width, height: f.height)
            }

            completedBlock(block: block, frame: f)
                .scaleEffect(x: impactScaleX, y: impactScaleY, anchor: .bottom)
                .offset(y: dropOffset)
        }
        .scaleEffect(x: rippleScaleX, y: rippleScaleY, anchor: .bottom)
        .offset(y: rippleOffsetY)
    }

    // MARK: - Live Completed Block

    private func completedBlock(block: PlacedBlock, frame: CGRect) -> some View {
        FlippableBlockView(
            block: block,
            width: frame.width,
            height: frame.height,
            cornerRadius: cornerRadius,
            exposedSegments: towerVM.exposedSegments(for: block),
            modelContext: modelContext,
            onExpandPhoto: { _ in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    activeCarouselBlockID = block.id
                }
            }
        )
    }

    // MARK: - Actions

    private func handleComplete(_ habit: Habit) {
        timelineVM.completeHabit(habit)
        refreshData()
        triggerDropAnimation()
    }

    /// Process a single pending drop from the timeline immediately.
    private func processTimelineDrop() {
        guard let habit = pendingDrops.last else { return }
        // Small delay to let the TimelineHabitRow animation finish
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            pendingDrops.removeAll { $0.id == habit.id }
            timelineVM.completeHabit(habit)
            refreshData()
            triggerDropAnimation()
        }
    }

    /// Skip a habit — remove from today without completing.
    private func skipHabit(_ habit: Habit) {
        timelineVM.skipHabit(habit)
        refreshData()
    }

    private func generateTestBlock() {
        let titles = ["Meditate", "Read", "Gym", "Sketch", "Journal", "Walk", "Code", "Stretch", "Cook", "Run"]
        let categories = HabitCategory.allCases
        let sizes: [BlockSize] = [.small, .small, .small, .medium, .medium, .hard]
        let times = ["07:00", "07:30", "08:00", "09:00", "09:30", "10:00",
                     "11:00", "12:00", "13:00", "14:00", "15:00", "16:00",
                     "17:00", "18:00", "19:00", "20:00"]
        let dayParts: [TimeOfDay] = [.morning, .afternoon, .evening]

        let habit = Habit(
            title: titles.randomElement()!,
            category: categories.randomElement()!,
            blockSize: sizes.randomElement()!,
            scheduledTime: times.randomElement(),
            timeOfDay: dayParts.randomElement()
        )
        modelContext.insert(habit)
        try? modelContext.save()
        refreshData()
    }

    private func resetTower() {
        for log in logs { modelContext.delete(log) }
        for habit in habits { modelContext.delete(habit) }
        try? modelContext.save()
        refreshData()
    }

    // MARK: - Daily Story Carousel

    private var carouselPresented: Binding<Bool> {
        Binding(
            get: { activeCarouselBlockID != nil },
            set: { if !$0 { activeCarouselBlockID = nil } }
        )
    }

    private var todaysPhotoBlocks: [PlacedBlock] {
        let dateStr = timelineVM.currentDateString
        return towerVM.placedBlocks.filter { block in
            block.log.dateString == dateStr && block.log.imageData != nil
        }
    }
}

#Preview {
    MainAppView()
        .modelContainer(for: [Habit.self, HabitLog.self, MoodLog.self], inMemory: true)
        .environment(EventKitService())
        .environment(HealthKitService())
}
