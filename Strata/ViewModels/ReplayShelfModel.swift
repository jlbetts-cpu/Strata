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

    /// How many more times a poster that rendered empty is asked for before
    /// the pass gives up on it. See the loop in `reload`.
    static let emptyRenderRetries = 2

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

    /// **The replay whose window is open right now, unless the page is already
    /// offering it.** (2026-10-01)
    ///
    /// The Wins tab used to carry this as `headerReplayPill`, through
    /// `ReplayEntry.live`. The owner took the pill off — "the your month doesnt
    /// belong on the wins because its already in memories" — and that left the
    /// open WEEK with no route anywhere in the app, because this page offers the
    /// SELECTED MONTH's replay and nothing else. Put to him with the cost named,
    /// his call was that all replays live in Memories. So Memories answers the
    /// question the pill used to answer.
    ///
    /// **A week beats a month, which inverts `ReplayEntry.live`'s preference,
    /// and the reason is that this page is not the Wins tab.** `ReplayEntry`
    /// prefers the month "because it is the rarer event, and the week is on its
    /// shelf either way" — and the week is not on any shelf any more, while a
    /// month is addressed by the picker directly above this row. So on the two
    /// or three days a year when both windows are open, the month is one tap
    /// away by name and the week is nowhere, which decides it. `ReplayEntry.live`
    /// is left alone: it still decides the notifications, where the rarer event
    /// is the better one to interrupt somebody with.
    ///
    /// **It reads the replays already loaded rather than asking the store.**
    /// `ReplayEntry.live` takes a `hasWins` that runs a fetch, and this is read
    /// from a view body. The shelf has already fetched every finished month and
    /// week plus both open periods (`periods(now:)`), so the answer is in hand.
    ///
    /// - Parameter offering: the replay the page's first row already draws.
    static func live(in loaded: [Replay], besides offering: Replay?,
                     now: Date, calendar: Calendar = .current) -> Replay? {
        let open = [ReplayPeriod.current(.week, at: now, calendar: calendar),
                    ReplayPeriod.current(.month, at: now, calendar: calendar)]
        for period in open.compactMap({ $0 }) {
            guard let replay = loaded.first(where: { $0.period == period }) else { continue }
            guard replay.id != offering?.id else { continue }
            return replay
        }
        return nil
    }

    /// **The tallest tower a poster can draw and still be a picture.**
    ///
    /// `posterScale` fits a row's tallest tower into the poster's height, so
    /// a taller month looks taller. That is the right idea and it has a floor
    /// it was falling through: measured on the Memories page with a seeded
    /// September of 138 wins, the shared scale came out at about 0.15, which
    /// drew the four column grid 51 points wide inside a 360 point poster.
    /// Eighty six per cent of the image was blank, and `MonthReplayRow`,
    /// which crops the middle of it into a 116 by 84 thumbnail, showed a
    /// fifteen point stripe of confetti on white. The row's own comment says
    /// a picture 52 points wide is not a picture, it is a stripe. It was
    /// still a stripe, and smaller.
    ///
    /// So the scale stops shrinking once the grid would be narrower than 85%
    /// of the poster. Over that floor every month fills the width and crops at
    /// the top instead, which is how a book cover works: a detail at a size
    /// you can read, not the whole thing reduced until it is a thread.
    ///
    /// **85 and not 55.** 55 was tried first and measured: the thumbnail
    /// became a real mosaic instead of a stripe, and then sat in white
    /// margins, because the row crops the poster to 116 points wide and 55%
    /// of it is 64. The fit-by-width scale is about 0.90 anyway, so a floor
    /// near it costs almost nothing: any month short enough to be scaled by
    /// height is also short enough that its grid already fills the frame.
    ///
    /// The price is that a tall month and a taller one now look the same, and
    /// it is the right price. The count sits in text beside the picture, so
    /// nothing is lost by the picture not also encoding it, and the owner's
    /// read of the old shelf was that it looked like floating blocks.
    ///
    /// What was NOT done: giving the month row its own render. One poster
    /// serves the shelf and the row from one cache, and a second path would
    /// be a second thing to keep true.
    static var legibleTowerHeight: CGFloat {
        let m = ReplayScript.Metrics.standard(frame: ReplayCard.size)
        let gridWidth = GridConstants.gridWidth(cellSize: m.cell)
        let floorScale = 0.85 * ReplayCard.size.width / max(gridWidth, 1)
        return (ReplayCard.size.height - 2 * ReplayCard.posterMargin) / max(floorScale, 0.01)
    }

    /// The tallest finished tower in a row, in world points: what every
    /// poster in that row is scaled against, capped at the height above.
    static func rowTowerHeight(_ replays: [Replay]) -> CGFloat {
        let metrics = ReplayScript.Metrics.standard(frame: ReplayCard.size)
        let tallest = replays.map { GridConstants.gridHeight(rows: $0.rows, cellSize: metrics.cell) }.max() ?? 0
        return min(tallest, legibleTowerHeight)
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
        var emptyRenders = 0
        #endif

        let order = Array(months.prefix(3)) + weeks + Array(months.dropFirst(3))
        for replay in order {
            guard !superseded() else { return }
            // One width for both, since the shelf is one row — see
            // `ReplayCard.posterWidth`.
            let width = ReplayCard.posterWidth
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
            var image = ReplayCard.poster(replay, images: images, scale: scale,
                                          rowTowerHeight: rowHeight, colorScheme: colorScheme, now: now)
            #if DEBUG
            renders.append(CACurrentMediaTime() - slice)
            #endif
            // **An empty render is asked again HERE, not left for "the next
            // reload"** (2026-10-02). The note that stood here said the next
            // reload would try it again, and on this page there is no next
            // reload: the page's `.task` makes three passes at appear and then
            // nothing until the scheme changes, so a poster that came back nil
            // in the last pass would stay a blank well for as long as the page
            // lived. Two more tries a beat apart, then it is left as missing.
            // Measured: 0 empty renders in 8 launches, so this is the latent
            // hole closed, not the blank row the review found (that was the
            // thumbnail's crop, `ReplayRow.thumbnail`).
            var retries = 0
            while image == nil, retries < Self.emptyRenderRetries {
                retries += 1
                #if DEBUG
                emptyRenders += 1
                #endif
                try? await Task.sleep(for: .milliseconds(250))
                guard !superseded() else { return }
                image = ReplayCard.poster(replay, images: images, scale: scale,
                                          rowTowerHeight: rowHeight, colorScheme: colorScheme, now: now)
            }
            // Still empty after that: not recorded as drawn, so a later reload
            // (a scheme change, a deletion, a return to the page) draws it;
            // whatever card was there stays.
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
        print(String(format: "[REPLAY-SHELF] months %d weeks %d, fetch %.1fms, cards drawn %d, empty renders %d (render max %.1fms, sum %.1fms), longest main-actor slice %.1fms, total %.1fms",
                     months.count, weeks.count, (fetched - began) * 1000, renders.count, emptyRenders,
                     (renders.max() ?? 0) * 1000, renders.reduce(0, +) * 1000,
                     (slices.max() ?? 0) * 1000, (end - began) * 1000))
        #endif
    }
}
