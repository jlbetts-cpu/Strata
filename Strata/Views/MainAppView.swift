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
    @State private var towerFilterMode: TowerFilterMode = .day
    @State private var animCoord = TowerAnimationCoordinator()
    @State private var towerImpactScale: CGFloat = 1.0

    // Drop queue: habits completed in timeline, awaiting tower release
    @State private var pendingDrops: [Habit] = []

    // In-place block expansion
    @State private var expandedBlockID: UUID? = nil
    @Namespace private var blockExpansion

    // Block tap discovery hint
    @AppStorage("hasSeenBlockTapHint") private var hasSeenBlockTapHint = false
    @State private var showBlockTapHint = false
    @State private var hintBlockID: UUID? = nil

    // New habit menu
    @State private var isNewHabitMenuOpen: Bool = false
    @State private var newHabitPrefillTime: String? = nil

    // Skeleton build-up animation
    @State private var visibleSkeletonCount: Int = 0
    @State private var skeletonBuildTask: Task<Void, Never>?
    @State private var reloadTask: Task<Void, Never>?
    @State private var hintDismissTask: Task<Void, Never>?

    // Timer guard (Phase 1D)
    @State private var lastLogCount: Int = 0
    @State private var lastCompletionDate: Date? = nil
    @State private var refreshTask: Task<Void, Never>?

    // Cached timeline computed properties (Phase 2A/2B)
    @State private var cachedAllHabitsForSelectedDate: [Habit] = []
    @State private var cachedCompletedHabitIDsForSelectedDate: Set<UUID> = []
    @State private var cachedSkippedHabitIDsForSelectedDate: Set<UUID> = []
    @State private var cachedDailyPhotoBlocks: [PlacedBlock] = []
    @State private var cachedHabitPhotoBlocks: [PlacedBlock] = []

    // Timeline selected date (defaults to today)
    @State private var timelineSelectedDate: Date = Date()

    // Cached week completed dates
    @State private var weekCompletedDates: Set<String> = []

    // Cached incomplete timeline habits
    @State private var cachedIncompleteForTimeline: [Habit] = []

    // Cached computed properties
    @State private var cachedFilteredLogs: [HabitLog] = []
    @State private var cachedWeekData: [DayProgressData] = []
    @State private var perfectDayDates: Set<String> = []

    // Tower scroll
    @State private var isScrolled: Bool = false
    @State private var scrollToDropID: UUID? = nil
    @State private var scrollToTopTrigger = 0
    @State private var towerScrollOffset: CGFloat = 0
    @State private var screenHeight: CGFloat = 0
    @State private var currentColW: CGFloat = floor(
        (UIScreen.main.bounds.width - GridConstants.horizontalPadding * 2 - GridConstants.spacing * CGFloat(GridConstants.columnCount - 1))
        / CGFloat(GridConstants.columnCount)
    )
    @State private var safeAreaTop: CGFloat = 0
    @State private var safeAreaBottom: CGFloat = 0

    private let hPad: CGFloat = GridConstants.horizontalPadding
    private let spacing: CGFloat = GridConstants.spacing
    private let columns = GridConstants.columnCount
    private let cornerRadius: CGFloat = GridConstants.cornerRadius
    private let collapsedHeaderHeight: CGFloat = 0

    private var filteredLogs: [HabitLog] { cachedFilteredLogs }

    private func recomputeFilteredLogs(logsByDate: [String: [HabitLog]]) {
        let calendar = Calendar.current
        let now = Date()
        switch towerFilterMode {
        case .day:
            let todayStr = TimelineViewModel.dateString(from: now)
            cachedFilteredLogs = logsByDate[todayStr] ?? []
        case .week:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let weekStartStr = TimelineViewModel.dateString(from: startOfWeek)
            cachedFilteredLogs = logsByDate.flatMap { key, value in key >= weekStartStr ? value : [] }
        case .month:
            cachedFilteredLogs = Array(logs)
        }
        // Filter by active tower
        if let activeTowerID = towerManager.activeTower?.id {
            cachedFilteredLogs = cachedFilteredLogs.filter { $0.habit?.tower?.id == activeTowerID }
        }
    }

    @State private var showSettings = false

    var body: some View {
        mainContent
            .onAppear(perform: setup)
            .onChange(of: reduceMotion) { _, newValue in
                animCoord.reduceMotion = newValue
            }
            .onChange(of: habits.count) { guard !towerVM.isLoading else { return }; scheduleRefresh() }
            .onChange(of: towerFilterMode) {
                reloadTowerForFilterChange()
            }
            .onChange(of: expandedBlockID) {
                if let expandedID = expandedBlockID,
                   let block = towerVM.placedBlocks.first(where: { $0.id == expandedID }) {
                    cachedDailyPhotoBlocks = towerVM.placedBlocks.filter {
                        $0.log.dateString == block.log.dateString && $0.log.imageFileName != nil
                    }
                    // Journey filmstrip: same habit, any date, has photo, sorted recent-first
                    cachedHabitPhotoBlocks = towerVM.placedBlocks
                        .filter { $0.habit.id == block.habit.id && $0.log.imageFileName != nil }
                        .sorted { ($0.log.completedAt ?? .distantPast) > ($1.log.completedAt ?? .distantPast) }
                        .prefix(30)
                        .map { $0 }
                } else {
                    cachedDailyPhotoBlocks = []
                    cachedHabitPhotoBlocks = []
                }
            }
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
                guard !towerVM.isLoading else { return }
                let currentCount = logs.count
                // Only refresh if log count changed (avoids O(n) max scan on every tick)
                if currentCount != lastLogCount {
                    refreshData()
                }
            }
    }

    private var mainContent: some View {
        TabView(selection: $selectedTab) {
            Tab("Tower", systemImage: "square.stack.fill", value: StrataTab.tower) {
                NavigationStack {
                    towerTab
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .principal) {
                                Text(towerDateString)
                                    .font(.headline)
                            }
                            ToolbarItem(placement: .topBarLeading) {
                                TowerFilterMenuButton(selection: $towerFilterMode)
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    HapticsEngine.lightTap()
                                    showSettings = true
                                } label: {
                                    Image(systemName: "gearshape")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                }
                .sheet(isPresented: $showSettings) {
                    NavigationStack { SettingsView() }
                }
            }
            Tab("Today", systemImage: "calendar", value: StrataTab.today) {
                NavigationStack {
                    timelineTabContent
                        .navigationTitle("Today")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            Tab("Plan", systemImage: "list.bullet.clipboard", value: StrataTab.plan) {
                NavigationStack {
                    PlanPageView()
                        .environment(\.switchTab, { selectedTab = $0 })
                }
            }
            Tab("Insights", systemImage: "chart.bar", value: StrataTab.insights) {
                InsightsView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
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

    private func flippedY(for f: CGRect, gridH: CGFloat) -> CGFloat {
        gridH - f.minY - f.height
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

    private var towerDateString: String {
        Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private var todayCompletedCount: Int { timelineVM.completedToday.count }
    private var todayTotalCount: Int { timelineVM.todaysHabits.count }

    private func towerTabContent() -> some View {
        let colW = currentColW

        return towerContent(colW: colW, topInset: collapsedHeaderHeight,
                     safeAreaTop: safeAreaTop, safeAreaBottom: safeAreaBottom,
                     viewportHeight: screenHeight)
            .environment(\.towerFilterMode, towerFilterMode)
            .environment(\.perfectDayDates, perfectDayDates)
            #if DEBUG
            .overlay(alignment: .topLeading) {
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
                .padding(.top, 8)
                .padding(.leading, hPad)
            }
            #endif
            .overlay(alignment: .bottom) {
                if towerFilterMode == .day,
                   let nextHabit = incompleteForTimeline.first {
                    TowerNextUpPill(
                        habitTitle: nextHabit.title,
                        category: nextHabit.category,
                        onTap: {
                            HapticsEngine.lightTap()
                            selectedTab = .today
                        }
                    )
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(GridConstants.gentleReveal, value: incompleteForTimeline.first?.id)
                }
            }
            .background { WarmBackground().ignoresSafeArea() }
            .overlay {
                if let expandedID = expandedBlockID,
                   let block = towerVM.placedBlocks.first(where: { $0.id == expandedID }) {
                    // Blur scrim
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .onTapGesture { dismissCard() }
                        .transition(.opacity)
                        .accessibilityHidden(true)

                    // Floating card
                    BlockExpansionCard(
                        block: block,
                        dailyPhotoBlocks: cachedDailyPhotoBlocks,
                        habitPhotoBlocks: cachedHabitPhotoBlocks,
                        namespace: blockExpansion,
                        modelContext: modelContext,
                        onDismiss: { dismissCard() }
                    )
                }
            }
    }

    // MARK: - Timeline Tab

    private var timelineTabContent: some View {
        ScheduleTimelineView(
            weekData: weekData,
            selectedDate: $timelineSelectedDate,
            allHabits: cachedAllHabitsForSelectedDate,
            completedHabitIDs: cachedCompletedHabitIDsForSelectedDate,
            skippedHabitIDs: cachedSkippedHabitIDsForSelectedDate,
            isViewingToday: Calendar.current.isDateInToday(timelineSelectedDate),
            isViewingPast: !Calendar.current.isDateInToday(timelineSelectedDate) && timelineSelectedDate < Date(),
            onComplete: { habit in
                pendingDrops.append(habit)
            },
            onSkip: { habit in
                timelineVM.skipHabit(habit)
                scheduleRefresh()
            },
            onUndo: { habit in
                timelineVM.undoCompletion(habit)
                scheduleRefresh()
            },
            onUndoSkip: { habit in
                timelineVM.undoSkip(habit)
                scheduleRefresh()
            },
            onAddHabit: { prefillTime in
                newHabitPrefillTime = prefillTime
                isNewHabitMenuOpen = true
            },
            onEditInPlan: { _ in
                selectedTab = .plan
            },
            towerBlockCount: towerVM.placedBlocks.count,
            debugTower: towerManager.activeTower
        )
        .onChange(of: timelineSelectedDate) {
            scheduleRefresh()
        }
    }

    private func recomputeTimelineHabits(logsByDate: [String: [HabitLog]]) {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(timelineSelectedDate)
        let dateStr = TimelineViewModel.dateString(from: timelineSelectedDate)

        // Completed + skipped IDs — O(1) lookup then small-array filter
        let dateLogs = logsByDate[dateStr] ?? []
        cachedCompletedHabitIDsForSelectedDate = Set(dateLogs.filter { $0.completed }.compactMap { $0.habit?.id })
        cachedSkippedHabitIDsForSelectedDate = Set(dateLogs.filter { $0.skipped }.compactMap { $0.habit?.id })

        if isToday {
            cachedAllHabitsForSelectedDate = timelineVM.todaysHabits
                .filter { $0.tower?.id == towerManager.activeTower?.id }
                .sorted { (TimelineViewModel.effectiveHour(for: $0) ?? 0) < (TimelineViewModel.effectiveHour(for: $1) ?? 0) }
            return
        }

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
            cachedAllHabitsForSelectedDate = scheduled.sorted {
                (TimelineViewModel.effectiveHour(for: $0) ?? 0) < (TimelineViewModel.effectiveHour(for: $1) ?? 0)
            }
        } else {
            cachedAllHabitsForSelectedDate = scheduled.filter { !cachedCompletedHabitIDsForSelectedDate.contains($0.id) }
                .sorted { (TimelineViewModel.effectiveHour(for: $0) ?? 0) < (TimelineViewModel.effectiveHour(for: $1) ?? 0) }
        }
    }

    private static let dateStringFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Week Progress Data

    private var weekData: [DayProgressData] { cachedWeekData }

    private func recomputeWeekData() {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let weekDates = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
        let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

        // Single pass: group logs by dateString for counts + per-habit status
        var completedByDate: [String: Int] = [:]
        var skippedByDate: [String: Int] = [:]
        var completedIDsByDate: [String: Set<UUID>] = [:]
        var skippedIDsByDate: [String: Set<UUID>] = [:]
        for log in logs {
            if log.completed {
                completedByDate[log.dateString, default: 0] += 1
                if let hid = log.habit?.id { completedIDsByDate[log.dateString, default: []].insert(hid) }
            }
            if log.skipped {
                skippedByDate[log.dateString, default: 0] += 1
                if let hid = log.habit?.id { skippedIDsByDate[log.dateString, default: []].insert(hid) }
            }
        }

        // Single pass: group habits by DayCode + date for todos
        let towerHabits = habits.filter { $0.tower?.id == towerManager.activeTower?.id }
        var habitsByDayCode: [DayCode: [Habit]] = [:]
        var todosByDate: [String: [Habit]] = [:]
        for habit in towerHabits {
            if habit.isTodo {
                if let d = habit.scheduledDate { todosByDate[d, default: []].append(habit) }
            } else {
                for code in habit.frequency { habitsByDayCode[code, default: []].append(habit) }
            }
        }

        cachedWeekData = weekDates.enumerated().map { index, date in
            let dayNum = calendar.component(.day, from: date)
            let isToday = calendar.isDateInToday(date)
            let isFuture = date > Date() && !isToday
            let dateStr = TimelineViewModel.dateString(from: date)
            let weekday = calendar.component(.weekday, from: date)
            let dayCode = DayCode.from(weekday: weekday)

            // Per-day habit list for Week Matrix
            let dayHabits = (habitsByDayCode[dayCode] ?? []) + (todosByDate[dateStr] ?? [])
            let completedIDs = completedIDsByDate[dateStr] ?? []
            let skippedIDs = skippedIDsByDate[dateStr] ?? []

            let habitSummaries = dayHabits.map { habit in
                HabitSummary(
                    id: habit.id,
                    category: habit.category,
                    isCompleted: completedIDs.contains(habit.id),
                    isSkipped: skippedIDs.contains(habit.id),
                    effectiveHour: TimelineViewModel.effectiveHour(for: habit)
                )
            }.sorted { ($0.effectiveHour ?? 24) < ($1.effectiveHour ?? 24) }

            let total = dayHabits.count
            let completed = completedByDate[dateStr] ?? 0
            let skipped = skippedByDate[dateStr] ?? 0
            let rate = total > 0 ? Double(completed) / Double(total) : 0

            return DayProgressData(
                date: date,
                dayLabel: dayLabels[index],
                dayNumber: dayNum,
                completionRate: rate,
                completedCount: completed,
                skippedCount: skipped,
                totalCount: total,
                isToday: isToday,
                isFuture: isFuture,
                habits: habitSummaries
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
        // Skeleton pop-in — bouncier than gentleReveal for playful stagger effect
        withAnimation(GridConstants.skeletonPop) {
            visibleSkeletonCount = 1
        }
        skeletonBuildTask = Task { @MainActor in
            for i in 2...8 {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
                withAnimation(GridConstants.skeletonPop) {
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
            _ = withAnimation(GridConstants.layoutReflow) {
                refreshData()
            }
            let elapsed = ContinuousClock.now - loadStart
            let remaining = max(.zero, .milliseconds(300) - elapsed)
            try? await Task.sleep(for: remaining)
            guard !Task.isCancelled else { return }
            stopSkeletonBuildUp()
        }
    }

    /// Lightweight reload for filter changes — cross-dissolve, no skeleton
    private func reloadTowerForFilterChange() {
        HapticsEngine.lightTap()
        _ = withAnimation(GridConstants.layoutReflow) {
            refreshData()
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
                withAnimation(GridConstants.naturalSettle) {
                    towerImpactScale = 1.0
                }
            }
        }
        startSkeletonBuildUp()
        Task {
            let loadStart = ContinuousClock.now
            // Migrate existing imageData blobs to file system
            await ImageMigrationRunner.migrateIfNeeded(context: modelContext)
            _ = withAnimation(GridConstants.layoutReflow) {
                refreshData()
            }
            let elapsed = ContinuousClock.now - loadStart
            let remaining = max(.zero, .milliseconds(300) - elapsed)
            try? await Task.sleep(for: remaining)
            stopSkeletonBuildUp()

            // Block tap discovery hint for existing users
            if !hasSeenBlockTapHint && !towerVM.placedBlocks.isEmpty {
                hintBlockID = towerVM.placedBlocks.last?.id
                try? await Task.sleep(for: .seconds(1.0))
                withAnimation(GridConstants.gentleReveal) { showBlockTapHint = true }
                hasSeenBlockTapHint = true
                hintDismissTask = Task {
                    try? await Task.sleep(for: .seconds(3.0))
                    withAnimation(GridConstants.crossFade) { showBlockTapHint = false; hintBlockID = nil }
                }
            }
        }
    }

    private func recomputePerfectDayDates() {
        let calendar = Calendar.current
        let towerHabits = habits.filter { $0.tower?.id == towerManager.activeTower?.id }

        var completedByDate: [String: Int] = [:]
        for log in cachedFilteredLogs where log.completed {
            completedByDate[log.dateString, default: 0] += 1
        }

        var result: Set<String> = []
        for (dateStr, completedCount) in completedByDate {
            if let date = Self.dateStringFormatter.date(from: dateStr) {
                let weekday = calendar.component(.weekday, from: date)
                let dayCode = DayCode.from(weekday: weekday)
                let scheduledCount = towerHabits.filter { habit in
                    if habit.isTodo { return habit.scheduledDate == dateStr }
                    return habit.frequency.contains(dayCode)
                }.count
                if scheduledCount > 0 && completedCount >= scheduledCount {
                    result.insert(dateStr)
                }
            }
        }
        perfectDayDates = result
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(16))
            guard !Task.isCancelled else { return }
            refreshData()
        }
    }

    @discardableResult
    private func refreshData() -> Set<UUID> {
        // Single-pass log index — O(n) once, then O(1) lookups downstream
        var logsByDate: [String: [HabitLog]] = [:]
        var allCompletedDateStrings: Set<String> = []
        var maxCompletedAt: Date? = nil
        for log in logs {
            logsByDate[log.dateString, default: []].append(log)
            if log.completed {
                allCompletedDateStrings.insert(log.dateString)
                if let at = log.completedAt, (maxCompletedAt == nil || at > maxCompletedAt!) {
                    maxCompletedAt = at
                }
            }
        }

        recomputeFilteredLogs(logsByDate: logsByDate)
        recomputeWeekData()
        recomputePerfectDayDates()
        let towerHabits = habits.filter { $0.tower?.id == towerManager.activeTower?.id }
        timelineVM.loadToday(habits: towerHabits, logs: logs)
        recomputeTimelineHabits(logsByDate: logsByDate)
        let droppedIDs: Set<UUID> = withAnimation(GridConstants.heavySettle) {
            towerVM.buildTower(from: filteredLogs)
        }
        weekCompletedDates = allCompletedDateStrings
        recomputeIncompleteTimeline()

        // Update timer guard values from index (avoid redundant O(n) scan)
        lastLogCount = logs.count
        lastCompletionDate = maxCompletedAt

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

        // Block tap discovery hint (one-time, after first drop)
        if !hasSeenBlockTapHint && !habits.isEmpty {
            hintBlockID = towerVM.placedBlocks.last?.id
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(GridConstants.gentleReveal) { showBlockTapHint = true }
            hasSeenBlockTapHint = true
            hintDismissTask = Task {
                try? await Task.sleep(for: .seconds(3.0))
                withAnimation(GridConstants.crossFade) { showBlockTapHint = false; hintBlockID = nil }
            }
        }
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
        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // Top anchor for FAB scroll
                    Color.clear.frame(height: 1)
                        .id("TowerTop")

                    Color.clear
                        .frame(width: gridW, height: max(gridH, 1))

                    if towerVM.isLoading {
                        skeletonGrid(colW: colW, gridH: gridH)
                    } else if towerVM.totalRows == 0 {
                        // Ghost tower empty state
                        ghostTowerEmptyState(colW: colW, gridH: gridH)
                    } else {
                        // Ground plane at tower foundation
                        towerGroundPlane(gridW: gridW, gridH: gridH)

                        placedBlocksGrid(colW: colW, gridH: gridH,
                                         viewportHeight: viewportHeight, topInset: topInset)

                        // Block count below ground plane (building foundation label)
                        if towerVM.placedBlocks.count > 0 {
                            Text("\(towerVM.placedBlocks.count) blocks")
                                .font(Typography.caption)
                                .foregroundStyle(.primary.opacity(0.3))
                                .contentTransition(.numericText())
                                .frame(width: gridW, alignment: .center)
                                .offset(y: gridH + 16)
                        }
                    }
                }
                .scaleEffect(y: towerImpactScale, anchor: .bottom)
                .padding(.horizontal, hPad)
                .padding(.bottom, 8)
                .frame(
                    minHeight: viewportHeight - safeAreaTop,
                    alignment: .bottom
                )
            }
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
                withAnimation(GridConstants.heavySettle) {
                    proxy.scrollTo("TowerTop", anchor: .top)
                }
            }
        }
    }

    @ViewBuilder
    private func skeletonGrid(colW: CGFloat, gridH: CGFloat) -> some View {
        let skeletons = towerVM.skeletonLayout()
        ZStack(alignment: .topLeading) {
        ForEach(skeletons.prefix(visibleSkeletonCount)) { skel in
            let f = GridConstants.blockFrame(
                column: skel.column, row: skel.row,
                columnSpan: skel.columnSpan, rowSpan: skel.rowSpan,
                cellSize: colW
            )
            SkeletonBlockView(width: f.width, height: f.height)
                .offset(x: f.minX, y: flippedY(for: f, gridH: gridH))
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.3, anchor: .bottom).combined(with: .opacity),
                        removal: .opacity
                    )
                )
        }
        }
    }

    @ViewBuilder
    private func placedBlocksGrid(colW: CGFloat, gridH: CGFloat,
                                   viewportHeight: CGFloat, topInset: CGFloat) -> some View {
        let visibleBlocks = visibleTowerBlocks(
            colW: colW, gridH: gridH,
            viewportHeight: viewportHeight, topInset: topInset
        )
        ZStack(alignment: .topLeading) {
            blockForEach(visibleBlocks: visibleBlocks, colW: colW, gridH: gridH)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tower grid, \(towerVM.placedBlocks.count) blocks")
    }

    @ViewBuilder
    private func blockForEach(visibleBlocks: [PlacedBlock], colW: CGFloat,
                               gridH: CGFloat) -> some View {
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
                         gridH: gridH, safeAreaTop: safeAreaTop)
                .frame(width: f.width, height: f.height)
                .id(block.id)
                .offset(x: f.minX, y: flippedY(for: f, gridH: gridH))
                .zIndex(isAnimating ? 100 : Double(block.row + 1))
                .accessibilitySortPriority(-Double(block.row))
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
        guard blocks.count > 30 else { return blocks }

        let cellStride = colW + spacing
        guard cellStride > 0 else { return blocks }

        // Visible content range in grid coordinates
        let visibleTop = towerScrollOffset - topInset - 150 // buffer
        let visibleBottom = towerScrollOffset + viewportHeight + 150

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

    // MARK: - Tower Ground Plane

    private func towerGroundPlane(gridW: CGFloat, gridH: CGFloat) -> some View {
        // Momentum Ground Glow — warms toward green as daily completions accumulate
        // Research: Goal Gradient Effect (Hull 1932, Kivetz 2006)
        let warmth = min(1.0, Double(todayCompletedCount) / Double(max(todayTotalCount, 1)))
        let neutralColor = colorScheme == .dark ? Color.primary.opacity(0.08) : AppColors.warmBlack.opacity(0.15)
        let glowColor = AppColors.healthGreen.opacity(warmth * 0.35)

        return ZStack {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: neutralColor, location: 0.3),
                    .init(color: neutralColor, location: 0.7),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: gridW, height: 3)

            // Green warmth overlay — blends in as completions increase
            if warmth > 0 {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: glowColor, location: 0.25),
                        .init(color: glowColor, location: 0.75),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: gridW, height: 3)
                .blur(radius: 5)
                .animation(GridConstants.progressFill, value: warmth)
            }
        }
        .shadow(
            color: colorScheme == .dark ? Color.primary.opacity(0.06) : AppColors.warmBlack.opacity(0.12),
            radius: 4, x: 0, y: 2
        )
        .offset(y: gridH)
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

    // MARK: - Ghost Tower Empty State

    @ViewBuilder
    private func ghostTowerEmptyState(colW: CGFloat, gridH: CGFloat) -> some View {
        let ghosts = towerVM.skeletonLayout(blockCount: 5)
        ForEach(ghosts) { skel in
            let f = GridConstants.blockFrame(
                column: skel.column, row: skel.row,
                columnSpan: skel.columnSpan, rowSpan: skel.rowSpan,
                cellSize: colW
            )
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
                .frame(width: f.width, height: f.height)
                .offset(x: f.minX, y: flippedY(for: f, gridH: gridH))
        }

        VStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: GridConstants.iconEmptyState, weight: .light))
                .foregroundStyle(.primary.opacity(0.25))
            Text("Your tower starts here")
                .font(Typography.headerMedium)
                .foregroundStyle(.primary.opacity(0.6))
            Text("Complete a habit on the Today tab\nto place your first block")
                .font(Typography.bodySmall)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    }

    // MARK: - Live Completed Block

    private func completedBlock(block: PlacedBlock, frame: CGRect) -> some View {
        let isExpanded = expandedBlockID == block.id

        return FlippableBlockView(
            block: block,
            width: frame.width,
            height: frame.height,
            cornerRadius: cornerRadius,
            modelContext: modelContext,
            onTap: {
                if !isExpanded {
                    withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.heavySettle) {
                        expandedBlockID = block.id
                    }
                }
            }
        )
        .matchedGeometryEffect(id: block.id, in: blockExpansion)
        .opacity(isExpanded ? 0 : 1)
        .overlay {
            if showBlockTapHint && hintBlockID == block.id {
                Text("Tap to explore")
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    .allowsHitTesting(false)
            }
        }
    }

    private func dismissCard() {
        HapticsEngine.tick()
        try? modelContext.save()
        withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.heavySettle) {
            expandedBlockID = nil
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

}

#Preview {
    MainAppView()
        .modelContainer(for: [Habit.self, HabitLog.self, MoodLog.self, Tower.self], inMemory: true)
        .environment(EventKitService())
        .environment(HealthKitService())
}
