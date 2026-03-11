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
    enum DrawerPosition: Equatable { case closed, mid, full }
    @State private var drawerPosition: DrawerPosition = .closed
    @State private var dragOffset: CGFloat = 0
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
    @State private var showTopButton = false
    @State private var hideButtonTask: Task<Void, Never>? = nil

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
    private let drawerClosedHeight: CGFloat = 90
    private let weekStripHeight: CGFloat = 86

    var body: some View {
        GeometryReader { geo in
            let colW = floor(
                (geo.size.width - hPad * 2 - spacing * CGFloat(columns - 1)) / CGFloat(columns)
            )

            ZStack(alignment: .top) {
                towerContent(colW: colW, topInset: drawerClosedHeight)
                unifiedDrawer(screenHeight: geo.size.height)
            }
        }
        .background(Color(white: 0.96))
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
        .onChange(of: drawerPosition) { oldValue, newValue in
            if newValue == .closed && oldValue != .closed && !pendingDrops.isEmpty {
                Task { await cascadeDropPendingBlocks() }
            }
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            refreshData()
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
            towerVM.buildTower(from: logs, incompleteHabits: timelineVM.incompleteWithinHour)
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

    // MARK: - Unified Header + Drawer

    private func drawerHeight(for position: DrawerPosition, screenHeight: CGFloat) -> CGFloat {
        switch position {
        case .closed: return drawerClosedHeight
        case .mid: return drawerClosedHeight + weekStripHeight
        case .full: return screenHeight
        }
    }

    private func snapPosition(currentHeight: CGFloat, velocity: CGFloat, screenHeight: CGFloat) -> DrawerPosition {
        let closedH = drawerHeight(for: .closed, screenHeight: screenHeight)
        let midH = drawerHeight(for: .mid, screenHeight: screenHeight)
        let fullH = drawerHeight(for: .full, screenHeight: screenHeight)

        // Flick down (positive velocity) → advance to larger stop
        if velocity > 300 {
            if currentHeight < midH { return .mid }
            return .full
        }
        // Flick up (negative velocity) → retreat to smaller stop
        if velocity < -300 {
            if currentHeight > midH { return .mid }
            return .closed
        }
        // No strong velocity → snap to nearest
        let distances: [(DrawerPosition, CGFloat)] = [
            (.closed, abs(currentHeight - closedH)),
            (.mid, abs(currentHeight - midH)),
            (.full, abs(currentHeight - fullH)),
        ]
        return distances.min(by: { $0.1 < $1.1 })!.0
    }

    private func unifiedDrawer(screenHeight: CGFloat) -> some View {
        let targetHeight = drawerHeight(for: drawerPosition, screenHeight: screenHeight)
        let fullHeight = screenHeight
        let currentHeight = max(drawerClosedHeight, min(fullHeight, targetHeight + dragOffset))

        let drawerDrag = DragGesture()
            .onChanged { value in
                dragOffset = value.translation.height
            }
            .onEnded { value in
                let velocity = value.predictedEndTranslation.height - value.translation.height
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    drawerPosition = snapPosition(
                        currentHeight: currentHeight,
                        velocity: velocity,
                        screenHeight: screenHeight
                    )
                    dragOffset = 0
                }
            }

        return VStack(spacing: 0) {
            // Header + week strip — draggable zone for the drawer
            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                if drawerPosition == .mid || drawerPosition == .full {
                    weekStrip
                        .padding(.top, 16)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .contentShape(Rectangle())
            .gesture(drawerDrag)

            // Timeline content — free from drawer drag, has its own gestures
            if drawerPosition == .full {
                timelineScrollView
                    .frame(maxHeight: .infinity)
                    .transition(.opacity)
            }

            Spacer(minLength: 0)

            // Bottom handle pill — draggable to close
            Capsule()
                .frame(width: 40, height: 5)
                .foregroundStyle(.clear)
                .glassEffect(.regular, in: .capsule)
                .shadow(color: .clear, radius: 0)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .gesture(drawerDrag)
        }
        .clipped()
        .safeAreaPadding(.top)
        .frame(height: currentHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .background(
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea(edges: .top)
                .mask(
                    VStack(spacing: 0) {
                        Rectangle()
                        LinearGradient(
                            colors: [.black, .black.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 20)
                    }
                )
                .opacity((drawerPosition != .closed || !isScrolledPastTop) ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: drawerPosition)
                .animation(.easeInOut(duration: 0.3), value: isScrolledPastTop)
        )
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
                proxy.scrollTo(currentHourAnchor, anchor: .center)
            }
            .onChange(of: drawerPosition) { _, newValue in
                if newValue == .full {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(currentHourAnchor, anchor: .center)
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

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(StrataTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                }

                Divider()

                Button(role: .destructive) {
                    resetTower()
                } label: {
                    Label("Reset Tower", systemImage: "trash")
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .frame(width: 40, height: 40)
                    .glassEffect(.regular.interactive(), in: .circle)
            }

            Text(Date().formatted(.dateTime.month(.wide).day().year()))
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .layoutPriority(1)

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.primary)

                Text("\(Int(towerVM.altimeterHeight))m")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassEffect(.regular.interactive(), in: .capsule)

            Button(action: generateTestBlock) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .frame(width: 40, height: 40)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
        }
        .padding(.bottom, 12)
    }

    // MARK: - Week Strip

    private let brandMint = Color(hex: 0x10B77F)

    private var weekStrip: some View {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let weekDates = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
        let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

        return HStack(spacing: 0) {
            ForEach(Array(weekDates.enumerated()), id: \.offset) { index, date in
                let dayNum = calendar.component(.day, from: date)
                let isToday = calendar.isDateInToday(date)
                let dateStr = TimelineViewModel.dateString(from: date)
                let isCompleted = weekCompletedDates.contains(dateStr)
                let isFuture = date > Date() && !isToday

                VStack(spacing: 6) {
                    Text(dayLabels[index])
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isFuture ? Color.primary.opacity(0.25) : Color.primary.opacity(0.5))

                    ZStack {
                        Circle()
                            .stroke(
                                isToday ? brandMint :
                                    isCompleted ? brandMint :
                                    Color.primary.opacity(isFuture ? 0.06 : 0.1),
                                lineWidth: isToday ? 2 : 1
                            )
                            .frame(width: 36, height: 36)

                        if isToday {
                            Circle()
                                .fill(brandMint.opacity(0.1))
                                .frame(width: 36, height: 36)
                        }

                        Text("\(dayNum)")
                            .font(.system(size: 15, weight: isToday ? .bold : .medium, design: .rounded))
                            .foregroundStyle(isFuture ? Color.primary.opacity(0.4) : Color.primary)

                        if isCompleted && !isToday {
                            Image(systemName: "checkmark")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(brandMint)
                                .offset(x: 13, y: -13)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
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

    private func towerContent(colW: CGFloat, topInset: CGFloat) -> some View {
        let gridW = CGFloat(columns) * colW + CGFloat(columns - 1) * spacing
        let rowCount = towerVM.totalRows
        let gridH = rowCount > 0
            ? CGFloat(rowCount) * colW + CGFloat(rowCount - 1) * spacing
            : 0

        return ZStack(alignment: .bottomTrailing) {
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

                        ForEach(towerVM.incompleteBlocks) { block in
                            let f = GridConstants.blockFrame(
                                column: block.column, row: block.row,
                                columnSpan: block.columnSpan, rowSpan: block.rowSpan,
                                cellSize: colW
                            )
                            incompleteBlock(habit: block.habit, frame: f)
                                .id(block.id)
                                .offset(x: f.minX, y: flippedY(for: f, gridH: gridH))
                                .zIndex(Double(block.row + 1))
                        }
                    }
                    .padding(.horizontal, hPad)
                    .padding(.bottom, 48)
                    .padding(.top, drawerClosedHeight + 20)
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
                    // Content minY near 0 or positive means we're at the top
                    let isScrolled = offset < -50
                    isScrolledPastTop = isScrolled
                    if isScrolled && !showTopButton {
                        withAnimation(.easeOut(duration: 0.2)) { showTopButton = true }
                        scheduleHideButton()
                    } else if !isScrolled && showTopButton {
                        withAnimation(.easeOut(duration: 0.2)) { showTopButton = false }
                        hideButtonTask?.cancel()
                    } else if isScrolled && showTopButton {
                        // User is still scrolling — reset the timer
                        scheduleHideButton()
                    }
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

            // Floating Action Button
            Button {
                scrollToTopTrigger += 1
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .opacity(showTopButton ? 1 : 0)
            .scaleEffect(showTopButton ? 1 : 0.8)
            .animation(.easeOut(duration: 0.2), value: showTopButton)
            .padding(.trailing, 24)
            .padding(.bottom, 36)
        }
        .padding(.top, topInset)
    }

    private func scheduleHideButton() {
        hideButtonTask?.cancel()
        hideButtonTask = Task {
            try? await Task.sleep(for: .seconds(2.0))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { showTopButton = false }
        }
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

    // MARK: - Live Incomplete Block

    private func incompleteBlock(habit: Habit, frame: CGRect) -> some View {
        IncompleteGridBlock(
            habit: habit,
            width: frame.width,
            height: frame.height,
            cornerRadius: cornerRadius,
            onComplete: {
                handleComplete(habit)
            }
        )
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

// MARK: - Incomplete Grid Block (hold-to-charge, vanish, gravity drop)

struct IncompleteGridBlock: View {
    let habit: Habit
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let onComplete: () -> Void

    @State private var isCharging = false
    @State private var isVanished = false
    @State private var hapticTrigger = 0

    private let holdDuration: Double = 0.6

    private var style: CategoryStyle {
        habit.category.style
    }

    var body: some View {
        let isBig = habit.blockSize.columnSpan > 1 || habit.blockSize.rowSpan > 1

        ZStack {
            // Muted clay fill
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(style.gradient.opacity(0.25))

            // Dashed outline
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(style.gradientBottom.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))

            Text(habit.title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(style.gradientBottom.opacity(0.7))
                .lineLimit(habit.blockSize.rowSpan > 1 ? 3 : 1)
                .minimumScaleFactor(0.65)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 12)
                .padding(.bottom, 12)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        // Charge squeeze
        .scaleEffect(isCharging ? 0.9 : 1.0)
        // Vanish on release
        .scaleEffect(isVanished ? 0.01 : 1.0)
        .opacity(isVanished ? 0 : 1)
        .contentShape(Rectangle())
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1.0), trigger: hapticTrigger)
        .onLongPressGesture(minimumDuration: holdDuration, perform: {
            // Release — vanish the scaffolding
            hapticTrigger += 1

            withAnimation(.spring(response: 0.15, dampingFraction: 0.9)) {
                isCharging = false
                isVanished = true
            }

            // Micro-delay so user sees the empty hole, then trigger gravity drop
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                onComplete()
            }

            // Reset for potential reuse
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isVanished = false
            }
        }, onPressingChanged: { pressing in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                isCharging = pressing
            }
        })
    }
}

#Preview {
    MainAppView()
        .modelContainer(for: [Habit.self, HabitLog.self, MoodLog.self], inMemory: true)
        .environment(EventKitService())
        .environment(HealthKitService())
}
