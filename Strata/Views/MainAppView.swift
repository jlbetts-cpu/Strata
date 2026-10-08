import SwiftUI
import SwiftData
import Combine
import CoreSpotlight

/// **What the app is called, asked of the bundle rather than typed out.**
///
/// Found 2026-10-01, photographing the camera's refused state: the built
/// `Info.plist` carries `CFBundleDisplayName` **Some Wins** and `CFBundleName`
/// **Strata**, and a sentence on that screen read "Turn the camera on for
/// Strata in Settings". The home screen says Some Wins, the Settings row says
/// Some Wins, and the app was naming a row that does not exist — on the one
/// screen whose whole job is to send somebody to that row.
///
/// `CLAUDE.md` records the wordmark being off "pending the RENAME", and this is
/// the other half of the same thing: the drawing came off and the WORDS did
/// not. Asking the bundle fixes every name at once and survives the next one,
/// which is the point — a hard-coded "Some Wins" would be the same bug again with
/// a different spelling.
///
/// `CFBundleDisplayName` first, because that is the one iOS prints under the
/// icon and in the Settings list; `CFBundleName` is the fallback, and the
/// literal is there only so a missing key cannot produce a sentence with a
/// hole in it.
///
/// **The fallback said "Strata" until 2026-10-02**, which is the name the app
/// had before it was renamed: a missing key would have printed the OLD name
/// into a sentence. Twenty-one other user-facing strings across the app said it
/// too, two of them sending people to look for a Settings entry that does not
/// exist under that name; all of them say Some Wins now.
enum AppName {
    static let display: String =
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
        ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
        ?? "Some Wins"
}

// MARK: - Landing from a notification

/// A tapped notification's tab (`NotificationRoute`): the daily reminder on
/// Wins, the past win and the replays on Memories, which then shows the day
/// or plays the replay itself. A modifier because `mainContent` is at the
/// type checker's ceiling.
private struct NotificationLanding: ViewModifier {
    @Binding var selectedTab: StrataTab
    private var router: LandingRouter { LandingRouter.shared }

    func body(content: Content) -> some View {
        content
            .onChange(of: router.pending) { _, route in land(route) }
            // A cold launch from the notification: the tap arrived before
            // this view did.
            .onAppear { land(router.pending) }
    }

