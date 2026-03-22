import SwiftUI
import SwiftData
import Combine

struct MainAppView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var habits: [Habit]
    @Query private var logs: [HabitLog]

    init() {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
        let monthStartString = TimelineViewModel.dateString(from: startOfMonth)
        _logs = Query(filter: #Predicate<HabitLog> { log in
            log.dateString >= monthStartString
        })
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var towerVM = TowerViewModel()
    @State private var timelineVM = TimelineViewModel()
    @State private var habitManagerVM = HabitManagerViewModel()
    @State private var towerManager = TowerManager()
    @State private var hasLoadedDemo = false
    @State private var selectedTab: StrataTab = .tower
    @State private var hapticLightTrigger = 0
    @State private var hapticMediumTrigger = 0
    @State private var hapticHeavyTrigger = 0

    @State private var towerFilterMode: TowerFilterMode = .day
    @State private var animCoord = TowerAnimationCoordinator()
    @State private var towerSwayPhase: Bool = false
    @State private var towerImpactScale: CGFloat = 1.0

    // Drop queue: habits completed in timeline, awaiting tower release
    @State private var pendingDrops: [Habit] = []

    // Daily Story carousel
    @State private var activeCarouselBlockID: UUID? = nil

    // In-place block expansion
    @State private var expandedBlockID: UUID? = nil

    // New habit menu
    @State private var isNewHabitMenuOpen: Bool = false
    @State private var newHabitPrefillTime: String? = nil

    // Skeleton build-up animation
    @State private var visibleSkeletonCount: Int = 0
    @State private var skeletonBuildTask: Task<Void, Never>?
    @State private var reloadTask: Task<Void, Never>?

    // Timeline selected date (defaults to today)
    @State private var timelineSelectedDate: Date = Date()

    // Cached week completed dates
    @State private var weekCompletedDates: Set<String> = []

    // Cached incomplete timeline habits
    @State private var cachedIncompleteForTimeline: [Habit] = []

    // Cached computed properties
    @State private var cachedFilteredLogs: [HabitLog] = []
    @State private var cachedWeekData: [DayProgressData] = []

    // Tower scroll
    @State private var isScrolled: Bool = false
    @State private var scrollToDropID: UUID? = nil
    @State private var scrollToTopTrigger = 0
    @State private var towerScrollOffset: CGFloat = 0
    @State private var screenHeight: CGFloat = 0
    @State private var currentColW: CGFloat = 0
    @State private var safeAreaTop: CGFloat = 0
    @State private var safeAreaBottom: CGFloat = 0

    private let hPad: CGFloat = GridConstants.horizontalPadding
    private let spacing: CGFloat = GridConstants.spacing
    private let columns = GridConstants.columnCount
    private let cornerRadius: CGFloat = GridConstants.cornerRadius
    private let collapsedHeaderHeight: CGFloat = 110

    private var filteredLogs: [HabitLog] { cachedFilteredLogs }

    private func recomputeFilteredLogs() {
        let calendar = Calendar.current
        let now = Date()
        switch towerFilterMode {
        case .day:
            let todayStr = TimelineViewModel.dateString(from: now)
            cachedFilteredLogs = logs.filter { $0.dateString == todayStr }
        case .week:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let weekStartStr = TimelineViewModel.dateString(from: startOfWeek)
            cachedFilteredLogs = logs.filter { $0.dateString >= weekStartStr }
        case .month:
            cachedFilteredLogs = Array(logs)
        }
        // Filter by active tower
        if let activeTowerID = towerManager.activeTower?.id {
            cachedFilteredLogs = cachedFilteredLogs.filter { $0.habit?.tower?.id == activeTowerID }
        }
    }

    @State private var addTapTrigger: Int = 0

    @State private var showPlanPage = false

    var body: some View {
        mainContent
            .sheet(isPresented: $showPlanPage) {
                NavigationStack {
                    PlanPageView()
                }
            }
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
            .onChange(of: habits.count) { guard !towerVM.isLoading else { return }; refreshData() }
            .onChange(of: towerFilterMode) {
                reloadTowerWithAnimation()
            }
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
                guard !towerVM.isLoading else { return }
                refreshData()
            }
    }

    private var mainContent: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                Tab("Tower", systemImage: "square.stack.fill", value: StrataTab.tower) {
                    towerTab
                }
                Tab("Today", systemImage: "calendar", value: StrataTab.today) {
                    timelineTabContent
                }
                Tab("Insights", systemImage: "chart.bar", value: StrataTab.insights) {
                    InsightsView()
                }
                Tab("Preferences", systemImage: "gearshape", value: StrataTab.preferences) {
                    SettingsView()
                }
            }
            .tabBarMinimizeBehavior(.onScrollDown)

            // Floating + button
            addButton
                .padding(.trailing, 20)
                .padding(.bottom, 70)
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == .tower && !pendingDrops.isEmpty {
                Task { await cascadeDropPendingBlocks() }
            }
            if newTab != .today {
                timelineSelectedDate = Date()
            }
        }
        .onChange(of: towerManager.activeTower?.id) {
            reloadTowerWithAnimation()
        }
    }

    // MARK: - Main Content

    private var towerTab: some View {
        towerTabContent()
            .background { geometryTracker }
    }

    private func columnWidth(for totalWidth: CGFloat) -> CGFloat {
        floor((totalWidth - hPad * 2 - spacing * CGFloat(columns - 1)) / CGFloat(columns))
    }

    private var geometryTracker: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear {
                    screenHeight = geo.size.height
                    safeAreaTop = geo.safeAreaInsets.top
                    safeAreaBottom = geo.safeAreaInsets.bottom
                    currentColW = columnWidth(for: geo.size.width)
                }
                .onChange(of: geo.size.height) { _, h in screenHeight = h }
                .onChange(of: geo.size.width) { _, w in
                    currentColW = columnWidth(for: w)
                }
                .onChange(of: geo.safeAreaInsets.top) { _, t in safeAreaTop = t }
                .onChange(of: geo.safeAreaInsets.bottom) { _, b in safeAreaBottom = b }
        }
    }

    private func towerTabContent() -> some View {
        let colW = currentColW

        return ZStack(alignment: .top) {
            // Warm background surface
            WarmBackground()
                .ignoresSafeArea()

            // Layer 1: ScrollView with blocks — fills screen, under safe area
            towerContent(colW: colW, topInset: collapsedHeaderHeight,
                         safeAreaTop: safeAreaTop, safeAreaBottom: safeAreaBottom,
                         viewportHeight: screenHeight)
                .scaleEffect(y: towerImpactScale, anchor: .bottom)
                .environment(\.towerFilterMode, towerFilterMode)
                .ignoresSafeArea(.container, edges: .top)

            #if DEBUG
            Menu {
                Button("Add Block", systemImage: "plus") {
                    injectDebugBlock()
                }
                Button("Remove Block", systemImage: "minus") {
                    removeLastDebugBlock()
                }
                Divider()
                Button("Reset Tower", systemImage: "arrow.counterclockwise", role: .destructive) {
                    resetTower()
                }
            } label: {
                Text("Debug")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, safeAreaTop + 12)
            .padding(.trailing, hPad)
            #endif

            AltimeterPill(heightMeters: towerVM.altimeterHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, safeAreaTop + 48)
                .padding(.trailing, hPad)
                .opacity(towerVM.totalRows > 0 ? 1 : 0)

            // Filter pill — top-left of tower screen
            TowerFilterPill(selection: $towerFilterMode)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, safeAreaTop + 12)
                .padding(.leading, hPad)
        }
    }

    // MARK: - Timeline Tab

    private var timelineTabContent: some View {
        ScheduleTimelineView(
            weekData: weekData,
            selectedDate: $timelineSelectedDate,
            incompleteHabits: habitsForSelectedDate,
            isViewingToday: Calendar.current.isDateInToday(timelineSelectedDate),
            isViewingPast: !Calendar.current.isDateInToday(timelineSelectedDate) && timelineSelectedDate < Date(),
            onComplete: { habit in
                pendingDrops.append(habit)
            },
            onSkip: { habit in
                timelineVM.skipHabit(habit)
                refreshData()
            },
            onAddHabit: { prefillTime in
                newHabitPrefillTime = prefillTime
                isNewHabitMenuOpen = true
            }
        )
        .onChange(of: timelineSelectedDate) {
            refreshData()
        }
    }

    /// Habits for the currently selected date in the timeline
    private var habitsForSelectedDate: [Habit] {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(timelineSelectedDate)

        if isToday {
            return incompleteForTimeline
        }

        let dateStr = TimelineViewModel.dateString(from: timelineSelectedDate)
        let weekday = calendar.component(.weekday, from: timelineSelectedDate)
        let dayCode = DayCode.from(weekday: weekday)
        let isPast = timelineSelectedDate < Date()

        let scheduled = habits.filter { habit in
            if habit.tower?.id != towerManager.activeTower?.id { return false }
            if habit.isTodo {
                return habit.scheduledDate == dateStr
            }
            return habit.frequency.contains(dayCode)
        }

        if isPast {
            // Past: show all scheduled habits (completed ones will show as completed)
            return scheduled.sorted {
                (TimelineViewModel.effectiveHour(for: $0) ?? 0) < (TimelineViewModel.effectiveHour(for: $1) ?? 0)
            }
        } else {
            // Future: show scheduled, filter out already-completed
            let completedIDs = Set(logs.filter { $0.dateString == dateStr && $0.completed }.compactMap { $0.habit?.id })
            return scheduled.filter { !completedIDs.contains($0.id) }
                .sorted { (TimelineViewModel.effectiveHour(for: $0) ?? 0) < (TimelineViewModel.effectiveHour(for: $1) ?? 0) }
        }
    }

    // MARK: - Floating Add Button

    private var addButton: some View {
        Button {
            addTapTrigger += 1
            showPlanPage = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 52, height: 52)
        }
        .buttonStyle(.glassProminent)
        .shadow(color: .black.opacity(GridConstants.adaptiveShadowOpacity(0.08, colorScheme: colorScheme)), radius: 20, y: 8)
        .shadow(color: .black.opacity(GridConstants.adaptiveShadowOpacity(0.12, colorScheme: colorScheme)), radius: 4, y: 2)
        .phaseAnimator([false, true], trigger: addTapTrigger) { content, phase in
            content.scaleEffect(
                x: phase ? 1.06 : 1.0,
                y: phase ? 0.94 : 1.0
            )
        } animation: { phase in
            phase ? .spring(duration: 0.08) : .spring(duration: 0.25, bounce: 0.3)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: addTapTrigger)
    }

    // MARK: - Dominant Date (Split-Flap)

    private var dominantVisibleDate: Date {
        guard !towerVM.placedBlocks.isEmpty else { return Date() }

        let rowCount = towerVM.totalRows
        guard rowCount > 0, currentColW > 0, screenHeight > 0 else { return Date() }

        let cellStride = currentColW + spacing

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

        if let dominant, let date = Self.dateStringFormatter.date(from: dominant) {
            return date
        }
        return Date()
    }

    private static let dateStringFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var dominantMonth: String {
        dominantVisibleDate.formatted(.dateTime.month(.abbreviated))
    }

    private var dominantDay: String {
        String(Calendar.current.component(.day, from: dominantVisibleDate))
    }

    // MARK: - Week Progress Data

    private var weekData: [DayProgressData] { cachedWeekData }

    private func recomputeWeekData() {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let weekDates = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
        let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

        cachedWeekData = weekDates.enumerated().map { index, date in
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
                date: date,
                dayLabel: dayLabels[index],
                dayNumber: dayNum,
                completionRate: rate,
                isToday: isToday,
                isFuture: isFuture
            )
        }
    }

    // MARK: - Skeleton Build-Up

    private func startSkeletonBuildUp() {
        skeletonBuildTask?.cancel()
        if reduceMotion {
            visibleSkeletonCount = 8
            return
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
            visibleSkeletonCount = 1
        }
        skeletonBuildTask = Task { @MainActor in
            for i in 2...8 {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                    visibleSkeletonCount = i
                }
            }
        }
    }

    private func stopSkeletonBuildUp() {
        skeletonBuildTask?.cancel()
        skeletonBuildTask = nil
        visibleSkeletonCount = 0
    }

    private func reloadTowerWithAnimation() {
        reloadTask?.cancel()
        towerVM.startLoading()
        startSkeletonBuildUp()
        reloadTask = Task {
            let loadStart = ContinuousClock.now
            guard !Task.isCancelled else { return }
            _ = withAnimation(.spring(response: 0.55, dampingFraction: 0.9)) {
                refreshData()
            }
            let elapsed = ContinuousClock.now - loadStart
            let remaining = max(.zero, .milliseconds(300) - elapsed)
            try? await Task.sleep(for: remaining)
            guard !Task.isCancelled else { return }
            stopSkeletonBuildUp()
        }
    }

    // MARK: - Setup

    private func setup() {
        HapticsEngine.prepare()
        towerManager.ensureDefaultTower(context: modelContext)
        towerManager.loadActiveTower(context: modelContext)
        timelineVM.modelContext = modelContext
        habitManagerVM.modelContext = modelContext
        animCoord.reduceMotion = reduceMotion
        animCoord.lookupMass = { [towerVM] id in
            towerVM.placedBlocks.first(where: { $0.id == id })?.habit.blockSize.massTier
        }
        animCoord.onImpact = { [towerVM, animCoord] landedID, mass in
            animCoord.triggerRipple(from: landedID, massTier: mass, placedBlocks: towerVM.placedBlocks)
            // Tower compression pulse — global impact response
            let compression: CGFloat = mass >= 2 ? 0.004 : 0.002
            withAnimation(.easeOut(duration: 0.06)) {
                towerImpactScale = 1.0 - compression
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    towerImpactScale = 1.0
                }
            }
        }
        if !reduceMotion {
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                towerSwayPhase = true
            }
        }
        startSkeletonBuildUp()
        Task {
            let loadStart = ContinuousClock.now
            // Migrate existing imageData blobs to file system
            await ImageMigrationRunner.migrateIfNeeded(context: modelContext)
            _ = withAnimation(.spring(response: 0.55, dampingFraction: 0.9)) {
                refreshData()
            }
            let elapsed = ContinuousClock.now - loadStart
            let remaining = max(.zero, .milliseconds(300) - elapsed)
            try? await Task.sleep(for: remaining)
            stopSkeletonBuildUp()
        }
    }

    @discardableResult
    private func refreshData() -> Set<UUID> {
        recomputeFilteredLogs()
        recomputeWeekData()
        let towerHabits = habits.filter { $0.tower?.id == towerManager.activeTower?.id }
        timelineVM.loadToday(habits: towerHabits, logs: logs)
        let droppedIDs: Set<UUID> = withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            towerVM.buildTower(from: filteredLogs)
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

    // MARK: - Timeline Data (shared with TimelineView via props)

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
                              safeAreaTop: CGFloat, safeAreaBottom: CGFloat,
                              viewportHeight: CGFloat) -> some View {
        let gridW = CGFloat(columns) * colW + CGFloat(columns - 1) * spacing
        let rowCount = towerVM.totalRows
        let gridH = rowCount > 0
            ? CGFloat(rowCount) * colW + CGFloat(rowCount - 1) * spacing
            : 0
        let footerClearance: CGFloat = 16
        let contentHeight = max(gridH, viewportHeight - topInset - 20 - footerClearance)

        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // Top anchor for FAB scroll
                    Color.clear.frame(height: 1)
                        .id("TowerTop")

                    Color.clear
                        .frame(width: gridW, height: contentHeight)

                    if towerVM.isLoading {
                        skeletonGrid(colW: colW, contentHeight: contentHeight)
                    } else {
                        placedBlocksGrid(colW: colW, contentHeight: contentHeight,
                                         viewportHeight: viewportHeight, topInset: topInset)
                    }
                }
                .padding(.horizontal, hPad)
                .padding(.top, safeAreaTop + collapsedHeaderHeight + 20)
                .padding(.bottom, footerClearance)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollClipDisabled(true)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { oldOffset, newOffset in
                if abs(newOffset - towerScrollOffset) > 8 {
                    towerScrollOffset = newOffset
                }
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
    }

    @ViewBuilder
    private func skeletonGrid(colW: CGFloat, contentHeight: CGFloat) -> some View {
        let skeletons = towerVM.skeletonLayout()
        ForEach(skeletons.prefix(visibleSkeletonCount)) { skel in
            let f = GridConstants.blockFrame(
                column: skel.column, row: skel.row,
                columnSpan: skel.columnSpan, rowSpan: skel.rowSpan,
                cellSize: colW
            )
            SkeletonBlockView(width: f.width, height: f.height)
                .offset(x: f.minX, y: contentHeight - f.maxY)
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.3, anchor: .bottom).combined(with: .opacity),
                        removal: .opacity
                    )
                )
        }
    }

    @ViewBuilder
    private func placedBlocksGrid(colW: CGFloat, contentHeight: CGFloat,
                                   viewportHeight: CGFloat, topInset: CGFloat) -> some View {
        let visibleBlocks = visibleTowerBlocks(
            colW: colW, gridH: contentHeight,
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
            let stagger = towerVM.staggerDelay(for: block)

            animatedBlock(block: block, frame: f, phase: phase, isNew: isNew,
                         gridH: contentHeight, safeAreaTop: safeAreaTop)
                .id(block.id)
                .offset(x: f.minX, y: contentHeight - f.maxY)
                .zIndex(isAnimating ? 100 : Double(block.row + 1))
                .transition(.opacity.animation(.easeOut(duration: 0.2).delay(stagger)))
        }
    }

    // MARK: - Visible Block Culling

    private func visibleTowerBlocks(
        colW: CGFloat, gridH: CGFloat,
        viewportHeight: CGFloat, topInset: CGFloat
    ) -> [PlacedBlock] {
        let blocks = towerVM.placedBlocks
        // For small towers, render everything
        guard blocks.count > 40 else { return blocks }

        let cellStride = colW + spacing
        guard cellStride > 0 else { return blocks }

        // Visible content range in grid coordinates
        let visibleTop = towerScrollOffset - topInset - 200 // buffer
        let visibleBottom = towerScrollOffset + viewportHeight + 200

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
        let rippleScaleX: CGFloat = isRippling ? 1.0 + 0.030 * ri : 1.0
        let rippleScaleY: CGFloat = isRippling ? 1.0 - 0.050 * ri : 1.0
        let rippleOffsetY: CGFloat = isRippling ? 2.5 * ri : 0

        return ZStack {
            if isNew {
                ghostSlot(width: f.width, height: f.height)
            }

            completedBlock(block: block, frame: f)
                .scaleEffect(x: impactScaleX, y: impactScaleY, anchor: .bottom)
                .rotation3DEffect(.degrees(wobbleDegrees), axis: (x: 0, y: 0, z: 1))
                .brightness(flashBrightness)
                .shadow(
                    color: phase != nil ? .black.opacity(GridConstants.adaptiveShadowOpacity(0.12, colorScheme: colorScheme)) : .clear,
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

                    if block.log.imageFileName != nil {
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
            if block.log.imageFileName != nil && !isExpanded {
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

    // MARK: - Debug Block Injection (temporary)

    #if DEBUG
    private func removeLastDebugBlock() {
        guard let lastLog = logs.filter({ $0.completed })
            .sorted(by: { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) })
            .last else { return }
        if let fileName = lastLog.imageFileName {
            ImageManager.shared.deleteImage(fileName: fileName)
        }
        if let habit = lastLog.habit {
            modelContext.delete(habit)
        }
        modelContext.delete(lastLog)
        try? modelContext.save()
        refreshData()
    }

    private func injectDebugBlock() {
        let sizes: [BlockSize] = [.small, .medium, .hard]
        let categories: [HabitCategory] = HabitCategory.allCases
        let namesByCategory: [HabitCategory: [String]] = [
            .health:      ["Morning Run", "Drink Water", "Stretch", "Gym", "Walk 10k Steps", "Sleep by 11"],
            .work:        ["Deep Work", "Clear Inbox", "Stand-Up", "Code Review", "Ship Feature", "Write Docs"],
            .creativity:  ["Sketch", "Write 500 Words", "Play Guitar", "Photography", "Design Sprint", "Journaling"],
            .focus:       ["Read 30 Min", "No Phone Hour", "Pomodoro x4", "Study Session", "Meditate", "Plan Tomorrow"],
            .social:      ["Call a Friend", "Family Dinner", "Coffee Chat", "Send Thank You", "Team Lunch", "Game Night"],
            .mindfulness: ["Meditate", "Breathwork", "Gratitude Log", "Body Scan", "Yoga", "Nature Walk"]
        ]
        let category = categories.randomElement()!
        let title = namesByCategory[category]!.randomElement()!
        let habit = Habit(
            title: title,
            category: category,
            blockSize: sizes.randomElement()!,
            frequency: [],
            scheduledTime: nil
        )
        habit.tower = towerManager.activeTower
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
        for log in logs {
            if let fileName = log.imageFileName {
                ImageManager.shared.deleteImage(fileName: fileName)
            }
            modelContext.delete(log)
        }
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
            block.log.dateString == dateStr && block.log.imageFileName != nil
        }
    }
}

#Preview {
    MainAppView()
        .modelContainer(for: [Habit.self, HabitLog.self, MoodLog.self, Tower.self], inMemory: true)
        .environment(EventKitService())
        .environment(HealthKitService())
}
