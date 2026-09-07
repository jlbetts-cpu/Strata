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
    /// The tower shows today, and only today.
    ///
    /// Week and Month views were a filter over the same blocks; dropping them
    /// removes a control, a title that changed under you, a redundant "N today"
    /// in the header and a whole class of "why is that block here" question.
    /// The value is kept rather than the enum deleted because block chrome,
    /// patina and day separators all read it.
    /// Which span of wins the tower is showing.
    ///
    /// This was frozen to `.day` when the header lost its filter control. The
    /// filter is back — the tower is the app's one view of what you have done,
    /// so being able to see a week or a month of it belongs here — and the
    /// period label does NOT come back with it: the control names the period,
    /// so a title saying the same thing would be the same fact twice.
    @AppStorage("towerFilterMode") private var towerFilterModeRaw: String = TowerFilterMode.day.rawValue
    private var towerFilterMode: TowerFilterMode {
        get { TowerFilterMode(rawValue: towerFilterModeRaw) ?? .day }
        nonmutating set { towerFilterModeRaw = newValue.rawValue }
    }
    @State private var pendingTowerFilterMode: TowerFilterMode? = nil
    @State private var animCoord = TowerAnimationCoordinator()
    @State private var towerProbe = TowerGeometryProbe()
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

    // #386: Perfect day anticipation

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
            // This month. It returned EVERY log ever recorded, which made
            // "Month" mean "all time" and grew without bound.
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let monthStartStr = TimelineViewModel.dateString(from: startOfMonth)
            cachedFilteredLogs = logsByDate.flatMap { key, value in key >= monthStartStr ? value : [] }
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
    @State private var debugAutoChecksLeft = 0
    @State private var debugTabFlipsLeft = 0
    /// Light on every page but the camera. Held separately from `selectedTab`
    /// so it can be changed without an animation; see `mainContent`.
    @State private var windowScheme: ColorScheme = .light
    /// Bumped when leaving the camera, to force a fresh tab bar.
    @State private var tabBarGeneration = 0
    /// The habit whose sheet is open, from a long press on an outlined block.
    @State private var editingHabit: Habit?
    /// Blocks that have been logged but not yet seen falling.
    ///
    /// The drop animation used to depend on WHICH build happened to place the
    /// block: the cascade diffed the tower, and a refresh arriving first (from
    /// the habit count changing, a timer, a HealthKit verification) consumed
    /// that diff, leaving the cascade to fall back on re-deriving the log id
    /// from the habit's relationship — which sometimes came back empty. That is
    /// why the drop played most of the time and not always.
    ///
    /// An id is claimed the moment a win is logged and cleared the moment the
    /// tower places it. No diff, no ordering, no race.
    /// The size currently being drawn out of the next slot, so the slot can
    /// move to where a block of THAT size would actually land.
    @State private var drawingSize: BlockSize = .small
    @State private var nextWinCategory: HabitCategory = .health
    @State private var awaitingDropIDs: Set<UUID> = []
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
            .modifier(DebugFlipTabs(
                remaining: $debugTabFlipsLeft,
                selected: $selectedTab
            ))
            .modifier(DebugAutoCheck(
                doneCount: cachedCompletedHabitIDsForSelectedDate.count,
                remaining: $debugAutoChecksLeft,
                next: {
                    cachedAllHabitsForSelectedDate.first {
                        !cachedCompletedHabitIDsForSelectedDate.contains($0.id)
                            && !QuickWinService.isWin($0)
                    }
                },
                fire: { tickHabit($0) }
            ))
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

    /// Extracted from `mainContent`: that body is a four-Tab TabView already at
    /// the type-checker's ceiling, and removing the toolbar was enough to tip
    /// it over.
    private var towerTabRoot: some View {
        NavigationStack {
            // No navigation bar at all. The header below carries the count, and
            // there is no longer a filter to put anywhere.
            towerTab
                .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $isNewHabitMenuOpen) {
            AddWinSheet(
                modelContext: modelContext,
                tower: towerManager.activeTower,
                onSaved: { _ in scheduleRefresh() }
            )
        }
        // Long-pressing an outlined block opens the same sheet, in edit mode.
        // One sheet for making a thing and for changing it, because they are
        // the same four questions.
        .sheet(item: $editingHabit) { habit in
            AddWinSheet(
                modelContext: modelContext,
                tower: towerManager.activeTower,
                editing: habit,
                onSaved: { _ in scheduleRefresh() },
                onDeleted: { scheduleRefresh() }
            )
        }
    }

    private var mainContent: some View {
        TabView(selection: $selectedTab) {
            // Hollow when it is not the page you are on, filled when it
            // is. One glyph in two states says "here" without needing the
            // label, the colour or the pill to say it as well — and it is what
            // every tab bar on the platform does, so it needs no learning.
            Tab(value: StrataTab.tower) {
                towerTabRoot
                        } label: {
                Label("Wins", systemImage: selectedTab == .tower ? "square.stack.fill" : "square.stack")
            }
            // No badge. It counted blocks queued to drop, which is an
            // implementation detail measured in milliseconds — it flashed a
            // red notification dot on the tab you were already looking at.
            // No Today tab. The tower IS today.
            //
            // The checklist that replaced Today and Plan lasted one step,
            // because once the rows were drawn as blocks it was obvious they
            // were describing something the tower could just show. An
            // unfinished habit is now an outlined block sitting in the cell it
            // will occupy, on top of what is already built — so the whole day
            // is one picture instead of two screens that refer to each other.
            // A photo of a win, taken in the app.
            //
            // The camera is a tab rather than a step inside the add sheet
            // because taking the picture and describing the win are two
            // different moments: you photograph the thing when it happens, and
            // you can name it after. Shooting from here logs the win straight
            // away with the photo already on it.
            Tab(value: StrataTab.camera) {
                cameraTab
            } label: {
                Label("Camera", systemImage: selectedTab == .camera ? "camera.fill" : "camera")
            }
            Tab(value: StrataTab.insights) {
                insightsTabRoot
            } label: {
                Label("Insights", systemImage: selectedTab == .insights ? "chart.bar.fill" : "chart.bar")
            }
        }
        // The window's appearance, changed without an animation.
        //
        // Two things had to be true and they pulled against each other.
        //
        // It has to be ONE declaration. It was three — `.light` on the tower,
        // `.dark` on the camera, `.light` on Insights — and in a TabView the
        // content of a tab you are not looking at stays in the hierarchy, so
        // after leaving the camera its `.dark` was still being declared,
        // competing with the tower's `.light`, and which one won came down to
        // ordering. That is the appearance "not understanding it is in the
        // light again": two views were still arguing about it.
        //
        // And it must not crossfade. The tower and Insights are always light,
        // the camera is always dark; none of them is transitioning to
        // anything, so a blend through a state that never existed reads as a
        // hiccup.
        //
        // A separate value, updated in a transaction with animations disabled,
        // gets both. Deriving it inline from `selectedTab` cannot: the change
        // arrives carrying whatever transaction the tab switch brought with
        // it. An earlier attempt wrapped the SELECTION in a custom binding
        // instead — which fixed the animation and quietly broke programmatic
        // navigation, because the TabView writes its own selection back
        // through that binding on appear and overwrote anything set during
        // setup.
        .preferredColorScheme(windowScheme)
        .onChange(of: selectedTab) { _, newTab in
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                windowScheme = newTab == .camera ? .dark : .light
            }
        }
        // Rebuild the bar when the camera stops being behind it.
        //
        // The tab bar is Liquid Glass: it samples what is behind it and CACHES
        // that sample. Measured, same page and same window scheme — a tower
        // that had never shown the camera read 0.956, one that had read 0.341.
        // It was not failing to follow the scheme; it was still wearing the
        // black it picked up over the viewfinder, and nothing invalidates
        // that: not the window scheme, not
        // `toolbarBackgroundVisibility(.hidden)`, not
        // `toolbarColorScheme`, not a `UITabBarAppearance`.
        //
        // Changing the identity is the one thing that does, because it makes a
        // new bar rather than asking the old one to think again. It costs a
        // rebuild of the tab content on the way OUT of the camera only.
        .id(tabBarGeneration)
        // Black on light, white on dark.
        //
        // A single fixed colour was tried and it is worse: the best any one
        // colour can manage against BOTH the app's off-white and the
        // viewfinder's near-black is 4.33:1, and a hue that compromises for
        // two grounds looks chosen for neither. `.primary` is simply the ink
        // of whichever ground it is on — maximum contrast on both, and the
        // same colour as the icons beside it, which is what "the highlight is
        // the icon colour" meant.
        .tint(.primary)
        .modifier(TabBarCollapseModifier())
        .onChange(of: selectedTab) { oldTab, newTab in
            if oldTab == .camera && newTab != .camera {
                tabBarGeneration += 1
            }
            HapticsEngine.tick()
            if newTab == .tower && !pendingDrops.isEmpty {
                Task { await cascadeDropPendingBlocks() }
            }
            if newTab != .tower {
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
            selectedTab = .tower
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

    /// The whole header: one number, and what it counts.
    ///
    /// It has lost a filter control, a period label and a height, in that
    /// order. The tower is today only now, so the period is a constant and a
    /// constant is not information. The height was a second way of saying what
    /// the tower already shows by being tall. What is left is the count and the
    /// word for what it counts.
    ///
    /// "Wins", not "blocks": a block is what the thing is made of, a win is
    /// what it means.
    private var towerHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(towerVM.placedBlocks.count)")
                .font(.system(size: GridConstants.tallyNumeral, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.85))
                .contentTransition(.numericText())
            Text(towerVM.placedBlocks.count == 1 ? "win" : "wins")
                .font(.system(size: GridConstants.tallyWord, weight: .regular, design: .rounded))
                .foregroundStyle(.primary.opacity(0.35))
            Spacer(minLength: 0)
            TowerRangePicker(selection: Binding(
                get: { towerFilterMode },
                set: { towerFilterMode = $0 }
            ))
        }
        .animation(GridConstants.motionSmooth, value: towerVM.placedBlocks.count)
        .accessibilityElement(children: .combine)
        .padding(.horizontal, hPad)
        .padding(.top, 4)
        // Air between the count and the top of a tall tower. Without it a
        // tower that reaches the top of the scroll runs straight into the
        // number and the page reads as crowded.
        .padding(.bottom, 20)
    }

    /// Ticking a row. Exactly the path the timeline used: save first, update
    /// the cache optimistically, then queue the drop. The cascade and the
    /// tower do not know or care where the tick came from.
    private func tickHabit(_ habit: Habit) {

        timelineVM.completeHabit(habit)
        cachedCompletedHabitIDsForSelectedDate.insert(habit.id)
        if healthKitService.verifiedHabitIDs.contains(habit.id) {
            let dateStr = TimelineViewModel.dateString(from: Date())
            if let log = habit.logs.first(where: { $0.dateString == dateStr }) {
                log.verifiedByHealthKit = true
            }
        }
        pendingDrops.append(habit)
    }

    /// Extracted, like the other tab roots. `mainContent` is a three-Tab
    /// TabView already at the type-checker's ceiling — adding one parameter to
    /// the Insights call tipped it over with "unable to type-check this
    /// expression in reasonable time". See CLAUDE.md.
    private var insightsTabRoot: some View {
        NavigationStack {
            InsightsView(
                habits: Array(habits),
                logs: Array(logs),
                onAddHabit: {
                    HapticsEngine.lightTap()
                    isNewHabitMenuOpen = true
                },
                onNavigateToTower: { _ in selectedTab = .tower },
                openSettings: { showSettings = true }
            )
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

    /// The camera tab. A shot here becomes a win with that photo as its face,
    /// and the tower is where you land afterwards to watch it drop.
    private var cameraTab: some View {
        // No `.ignoresSafeArea()` here. The preview ignores it from the
        // inside; the screen needs real insets so the shutter can be placed
        // above the tab bar and the count below the notch.
        CameraView(
            onCaptured: { image in
                logWin(size: .small, photo: image)
                selectedTab = .tower
            },
            winCount: towerVM.placedBlocks.count,
            fillsScreen: true
        )
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

    /// Which multiple of ten the tower has already danced for.
    ///
    /// Seeded from the current count on first build, so opening the app on a
    /// tower that is already at thirty does not set it off.
    @State private var lastDanceMilestone: Int? = nil

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
            // Nothing sits under the tower.
            //
            // This overlay held three frosted capsules — "One more for a
            // perfect day...", a comeback banner, and a next-up pill — stacked
            // between the tower and the tab bar. Notifications on the one
            // screen that is meant to be only the tower, in `.ultraThinMaterial`,
            // which is the frosted band that belongs to blocks and to nothing
            // else. The tower stands on its reflection with the tab bar
            // directly beneath it, and that is the whole page.
            .background { WarmBackground().ignoresSafeArea() }
            // Tapping a block opens the same sheet that made it.
            //
            // It used to expand into `BlockExpansionCard` — a floating card
            // behind a frosted scrim, with the block flying into a hero image
            // through a matched-geometry effect. Handsome, and the wrong
            // shape: editing a win asks the same four questions as adding one,
            // so it should be the same sheet with the answers filled in.
            //
            // It also fixes the camera. That card reached for
            // `CameraPickerView`, which is `UIImagePickerController` — the
            // stock iOS camera, with none of this app's chrome. The sheet uses
            // the app's own viewfinder.
            .overlay {
                if expandedBlockID != nil, let milestone = pendingMilestone {
                    MilestoneCelebration(milestone: milestone) {
                        pendingMilestone = nil
                    }
                    .transition(.opacity)
                    .zIndex(200)
                }
            }
            .sheet(item: Binding(
                get: {
                    expandedBlockID.flatMap { id in
                        towerVM.placedBlocks.first { $0.id == id }
                    }
                },
                set: { if $0 == nil { dismissCard() } }
            )) { block in
                AddWinSheet(
                    modelContext: modelContext,
                    tower: towerManager.activeTower,
                    editing: block.habit,
                    editingLog: block.log,
                    onSaved: { _ in repackTower() },
                    onDeleted: { repackTower() }
                )
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
        // The placeholder arrives as one object, quietly.
        //
        // It used to pop its eight blocks in one at a time, 50ms apart, each
        // scaling up from 0.3 with a bounce — and then delete all eight the
        // moment real data arrived. On an empty tower that meant watching a
        // tower build itself out of nothing and then vanish, which is both the
        // least calm thing on the screen and a claim about your day that is
        // not true. A placeholder's job is to be unremarkable until the real
        // thing replaces it.
        if reduceMotion {
            visibleSkeletonCount = 8
        } else {
            withAnimation(GridConstants.gentleReveal) {
                visibleSkeletonCount = 8
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

    /// A block's footprint changed, so the grid repacks around it.
    ///
    /// This used to call `reloadTowerWithAnimation`, which raises `isLoading`
    /// and puts the placeholder up — so changing a block's size made the whole
    /// tower vanish into the loading skeleton, wait out a forced 300ms floor,
    /// and come back rebuilt. That is why resizing did not look like the tower
    /// rearranging: it wasn't. It was a reload wearing a resize's clothes.
    ///
    /// A resize is a layout change. The blocks move to their new places, once,
    /// in one animation, while you watch.
    private func repackTower() {
        _ = withAnimation(GridConstants.layoutReflow) {
            refreshData()
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

    /// Merge groups over SETTLED blocks only.
    ///
    /// A falling block was joining its group the moment the tower rebuilt,
    /// which is before it lands — so the destination was already painted in
    /// while the block was still in the air, and the block then passed over its
    /// own filled slot on the way down. That is the lighter patch, and it is
    /// also why the merge never looked like a merge: there was nothing left to
    /// join by the time it arrived.
    ///
    /// Costs nothing in the common case: with nothing animating this is the
    /// value the view model already computed.
    private var liveMergeGroups: [MergeGroup] {
        let animating = animCoord.activelyAnimatingIDs
        guard !animating.isEmpty else { return towerVM.mergeGroups }
        return BlockMerge.groups(
            for: towerVM.placedBlocks.filter { !animating.contains($0.id) }
        )
    }

    private var liveGroupedIDs: Set<UUID> {
        let animating = animCoord.activelyAnimatingIDs
        guard !animating.isEmpty else { return towerVM.groupedBlockIDs }
        return Set(liveMergeGroups.flatMap(\.memberIDs))
    }

    /// What of the tower reaches the water: the bottom row, as colour and
    /// width. A reflection at the base of something shows only what is nearest
    /// the surface, so nothing above row 0 contributes and nothing but position
    /// and colour survives.
    private func reflectionFacets(colW: CGFloat) -> [TowerReflection.Facet] {
        // Reflect what is DRAWN, not what is stored.
        //
        // One facet per block put a gap in the water everywhere the tower had a
        // seam — including seams that no longer exist, because a merged run is
        // one object with no gaps in it. The water was reflecting the data
        // model rather than the tower.
        //
        // Bottom-row cells are walked left to right and merged into one facet
        // wherever consecutive cells belong to the same merged group, so the
        // reflection spans the join exactly as the shape above it does.
        let bottom = towerVM.placedBlocks.filter { $0.row == 0 }
        guard !bottom.isEmpty else { return [] }

        var groupOf: [UUID: UUID] = [:]
        for group in towerVM.mergeGroups {
            for member in group.memberIDs { groupOf[member] = group.id }
        }

        // Cell index -> the block occupying it.
        var byColumn: [Int: PlacedBlock] = [:]
        for block in bottom {
            for c in block.column..<(block.column + block.columnSpan) {
                byColumn[c] = block
            }
        }

        var facets: [TowerReflection.Facet] = []
        var column = 0
        while column < GridConstants.columnCount {
            guard let block = byColumn[column] else { column += 1; continue }
            let runKey = groupOf[block.id]
            var end = column
            // Extend while the next cell is in the same merged run. A block not
            // in a group runs only as far as its own span.
            while let next = byColumn[end + 1],
                  runKey != nil ? groupOf[next.id] == runKey : next.id == block.id {
                end += 1
            }
            let startX = GridConstants.blockFrame(
                column: column, row: 0, columnSpan: 1, rowSpan: 1, cellSize: colW
            ).minX
            let endFrame = GridConstants.blockFrame(
                column: end, row: 0, columnSpan: 1, rowSpan: 1, cellSize: colW
            )
            facets.append(
                TowerReflection.Facet(
                    id: block.id,
                    x: startX,
                    width: endFrame.maxX - startX,
                    color: block.habit.displayCategory.style.baseColor
                )
            )
            column = end + 1
        }
        return facets
    }

    // MARK: - Wins

    /// Blocks that landed on the tower today — taps of the next slot plus
    /// habits completed. One honest number for what today added, rather than
    /// a count that stays still while the tower visibly grows.
    private var blocksToday: Int {
        let today = DateUtils.dateString(from: Date())
        return logs.filter { $0.dateString == today && $0.completed }.count
    }

    /// The colour the next win will be — decided ONCE, held, and handed to
    /// `logWin` unchanged.
    ///
    /// This was a computed property calling a picker that breaks ties at
    /// random, so it returned a different colour on every body evaluation: the
    /// slot flickered through colours while you dragged, and then `logWin`
    /// called it a second time, so the block that landed was a third colour
    /// again. What the slot promises is now what drops.
    private func rerollNextWinCategory() {
        #if DEBUG
        if let forced = DebugHarness.forcedWinCategory {
            nextWinCategory = forced
            return
        }
        #endif
        nextWinCategory = QuickWinService.spontaneousCategory(existing: Array(habits))
    }

    private func logWin(size: BlockSize = .small, photo: UIImage? = nil) {
        do {
            // The colour the slot has been showing, not a fresh roll.
            let win = try QuickWinService.logWin(
                size: size,
                spontaneous: nextWinCategory,
                context: modelContext,
                tower: towerManager.activeTower
            )
            rerollNextWinCategory()
            // Written before the drop is queued, so the block arrives with its
            // face on rather than growing one a moment after it lands.
            if let photo, let log = win.habit.logs.first(where: { $0.id == win.logID }) {
                let id = log.id
                let aspect = CGFloat(size.columnSpan) / CGFloat(size.rowSpan)
                let framed = ImageManager.trimmed(photo, toAspect: aspect)
                Task { @MainActor in
                    if let name = try? await ImageManager.shared.save(image: framed, for: id) {
                        log.imageFileName = name
                        try? modelContext.save()
                        scheduleRefresh()
                    }
                }
            }
            // Claim the animation up front. Whichever build ends up placing
            // this block hands it to the animator; see `enqueueArrivals`.
            awaitingDropIDs.insert(win.logID)
            // The same path a normal completion takes, so the block lands on
            // the tower identically. No refresh here: appending to pendingDrops
            // starts the cascade, and the cascade refreshes.
            pendingDrops.append(win.habit)
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
        // Before anything reads `isWin`.
        QuickWinService.migrateLegacyWins(context: modelContext)
        towerManager.ensureDefaultTower(context: modelContext)
        towerManager.loadActiveTower(context: modelContext)
        #if DEBUG
        DebugHarness.seed(context: modelContext, tower: towerManager.activeTower)
        rerollNextWinCategory()
        debugAutoWinsLeft = DebugHarness.autoWins
        debugAutoChecksLeft = DebugHarness.autoChecks
        debugTabFlipsLeft = DebugHarness.tabFlips
        if let tab = DebugHarness.startTab {
            selectedTab = tab
            windowScheme = tab == .camera ? .dark : .light
        }
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
            // The column too, so the landing is heard where it is seen.
            // `blockImpact` has always taken it and always been called without
            // it, so the stereo placement its own comment describes has never
            // once happened.
            let landedColumn = towerVM.placedBlocks.first(where: { $0.id == landedID })?.column ?? 2
            SoundEngine.blockImpact(mass: mass, column: landedColumn) // Bimodal: haptic + audio (Vroomen 2000)
            // No whole-tower compression.
            //
            // It scaled the ENTIRE stack on impact, so a landing moved every
            // block on screen at once — the tower flexing rather than standing.
            // Even at 0.3% that is several points at the top of a tall tower,
            // and it is the last thing still contradicting "one structure".
            // The landing is carried by the block that landed, the haptic and
            // the water, all of which are local to where it happened.
        }
        // Post-cascade settle — the tower exhales (Gestalt Pragnanz closure)
        animCoord.onAllDropsComplete = { [self] in
            guard !reduceMotion else { return }
            // No exhale.
            //
            // The whole tower used to scale to 1.02 and back after every
            // cascade. `towerImpactScale` is a Y scale on the entire stack
            // anchored at the bottom, so 2% on a 600pt tower throws the top of
            // it 12 points and drags every block with it — one global lurch,
            // fired on the most routine action in the app. That is the jolt.
            // apple-design.md §11: keep per-frame change under the perception
            // threshold; this was an order of magnitude over it.
            Task { @MainActor in

                // Every tenth win, the tower dances.
                //
                // The wave already existed but only a perfect day could set it
                // off, which most days are not — so the thing most worth
                // seeing almost never fired. A round number of wins is
                // something every user reaches, on their own terms, and it is
                // the tower's own count rather than a judgement about the day.
                //
                // Keyed to the milestone rather than the count, so it fires
                // once when you cross it and never again on a rebuild or a tab
                // switch.
                let wins = towerVM.placedBlocks.count
                let milestone = wins / GridConstants.danceEvery
                if wins > 0, wins % GridConstants.danceEvery == 0,
                   milestone != lastDanceMilestone {
                    lastDanceMilestone = milestone
                    try? await Task.sleep(for: .milliseconds(180))
                    HapticsEngine.reward()
                    animCoord.triggerJubilation(placedBlocks: towerVM.placedBlocks)
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
            // Enqueueing lives in refreshData, so every path gets it.
            refreshData()
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
        let hadBuiltBefore = towerVM.hasBuiltOnce
        // Seed the dance milestone from whatever is already there, so a tower
        // that opens at thirty wins does not immediately celebrate thirty.
        defer {
            if lastDanceMilestone == nil {
                lastDanceMilestone = towerVM.placedBlocks.count / GridConstants.danceEvery
            }
        }
        var droppedIDs: Set<UUID> = []
        // Insert the block and start it falling in ONE transaction.
        //
        // These used to be two: `withAnimation` commits its transaction when
        // its closure returns, so the arriving block rendered once at its slot
        // before `enqueueArrivals` moved it up to the runway — and that move,
        // landing in the next transaction, was itself animated. Filmed at
        // 60fps the block appeared in place, flew UP 163pt over 0.13s, then
        // fell back down. That is the inconsistency: every drop was playing a
        // lift it was never supposed to have, and how much of it you saw
        // depended on how the two animations happened to overlap.
        //
        // Inside one transaction the block is born at the top of the runway,
        // so there is no prior position to animate away from.
        withAnimation(GridConstants.heavySettle) {
            droppedIDs = towerVM.buildTower(from: filteredLogs, filterMode: towerFilterMode)
            // Before anything renders, so no view body ever creates one.
            animCoord.ensureStates(for: towerVM.placedBlocks.map(\.id))
            enqueueArrivals(diff: droppedIDs, hadBuiltBefore: hadBuiltBefore)
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

        // The anticipation and comeback banners are gone with the capsules
        // that displayed them; only the bookkeeping their absence still needs
        // is kept.
        let todayStr = TimelineViewModel.dateString(from: Date())
        let todayCompleted = cachedFilteredLogs.filter { $0.dateString == todayStr && $0.completed }.count
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

    /// Hands every block that just arrived to the drop animator, exactly once.
    ///
    /// The single place this happens. It runs after every build, so it does not
    /// matter which path caused the block to appear — a win, a habit completed
    /// elsewhere, a HealthKit verification, the minute timer. Whichever build
    /// places the block animates it.
    ///
    /// Not on the first build, when every block is new relative to an empty set
    /// and the whole tower would cascade on launch.
    private func enqueueArrivals(diff: Set<UUID>, hadBuiltBefore: Bool) {
        let placed = Set(towerVM.placedBlocks.map(\.id))
        let claimed = awaitingDropIDs.intersection(placed)
        awaitingDropIDs.subtract(placed)
        guard hadBuiltBefore else { return }
        var toAnimate = diff.union(claimed)
        toAnimate.subtract(animCoord.activelyAnimatingIDs)
        for id in toAnimate {
            if let block = towerVM.placedBlocks.first(where: { $0.id == id }) {
                animCoord.setFallStart(for: id, offset: fallStartOffset(for: block))
            }
            enqueueDrop(blockIDs: [id])
        }
    }

    /// How far above its slot a block has to start so that it enters the screen
    /// from off the top edge.
    ///
    /// Measured, not derived. The block's slot is `gridTopOnScreen + slotTop`
    /// in window coordinates; putting its bottom edge `dropClearance` above
    /// zero puts the whole block outside the screen, and the ScrollView clips
    /// there, so what the viewer sees is a block sliding in from above rather
    /// than one materialising in mid-air.
    private func fallStartOffset(for block: PlacedBlock) -> CGFloat {
        guard towerProbe.hasMeasured else { return -GridConstants.dropRunway }
        let frame = GridConstants.blockFrame(
            column: block.column, row: block.row,
            columnSpan: block.columnSpan, rowSpan: block.rowSpan,
            cellSize: towerProbe.cellSize
        )
        let slotTopInGrid = towerProbe.gridHeight - frame.maxY
        let slotTopOnScreen = towerProbe.gridTopOnScreen + slotTopInGrid
        // Never shorter than the old fixed runway: if the slot is already near
        // the top of the screen the fall still needs to read as a fall.
        return -max(slotTopOnScreen + frame.height + GridConstants.dropClearance,
                    GridConstants.dropRunway)
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

        // The first block used to zoom the whole tower to 1.08 for drama.
        // Eight percent moves everything on screen by up to fifty points, and
        // it fired on the one drop where the user has least idea what to
        // expect. The block's own fall and landing carry the moment; the page
        // does not need to lurch to underline it.
        if isFirstDrop && !reduceMotion {
            try? await Task.sleep(for: .milliseconds(120))
        }

        scrollToTopTrigger += 1
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s scroll settle

        // The animation is claimed in `logWin` and handed over by
        // `refreshData`, so this only has to make the tower rebuild.
        let claimed = awaitingDropIDs
        refreshData()

        // No second scroll.
        //
        // This used to centre the new block a moment after scrolling to the
        // top — two scrolls for one drop, the second firing while the block
        // was still in the air. The tower slid underneath a falling block,
        // which is both a premature animation and the tower moving when
        // nothing asked it to. Scrolling to the top already brings the slot
        // into view, because the slot is at the top of the tower.
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

        // The next slot has to be INSIDE the measured grid.
        //
        // When the top row is full the slot goes to a brand new row above it,
        // at `row == totalRows` — but the grid was measured from the placed
        // blocks alone, so that row fell outside the container. It rendered
        // (a ZStack does not clip) but it was not part of the scrollable
        // content, so the scroll view stopped at the tower's top and there was
        // no way to reach the slot. It is also why a drop into that row was
        // never seen falling: the whole fall happened above the scrollable
        // area.
        // Nothing outlined on the tower.
        //
        // Today's unfinished habits were drawn here as ghost blocks for one
        // pass. They made the tower busy — a page whose whole claim is that
        // every object on it is something you DID, carrying a second set of
        // objects that are things you have not. The tower is the record; the
        // planning lives elsewhere.
        let slotPos = towerVM.computeGhostPosition(for: drawingSize)
        let slotRows = slotPos.map { $0.row + drawingSize.rowSpan } ?? 0
        let layoutRows = rowCount > 0
            ? max(rowCount, slotRows)
            : placeholderRows
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
                        // Where the grid really is, so a fall can start above
                        // the screen. Writes to a plain object, not to state —
                        // see `TowerGeometryProbe`.
                        .onGeometryChange(for: CGRect.self) { proxy in
                            proxy.frame(in: .global)
                        } action: { rect in
                            towerProbe.gridTopOnScreen = rect.minY
                            towerProbe.gridHeight = gridH
                            towerProbe.cellSize = colW
                        }

                    if towerVM.isLoading {
                        skeletonGrid(skeletons: placeholders, colW: colW, gridH: gridH)
                    } else if towerVM.totalRows == 0 {
                        // An empty tower gets the same next slot a full one
                        // does — pressing it is how the first block arrives, so
                        // it cannot be the one state without a way to press.
                        //
                        // Only when there is nothing outlined either: a day
                        // with habits still to do is not an empty tower, it is
                        // a tower that has not been built yet.
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
                        ForEach(liveMergeGroups) { group in
                            MergedGroupView(
                                group: group,
                                cellSize: colW,
                                gridWidth: gridW,
                                gridHeight: gridH
                            )
                        }

                        placedBlocksGrid(colW: colW, gridH: gridH,
                                         viewportHeight: viewportHeight, topInset: topInset,
                                         slotPos: slotPos)

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
        }
        }
        // One fade for the whole placeholder, in and out, so it never reads as
        // eight separate things arriving and eight separate things leaving.
        .transition(.opacity)
    }

    @ViewBuilder
    private func placedBlocksGrid(colW: CGFloat, gridH: CGFloat,
                                   viewportHeight: CGFloat, topInset: CGFloat,
                                   slotPos: (column: Int, row: Int)?) -> some View {
        let visibleBlocks = visibleTowerBlocks(
            colW: colW, gridH: gridH,
            viewportHeight: viewportHeight, topInset: topInset
        )
        ZStack(alignment: .topLeading) {
            TowerBlocksForEach(
                visibleBlocks: visibleBlocks, animCoord: animCoord, towerVM: towerVM,
                groupedIDs: liveGroupedIDs,
                mergeDestinedIDs: towerVM.groupedBlockIDs,
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
            // Positioned for the size being DRAWN, not for a small block.
            //
            // Packing is append-only, so an arriving block never moves the ones
            // already placed — but a bigger block does not always fit where a
            // smaller one would, so the slot itself moves to the first gap that
            // takes it. That is the tower showing you, live, exactly where this
            // block is going to end up.
            if !animCoord.isCascading, let pos = slotPos {
                let ghostFrame = GridConstants.blockFrame(
                    column: pos.column, row: pos.row,
                    columnSpan: drawingSize.columnSpan, rowSpan: drawingSize.rowSpan,
                    cellSize: colW
                )
                NextSlotButton(
                    reduceMotion: reduceMotion,
                    cornerRadius: cornerRadius,
                    previewCategory: nextWinCategory,
                    onSizeChanged: { drawingSize = $0 },
                    action: { logWin(size: $0) },
                    onOpenMenu: { isNewHabitMenuOpen = true }
                )
                .frame(width: ghostFrame.width, height: ghostFrame.height)
                .offset(x: ghostFrame.minX, y: flippedY(for: ghostFrame, gridH: gridH))
                // No animation modifier here.
                //
                // `onSizeChanged` is already called inside a `slotSnap`
                // transaction, so this was a SECOND animation driving the same
                // change — and only this one, which meant the slot's frame and
                // offset ran on one spring while the grid height they are
                // measured against ran on another. Changing size moves the
                // slot AND grows the container by a row, and the two have to
                // be the same animation or the ghost is briefly somewhere the
                // block will not land. One transaction now covers all three.
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
            previewCategory: nextWinCategory,
            onSizeChanged: { drawingSize = $0 },
            action: { logWin(size: $0) },
            onOpenMenu: { isNewHabitMenuOpen = true }
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

            // Teaches the whole interaction in one sentence, on the one
            // screen where there is nothing else to read. Both halves of the
            // rule — tap does it, hold plans it — and after that the gestures
            // are the same everywhere: tapping an outlined block marks it
            // done, holding one edits it.
            Text("Hold the empty block to record something you did.\nTap it to plan something instead.")
                .font(Typography.bodySmall)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // No "or plan your day". There is nowhere else to go: planning
            // is adding an outlined block to this same tower.
            Button {
                HapticsEngine.lightTap()
                isNewHabitMenuOpen = true
            } label: {
                Text("or add something now")
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
        /// Members of a merged run, computed over settled blocks only so a
        /// falling block does not join its group before it lands.
        let groupedIDs: Set<UUID>
        /// Blocks that WILL be part of a merged run once they settle,
        /// including ones still in the air.
        let mergeDestinedIDs: Set<UUID>
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
            // Read the dance's phase counter here, at the top of the grid's
            // body, so a phase change is guaranteed to invalidate it. Reading
            // the per-block values inside the ForEach closure below is not a
            // dependency SwiftUI reliably attributes to this body — which is
            // exactly why the wave ran to completion without moving anything.
            let _ = animCoord.danceTick
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
                    isGroupMember: groupedIDs.contains(block.id),
                    willMerge: mergeDestinedIDs.contains(block.id),
                    isCovered: towerVM.coveredBlockIDs.contains(block.id),
                    onTapExpandBlock: onTapExpandBlock
                )
                .frame(width: f.width, height: f.height)
                // The dance has to be read HERE.
                //
                // These three lived inside `AnimatedBlockView`, which is an
                // `Equatable` view. Its `==` cannot see them — they live on a
                // shared reference the two sides hold in common — so nothing
                // ever invalidated the child and the wave never reached the
                // screen: the coordinator set `jubilationLift = -10` on every
                // block and the foundation moved one pixel in a whole run.
                // The drop phases only worked because this grid happens to
                // read `dropPhase` below, for `zIndex`, which re-renders the
                // row. Reading the dance here gives it the same guarantee
                // instead of the same accident.
                .rotationEffect(.degrees(animState.jubilationWobble))
                .offset(y: animState.jubilationLift)
                .brightness(animState.jubilationGlow)
                .id(block.id)
                .offset(x: f.minX, y: gridH - f.minY - f.height)
                .zIndex(animState.dropPhase != nil ? 100 : Double(block.row + 1))
                .accessibilitySortPriority(-Double(block.row))
                // A newly dropped block gets NO insertion transition. It was
                // fading in over 0.2s while simultaneously falling, so the
                // first half of the fall happened at low opacity and what you
                // saw was the block appearing near its slot — "it just spawns
                // in and then there's a ripple". It is opaque from the first
                // frame and the fall is the whole of its entrance.
                .transition(isNewlyDropped
                            ? .identity
                            : .opacity.animation(.easeOut(duration: 0.2).delay(stagger)))
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
        /// True once this block has settled into a merged run.
        /// True as soon as the tower knows it BELONGS to one, even mid-flight.
        let willMerge: Bool
        let isCovered: Bool
        let onTapExpandBlock: (UUID) -> Void

        @Environment(\.modelContext) private var modelContext

        static func == (lhs: Self, rhs: Self) -> Bool {
            // The habit's own properties MUST be in here. Comparing only the
            // id and the frame meant a category change — same block, same
            // slot — compared equal, so SwiftUI skipped the redraw and the new
            // colour did not appear until something else forced a rebuild.
            // That is "editing a block only takes effect when I add another".
            lhs.block.id == rhs.block.id
            && lhs.block.habit.displayCategory == rhs.block.habit.displayCategory
            && lhs.block.habit.title == rhs.block.habit.title
            && lhs.block.habit.blockSize == rhs.block.habit.blockSize
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
            && lhs.willMerge == rhs.willMerge
            && lhs.isCovered == rhs.isCovered
        }



        var body: some View {
            let phase = animState.dropPhase
            let isAnimating = phase != nil
            let isNew = isAnimating || isNewlyDropped
            let mass = CGFloat(block.habit.blockSize.massTier)

            let dropOffset: CGFloat = switch phase {
            case .falling:
                // Captured once, when the drop was queued, from where this
                // block actually sits on screen — far enough above the top edge
                // that it enters from outside the screen rather than appearing
                // in mid-air. See `fallStartOffset(for:)`.
                //
                // Every earlier version of this line computed the start from
                // the world WHILE the block was in the air, and each one made
                // the drop inconsistent in its own way: from `towerScrollOffset`
                // it varied fourfold with the scroll position; from `gridH` it
                // jerked upward one row-pitch on the drops that completed a row;
                // as a constant above the SLOT it started low on a short tower,
                // which is what read as blocks coming up from the bottom.
                animState.fallStartOffset
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

            // No impact flash on a block that is about to become part of a
            // larger shape.
            //
            // Filmed at 60fps: the landed block sat 6% brighter than the mass
            // it was joining for the whole squash phase, and the crossfade then
            // had to fade that difference out — which is the "lighter patch"
            // that made the merge visible. A block that is merging has no
            // separate surface to flash; the shape it joins is the thing that
            // took the impact.
            let flashBrightness: Double = (phase == .squash && !willMerge) ? 0.06 : 0

            // The landing shadow goes too, for the same reason: it drew an
            // outline around a block that is supposed to be dissolving into its
            // neighbours. It keeps the FALLING shadow — in the air it is still
            // a separate object.
            let (dropShadowRadius, dropShadowY): (CGFloat, CGFloat) = switch phase {
            case .falling: (12, 8)
            case .squash: willMerge ? (0, 0) : (1, 0.5)
            case .stretch: willMerge ? (0, 0) : (3, 1.5)
            case .wobble: willMerge ? (0, 0) : (4, 2)
            case .none: (0, 0)
            }

            let isRippling = animState.isRippling
            let ri = animState.rippleIntensity
            // Compression only — no downward shift.
            //
            // The blocks also moved DOWN by up to 2.5pt when rippled, which on
            // the bottom row (where intensity is highest and there is nothing
            // below to move into) read as the foundation jerking downward. A
            // block being compressed already says it took weight; sliding it
            // down as well says the tower sank, which it did not.
            //
            // Halved as well: apple-design.md §11 asks that per-frame change
            // stay under the perception threshold, and 5% of a block's height
            // in one spring was over it.
            let rippleScaleX: CGFloat = isRippling ? 1.0 + 0.015 * ri : 1.0
            let rippleScaleY: CGFloat = isRippling ? 1.0 - 0.025 * ri : 1.0
            let rippleOffsetY: CGFloat = 0

            let isExpanded = expandedBlockID == block.id

            ZStack {
                // The empty socket shows only while the block is ABOVE it.
                //
                // It was drawn for `isNew`, which stays true for two seconds
                // after the drop — so a translucent material square sat on top
                // of the tower long after the block had landed in it. On a
                // merged run that is a pale patch in the middle of the shape,
                // which is what still made the join obvious after the colour
                // and the chrome had been matched. Filmed at 60fps it was
                // steady, not fading, which is what gave it away: a crossfade
                // artifact would have decayed.
                if phase == .falling {
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
                    // Chrome goes the moment it touches down, not when the
                    // crossfade finishes — the rim is what was still drawing a
                    // boundary through the middle of one shape.
                    chromeless: willMerge && phase != .falling,
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
                // Foundation darkening removed.
                //
                // Measured: a merged shape rendered (14,173,116) and a
                // standalone block of the same colour (9,168,111). The entire
                // difference was this 2% — a merged run draws one flat fill and
                // never had it. So a block landing into a group visibly
                // lightened at the moment it joined, which is precisely the
                // thing a merge must not do. Two percent was never legible as a
                // depth cue on its own, and the contact shade does that job
                // properly now.
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
            // No per-row parallax.
            //
            // Higher rows used to shift more than lower ones as the tower
            // scrolled, as a depth cue. It is the one effect that directly
            // contradicts the tower being a single structure: the rows slide
            // against each other, and because `towerScrollOffset` is only
            // republished in 8pt steps it did it in visible jumps rather than
            // smoothly. The tower moves as one object or it is not one object.
            // The dance is applied by the grid, not here. See `placedBlocksGrid`.
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

/// Ticks checklist rows without a finger, so the tick-to-block loop can be
/// filmed on a machine that cannot tap.
private struct DebugAutoCheck: ViewModifier {
    let doneCount: Int
    @Binding var remaining: Int
    let next: () -> Habit?
    let fire: (Habit) -> Void

    func body(content: Content) -> some View {
        #if DEBUG
        content.task(id: doneCount) {
            guard remaining > 0 else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, remaining > 0, let habit = next() else { return }
            remaining -= 1
            fire(habit)
        }
        #else
        content
        #endif
    }
}

/// Flips between the tower and the camera on a timer, so the appearance swap
/// can be filmed on a machine that cannot tap.
private struct DebugFlipTabs: ViewModifier {
    @Binding var remaining: Int
    @Binding var selected: StrataTab

    func body(content: Content) -> some View {
        #if DEBUG
        content.task(id: remaining) {
            guard remaining > 0 else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, remaining > 0 else { return }
            remaining -= 1
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selected = selected == .camera ? .tower : .camera
            }
        }
        #else
        content
        #endif
    }
}
