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

/// **The real tab, found** (2026-10-16). The bar is the system's and its
/// buttons carry no names a view can be found by, so the tab is found by
/// where it is: the bar's visible tab pictures, gathered into columns left
/// to right, and the column at the tab's place in `StrataTab`. Public UIKit
/// only: frames, visibility and a transform on the picture. When it cannot
/// be found the hand-off still plays, to the tab's usual place.
@MainActor
enum TabGlyph {
    /// Every visible picture of the tab at `index` (the bar draws a tab twice,
    /// once for the glass lens over it).
    static func pictures(at index: Int) -> [UIImageView] {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        for window in windows {
            guard let bar = first(in: window, where: { $0 is UITabBar && !$0.isHidden }) else { continue }
            var images: [UIImageView] = []
            collect(in: bar, into: &images)
            let visible = images.filter { image in
                guard image.bounds.width >= 16, image.bounds.width <= 44, image.superview is UIControl else { return false }
                var v: UIView? = image
                while let view = v { if view.isHidden || view.alpha < 0.01 { return false }; v = view.superview }
                return true
            }
            // Columns: pictures whose middles are within a few points.
            var columns: [(x: CGFloat, views: [UIImageView])] = []
            for image in visible {
                let x = image.convert(CGPoint(x: image.bounds.midX, y: image.bounds.midY), to: nil).x
                if let k = columns.firstIndex(where: { abs($0.x - x) < 8 }) {
                    columns[k].views.append(image)
                } else {
                    columns.append((x, [image]))
                }
            }
            columns.sort { $0.x < $1.x }
            guard columns.count == StrataTab.allCases.count, columns.indices.contains(index) else { return [] }
            return columns[index].views
        }
        return []
    }

    static func index(of tab: StrataTab) -> Int { StrataTab.allCases.firstIndex(of: tab) ?? 0 }

    /// The bar's own glass shape, in the window: the widest visible view
    /// inside the tab bar.
    static func barFrame() -> CGRect? {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        for window in windows {
            guard let bar = first(in: window, where: { $0 is UITabBar && !$0.isHidden }) else { continue }
            let platter = bar.subviews.filter { !$0.isHidden && $0.alpha > 0.01 }.max { $0.bounds.width < $1.bounds.width }
            return platter.map { $0.convert($0.bounds, to: nil) }
        }
        return nil
    }

    /// A tab's button (the pill's place) and its picture, in the window.
    static func frames(of tab: StrataTab) -> (button: CGRect, picture: CGRect)? {
        guard let image = pictures(at: index(of: tab)).first, let button = image.superview else { return nil }
        return (button.convert(button.bounds, to: nil), image.convert(image.bounds, to: nil))
    }

    /// The tab's name under its picture, when Show Tab Names has put one
    /// there: its frame in the window and its font, so a drawing of the bar
    /// can say it in the same place (`CameraTabBarSkin`).
    static func title(of tab: StrataTab) -> (frame: CGRect, font: UIFont)? {
        guard let image = pictures(at: index(of: tab)).first, let button = image.superview,
              let label = first(in: button, where: { ($0 as? UILabel)?.text?.isEmpty == false }) as? UILabel
        else { return nil }
        return (label.convert(label.bounds, to: nil), label.font)
    }

    /// The tab's picture, in the window.
    static func frame(of tab: StrataTab) -> CGRect? {
        guard let image = pictures(at: index(of: tab)).first else { return nil }
        return image.convert(image.bounds, to: nil)
    }

    /// **It takes one**: a quick swell and a spring back.
    static func gulp(_ tab: StrataTab) {
        for image in pictures(at: index(of: tab)) {
            UIView.animate(withDuration: 0.09, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
                image.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
            } completion: { _ in
                UIView.animate(withDuration: 0.42, delay: 0, usingSpringWithDamping: 0.45, initialSpringVelocity: 0,
                               options: [.beginFromCurrentState, .allowUserInteraction]) {
                    image.transform = .identity
                }
            }
        }
    }

    private static func collect(in view: UIView, into out: inout [UIImageView]) {
        if let image = view as? UIImageView { out.append(image) }
        for sub in view.subviews { collect(in: sub, into: &out) }
    }

    private static func first(in view: UIView, where test: (UIView) -> Bool) -> UIView? {
        if test(view) { return view }
        for sub in view.subviews {
            if let hit = first(in: sub, where: test) { return hit }
        }
        return nil
    }
}

