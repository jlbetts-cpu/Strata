import SwiftUI
import SwiftData
import Combine
import CoreSpotlight

// MARK: - Tab Bar Collapse (iOS 26+ availability guard)
private struct TabBarCollapseModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
    }
}

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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(HealthKitService.self) private var healthKitService
    @Environment(EventKitService.self) private var eventKitService
    @Environment(FocusFilterService.self) private var focusFilterService
    @State private var towerVM = TowerViewModel()
    @State private var timelineVM = TimelineViewModel()
    @State private var habitManagerVM = HabitManagerViewModel()
    @State private var towerManager = TowerManager()
    @State private var hasLoadedDemo = false
    @State private var selectedTab: StrataTab = .tower
    // #270: Tower filter persistence across launches
    @AppStorage("towerFilterMode") private var towerFilterMode: TowerFilterMode = .week
    @State private var pendingTowerFilterMode: TowerFilterMode? = nil
    @State private var animCoord = TowerAnimationCoordinator()
    @State private var towerImpactScale: CGFloat = 1.0
    @State private var motionCoord = DeviceMotionCoordinator()

    // Drop queue: habits completed in timeline, awaiting tower release
    @State private var pendingDrops: [Habit] = []

    // Block flyaway bridge (Today → Tower visual connection)
    @State private var flyawayActive: Bool = false
    @State private var flyawayCategory: HabitCategory? = nil
    @State private var flyawayLanded: Bool = false

    // In-place block expansion
    @State private var expandedBlockID: UUID? = nil
    @Namespace private var blockExpansion

    // Onboarding
    @StateObject private var onboarding = OnboardingState()

    // #109: Comeback celebration
    @AppStorage("lastCompletionDateString") private var lastCompletionDateString: String = ""
    @State private var showComebackBanner = false

    // #386: Perfect day anticipation
    @State private var showPerfectDayAnticipation = false

    // Block tap discovery hint (legacy — replaced by onboarding.hasSeenFirstBlockHint)
    @AppStorage("hasSeenBlockTapHint") private var hasSeenBlockTapHint = false
    @State private var showBlockTapHint = false
    @State private var hintBlockID: UUID? = nil

    // First block magic (Phase 5 — Murdock 1962 primacy effect)
    @AppStorage("hasSeenFirstDrop") private var hasSeenFirstDrop = false
    @AppStorage("hasSeenHealthKitVerification") private var hasSeenHealthKitVerification = false
    @AppStorage("lastDayBoundaryCheck") private var lastDayBoundaryCheck: String = ""
    @State private var showFirstBlockLabel = false

    // Tower Aurora (Phase 5 — Skinner 1938 variable reward)
    @AppStorage("lastAuroraWeek") private var lastAuroraWeek: Int = 0
    @State private var showAurora = false
    @State private var showTowerConfetti = false
    @AppStorage("lastCelebrationDate") private var lastCelebrationDate: String = ""

    // #84-86: Milestone system
    @State private var milestoneStore = MilestoneStore.load()
    @State private var pendingMilestone: Milestone? = nil

    // New habit menu
    @State private var isNewHabitMenuOpen: Bool = false
    @State private var newHabitPrefillTime: String? = nil

    // Skeleton build-up animation
    @State private var visibleSkeletonCount: Int = 0
    @State private var skeletonBuildTask: Task<Void, Never>?
    @State private var reloadTask: Task<Void, Never>?
    @State private var hintDismissTask: Task<Void, Never>?

    // Setup guard
    @State private var hasSetUp = false

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
    @State private var cachedStreaks: [UUID: Int] = [:]

    // Deep link from Spotlight
    @State private var deepLinkHabitID: UUID? = nil

    // Spotlight indexing debounce
    @State private var spotlightIndexTask: Task<Void, Never>?
    @State private var lastIndexedHabitCount: Int = 0

    // Tower scroll
    @State private var isScrolled: Bool = false
    @State private var scrollToDropID: UUID? = nil
    @State private var scrollToTopTrigger = 0
    @State private var towerScrollOffset: CGFloat = 0
    @State private var screenHeight: CGFloat = 0
    @State private var currentColW: CGFloat = 82 // Default for iPhone 15 Pro — geometryTracker recalculates on appear
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

    /// Set by `-strataOpenSheet block`: expand the first block once the tower
    /// has finished building, since a block card is only reachable by tapping.
    /// Always present, only ever set in DEBUG — a `#if` around a @State that
    /// something in `body` binds to costs more than the property does.
    @State private var wantsDebugExpand = false
    @State private var debugAutoWinsLeft = 0
    @State private var waterImpacts: [TowerReflection.Impact] = []
    @State private var winSaveFailed = false
    @State private var showSettings = false
    @State private var showDataFallbackAlert = SharedModelContainer.isUsingInMemoryFallback

    var body: some View {
        mainContent
            .onAppear(perform: setup)
            .onChange(of: reduceMotion) { _, newValue in
                animCoord.reduceMotion = newValue
            }
            .modifier(DebugAutoWin(
                blockCount: towerVM.placedBlocks.count,
                remaining: $debugAutoWinsLeft,
                fire: { logWin() }
            ))
            .modifier(DebugExpandFirstBlock(
                blockCount: towerVM.placedBlocks.count,
                firstBlockID: towerVM.placedBlocks.first?.id,
                wants: $wantsDebugExpand,
                expanded: $expandedBlockID
            ))
            // Not while a drop is queued. Inserting the habit changes
            // habits.count, which used to refresh the tower immediately — so
            // the block appeared in its final place, then vanished when the
            // cascade started it from above, then fell. That is the flash.
            // The cascade does its own refresh; this one only exists for
            // changes that arrive from elsewhere.
            .onChange(of: habits.count) {
                guard !towerVM.isLoading, pendingDrops.isEmpty else { return }
                scheduleRefresh()
            }
            .onChange(of: towerFilterMode) {
                cachedTowerTitle = computeTowerTitle()
                animCoord.clearAnimationStates() // #430: Clear stale animation on filter change
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
                guard scenePhase == .active else { return }
                // Celebration guard removed — now uses date-based @AppStorage instead of timer reset
                guard !towerVM.isLoading else { return }
                let currentCount = logs.count
                // Only refresh if log count changed (avoids O(n) max scan on every tick)
                if currentCount != lastLogCount {
                    refreshData()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    // Belt and suspenders: refresh HealthKit on every foreground
                    healthKitService.refreshProgress()
                    healthKitService.evaluateThresholds()
                    healthKitService.startForegroundPolling()

                    // Refresh calendar events for selected date
                    eventKitService.fetchEvents(for: timelineSelectedDate)

                    // Day-boundary auto-complete: silently complete unacknowledged verified habits from previous days
                    performDayBoundaryAutoComplete()

                    // Refresh Focus Filter state
                    focusFilterService.refresh()

                    // Reindex Spotlight to update completion status
                    SpotlightIndexer.reindex(container: SharedModelContainer.shared)
                } else if newPhase == .background {
                    healthKitService.stopForegroundPolling()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .healthKitHabitVerified)) { notification in
                guard let habitIDs = notification.userInfo?["habitIDs"] as? [UUID] else { return }
                HapticsEngine.lightTap()

                // First-ever flag — row handles celebration haptic now
                if !hasSeenHealthKitVerification {
                    hasSeenHealthKitVerification = true
                }

                scheduleRefresh()
            }
            .alert("Couldn't save that win", isPresented: $winSaveFailed) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Nothing was added. Try again.")
            }
            .fullScreenCover(isPresented: Binding(
                get: { !onboarding.hasSeenWelcome },
                set: { if !$0 { onboarding.hasSeenWelcome = true } }
            )) {
                WelcomeView {
                    onboarding.hasSeenWelcome = true
                    selectedTab = .tower
                }
            }
            .alert("Data Could Not Be Loaded", isPresented: $showDataFallbackAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your habits couldn't be loaded from storage. You can still use the app, but changes won't be saved between sessions. Try restarting the app — if the problem persists, use Settings → Export Data to save your information.")
            }
    }

    private var mainContent: some View {
        TabView(selection: $selectedTab) {
            Tab("Tower", systemImage: "square.stack.fill", value: StrataTab.tower) {
                NavigationStack {
                    towerTab
                        // No navigation bar at all. The filter said "Day" and
                        // the title said "Today" — the same fact twice, an inch
                        // apart, in two type styles. The tally below carries
                        // both, and the filter is a control inside it.
                        .toolbar(.hidden, for: .navigationBar)
                }
                .sheet(isPresented: $isNewHabitMenuOpen) {
                    NewHabitMenu(
                        isPresented: $isNewHabitMenuOpen,
                        modelContext: modelContext,
                        onCreated: { scheduleRefresh() },
                        prefillTime: newHabitPrefillTime,
                        tower: towerManager.activeTower
                    )
                }
            }
            .badge(pendingDrops.count)
            Tab("Today", systemImage: "calendar", value: StrataTab.today) {
                NavigationStack {
                    timelineTabContent
                        .environment(\.switchTab, { selectedTab = $0 })
                        // The date, not "Today": it changes as you move through
                        // the week, so it carries something the tab bar cannot.
                        .navigationTitle(timelineSelectedDate.formatted(.dateTime.month(.wide).day()))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { todayToolbar }
                }
            }
            Tab("Plan", systemImage: "list.bullet.clipboard", value: StrataTab.plan) {
                NavigationStack {
                    PlanPageView()
                        .environment(\.switchTab, { selectedTab = $0 })
                }
            }
            Tab("Insights", systemImage: "chart.bar", value: StrataTab.insights) {
                NavigationStack {
                    InsightsView(
                        habits: Array(habits),
                        logs: Array(logs),
                        onAddHabit: {
                            HapticsEngine.lightTap()
                            isNewHabitMenuOpen = true
                        },
                        onNavigateToTower: { filterMode in
                            pendingTowerFilterMode = filterMode
                            selectedTab = .tower
                        }
                    )
                    .environment(\.switchTab, { selectedTab = $0 })
                    .toolbar { insightsToolbar }
                }
                .sheet(isPresented: $showSettings) {
                    NavigationStack {
                        SettingsView(
                            onboarding: onboarding,
                            onResetAllData: { resetTower() }
                        )
                    }
                }
            }
        }
        .modifier(TabBarCollapseModifier())
        .onChange(of: selectedTab) { _, newTab in
            HapticsEngine.tick()
            // Apply pending filter from Insights → Tower navigation
            if newTab == .tower, let mode = pendingTowerFilterMode {
                towerFilterMode = mode
                pendingTowerFilterMode = nil
            }
            if newTab == .tower && !pendingDrops.isEmpty {
                Task { await cascadeDropPendingBlocks() }
            }
            if newTab != .today {
                timelineSelectedDate = Date()
            }
            // Device parallax — start on Tower, stop on leave
            if newTab == .tower && !reduceMotion {
                motionCoord.start()
            } else {
                motionCoord.stop()
            }
            // Tower Aurora check — async to not block tab transition
            if newTab == .tower && towerVM.totalRows > 0 {
                Task { @MainActor in
                    let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
                    let todayStr = TimelineViewModel.dateString(from: Date())
                    let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
                    let recentPerfectDays = perfectDayDates.filter { dateStr in
                        guard let date = Self.dateStringFormatter.date(from: dateStr) else { return false }
                        return date >= weekStart && dateStr <= todayStr
                    }.count
                    if recentPerfectDays >= 3 && lastAuroraWeek != currentWeek {
                        lastAuroraWeek = currentWeek
                        try? await Task.sleep(for: .milliseconds(500))
                        showAurora = true
                    }
                }
            }
        }
        .onChange(of: pendingDrops.count) { _, newCount in
            if newCount > 0 && selectedTab == .tower {
                Task { await cascadeDropPendingBlocks() }
            }
        }
        .onChange(of: towerManager.activeTower?.id) {
            reloadTowerWithAnimation()
        }
        // Block flyaway bridge — mini block flies from Today to Tower tab
        .overlay {
            if flyawayActive, let category = flyawayCategory {
                FlyawayBlockView(category: category, landed: $flyawayLanded)
                    .onChange(of: flyawayLanded) { _, landed in
                        if landed {
                            HapticsEngine.squish(mass: 1)
                            SoundEngine.blockImpact(mass: 1)
                            flyawayActive = false
                            flyawayLanded = false
                        }
                    }
                    .allowsHitTesting(false)
            }
        }
        // Spotlight deep link handler
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                  let habitID = UUID(uuidString: identifier) else { return }
            selectedTab = .today
            deepLinkHabitID = habitID
        }
    }

    // MARK: - Main Content

    private var towerTab: some View {
        towerTabContent()
            .background { geometryTracker }
            // Pinned to the page, not to the tower. The tally used to sit under
            // the bottom row, which meant it moved every time the tower grew
            // and put a caption between the tower and the tab bar. Here it is
            // always in the same place, and the tower has nothing beneath it
            // but its own reflection.
            .safeAreaInset(edge: .top, spacing: 0) { towerHeader }
    }

    /// The whole header: what the tower is, and what it is showing.
    ///
    /// This replaces a navigation bar plus a separate tally. There were four
    /// text elements across the top of the page and two of them said the same
    /// thing — a "Day" filter beside a "Today" title. Now there is one block of
    /// information on the left and one control on the right, and the period
    /// appears once, as the subject of the sentence the numbers are making.
    private var towerHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(towerVM.placedBlocks.count)")
                        .font(.system(size: 40, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.85))
                        .contentTransition(.numericText())
                    Text(towerVM.placedBlocks.count == 1 ? "block" : "blocks")
                        .font(Typography.bodyMedium)
                        .foregroundStyle(.primary.opacity(0.35))
                }
                Text(tallyDetail)
                    .font(Typography.bodySmall)
                    .foregroundStyle(.primary.opacity(0.3))
                    .contentTransition(.numericText())
            }
            .animation(GridConstants.motionSmooth, value: towerVM.placedBlocks.count)
            .accessibilityElement(children: .combine)

            Spacer(minLength: 12)

            TowerFilterMenuButton(selection: $towerFilterMode)
                .padding(.top, 6)
        }
        .padding(.horizontal, hPad)
        .padding(.top, 4)
    }

    /// The period, the height, and today — in that order, because the period is
    /// what the big number is counting and the rest qualifies it.
    private var tallyDetail: String {
        var parts = [cachedTowerTitle]
        let metres = Int(towerVM.altimeterHeight)
        if metres > 0 { parts.append("\(metres)m") }
        // Not while the filter is already showing only today — the big number
        // IS today's count then, and "Today · 6m · 6 today" says it twice.
        if towerFilterMode != .day, blocksToday > 0 {
            parts.append("\(blocksToday) today")
        }
        return parts.joined(separator: " · ")
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

    @State private var cachedTowerTitle: String = ""

    private func computeTowerTitle() -> String {
        switch towerFilterMode {
        case .day:
            return "Today"
        case .week, .month:
            let dateStrings = cachedFilteredLogs.map(\.dateString)
            guard let earliestStr = dateStrings.min(), let latestStr = dateStrings.max() else {
                return towerFilterMode == .week ? "This Week" : Date().formatted(.dateTime.month(.wide))
            }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            guard let earliest = formatter.date(from: earliestStr),
                  let latest = formatter.date(from: latestStr) else {
                return towerFilterMode == .week ? "This Week" : Date().formatted(.dateTime.month(.wide))
            }
            let cal = Calendar.current
            if cal.isDate(earliest, inSameDayAs: latest) {
                return earliest.formatted(.dateTime.month(.wide).day())
            } else {
                let startStr = earliest.formatted(.dateTime.month(.abbreviated).day())
                let endStr = latest.formatted(.dateTime.month(.abbreviated).day())
                return "\(startStr) – \(endStr)"
            }
        }
    }

    private func updateVisibleDateTitle() {
        guard towerFilterMode != .day else { return }
        let blocks = towerVM.placedBlocks
        guard !blocks.isEmpty else { return }

        let colW = currentColW
        let cellStride = colW + spacing
        guard cellStride > 0 else { return }

        let rowCount = towerVM.totalRows
        let gridH = rowCount > 0
            ? CGFloat(rowCount) * colW + CGFloat(rowCount - 1) * spacing
            : 0

        let visibleTop = towerScrollOffset - collapsedHeaderHeight - 150
        let visibleBottom = towerScrollOffset + screenHeight + 150

        let visibleDateStrings: Set<String> = blocks.reduce(into: []) { result, block in
            let blockY = gridH - CGFloat(block.row + block.rowSpan) * cellStride
            let blockBottom = gridH - CGFloat(block.row) * cellStride
            if blockBottom >= visibleTop && blockY <= visibleBottom {
                result.insert(block.log.dateString)
            }
        }

        guard !visibleDateStrings.isEmpty else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dates = visibleDateStrings.compactMap { formatter.date(from: $0) }.sorted()
        guard let earliest = dates.first, let latest = dates.last else { return }

        let newTitle: String
        if Calendar.current.isDate(earliest, inSameDayAs: latest) {
            newTitle = earliest.formatted(.dateTime.month(.wide).day())
        } else {
            let startStr = earliest.formatted(.dateTime.month(.abbreviated).day())
            let endStr = latest.formatted(.dateTime.month(.abbreviated).day())
            newTitle = "\(startStr) – \(endStr)"
        }

        if newTitle != cachedTowerTitle {
            cachedTowerTitle = newTitle
        }
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
            .overlay(alignment: .bottom) {
                VStack(spacing: 8) {
                    // #386: Perfect day anticipation — "One more for a perfect day..."
                    if showPerfectDayAnticipation && towerFilterMode == .day {
                        Text("One more for a perfect day...")
                            .font(Typography.caption)
                            .foregroundStyle(.primary.opacity(0.5))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // #109: Comeback celebration banner
                    if showComebackBanner {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.wave.fill")
                                .foregroundStyle(AppColors.accentPurple)
                            Text("Welcome back! This block matters.")
                                .font(Typography.bodySmall)
                                .foregroundStyle(.primary.opacity(0.7))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

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
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(GridConstants.gentleReveal, value: incompleteForTimeline.first?.id)
                    }
                }
                .padding(.bottom, 16)
            }
            .background { WarmBackground().ignoresSafeArea() }
            .overlay {
                if let expandedID = expandedBlockID,
                   let block = towerVM.placedBlocks.first(where: { $0.id == expandedID }) {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .onTapGesture { dismissCard() }
                        .transition(.opacity)
                        .accessibilityHidden(true)

                    // #86: Milestone celebration overlay
                    if let milestone = pendingMilestone {
                        MilestoneCelebration(milestone: milestone) {
                            pendingMilestone = nil
                        }
                        .transition(.opacity)
                        .zIndex(200)
                    }

                    // Floating card
                    BlockExpansionCard(
                        block: block,
                        dailyPhotoBlocks: cachedDailyPhotoBlocks,
                        namespace: blockExpansion,
                        modelContext: modelContext,
                        onDismiss: { dismissCard() },
                        onLayoutChanged: { reloadTowerWithAnimation() }
                    )
                    .onAppear { HapticsEngine.lightTap() }
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
                // Save completion IMMEDIATELY — don't defer to tower cascade
                timelineVM.completeHabit(habit)

                // Optimistic UI — update cached IDs before @Query fires (Set.insert is idempotent)
                cachedCompletedHabitIDsForSelectedDate.insert(habit.id)

                // Mark verifiedByHealthKit on the log if this was a HealthKit-verified habit
                if healthKitService.verifiedHabitIDs.contains(habit.id) {
                    let dateStr = TimelineViewModel.dateString(from: Date())
                    if let log = habit.logs.first(where: { $0.dateString == dateStr }) {
                        log.verifiedByHealthKit = true
                    }
                }
                flyawayCategory = habit.category
                if !reduceMotion { flyawayActive = true }
                pendingDrops.append(habit)

                // Donate to Siri for pattern learning
                let entity = HabitEntity(id: habit.id, title: habit.title, category: habit.category.rawValue, isCompletedToday: true)
                let intent = CompleteHabitIntent()
                intent.habit = entity
            },
            onSkip: { habit in
                timelineVM.skipHabit(habit)
                scheduleRefresh()
            },
            onUndo: { habit in
                timelineVM.undoCompletion(habit)
                cachedCompletedHabitIDsForSelectedDate.remove(habit.id)
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
            onboarding: onboarding,
            cachedStreaks: cachedStreaks,
            healthKitProgress: healthKitService.habitProgress,
            verifiedHabitIDs: healthKitService.verifiedHabitIDs,
            calendarEvents: eventKitService.todaysEvents,
            deepLinkHabitID: $deepLinkHabitID
        )
        .onChange(of: timelineSelectedDate) {
            scheduleRefresh()
            // Celebration guard now date-based via @AppStorage — no reset needed
            // Refresh calendar events for the selected date
            eventKitService.fetchEvents(for: timelineSelectedDate)
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
            // Focus Filter — only show habits matching active Focus category
            if let focusCategory = focusFilterService.activeCategory {
                cachedAllHabitsForSelectedDate = cachedAllHabitsForSelectedDate
                    .filter { $0.category == focusCategory }
            }
            // Compute streaks for today's habits (reuses existing @Query logs)
            let streakVM = StreakViewModel()
            let logsArray = Array(logs)
            cachedStreaks = Dictionary(uniqueKeysWithValues:
                cachedAllHabitsForSelectedDate.map { ($0.id, streakVM.calculateStreak(for: $0, logs: logsArray)) }
            )
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
            // Only show habits that existed on this date
            guard habit.createdAt <= timelineSelectedDate else { return false }
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

        // Focus Filter — only show habits matching active Focus category
        if let focusCategory = focusFilterService.activeCategory {
            cachedAllHabitsForSelectedDate = cachedAllHabitsForSelectedDate
                .filter { $0.category == focusCategory }
        }
    }

    private static let dateStringFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // #103: Time-of-day greeting (Fogg 2003 — contextual motivation)
    private static var timeOfDayGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Your tower starts here"
        }
    }


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
            // Filter to only scheduled habits (prevents inflated ring from other towers)
            let scheduledIDs = Set(dayHabits.map(\.id))
            let completed = (completedIDsByDate[dateStr] ?? []).intersection(scheduledIDs).count
            let skipped = (skippedIDsByDate[dateStr] ?? []).intersection(scheduledIDs).count
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
        withAnimation(GridConstants.crossFade) {
            visibleSkeletonCount = 0
        }
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

    /// A block has landed — disturb the water under it.
    ///
    /// Every block sends rings, not just the bottom row: the tower is standing
    /// in the water, so anything landing on it travels down through it. Rings
    /// spread from the landing block's own column, which is what makes the
    /// water feel attached to the tower rather than played at it.
    private func recordWaterImpact(blockID: UUID, mass: Int) {
        guard !reduceMotion,
              let block = towerVM.placedBlocks.first(where: { $0.id == blockID }) else { return }
        let f = GridConstants.blockFrame(
            column: block.column, row: 0,
            columnSpan: block.columnSpan, rowSpan: 1,
            cellSize: currentColW
        )
        let now = Date().timeIntervalSinceReferenceDate
        waterImpacts.append(
            TowerReflection.Impact(id: UUID(), x: f.midX, start: now, mass: mass)
        )
        // Drop anything that has finished spreading. Cheap, and it keeps the
        // array from growing across a long cascade.
        waterImpacts.removeAll { now - $0.start > TowerReflection.Impact.lifetime }
    }

    /// What of the tower reaches the water: the bottom row, as colour and
    /// width. A reflection at the base of something shows only what is nearest
    /// the surface, so nothing above row 0 contributes and nothing but position
    /// and colour survives.
    private func reflectionFacets(colW: CGFloat) -> [TowerReflection.Facet] {
        towerVM.placedBlocks
            .filter { $0.row == 0 }
            .map { block in
                let f = GridConstants.blockFrame(
                    column: block.column, row: 0,
                    columnSpan: block.columnSpan, rowSpan: 1,
                    cellSize: colW
                )
                return TowerReflection.Facet(
                    id: block.id,
                    x: f.minX,
                    width: f.width,
                    color: block.habit.displayCategory.style.baseColor
                )
            }
    }

    // MARK: - Wins

    /// Blocks that landed on the tower today — taps of the next slot plus
    /// habits completed. One honest number for what today added, rather than
    /// a count that stays still while the tower visibly grows.
    private var blocksToday: Int {
        let today = DateUtils.dateString(from: Date())
        return logs.filter { $0.dateString == today && $0.completed }.count
    }

    private func logWin(size: BlockSize = .small) {
        do {
            let habit = try QuickWinService.logWin(
                size: size,
                context: modelContext,
                tower: towerManager.activeTower
            )
            // The same path a normal completion takes, so the block lands on
            // the tower identically.
            // No refresh here: appending to pendingDrops starts the cascade,
            // and the cascade refreshes. Doing it here as well built the tower
            // twice and made the new block flash before it fell.
            pendingDrops.append(habit)
        } catch {
            winSaveFailed = true
        }
    }

    // MARK: - Toolbars
    //
    // Extracted from `mainContent` rather than written inline. That body is a
    // five-Tab TabView and was already at the type-checker's limit — adding one
    // modifier to a toolbar item inside it fails with "unable to type-check
    // this expression in reasonable time". Typed ToolbarContent also gives the
    // iOS 26 availability gate somewhere to live.
    //
    // `sharedBackgroundVisibility(.hidden)` drops the glass capsule iOS 26 puts
    // behind every toolbar item, leaving a bare glyph on the warm ground. It is
    // iOS 26+ and the deployment target is 18, so it is gated;
    // ToolbarContentBuilder supports `if #available` via buildLimitedAvailability.

    @ToolbarContentBuilder
    private var todayToolbar: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarTrailing) { addHabitButton }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarTrailing) { addHabitButton }
        }
    }

    private var addHabitButton: some View {
        Button {
            HapticsEngine.lightTap()
            isNewHabitMenuOpen = true
        } label: {
            Image(systemName: "plus")
                .iconSize(GridConstants.iconToolbar, relativeTo: .body, weight: .medium)
                .foregroundStyle(AppColors.accentWarm)
        }
    }

    // The tower carries the filter and nothing else. Settings moved to
    // Insights: it is a place you go to look at the app, which is where the
    // switches that change the app belong. The tower is the record.
    @ToolbarContentBuilder
    private var towerToolbar: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarLeading) {
                TowerFilterMenuButton(selection: $towerFilterMode)
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarLeading) {
                TowerFilterMenuButton(selection: $towerFilterMode)
            }
        }
    }

    @ToolbarContentBuilder
    private var insightsToolbar: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarTrailing) { settingsButton }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarTrailing) { settingsButton }
        }
    }

    private var settingsButton: some View {
        Button {
            HapticsEngine.lightTap()
            showSettings = true
        } label: {
            Image(systemName: "gearshape")
                .iconSize(GridConstants.iconToolbar, relativeTo: .body)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Setup

    private func setup() {
        guard !hasSetUp else { return }
        hasSetUp = true
        HapticsEngine.prepare()
        cachedTowerTitle = computeTowerTitle()
        towerManager.ensureDefaultTower(context: modelContext)
        towerManager.loadActiveTower(context: modelContext)
        #if DEBUG
        DebugHarness.seed(context: modelContext, tower: towerManager.activeTower)
        debugAutoWinsLeft = DebugHarness.autoWins
        if let tab = DebugHarness.startTab { selectedTab = tab }
        switch DebugHarness.openSheet {
        case "settings": selectedTab = .insights; showSettings = true
        case "add":      selectedTab = .tower; isNewHabitMenuOpen = true
        case "block":    selectedTab = .tower; wantsDebugExpand = true
        default:         break
        }
        #endif
        timelineVM.modelContext = modelContext
        habitManagerVM.modelContext = modelContext

        // HealthKit setup: sync connected habits and start observers
        syncHealthKitConnectedHabits()
        healthKitService.checkAvailability()
        #if DEBUG
        let mayAskForHealth = !DebugHarness.isActive
        #else
        let mayAskForHealth = true
        #endif
        if healthKitService.isAvailable && mayAskForHealth {
            Task {
                await healthKitService.requestAccess()
                healthKitService.setupObservers()
                healthKitService.refreshProgress()
                healthKitService.startForegroundPolling()
            }
        }

        // Calendar setup
        if eventKitService.isAuthorized {
            eventKitService.fetchTodaysEvents()
        }
        animCoord.reduceMotion = reduceMotion
        animCoord.lookupMass = { [towerVM] id in
            towerVM.placedBlocks.first(where: { $0.id == id })?.habit.blockSize.massTier
        }
        animCoord.onImpact = { [towerVM, animCoord] landedID, mass in
            animCoord.triggerRipple(from: landedID, massTier: mass, placedBlocks: towerVM.placedBlocks)
            recordWaterImpact(blockID: landedID, mass: mass)
            SoundEngine.blockImpact(mass: mass) // Bimodal: haptic + audio (Vroomen 2000)
            // Tower compression pulse — global impact response
            let compression: CGFloat = mass >= 2 ? 0.004 : 0.002
            withAnimation(.easeOut(duration: 0.06)) {
                towerImpactScale = 1.0 - compression
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(60))
                withAnimation(GridConstants.naturalSettle) {
                    towerImpactScale = 1.0
                }
            }
        }
        // Post-cascade settle — the tower exhales (Gestalt Pragnanz closure)
        animCoord.onAllDropsComplete = { [self] in
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                towerImpactScale = 1.02
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    towerImpactScale = 1.0
                }

                // Perfect day jubilation — blocks dance bottom-to-top (Schultz 1997)
                let todayStr = TimelineViewModel.dateString(from: Date())
                if towerFilterMode == .day && perfectDayDates.contains(todayStr) && lastCelebrationDate != todayStr {
                    lastCelebrationDate = todayStr  // Once per calendar day — prevents repeat on tab switch
                    try? await Task.sleep(for: .milliseconds(200))
                    HapticsEngine.reward()
                    animCoord.triggerJubilation(placedBlocks: towerVM.placedBlocks)
                    // Confetti after jubilation wave actually finishes
                    Task { @MainActor in
                        while animCoord.isJubilating {
                            try? await Task.sleep(for: .milliseconds(100))
                        }
                        try? await Task.sleep(for: .milliseconds(200))
                        showTowerConfetti = true
                    }
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
            let hadBuilt = towerVM.hasBuiltOnce
            let dropped = refreshData()
            // EVERY block that arrives falls.
            //
            // This return value used to be discarded, so only blocks that came
            // through `cascadeDropPendingBlocks` were ever handed to the
            // animator. Anything arriving by another route — completing a habit
            // elsewhere, a HealthKit verification, the minute timer noticing a
            // new log — appeared in its final place with a ghost slot behind it
            // and no fall. That is the "some fall, some don't".
            //
            // Not on the first build, when every block is new relative to an
            // empty set and the whole tower would cascade on launch.
            guard hadBuilt, !dropped.isEmpty, !animCoord.isCascading else { return }
            for id in dropped { enqueueDrop(blockIDs: [id]) }
        }
    }

    @discardableResult
    private func refreshData() -> Set<UUID> {
        // Keep HealthKit service in sync with current habits
        syncHealthKitConnectedHabits()

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
            towerVM.buildTower(from: filteredLogs, filterMode: towerFilterMode)
        }
        towerVM.computeDaySeparators(perfectDayDates: perfectDayDates)
        updateVisibleDateTitle()
        weekCompletedDates = allCompletedDateStrings
        recomputeIncompleteTimeline()

        // Update timer guard values from index (avoid redundant O(n) scan)
        lastLogCount = logs.count
        lastCompletionDate = maxCompletedAt

        // Purge stale animation state
        let validIDs = Set(towerVM.placedBlocks.map(\.id))
        animCoord.purgeStaleState(validIDs: validIDs)

        // #386: Perfect day anticipation — check if one habit remains
        let todayStr = TimelineViewModel.dateString(from: Date())
        let todayHabits = habits.filter { $0.tower?.id == towerManager.activeTower?.id && !$0.isTodo }
        let todayCompleted = cachedFilteredLogs.filter { $0.dateString == todayStr && $0.completed }.count
        let todayTotal = todayHabits.count
        let newAnticipation = todayTotal > 0 && (todayTotal - todayCompleted) == 1
        if newAnticipation != showPerfectDayAnticipation {
            withAnimation(GridConstants.gentleReveal) {
                showPerfectDayAnticipation = newAnticipation
            }
        }

        // #109: Comeback detection — after 3+ day gap
        if todayCompleted > 0 && !lastCompletionDateString.isEmpty {
            if let lastDate = Self.dateStringFormatter.date(from: lastCompletionDateString) {
                let daysSince = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
                if daysSince >= 3 && !showComebackBanner {
                    withAnimation(GridConstants.gentleReveal) { showComebackBanner = true }
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(4))
                        withAnimation(GridConstants.crossFade) { showComebackBanner = false }
                    }
                }
            }
        }
        if todayCompleted > 0 { lastCompletionDateString = todayStr }

        // #85: Milestone detection — check on every refresh
        let newMilestones = MilestoneDetector.detectNewMilestones(
            totalBlocks: towerVM.placedBlocks.count,
            towerHeightMeters: towerVM.altimeterHeight,
            perfectDayCount: perfectDayDates.count,
            longestStreak: 0, // TODO: compute from streaks
            store: &milestoneStore
        )
        if let first = newMilestones.first {
            milestoneStore.save()
            pendingMilestone = first
        }

        // Debounced Spotlight reindex — only when habit count changes (create/delete)
        if habits.count != lastIndexedHabitCount {
            lastIndexedHabitCount = habits.count
            spotlightIndexTask?.cancel()
            spotlightIndexTask = Task {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                SpotlightIndexer.reindex(container: SharedModelContainer.shared)
            }
        }

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
        let isFirstDrop = !hasSeenFirstDrop && !habits.isEmpty

        // First block: zoom in for drama (Murdock 1962 primacy effect)
        if isFirstDrop && !reduceMotion {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                towerImpactScale = 1.08
            }
            try? await Task.sleep(for: .milliseconds(400))
        }

        scrollToTopTrigger += 1
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s scroll settle

        // Capture the log IDs we KNOW are new before refreshData() can consume them.
        // This fixes a race where refreshData() (via timer or other trigger) already updated
        // previousBlockIDs, causing buildTower() to return empty newlyDroppedIDs.
        let todayStr = TimelineViewModel.dateString(from: Date())
        let pendingLogIDs: Set<UUID> = Set(habits.compactMap { habit in
            habit.logs.first(where: { $0.dateString == todayStr && $0.completed })?.id
        })

        let droppedIDs = refreshData()

        // Use explicitly tracked IDs — fall back to buildTower's diff if available
        let animateIDs = droppedIDs.isEmpty
            ? pendingLogIDs.intersection(Set(towerVM.placedBlocks.map(\.id)))
            : droppedIDs

        if let firstDropped = animateIDs.first {
            scrollToDropID = firstDropped
        }

        // Enqueue individually for sequential animation (coordinator drains with 60ms gaps)
        for droppedID in animateIDs {
            enqueueDrop(blockIDs: [droppedID])
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

        // #50: First Block haptic choreography — lightTap→pause→reward→pause→success
        if isFirstDrop {
            hasSeenFirstDrop = true
            HapticsEngine.lightTap()
            try? await Task.sleep(for: .milliseconds(200))
            HapticsEngine.reward()
            try? await Task.sleep(for: .milliseconds(300))
            HapticsEngine.success()

            try? await Task.sleep(for: .seconds(reduceMotion ? 0.5 : 1.5))

            if !reduceMotion {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    towerImpactScale = 1.0
                }
            }

            // "Your first block." — shows in ALL motion modes
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 300 : 800))
            withAnimation(GridConstants.gentleReveal) {
                showFirstBlockLabel = true
            }
            try? await Task.sleep(for: .seconds(2))
            withAnimation(GridConstants.crossFade) {
                showFirstBlockLabel = false
            }
        }
    }

    // MARK: - Tower Content

    private func towerContent(colW: CGFloat, topInset: CGFloat,
                              safeAreaTop: CGFloat, safeAreaBottom: CGFloat,
                              viewportHeight: CGFloat) -> some View {
        let gridW = CGFloat(columns) * colW + CGFloat(columns - 1) * spacing
        let rowCount = towerVM.totalRows

        // The loading skeleton and the empty-state ghosts are laid out by the
        // same bottom-up `flippedY(for:gridH:)` as real blocks, but they run
        // when `totalRows` is 0. With `gridH` at 0 every placeholder got a
        // NEGATIVE y and drew above the container — up over the toolbar and the
        // status bar. That is the "ghost blocks run off screen" report. So the
        // placeholders' own layout supplies the height when there are no real
        // rows to measure.
        let placeholders: [TowerViewModel.SkeletonBlock] = rowCount > 0
            ? []
            : (towerVM.isLoading
               ? towerVM.skeletonLayout()
               : [])
        let placeholderRows = placeholders.map { $0.row + $0.rowSpan }.max() ?? 0
        let layoutRows = rowCount > 0 ? rowCount : placeholderRows
        let gridH = layoutRows > 0
            ? CGFloat(layoutRows) * colW + CGFloat(layoutRows - 1) * spacing
            : 0
        // Everything under the grid — ground plane, tier badge, the transient
        // first-block label — is drawn with `.offset` from the grid's bottom
        // edge. `.offset` does not affect layout, so the sizing spacer below
        // has to be told about it or the container reserves no space for any
        // of it and it hangs outside the measured bounds.
        let waterDepth = TowerReflection.depth
        let footerReserve: CGFloat = waterDepth + (showFirstBlockLabel ? 30 : 0)
        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // Top anchor for FAB scroll
                    Color.clear.frame(height: 1)
                        .id("TowerTop")

                    Color.clear
                        .frame(width: gridW,
                               height: max(gridH, 1) + (rowCount > 0 ? footerReserve : 0))

                    if towerVM.isLoading {
                        skeletonGrid(skeletons: placeholders, colW: colW, gridH: gridH)
                    } else if towerVM.totalRows == 0 {
                        // An empty tower gets the same next slot a full one
                        // does — pressing it is how the first block arrives, so
                        // it cannot be the one state without a way to press.
                        emptyTowerSlot(colW: colW)
                    } else {
                        // Ground plane at tower foundation, and the water
                        // it sits on.
                        towerGroundPlane(gridW: gridW, gridH: gridH)

                        TowerReflection(
                            facets: reflectionFacets(colW: colW),
                            impacts: waterImpacts,
                            gridWidth: gridW,
                            cornerRadius: cornerRadius,
                            reduceMotion: reduceMotion
                        )
                        .offset(y: gridH + 1)

                        // Merged runs, under the blocks. Members draw
                        // nothing when settled, so this IS their appearance.
                        ForEach(towerVM.mergeGroups) { group in
                            MergedGroupView(
                                group: group,
                                cellSize: colW,
                                gridWidth: gridW,
                                gridHeight: gridH
                            )
                        }

                        placedBlocksGrid(colW: colW, gridH: gridH,
                                         viewportHeight: viewportHeight, topInset: topInset)

                        // #74: Height markers — "30m", "60m" at 10-row intervals
                        if towerVM.totalRows >= 10 {
                            let markerInterval = 10
                            let cellStride = colW + spacing
                            ForEach(Array(stride(from: markerInterval, to: towerVM.totalRows, by: markerInterval)), id: \.self) { row in
                                let meters = Int(Double(row) * GridConstants.metersPerBlock)
                                let markerY = gridH - CGFloat(row) * cellStride
                                // Right-aligned inside the grid: `gridW + 4`
                                // put these past the screen edge, so the "m"
                                // was clipped off every marker.
                                Text("\(meters)m")
                                    .font(Typography.caption2)
                                    .foregroundStyle(.primary.opacity(0.15))
                                    .frame(width: gridW, alignment: .trailing)
                                    .offset(y: markerY - 6)
                            }
                        }

                        // Nothing sits under the tower. The count moved to a
                        // fixed place at the top of the page (`towerTally`) so
                        // the tower can stand on its water with the tab bar
                        // directly beneath it, rather than on a caption.
                        if showFirstBlockLabel {
                            Text("Your first block.")
                                .font(Typography.bodySmall)
                                .foregroundStyle(.primary.opacity(0.5))
                                .frame(width: gridW, alignment: .center)
                                .offset(y: gridH + waterDepth + 6)
                                .transition(.opacity)
                        }
                    }
                }
                .scaleEffect(y: towerImpactScale, anchor: .bottom)
                // Device parallax — tower shifts with phone tilt (Harrison 2011)
                .rotation3DEffect(.degrees(motionCoord.pitch * 2.5), axis: (1, 0, 0), perspective: 0.8)
                .rotation3DEffect(.degrees(motionCoord.roll * 2.5), axis: (0, 1, 0), perspective: 0.8)
                // Tower Aurora — rare, earned, beautiful (Skinner 1938)
                .overlay {
                    if showAurora && !reduceMotion {
                        TowerAuroraView(isActive: $showAurora)
                    }
                    if showTowerConfetti {
                        AllClearCelebration(
                            isActive: $showTowerConfetti,
                            completedCategories: Array(Set(
                                cachedAllHabitsForSelectedDate
                                    .filter { cachedCompletedHabitIDsForSelectedDate.contains($0.id) }
                                    .map(\.category)
                            ))
                        )
                            .allowsHitTesting(false)
                    }
                }
                .padding(.horizontal, hPad)
                // The tab bar's inset is already applied to this scroll view
                // by TabView, so adding `safeAreaBottom` here counted it twice.
                .padding(.bottom, 8)
                // `viewportHeight` is a GeometryReader size, which already
                // excludes the safe areas. Subtracting `safeAreaTop` from it
                // took the top inset off a second time and left that much
                // dead air under a bottom-aligned tower.
                .frame(
                    minHeight: viewportHeight,
                    alignment: .bottom
                )
                // Outside the bottom-anchored grid, so it centres on the
                // viewport rather than on the ghost footing.
                .overlay {
                    if !towerVM.isLoading && towerVM.totalRows == 0 {
                        towerEmptyStateMessage
                    }
                }
            }
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { oldOffset, newOffset in
                if abs(newOffset - towerScrollOffset) > 8 {
                    towerScrollOffset = newOffset
                    updateVisibleDateTitle()
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
    private func skeletonGrid(skeletons: [TowerViewModel.SkeletonBlock], colW: CGFloat, gridH: CGFloat) -> some View {
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
            TowerBlocksForEach(
                visibleBlocks: visibleBlocks, animCoord: animCoord, towerVM: towerVM,
                colW: colW, gridH: gridH, safeAreaTop: safeAreaTop,
                collapsedHeaderHeight: collapsedHeaderHeight,
                towerScrollOffset: towerScrollOffset,
                cornerRadius: cornerRadius, expandedBlockID: expandedBlockID,
                showBlockTapHint: showBlockTapHint, hintBlockID: hintBlockID,
                blockExpansionNamespace: blockExpansion,
                reduceMotion: reduceMotion, colorScheme: colorScheme,
                onTapExpandBlock: { id in
                    withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.cardMorph) {
                        expandedBlockID = id
                    }
                }
            )

            // Day separators (Week/Month modes)
            if towerFilterMode != .day {
                let gridW = CGFloat(columns) * colW + CGFloat(columns - 1) * spacing
                ForEach(towerVM.daySeparators) { sep in
                    let sepY = gridH - CGFloat(sep.gridRow) * (colW + spacing) + 2
                    DaySeparatorView(separator: sep, gridWidth: gridW)
                        .offset(y: sepY)
                }
            }

            // The next slot, as a button.
            //
            // This was a passive preview of where your next scheduled habit
            // would land, behind a Settings toggle. It is now the way a win is
            // logged: press the empty slot and a block drops into it. That
            // replaces the Wins tab, which was a whole page to say one thing
            // the tower can say in the place where it happens.
            //
            // It sits at computeGhostPosition, so it is always exactly where
            // the block will land. The tower is bottom-aligned and the scroll
            // opens at the top, so the slot is on screen when the tab opens.
            if !animCoord.isCascading,
               let pos = towerVM.computeGhostPosition(for: .small) {
                let ghostFrame = GridConstants.blockFrame(
                    column: pos.column, row: pos.row,
                    columnSpan: 1, rowSpan: 1,
                    cellSize: colW
                )
                NextSlotButton(
                    reduceMotion: reduceMotion,
                    cornerRadius: cornerRadius,
                    action: { logWin(size: $0) }
                )
                .frame(width: ghostFrame.width, height: ghostFrame.height)
                .offset(x: ghostFrame.minX, y: flippedY(for: ghostFrame, gridH: gridH))
            }
        }
        .accessibilityElement(children: .combine)
        // #128: Tower summary rotor — block count + height + today count
        .accessibilityLabel("Tower grid, \(towerVM.placedBlocks.count) blocks, \(Int(towerVM.altimeterHeight)) meters, \(todayCompletedCount) of \(todayTotalCount) today")
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
            if animCoord.activelyAnimatingIDs.contains(block.id) || towerVM.newlyDroppedIDs.contains(block.id) {
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
        let neutralColor = AppColors.warmBlack.opacity(0.15)
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
            color: AppColors.warmBlack.opacity(0.12),
            radius: 4, x: 0, y: 2
        )
        .offset(y: gridH)
    }


    // MARK: - Ghost Tower Empty State

    /// The next slot on an empty tower: one cell, on the ground.
    ///
    /// This replaces a decorative three-block footing. A row of ghosts that
    /// cannot be pressed says "blocks go here" to someone who is looking for
    /// how to put one there; one slot that can be pressed answers it.
    @ViewBuilder
    private func emptyTowerSlot(colW: CGFloat) -> some View {
        let f = GridConstants.blockFrame(
            column: 0, row: 0, columnSpan: 1, rowSpan: 1, cellSize: colW
        )
        NextSlotButton(
            reduceMotion: reduceMotion,
            cornerRadius: cornerRadius,
            action: { logWin(size: $0) }
        )
        .frame(width: f.width, height: f.height)
        .offset(x: f.minX, y: 0)
    }

    /// The faint footing an empty tower sits on. Blocks only — the invitation
    /// is `towerEmptyStateMessage`, drawn as a centred overlay, because the two
    /// were in one ZStack and the copy landed on top of the ghosts.
    @ViewBuilder
    private func ghostTowerEmptyState(ghosts: [TowerViewModel.SkeletonBlock], colW: CGFloat, gridH: CGFloat) -> some View {
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
    }

    /// The invitation on an empty tower.
    ///
    /// It used to end in a filled "Go to Today" button, which was the loudest
    /// thing on the page and pointed away from it. There is a pressable slot on
    /// the ground now, so the copy names that instead, and scheduling is a
    /// quiet second line rather than the headline.
    private var towerEmptyStateMessage: some View {
        VStack(spacing: 10) {
            // #103: Time-of-day greeting
            Text(Self.timeOfDayGreeting)
                .font(Typography.headerMedium)
                .foregroundStyle(.primary.opacity(0.6))

            Text("Press the empty block\nto record something you did.")
                .font(Typography.bodySmall)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                HapticsEngine.lightTap()
                selectedTab = .today
            } label: {
                Text("or plan your day")
                    .font(Typography.bodySmall)
                    .foregroundStyle(.primary.opacity(0.4))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Tower Block Views (Extracted for observation isolation)

    private struct TowerBlocksForEach: View {
        let visibleBlocks: [PlacedBlock]
        let animCoord: TowerAnimationCoordinator
        let towerVM: TowerViewModel
        let colW: CGFloat
        let gridH: CGFloat
        let safeAreaTop: CGFloat
        let collapsedHeaderHeight: CGFloat
        let towerScrollOffset: CGFloat
        let cornerRadius: CGFloat
        let expandedBlockID: UUID?
        let showBlockTapHint: Bool
        let hintBlockID: UUID?
        let blockExpansionNamespace: Namespace.ID
        let reduceMotion: Bool
        let colorScheme: ColorScheme
        let onTapExpandBlock: (UUID) -> Void

        var body: some View {
            ForEach(visibleBlocks) { block in
                let f = GridConstants.blockFrame(
                    column: block.column, row: block.row,
                    columnSpan: block.columnSpan, rowSpan: block.rowSpan,
                    cellSize: colW
                )
                let animState = animCoord.state(for: block.id)
                let isNewlyDropped = towerVM.newlyDroppedIDs.contains(block.id)
                let stagger = towerVM.staggerDelay(for: block)

                AnimatedBlockView(
                    block: block, frame: f, animState: animState,
                    isNewlyDropped: isNewlyDropped, staggerDelay: stagger,
                    gridH: gridH, safeAreaTop: safeAreaTop,
                    collapsedHeaderHeight: collapsedHeaderHeight,
                    towerScrollOffset: towerScrollOffset,
                    cornerRadius: cornerRadius, expandedBlockID: expandedBlockID,
                    showBlockTapHint: showBlockTapHint, hintBlockID: hintBlockID,
                    blockExpansionNamespace: blockExpansionNamespace,
                    reduceMotion: reduceMotion, colorScheme: colorScheme,
                    isFoundation: towerVM.foundationBlockIDs.contains(block.id),
                    isCrown: towerVM.topRowBlockIDs.contains(block.id),
                    milestoneNumber: towerVM.milestoneBlockIDs[block.id],
                    isGroupMember: towerVM.groupedBlockIDs.contains(block.id),
                    isCovered: towerVM.coveredBlockIDs.contains(block.id),
                    onTapExpandBlock: onTapExpandBlock
                )
                .frame(width: f.width, height: f.height)
                .id(block.id)
                .offset(x: f.minX, y: gridH - f.minY - f.height)
                .zIndex(animState.dropPhase != nil ? 100 : Double(block.row + 1))
                .accessibilitySortPriority(-Double(block.row))
                .transition(.opacity.animation(.easeOut(duration: 0.2).delay(stagger)))
            }
        }
    }

    private struct AnimatedBlockView: View, Equatable {
        let block: PlacedBlock
        let frame: CGRect
        let animState: BlockAnimationState
        let isNewlyDropped: Bool
        let staggerDelay: Double
        let gridH: CGFloat
        let safeAreaTop: CGFloat
        let collapsedHeaderHeight: CGFloat
        let towerScrollOffset: CGFloat
        let cornerRadius: CGFloat
        let expandedBlockID: UUID?
        let showBlockTapHint: Bool
        let hintBlockID: UUID?
        let blockExpansionNamespace: Namespace.ID
        let reduceMotion: Bool
        let colorScheme: ColorScheme
        let isFoundation: Bool
        let isCrown: Bool
        let milestoneNumber: Int?
        let isGroupMember: Bool
        let isCovered: Bool
        let onTapExpandBlock: (UUID) -> Void

        @Environment(\.modelContext) private var modelContext

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.block.id == rhs.block.id
            && lhs.frame == rhs.frame
            && lhs.isNewlyDropped == rhs.isNewlyDropped
            && lhs.gridH == rhs.gridH
            && lhs.towerScrollOffset == rhs.towerScrollOffset
            && lhs.expandedBlockID == rhs.expandedBlockID
            && lhs.showBlockTapHint == rhs.showBlockTapHint
            && lhs.hintBlockID == rhs.hintBlockID
            && lhs.reduceMotion == rhs.reduceMotion
            && lhs.colorScheme == rhs.colorScheme
            && lhs.isFoundation == rhs.isFoundation
            && lhs.isCrown == rhs.isCrown
            && lhs.milestoneNumber == rhs.milestoneNumber
            && lhs.isGroupMember == rhs.isGroupMember
            && lhs.isCovered == rhs.isCovered
        }



        var body: some View {
            let phase = animState.dropPhase
            let isAnimating = phase != nil
            let isNew = isAnimating || isNewlyDropped
            let mass = CGFloat(block.habit.blockSize.massTier)

            let dropOffset: CGFloat = switch phase {
            case .falling:
                {
                    // Start above the viewport, but not so far above that most
                    // of the fall happens off screen. At -400 the block covered
                    // its whole visible run in the last third of an already
                    // short animation, so what you saw was an arrival rather
                    // than a fall. Clamped to a range now: high enough to enter
                    // from off screen, close enough that the travel reads.
                    let paddingTop = safeAreaTop + collapsedHeaderHeight + 20
                    let blockInScrollContent = paddingTop + (gridH - frame.maxY)
                    let dynamicOffset = towerScrollOffset - blockInScrollContent - frame.height - 60
                    return max(min(dynamicOffset, -240), -520)
                }()
            case .squash, .stretch, .wobble: CGFloat(0)
            case .none: CGFloat(0)
            }

            let (impactScaleX, impactScaleY): (CGFloat, CGFloat) = switch phase {
            case .squash:
                (1.0 + GridConstants.squashScaleX(mass: mass),
                 1.0 - GridConstants.squashScaleY(mass: mass))
            case .stretch:
                (1.0 - GridConstants.stretchScaleX(mass: mass),
                 1.0 + GridConstants.stretchScaleY(mass: mass))
            default: (1.0, 1.0)
            }

            let wobbleDegrees: Double = switch phase {
            case .wobble: mass >= 2 ? GridConstants.wobbleDegreesHeavy : GridConstants.wobbleDegreesLight
            default: 0
            }

            let flashBrightness: Double = phase == .squash ? 0.06 : 0

            let (dropShadowRadius, dropShadowY): (CGFloat, CGFloat) = switch phase {
            case .falling: (12, 8)
            case .squash: (1, 0.5)
            case .stretch: (3, 1.5)
            case .wobble: (4, 2)
            case .none: (0, 0)
            }

            let isRippling = animState.isRippling
            let ri = animState.rippleIntensity
            let rippleScaleX: CGFloat = isRippling ? 1.0 + 0.030 * ri : 1.0
            let rippleScaleY: CGFloat = isRippling ? 1.0 - 0.050 * ri : 1.0
            let rippleOffsetY: CGFloat = isRippling ? 2.5 * ri : 0

            let isExpanded = expandedBlockID == block.id

            ZStack {
                if isNew {
                    ghostSlot(width: frame.width, height: frame.height)
                }

                FlippableBlockView(
                    block: block,
                    width: frame.width,
                    height: frame.height,
                    cornerRadius: cornerRadius,
                    modelContext: modelContext,
                    // A falling block draws itself; it joins the shape on
                    // landing.
                    isGroupMember: isGroupMember && phase == nil,
                    isCovered: isCovered,
                    onTap: {
                        if !isExpanded {
                            onTapExpandBlock(block.id)
                        }
                    }
                )
                .matchedGeometryEffect(id: block.id, in: blockExpansionNamespace)
                .opacity(isExpanded ? 0 : block.isSkipped ? 0.30 : 1)
                .overlay {
                    // Skipped block diagonal lines
                    if block.isSkipped {
                        Canvas { context, size in
                            let step: CGFloat = 8
                            var path = Path()
                            var x: CGFloat = -size.height
                            while x < size.width {
                                path.move(to: CGPoint(x: x, y: size.height))
                                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                                x += step
                            }
                            context.stroke(path, with: .color(.white.opacity(0.3)), lineWidth: 0.5)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        .allowsHitTesting(false)
                    }
                }
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
                .scaleEffect(x: impactScaleX, y: impactScaleY, anchor: .bottom)
                .rotation3DEffect(.degrees(wobbleDegrees), axis: (x: 0, y: 0, z: 1))
                .brightness(flashBrightness)
                .shadow(
                    color: phase != nil ? .black.opacity(
                        GridConstants.adaptiveShadowOpacity(0.12, colorScheme: colorScheme)
                    ) : .clear,
                    radius: dropShadowRadius, x: 0, y: dropShadowY
                )
                // Depth-based shadow — higher blocks cast longer shadows (Mamassian 1998)
                //
                .shadow(
                    color: .black.opacity(0.04),
                    radius: GridConstants.shadowRadius + CGFloat(block.row) * GridConstants.depthShadowScale,
                    x: 0,
                    y: GridConstants.shadowY + CGFloat(block.row) * GridConstants.depthShadowYScale
                )
                // Foundation blocks — slightly darker
                .brightness(isFoundation ? -0.02 : 0)
                // Crown — white top edge on topmost blocks
                .overlay(alignment: .top) {
                    if isCrown {
                        Rectangle()
                            .fill(.white.opacity(0.15))
                            .frame(height: 1)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
                }
                .offset(y: dropOffset + animState.microBounceY)
            }
            .scaleEffect(x: rippleScaleX, y: rippleScaleY, anchor: .bottom)
            .offset(y: rippleOffsetY)
            // #34: Parallax depth — higher rows shift slightly more (subtle depth cue)
            .offset(y: reduceMotion ? 0 : CGFloat(block.row) * 0.0003 * towerScrollOffset)
            // Jubilation wave — rotation, lift, glow (perfect day celebration)
            .rotationEffect(.degrees(animState.jubilationWobble))
            .offset(y: animState.jubilationLift)
            .brightness(animState.jubilationGlow)
        }

        private func ghostSlot(width: CGFloat, height: CGFloat) -> some View {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .frame(width: width, height: height)
        }
    }

    private func dismissCard() {
        HapticsEngine.tick()
        try? modelContext.save()
        withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.cardMorph) {
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
        let categories: [HabitCategory] = HabitCategory.selectable
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

    // MARK: - HealthKit Integration

    /// Sync connected HealthKit habits to the service
    private func syncHealthKitConnectedHabits() {
        healthKitService.connectedHabits = habits.compactMap { habit in
            guard let type = habit.healthKitType else { return nil }
            return (id: habit.id, type: type, threshold: habit.healthKitThreshold ?? 0)
        }
    }

    /// Day-boundary auto-complete: silently complete unacknowledged verified habits from yesterday
    private func performDayBoundaryAutoComplete() {
        let todayStr = TimelineViewModel.dateString(from: Date())
        guard lastDayBoundaryCheck != todayStr else { return }
        lastDayBoundaryCheck = todayStr

        // Find yesterday's date
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else { return }
        let yesterdayStr = TimelineViewModel.dateString(from: yesterday)

        // Find HealthKit-connected habits that were verified yesterday but not acknowledged
        let connectedHabits = habits.filter { $0.healthKitType != nil }
        for habit in connectedHabits {
            let hasLog = habit.logs.contains { $0.dateString == yesterdayStr && $0.completed }
            if !hasLog {
                // Check if there's an existing log to update, or create a new one
                if let existingLog = habit.logs.first(where: { $0.dateString == yesterdayStr }) {
                    existingLog.completed = true
                    existingLog.completedAt = yesterday
                    existingLog.verifiedByHealthKit = true
                } else {
                    let log = HabitLog(habit: habit, dateString: yesterdayStr, completed: true)
                    log.completedAt = yesterday
                    log.verifiedByHealthKit = true
                    modelContext.insert(log)
                }
            }
        }
        try? modelContext.save()
    }

    private func resetTower() {
        // 1. Delete all image files from disk (must read file names before deleting entities)
        let allLogs = (try? modelContext.fetch(FetchDescriptor<HabitLog>())) ?? []
        for log in allLogs {
            if let fileName = log.imageFileName {
                ImageManager.shared.deleteImage(fileName: fileName)
            }
        }

        // 2. Batch-delete all SwiftData entities
        try? modelContext.delete(model: HabitLog.self)
        try? modelContext.delete(model: Habit.self)
        try? modelContext.delete(model: PlanFolder.self)
        try? modelContext.delete(model: MoodLog.self)
        try? modelContext.delete(model: Tower.self)
        try? modelContext.save()

        // 3. Reset UserDefaults (onboarding, tower selection, hints, plan prefs)
        for key in [
            "activeTowerID",
            "onb_welcome", "onb_hold", "onb_skip", "onb_firstBlock",
            "onb_nlp", "onb_drag", "onb_photo", "onb_week",
            "onb_contextMenu", "onb_sessionCount",
            "hasSeenBlockTapHint", "hasCompletedFirstHabit",
            "hasSeenHealthKitVerification", "lastDayBoundaryCheck",
            "sectionExpanded", "smartViewOverrides", "planSortMode"
        ] {
            UserDefaults.standard.removeObject(forKey: key)
        }

        // 4. Reset in-memory @AppStorage / @StateObject properties
        hasSeenBlockTapHint = false
        onboarding.hasSeenWelcome = false
        onboarding.hasSeenHoldHint = false
        onboarding.hasSeenSkipHint = false
        onboarding.hasSeenFirstBlockHint = false
        onboarding.hasSeenNLPHint = false
        onboarding.hasSeenDragHint = false
        onboarding.hasSeenPhotoHint = false
        onboarding.hasSeenWeekHint = false
        onboarding.hasSeenContextMenuHint = false
        onboarding.sessionCount = 0
        onboarding.dismissHint()

        // 5. Reset in-memory view state
        pendingDrops = []
        expandedBlockID = nil
        showBlockTapHint = false
        hintBlockID = nil
        animCoord.reset()
        selectedTab = .tower

        // 6. Re-create fresh default tower and set as active
        towerManager.ensureDefaultTower(context: modelContext)
        towerManager.loadActiveTower(context: modelContext)

        // 7. Rebuild all derived state from now-empty database
        refreshData()
    }

}

// MARK: - Block Flyaway (Today → Tower visual bridge)

private struct FlyawayBlockView: View {
    let category: HabitCategory
    @Binding var landed: Bool
    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let screenW = geo.size.width
            let screenH = geo.size.height

            // Target: Tower tab icon — first of 4 equal tabs (Fitts 1954)
            let targetX = screenW / 8.0
            let targetY = screenH + 24.5 // Center of 49pt tab bar below content

            // Start: center of overlay (habit rows are upper-half)
            let startX = screenW / 2.0
            let startY = screenH * 0.45

            let t = progress
            let dx = targetX - startX
            let dy = targetY - startY

            // Cubic ease-out: decelerate into target (Apple collect pattern)
            let easedT = 1.0 - pow(1.0 - t, 3.0)

            // Parabolic arc peak at t≈0.5 (natural throw-and-catch — Heider & Simmel 1944)
            let arcPeak: CGFloat = -60
            let arcOffset = arcPeak * 4.0 * t * (1.0 - t)

            let currentX = dx * easedT
            let currentY = dy * t + arcOffset
            let scale = 1.0 - t * 0.65

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(category.style.gradient)
                .frame(width: 32, height: 32)
                .frame(minWidth: 44, minHeight: 44)
                .shadow(color: .black.opacity(0.15 * (1.0 - t * 0.5)), radius: 4, y: 2)
                .scaleEffect(scale)
                .offset(x: currentX, y: currentY)
                .opacity(1.0 - t * 0.3)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(GridConstants.blockFlyaway) {
                progress = 1.0
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                landed = true
            }
        }
    }
}

// MARK: - Tower Aurora (rare, earned, beautiful — Skinner 1938)

private struct TowerAuroraView: View {
    @Binding var isActive: Bool
    @State private var startTime: Date?

    private let duration: TimeInterval = 2.5

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let width = geo.size.width

            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: false)) { timeline in
                let elapsed = startTime.map { timeline.date.timeIntervalSince($0) } ?? 0
                let progress = min(elapsed / duration, 1.0)
                let fade = max(0, 1.0 - max(0, progress - 0.6) / 0.4)

                let sway1 = sin(elapsed * 1.5) * 15
                let sway2 = sin(elapsed * 2.0 + 1) * 12
                let sway3 = sin(elapsed * 2.5 + 2) * 8

                ZStack {
                    // Cool curtain (teal → blue) — lower altitude, faster
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.06, green: 0.72, blue: 0.50).opacity(0.18 * fade),
                                    Color(red: 0.25, green: 0.66, blue: 1.0).opacity(0.14 * fade)
                                ],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: width * 0.85, height: 140)
                        .blur(radius: 30)
                        .offset(x: -width * 0.08 + sway1, y: height * (1.0 - progress * 1.2))

                    // Warm curtain (purple → magenta) — higher altitude, slower
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.69, green: 0.61, blue: 0.98).opacity(0.15 * fade),
                                    Color(red: 0.93, green: 0.52, blue: 0.71).opacity(0.12 * fade)
                                ],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: width * 0.7, height: 110)
                        .blur(radius: 25)
                        .offset(x: width * 0.12 + sway2, y: height * (1.0 - progress * 1.05) - 40)

                    // Gold accent shimmer — fastest, thinnest
                    Ellipse()
                        .fill(GridConstants.patinaGold.opacity(0.10 * fade))
                        .frame(width: width * 0.5, height: 70)
                        .blur(radius: 15)
                        .offset(x: sway3, y: height * (1.0 - progress * 1.35) + 20)
                }
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .onAppear {
            startTime = Date()
            HapticsEngine.reward()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(Int(duration * 1000)))
                SoundEngine.allClearChime()
                try? await Task.sleep(for: .seconds(1))
                isActive = false
            }
        }
    }
}

