import SwiftData
import SwiftUI

/// What the Replays section shows: finished months and recent weeks that had
/// a win, each with its card rendered once and kept.
///
/// **Kept here, in memory, not in `ThumbnailStore`.** A card is cheap to draw
/// again after a relaunch and it is only ever shown on this one page, which
/// holds this model for as long as the tab lives. Keyed by period and a
/// signature of what the card draws, so an edit to a past week redraws its
/// card and nothing else does.
@Observable
final class ReplayShelfModel {
    var months: [Replay] = []
    var weeks: [Replay] = []
    /// Whether a reload has found out which periods have a replay. Until then
    /// empty `months` and `weeks` mean "not asked yet", not "none", and the
    /// page must not tell someone with last month's replay that their first
    /// month starts here.
    private(set) var hasLoaded = false
    /// The `now` the last reload chose its periods against. The shelf words
    /// its names against it, so the two agree.
    private(set) var now = Date()
    /// By `key(_:scheme:)`: a poster is drawn in the page's scheme, and both
    /// schemes are kept so switching back does not redraw the shelf.
    var cards: [String: UIImage] = [:]
    /// Card key -> the signature it was drawn from.
    @ObservationIgnored private var drawn: [String: Int] = [:]
    /// A reload that finds a newer one started stops drawing.
    @ObservationIgnored private var generation = 0
    /// The store and the periods the rows were last found from. When neither
    /// has changed the rows are still right and the up to 32 queries behind
    /// them are skipped: every visit to Memories used to make them all again.
    @ObservationIgnored private var foundFrom: (store: StoreSignature, periods: [String])?
    /// The last pass that left every card for a scheme and scale up to date.
    /// Asked again with nothing changed, there is nothing to draw and nothing
    /// to sign: the pass is skipped outright.
    @ObservationIgnored private var completePass: (store: StoreSignature, periods: [String], card: String)?

    static let monthCount = 12
    static let weekCount = 4

    static func periods(now: Date, calendar: Calendar = .current) -> (months: [ReplayPeriod], weeks: [ReplayPeriod]) {
        var months = ReplayPeriod.finished(.month, before: now, count: monthCount, calendar: calendar)
        var weeks = ReplayPeriod.finished(.week, before: now, count: weekCount, calendar: calendar)
        if let open = ReplayPeriod.current(.month, at: now, calendar: calendar), !months.contains(open) { months.insert(open, at: 0) }
        if let open = ReplayPeriod.current(.week, at: now, calendar: calendar), !weeks.contains(open) { weeks.insert(open, at: 0) }
        return (months, weeks)
    }

    static func key(_ replay: Replay, scheme: ColorScheme) -> String {
        "\(replay.id)-\(scheme == .dark ? "dark" : "light")"
    }

    /// The tallest finished tower in a row, in world points: what every
    /// poster in that row is scaled against.
    static func rowTowerHeight(_ replays: [Replay]) -> CGFloat {
        let metrics = ReplayScript.Metrics.standard(frame: ReplayCard.size)
        return replays.map { GridConstants.gridHeight(rows: $0.rows, cellSize: metrics.cell) }.max() ?? 0
    }

    /// Everything a poster draws. The spec's count plus newest id misses a
    /// photograph added to or removed from a win that is not the newest, and
    /// a card is mostly photographs; this costs one pass over at most a
    /// month of blocks. The row's tallest tower is in it too: a new, taller
    /// month rescales, and so redraws, every poster in its row.
    static func signature(_ replay: Replay, rowTowerHeight: CGFloat = 0, pixelScale: CGFloat = 0) -> Int {
        var h = Hasher()
        h.combine(rowTowerHeight)
        h.combine(pixelScale)
        h.combine(replay.count)
        for b in replay.blocks {
            h.combine(b.id)
            h.combine(b.win.photo)
            h.combine(b.win.size)
            h.combine(b.win.category)
            h.combine(b.win.title)
            h.combine(b.win.crop.x)
            h.combine(b.win.crop.y)
        }
        return h.finalize()
    }