/// **The tower that goes into Memories, a piece at a time** (the owner,
/// 2026-10-16: the blocks "jump off one by one into the Memories icon", and
/// the icon "animates as if taking them"). Drawn by `StaticTowerView`, the
/// real blocks, so what leaves is exactly what you built. From the top down,
/// each piece hops and arcs into the Memories tab (`TowerHop`), and the tab
/// swells as each one lands (`TabGlyph.gulp`) with a tick under the finger.
/// Under Reduce Motion it fades where it stands.
///
/// It went as one shrinking tower before, aimed at 70.5% of the width: the
/// Memories tab when the bar had three tabs. With four, that was the gap
/// between Camera and Memories. The tab's place is measured now.
struct DayHandoffLayer: View {
    let logs: [HabitLog]
    let modelContext: ModelContext
    var finished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var vm = TowerViewModel()
    @State private var built = false
    @State private var gone = false
    @State private var goneCount = 0
    /// The Memories tab in the window, once found.
    @State private var tabFrame: CGRect?

    /// How long yesterday stands before it goes, each piece's flight at
    /// most and least, and the breath after one lands before the next goes.
    static let hold: Double = 0.45
    static let flightLongest: Double = 0.45
    static let flightShortest: Double = 0.26
    static let landing: Double = 0.08

    static func flight(pieces: Int) -> Double {
        let budget = 5.0 / Double(max(pieces, 1)) - landing
        return min(flightLongest, max(flightShortest, budget))
    }

    @State private var towerHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width - GridConstants.horizontalPadding * 2
            // Standing where the Wins tower stands: on its foot, above the
            // tab bar, the width of the page.
            let rest = CGPoint(x: geo.size.width / 2,
                               y: geo.size.height - Self.restingLift - towerHeight / 2)
            let target = target(in: geo)
            if built {
                StaticTowerView(blocks: vm.placedBlocks, mergeGroups: vm.mergeGroups,
                                groupedIDs: vm.groupedBlockIDs, coveredIDs: vm.coveredBlockIDs,
                                modelContext: modelContext, width: width, maxCell: 200)
                    .environment(\.towerFilterMode, .day)
                    .environment(\.towerLeaving, reduceMotion ? nil
                                 : TowerLeaving(gone: goneCount, to: CGSize(width: target.x - rest.x, height: target.y - rest.y)))
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { towerHeight = $0 }
                    .position(rest)
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
            tabFrame = TabGlyph.frame(of: .memories)
            guard !reduceMotion else {
                withAnimation(GridConstants.crossFade) { gone = true }
                try? await Task.sleep(for: .seconds(0.25))
                HapticsEngine.lightTap()
                finished()
                return
            }
            let pieces = TowerPieces.count(blocks: vm.placedBlocks, groups: vm.mergeGroups)
            // **One at a time** (the owner, 2026-10-16: "make sure the
            // animation is one at a time"): a piece goes only once the one
            // before it has landed. Each flight shortens on a big day so the
            // whole of it stays near five seconds.
            let flight = Self.flight(pieces: pieces)
            for i in 0..<pieces {
                withAnimation(.timingCurve(0.35, 0, 0.45, 1, duration: flight)) { goneCount = i + 1 }
                try? await Task.sleep(for: .seconds(flight * 0.92))
                TabGlyph.gulp(.memories)
                HapticsEngine.tick()
                try? await Task.sleep(for: .seconds(Self.landing))
            }
            try? await Task.sleep(for: .seconds(0.2))
            finished()
        }
    }

    /// The Memories tab's middle in this layer, or its usual place: the
    /// last of four across the bar.
    private func target(in geo: GeometryProxy) -> CGPoint {
        let origin = geo.frame(in: .global).origin
        if let tabFrame {
            return CGPoint(x: tabFrame.midX - origin.x, y: tabFrame.midY - origin.y)
        }
        return CGPoint(x: geo.size.width * 0.81, y: geo.size.height + geo.safeAreaInsets.bottom - 30)
    }

    /// Where the tower's foot stands above the bottom of the screen, as the
    /// Wins tower does above the tab bar (`DayAlbumDetailView.groundGap`'s
    /// measurement: about 91pt).
    private static let restingLift: CGFloat = 91
}