#Preview {
    MainAppView()
        .modelContainer(for: [Habit.self, HabitLog.self, MoodLog.self, Tower.self], inMemory: true)
        .environment(EventKitService())
        .environment(HealthKitService())
        .environment(FocusFilterService())
}

/// Opens a block's card without a tap, for screenshots.
///
/// A block card is only reachable by tapping the block, and nothing on this
/// machine can tap. Extracted into a modifier rather than written inline
/// because `MainAppView.body` is at the type-checker's ceiling and one more
/// `.onChange` on it fails to compile.
private struct DebugExpandFirstBlock: ViewModifier {
    let blockCount: Int
    let firstBlockID: UUID?
    @Binding var wants: Bool
    @Binding var expanded: UUID?

    func body(content: Content) -> some View {
        #if DEBUG
        content.onChange(of: blockCount) { _, count in
            guard wants, count > 0 else { return }
            wants = false
            expanded = firstBlockID
        }
        #else
        content
        #endif
    }
}

/// Presses the next slot without a tap, for watching the drop cascade.
private struct DebugAutoWin: ViewModifier {
    let blockCount: Int
    @Binding var remaining: Int
    let fire: () -> Void

    func body(content: Content) -> some View {
        #if DEBUG
        content.task(id: blockCount) {
            guard remaining > 0 else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, remaining > 0 else { return }
            remaining -= 1
            fire()
        }
        #else
        content
        #endif
    }
}
