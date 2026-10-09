import SwiftData
import SwiftUI

/// **Yesterday goes into Memories** (the unification pass, 2026-10-09; the
/// owner: "the daily resets must visibly flow into Memories so nothing feels
/// erased... the user should feel both the fresh daily start and the sense
/// that it's all piling up").
///
/// The Wins tower is a new canvas every day, on purpose. The first time Wins
/// is seen on a new day, if yesterday had wins, yesterday's tower stands
/// where it stood for a breath, then shrinks and glides into the Memories
/// tab, and today's empty ground is what is left. No words, no badge, no
/// count: the motion says it. On the next visit to Memories, yesterday's day
/// on the calendar settles in once (`DayHandoff.arrived`).
///
/// Never after a day with no wins: nothing is announced about a quiet day.
nonisolated enum DayHandoff {
    /// The last day the hand-off was decided, played or not.
    static let lastDayKey = "handoff.lastDay"
    /// The day that just went into Memories, for its calendar cell to
    /// settle once; cleared when Memories has shown it.
    static let arrivedKey = "handoff.arrivedDay"

    /// The day to hand off now, or nil: the day before `today`, once per
    /// day, only when it had a win.
    static func due(today: String, lastDecided: String?, yesterday: String, yesterdayHadWins: Bool) -> String? {
        guard lastDecided != today, yesterdayHadWins else { return nil }
        return yesterday
    }
}

/// The tower that glides. Drawn by `StaticTowerView`, the real blocks, so
/// what leaves is exactly what you built.
struct DayHandoffLayer: View {
    let logs: [HabitLog]
    let modelContext: ModelContext
    var finished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var vm = TowerViewModel()
    @State private var built = false
    @State private var gone = false

    /// How long yesterday stands before it goes, and how long it travels.
    static let hold: Double = 0.45
    static let travel: Double = 0.75

    @State private var towerHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width - GridConstants.horizontalPadding * 2
            // Standing where the Wins tower stands: on its foot, above the
            // tab bar, the width of the page.
            let rest = CGPoint(x: geo.size.width / 2,
                               y: geo.size.height - Self.restingLift - towerHeight / 2)
            // The Memories tab, the third of the bar's three: where the tower
            // goes. The bar is the system's, so this is its measured place on
            // the screen rather than a frame read from it.
            let target = CGPoint(x: geo.size.width * 0.705,
                                 y: geo.size.height + geo.safeAreaInsets.bottom - 30)
            let travels = gone && !reduceMotion
            if built {
                StaticTowerView(blocks: vm.placedBlocks, mergeGroups: vm.mergeGroups,
                                groupedIDs: vm.groupedBlockIDs, coveredIDs: vm.coveredBlockIDs,
                                modelContext: modelContext, width: width, maxCell: 200)
                    .environment(\.towerFilterMode, .day)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { towerHeight = $0 }
                    .scaleEffect(travels ? 0.06 : 1)
                    .position(rest)
                    .offset(x: travels ? target.x - rest.x : 0, y: travels ? target.y - rest.y : 0)
                    .opacity(gone ? 0 : 1)
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            _ = vm.buildTower(from: logs, filterMode: .day)
            built = true
            await MainAppView.waitForLaunchToFinish()
            try? await Task.sleep(for: .seconds(Self.hold))
            withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.dayHandoffTravel) {
                gone = true
            }
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.25 : Self.travel))
            HapticsEngine.lightTap()
            finished()
        }
    }

    /// Where the tower's foot stands above the bottom of the screen, as the
    /// Wins tower does above the tab bar (`DayAlbumDetailView.groundGap`'s
    /// measurement: about 91pt).
    private static let restingLift: CGFloat = 91
}
