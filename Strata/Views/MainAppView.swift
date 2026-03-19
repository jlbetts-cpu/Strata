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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var towerVM = TowerViewModel()
    @State private var timelineVM = TimelineViewModel()
    @State private var habitManagerVM = HabitManagerViewModel()
    @State private var hasLoadedDemo = false
    @State private var selectedDetent: PresentationDetent = SheetContentView.smallDetent
    @State private var selectedTab: Int = 0
    @State private var hapticLightTrigger = 0
    @State private var hapticMediumTrigger = 0
    @State private var hapticHeavyTrigger = 0

    @State private var animCoord = TowerAnimationCoordinator()
    @State private var towerSwayPhase: Bool = false

    // Drop queue: habits completed in timeline, awaiting tower release
    @State private var pendingDrops: [Habit] = []

    // Stash animation: IDs of habits playing the fly-up exit
    @State private var stashedHabitIDs: Set<UUID> = []

    // Timeline drag-to-reschedule
    @State private var draggingHabitID: UUID? = nil
    @State private var dragYOffset: CGFloat = 0

    // Daily Story carousel
    @State private var activeCarouselBlockID: UUID? = nil

    // In-place block expansion
    @State private var expandedBlockID: UUID? = nil

    // New habit menu
    @State private var isNewHabitMenuOpen: Bool = false
    @State private var newHabitPrefillTime: String? = nil

    // Cached week completed dates
    @State private var weekCompletedDates: Set<String> = []

    // Cached incomplete timeline habits
    @State private var cachedIncompleteForTimeline: [Habit] = []

    // Tower scroll
    @State private var isScrolled: Bool = false
    @State private var scrollToDropID: UUID? = nil
    @State private var scrollToTopTrigger = 0
    @State private var towerScrollOffset: CGFloat = 0
    @State private var screenHeight: CGFloat = 0
    @State private var currentColW: CGFloat = 0

    // Timeline constants
    private let timelineStartHour = 0
    private let timelineEndHour = 23

    // Pinch-to-zoom timeline scale
    @AppStorage("timelinePixelsPerMinute") private var pixelsPerMinute: Double = 2.0
    @GestureState private var magnifyBy: CGFloat = 1.0

    /// Effective scale factor (live during gesture, baked after)
    private var effectiveScale: CGFloat { pixelsPerMinute * magnifyBy }
    /// Height of one hour in points at current zoom
    private var hourHeight: CGFloat { 60.0 * effectiveScale }

    private let hPad: CGFloat = GridConstants.horizontalPadding
    private let spacing: CGFloat = GridConstants.spacing
    private let columns = GridConstants.columnCount
    private let cornerRadius: CGFloat = GridConstants.cornerRadius
    private let collapsedHeaderHeight: CGFloat = 74

    var body: some View {
        Group {
            switch selectedTab {
            case 0:
                GeometryReader { geo in
                    towerTabContent(geo: geo)
                }
            case 1:
                Text("Coming soon")
                    .font(Typography.headerLarge)
                    .foregroundStyle(.secondary)
            case 2:
                Text("Coming soon")
                    .font(Typography.headerLarge)
                    .foregroundStyle(.secondary)
            default:
                EmptyView()
            }
        }
        // MARK: - Sheet hidden for Figma redesign
//        .sheet(isPresented: .constant(true)) {
//            SheetContentView(
//                selectedDetent: $selectedDetent,
//                selectedTab: $selectedTab,
//                weekData: weekData,
//                timelineContent: AnyView(timelineScrollView)
//            )
//            .presentationDetents(
//                [SheetContentView.smallDetent, SheetContentView.mediumDetent, SheetContentView.largeDetent],
//                selection: $selectedDetent
//            )
//            .presentationDragIndicator(.hidden)
//            .presentationBackgroundInteraction(.enabled(upThrough: SheetContentView.mediumDetent))
//            .presentationCornerRadius(28)
//            .presentationBackground(.clear)
//            .interactiveDismissDisabled()
//        }
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
        .onChange(of: reduceMotion) { _, newValue in
            animCoord.reduceMotion = newValue
        }
        .onChange(of: habits.count) { refreshData() }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            refreshData()
        }
    }

    // MARK: - Main Content

    private func towerTabContent(geo: GeometryProxy) -> some View {
        let colW = floor(
            (geo.size.width - hPad * 2 - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        )
        let gridW = CGFloat(columns) * colW + CGFloat(columns - 1) * spacing
        let safeTop = geo.safeAreaInsets.top

        return ZStack(alignment: .top) {
            // Warm background surface
            WarmBackground()
                .ignoresSafeArea()

            // Layer 1: ScrollView with blocks — fills screen, under safe area
            towerContent(colW: colW, topInset: collapsedHeaderHeight,
                         safeAreaTop: safeTop, viewportHeight: geo.size.height)
                .ignoresSafeArea(.container, edges: .top)

            // MARK: - Header & new habit menu hidden for Figma redesign
            // Floating + button for debug block injection
            #if DEBUG
            Button(action: { injectDebugBlock() }) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, safeTop + 12)
            .padding(.trailing, hPad)
            #endif

//            StrataHeaderView(
//                month: dominantMonth,
//                day: dominantDay,
//                isScrolled: isScrolled,
//                gridWidth: gridW,
//                onPlusTap: {
//                    #if DEBUG
//                    injectDebugBlock()
//                    #endif
//                }
//            )
//
//            if isNewHabitMenuOpen {
//                Color.black.opacity(0.001)
//                    .ignoresSafeArea()
//                    .onTapGesture {
//                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//                            isNewHabitMenuOpen = false
//                        }
//                    }
//
//                NewHabitMenu(
//                    isPresented: $isNewHabitMenuOpen,
//                    modelContext: modelContext,
//                    onCreated: {
//                        refreshData()
//                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
//                            selectedDetent = SheetContentView.largeDetent
//                        }
//                    },
//                    prefillTime: newHabitPrefillTime
//                )
//                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
//                .padding(.top, safeTop + collapsedHeaderHeight + 8)
//                .padding(.trailing, hPad)
//                .transition(.scale(scale: 0.5, anchor: .topTrailing).combined(with: .opacity))
//                .zIndex(200)
//            }
        }
        .onChange(of: selectedDetent) { oldDetent, newDetent in
            if newDetent != SheetContentView.smallDetent {
                scrollToTopTrigger += 1
            }
            if oldDetent == SheetContentView.largeDetent
                && newDetent != SheetContentView.largeDetent
                && !pendingDrops.isEmpty {
                Task { await cascadeDropPendingBlocks() }
            }
        }
        .onAppear {
            screenHeight = geo.size.height
            currentColW = colW
        }
        .onChange(of: geo.size.height) { _, h in screenHeight = h }
        .onChange(of: geo.size.width) { _, w in
            currentColW = floor(
                (w - hPad * 2 - spacing * CGFloat(columns - 1)) / CGFloat(columns)
            )
        }
    }

    // MARK: - Dominant Date (Split-Flap)

    private var dominantVisibleDate: Date {
        guard !towerVM.placedBlocks.isEmpty else { return Date() }

        let rowCount = towerVM.totalRows
        guard rowCount > 0, currentColW > 0, screenHeight > 0 else { return Date() }

        let cellStride = currentColW + spacing
        let _ = CGFloat(rowCount) * currentColW + CGFloat(rowCount - 1) * spacing

        let contentTopY = towerScrollOffset
        let viewTop = collapsedHeaderHeight + 20
        let viewBottom = screenHeight

        let internalTopPad = collapsedHeaderHeight + 20
        let visibleTopInContent = viewTop - contentTopY
        let visibleBottomInContent = viewBottom - contentTopY

        let visibleTopInGrid = visibleTopInContent - internalTopPad
        let visibleBottomInGrid = visibleBottomInContent - internalTopPad

        let topGridRow = max(0, rowCount - 1 - Int(visibleBottomInGrid / cellStride))
        let bottomGridRow = min(rowCount - 1, rowCount - 1 - Int(visibleTopInGrid / cellStride))

        let visibleBlocks = towerVM.placedBlocks.filter { block in
            block.row >= topGridRow && block.row <= bottomGridRow
        }

        guard !visibleBlocks.isEmpty else { return Date() }

        // Count occurrences of each dateString — pick the mode (most frequent)
        var counts: [String: Int] = [:]
        for block in visibleBlocks {
            counts[block.log.dateString, default: 0] += 1
        }

        // Break ties by most recent date
        let dominant = counts.max { a, b in
            if a.value != b.value { return a.value < b.value }
            return a.key < b.key
        }?.key

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let dominant, let date = formatter.date(from: dominant) {
            return date
        }
        return Date()
    }

    private var dominantMonth: String {
        dominantVisibleDate.formatted(.dateTime.month(.abbreviated))
    }

    private var dominantDay: String {
        String(Calendar.current.component(.day, from: dominantVisibleDate))
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
        animCoord.reduceMotion = reduceMotion
        animCoord.lookupMass = { [towerVM] id in
            towerVM.placedBlocks.first(where: { $0.id == id })?.habit.blockSize.massTier
        }
        animCoord.onImpact = { [towerVM, animCoord] landedID, mass in
            animCoord.triggerRipple(from: landedID, massTier: mass, placedBlocks: towerVM.placedBlocks)
        }
        if !reduceMotion {
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                towerSwayPhase = true
            }
        }
        refreshData()
    }

    @discardableResult
    private func refreshData() -> Set<UUID> {
        timelineVM.loadToday(habits: habits, logs: logs)
        let droppedIDs: Set<UUID> = withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            towerVM.buildTower(from: logs)
        }
        weekCompletedDates = Set(logs.filter { $0.completed }.map { $0.dateString })
        recomputeIncompleteTimeline()

        // Purge stale animation state
        let validIDs = Set(towerVM.placedBlocks.map(\.id))
        animCoord.purgeStaleState(validIDs: validIDs)
        return droppedIDs
    }

    private func enqueueDrop(blockIDs: Set<UUID>) {
        animCoord.enqueueDrop(blockIDs: blockIDs)
    }

    // MARK: - Time-Scaled Timeline

    /// The current hour (clamped to timeline range) used as scroll anchor ID.
    private var currentHourAnchor: Int {
        let hour = Calendar.current.component(.hour, from: Date())
        return max(timelineStartHour, min(timelineEndHour, hour))
    }

    private let gutterWidth: CGFloat = GridConstants.timelineGutterWidth

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
                                .font(Typography.caption2)
                                .foregroundStyle(Color.primary.opacity(0.4))
                                .frame(width: gutterWidth, alignment: .trailing)
                                .padding(.trailing, 8)

                            Rectangle()
                                .fill(Color.primary.opacity(0.05))
                                .frame(height: 0.33)
                        }
                        .id(hour)
                        .offset(y: y - 6)
                    }

                    // Task blocks — duration-sized, time-positioned, sorted chronologically
                    let sortedTimeline = incompleteForTimeline

                    if sortedTimeline.isEmpty {
                        Text("No habits scheduled")
                            .font(Typography.bodyMedium)
                            .foregroundStyle(Color.primary.opacity(0.3))
                            .frame(maxWidth: .infinity)
                            .offset(y: CGFloat(currentHourAnchor - timelineStartHour) * 60.0 * effectiveScale - 20)
                    }

                    ForEach(Array(sortedTimeline.enumerated()), id: \.element.id) { idx, habit in
                        let minutesFromStart = minutesFromStartOfDay(for: habit)
                        let y = minutesFromStart * effectiveScale
                        let durationMins = habit.blockSize.durationMinutes
                        let h = max(durationMins * effectiveScale, 28) // min tap target
                        let isDragging = draggingHabitID == habit.id
                        let extraY = isDragging ? dragYOffset : 0
                        let isStashed = stashedHabitIDs.contains(habit.id)

                        HStack(spacing: 0) {
                            Color.clear
                                .frame(width: gutterWidth + 12)

                            TimelineHabitRow(
                                habit: habit,
                                rowHeight: h,
                                cornerRadius: cornerRadius,
                                onComplete: { completedHabit in
                                    stashAndQueueDrop(completedHabit)
                                },
                                onSkip: { skippedHabit in
                                    skipHabit(skippedHabit)
                                }
                            )
                        }
                        .offset(y: y + extraY)
                        // Curved arc: scale down, fly up-right toward date pill
                        .scaleEffect(isStashed ? 0.3 : (isDragging ? 1.04 : 1.0))
                        .offset(
                            x: isStashed ? 80 : 0,
                            y: isStashed ? -200 : 0
                        )
                        .opacity(isStashed ? 0 : 1)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isStashed)
                        .shadow(
                            color: isDragging ? Color.black.opacity(0.18) : .clear,
                            radius: isDragging ? 12 : 0, y: isDragging ? 4 : 0
                        )
                        .zIndex(isDragging ? 100 : Double(idx))
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
            .onChange(of: selectedDetent) { _, newDetent in
                if newDetent == SheetContentView.largeDetent {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("NowLine", anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private var incompleteForTimeline: [Habit] { cachedIncompleteForTimeline }

    private func recomputeIncompleteTimeline() {
        let completedIDs = Set(timelineVM.completedToday.compactMap { $0.habit?.id })
        let pendingIDs = Set(pendingDrops.map(\.id))
        let skippedIDs = timelineVM.skippedHabitIDs
        cachedIncompleteForTimeline = timelineVM.todaysHabits.filter { habit in
            !completedIDs.contains(habit.id) && !pendingIDs.contains(habit.id) && !skippedIDs.contains(habit.id)
        }
        .sorted { (TimelineViewModel.effectiveHour(for: $0) ?? 0) < (TimelineViewModel.effectiveHour(for: $1) ?? 0) }
    }

    private var nowIndicator: some View {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let totalMinutes = CGFloat((hour - timelineStartHour) * 60 + minute)
        let y = totalMinutes * effectiveScale

        let warmRed = Color(hex: 0xE85D4A)

        return HStack(spacing: 0) {
            Text("")
                .font(Typography.caption2)
                .frame(width: gutterWidth, alignment: .trailing)
                .padding(.trailing, 8)

            Circle()
                .fill(warmRed)
                .frame(width: 6, height: 6)

            Rectangle()
                .fill(warmRed)
                .frame(height: 1.0)
        }
        .frame(height: 6)
        .offset(y: y - 3)
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
        animCoord.isCascading = true

        scrollToTopTrigger += 1
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s scroll settle

        for (index, habit) in habits.enumerated() {
            timelineVM.completeHabit(habit)
            let droppedIDs = refreshData()
            HapticsEngine.cascade(index: index)
            if let droppedID = droppedIDs.first {
                scrollToDropID = droppedID
            }
            enqueueDrop(blockIDs: droppedIDs)
        }
        // animCoord.isCascading cleared by drain loop when it finishes
    }

    // MARK: - Tower Content

    private func towerContent(colW: CGFloat, topInset: CGFloat,
                              safeAreaTop: CGFloat,
                              viewportHeight: CGFloat) -> some View {
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
                            .frame(width: gridW, height: max(gridH, viewportHeight - topInset - 48))

                        let visibleBlocks = visibleTowerBlocks(
                            colW: colW, gridH: gridH,
                            viewportHeight: viewportHeight, topInset: topInset
                        )
                        ForEach(visibleBlocks) { block in
                            let f = GridConstants.blockFrame(
                                column: block.column, row: block.row,
                                columnSpan: block.columnSpan, rowSpan: block.rowSpan,
                                cellSize: colW
                            )
                            let phase = animCoord.dropPhases[block.id]
                            let isAnimating = phase != nil
                            let isNew = isAnimating || towerVM.newlyDroppedIDs.contains(block.id)

                            animatedBlock(block: block, frame: f, phase: phase, isNew: isNew,
                                         gridH: gridH, safeAreaTop: safeAreaTop)
                                .id(block.id)
                                .offset(x: f.minX, y: gridH - f.maxY)
                                .zIndex(isAnimating ? 100 : Double(block.row + 1))
                        }
                    }
                    .padding(.horizontal, hPad)
                    .padding(.top, safeAreaTop + collapsedHeaderHeight + 20)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollClipDisabled(true)
                // Scroll stays enabled during cascade — animations work independently
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    geo.contentOffset.y
                } action: { oldOffset, newOffset in
                    towerScrollOffset = newOffset
                    let wasScrolled = oldOffset > 0
                    let nowScrolled = newOffset > 0
                    if wasScrolled != nowScrolled {
                        isScrolled = nowScrolled
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

            // Tower scrubber — scroll indicator + fast scrub
            TowerScrubberView(
                towerContentHeight: gridH,
                scrollOffset: towerScrollOffset,
                viewportHeight: viewportHeight,
                heightMeters: towerVM.altimeterHeight,
                topInset: 44,
                onScrub: { fraction in
                    let targetRow = Int((1.0 - fraction) * CGFloat(max(1, towerVM.totalRows)))
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
        .safeAreaInset(edge: .bottom) {
            // Fixed bottom inset while sheet is hidden for Figma redesign
            Color.clear.frame(height: 20)
        }
    }

    // MARK: - Visible Block Culling

    private func visibleTowerBlocks(
        colW: CGFloat, gridH: CGFloat,
        viewportHeight: CGFloat, topInset: CGFloat
    ) -> [PlacedBlock] {
        let blocks = towerVM.placedBlocks
        // For small towers, render everything
        guard blocks.count > 80 else { return blocks }

        let cellStride = colW + spacing
        guard cellStride > 0 else { return blocks }

        // Visible content range in grid coordinates
        let visibleTop = -towerScrollOffset - topInset - 200 // buffer
        let visibleBottom = -towerScrollOffset + viewportHeight + 200

        return blocks.filter { block in
            // Blocks currently animating must always render
            if animCoord.dropPhases[block.id] != nil || towerVM.newlyDroppedIDs.contains(block.id) {
                return true
            }
            let blockY = gridH - CGFloat(block.row + block.rowSpan) * cellStride
            let blockBottom = gridH - CGFloat(block.row) * cellStride
            return blockBottom >= visibleTop && blockY <= visibleBottom
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

    // MARK: - Animated Block Wrapper

    private func animatedBlock(
        block: PlacedBlock,
        frame f: CGRect,
        phase: TowerAnimationCoordinator.DropPhase?,
        isNew: Bool,
        gridH: CGFloat = 0,
        safeAreaTop: CGFloat = 0
    ) -> some View {
        let mass = CGFloat(block.habit.blockSize.massTier)

        let dropOffset: CGFloat = switch phase {
        case .falling:
            {
                let paddingTop = safeAreaTop + collapsedHeaderHeight + 20
                let blockInScrollContent = paddingTop + (gridH - f.maxY)
                let dynamicOffset = towerScrollOffset - blockInScrollContent - f.height - 60
                return min(dynamicOffset, -400)
            }()
        case .squash, .stretch, .wobble: CGFloat(0)
        case .none: CGFloat(0)
        }

        // Volume-preserving squash-and-stretch (energy-proportional: quadratic in mass)
        let (impactScaleX, impactScaleY): (CGFloat, CGFloat) = switch phase {
        case .squash:
            (1.0 + GridConstants.squashScaleX(mass: mass),
             1.0 - GridConstants.squashScaleY(mass: mass))
        case .stretch:
            (1.0 - GridConstants.stretchScaleX(mass: mass),
             1.0 + GridConstants.stretchScaleY(mass: mass))
        default:
            (1.0, 1.0)
        }

        // Wobble rotation on settle
        let wobbleDegrees: Double = switch phase {
        case .wobble:
            mass >= 2 ? GridConstants.wobbleDegreesHeavy : GridConstants.wobbleDegreesLight
        default:
            0
        }

        // Landing flash on squash impact
        let flashBrightness: Double = phase == .squash ? 0.06 : 0

        // Phase-aware shadow during drop
        let (dropShadowRadius, dropShadowY): (CGFloat, CGFloat) = switch phase {
        case .falling: (12, 8)
        case .squash: (1, 0.5)
        case .stretch: (3, 1.5)
        case .wobble: (4, 2)
        case .none: (0, 0)
        }

        // Ripple: volume-preserving compress
        let isRippling = animCoord.ripplingBlockIDs.contains(block.id)
        let ri = animCoord.rippleIntensity[block.id] ?? 1.0
        let rippleScaleX: CGFloat = isRippling ? 1.0 + 0.020 * ri : 1.0
        let rippleScaleY: CGFloat = isRippling ? 1.0 - 0.035 * ri : 1.0
        let rippleOffsetY: CGFloat = isRippling ? 1.5 * ri : 0

        return ZStack {
            if isNew {
                ghostSlot(width: f.width, height: f.height)
            }

            completedBlock(block: block, frame: f)
                .scaleEffect(x: impactScaleX, y: impactScaleY, anchor: .bottom)
                .rotation3DEffect(.degrees(wobbleDegrees), axis: (x: 0, y: 0, z: 1))
                .brightness(flashBrightness)
                .shadow(
                    color: phase != nil ? .black.opacity(0.12) : .clear,
                    radius: dropShadowRadius,
                    x: 0,
                    y: dropShadowY
                )
                .offset(y: dropOffset)
        }
        .scaleEffect(x: rippleScaleX, y: rippleScaleY, anchor: .bottom)
        .offset(y: rippleOffsetY)
        // Idle micro-sway — alive feel when not animating
        .rotationEffect(
            .degrees((!reduceMotion && phase == nil && towerSwayPhase) ? 0.12 : ((!reduceMotion && phase == nil) ? -0.12 : 0)),
            anchor: .bottom
        )
    }

    // MARK: - Live Completed Block

    private func completedBlock(block: PlacedBlock, frame: CGRect) -> some View {
        let isExpanded = expandedBlockID == block.id
        let expandedW = CGFloat(columns) * frame.width / CGFloat(block.columnSpan)
        let expandedH = frame.height * 2.5

        return ZStack {
            FlippableBlockView(
                block: block,
                width: isExpanded ? expandedW : frame.width,
                height: isExpanded ? expandedH : frame.height,
                cornerRadius: isExpanded ? 16 : cornerRadius,
                modelContext: modelContext,
                onExpandPhoto: { _ in
                    if isExpanded {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            activeCarouselBlockID = block.id
                        }
                    }
                }
            )

            // Expanded detail overlay
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(block.habit.category.style.baseColor)
                            .frame(width: 10, height: 10)

                        Text(block.habit.title)
                            .font(Typography.headerLarge)
                            .foregroundStyle(.white)
                    }

                    if let time = block.log.completedAt {
                        Text("Completed \(time.formatted(date: .omitted, time: .shortened))")
                            .font(Typography.bodySmall)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    Text("+\(block.habit.blockSize.baseXP) XP")
                        .font(Typography.bodyMedium)
                        .foregroundStyle(.white.opacity(0.9))

                    if block.log.imageData != nil {
                        Text("Tap photo to expand")
                            .font(Typography.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .frame(
            width: isExpanded ? expandedW : frame.width,
            height: isExpanded ? expandedH : frame.height
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
        .onTapGesture {
            if block.log.imageData != nil && !isExpanded {
                // Photo blocks: open carousel on tap (unchanged behavior)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    activeCarouselBlockID = block.id
                }
            } else {
                // Toggle expansion
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    if expandedBlockID == block.id {
                        expandedBlockID = nil
                    } else {
                        expandedBlockID = block.id
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func handleComplete(_ habit: Habit) {
        timelineVM.completeHabit(habit)
        let droppedIDs = refreshData()
        enqueueDrop(blockIDs: droppedIDs)
    }

    /// Stash a completed habit: play curved arc animation toward date pill, then queue for cascade.
    private func stashAndQueueDrop(_ habit: Habit) {
        _ = withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            stashedHabitIDs.insert(habit.id)
        }
        // After arc animation finishes, move to pending drops
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            stashedHabitIDs.remove(habit.id)
            pendingDrops.append(habit)
        }
    }

    /// Skip a habit — remove from today without completing.
    private func skipHabit(_ habit: Habit) {
        timelineVM.skipHabit(habit)
        refreshData()
    }

    // MARK: - Debug Block Injection (temporary)

    #if DEBUG
    private func injectDebugBlock() {
        let sizes: [BlockSize] = [.small, .medium, .hard]
        let categories: [HabitCategory] = HabitCategory.allCases
        let habit = Habit(
            title: "Debug \(Int.random(in: 100...999))",
            category: categories.randomElement()!,
            blockSize: sizes.randomElement()!,
            frequency: [],
            scheduledTime: nil
        )
        modelContext.insert(habit)

        let log = HabitLog(habit: habit, dateString: TimelineViewModel.dateString(from: Date()))
        log.completed = true
        log.completedAt = Date()
        modelContext.insert(log)

        try? modelContext.save()
        let droppedIDs = refreshData()
        enqueueDrop(blockIDs: droppedIDs)
    }
    #endif

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

// MARK: - Warm Background

private struct WarmBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Rectangle().fill(
            colorScheme == .dark
                ? Color(red: 0.08, green: 0.08, blue: 0.085)
                : Color(red: 0.98, green: 0.975, blue: 0.965)
        )
    }
}

#Preview {
    MainAppView()
        .modelContainer(for: [Habit.self, HabitLog.self, MoodLog.self], inMemory: true)
        .environment(EventKitService())
        .environment(HealthKitService())
}