    /// Fetches the periods, then draws any card that is missing or stale.
    ///
    /// One card at a time with a yield between, so the drawer keeps drawing
    /// while the shelf fills in. The cards a person sees first (the newest
    /// months and every week) are drawn first.
    ///
    /// Stops at the next period or card when its task is cancelled (the page
    /// went away) or a newer reload started.
    ///
    /// `redrawsStale` false: a card that is MISSING is drawn, but one that is
    /// only out of date keeps its old poster and waits. Redrawing runs
    /// `ImageRenderer` on the main actor, and after any new win the current
    /// week's and month's cards are stale — so every visit to the tab redrew
    /// them under a map where the shelf could not even be seen. The page asks
    /// again, with true, when the drawer is raised.
    func reload(context: ModelContext, colorScheme: ColorScheme, displayScale: CGFloat, now: Date,
                redrawsStale: Bool = true, drawsMissing: Bool = true) async {
        generation += 1
        let mine = generation
        func superseded() -> Bool { mine != generation || Task.isCancelled }
        #if DEBUG
        let began = CACurrentMediaTime()
        var slices: [Double] = []
        var slice = began
        #endif

        let p = Self.periods(now: now)
        let store = StoreSignature.current(context: context)
        let periodIDs = (p.months + p.weeks).map(\.id)
        let unchanged = hasLoaded && foundFrom.map { $0.store == store && $0.periods == periodIDs } == true
        // A count with a limit of one per period first: most of a year of
        // months is usually empty, and a full fetch of an empty range is
        // still a fetch. **One period per slice.** Fetched in one pass, a
        // year of seeded history (`-strataSeedHistory 400`) held the main
        // actor for 202ms; one period at a time, no slice of the whole
        // reload, card drawing included, measured over 64ms.
        var found: [Replay] = unchanged ? months + weeks : []
        for period in unchanged ? [] : p.months + p.weeks {
            guard !superseded() else { return }
            guard ReplayLoader.hasWins(period, context: context) else { continue }
            let replay = ReplayLoader.replay(for: period, context: context)
            if replay.count > 0 { found.append(replay) }
            #if DEBUG
            slices.append(CACurrentMediaTime() - slice)
            #endif
            await Task.yield()
            guard !superseded() else { return }
            #if DEBUG
            slice = CACurrentMediaTime()
            #endif
        }
        self.now = now
        if !unchanged {
            months = found.filter { $0.period.kind == .month }
            weeks = found.filter { $0.period.kind == .week }
            foundFrom = (store, periodIDs)
        }
        if !hasLoaded { hasLoaded = true }
        let live = Set((months + weeks).flatMap { [Self.key($0, scheme: .light), Self.key($0, scheme: .dark)] })
        for key in cards.keys where !live.contains(key) {
            cards[key] = nil
            drawn[key] = nil
        }
        let pass = "\(colorScheme == .dark ? "dark" : "light")-\(displayScale)"
        if unchanged, let done = completePass, done.store == store, done.periods == periodIDs, done.card == pass {
            #if DEBUG
            PerfProbe.emit(String(format: "[PERF-SPAN] ReplayShelfModel.reload main %.1fms (unchanged, nothing to draw)",
                                  (CACurrentMediaTime() - began) * 1000))
            #endif
            return
        }
        /// A card left stale or undrawn: this pass does not count as complete.
        var skippedStale = false
        let heights: [ReplayKind: CGFloat] = [.month: Self.rowTowerHeight(months), .week: Self.rowTowerHeight(weeks)]
        #if DEBUG
        let fetched = CACurrentMediaTime()
        slices.append(fetched - slice)
        var renders: [Double] = []
        #endif

        let order = Array(months.prefix(3)) + weeks + Array(months.dropFirst(3))
        for replay in order {
            guard !superseded() else { return }
            let width = replay.period.kind == .month ? ReplayCard.monthPosterWidth : ReplayCard.weekPosterWidth
            let scale = width * displayScale / ReplayCard.size.width
            let rowHeight = heights[replay.period.kind] ?? 0
            let key = Self.key(replay, scheme: colorScheme)
            let signature = Self.signature(replay, rowTowerHeight: rowHeight, pixelScale: scale)
            guard drawn[key] != signature else { continue }
            // Stale, not missing, and nobody can see the shelf: keep the old one.
            guard redrawsStale || cards[key] == nil else { skippedStale = true; continue }
            // Missing, and the caller says nobody can see it yet: not now.
            guard drawsMissing || cards[key] != nil else { skippedStale = true; continue }
            #if DEBUG
            slices.append(CACurrentMediaTime() - slice)
            #endif
            let images = await ReplayImages.load(replay, cellPixels: ReplayCard.cell * scale)
            guard !superseded() else { return }
            #if DEBUG
            slice = CACurrentMediaTime()
            #endif
            let image = ReplayCard.poster(replay, images: images, scale: scale,
                                          rowTowerHeight: rowHeight, colorScheme: colorScheme, now: now)
            #if DEBUG
            renders.append(CACurrentMediaTime() - slice)
            #endif
            // A render that came back empty is not recorded as drawn, so the
            // next reload tries it again; whatever card was there stays.
            if let image {
                cards[key] = image
                drawn[key] = signature
            } else {
                skippedStale = true
            }
            #if DEBUG
            slices.append(CACurrentMediaTime() - slice)
            #endif
            await Task.yield()
            guard !superseded() else { return }
            #if DEBUG
            slice = CACurrentMediaTime()
            #endif
        }

        if !skippedStale { completePass = (store, periodIDs, pass) }

        #if DEBUG
        let end = CACurrentMediaTime()
        PerfProbe.emit(String(format: "[PERF-SPAN] ReplayShelfModel.reload main %.1fms (longest slice %.1fms, cards drawn %d, wall %.1fms)",
                              slices.reduce(0, +) * 1000, (slices.max() ?? 0) * 1000, renders.count, (end - began) * 1000))
        print(String(format: "[REPLAY-SHELF] months %d weeks %d, fetch %.1fms, cards drawn %d (render max %.1fms, sum %.1fms), longest main-actor slice %.1fms, total %.1fms",
                     months.count, weeks.count, (fetched - began) * 1000, renders.count,
                     (renders.max() ?? 0) * 1000, renders.reduce(0, +) * 1000,
                     (slices.max() ?? 0) * 1000, (end - began) * 1000))
        #endif
    }
}