    private func land(_ route: NotificationRoute?) {
        guard let route else { return }
        switch route {
        case .wins: selectedTab = .tower
        case .memories, .memoriesDay, .replay: selectedTab = .memories
        case .crew: break
        }
        router.pending = nil
    }
}

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
    /// The minute refresh's clock, made once.
    ///
    /// It was `Timer.publish(...).autoconnect()` written inside `body`, which
    /// built a new publisher on every evaluation; `onReceive` resubscribes
    /// when handed a different one, so the minute restarted each time the
    /// view updated and could go unfired while the tower was busy. A
    /// `static let` is the same publisher every time. Not a `.task` loop:
    /// that captures the view as it was when the task began, and the handler
    /// reads `scenePhase` and `logs`, which must be current.
    private static let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(FocusFilterService.self) private var focusFilterService
    @State private var towerVM = TowerViewModel()
    @State private var timelineVM = TimelineViewModel()
    @State private var towerManager = TowerManager()
    /// The tower, not the camera (the owner, 2026-10-06: "i think I want it
    /// to open up on the wins screen now on app launch instead of the
    /// camera"). It opened on the viewfinder because a photo is the fastest
    /// way to log a win; the tower is today's wins and the empty slot, so it
    /// shows what you have done and still logs a win in one tap.
    /// The tab the app opens on. A constant so the window's colour scheme can
    /// be seeded from the same value rather than a second copy of it.
    private static let launchTab: StrataTab = .tower

    /// Which tab the app opens on.
    ///
    /// **`.tower`**, always, and on the launch right after onboarding as
    /// well: that one was already the tower, so a new user's first block is
    /// the first thing they see.
    ///
    /// It is the INITIAL value rather than a `selectTab` call during `setup()`
    /// because that does not stick — CLAUDE.md records it: the `TabView`
    /// writes its own selection back through the binding on appear and
    /// overwrites anything set during setup. Measured here too: the tab was
    /// set and the app still opened on the camera. Nothing can overwrite a
    /// value that was never anything else.
    static func initialTab() -> StrataTab {
        // **`-strataStartTab` is answered HERE, and it was not** (found
        // 2026-10-01, by photographing a screen on a simulator the app had
        // never run on before).
        //
        // The flag was only read in `setup()`, which calls `selectTab` — and
        // the paragraph directly above says why that cannot work: the `TabView`
        // writes its own selection back through the binding on appear and
        // overwrites anything set during setup. So the flag did nothing, and
        // every capture that appeared to obey it obeyed `welcomeWinKey`
        // instead, which is set on any simulator the app has been used on.
        // That is the worst kind of broken fixture: it works on the machine it
        // was written on and silently photographs the wrong tab everywhere
        // else. `-strataStartTab camera` "worked" for the same wrong reason in
        // reverse, on a fresh container where `.camera` was the default anyway.
        #if DEBUG
        if let wanted = DebugHarness.startTab { return wanted }
        #endif
        return launchTab
    }

    /// Set when onboarding finishes; consumed by `dropWelcomeWinIfNeeded`.
    static let welcomeWinKey = "pendingWelcomeWin"

    /// Live ripples on the page's own surface. Swept as they die.
    @State private var touchRipples: [TouchRipple] = []
    @State private var selectedTab: StrataTab = MainAppView.initialTab()
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
    /// The tower is today. Not a setting.
    ///
    /// This used to be `@AppStorage("towerFilterMode")` driven by a
    /// Day / Week / Month picker in the header — and when the share button
    /// replaced that picker, the stored value kept driving the tower with
    /// nothing left to change it. Anyone whose value happened to be Week or
    /// Month was permanently stuck looking at a month of blocks with a date
    /// and a count printed under them, and no way back.
    ///
    /// It is a constant now because the product answer is not "make the
    /// picker reachable again": the tower is the record of TODAY, and other
    /// days are what History is for. The stale key is cleared on launch so
    /// existing installs recover.
    private let towerFilterMode: TowerFilterMode = .day
    @State private var animCoord = TowerAnimationCoordinator()
    /// The landing the lattice is answering, if any. Cleared as soon as the
    /// ring has finished, so the surface goes back to drawing nothing: with
    /// nothing here `TowerLattice` builds no ring cells at all.
    @State private var latticeRipple: LatticeRipple?
    @State private var towerProbe = TowerGeometryProbe()
    /// What the widget was last handed. Not observed: see `WidgetPublisher`.
    @State private var widgetPublisher = WidgetPublisher()

    // Drop queue: habits completed in timeline, awaiting tower release
    @State private var pendingDrops: [Habit] = []

    /// The block whose edit sheet is open. It also hides that block on the
    /// tower while the sheet is up (`AnimatedBlockView`).
    @State private var expandedBlockID: UUID? = nil

    @State private var showTowerConfetti = false
    @AppStorage("lastCelebrationDate") private var lastCelebrationDate: String = ""


    // New habit menu
    /// What the add sheet is being opened WITH.
    ///
    /// This used to be three separate pieces of `@State` behind an
    /// `isPresented` flag, and the flag lost its payload: measured, the plan
    /// line's text was set correctly and then read back as nil when the sheet
    /// was built, because swapping one sheet for another runs the incoming
    /// sheet's `onDismiss` during reconciliation and that is what cleared it.
    ///
    /// `.sheet(item:)` makes the payload the identity of the presentation, so
    /// there is nothing left for anything else to null out.
    @State private var winDraft: WinDraft?
    /// **The day's cue over the slot** (`WinCue`), while it is up, and where
    /// the slot is on screen for it to rise from.
    @State private var winCue: String?
    @State private var slotFrame: CGRect = .zero
    @AppStorage(WinCue.defaultsKey) private var winCueDay = ""
    @AppStorage(DailyGoal.defaultsKey) private var dailyGoal = DailyGoal.standard
    /// **The goal everything on Wins asks**: the crest, the cue, the dance
    /// and the booth. It was your three on a Hard day; Hard day is gone
    /// (2026-10-07), so it is the number you set.
    private var todaysGoal: Int { dailyGoal }
    /// The booth, open: printing (the goal was just reached) or not.
    @State private var booth: BoothOpening?
    @State private var showsYourDay = false
    /// The one tip ask, after a booth closes (`TipJar.takeAsk`).
    @State private var showsTipAsk = false
    @AppStorage("stripPrintedDay") private var stripPrintedDay = ""
    @State private var eveningDecided = ""
    /// Held while the plan sheet is still on screen, and promoted to
    /// `winDraft` once it has finished dismissing.
    @State private var pendingDraft: WinDraft?
    /// A plan line ticked optimistically, still waiting to become a block.
    ///
    /// **The tick has to be able to go back.** Pressing a line checks it
    /// immediately, which is right — the alternative leaves the commonest
    /// gesture in the sheet with no visible result until two screens later.
    /// But nothing ever un-checked it, so cancelling the add sheet left a
    /// finished line with no block behind it, and the plan claimed something
    /// that had not happened.
    @State private var tickAwaitingWin: UUID?
    /// The add sheet open now came from a plan line: closing it reopens the
    /// day's sheet on the Plan.
    @State private var returnsToPlan = false
    /// The orphan sweep runs once a launch, not once a refresh.
    @State private var hasPrunedImages = false
    /// The day's sheet is up (`DaySheet`, a Plan tab and a Journal tab).
    @State private var isPlanning = false
    /// The tab it opens on: the one used last, unless that is the Journal and
    /// Lock Journal was refused, which opens the Plan (`DayTabs.opening`).
    @State private var dayOpeningTab: DayTab = .plan
    /// The tab used last, written by the sheet's switch. Default Plan.
    @AppStorage(DayTabs.defaultsKey) private var lastDayTab = DayTab.plan.rawValue

    // Skeleton build-up animation
    @State private var visibleSkeletonCount: Int = 0
    @State private var skeletonBuildTask: Task<Void, Never>?
    /// When the placeholder went up, or nil when it has not.
    @State private var skeletonShownAt: ContinuousClock.Instant?
    @State private var reloadTask: Task<Void, Never>?

    // Setup guard
    @State private var hasSetUp = false

    // Timer guard (Phase 1D)
    @State private var lastLogCount: Int = 0
    @State private var refreshTask: Task<Void, Never>?

    // Cached timeline computed properties (Phase 2A/2B)
    @State private var cachedAllHabitsForSelectedDate: [Habit] = []
    @State private var cachedCompletedHabitIDsForSelectedDate: Set<UUID> = []

    // Timeline selected date (defaults to today)
    @State private var timelineSelectedDate: Date = Date()

    // Cached incomplete timeline habits

    // Cached computed properties
    @State private var cachedFilteredLogs: [HabitLog] = []
    @State private var perfectDayDates: Set<String> = []

    // Deep link from Spotlight
    @State private var deepLinkHabitID: UUID? = nil

    // Spotlight indexing debounce
    @State private var spotlightIndexTask: Task<Void, Never>?
    @State private var lastIndexedHabitCount: Int = 0
    @State private var scrollToTopTrigger = 0
    /// The tower's scroll position, as far as block culling needs it.
    ///
    /// **Published only when culling can apply** (more than
    /// `cullThreshold` blocks), and then only in half-viewport steps. It was
    /// written every 8pt of scroll and passed into every block view, whose
    /// `==` compared it, so each write re-evaluated every block's body: 884
    /// block bodies a second over a scripted fling of a 60-block tower, for a
    /// value no block drew with. The raw offset lives on `towerProbe`, which
    /// is not observed, and is copied in here when culling starts.
    ///
    /// Nil until it has been published once. Until then the cull reads the
    /// probe's live value: the first culling body runs before the `onChange`
    /// that would have copied it in, so a stored 0 there culled against the
    /// top of the tower wherever it was scrolled.
    @State private var towerScrollOffset: CGFloat?
    /// Above this many blocks the tower culls what is off screen.
    private static let cullThreshold = 120
    @State private var screenHeight: CGFloat = 0
    @State private var currentColW: CGFloat = 82 // Default for iPhone 15 Pro — geometryTracker recalculates on appear
    @State private var safeAreaTop: CGFloat = 0
    @State private var safeAreaBottom: CGFloat = 0

    private let hPad: CGFloat = GridConstants.horizontalPadding

    /// The tower's own width — what the header aligns to.
    private var towerGridWidth: CGFloat {
        CGFloat(columns) * currentColW + CGFloat(columns - 1) * spacing
    }
    private let spacing: CGFloat = GridConstants.spacing
    private let columns = GridConstants.columnCount
    private let cornerRadius: CGFloat = GridConstants.cornerRadius
    private let collapsedHeaderHeight: CGFloat = 0

    private var filteredLogs: [HabitLog] { cachedFilteredLogs }

    private func recomputeFilteredLogs(logsByDate: [String: [HabitLog]]) {
        let todayStr = TimelineViewModel.dateString(from: Date())
        cachedFilteredLogs = logsByDate[todayStr] ?? []
        if let activeTowerID = towerManager.activeTower?.id {
            cachedFilteredLogs = cachedFilteredLogs.filter { $0.habit?.tower?.id == activeTowerID }
        }
    }

    /// Set by `-strataOpenSheet block`: expand the first block once the tower
    /// has finished building, since a block card is only reachable by tapping.
    /// Always present, only ever set in DEBUG — a `#if` around a @State that
    /// something in `body` binds to costs more than the property does.
    @State private var wantsDebugExpand = false
    /// `-strataOpenReplay`: the replay opened on launch. DEBUG only.
    @State private var debugReplay: Replay?
    /// Whether the launch-opened replay is a sample (bundled faces, no close
    /// gate on real data) or the user's own wins. Read once, at the moment
    /// `debugReplay` is set, by `DebugReplayCover`.
    @State private var debugReplayIsSample = true
    /// The next moment a replay window opens or closes. The reminder is
    /// re-scheduled there once, so an edge that passes with the app open
    /// (Sunday 5pm, Tuesday as it starts, the last day 5pm, the 3rd) is not
    /// missed and does not need a polling timer.
    ///
    /// **`liveReplay` and `playingReplay` went with the pill** (2026-10-01).
    /// Replays live in Memories now; this screen no longer offers one, so the
    /// period it would have offered is not state this view has to hold, and
    /// `ReplayLoader.hasWins`'s two fetch counts are off `refreshData`, which
    /// is called from a 60s timer.
    @State private var replayEdge: Date?
    /// `logs.count` and the tower's block count when the reminder was last
    /// re-scheduled from `refreshData()`. A win deleted or un-done drops no
    /// block, so without these a period that lost its last win kept its
    /// notification.
    @State private var replayDecidedCounts: [Int]?
    @State private var debugAutoWinsLeft = 0
    @State private var debugAutoChecksLeft = 0
    @State private var debugTabFlipsLeft = 0
    /// Light on every page but the camera. Held separately from `selectedTab`
    /// so it can be changed without an animation; see `mainContent`.
    ///
    /// Seeded from the tab the app OPENS on, not hardcoded to `.light`. It was
    /// only ever updated by `.onChange(of: selectedTab)` — and once the app
    /// started opening on the camera, the tab never changed, so the change
    /// never fired and the window stayed light behind a black viewfinder. The
    /// tab bar's icons came up black on black.
    @State private var windowScheme: ColorScheme? = MainAppView.scheme(for: MainAppView.initialTab())
    /// The scheme the tab bar's pictures are drawn for (`StrataTab.label`):
    /// the window's, when it forces one, or the system's.
    @Environment(\.colorScheme) private var systemScheme
    private var barScheme: ColorScheme { windowScheme ?? systemScheme }

    /// The one place that decides. Both the initial value and every later
    /// change go through it, so they cannot disagree.
    /// What the window's appearance should be on a given tab.
    ///
    /// **`nil` means "follow the system"**, which is what every tab but the
    /// camera now does. It used to force `.light` everywhere — the light-only
    /// conversion — and the owner's call is that "we should make the design
    /// work in both dark and light mode while still keeping the etheral vibe".
    /// An app that refuses the system appearance is not ethereal, it is just
    /// loud in one direction.
    ///
    /// The camera stays pinned to `.dark` and that is not an exception to the
    /// rule, it is the rule: a viewfinder is a dark room whatever the phone is
    /// set to, and its chrome is white type over a live image in both.
    private static func scheme(for tab: StrataTab) -> ColorScheme? {
        tab == .camera ? .dark : nil
    }
    /// The block currently being carried, and the one it would land on.
    // MARK: - Rearranging the tower
    // **NOTHING BELOW CAN RUN ANY MORE.** (2026-09-28)
    //
    // Every one of these was reached from `.draggable` on a placed block, and
    // that gesture was removed at the owner's request; the grid's own comment at
    // the block says why. They are left in the tree rather than cut out because
    // they are interleaved with a page of unrelated view code and a block delete
    // took eight things with it that had nothing to do with rearranging. Removing
    // them is a sweep of its own, with a build between each one.
    //
    // Until then: `carriedBlockID` is never written, so `isRearranging` is always
    // false and its three guards always take the other branch.
    //
    // The first version of this was wrong twice over and both are worth
    // writing down.
    //
    // It read "which block is under the finger", moved the carried block to
    // that block's index, and repacked on release — so you could not see what
    // you were going to get until you had it, and a 2x2 or a merged run covers
    // several cells, which made "the block under the finger" often not the one
    // meant.
    //
    // Worse, it was a `DragGesture`, and any gesture attached inside the
    // tower's ScrollView takes the touch away from it. High priority,
    // simultaneous, and a long press sequenced before a drag were all tried
    // and all three stopped the tower scrolling: a UI test swiping a 44-block
    // tower measured 0.0pt with a gesture attached and a clean scroll without
    // one. Reordering now goes through the system's drag and drop, which is
    // the mechanism scroll views were built to coexist with. See `BlockMove`.
    // MARK: - Rearranging the tower
    //
    // Dragging a block does not pick it up. The block leaves its slot, the
    // tower reorganises live to show where it would land, and letting go keeps
    // that arrangement — so what you see before you release is what you get.
    // Dragging away and releasing puts it back.
    //
    // Nothing is written to SwiftData until the drop. The proposal lives
    // entirely in `previewOrder`, because an unrelated `context.save()` — a
    // HealthKit verification, a win logged from a Shortcut — would otherwise
    // persist an arrangement the user never released.

    /// The block being carried, or nil when nothing is being rearranged.
    @State private var carriedBlockID: UUID?
    /// The committed order, snapshotted at lift. What a cancel returns to.
    /// The order IS the whole state of an arrangement: `buildTower` derives
    /// every coordinate from the sequence.
    @State private var committedOrder: [UUID] = []
    /// The order currently on screen. Nil means "showing the committed one".
    @State private var previewOrder: [UUID]?
    /// The block the finger is over. Internal — it has no visual of its own.
    @State private var hoverTargetID: UUID?
    /// Fires the restore when the finger stays off every block. Cancelled by
    /// any new hover, and by a drop.
    @State private var restoreTask: Task<Void, Never>?

    /// The tower is being rearranged. Read at the top of the grid's body so
    /// SwiftUI cannot miss it — not inside the memoised block view, for the
    /// reason CLAUDE.md gives about `Equatable` views and observable state.
    private var isRearranging: Bool { carriedBlockID != nil }
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
    @State private var winSaveFailed = false
    /// Reset All Data did not commit. Nothing was deleted. Only for a reset
    /// that does not run from a sheet (the harness); Settings shows its own,
    /// because an alert here cannot appear over the Profile sheet.
    @State private var resetFailed = false
    /// Which tab's header opened Profile, if any. See `profileBinding(for:)`.
    @State private var profileOrigin: StrataTab?
    /// `-strataOpenSheet settings`: open Profile and push on to Settings.
    @State private var profileOpensSettings = false
    // `showDataFallbackAlert` was here. It was an alert over a working-looking
    // tower saying nothing would be saved between sessions, and somebody who
    // tapped OK could log four wins and lose all four. The store's third
    // outcome is now a screen INSTEAD of the app (`StoreUnavailableView`, put
    // up by `StrataApp`), so by the time this view exists the store is open and
    // there is nothing for an alert to say.

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
            .modifier(DebugReplayCover(replay: $debugReplay, isSample: debugReplayIsSample))
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
                animCoord.clearAnimationStates() // #430: Clear stale animation on filter change
                reloadTowerForFilterChange()
            }
            .onReceive(Self.minuteTimer) { _ in
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
                    focusFilterService.refresh()
                    SpotlightIndexer.reindex(container: SharedModelContainer.shared)
                    // Keep a fortnight of reminders ahead. See `DailyReminder`.
                    if reminderOn {
                        Task { await DailyReminder.schedule(hour: reminderHour, minute: reminderMinute,
                                                            loggedToday: blocksToday > 0) }
                    }
                    refreshReplayWindow()
                } else {
                    // **Leaving the app is the moment before the home screen
                    // is looked at.** The snapshot was only ever published
                    // from `refreshData`, which runs while you are still in
                    // here — so a win logged and then swiped away from could
                    // reach the widget late: "widget doesnt update fast when
                    // you add a win for the home widget."
                    //
                    // Free when nothing changed, because the publish
                    // compares with the snapshot it last wrote before writing,
                    // and only then asks WidgetKit to reload. A reload request is the thing the system
                    // throttles; a no-op is not one.
                    publishWidgetSnapshot()
                }
            }
            // One sleep to the next window edge, where the reminder is
            // re-scheduled, which sets the edge after it and restarts this.
            // Cancelled with the view; a wake that comes a moment early sleeps
            // the rest.
            .task(id: replayEdge) {
                guard let edge = replayEdge else { return }
                while Date() < edge {
                    do { try await Task.sleep(for: .seconds(max(edge.timeIntervalSinceNow, 0.01))) } catch { return }
                }
                refreshReplayWindow()
            }
            .alert("Nothing was deleted", isPresented: $resetFailed) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("\(AppName.display) could not reset your data, so every win and photo is still here. Try again.")
            }
            .alert("Couldn't save that win", isPresented: $winSaveFailed) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Nothing was added. Try again.")
            }
    }

    /// Extracted from `mainContent`: that body is a four-Tab TabView already at
    /// the type-checker's ceiling, and removing the toolbar was enough to tip
    /// it over.
    private var towerTabRoot: some View {
        NavigationStack(path: $crewPath) {
            // No navigation bar at all. The header below carries the count, and
            // there is no longer a filter to put anywhere.
            towerTab
                .toolbar(.hidden, for: .navigationBar)
                .modifier(CrewDestinations(path: $crewPath,
                                           addWin: { winDraft = WinDraft(crews: [$0]) },
                                           logWin: { logCrewWin(size: $1, colour: $2, to: $0) }))
        }
        // The first-win invitation (`FirstWinInvite`): once after your very
        // first win, once more after your first reaction, never again.
        .modifier(FirstWinInvitePrompt(blockCount: towerVM.placedBlocks.count,
                                       crewPath: $crewPath,
                                       towerCard: { shareCard() }))
        // The add sheet opens from the plan's DISMISSAL, not from the same
        // closure that closes it. Setting `isPlanning = false` and
        // Setting one flag false and another true together asks UIKit to present a sheet
        // while another is still dismissing, and the second one is silently
        // dropped — which is exactly what happened: the line was tapped, the
        // plan closed, and nothing opened.
        // The add sheet opens from the plan's DISMISSAL, not from the same
        // closure that closes it. Asking UIKit to present a sheet while
        // another is still dismissing drops the second one silently.
        .sheet(isPresented: $isPlanning, onDismiss: {
            if let pending = pendingDraft {
                winDraft = pending
                pendingDraft = nil
            }
        }) {
            // **The day's sheet: a Plan tab and a Journal tab** (the owner,
            // 2026-10-05). It replaced the Plan sheet and today's Journal
            // sheet, then was one mixed page for an evening.
            DaySheet(dateString: DateUtils.dateString(from: Date()),
                     tabs: .wins, opening: dayOpeningTab, onThree: { three in
                // One of your three, from the top of the plan: written in the
                // add sheet, small, in its colour (a typed one with no colour
                // takes the one it was last logged in, as the ideas do).
                let colour = three.category
                    ?? WinIdeas.candidates(context: modelContext).three
                        .first { $0.title.lowercased() == three.id && !$0.keepsColour }?.category
                pendingDraft = WinDraft(title: three.title, size: .small, colour: colour)
                returnsToPlan = true
                isPlanning = false
            }) { item in
                // Hand the line to the add sheet rather than completing it
                // here: a win needs a size and a colour, and the block has to
                // be dropped rather than ticked.
                pendingDraft = WinDraft(title: item.text, size: item.size, colour: item.category,
                                        planItemID: item.id)
                tickAwaitingWin = item.id
                returnsToPlan = true
                isPlanning = false
            }
            // **Keyed on the opening tab.** The sheet's content is built
            // before `openDay` has picked the tab, and a `@State` keeps the
            // first value it is given, so a day last left on the Journal
            // reopened on the Plan. A new opening is a new sheet.
            .id(dayOpeningTab)
        }
        .sheet(item: $winDraft, onDismiss: {
            let saved = tickAwaitingWin == nil
            // Closed without saving: put the line back the way it was.
            if let id = tickAwaitingWin {
                setPlanItemDone(id, false)
                tickAwaitingWin = nil
            }
            // **Back to the plan it came from** (the owner, 2026-10-06).
            // Ticking three lines was three trips: tick, Add, open the plan
            // again. A saved win gets a moment to drop onto the tower first;
            // backing out goes straight back. From the dismissal, as the add
            // sheet itself opens from the plan's.
            if returnsToPlan {
                returnsToPlan = false
                Task { @MainActor in
                    if saved { try? await Task.sleep(for: .milliseconds(900)) }
                    dayOpeningTab = .plan
                    isPlanning = true
                }
            }
        }) { draft in
            AddWinSheet(
                modelContext: modelContext,
                tower: towerManager.activeTower,
                initialTitle: draft.title,
                initialPhoto: draft.photo,
                initialSize: draft.size,
                initialPlace: draft.place,
                initialCrop: draft.crop,
                initialColour: draft.colour,
                initialCrews: draft.crews,
                onSaved: { habit in
                    if let id = draft.planItemID {
                        // The win remembers the line, so deleting it later can
                        // put the line back.
                        habit.planItemID = id
                        setPlanItemDone(id, true)
                        // Saved, so the tick is earned and must not be undone
                        // by the dismissal that follows.
                        tickAwaitingWin = nil
                    }
                    scheduleRefresh()
                }
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

    /// The tower as the 9:16 share card, for an invitation's picture.
    private func shareCard() -> UIImage? {
        TowerShare.image(
            blocks: towerVM.placedBlocks,
            mergeGroups: towerVM.mergeGroups,
            groupedIDs: towerVM.groupedBlockIDs,
            coveredIDs: towerVM.coveredBlockIDs,
            modelContext: modelContext
        )
    }

    /// Marks the plan line a win was written from as done.
    ///
    /// Done, not deleted: a completed line stays on the plan for the rest of
    /// the day so you can see what you got through. `PlanItem.sweep` clears
    /// one-offs when the day turns.
    private func setPlanItemDone(_ id: UUID, _ done: Bool) {
        let descriptor = FetchDescriptor<PlanItem>(predicate: #Predicate { $0.id == id })
        guard let item = (try? modelContext.fetch(descriptor))?.first else { return }
        item.completedAt = done ? Date() : nil
        try? modelContext.save()
    }

    /// **The tab bar's selection, passed straight through, with one thing
    /// noticed on the way**: a tap on Memories while already on Memories
    /// (the cohesion pass, 2026-10-05, "jump to today"). The value written is
    /// always the value given, so this is the plain `$selectedTab` in every
    /// other respect. The note on `.preferredColorScheme` below records a
    /// wrapping binding that broke programmatic navigation; that one CHANGED
    /// the write, and this one never does.
    private var tabSelection: Binding<StrataTab> {
        Binding(
            get: { selectedTab },
            set: { tab in
                if tab == .memories, selectedTab == .memories {
                    LandingRouter.shared.memoriesReselected += 1
                }
                selectedTab = tab
            })
    }

    private var mainContent: some View {
        TabView(selection: tabSelection) {
            // Hollow when it is not the page you are on, filled when it
            // is. One glyph in two states says "here" without needing the
            // label, the colour or the pill to say it as well — and it is what
            // every tab bar on the platform does, so it needs no learning.
            //
            // **THE WORDS ARE BACK** (the owner, 2026-10-06: "I think we
            // should add the label text under again in the sf pro like it
            // will make everything very cohesive"), with his drawn icons,
            // grey when not selected, as Luma sets its bar. The note below is
            // the call it reverses, kept for why it was made.
            //
            // **AND NO WORDS UNDER IT** (the owner, 2026-10-01: "no tiny text
            // under or anythign like that", asked with the whole app in view,
            // and then specifically for this bar when it was put to him against
            // keeping the labels).
            //
            // The labels were the smallest type the app shipped: 10pt, the one
            // size below `caption2`, and the only place three words sat in a
            // row at a size nothing else on any screen uses. They were also the
            // weakest of the four things already saying which tab you are on —
            // the glyph fills, the capsule moves, the page behind it changes,
            // and the window's whole appearance changes with it.
            //
            // The bet this takes is that three glyphs are legible without
            // words, and it is a short bet: there are three of them, they are
            // never rearranged, and no two are near each other in shape (a
            // stack, a camera, a picture). **The name is not lost, it is
            // moved**: `accessibilityLabel` carries each one, so VoiceOver
            // reads exactly what it read before.
            //
            // **AND THE MEMORIES TAB NEVER FILLED** (found 2026-10-01 by a
            // consistency pass, fixed here). `StrataTab.icon(selected:)` was
            // written to be the one place a tab's two states are decided, and
            // its own doc said so, and then nothing here was changed to call
            // it: two of these three typed both strings inline and the third
            // passed the always-hollow `icon`. So the paragraph above is a
            // promise this bar was not keeping — one of its three glyphs could
            // not say "here" at all, and the onboarding mock-up, which IS a
            // caller of the shared function, drew a filled one.
            //
            // **AND THEN ALL THREE RENDERED FILLED ANYWAY.** Wiring the function
            // up was necessary and not sufficient: SwiftUI's `Tab` applies
            // `.fill` over whatever glyph it is handed, so `square.stack` and
            // `square.stack.fill` arrived at the same picture and the branch was
            // dead a second time, in a second way. `.symbolVariant(.none)` is
            // what stops the platform overriding the name. Measured before it:
            // the Wins glyph was 3,778 dark pixels selected against 3,740
            // unselected, a 1.0% difference, which is two names for one drawing.
            Tab(value: StrataTab.tower) {
                // "Win deleted · Undo" and "Win added · Undo" (`UndoLine`).
                towerTabRoot.undoLine()
            } label: {
                StrataTab.tower.label(selected: selectedTab == .tower, scheme: barScheme)
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
                StrataTab.camera.label(selected: selectedTab == .camera, scheme: barScheme)
            }
            Tab(value: StrataTab.memories) {
                memoriesTabRoot.undoLine()
            } label: {
                StrataTab.memories.label(selected: selectedTab == .memories, scheme: barScheme)
            }
        }
        // A crew asked for from outside (a notification, an invitation) is on
        // the Wins tab: go there, wherever the app was.
        .onChange(of: CrewRouter.shared.open) { _, crew in if crew != nil { selectedTab = .tower } }
        // A cold launch from a crew's notification: the crew was asked for
        // before this view existed, so there was no change to hear and the
        // app opened on the camera (found 2026-10-06).
        .onAppear { if CrewRouter.shared.open != nil { selectedTab = .tower } }
        // The app's own notifications, tapped: the tab their subject is on.
        .modifier(NotificationLanding(selectedTab: $selectedTab))
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
        // **Going DARK waits for the camera's dissolve; coming back does not.**
        //
        // The camera fades its page in over 0.36s rather than cutting (see
        // `CameraView`), and the status bar is above every view in the app —
        // so flipping the window to dark on the instant the tab changes puts
        // white system text on a page that is still white for a third of a
        // second. Unreadable, and the one piece of chrome nothing can draw
        // over.
        //
        // 0.2s is a little past the middle of that fade, where the page has
        // gone far enough that white reads. The other direction has nothing to
        // wait for — leaving the camera arrives on a page that is already
        // drawn — so it stays instant, which is also what keeps a quick
        // there-and-back from queueing two flips.
        //
        // Cancelled by `id:`, so flicking through tabs cannot land a stale one.
        .task(id: selectedTab) {
            let scheme = Self.scheme(for: selectedTab)
            if scheme == .dark {
                try? await Task.sleep(for: .seconds(0.2))
                guard !Task.isCancelled else { return }
            }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                windowScheme = scheme
            }
        }
        // The tab bar is NOT rebuilt when leaving the camera.
        //
        // It is Liquid Glass: it samples what is behind it and caches that, so
        // after a full-screen viewfinder it stays dark — measured at 0.341
        // against 0.956 for a tower that had never shown the camera. Four ways
        // to make it re-sample were tried: `UITabBarAppearance`,
        // `toolbarColorScheme(_:for: .tabBar)`,
        // `toolbarBackgroundVisibility(.hidden)`, and changing the TabView's
        // `.id`. Only the last worked — and it BREAKS `selection`: a TabView
        // with an `.id` ignores its selection binding and sits on its first
        // tab, so `-strataStartTab insights` landed on Wins and so would any
        // deep link. Re-asserting the selection afterwards does not help,
        // because the binding is ignored from the first render.
        //
        // Navigation that works beats chrome that is the right shade. The bar
        // staying dark after the camera is a known cost, written down here so
        // the next person does not spend the afternoon on it again.
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
            // Off the camera: the front flash's brightness goes back now, not
            // when the camera's view finally disappears under the new tab.
            if oldTab == .camera { RingBrightness.restore() }
            HapticsEngine.tick()
            Analytics.shared.signal(.screen, [.screen(newTab == .tower ? .wins : newTab == .camera ? .camera : .memories)])
            if newTab == .tower && !pendingDrops.isEmpty {
                Task { await cascadeDropPendingBlocks() }
            } else if newTab == .tower {
                // A goal crossed on another tab with nothing left to drop
                // (the win landed while the tower was hidden) dances now.
                Task { await celebrateGoalIfDue() }
            }
            if newTab != .tower {
                timelineSelectedDate = Date()
            }
        }
        .onChange(of: animCoord.confettiBursts) {
            showTowerConfetti = true
        }
        .onChange(of: pendingDrops.count) { _, newCount in
            if newCount > 0 && selectedTab == .tower {
                Task { await cascadeDropPendingBlocks() }
            }
        }
        .onChange(of: towerManager.activeTower?.id) {
            reloadTowerWithAnimation()
        }
        // Spotlight deep link handler
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                  let habitID = UUID(uuidString: identifier) else { return }
            selectedTab = .tower
            deepLinkHabitID = habitID
            openDeepLinkedWin()
        }
    }

    /// **A Spotlight result opens the win it names.** The handler above used
    /// to switch to the Wins tab and store the id, and nothing ever read it:
    /// searching for a win landed you on today's tower with no sign of the
    /// thing you searched for.
    ///
    /// On today's tower it opens exactly as a tap would. Anywhere else there
    /// is no block to open, so it opens the win's own sheet. It waits for the
    /// tower's first build before choosing, or a cold launch from Spotlight
    /// would see an empty tower and send today's win to the sheet instead;
    /// `refreshData` asks again once the blocks are placed.
    private func openDeepLinkedWin() {
        guard let id = deepLinkHabitID, towerVM.hasBuiltOnce else { return }
        deepLinkHabitID = nil
        if let block = towerVM.placedBlocks.last(where: { $0.habit?.id == id }) {
            withAnimation(GridConstants.crossFade) {
                expandedBlockID = block.id
            }
        } else if let habit = habits.first(where: { $0.id == id }) {
            editingHabit = habit
        }
    }

    // MARK: - Main Content

    /// The cue, risen just over the slot, on whichever side keeps it on
    /// screen: a line arriving above the place a win is logged.
    @ViewBuilder
    private var winCueLayer: some View {
        if let line = winCue, slotFrame != .zero {
            GeometryReader { geo in
                let origin = geo.frame(in: .global).origin
                let slot = slotFrame.offsetBy(dx: -origin.x, dy: -origin.y)
                let left = slot.midX < geo.size.width / 2
                let margin = GridConstants.horizontalPadding
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    HStack(spacing: 0) {
                        if !left { Spacer(minLength: margin) }
                        WinCueBubble(text: line) {
                            withAnimation(GridConstants.cueOut) { winCue = nil }
                            winDraft = WinDraft()
                        }
                        if left { Spacer(minLength: margin) }
                    }
                    .padding(.leading, left ? max(margin, slot.minX) : 0)
                    .padding(.trailing, left ? 0 : max(margin, geo.size.width - slot.maxX))
                }
                .frame(width: geo.size.width, height: max(0, slot.minY - GridConstants.gapTight))
                .transition(reduceMotion ? .opacity
                            : .scale(scale: 0.86, anchor: left ? .bottomLeading : .bottomTrailing).combined(with: .opacity))
            }
        }
    }

    private var towerTab: some View {
        towerTabContent()
            .background { geometryTracker }
            .overlay { winCueLayer }
            // Asked a beat after the tower settles, once a day (`WinCue`).
            .task(id: "\(selectedTab == .tower)|\(scenePhase == .active)|\(blocksToday)") {
                // A win landed or the tab changed: a cue on screen has had
                // its answer, or is somewhere it no longer belongs.
                if winCue != nil { withAnimation(GridConstants.cueOut) { winCue = nil } }
                // Not before a first win ever: the tower's own line asks then
                // ("Tap the slot to log your first win.").
                guard selectedTab == .tower, scenePhase == .active, winDraft == nil, !logs.isEmpty,
                      let line = WinCue.line(winsToday: blocksToday, now: Date(),
                                             shownOn: winCueDay.isEmpty ? nil : winCueDay, goal: todaysGoal)
                else { return }
                try? await Task.sleep(for: .seconds(1.6))
                guard !Task.isCancelled, winDraft == nil else { return }
                winCueDay = DateUtils.dateString(from: Date())
                // Seen here, so the evening does not ask it again.
                Task { await EveningCheckIn.update(context: modelContext) }
                withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.cueIn) {
                    winCue = line
                }
                try? await Task.sleep(for: .seconds(9))
                withAnimation(GridConstants.cueOut) { winCue = nil }
            }
            // Pinned to the page, not to the tower. The tally used to sit under
            // the bottom row, which meant it moved every time the tower grew
            // and put a caption between the tower and the tab bar. Here it is
            // always in the same place, and the tower has nothing beneath it
            // at all.
            .safeAreaInset(edge: .top, spacing: 0) { towerHeader }
            // **The head that lives on the tower, OVER the header** (moved
            // 2026-10-02). It was an overlay on the scroll view, under this
            // pinned header, so carried over the bubble beside the Plan button
            // he went beneath its glass and his face frosted (filmed). Here he
            // is above the header's glass; still not inside the scrolling
            // content, so he does not scroll away with the tower, and his
            // world is measured in the window, so his bounds are unchanged.
            // Off unless the Profile switch is on, and while it is off this
            // builds no view, starts no clock and asks for no frames.
            .overlay {
                TowerCompanionLayer(
                    active: selectedTab == .tower,
                    probe: towerProbe,
                    bottomInset: GridConstants.tabBarClearance,
                    landing: {
                        latticeRipple.map {
                            TowerCompanionLanding(
                                at: $0.started,
                                cell: TowerCompanionWorld.Cell($0.column, $0.row,
                                                               $0.columnSpan, $0.rowSpan))
                        }
                    }
                ) {
                    towerVM.placedBlocks.lazy.map {
                        TowerCompanionWorld.Cell($0.column, $0.row,
                                                 $0.columnSpan, $0.rowSpan)
                    }
                }
            }
            // **Touch the page and it answers — the whole page.**
            //
            // See `TouchRipple`: rings on water, never a highlight, drawn
            // BEHIND the content so a block hides them, and it consumes
            // nothing — a tap on a block, the slot or the tab bar still
            // reaches them.
            //
            // Here rather than on `towerTabContent`, which is where it was:
            // the header is a `safeAreaInset`, so it is outside the content it
            // insets and a ripple attached in there could not reach it. The
            // owner asked for "all over the screen, in the header as well".
            .touchRipples($touchRipples)
            // **The ground goes on AFTER the ripple, which puts it UNDER it.**
            //
            // `.background` stacks backwards, so the one applied last is the
            // one furthest back. This used to live inside `towerTabContent`,
            // which is nearer the content than the ripple layer is — so the
            // rings were drawn behind an opaque page and the whole effect
            // measured three levels of grey. Nothing about the drawing was
            // wrong; it was underneath the floor.
            //
            // The ground is `WarmBackground` for every screen in the app now,
            // field and all — see that type. This tab no longer has a private
            // one, and the debug flag that used to switch it is gone with it.
            .background { WarmBackground().ignoresSafeArea() }
    }

    /// The whole header: the day's button, Crews, and nothing else.
    ///
    /// It has lost a filter control, a period label, a height and now **the
    /// count**, in that order. The owner, 2026-09-30: "remove the wins number
    /// from the top for now."
    ///
    /// The right call, and the tower is the argument for it: a page whose whole
    /// subject is a stack that grows does not need a numeral saying how tall the
    /// stack is. It was the loudest thing on the screen — the largest type in
    /// the app, in the heaviest ink, over the emptiest part of the page — and it
    /// was saying what the thing underneath it already shows.
    ///
    /// **"For now".** The count is not gone from the app: it is in the widget,
    /// in Profile's streak, in every replay, and `VoiceOver` still reads the
    /// tower's. If it comes back it should come back somewhere it is the
    /// subject rather than a caption on something else.
    ///
    /// `ViewThatFits` went with it. It was there because the count, "wins" and
    /// two controls did not fit one row at an accessibility text size; two
    /// controls always do.
    // **THE DATE IS OFF THE HEADER** (the owner, 2026-10-01: "the Oct 17 on
    // the left idk if that looks very clean i think it honestly looks better
    // without there being something in the corner like that maybe I will add a
    // logo later in the corner but I think for now it shouldnt be there").
    //
    // It went on to answer a real question — the tower is TODAY's tower and
    // nothing on the page said which day — and the answer was a word in a
    // corner, which is the cheapest kind of answer and the one that costs the
    // page most. Measured on the shipped screen: "Thursday, October 1" ran
    // 135pt across the top-left, 17pt tall, on a page whose whole top half is
    // deliberately empty. One phrase, set in the second-quietest ink, at the
    // one place the eye lands first.
    //
    // The question it answered is still real, and it is not this screen's to
    // answer in type. A person who has been away sees it in the tower itself,
    // which is empty when the day turns. If that ever proves not to be enough,
    // the fix is the empty state saying it once, not a permanent caption.
    //
    // `DateFormatter` and its `EEEEdMMMM` template went with it.

    private var towerHeader: some View {
        // Centred, not baseline-aligned: there is no type left in this row to
        // sit a baseline on, and two capsules of the same height centre on
        // each other exactly.
        ZStack(alignment: .top) {
        HStack(alignment: .center, spacing: GridConstants.gapTight) {
            // **Mine on the left, the crew on the right** (owner-approved,
            // 2026-10-05). The day's page is ONE glass button at the leading
            // edge, `checklist` (his pick), because the plan and the note are
            // one page now ("the plan and journal screen could probably be
            // merged"); it replaced the Journal and Plan pair the same day.
            // Crews stands alone at the trailing edge. Three reasons for the
            // right, each pinned in `WinsBatchTests.headerOrder`: the HIG's
            // trailing end is for what must stay available; Instagram and
            // Strava both put their chat and notification entry points top
            // right; and a right thumb reaches the top right more easily than
            // the top left (Hoober). It was top left from 2026-10-02 ("a
            // simple social button on the top left"), which this placement
            // supersedes at his word.
            //
            // **The head's bubble is gone from this row** (the owner,
            // 2026-10-05: "remove the head from the main home screen because
            // i feel like it would make too many buttons there since we added
            // the journal component"). It stood directly left of the Plan
            // from 2026-10-02, and was where the tower head parked. Without
            // it he cannot be parked, so he lives on the tower whenever
            // Profile's tower switch is on (`CompanionParking.hasDock`).
            // No dot on it: on Wins only Crews ever carries one.
            headerDay
            Spacer(minLength: 0)
            // Empty while crews are off, so the pair has the row to itself.
            // The unread dot is `CrewsButton`'s own, from `SocialStore.unread`.
            if CrewsFlag.isOn {
                CrewsButton { crewPath = [.list] }
            }
        }
        // **The day's goal in the middle** (`GoalCrest`), laid out as a
        // crew's tower lays out its faces and name: your head in the ring,
        // the fraction in the crew's caption under it. Centred on the row,
        // not between its two buttons, so it holds the same place with crews
        // on or off.
        GoalCrest(wins: blocksToday, goal: todaysGoal, openDay: { showsYourDay = true })
        }
        // **The goal opens the booth and prints the strip** (`StripBooth`;
        // the owner's pick: "Dance, then open the booth"), once a day, when
        // the tower's dance has had its moment.
        .onChange(of: blocksToday) { old, new in
            let today = DateUtils.dateString(from: Date())
            guard DailyGoal.reached(from: old, to: new, goal: todaysGoal), stripPrintedDay != today else { return }
            stripPrintedDay = today
            // **Only with something to print** (2026-10-07, his pick:
            // "Doodled blocks only"): photographs and doodled blocks make a
            // strip; a day of plain colour blocks dances and opens nothing,
            // where it used to print one empty frame.
            Task { @MainActor in
                guard await !PhotoStrip.mine(day: today, context: modelContext, small: true).candidates.isEmpty
                else { return }
                openBoothWhenFree(prints: true)
            }
        }
        .fullScreenCover(item: $booth, onDismiss: {
            // **The one tip ask** follows a strip just developed, from the
            // third on, once ever (`TipJar.shouldAsk`); a beat after the
            // booth has gone, never over it.
            guard TipJar.shared.takeAsk(today: DateUtils.dateString(from: Date())),
                  !TipJar.shared.products.isEmpty else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                showsTipAsk = true
            }
        }) { opening in
            if let day = opening.day {
                // An earlier day: a keepsake, so it develops when opened.
                StripBooth(owner: .me, day: day, prints: false) {
                    await PhotoStrip.mine(day: day, context: modelContext)
                }
            } else {
                StripBooth(owner: .me, prints: opening.prints, canDevelop: { blocksToday >= todaysGoal }) {
                    await PhotoStrip.mine(context: modelContext)
                }
            }
        }
        .sheet(isPresented: $showsTipAsk) { TipAskSheet() }
        .sheet(isPresented: $showsYourDay) {
            YourDaySheet(goal: $dailyGoal) { day in
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    booth = BoothOpening(prints: false, day: day)
                }
            }
        }
        .accessibilityElement(children: .contain)
        // Constrained to the GRID's width, not the page's.
        //
        // The tower is leading-aligned inside the padded page, and four
        // columns rarely divide the remaining width exactly — so the grid ends
        // a couple of points short of the page's trailing padding. Padding the
        // header by `hPad` on both sides therefore put the share button past
        // the tower's right edge. Measured: tower right 383.7pt, button right
        // 386pt. Giving the header the grid's own width lands both on the same
        // line whatever the screen.
        .frame(width: towerGridWidth, alignment: .leading)
        .padding(.leading, hPad)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Shared with every other screen's title — see `headerTopPadding`.
        // Works out at the 4pt this used to hard-code; the other headers move
        // to meet it.
        .padding(.top, GridConstants.headerTopPadding(forTitleSize: GridConstants.tallyNumeral))
        // Air between the header and the top of a tall tower. Without it a
        // tower that reaches the top of the scroll runs straight into the
        // date and the page reads as crowded.
        //
        // `gapWide`, not the 20 it hard-coded. 20 is not on the ladder
        // (8/12/16/24/32) and it was the only value on this screen that was
        // not, which is a check-7 failure whatever it looks like: a fifth
        // value is a value nobody can reuse.
        .padding(.bottom, GridConstants.gapWide)
    }

    // **`headerCount` is deleted.** It had no call site: the count came off
    // this screen at the owner's word and the property was left behind, so the
    // file still carried the numeral's optical inset, its `numericText`
    // transition and the argument for "wins" being the quieter of the two —
    // forty lines reasoning about a view nothing drew. The reasoning that is
    // worth keeping is in `Typography.tally` and in the note above
    // `towerHeader`; the rest went with the view.

    // **`headerReplayPill` IS DELETED. REPLAYS LIVE IN MEMORIES.**
    //
    // The owner, 2026-10-01: "the your month doesnt belong on the wins because
    // its already in memories", and, put to him directly, the call to move the
    // week with it so every replay is in one place.
    //
    // It was a real duplication, not a stylistic one. The pill offered the open
    // month; `ReplayRow` under the Memories month picker offers the same month,
    // with a picture of it. Two routes to one thing, on two tabs, and the one
    // on Wins was the one with no picture.
    //
    // **What this screen gains is the corner.** The header is now one control
    // in open air, which is the owner's own framing of it ("maybe I will add a
    // logo later in the corner but I think for now it shouldnt be there"). The
    // date went with the same message; see the note above `towerHeader`.
    //
    // The state it drove went with it: `liveReplay`, `playingReplay` and the
    // cover that presented them. What stayed is `refreshReplayWindow`, because
    // the replay NOTIFICATIONS are still this view's to keep warm.

    private var headerDay: some View {
        // **The day's page: the plan, then the note**, where the Plan button
        // stood, which was where sharing was, which was where the range
        // picker was before that.
        //
        // Planning is a thing some people do every morning, and it has to be
        // one press from the tower or it will not happen; writing the day
        // down is the same press now. This corner takes whichever is used
        // most, and it is not the one that needs an audience.
        GlassIconButton(
            systemName: DayIcon.name,
            onPage: true,
            accessibilityLabel: "Plan and Journal"
        ) {
            openDay()
        }
        .companionObstacle("plan")
        // No profile button here. Profile lives on Memories only — the
        // owner's call: the tower is today's record and its corner belongs
        // to the plan; who you are and how your weeks have gone is the
        // Memories tab's subject.
    }

    /// Opens the day's sheet on the tab used last. Only the Journal asks
    /// `JournalLock`, once a session, as it always did; refused, the sheet
    /// opens on the Plan, because the lock is for the note.
    private func openDay() {
        Task {
            var stored = lastDayTab
            #if DEBUG
            // `-strataDayTab plan|journal`: a screenshot script picks the tab.
            if let pick = DebugHarness.dayTab { stored = pick }
            #endif
            let wants = DayTabs.stored(stored)
            let mayOpen = wants == .journal ? await JournalLock.shared.unlock() : true
            dayOpeningTab = DayTabs.opening(stored: stored, journalMayOpen: mayOpen)
            isPlanning = true
        }
    }

    /// **The day's two dominant colours, by how much of the tower they cover.**
    ///
    /// Area-weighted rather than counted: a single Deep is four cells and says
    /// more about the shape of the day than four Quicks scattered through it.
    /// Two, because `GroundField.maxStops` is two and mixing six washes makes grey.
    ///
    /// Cheap on purpose. It walks the blocks already in hand, does no decoding
    /// and touches no photograph, and it is read on the same pass that draws
    /// them.
    private var dayColours: [Color] {
        var area: [HabitCategory: Int] = [:]
        for b in towerVM.placedBlocks {
            area[b.look.displayCategory, default: 0] += b.columnSpan * b.rowSpan
        }
        return area.sorted { $0.value > $1.value }.map { $0.key.style.baseColor }
    }

    /// **The day's photographs, biggest block first**, for the backdrop to stand
    /// on. At most `GroundField.maxPhotos`, and only ones that actually have a
    /// file: a day of unphotographed wins draws the sky alone, which is correct
    /// rather than a fallback.
    ///
    /// Biggest first because a Deep is four cells of somebody's day and a Quick
    /// is one, so the picture that mattered most gets the most of the page.
    private var dayPhotos: [String] {
        towerVM.placedBlocks
            .filter { $0.look.imageFileName != nil }
            .sorted { $0.columnSpan * $0.rowSpan > $1.columnSpan * $1.rowSpan }
            .compactMap(\.look.imageFileName)
            .prefix(GroundField.maxPhotos)
            .map { $0 }
    }

    /// 0 on an empty tower, 1 once it fills the frame.
    ///
    /// **The wash comes up with the tower.** At full strength over a single
    /// block the page would announce a colour for one win, which is both a lie
    /// about the day and the "colour used to mean futuristic" §4 forbids. Twelve
    /// cells is roughly the point at which the tower stops being a strip along
    /// the bottom of the screen.
    private var dayFill: Double {
        let cells = towerVM.placedBlocks.reduce(0) { $0 + $1.columnSpan * $1.rowSpan }
        return min(1, Double(cells) / 12)
    }

    /// Which block is under a point in the grid's coordinate space.
    ///
    /// Arithmetic rather than hit testing: the grid is a fixed pitch, so the
    /// cell under the finger is a division, and the block owning that cell is
    /// a lookup. Hit testing would have meant a gesture per block, and a drag
    /// that starts on one and ends on another is one gesture crossing several
     // MARK: - Rearranging
    // **NOTHING BELOW CAN RUN ANY MORE.** (2026-09-28)
    //
    // Every one of these was reached from `.draggable` on a placed block, and
    // that gesture was removed at the owner's request; the grid's own comment at
    // the block says why. They are left in the tree rather than cut out because
    // they are interleaved with a page of unrelated view code and a block delete
    // took eight things with it that had nothing to do with rearranging. Removing
    // them is a sweep of its own, with a build between each one.
    //
    // Until then: `carriedBlockID` is never written, so `isRearranging` is always
    // false and its three guards always take the other branch.

    /// A block has been lifted. Remember where everything was, and take the
    /// carried one out of the tower so the gap closes under the finger.
    private func beginRearrange(_ id: UUID) {
        guard carriedBlockID == nil else { return }
        restoreTask?.cancel(); restoreTask = nil
        committedOrder = towerVM.placedBlocks.map(\.id)
        carriedBlockID = id
        hoverTargetID = nil
        previewOrder = committedOrder.filter { $0 != id }
        HapticsEngine.snap()
        reflowTowerOrder()
    }

    /// The finger has entered or left a block.
    private func hover(_ id: UUID, targeted: Bool) {
        guard let carried = carriedBlockID, id != carried else { return }
        if targeted {
            // Any new target cancels a pending restore. Crossing from one
            // block to the next fires `false` on the old one and `true` on the
            // new one a frame or two apart, so without this the tower would
            // snap back on every crossing.
            restoreTask?.cancel(); restoreTask = nil
            guard hoverTargetID != id else { return }
            hoverTargetID = id
            previewOrder = TowerOrdering.reordered(ids: committedOrder, moving: carried, onto: id)
            HapticsEngine.tick()
            reflowTowerOrder()
        } else if hoverTargetID == id {
            hoverTargetID = nil
            scheduleRestore()
        }
    }

    /// Nothing is under the finger any more.
    ///
    /// iOS 18 gives no drag-session-ended callback — `.draggable` has no
    /// completion, `DropDelegate` has no session-end, and `DragSession` /
    /// `onDragSessionUpdated` are iOS 26. So this does not detect the end of
    /// the drag; it detects leaving the tower, which is what a cancel looks
    /// like from here. `commitRearrange` cancels this as its first statement,
    /// which makes the delivery order of `isTargeted:false` and the drop
    /// irrelevant.
    private func scheduleRestore() {
        restoreTask?.cancel()
        restoreTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled, carriedBlockID != nil else { return }
            cancelRearrange()
        }
    }

    private func commitRearrange(_ carried: UUID, onto target: UUID) {
        restoreTask?.cancel(); restoreTask = nil
        defer { endRearrange() }
        guard carried != target else { return }
        // The tower is already showing this arrangement from the last hover,
        // so the write is the only thing left to do. `scheduleRefresh` puts the
        // heavy `refreshData` on the next tick, out of the way of the system's
        // own drop-completion animation.
        TowerOrdering.commit(moving: carried, onto: target,
                             logs: towerVM.placedBlocks.compactMap(\.log),
                             context: modelContext) { scheduleRefresh() }
    }

    private func cancelRearrange() {
        previewOrder = nil
        endRearrange()
        reflowTowerOrder()
    }

    private func endRearrange() {
        carriedBlockID = nil
        hoverTargetID = nil
        previewOrder = nil
        committedOrder = []
        restoreTask?.cancel(); restoreTask = nil
    }

    /// Repack the tower to the arrangement currently being proposed.
    ///
    /// Deliberately NOT `repackTower()`. That calls `refreshData()`, which is a
    /// full recompute — HealthKit sync, an index over every log, week data,
    /// perfect days, timeline reload, milestone detection — and, worst of all,
    /// `enqueueArrivals`. That does not merely queue animations: it CONSUMES
    /// `awaitingDropIDs`, so one reflow during a pending drop silently eats
    /// that block's fall. It is the intermittent-drop bug `awaitingDropIDs`
    /// was written to kill, re-armed.
    ///
    /// `buildTower` alone is enough, because it also recomputes the merge
    /// groups, covered ids, crown, foundation, milestones and row count —
    /// everything the grid reads.
    private func reflowTowerOrder() {
        // `buildTower` sets `newlyDroppedIDs` by diffing against the previous
        // ids. During a reflow that set is identical, so it comes out empty —
        // which would clear a drop that is still in the air. Refuse to run
        // while anything is falling; the drag simply does not reflow until the
        // tower is still.
        guard !animCoord.isCascading, animCoord.activelyAnimatingIDs.isEmpty else { return }
        let order = previewOrder ?? committedOrder
        guard !order.isEmpty else { return }
        let byID = Dictionary(filteredLogs.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let logs = order.compactMap { byID[$0] }
        _ = withAnimation(GridConstants.slotSnap) {
            towerVM.buildTower(from: logs, filterMode: towerFilterMode, preserveOrder: true)
        }
    }

    /// Ticking a row. Exactly the path the timeline used: save first, update
    /// the cache optimistically, then queue the drop. The cascade and the
    /// tower do not know or care where the tick came from.
    private func tickHabit(_ habit: Habit) {

        timelineVM.completeHabit(habit)
        cachedCompletedHabitIDsForSelectedDate.insert(habit.id)
        pendingDrops.append(habit)
    }

    /// Moves to a tab from code, and makes it stick.
    ///
    /// Assigning during `setup` alone is a race: `setup` runs on the first
    /// `onAppear`, and the TabView commits its own default selection during
    /// the same layout pass — sometimes after us. Re-asserting on the next
    /// runloop turn costs nothing and removes the coin flip. It showed up as a
    /// launch argument landing on the wrong tab, but any deep link would hit
    /// the same race.
    // **`selectTab(_:)` is deleted** (2026-10-01). Its last caller was the
    // `-strataStartTab` read in `setup()`, and that read was the bug: a
    // selection written during setup is overwritten by the `TabView` on appear,
    // which this file had already written down twice. The flag is answered in
    // `initialTab()` now, so nothing in the app sets the tab programmatically
    // and the function was a retry loop for a problem that no longer exists.

    /// Extracted, like the other tab roots. `mainContent` is a three-Tab
    /// TabView already at the type-checker's ceiling — adding one parameter to
    /// the Insights call tipped it over with "unable to type-check this
    /// expression in reasonable time". See CLAUDE.md.
    private var memoriesTabRoot: some View {
        // No `NavigationStack` here — `MemoriesView` owns its own, because it
        // pushes from four places: an album on the shelf, a curated album, a
        // day in the month tower, and the full grid behind the tail card.
        StableMemoriesTab(openProfile: { profileOrigin = .memories })
        .equatable()
        // The header's head sleeps while Profile covers it. Before `.sheet`,
        // so Profile's own head is not put to sleep with it.
        .environment(\.headsAwake, profileOrigin != .memories)
        .sheet(isPresented: profileBinding(for: .memories),
               onDismiss: { profileOpensSettings = false }) {
            profileSheet
        }
    }

    /// The camera tab.
    ///
    /// A shot used to become a win immediately — logged untitled, at the
    /// smallest size, dropped on the tower. Which meant every photograph
    /// arrived as a block you then had to find and open to name. It goes to
    /// the add sheet now, already holding the picture, so naming and sizing
    /// happen once while you are still thinking about the thing you did.
    private var cameraTab: some View {
        // No `.ignoresSafeArea()` here. The preview ignores it from the
        // inside; the screen needs real insets so the shutter can be placed
        // above the tab bar and the count below the notch.
        StableCameraTab(onCaptured: { image, size, place, crop in
            selectedTab = .tower
            winDraft = WinDraft(photo: image, size: size, place: place, crop: crop)
        })
        .equatable()
        // **THE VIEWFINDER IS COVERED THE MOMENT IT IS NOT THE TAB YOU ARE ON.**
        //
        // The owner, with a photograph of it: "why when I switch to the Wins
        // page from the camera doesn't it instantly change to light mode — it
        // has this grey look, that makes it really not clean." Measured on the
        // built app: the page comes back at 246 and the tab bar stays at
        // (70, 70, 70).
        //
        // The bar is Liquid Glass. It samples what is BEHIND it and caches
        // that, and a tab you have left is not unmounted — a `TabView` keeps it
        // in the hierarchy — so behind the bar there is still a near-black
        // viewfinder, and the bar is faithfully showing it. The file already
        // records four attempts at this from the other end: `UITabBarAppearance`,
        // `toolbarColorScheme(_:for: .tabBar)`, `toolbarBackgroundVisibility`,
        // and an `.id` on the `TabView` — only the last worked and it breaks
        // `selection` outright, which is navigation traded for a shade.
        //
        // This is the same fix from the other side: give the bar something
        // light to sample. The camera is still there, still running, still
        // warm — it is simply behind the app's own ground whenever it is not
        // the screen you are looking at. Nothing is torn down, so coming back
        // is as fast as it was, and the dissolve on arrival (see `CameraView`)
        // covers the handover in the other direction.
        .overlay {
            if selectedTab != .camera {
                WarmBackground()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
    }

    private func columnWidth(for totalWidth: CGFloat) -> CGFloat {
        floor((totalWidth - hPad * 2 - spacing * CGFloat(columns - 1)) / CGFloat(columns))
    }

    /// **`-strataLatticeLab`: a landing every second and a half, for ever.**
    ///
    /// The ripple is under three quarters of a second and a simulator
    /// screenshot takes longer than that to come back, so the real thing
    /// cannot be photographed by asking for a picture at the right moment.
    /// This makes the right moment come round again. DEBUG only, off unless
    /// the flag is passed, and it does not touch the tower — it only tells
    /// the lattice it was hit.
    @MainActor
    private func startLatticeLab() {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-strataLatticeLab") else { return }
        Task { @MainActor in
            var step = 0
            while !Task.isCancelled {
                // 1x1, 2x1, 2x2, and then a 2x2 carrying a PHOTOGRAPH's
                // colour, so the photo path can be photographed rather than
                // only reasoned about. Needs `-strataSeedTodayPhotos`: the
                // seeder deliberately leaves TODAY without photographs, and
                // today is what the tower shows.
                let sizes = [(1, 1), (2, 1), (2, 2), (2, 2)]
                let (cols, rows) = sizes[step % sizes.count]
                step += 1
                // **The photograph the ring used to be tinted by is gone from
                // this fixture, along with the tinting and the `wantsPhoto`
                // flag that chose it.** It picked the block whose category hue
                // was furthest from the others so two rings could be told apart
                // in a screenshot; there is one ink ring now and nothing to
                // tell apart. What the lab still varies is the SIZE, which is
                // what `peak(for:)` reads.
                latticeRipple = LatticeRipple(
                    column: 1,
                    // A few rows up, so the whole ring is inside the lattice
                    // rather than half of it below the ground row. It is
                    // where a landing really happens on a tower with a few
                    // blocks in it.
                    row: 3,
                    columnSpan: cols, rowSpan: rows)
                try? await Task.sleep(for: .seconds(1.5))
            }
        }
        #endif
    }


    /// **Tells the lattice where it was hit, and clears it afterwards.**
    ///
    /// The clear is not a performance story any more and the comment that
    /// said it was outlived the code by a version: there is no `TimelineView`
    /// behind the lattice, so a screen with nothing landing on it already
    /// asks the system for no frames. It is here because a landing left set
    /// would be a landing the surface is still answering, and the next one
    /// has to be able to tell itself apart from it.
    @MainActor
    private func rippleTheLattice(from landedID: UUID) {
        guard !reduceMotion,
              let block = towerVM.placedBlocks.first(where: { $0.id == landedID })
        else { return }
        // **The ring carries no colour, and this comment used to say the
        // opposite.** It asked for the block's category colour on this frame
        // and the photograph's average swapped in underneath, worked out off
        // the main actor from the smallest thumbnail. That was built, and the
        // owner looked at it (2026-09-23): "I feel like the color of the
        // pulses is what makes it not look premium, I feel like it should
        // just be a more visible grey."
        //
        // So the ripple carries WHERE and HOW BIG and nothing else, and
        // `TowerLattice.peak(for:)` rings in ink. `LatticeTint` went with the
        // feature. What is left here is free: four integers off a block that
        // is already in hand, on the frame it lands on.
        let ripple = LatticeRipple(column: block.column,
                                   row: block.row,
                                   columnSpan: block.columnSpan,
                                   rowSpan: block.rowSpan)
        latticeRipple = ripple
        let life = TowerLattice.duration(for: ripple.span)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(life + 0.05))
            // Only if nothing else has landed since: a second landing owns
            // the surface now and clearing here would cut its ring short.
            // Compared on `started` rather than on the whole value, because
            // this landing's own colour may have been swapped for its
            // photograph's while the ring was running.
            if latticeRipple?.started == ripple.started { latticeRipple = nil }
        }
    }

    private func flippedY(for f: CGRect, gridH: CGFloat) -> CGFloat {
        gridH - f.minY - f.height
    }

    /// **Measurement only, and it must take no touches.**
    ///
    /// A `Color` is hit-testable in SwiftUI however transparent it is, and this
    /// one covers the whole page as a background of the tower. Under the new
    /// touch-ripple plate — which sits further back still, so that only a tap no
    /// control claimed reaches it — this swallowed every one of them, and the
    /// page answered nothing anywhere. Tapped on a real simulator to find it.
    private var geometryTracker: some View {
        GeometryReader { geo in
            Color.clear
                .allowsHitTesting(false)
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

    /// The day the tower last danced for its goal, so it dances once a day,
    /// when the goal is crossed (`DailyGoal`). Seeded on the first build so a
    /// tower opened already past its goal does not dance on arrival.
    @AppStorage("goalDanceDay") private var goalDanceDay = ""
    @State private var goalDanceSeeded = false
    /// Where the Wins tab's stack has gone: Crews, then a crew.
    @State private var crewPath: [CrewRoute] = []

 

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
            // else. The tower stands on the page's own ground with the tab
            // bar directly beneath it, and that is the whole page.
            #if DEBUG
            // One ripple in the middle, so the effect can be photographed.
            .task {
                guard DebugHarness.ripple else { return }
                // **HELD AT A FIXED AGE, NOT REPLAYED.**
                //
                // It used to respawn every 700ms, and a `simctl` screenshot
                // takes about a second — so every frame caught a different and
                // arbitrary phase, and the first four came back identical and
                // empty. Pinning `born` to a constant age means the ripple is
                // always at the same point in its life and can actually be
                // photographed. 0.18s is a little after launch, where the rings
                // are open and still strong.
                while !Task.isCancelled {
                    touchRipples = [TouchRipple(at: CGPoint(x: 200, y: 330),
                                                born: Date().addingTimeInterval(-0.18))]
                    try? await Task.sleep(for: .milliseconds(40))
                }
            }
            #endif
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

        if isToday {
            cachedAllHabitsForSelectedDate = timelineVM.todaysHabits
                .filter { $0.tower?.id == towerManager.activeTower?.id }
                .sorted { (TimelineViewModel.effectiveHour(for: $0) ?? 0) < (TimelineViewModel.effectiveHour(for: $1) ?? 0) }
            // Focus Filter — only show habits matching active Focus category
            if let focusCategory = focusFilterService.activeCategory {
                cachedAllHabitsForSelectedDate = cachedAllHabitsForSelectedDate
                    .filter { $0.category == focusCategory }
            }
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


    // MARK: - Skeleton Build-Up

    /// Puts the placeholder up only if the tower is still loading after
    /// `skeletonGrace`.
    ///
    /// It used to go up at once and stay for at least 300ms, so even a tower
    /// whose data was ready in 20ms sat behind a placeholder for a third of a
    /// second: perceived load time had a floor. Now a fast load never shows
    /// it. A slow one does, and once shown it stays `skeletonHold` so it
    /// cannot flash for a frame.
    private func armSkeleton() {
        skeletonBuildTask?.cancel()
        // Already up (a reload cancelled during the hold): leave it up and
        // keep its time, so the next `settleSkeleton` takes it down. Clearing
        // the time here orphaned it at full count, and taking it down here
        // would flash it out and back in 100ms later.
        guard skeletonShownAt == nil else { return }
        skeletonBuildTask = Task { @MainActor in
            try? await Task.sleep(for: Self.skeletonGrace)
            guard !Task.isCancelled, towerVM.isLoading else { return }
            skeletonShownAt = .now
            startSkeletonBuildUp()
        }
    }

    /// Takes the placeholder down if it went up, after its hold.
    private func settleSkeleton() async {
        skeletonBuildTask?.cancel()
        skeletonBuildTask = nil
        guard let shownAt = skeletonShownAt else { return }
        let remaining = Self.skeletonHold - (ContinuousClock.now - shownAt)
        if remaining > .zero { try? await Task.sleep(for: remaining) }
        guard !Task.isCancelled else { return }
        skeletonShownAt = nil
        stopSkeletonBuildUp()
    }

    private static let skeletonGrace: Duration = .milliseconds(100)
    private static let skeletonHold: Duration = .milliseconds(300)

    private func startSkeletonBuildUp() {
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
            withAnimation(GridConstants.motionSnappy) {
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
        armSkeleton()
        reloadTask = Task {
            guard !Task.isCancelled else { return }
            _ = withAnimation(GridConstants.layoutReflow) {
                refreshData()
            }
            await settleSkeleton()
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
        // No merged runs while rearranging. A `MergeGroup`'s id is its lowest
        // member's UUID, so it changes the moment membership does — and the
        // `ForEach` over these would insert and remove whole shapes on every
        // reflow, hard-cutting instead of moving. Every block drawing itself
        // is also the better reading: you are moving one object, so the
        // objects should be individually legible while you do it.
        guard !isRearranging else { return [] }
        let animating = animCoord.activelyAnimatingIDs
        guard !animating.isEmpty else { return towerVM.mergeGroups }
        return BlockMerge.groups(
            for: towerVM.placedBlocks.filter { !animating.contains($0.id) }
        )
    }

    // MARK: - Wins

    /// Blocks that landed on the tower today — taps of the next slot plus
    /// habits completed. One honest number for what today added, rather than
    /// a count that stays still while the tower visibly grows.
    @AppStorage("notificationsEnabled") private var reminderOn = false
    @AppStorage("reminderHour") private var reminderHour = 8
    @AppStorage("reminderMinute") private var reminderMinute = 0
    /// The last day today's reminder was taken back, so a refresh that finds
    /// the same win again does not ask the notification centre again.
    @State private var reminderSkippedDay = ""

    private var blocksToday: Int {
        let today = DateUtils.dateString(from: Date())
        return logs.filter { $0.dateString == today && $0.completed }.count
    }

    /// **The goal's moment, in order: the dance, then the confetti, then the
    /// booth** (2026-10-08, the owner: "i hit the goal and the tower didnt
    /// dance or the block confetti come out"). Two faults made that:
    ///
    /// - The day was marked as danced BEFORE the dance was asked for, and the
    ///   dance refuses while anything is still settling. A refusal spent the
    ///   day's dance with nothing on screen. Now it waits for the tower to be
    ///   still and marks the day only once the dance has started.
    /// - Confetti was wired only to the old "perfect day" of scheduled habits,
    ///   which one-off wins never make, so a goal never threw any.
    ///
    /// And the booth, which used to open 1.8s after the crossing whatever was
    /// happening, now waits for both to finish (`openBoothWhenFree`).
    private func celebrateGoalIfDue() async {
        let today = DateUtils.dateString(from: Date())
        guard goalDanceSeeded, selectedTab == .tower, goalDanceDay != today,
              towerVM.placedBlocks.count >= todaysGoal else { return }
        if reduceMotion {
            // No dance and no burst under Reduce Motion: the haptic is the
            // moment, and the booth may come up.
            goalDanceDay = today
            HapticsEngine.reward()
            return
        }
        // Up to four seconds for the landing to settle.
        var waited = 0
        while !animCoord.isStill, waited < 40 {
            try? await Task.sleep(for: .milliseconds(100))
            waited += 1
        }
        try? await Task.sleep(for: .milliseconds(180))
        let started = goalDanceDay != today && selectedTab == .tower
            && animCoord.triggerJubilation(placedBlocks: towerVM.placedBlocks)
        guard started else { return }
        goalDanceDay = today
        HapticsEngine.reward()
        while animCoord.isJubilating {
            try? await Task.sleep(for: .milliseconds(100))
        }
        try? await Task.sleep(for: .milliseconds(200))
        animCoord.confettiBursts += 1
    }

    /// **The booth opens when the screen is free** (found 2026-10-07). It
    /// was set 1.8s after the goal was crossed whatever was on screen; a
    /// crossing during the launch (the day's wins arriving, from a sync or
    /// a seed) set it under the drawn logo, the cover never came up, and
    /// SwiftUI went on believing it was presented: every sheet after it,
    /// Add a win included, silently refused to open. Now it waits, after
    /// the dance, for the launch to be over and nothing else to be up, and
    /// gives up after half a minute rather than ambush someone later.
    private func openBoothWhenFree(prints: Bool) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            for _ in 0..<60 {
                // After the goal's dance and confetti, never over them; on
                // another tab the dance waits for the tower, so the booth
                // does not wait for it.
                let today = DateUtils.dateString(from: Date())
                let celebrated = goalDanceDay == today || selectedTab != .tower || reduceMotion
                if booth == nil, LaunchMoment.shared.finished, scenePhase == .active, !Self.somethingIsPresented,
                   celebrated, !animCoord.isJubilating, !showTowerConfetti {
                    booth = BoothOpening(prints: prints)
                    return
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    /// Whether a sheet or cover is up over the app, whoever put it there.
    private static var somethingIsPresented: Bool {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        return windows.contains { $0.isKeyWindow && $0.rootViewController?.presentedViewController != nil }
    }

    /// Keeps the replay notifications warm, and sets the next moment to do it
    /// again. Called on scene-active, from `refreshData()` only when a win
    /// actually landed or a count changed, and at `replayEdge`.
    ///
    /// It used to also decide the Wins pill, which is why it ran
    /// `ReplayEntry.live` and `ReplayLoader.hasWins`. The pill is gone and so
    /// is that fetch: `ReplayReminder.schedule` asks the store the same
    /// question for itself, so asking it here first was asking twice.
    private func refreshReplayWindow() {
        replayEdge = ReplayEntry.nextEdge(after: Date())
        Task {
            await ReplayReminder.schedule(context: modelContext)
            // Tonight's past win, once today has a win of its own.
            await PastWinReminder.schedule(context: modelContext)
        }
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

    /// The first block, dropped once, when somebody finishes onboarding.
    ///
    /// **Endowed progress.** A tower that starts at zero asks you to begin; a
    /// tower with one block on it asks you to continue, and those are not the
    /// same request. Nunes and Drèze showed it directly in 2006: a loyalty
    /// card with two of ten stamps already filled was completed at nearly
    /// twice the rate of one with none of eight, for identical remaining
    /// effort. Most habit apps open on an empty page and fight that finding
    /// rather than use it.
    ///
    /// It is also TRUE, which matters more here than the psychology. Finding
    /// this app, installing it and sitting through the walkthrough is a thing
    /// they actually did, and the app's whole claim is that the things you
    /// actually did count. A fabricated block would be it lying on its first
    /// screen.
    ///
    /// A `.hard` — the biggest — because it is the only block on the grid, and
    /// a lone 1x1 reads as a rounding error rather than as a start.
    private func dropWelcomeWinIfNeeded() {
        let key = Self.welcomeWinKey
        guard UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(false, forKey: key)
        // **The win you dropped on onboarding's last page** (2026-10-05), on
        // the active tower through `QuickWinService.logWin`, the path every
        // one-tap win takes. It replaces "Welcome": the first block is now
        // one you named.
        if OnboardingFirstWin.isPending() {
            OnboardingFirstWin.land(context: modelContext, tower: towerManager.activeTower)
            scheduleRefresh()
            return
        }
        // **No "Welcome" block** (2026-10-08). Onboarding no longer ends on a
        // first win, and a win nobody did is not a head start, it is the app
        // speaking for them: the first block is theirs, from the slot.
        return
        // Belt and braces: never two of them. The flag alone is enough in
        // practice, but a welcome block is the one thing that must not be
        // able to arrive twice — it would be the app's first act, doubled.
        let title = "Welcome"
        let existing = FetchDescriptor<Habit>(predicate: #Predicate { $0.title == title })
        guard ((try? modelContext.fetch(existing)) ?? []).isEmpty else { return }
        _ = try? QuickWinService.logWin(
            title: title,
            category: .unlabeled,
            size: .hard,
            spontaneous: .mindfulness,
            context: modelContext,
            tower: towerManager.activeTower
        )
        scheduleRefresh()
    }

    /// A crew tower's empty slot: the same one-tap win as this tower's, in
    /// the colour that slot showed, sent to that crew and no other. It is
    /// your win, so it stands on your tower too.
    private func logCrewWin(size: BlockSize, colour: HabitCategory, to crew: CrewID) {
        do {
            let win = try QuickWinService.logWin(size: size, spontaneous: colour,
                                                 context: modelContext, tower: towerManager.activeTower)
            if let log = (win.habit.logs ?? []).first(where: { $0.id == win.logID }) {
                CrewSync.post(log, to: [crew])
            }
            scheduleRefresh()
        } catch {
            HapticsEngine.warning()
        }
    }

    private func logWin(size: BlockSize = .small, photo: UIImage? = nil, holdFromCrews: Bool = false) {
        do {
            // The colour the slot has been showing, not a fresh roll.
            let win = try QuickWinService.logWin(
                size: size,
                spontaneous: nextWinCategory,
                context: modelContext,
                tower: towerManager.activeTower
            )
            rerollNextWinCategory()
            // A one-tap win goes where the last one went, with no step
            // (crews, spec 2.6). Its photograph follows on the save below,
            // which `CrewSync` sees and sends as an edit.
            if let log = (win.habit.logs ?? []).first(where: { $0.id == win.logID }) {
                // Drawn out of the slot: your tower only, until the sheet's
                // confirm sends it (`CrewHold`).
                if holdFromCrews { CrewHold.hold(log.id) } else { CrewSync.post(log) }
            }
            // Written before the drop is queued, so the block arrives with its
            // face on rather than growing one a moment after it lands.
            if let photo, let log = (win.habit.logs ?? []).first(where: { $0.id == win.logID }) {
                let id = log.id
                // Stored whole. The block crops to its own shape when it draws
                // (`scaledToFill`), so cropping to disk as well only made a
                // later resize crop the crop — see `AddWinSheet.attach`.
                Task { @MainActor in
                    if let name = try? await ImageManager.shared.save(image: photo, for: id) {
                        log.imageFileName = name
                        try? modelContext.save()
                        scheduleRefresh()
                    }
                }
            }
            // Claim the animation up front. Whichever build ends up placing
            // this block hands it to the animator; see `enqueueArrivals`.
            // **Undo, for a win drawn by accident** (the owner, 2026-10-06):
            // a held press or a stray drag on the slot logs a win, and taking
            // it back was find it, open it, delete it. Only from the slot:
            // pressing Add on the sheet is not an accident.
            if holdFromCrews {
                let habit = win.habit
                UndoLine.shared.show("Win added", undo: {
                    guard let pending = try? WinDeletion.delete(habit, in: modelContext) else { return }
                    pending.finish()
                    scheduleRefresh()
                })
            }
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
    //
    // This note is what the sheets' toolbars point back to. The Wins toolbar
    // it was written beside is gone — the tower draws its own header now —
    // and its `+` had not been attached to anything since.

    // MARK: - Profile

    /// Profile opens as a sheet from the Memories header, its only door.
    ///
    /// Keyed by the tab that asked rather than a plain flag, so a second door
    /// can be added without two `.sheet`s bound to one flag — every tab stays
    /// in the hierarchy, and two sheets asked to present at once is one UIKit
    /// silently drops.
    ///
    /// (This replaces the Insights-era toolbar and its gear, which nothing had
    /// shown since Insights went. Settings lives only inside Profile now.)
    private func profileBinding(for tab: StrataTab) -> Binding<Bool> {
        Binding(
            get: { profileOrigin == tab },
            set: { presented in
                if !presented, profileOrigin == tab { profileOrigin = nil }
            }
        )
    }

    private var profileSheet: some View {
        NavigationStack {
            ProfileView(
                onResetAllData: {
                    // Profile and head only if the record really went: a reset
                    // that deleted your face and kept your wins would be the
                    // original bug the other way round.
                    guard resetTower() else { return false }
                    // The policy says Reset All Data removes every photo; a
                    // profile photo is one, and a head is made of them.
                    ProfileStore.shared.reset()
                    HeadStore.shared.delete()
                    // Your wins leave every crew with the record.
                    if CrewsFlag.isOn { Task { await SocialStore.shared.withdrawEverything() } }
                    return true
                },
                opensSettings: profileOpensSettings
            )
        }
    }

    // MARK: - Setup

    private func setup() {
        guard !hasSetUp else { return }
        hasSetUp = true
        HapticsEngine.prepare()
        // The audio engine, started after the first frame and off the main
        // thread, so the first block to land does not wait for it. It used
        // to start inside the first impact and held that frame 338 to 404ms
        // (`SoundEngine.prepare`). Nothing when muted.
        Task(priority: .utility) { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            SoundEngine.prepare()
        }
        #if DEBUG
        // Before anything is fetched or seeded: a test that asserts a first
        // run needs a store that has never been used. See
        // `DebugHarness.resetsStore`.
        // Not from a sheet, so the root's alert is the one a person sees.
        if DebugHarness.resetsStore, !resetTower() { resetFailed = true }
        if let mode = DebugHarness.editBlock {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(20))
                guard let top = towerVM.placedBlocks.last else { return }
                top.habit?.title = "Edited title"
                top.habit?.category = top.look.displayCategory == .focus ? .social : .focus
                top.log?.imageFileName = towerVM.placedBlocks.lazy
                    .compactMap(\.look.imageFileName).first
                try? modelContext.save()
                NSLog("[strata-edit] edited %@ (%@)", top.id.uuidString, mode)
                if mode == "rebuild" { repackTower() }
            }
        }
        #endif

        // Before anything reads `isWin`.
        QuickWinService.migrateLegacyWins(context: modelContext)
        towerManager.ensureDefaultTower(context: modelContext)
        towerManager.loadActiveTower(context: modelContext)
        // The tower is pinned to today now. Anyone whose stored value was Week
        // or Month was stuck there — the picker that set it was replaced by
        // the share button — so the key goes, rather than sitting in defaults
        // waiting to be read by something.
        UserDefaults.standard.removeObject(forKey: "towerFilterMode")
        // Milestones were removed; the list of ones already unlocked has
        // nothing left to read it.
        UserDefaults.standard.removeObject(forKey: "milestoneStore")

        // Yesterday off the plan: finished one-offs go, finished repeats come
        // back unchecked. Anything unfinished is left exactly where it is.
        //
        // **This and the welcome drop below were inside `#if DEBUG` for
        // months**, along with the whole harness — one guard opened here and
        // did not close until after the debug flags, which reads as if it only
        // wraps the line beneath it. So on every build anyone has ever
        // installed: finished plan lines never swept, and a new user never got
        // their welcome block, which is the entire endowed-progress idea
        // silently absent from the shipped app. Found from a phone: "planned
        // items that were checked off should disappear the next day."
        //
        // Product behaviour does not belong behind a build flag. The harness
        // below still does.
        //
        // The backfill first: it gives rows from before `createdAt` and
        // `updatedAt` existed their real dates, and every later save would
        // otherwise stamp them with today.
        SocialFieldsBackfill.runIfNeeded(context: modelContext)
        PlanItem.sweep(context: modelContext)

        // **After the tower exists, not before.** This was a `.task` on the
        // view, which fires independently of `setup()` — so it ran while
        // `towerManager.activeTower` was still nil, the win was logged against
        // no tower, and a first-time user landed on an empty grid. Caught by
        // `testAFirstRunEndsOnATowerWithABlockOnIt`, which is the only test
        // that walks the real first launch.
        dropWelcomeWinIfNeeded()

        // After the store is settled and before anything draws from disk.
        pruneOrphanedImages()

        #if DEBUG
        DebugHarness.seed(context: modelContext, tower: towerManager.activeTower)
        // Before the restore screen opens, and from values that never reach
        // the context, so the plan it draws has real work in it. See
        // `DebugHarness.writeDebugBackup`.
        if let n = DebugHarness.seedBackup { DebugHarness.writeDebugBackup(count: n) }
        rerollNextWinCategory()
        debugAutoWinsLeft = DebugHarness.autoWins
        debugAutoChecksLeft = DebugHarness.autoChecks
        debugTabFlipsLeft = DebugHarness.tabFlips
        // `-strataStartTab` is the INITIAL value now (`initialTab()`), not a
        // `selectTab` here, for the reason this file already gave: a selection
        // set during setup does not stick.
        if DebugHarness.testsPhotoSave {
            DebugHarness.runPhotoSaveProbe()
        }
        if DebugHarness.reportsStore {
            DebugHarness.runStoreProbe()
        }
        if DebugHarness.reportsMigration {
            DebugHarness.runMigrationReport(context: modelContext)
        }
        if DebugHarness.probesPhotos {
            DebugHarness.runPhotoPipelineProbe()
        }
        if let n = DebugHarness.benchImages {
            DebugHarness.runImageBench(count: n)
        }
        #if DEBUG
        if WidgetPreviewRenderer.isRequested {
            // After the snapshot is published, so it draws the real tower.
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                WidgetPreviewRenderer.run(snapshot: WidgetSnapshot.read())
            }
        }
        #endif
        if DebugHarness.reportsLocation {
            DebugHarness.runLocationProbe(LocationService.shared)
        }
        // `-strataOpenJournal today` is the day's sheet from the Wins header
        // (2026-10-05), the same sheet the plan's flags open; `-strataDayTab`
        // picks its tab.
        if DebugHarness.seedPlan != nil || DebugHarness.openJournal == "today" {
            selectedTab = .tower
            openDay()
        }
        if DebugHarness.dumpsShareCard {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                guard let image = TowerShare.image(
                    blocks: towerVM.placedBlocks,
                    mergeGroups: towerVM.mergeGroups,
                    groupedIDs: towerVM.groupedBlockIDs,
                    coveredIDs: towerVM.coveredBlockIDs,
                    modelContext: modelContext
                ), let data = image.pngData() else { return }
                let url = URL.documentsDirectory.appending(path: "share-card.png")
                try? data.write(to: url)
                print("[SHARE] wrote \(Int(image.size.width))x\(Int(image.size.height)) to \(url.path)")
            }
        }
        if let which = DebugHarness.openReplay {
            // A beat after launch, not in this pass. A cover takes its
            // presenter's forced appearance, and the launch tab is the camera,
            // which pins the window dark; presented before the start tab's
            // scheme lands, the replay rendered dark on a light simulator.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                let fetchBegan = CACurrentMediaTime()
                defer {
                    ReplayOpenTiming().log(String(format: "[REPLAY-OPEN] %@ chosen in %.1fms", which, (CACurrentMediaTime() - fetchBegan) * 1000))
                }
                switch which {
                case "sampleWeek":
                    debugReplayIsSample = true
                    debugReplay = ReplaySample.replay(.week, now: Date())
                case "sampleMonth":
                    debugReplayIsSample = true
                    debugReplay = ReplaySample.replay(.month, now: Date())
                case "week":
                    debugReplayIsSample = false
                    debugReplay = ReplayLoader.replay(for: .week(containing: Date()), context: modelContext)
                case "month":
                    debugReplayIsSample = false
                    debugReplay = ReplayLoader.replay(for: .month(containing: Date()), context: modelContext)
                case "lastWeek":
                    // A finished week of seeded history: its past days carry
                    // stored photographs, which the current week's today
                    // does not.
                    debugReplayIsSample = false
                    debugReplay = ReplayPeriod.finished(.week, before: Date(), count: 1).first
                        .map { ReplayLoader.replay(for: $0, context: modelContext) }
                default: break
                }
            }
        }
        switch DebugHarness.openSheet {
        case "settings": selectedTab = .memories; profileOpensSettings = true; profileOrigin = .memories
        case "profile":  selectedTab = .memories; profileOrigin = .memories
        case "add":      selectedTab = .tower; winDraft = WinDraft()
        // The booth, printing as at the goal (`-strataOpenSheet booth`), or
        // opened from Your day (`booth-open`).
        case "booth":    selectedTab = .tower; booth = BoothOpening(prints: true)
        case "booth-open": selectedTab = .tower; booth = BoothOpening(prints: false)
        // Your day (`-strataOpenSheet yourday`), and with its three being
        // chosen (`yourthree`): both are behind a tap on the crest.
        case "yourday", "yourthree": selectedTab = .tower; showsYourDay = true
        // The plan is behind a header button, and a header button is the one
        // thing no screenshot script can press. Added for the screen audit:
        // a screen with no scriptable route in is a screen that gets rated
        // off its source instead of off its pixels, which is how the add
        // sheet sat 49% empty without anybody noticing.
        case "plan":     selectedTab = .tower; openDay()
        // **The add sheet HOLDING a photograph, which is a different page from
        // the fresh one and had never been photographed** (2026-10-01). With a
        // picture in it the colour row disappears — `AddWinSheet`'s own "no
        // colour question while you are taking the photo" — so the fresh
        // sheet's measurements say nothing about this one. The only route a
        // person has is the camera's Use Photo, and the simulator has no
        // capture device, so without this the state is unreachable here for the
        // same reason `-strataOpenReview` exists.
        case "addphoto": selectedTab = .tower
                         winDraft = WinDraft(photo: DebugHarness.placeholderPhoto())
        // The Deep block drawn out of the shutter, which is the one state whose
        // well (370pt) cannot fit above a keyboard (2026-10-02).
        case "adddeep":  selectedTab = .tower
                         winDraft = WinDraft(photo: DebugHarness.placeholderPhoto(), size: .hard)
        // The plan's line detail, which is behind a tap on a line. `PlanLines`
        // reads the same value and opens its first line; both halves are
        // needed, because the sheet has to be up before anything in it can be
        // tapped.
        case "planline": selectedTab = .tower; openDay()
        case "block":    selectedTab = .tower; wantsDebugExpand = true
        // The edit sheet's title, which is otherwise behind a long press.
        case "edit":     selectedTab = .tower; editingHabit = habits.first
        default:         break
        }
        #endif
        timelineVM.modelContext = modelContext

        animCoord.reduceMotion = reduceMotion
        startLatticeLab()
        animCoord.lookupMass = { [towerVM] id in
            towerVM.placedBlocks.first(where: { $0.id == id })?.look.blockSize.massTier
        }
        animCoord.onImpact = { [towerVM, animCoord] landedID, mass in
            animCoord.triggerRipple(from: landedID, massTier: mass, placedBlocks: towerVM.placedBlocks)
            // **The surface answers every landing, including the small one.**
            // The block-to-block ripple above deliberately ignores a Quick
            // because a one-cell block has no mass to shake a stack with. The
            // lattice is not the stack: a Quick still touches it, it just
            // touches it less, which is what `TowerLattice.peak(for:)` and
            // its reach are for.
            rippleTheLattice(from: landedID)
            // The column too, so the landing is heard where it is seen.
            // `blockImpact` has always taken it and always been called without
            // it, so the stereo placement its own comment describes has never
            // once happened.
            #if DEBUG
            PerfProbe.mark("impact")
            #endif
            let landedColumn = towerVM.placedBlocks.first(where: { $0.id == landedID })?.column ?? 2
            SoundEngine.blockImpact(mass: mass, column: landedColumn) // Bimodal: haptic + audio (Vroomen 2000)
            // No whole-tower compression.
            //
            // It scaled the ENTIRE stack on impact, so a landing moved every
            // block on screen at once — the tower flexing rather than standing.
            // Even at 0.3% that is several points at the top of a tall tower,
            // and it is the last thing still contradicting "one structure".
            // The landing is carried by the block that landed, its ripple
            // through the neighbours, and the haptic — all of which are local
            // to where it happened.
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

                // **The tower dances when you reach your goal** (the owner,
                // 2026-10-06: "when you reach your goal thats when the tower
                // dances"). It was every tenth win: a round number every user
                // reaches, which now gives way to the number they chose
                // (`GoalRing`), so the day's peak is the one they set. Once a
                // day, when the goal is crossed, never on a rebuild or a tab
                // switch. A crew's tower keeps its tenth (`CrewTowerModel`).
                await celebrateGoalIfDue()

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
                        animCoord.confettiBursts += 1
                    }
                }
            }
        }
        armSkeleton()
        Task {
            // Migrate existing imageData blobs to file system
            await ImageMigrationRunner.migrateIfNeeded(context: modelContext)
            _ = withAnimation(GridConstants.layoutReflow) {
                refreshData()
            }
            await settleSkeleton()
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
        // Single-pass log index — O(n) once, then O(1) lookups downstream
        var logsByDate: [String: [HabitLog]] = [:]
        for log in logs {
            logsByDate[log.dateString, default: []].append(log)
        }

        recomputeFilteredLogs(logsByDate: logsByDate)
        recomputePerfectDayDates()
        let towerHabits = habits.filter { $0.tower?.id == towerManager.activeTower?.id }
        timelineVM.loadToday(habits: towerHabits, logs: logs)
        recomputeTimelineHabits(logsByDate: logsByDate)
        let hadBuiltBefore = towerVM.hasBuiltOnce
        // Seed the dance milestone from whatever is already there, so a tower
        // that opens at thirty wins does not immediately celebrate thirty.
        defer {
            if !goalDanceSeeded {
                goalDanceSeeded = true
                if towerVM.placedBlocks.count >= todaysGoal {
                    goalDanceDay = DateUtils.dateString(from: Date())
                }
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
        withAnimation(GridConstants.motionSnappy) {
            droppedIDs = towerVM.buildTower(from: filteredLogs, filterMode: towerFilterMode)
            // Before anything renders, so no view body ever creates one.
            animCoord.ensureStates(for: towerVM.placedBlocks.map(\.id))
            enqueueArrivals(diff: droppedIDs, hadBuiltBefore: hadBuiltBefore)
        }
        // A win landed: the period it fell in may have just earned a replay
        // notification, or lost one. Guarded on droppedIDs rather than run
        // every call, because refreshData is a hot path called from a 60s
        // timer and scheduling touches the store.
        //
        // A count changing too: a deleted or un-done win drops nothing, and
        // the period's last one going must take the notification with it.
        let replayCounts = [logs.count, towerVM.placedBlocks.count]
        if !droppedIDs.isEmpty || replayCounts != replayDecidedCounts {
            replayDecidedCounts = replayCounts
            refreshReplayWindow()
        }
        // Update the timer guard from the index (avoid a redundant O(n) scan).
        lastLogCount = logs.count
        // The evening's one question, decided again when today's count moves
        // (`EveningCheckIn`).
        let eveningKey = "\(DateUtils.dateString(from: Date()))|\(blocksToday)"
        if eveningKey != eveningDecided {
            eveningDecided = eveningKey
            Task { await EveningCheckIn.update(context: modelContext) }
        }
        // A win today means today's reminder has nothing to say.
        let today = DateUtils.dateString(from: Date())
        if reminderOn, reminderSkippedDay != today, blocksToday > 0 {
            reminderSkippedDay = today
            DailyReminder.skipToday()
        }
        openDeepLinkedWin()

        // Purge stale animation state
        let validIDs = Set(towerVM.placedBlocks.map(\.id))
        animCoord.purgeStaleState(validIDs: validIDs)

        // The anticipation and comeback banners went with the capsules that
        // displayed them, and so has their bookkeeping: the one value still
        // written here, `lastCompletionDateString`, was read by nothing, and
        // working it out was a filter over every log of the period on a hot
        // path.

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

        publishWidgetSnapshot()
        return droppedIDs
    }

    /// Collect photographs no win points at any more.
    ///
    /// **Once per launch, and only on a fetch that is known to have
    /// succeeded.** This is the one path in the app that deletes real user
    /// photographs, so the guard matters more than the feature: `try?` would
    /// turn a failed fetch into an empty set, and an empty set means "nothing
    /// is referenced", which would erase every picture the person owns. A
    /// `do/catch` keeps a throw distinguishable from a store that legitimately
    /// holds no photographs.
    private func pruneOrphanedImages() {
        guard !hasPrunedImages else { return }
        hasPrunedImages = true
        // Before anything that can bail out below: `derived/` is excluded from
        // the device backup on every launch, not only when the migration
        // gets to start.
        let imageDirectory = ImageManager.shared.imageDirectory
        Task.detached(priority: .utility) { ImageDerivatives.ensureFolder(in: imageDirectory) }
        let referenced: Set<String>
        do {
            let logs = try modelContext.fetch(FetchDescriptor<HabitLog>())
            referenced = Set(logs.compactMap(\.imageFileName))
        } catch {
            // A fetch that threw tells us nothing about what is referenced,
            // and acting on nothing here deletes everything.
            NSLog("[strata] orphan sweep skipped: \(error)")
            return
        }
        let removed = ImageManager.shared.pruneOrphans(referenced: referenced)
        if removed > 0 {
            NSLog("[strata] orphan sweep removed \(removed) unreferenced photographs")
        }
        // **The derivative migration, after the sweep** so it never bakes a
        // photograph the sweep was about to remove. Detached at background
        // priority and a few seconds late, so a launch never waits on it; it
        // waits on visible work itself. See `ImageManager.migrateDerivatives`.
        Task.detached(priority: .background) {
            try? await Task.sleep(for: .seconds(4))
            await ImageManager.shared.migrateDerivatives()
        }
    }

    /// Hand the home screen a few hundred bytes of already-decided facts.
    ///
    /// See `WidgetSnapshot`: the widget deliberately cannot see the store, so
    /// this is the only channel. It writes only on a real change, because
    /// `refreshData()` runs on every save and asking WidgetKit to reload a
    /// timeline it has already drawn spends the widget's budget and eventually
    /// gets the updates throttled — which looks like a stale tower.
    private func publishWidgetSnapshot() {
        // Newest last, so the widget can take the tail and be showing the top
        // of the tower.
        let tail = Array(towerVM.placedBlocks.suffix(WidgetSnapshot.blockCap))
        let recent = tail.map { block in
            WidgetSnapshot.Block(
                columns: block.columnSpan,
                rows: block.rowSpan,
                hex: block.look.displayCategory.style.baseHexString,
                // Named for the source file, so an unchanged photograph keeps
                // an unchanged snapshot and nothing is rewritten. A doodled
                // block goes as its picture (`widgetDoodleName`).
                photo: block.look.imageFileName.map { "\($0).jpg" } ?? Self.widgetDoodleName(block.look))
        }
        // **Lifetime, not today.** The tower is pinned to today, so
        // `placedBlocks.count` and `blocksToday` are the same number — the
        // first render of this widget showed "2 wins" beside "+2", which is
        // the same fact twice, the exact thing the tower's own header was
        // redesigned to stop doing. The headline is the number that only ever
        // grows; the blocks under it are today's.
        //
        // `fetchCount` rather than a fetch: MainAppView's own query is
        // deliberately narrowed to the current month and must stay that way,
        // and counting rows does not materialise them.
        let everything = FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.completed })
        let lifetime = (try? modelContext.fetchCount(everything))
            ?? towerVM.placedBlocks.count
        let snapshot = WidgetSnapshot(
            total: lifetime,
            today: blocksToday,
            streak: widgetStreak(lifetime: lifetime),
            blocks: Array(recent),
            updated: Date())
        // Compared against the snapshot this launch last wrote, held in
        // memory, rather than by reading and decoding the file on the main
        // thread every refresh. The file is read once, for the first compare.
        if widgetPublisher.last == nil { widgetPublisher.last = WidgetSnapshot.read() }
        guard let last = widgetPublisher.last, !snapshot.sameContent(as: last) else { return }
        guard snapshot.write() else { return }
        widgetPublisher.last = snapshot
        // One reload, from the export once the photographs it needs are in
        // the group. This reloaded here as well, a moment before the export's
        // own, so every change cost the widget two reloads of its budget.
        exportWidgetPhotos(for: tail)
    }

    /// The widget's streak: consecutive days, over the 400-day horizon.
    ///
    /// **Not `logs`.** That query is narrowed to the current month on
    /// purpose, and the streak was worked out over it, so the widget's streak
    /// could never be longer than the day of the month and fell to 1 on
    /// every 1st. `ProfileViewModel` fetched the horizon correctly; this does
    /// the same.
    ///
    /// **Not on every drop.** The set of days is kept (`Streaks.WidgetDays`,
    /// which states the rule): an unchanged count needs nothing, one more win
    /// on the same day adds today, one more across a day change asks the
    /// store for the newest completed day (one row), and anything else is
    /// fetched on a background context and the snapshot republished when it
    /// lands. At most one full fetch runs per lifetime count, so a count the
    /// store cannot agree with (unsaved changes in this context) does not
    /// start a fetch on every publish. The very first fetch of a launch is
    /// synchronous, so the widget is never handed a zero streak to correct.
    /// The walk runs only when the days themselves changed (`Streaks.Memo`).
    private func widgetStreak(lifetime: Int) -> Int {
        let today = Date()
        let dayKey = DateUtils.dateString(from: today)
        switch widgetPublisher.days.advance(lifetime: lifetime, todayKey: dayKey) {
        case .current:
            if let days = widgetPublisher.days.days {
                return widgetPublisher.streak.current(among: days, today: today, restsPerWeek: Streaks.Rest.profile)
            }
        case .needsNewestKey:
            if let newest = Self.fetchNewestDayKey(context: modelContext) {
                widgetPublisher.days.insert(newestKey: newest, lifetime: lifetime, todayKey: dayKey)
                if let days = widgetPublisher.days.days {
                    return widgetPublisher.streak.current(among: days, today: today, restsPerWeek: Streaks.Rest.profile)
                }
            }
        case .needsFetch:
            break
        }
        let horizon = Streaks.horizonKey(today: today)
        if widgetPublisher.days.days == nil {
            if let days = Self.fetchDayKeys(context: modelContext, horizon: horizon) {
                widgetPublisher.days.replace(days: days, lifetime: lifetime, todayKey: dayKey)
                return widgetPublisher.streak.current(among: days, today: today, restsPerWeek: Streaks.Rest.profile)
            }
            return widgetPublisher.streak.value
        }
        guard !widgetPublisher.fetching,
              widgetPublisher.fetchedForLifetime != lifetime else { return widgetPublisher.streak.value }
        widgetPublisher.fetching = true
        widgetPublisher.fetchedForLifetime = lifetime
        let container = modelContext.container
        Task.detached(priority: .utility) {
            // The count is taken in the same context as the days, so the two
            // describe one moment even if a win is undone and redone while
            // this runs.
            let context = ModelContext(container)
            let days = Self.fetchDayKeys(context: context, horizon: horizon)
            let count = try? context.fetchCount(FetchDescriptor<HabitLog>(
                predicate: #Predicate { $0.completed }))
            await MainActor.run {
                widgetPublisher.fetching = false
                guard let days, let count else { return }
                widgetPublisher.days.replace(days: days, lifetime: count, todayKey: dayKey)
                // With the days in hand this is a compare and, only if the
                // streak moved, a write.
                publishWidgetSnapshot()
            }
        }
        return widgetPublisher.streak.value
    }

    /// The newest completed day in the store, one row.
    nonisolated private static func fetchNewestDayKey(context: ModelContext) -> String? {
        var descriptor = FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.completed },
            sortBy: [SortDescriptor(\.dateString, order: .reverse)])
        descriptor.fetchLimit = 1
        descriptor.propertiesToFetch = [\.dateString]
        return (try? context.fetch(descriptor))?.first?.dateString
    }

    /// Completed days inside the horizon, only `dateString` materialised.
    nonisolated private static func fetchDayKeys(context: ModelContext, horizon: String) -> Set<String>? {
        var descriptor = FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.completed && $0.dateString >= horizon })
        descriptor.propertiesToFetch = [\.dateString]
        guard let rows = try? context.fetch(descriptor) else { return nil }
        return Set(rows.map(\.dateString))
    }

    /// Copy the handful of photographs the widget will draw into the group.
    ///
    /// **The widget cannot read the app's documents directory** — a different
    /// process with a different container — so a reference would draw nothing.
    /// These are re-encoded at 128px, which covers a 38pt block at 3x, and
    /// written beside the snapshot.
    ///
    /// CLAUDE.md: `imageFileName` points at real user photographs. Nothing
    /// here opens them for writing, moves them, or deletes them; it asks
    /// `ImageManager` for a thumbnail and writes a NEW file elsewhere.
    /// **A doodled block on the widget** (the owner, 2026-10-07: "I do want
    /// you to do the doodle on the widgets"): the block's colour with his ink
    /// on it, the picture a crew is sent (`BlockDoodles.crewPicture`). Named
    /// for the doodle and the colour, so a redraw (a new file each save) or a
    /// new colour is exported again and nothing else is.
    static func widgetDoodleName(_ look: PlacedBlock.Look) -> String? {
        look.doodleFileName.map { "\($0)-\(look.displayCategory.rawValue).jpg" }
    }

    private func exportWidgetPhotos(for blocks: [PlacedBlock]) {
        guard let directory = WidgetSnapshot.photoDirectory else {
            WidgetReloader.reload()
            return
        }
        let wanted = blocks.compactMap(\.look.imageFileName)
        // Doodles are drawn here, on the main actor (`ImageRenderer`), and
        // only those not already on disk.
        var doodles: [String: Data] = [:]
        var doodleNames = Set<String>()
        for block in blocks {
            guard let doodle = block.look.doodleFileName, let name = Self.widgetDoodleName(block.look) else { continue }
            doodleNames.insert(name)
            guard !FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path),
                  let data = BlockDoodles.crewPicture(doodle, colour: block.look.displayCategory) else { continue }
            doodles[name] = data
        }
        Task.detached(priority: .utility) {
            try? FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)

            var keep = doodleNames
            for (name, data) in doodles {
                try? data.write(to: directory.appendingPathComponent(name), options: .atomic)
            }
            for name in wanted {
                let destination = directory.appendingPathComponent("\(name).jpg")
                keep.insert(destination.lastPathComponent)
                // Already exported and the source has not changed.
                if FileManager.default.fileExists(atPath: destination.path) { continue }
                guard let image = await ImageManager.shared.loadThumbnail(
                    fileName: name, maxWidth: WidgetSnapshot.photoPixels, lane: .prefetch),
                      let data = image.jpegData(compressionQuality: 0.8) else { continue }
                try? data.write(to: destination, options: .atomic)
            }

            // Anything the widget can no longer show is dead weight in a
            // container the user cannot see or clear.
            let existing = (try? FileManager.default.contentsOfDirectory(
                atPath: directory.path)) ?? []
            for file in existing where !keep.contains(file) {
                try? FileManager.default.removeItem(
                    at: directory.appendingPathComponent(file))
            }
            await MainActor.run { WidgetReloader.reload() }
        }
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

    // MARK: - Cascade Release (Async Sequential)

    @MainActor
    private func cascadeDropPendingBlocks() async {
        pendingDrops = []
        animCoord.isCascading = true
        scrollToTopTrigger += 1
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s scroll settle

        // The animation is claimed in `logWin` and handed over by
        // `refreshData`, so this only has to make the tower rebuild.
        refreshData()

        // Reset the drawn size here, not on release.
        //
        // `isCascading` is already true by this point, so the slot is hidden
        // and the reset is invisible. Doing it in `NextSlotButton.fire` meant
        // the slot shrank to 1x1 the instant your finger lifted and then sat
        // there for the 300ms scroll settle above, before the correctly-sized
        // block arrived — which read as the slot shrinking and the block
        // dropping as two separate events.
        drawingSize = .small

        // No second scroll.
        //
        // This used to centre the new block a moment after scrolling to the
        // top — two scrolls for one drop, the second firing while the block
        // was still in the air. The tower slid underneath a falling block,
        // which is both a premature animation and the tower moving when
        // nothing asked it to. Scrolling to the top already brings the slot
        // into view, because the slot is at the top of the tower.
        // animCoord.isCascading cleared by drain loop when it finishes

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
        // The tallest of the three things the container has to hold. It used
        // to be `rowCount > 0 ? max(rowCount, slotRows) : placeholderRows`,
        // which dropped `slotRows` on an EMPTY tower — so the first slot of
        // the day could be dragged out to a 2x2 and the grid stayed one cell
        // tall, leaving the drawn block outside the scrollable content.
        let layoutRows = max(rowCount, slotRows, placeholderRows)
        let gridH = layoutRows > 0
            ? CGFloat(layoutRows) * colW + CGFloat(layoutRows - 1) * spacing
            : 0
        // Everything under the grid — ground plane, tier badge, the transient
        // first-block label — is drawn with `.offset` from the grid's bottom
        // edge. `.offset` does not affect layout, so the sizing spacer below
        // has to be told about it or the container reserves no space for any
        // of it and it hangs outside the measured bounds.
        // Nothing under the tower now, so nothing to reserve for it.
        let footerReserve: CGFloat = 0
        // Once per evaluation. During a drop this is a fresh
        // `BlockMerge.groups` pass, and the grid needed it twice: for the
        // shapes here and for their member ids below.
        let mergeGroupsNow = liveMergeGroups
        let groupedIDsNow: Set<UUID> = animCoord.activelyAnimatingIDs.isEmpty && !isRearranging
            ? towerVM.groupedBlockIDs
            : Set(mergeGroupsNow.flatMap(\.memberIDs))
        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // Top anchor for FAB scroll. Measurement only — see
                    // `geometryTracker` on why a clear colour has to say so.
                    Color.clear.frame(height: 1)
                        .allowsHitTesting(false)
                        .id("TowerTop")

                    Color.clear
                        // Measurement only — see `geometryTracker`. This one
                        // covers the whole grid, so without it the tower's empty
                        // cells are the one place on the page that cannot
                        // answer a touch.
                        .allowsHitTesting(false)
                        .frame(width: gridW,
                               height: max(gridH, 1) + footerReserve)
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
                        emptyTowerSlot(colW: colW, gridH: gridH, gridW: gridW)
                    } else {
                        // Merged runs, under the blocks. Members draw
                        // nothing when settled, so this IS their appearance.
                        ForEach(mergeGroupsNow) { group in
                            MergedGroupView(
                                group: group,
                                cellSize: colW,
                                gridWidth: gridW,
                                gridHeight: gridH
                            )
                        }

                        placedBlocksGrid(colW: colW, gridH: gridH,
                                         viewportHeight: viewportHeight, topInset: topInset,
                                         slotPos: slotPos, groupedIDs: groupedIDsNow)

                        // Nothing sits under the tower. The count moved to a
                        // fixed place at the top of the page (`towerTally`) so
                        // the tower can stand with the tab bar directly
                        // beneath it, rather than on a caption.
                    }
                }
                // **ONE LAMP OVER THE WHOLE TOWER.**
                //
                // The owner: "I like that the blocks are reacting to the same
                // outer light. They don't all need the same light around the
                // corners — depending on where they are the light shall hit
                // them differently."
                //
                // Set here, on the grid, because this is the only place that
                // knows how tall the tower is: the lamp hangs a fixed distance
                // above the crown, so the spread of angles across the stack
                // stays the same whatever it has grown to. Every block and
                // every merged run reads it out of the environment and works
                // out its own corner. See `BlockLight`.
                .environment(\.blockLight, BlockLight.over(rows: layoutRows))
                // **The grid the blocks land in, drawn behind them.**
                //
                // Bottom aligned and taller than the content on purpose: a
                // background may overflow its anchor, so the lattice carries
                // a viewport further up the page than the tower reaches and
                // fades out inside that, which is what gives the empty screen
                // above a short tower its structure. See `TowerLattice`.
                .background(alignment: .bottom) {
                    // Nothing animates here on arrival. The surface only
                    // moves when something lands on it. See `TowerLattice`.
                    TowerLattice(cellSize: colW, contentHeight: max(gridH, 1),
                                 touches: touchRipples,
                                 ripple: latticeRipple)
                        .frame(width: gridW)
                }
                // **From the crown, not inside the grid** (2026-10-08). Hung
                // on the grid's top edge and never clipped, so the blocks fly
                // up out of the tower and fall back past it over the page.
                .overlay(alignment: .top) {
                    if showTowerConfetti {
                        // **Today's own colours** (2026-10-08). It read the
                        // scheduled habits completed today, a list one-off
                        // wins never fill, so a goal's burst could have no
                        // specks in it at all. One colour per kind of win on
                        // the tower as it is drawn (`displayCategory`; the
                        // stored category of an untitled win is grey).
                        let kinds = Array(Set(towerVM.placedBlocks.map(\.look.displayCategory)))
                        AllClearCelebration(
                            isActive: $showTowerConfetti,
                            completedCategories: kinds.isEmpty ? HabitCategory.selectable : kinds
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
                // **The empty state's one sentence is NOT here any more.** It
                // was an overlay pinned to the top of this page, written to sit
                // under the date; the date came off the header on 2026-10-01
                // and the sentence was left 533pt above the slot it names. It
                // rides on the slot now: see `emptyTowerSlot`.
            }
            // Only once a block is genuinely lifted. Disabling it any earlier
            // would be the old bug in a different costume: the tower has to
            // scroll normally right up until the moment something is in hand.
            // Only while arranging. The whole point of separating the press from
            // the drag is that the tower scrolls normally the rest of the time.
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { _, newOffset in
                towerProbe.scrollOffset = newOffset
                #if DEBUG
                PerfProbe.cullCheck(gridTop: towerProbe.gridTopOnScreen,
                                    windowHeight: viewportHeight + safeAreaTop + safeAreaBottom,
                                    fade: 0.2)
                #endif
                // Only a culling tower reads the offset, and its buffer is a
                // viewport and a half either side (`visibleTowerBlocks`), so
                // a value up to half a viewport stale still leaves a whole
                // viewport of blocks drawn beyond each edge.
                guard towerVM.placedBlocks.count > Self.cullThreshold else { return }
                if abs(newOffset - (towerScrollOffset ?? -.infinity)) > max(viewportHeight / 2, 100) {
                    towerScrollOffset = newOffset
                }
            }
            // Crossing into culling: the published value may be from a
            // scroll long ago, so take the real one before the first cull.
            // Leaving it: forget the value, so the next crossing culls its
            // first body against the live offset rather than this old one.
            .onChange(of: towerVM.placedBlocks.count > Self.cullThreshold) { _, culls in
                towerScrollOffset = culls ? towerProbe.scrollOffset : nil
            }
            .onChange(of: scrollToTopTrigger) {
                withAnimation(GridConstants.motionSnappy) {
                    proxy.scrollTo("TowerTop", anchor: .top)
                }
            }
            // **The head that lives on the tower.**
            //
            // The owner: "for the head I want it to be added to the Wins
            // screen as an option, where it kinda just floats on the top,
            // around, bouncing off the walls... occasionally he can drop down
            // and jump along the tops of the blocks, making sure to jump out
            // of the way of the blocks falling."
            //
            // The header is pinned over this scroll view and had nothing
            // between it and the tower: scrolled down one screen, the date
            // was printed on a salmon block across that block's own label.
            // See `ScrollEdge.swift` for the measurement and for the three
            // alternatives that were rejected.
            .softScrollEdge(.top)

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
                                   slotPos: (column: Int, row: Int)?,
                                   groupedIDs: Set<UUID>) -> some View {
        let visibleBlocks = visibleTowerBlocks(
            colW: colW, gridH: gridH,
            viewportHeight: viewportHeight, topInset: topInset
        )
        ZStack(alignment: .topLeading) {
            TowerBlocksForEach(
                visibleBlocks: visibleBlocks, animCoord: animCoord, towerVM: towerVM,
                groupedIDs: groupedIDs,
                mergeDestinedIDs: towerVM.groupedBlockIDs,
                colW: colW, gridH: gridH,
                cornerRadius: cornerRadius, expandedBlockID: expandedBlockID,
                reduceMotion: reduceMotion, colorScheme: colorScheme,
                onTapExpandBlock: { id in
                    // The release of a long press is not a tap, and a tap
                    // while arranging is not a request to edit.
                    withAnimation(GridConstants.crossFade) {
                        expandedBlockID = id
                    }
                },
                liftedBlockID: nil
            )

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
                    action: { logWin(size: $0, holdFromCrews: true) },
                    onOpenMenu: { winDraft = WinDraft() }
                )
                .frame(width: ghostFrame.width, height: ghostFrame.height)
                // Measured inside the offset, so it is where the slot is SEEN.
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { slotFrame = $0 }
                .offset(x: ghostFrame.minX, y: flippedY(for: ghostFrame, gridH: gridH))
                .companionObstacle("slot")
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
        // A container, not one combined element: each win is reachable and
        // opens by itself (`CrewBlockSpeech`), and the tower still says what
        // its header says when VoiceOver enters it.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("todaysTower")
        // What the header says, said to VoiceOver. It read "Tower grid, 6
        // blocks, 18 meters, 6 of 6 today": a height the screen stopped
        // showing long ago, and a count of scheduled habits that one-off wins
        // always complete, so the two numbers were always equal.
        .accessibilityLabel(towerVM.placedBlocks.count == 1 ? "Today's tower, 1 win" : "Today's tower, \(towerVM.placedBlocks.count) wins")
    }


    // MARK: - Visible Block Culling

    private func visibleTowerBlocks(
        colW: CGFloat, gridH: CGFloat,
        viewportHeight: CGFloat, topInset: CGFloat
    ) -> [PlacedBlock] {
        let blocks = towerVM.placedBlocks
        // Render everything up to a size a day's tower realistically reaches.
        //
        // This was 30, which is about seven rows — well inside what a good day
        // produces, so the cull was running constantly on ordinary towers.
        guard blocks.count > Self.cullThreshold else { return blocks }
        guard !isRearranging else { return blocks }

        let cellStride = colW + spacing
        guard cellStride > 0 else { return blocks }

        // A whole viewport of buffer either side, not 150pt.
        //
        // The cull tests each block's own extent, and a 2-row block reaches
        // further down the grid than a 1-row block sitting at the same height
        // — so at the boundary the tall one survived the cut and the short
        // ones beside it did not. That is the reported "it shows part of one
        // big block but not the smaller ones next to it": the test is per
        // block, so blocks of different heights cross it at different scroll
        // positions. Rather than pretend an extent test can be made
        // height-neutral, the boundary moves a full screen off either edge,
        // where nothing crossing it is visible.
        //
        // **And one and a half viewports, not one.** This was measured when a
        // block entering the cull faded in over 0.2s and the offset was only
        // republished every half viewport, so a one-viewport buffer could
        // insert a block about half a screen beyond the edge and an ordinary
        // fling covered that inside the fade: 49 blocks on screen mid-fade with
        // one viewport over a scripted fling of a 150-block tower, 0 with this.
        // **The fade is gone now** (see the transition in `towerGrid`), so the
        // translucent arrival it was sized against cannot happen. The buffer
        // stays at 1.5 because the second reason it exists is still live: the
        // offset's half-viewport republish rate means a one-viewport buffer can
        // insert a block inside the visible area at all, fade or no fade.
        let buffer = max(viewportHeight * 1.5, 600)
        let offset = towerScrollOffset ?? towerProbe.scrollOffset
        let visibleTop = offset - topInset - buffer
        let visibleBottom = offset + viewportHeight + buffer

        let kept = blocks.filter { block in
            // Blocks currently animating must always render
            if animCoord.activelyAnimatingIDs.contains(block.id) || towerVM.newlyDroppedIDs.contains(block.id) {
                return true
            }
            let blockY = gridH - CGFloat(block.row + block.rowSpan) * cellStride
            let blockBottom = gridH - CGFloat(block.row) * cellStride
            return blockBottom >= visibleTop && blockY <= visibleBottom
        }
        #if DEBUG
        if PerfProbe.isOn {
            PerfProbe.cullRender(kept.map { block in
                (block.id,
                 gridH - CGFloat(block.row + block.rowSpan) * cellStride,
                 gridH - CGFloat(block.row) * cellStride)
            })
        }
        #endif
        return kept
    }

    // MARK: - Tower Ground Plane

 

    // MARK: - Ghost Tower Empty State

    /// The next slot on an empty tower: the first block of the day, on the
    /// ground.
    ///
    /// This replaces a decorative three-block footing. A row of ghosts that
    /// cannot be pressed says "blocks go here" to someone who is looking for
    /// how to put one there; one slot that can be pressed answers it.
    ///
    /// **It is sized from `drawingSize`, exactly like the slot on a tower
    /// that already has blocks in it.** It used to be a hard-coded 1x1, which
    /// meant dragging out of it reported the size, previewed nothing, and
    /// then dropped a block bigger than the slot you had drawn. Every day
    /// starts on this screen, so that was the first thing anyone saw the
    /// gesture do — and it was the one place it did not work.
    @ViewBuilder
    private func emptyTowerSlot(colW: CGFloat, gridH: CGFloat, gridW: CGFloat) -> some View {
        let f = GridConstants.blockFrame(
            column: 0, row: 0,
            columnSpan: drawingSize.columnSpan, rowSpan: drawingSize.rowSpan,
            cellSize: colW
        )
        NextSlotButton(
            reduceMotion: reduceMotion,
            cornerRadius: cornerRadius,
            previewCategory: nextWinCategory,
            onSizeChanged: { drawingSize = $0 },
            action: { logWin(size: $0, holdFromCrews: true) },
            onOpenMenu: { winDraft = WinDraft() }
        )
        .frame(width: f.width, height: f.height)
        // **The sentence stands on the slot it names** (2026-10-02).
        //
        // It was a page overlay at y144 and the slot is at y694: 533pt of
        // nothing between an instruction and the one thing it is about. It
        // was placed under the date, and when the date came off the header
        // the anchor left and the sentence stayed. The owner: "the white space
        // is an aid but make it make sense". Space that separates a caption
        // from its subject is the kind that does not.
        //
        // So it is an overlay on the slot's own frame, `gapLabel` above its
        // top edge, the rung "between a heading and what it heads". Three
        // things follow from hanging it here rather than computing a page y:
        //
        // - **It moves with the slot.** Drag the slot out to a Deep and the
        //   frame grows up on `slotSnap`; the sentence rides on the same
        //   transaction, so it is never printed across the block you are
        //   drawing.
        // - **It leaves the moment the press commits** (`isCascading`), which
        //   is 300ms before the first block appears off the top of the screen
        //   and falls through the space it occupied. A first ever win never
        //   lands through a line of type.
        // - **It takes no layout.** An overlay does not size the grid, so the
        //   tower, the lattice and the fall's measured start are untouched.
        //
        // The 533pt is still there, above the sentence now instead of between
        // it and the slot: the room the tower has to grow into, with the
        // sentence at its foot rather than its ceiling.
        //
        // The anchor is a zero-height line on the slot's top edge with the
        // sentence hung off its BOTTOM: an `alignmentGuide` through the
        // conditional was ignored and printed the line across the slot.
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: gridW, height: 0)
                .overlay(alignment: .bottomLeading) {
                    if !animCoord.isCascading {
                        towerEmptyStateMessage
                            .padding(.bottom, GridConstants.gapLabel)
                            .frame(width: gridW, alignment: .leading)
                            .transition(.opacity)
                    }
                }
                .allowsHitTesting(false)
        }
        // Bottom-anchored, through the same helper the placed blocks use, so
        // the block grows UP off the ground the way the tower does rather
        // than down through it.
        .offset(x: f.minX, y: flippedY(for: f, gridH: gridH))
    }


    /// The invitation on an empty tower.
    ///
    /// It used to end in a filled "Go to Today" button, which was the loudest
    /// thing on the page and pointed away from it. There is a pressable slot on
    /// the ground now, so the copy names that instead, and scheduling is a
    /// quiet second line rather than the headline.
    /// The screen on an empty morning.
    ///
    /// This is the most-seen screen in the app: every day starts here. So it
    /// gets less, not more.
    ///
    /// Gone: the greeting, which changed four times a day and was never the
    /// reason anyone opened the app; the two-line gesture manual, which
    /// explained a rule that no longer exists; and the secondary button, which
    /// offered a second way to do the one thing the slot right above it does.
    /// A morning does not need to be briefed.
    ///
    /// What is left points at the slot — the only thing on the screen — and
    /// says what pressing it is for, once, quietly.
    private var towerEmptyStateMessage: some View {
        // Leading, on the page's own margin, because every other thing on
        // this screen is: the date, the grid and the slot all start at
        // `horizontalPadding`. Centred copy on a left-aligned page is two
        // alignment systems on one screen, and the eye has to find a new
        // start for one line out of three.
        // **ONE LINE, AT THE WEIGHT EVERY OTHER LINE ON THE PAGE IS SET AT.**
        //
        // It was two: "Nothing yet today" over "Tap the slot to log your first
        // win." in the smaller, quieter pair. Both halves of that failed on
        // 2026-10-01.
        //
        // The first line's reason is written down four hundred lines above and
        // has been deleted: "'Nothing yet today' is a statement about the day
        // and the day is named directly above it." The date came off this
        // header today, so a sentence justified by its neighbour was left
        // standing alone over an empty tower, saying that the empty tower is
        // empty. The owner, the same day: "the areas are very self explanitory
        // and I think over explaining components loses the charm."
        //
        // The second line's SIZE failed the other half of the same message:
        // "no tiny text under or anythign like that ... I like the text that is
        // there to feel like a medium weight." A title over a caption is
        // exactly the shape he named. The line that does work keeps the slot's
        // own vocabulary ("slot", and "tap", which is what `NextSlotButton`'s
        // `onOpenMenu` answers) and takes the title's weight and ink.
        //
        // It is inside the grid's padding now (an overlay on the slot), so it
        // starts on the margin without carrying one of its own.
        Text("Tap the slot to log your first win.")
            .font(Typography.headerMedium)
            .foregroundStyle(AppColors.inkPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Tower Block Views (Extracted for observation isolation)


    private func dismissCard() {
        HapticsEngine.tick()
        try? modelContext.save()
        withAnimation(GridConstants.crossFade) {
            expandedBlockID = nil
        }
    }

    // MARK: - Actions

    // MARK: - Debug Block Injection (temporary)

    #if DEBUG

    #endif


    /// - Returns: whether the record was actually emptied. When it was not,
    ///   nothing after the delete runs and the person is told.
    @discardableResult
    private func resetTower() -> Bool {
        // 1. Read the photograph names while there is still a record to read
        //    them from. Read, NOT removed: the files go in step 3, after the
        //    rows have committed. This used to delete the files first, which
        //    is the shape of the 2026-09-11 bug: a delete that fails leaves
        //    every win naming a photograph that is already gone.
        let photoNames: [String]
        do {
            photoNames = try StoreReset.photographNames(context: modelContext)
        } catch {
            NSLog("[strata-reset] could not read the record, so the reset did not run: \(error)")
            return false
        }

        // 2. Delete every SwiftData entity, ONE OBJECT AT A TIME, in one
        //    transaction.
        //
        // **This was a batch delete and it deleted nothing.** Measured on the
        // simulator, 2026-09-11: `delete(model: HabitLog.self)` fails with
        // "Constraint trigger violation: Batch delete failed due to mandatory
        // OTO nullify inverse on HabitLog/habit", and `Habit` the same on
        // `Habit/tower`. The loop lives in `StoreReset` now, because the debug
        // reset and the seed need the same one and a second copy is a second
        // place for a batch delete to come back.
        let remaining = StoreReset.deleteEverything(context: modelContext)

        // **Stop here if it did not commit.** The transaction rolled back, so
        // every win and every photograph is still there, and carrying on would
        // clear the tower selection, make a fresh default tower beside the old
        // ones and redraw, which is an app that looks reset over a record that
        // is not. Say so instead.
        guard remaining.failure == nil else {
            NSLog("[strata-reset] stopped: \(remaining.line)")
            return false
        }

        // 3. Only now the files, and only the ones no surviving win names.
        let removedPhotos = StoreReset.removePhotographs(photoNames, context: modelContext)
        // Reset runs once, on purpose, so one line about it is worth having in
        // a device log rather than only in DEBUG.
        NSLog("[strata-reset] photographs removed: \(removedPhotos.count) of \(photoNames.count)")
        #if DEBUG
        NSLog("[strata-reset] remaining after reset: \(remaining.line)")
        #endif
        if !remaining.isEmpty {
            NSLog("[strata-reset] reset did not empty the store: \(remaining.line)")
        }

        // 3. Reset UserDefaults (tower selection, first-drop, day boundary)
        //
        // The eleven `onb_*` keys and `hasSeenBlockTapHint` used to be listed
        // here. They belonged to an onboarding system that has been removed —
        // and of the nine flags it wrote, exactly one was ever read back.
        // `hasCompletedFirstHabit` was in the list too and was never declared
        // anywhere at all.
        for key in [
            "activeTowerID",
            "hasSeenFirstDrop", "lastAuroraWeek", "towerShowParallax",
            "lastDayBoundaryCheck",
            "sectionExpanded", "smartViewOverrides", "planSortMode"
        ] {
            UserDefaults.standard.removeObject(forKey: key)
        }

        // 5. Reset in-memory view state
        pendingDrops = []
        expandedBlockID = nil
        animCoord.reset()
        selectedTab = .tower

        // 6. Re-create fresh default tower and set as active
        towerManager.ensureDefaultTower(context: modelContext)
        towerManager.loadActiveTower(context: modelContext)

        // 7. Rebuild all derived state from now-empty database
        refreshData()

        // 8. No wins, so no replay: its notifications go, and the pill is
        // re-decided now rather than when the query next catches up.
        Task { await ReplayReminder.removePending() }
        refreshReplayWindow()
        return true
    }

}

// MARK: - Widget publishing memory

/// The last widget snapshot written and the streak memo, held across
/// refreshes. A plain class, like `TowerGeometryProbe`: written from
/// `refreshData()`, read by nothing on screen, so publishing it would only
/// re-render the app to deliver a value no view draws.
private final class WidgetPublisher {
    var last: WidgetSnapshot?
    var streak = Streaks.Memo()
    /// The days with a win, and the lifetime count they were fetched at.
    var days = Streaks.WidgetDays()
    /// A background day fetch is in flight.
    var fetching = false
    /// The lifetime count the last full fetch was started for. One per
    /// count: when this context holds unsaved changes the store's count never
    /// matches it, and without this every publish started another fetch.
    var fetchedForLifetime: Int?
}

// MARK: - Tab roots that ignore MainAppView's own updates

/// Memories, shielded from the tower's updates.
///
/// A closure cannot be compared, so `MemoriesView(openProfile: { ... })` was
/// a changed input on every `MainAppView` evaluation — every save, every drop
/// phase — and `MemoriesView.body` ran again each time, on a tab nobody was
/// looking at. This compares equal always, which is safe because the closure
/// only writes `MainAppView`'s `@State`, whose storage is the same from one
/// evaluation to the next. `MemoriesView`'s own state, environment and
/// observed models still update it.
private struct StableMemoriesTab: View, Equatable {
    let openProfile: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool { true }

    var body: some View {
        MemoriesView(openProfile: openProfile)
    }
}

/// The camera, shielded the same way and for the same reason.
private struct StableCameraTab: View, Equatable {
    let onCaptured: (UIImage, BlockSize, WinPlace?, CGPoint) -> Void

    static func == (lhs: Self, rhs: Self) -> Bool { true }

    var body: some View {
        CameraView(onCaptured: onCaptured, fillsScreen: true)
    }
}

#Preview {
    MainAppView()
        .modelContainer(for: [Habit.self, HabitLog.self, MoodLog.self, Tower.self], inMemory: true)
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

/// Presents the replay `-strataOpenReplay` asked for. A modifier for the same
/// reason as the one above: `body` is at the type-checker's ceiling.
private struct DebugReplayCover: ViewModifier {
    @Binding var replay: Replay?
    /// `false` for `-strataOpenReplay week|month`: the user's own wins, not
    /// the bundled sample faces.
    let isSample: Bool

    func body(content: Content) -> some View {
        #if DEBUG
        content.fullScreenCover(item: $replay) { shown in
            ReplayView(replay: shown, isSample: isSample) { replay = nil }
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
            try? await Task.sleep(for: .seconds(DebugHarness.flipEvery))
            guard !Task.isCancelled, remaining > 0 else { return }
            remaining -= 1
            var transaction = Transaction()
            transaction.disablesAnimations = true
            let other = DebugHarness.flipTo ?? .camera
            withTransaction(transaction) {
                selected = selected == other ? .tower : other
            }
        }
        #else
        content
        #endif
    }
}

/// The booth, asked for: printing when the goal was just reached.
struct BoothOpening: Identifiable {
    let id = UUID()
    let prints: Bool
    /// An earlier day's strip (`YourDaySheet`), or nil for today's.
    var day: String? = nil
}
