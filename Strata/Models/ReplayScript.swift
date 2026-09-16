import CoreGraphics
import Foundation
import os

/// A replay, as a pure function of time.
///
/// **There is no animation state anywhere in a replay.** Everything on screen
/// at time `t` is computed here from the replay and `t`. That is what makes it
/// clean: nothing stacks, pausing and skipping cannot put anything out of step,
/// the same function draws the live view and every frame of the saved video,
/// and it can be tested by evaluating it.
///
/// Coordinates: WORLD is the tower at full size, `minY` measured up from the
/// base, the way `GridConstants.blockFrame` gives it. SCREEN is the replay's
/// frame, y down. A world height `h` is drawn at
/// `metrics.baseY - camera.scale * (h - camera.rise)`.
struct ReplayScript {

    #if DEBUG
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Strata", category: "ReplayScript")
    #endif

    struct Metrics: Equatable {
        var frame: CGSize
        var cell: CGFloat
        /// Screen y of the tower's base.
        var baseY: CGFloat
        /// While following, the top of the tower is held at this screen y.
        var followY: CGFloat
        /// After the reveal, the finished tower's top may come no higher.
        var fitTopY: CGFloat
        /// Where the close's controls row starts, live. In the video, which
        /// draws no controls, the frame's usable bottom.
        var closeTop: CGFloat = 0

        /// The replay's lines for a frame.
        ///
        /// **Laid out from what is on the screen, not from fractions**
        /// (the owner, 2026-09-15: "use the whole screen; right now the
        /// buttons sit kinda high when there's a lot of space below"). When
        /// the caller says how tall the count and title stand (`topCopy`):
        /// - the controls row sits a fixed margin above the home indicator
        ///   (`gapWide` over the bottom inset, never under `gapSection` from
        ///   the edge), so no dead band opens under it on a tall phone;
        /// - the tower's base stands `gapWide` above the controls, and the
        ///   finished tower's top may rise to `gapWide` under the title, so
        ///   it fills the space between them with the same air above and
        ///   below;
        /// - with no controls (the video) the base takes their room too.
        ///
        /// `followY` stays at 0.24 of the frame, a clear gap under the count
        /// during the build, and never above where the finished top may go.
        ///
        /// Without `topCopy` (the script's tests, and anything that only
        /// wants a cell) the lines are the fractions they were set to at
        /// 402x874: base 0.79, fitted top 0.18.
        static func standard(frame: CGSize, topInset: CGFloat = 0, topCopy: CGFloat = 0,
                             bottomInset: CGFloat = 0, controlsHeight: CGFloat = 0) -> Metrics {
            let cell = GridConstants.cellSize(forGridWidth: frame.width - GridConstants.horizontalPadding * 2)
            guard topCopy > 0 else {
                let baseY = (frame.height * 0.79).rounded()
                return Metrics(frame: frame, cell: cell, baseY: baseY,
                               followY: (frame.height * 0.24).rounded(),
                               fitTopY: (frame.height * 0.18).rounded(),
                               closeTop: baseY + GridConstants.gapWide)
            }
            let air = GridConstants.gapWide
            let bottom = max(bottomInset + GridConstants.gapWide, GridConstants.gapSection)
            let closeTop = (frame.height - bottom - controlsHeight).rounded()
            let baseY = controlsHeight > 0 ? closeTop - air : closeTop
            let fitTopY = (topInset + topCopy + air).rounded()
            return Metrics(frame: frame, cell: cell, baseY: baseY,
                           followY: max((frame.height * 0.24).rounded(), fitTopY),
                           fitTopY: fitTopY, closeTop: closeTop)
        }
    }

    struct Pacing {
        var buildBudget: Double
        var buildCap: Double
        var air: Double
        var emptyHold: Double
        var reveal: Double
        var reduceMotionSpan: Double
        /// The whole replay, open to the last of the close, never runs longer
        /// than this, for any number of wins. The spec's promise, and a hard
        /// one: a real 154-win fortnight measured 27.64s against 28, and a
        /// full month with more wins would have passed it.
        var totalCap: Double
        let open = 0.9
        let holdAfterLast = 0.5
        let minGap = 0.14
        let maxGap = 0.55
        let floorGap = 0.04
        let cameraLead = 0.25
        /// The build camera starts rising for the first block that needs it
        /// no earlier than this before that block lands.
        let cameraEarliestRise = 0.75
        /// Points the build camera's corridor is narrowed by on both sides, so
        /// the curve's rounding between corners has room before it clips a
        /// landing block or carries a waiting one into the frame. What rounding
        /// still escapes is caught by the repair pass after the curve is built.
        let cameraCorridorMargin = 3.0
        /// Points under the drop clearance a ceiling sits at, so a block's
        /// bottom edge is at least this far above the frame at its first
        /// instant rather than exactly on the edge.
        let cameraCeilingSlack = 2.0
        /// How many times the repair pass may add keys before it stops.
        let cameraRepairPasses = 12
        /// How far the title and the close's controls rise as they arrive.
        let arriveSlide: CGFloat = 8
        /// How long the title and the controls take to arrive. Longer
        /// than the 0.3s linear fade they replaced, and eased out, so they
        /// settle rather than switch on (the owner, 2026-09-15: "the text
        /// needs a better animation").
        let arrive = 0.45
        let danceWave = 0.6
        /// Reduce Motion's blocks fade in over this.
        let closeFade = 0.3
        /// Between the date arriving and a Settings preview's "Sample" after
        /// it, and the step Reduce Motion's close adds to the replay's end.
        let closeStagger = 0.08
        let squashTime = 0.35
        /// How long the count takes to fade in at the open.
        let headerFade = 0.5
        /// The count's digit roll: at most this long, and never longer than
        /// the time to the next landing, so a roll always finishes before
        /// the next one starts.
        let rollTime = 0.16
        /// The squash-and-stretch settle: an exponentially decaying cosine.
        let squashDecay = 0.08
        let squashPeriod = 0.22

        static func of(_ kind: ReplayKind) -> Pacing {
            switch kind {
            case .week: Pacing(buildBudget: 10, buildCap: 12.5, air: 0.35, emptyHold: 0.45, reveal: 1.0, reduceMotionSpan: 4, totalCap: 18)
            case .month: Pacing(buildBudget: 18, buildCap: 22, air: 0.12, emptyHold: 0.2, reveal: 1.4, reduceMotionSpan: 6, totalCap: 28)
            }
        }
    }

    struct BlockPose: Equatable {
        var visible = false
        var opacity: Double = 1
        /// Screen points above the landed position (negative is up).
        var fallOffset: CGFloat = 0
        var scaleX: CGFloat = 1
        var scaleY: CGFloat = 1
        /// World points, negative is up. The dance.
        var lift: CGFloat = 0
        var tilt: Double = 0
    }

    struct Camera: Equatable {
        var rise: CGFloat
        var scale: CGFloat
    }

    /// The win count's roll at a moment: what it reads, what it read
    /// before the latest landing, and how far through the change it is
    /// (1 when settled).
    struct CountRoll: Equatable {
        var count: Int
        var previous: Int
        var progress: Double
    }

    /// One digit position of the count, right-aligned: the digit arriving,
    /// the digit leaving, and whether this position changes at all. Only a
    /// position that changes moves.
    struct DigitSlot: Equatable {
        var new: Character?
        var old: Character?
        var changes: Bool { new != old }
    }

    /// A line arriving: its opacity and how far below its place it still is.
    struct Arrival: Equatable {
        var opacity: Double
        var offset: CGFloat
    }

    struct Landing: Equatable {
        let time: Double
        let mass: Int
        let column: Int
        let blockIndex: Int
    }

    enum Phase: Equatable { case opening, building, revealing, dancing, closed }

    let replay: Replay
    let metrics: Metrics
    let reduceMotion: Bool
    let pacing: Pacing

    let gridWidth: CGFloat
    let towerHeight: CGFloat
    let fitScale: CGFloat
    let revealStart: Double
    let revealDuration: Double
    let danceStart: Double
    let closeStart: Double
    let duration: Double
    let landings: [Landing]

    /// Every landing's time, sorted: what the count is read from.
    private let landingTimes: [Double]
    private let starts: [Double]
    private let fallTimes: [Double]
    private let fallDistances: [CGFloat]
    private let dayStarts: [Double]
    private let danceDelays: [Double]
    private let cameraCurve: MonotoneCurve
    private let finalRise: CGFloat

    init(replay: Replay, metrics: Metrics, reduceMotion: Bool) {
        self.replay = replay
        self.metrics = metrics
        self.reduceMotion = reduceMotion
        let pacing = Pacing.of(replay.period.kind)
        self.pacing = pacing

        let cell = metrics.cell
        gridWidth = GridConstants.gridWidth(cellSize: cell)
        towerHeight = GridConstants.gridHeight(rows: replay.rows, cellSize: cell)
        fitScale = towerHeight > 0 ? min(1, (metrics.baseY - metrics.fitTopY) / towerHeight) : 1

        let n = replay.blocks.count
        let frames = replay.blocks.map {
            GridConstants.blockFrame(column: $0.column, row: $0.row,
                                     columnSpan: $0.columnSpan, rowSpan: $0.rowSpan, cellSize: cell)
        }

        if reduceMotion {
            // Day by day, evenly across the span; nothing moves.
            // Local temporaries, not the stored properties: a struct
            // initializer cannot capture `self` in a closure until every
            // stored property is definitely initialized.
            let step = pacing.reduceMotionSpan / Double(max(1, replay.period.days.count))
            let dayStartsLocal = replay.period.days.indices.map { pacing.open + Double($0) * step }
            let startsLocal = replay.blocks.map { dayStartsLocal[$0.day] }
            dayStarts = dayStartsLocal
            starts = startsLocal
            fallTimes = Array(repeating: 0, count: n)
            fallDistances = Array(repeating: 0, count: n)
            landings = replay.blocks.indices.map {
                Landing(time: startsLocal[$0], mass: replay.blocks[$0].win.size.massTier,
                        column: replay.blocks[$0].column, blockIndex: $0)
            }.sorted { $0.time < $1.time }
            landingTimes = landings.map(\.time)
            cameraCurve = MonotoneCurve(points: [(0, 0)])
            finalRise = 0
            revealStart = pacing.open + pacing.reduceMotionSpan + pacing.closeFade
            revealDuration = 0
            danceStart = revealStart
            danceDelays = Array(repeating: 0, count: n)
            closeStart = revealStart
            duration = closeStart + Self.closeLength(pacing)
            return
        }

        // Spacing between drops, solved from the count.
        let winDays = replay.countsByDay.filter { $0 > 0 }.count
        let emptyDays = replay.countsByDay.count - winDays
        let air = pacing.air * Double(max(0, winDays - 1)) + pacing.emptyHold * Double(emptyDays)
        var gap = n > 0 ? (pacing.buildBudget - air) / Double(n) : 0
        gap = min(max(gap, pacing.minGap), pacing.maxGap)
        if n > 0, Double(n) * gap + air > pacing.buildCap {
            gap = max(pacing.floorGap, (pacing.buildCap - air) / Double(n))
        }

        // Drop OFFSETS, walking the days: where each drop and each day would
        // start with every interval at full length, measured from the open.
        var offset = 0.0
        var dayOffsets: [Double] = []
        var dropOffsets = Array(repeating: 0.0, count: n)
        var i = 0
        for count in replay.countsByDay {
            dayOffsets.append(offset)
            if count == 0 { offset += pacing.emptyHold; continue }
            if i > 0 { offset += pacing.air }
            for _ in 0..<count { dropOffsets[i] = offset; offset += gap; i += 1 }
        }

        // Camera targets and fall distances, block by block in drop order.
        // None of this depends on when a block starts, only on where it lands.
        let followHeight = metrics.baseY - metrics.followY
        var top: CGFloat = 0
        var rises = Array(repeating: CGFloat(0), count: n)
        var times = Array(repeating: 0.0, count: n)
        var distances = Array(repeating: CGFloat(0), count: n)
        for k in 0..<n {
            top = max(top, frames[k].minY + frames[k].height)
            rises[k] = max(0, top - followHeight)
            // Screen top of the block once landed, with the camera at its target.
            let landedTop = metrics.baseY - (frames[k].minY + frames[k].height - rises[k])
            let d = landedTop + GridConstants.dropClearance + frames[k].height
            distances[k] = d
            let raw = (2 * Double(d) / Double(GridConstants.dropGravity)).squareRoot()
            times[k] = min(max(raw, GridConstants.dropDurationRange.lowerBound),
                           GridConstants.dropDurationRange.upperBound)
        }
        fallTimes = times
        fallDistances = distances

        // What follows the build, none of which is compressed: the reveal,
        // the dance and the close.
        let revealLength = (fitScale < 1 || (rises.max() ?? 0) > 0) ? pacing.reveal : 0
        let rowDelay = GridConstants.danceRowDelay
        let travel = Double(replay.rows) * rowDelay
        let squeeze = travel > GridConstants.danceTravelCap ? GridConstants.danceTravelCap / travel : 1
        let delays = replay.blocks.map { Double($0.row) * rowDelay * squeeze }
        let afterBuild = revealLength + (delays.max() ?? 0) + pacing.danceWave
            + Self.closeLength(pacing)
        let trailingEmpty = replay.countsByDay.last == 0

        // **The cap is hard.** The build's reveal starts at the latest of
        // every landing plus the hold, and a trailing empty day's own moment.
        // Each is `open + c * offset + fixed`, so the largest `c` in (0, 1]
        // that ends the whole replay on `totalCap` is solved directly. It
        // scales the gaps between drops, the air between days and the empty
        // days' holds together, so the shape of the build is kept. `floorGap`
        // may be undercut and falls may overlap; that is intended. At 1, as
        // for every replay that already fits, nothing changes.
        let latestReveal = pacing.totalCap - afterBuild
        var compression = 1.0
        func buildEnd(at c: Double) -> Double {
            var r = pacing.open + pacing.holdAfterLast
            for k in 0..<n { r = max(r, pacing.open + c * dropOffsets[k] + times[k] + pacing.holdAfterLast) }
            if trailingEmpty, let lastDay = dayOffsets.last {
                r = max(r, pacing.open + c * (lastDay + pacing.emptyHold))
            }
            return r
        }
        if buildEnd(at: 1) > latestReveal {
            for k in 0..<n where dropOffsets[k] > 0 {
                compression = min(compression, (latestReveal - pacing.open - times[k] - pacing.holdAfterLast) / dropOffsets[k])
            }
            if trailingEmpty, let lastDay = dayOffsets.last, lastDay + pacing.emptyHold > 0 {
                compression = min(compression, (latestReveal - pacing.open) / (lastDay + pacing.emptyHold))
            }
            compression = min(max(compression, 0), 1)
        }
        let startList = dropOffsets.map { pacing.open + compression * $0 }
        let dayStartList = dayOffsets.map { pacing.open + compression * $0 }
        dayStarts = dayStartList
        starts = startList

        landings = (0..<n).map {
            Landing(time: startList[$0] + times[$0], mass: replay.blocks[$0].win.size.massTier,
                    column: replay.blocks[$0].column, blockIndex: $0)
        }.sorted { $0.time < $1.time }
        landingTimes = landings.map(\.time)

        // **The camera is a taut string through the space its two promises
        // leave it.**
        //
        // It used to take one key per landing, `(landing - lead, rise)`. In a
        // month landings are 50 to 140ms apart, so a two-row step between two
        // keys was squeezed into 50ms: the sample month moved 186pt in about
        // 55ms at t=3.62, and the film showed the tower drop in one frame.
        //
        // Two alternatives were measured and failed:
        // - A fixed 0.5s grid of look-ahead keys was still 21pt per 60Hz frame
        //   in a 150-win month. Rising 0.75s ahead, it also carried blocks
        //   that had not started falling down into the frame: 25 appeared up
        //   to 92pt on screen instead of falling in from above.
        // - The laziest climb at the lowest workable speed kept both promises
        //   but moved in stop-start stairs, 15pt per frame at each step.
        //
        // The promises are a corridor.
        // - FLOOR: lead seconds before each landing, the camera is at least
        //   that block's rise, or the block lands above the follow line.
        // - CEILING: at each fall's first instant, the camera is at most that
        //   block's rise plus the drop clearance, or the block starts on
        //   screen. It is also 0 until `cameraEarliestRise` before the first
        //   landing that needs any rise.
        //
        // The keys are the corners of the SHORTEST path through that corridor
        // (string pulling). It is as straight as the corridor allows, so the
        // camera climbs at the tower's own rate and bends only where a floor
        // or a ceiling makes it. `MonotoneCurve` rounds the bends. The corridor
        // is narrowed by `cameraCorridorMargin` on both sides (floors never
        // past `finalRise`). Between SPARSE corners that is not enough: a
        // review sweep of 4000 inputs found the rounding bowing up to 56pt
        // out of the corridor. So after the curve is built, every floor or
        // ceiling it misses gets the straight path's own value as an extra
        // key, and the curve is rebuilt, until nothing is missed.
        finalRise = rises.max() ?? 0
        let lead = pacing.cameraLead
        let margin = pacing.cameraCorridorMargin
        // Constraint points: y is a floor (the path at x is at least y) or
        // a ceiling (at most y).
        var floors: [(x: Double, y: Double)] = []
        var ceilings: [(x: Double, y: Double)] = []
        for k in 0..<n where rises[k] > 0 {
            floors.append((max(0, startList[k] + times[k] - lead), min(Double(rises[k]) + margin, Double(finalRise))))
        }
        for k in 0..<n {
            ceilings.append((startList[k], Double(rises[k] + GridConstants.dropClearance) - pacing.cameraCeilingSlack - margin))
        }
        if let firstNeed = (0..<n).filter({ rises[$0] > 0 }).map({ startList[$0] + times[$0] }).min() {
            ceilings.append((max(0, firstNeed - pacing.cameraEarliestRise), 0))
        }
        var keys: [(x: Double, y: Double)] = [(0, 0)]
        if finalRise > 0, let end = floors.map(\.x).max() {
            let events = (floors.map { (x: $0.x, y: $0.y, isFloor: true) }
                          + ceilings.map { (x: $0.x, y: $0.y, isFloor: false) }
                          + [(x: end, y: Double(finalRise), isFloor: true)])
                .filter { $0.x > 1e-9 }
                .sorted { $0.x < $1.x }
            var apex = (x: 0.0, y: 0.0)
            var i = 0
            while i < events.count {
                // Sweep forward from the apex, narrowing the slopes a straight
                // line from it may take, until the window closes.
                var low = -Double.infinity, high = Double.infinity
                var lowAt = -1, highAt = -1
                var bent = false
                var j = i
                while j < events.count {
                    let e = events[j]
                    let dx = e.x - apex.x
                    if dx <= 1e-9 {
                        // Same instant as the apex: a floor raises it.
                        if e.isFloor, e.y > apex.y { apex.y = e.y }
                        j += 1
                        continue
                    }
                    let slope = (e.y - apex.y) / dx
                    if e.isFloor {
                        if slope > high {
                            // Pull tight around the ceiling that set `high`.
                            apex = (events[highAt].x, events[highAt].y)
                            keys.append(apex); i = highAt + 1; bent = true; break
                        }
                        if slope > low { low = slope; lowAt = j }
                    } else {
                        if slope < low {
                            apex = (events[lowAt].x, events[lowAt].y)
                            keys.append(apex); i = lowAt + 1; bent = true; break
                        }
                        if slope < high { high = slope; highAt = j }
                    }
                    j += 1
                }
                if !bent {
                    // Reached the end with the window still open. If a floor
                    // needs a steeper line than the one to the end, that floor
                    // is a corner: bend there and carry on sweeping, so the
                    // floors after it are still seen. (Appending it and
                    // jumping to the end skipped them: 120 hard wins over 30
                    // days missed a floor by 63pt.)
                    let toEnd = (Double(finalRise) - apex.y) / max(end - apex.x, 1e-9)
                    if lowAt >= 0, low > toEnd + 1e-12 {
                        apex = (events[lowAt].x, events[lowAt].y)
                        keys.append(apex)
                        i = lowAt + 1
                        continue
                    }
                    break
                }
            }
            // Exactly `finalRise`: the reveal starts from it.
            keys.append((end, Double(finalRise)))
        }
        // Where a ceiling sits below an earlier floor no path honours both,
        // and the apex steps down to the ceiling; `MonotoneCurve` holds the
        // camera level there rather than moving it down, so the floor wins,
        // as it did before.
        var curve = MonotoneCurve(points: keys)
        // Repair: the straight path is inside the corridor by construction;
        // the rounded curve through its corners may not be. Pin the curve to
        // the straight path wherever it strays, and rebuild.
        keys.sort { $0.x < $1.x }
        func straight(at x: Double) -> Double {
            guard let first = keys.first, let last = keys.last else { return 0 }
            if x <= first.x { return first.y }
            if x >= last.x { return last.y }
            var lo = 0, hi = keys.count - 1
            while hi - lo > 1 { let mid = (lo + hi) / 2; if keys[mid].x <= x { lo = mid } else { hi = mid } }
            let a = keys[lo], b = keys[hi]
            return b.x - a.x < 1e-9 ? b.y : a.y + (b.y - a.y) * (x - a.x) / (b.x - a.x)
        }
        for _ in 0..<pacing.cameraRepairPasses {
            var extra: [(x: Double, y: Double)] = []
            for f in floors where curve.value(at: f.x) < f.y - margin { extra.append((f.x, straight(at: f.x))) }
            for c in ceilings where curve.value(at: c.x) > c.y + margin { extra.append((c.x, straight(at: c.x))) }
            if extra.isEmpty { break }
            keys = (keys + extra).sorted { $0.x < $1.x }
            curve = MonotoneCurve(points: keys)
        }
        #if DEBUG
        // Out of passes with the curve still outside the corridor: a block
        // could be clipped as it lands or seen before it falls. Logged, not
        // asserted: a crash on a debug build installed from Xcode is worse
        // than one misdrawn camera, and no tested input needs more than 4 of
        // the 12 passes. A release build draws the best curve it has.
        let left = floors.contains { curve.value(at: $0.x) < $0.y - margin }
            || ceilings.contains { curve.value(at: $0.x) > $0.y + margin }
        if left {
            Self.logger.error("camera repair used all \(pacing.cameraRepairPasses, privacy: .public) passes and the curve still leaves its corridor (\(replay.count, privacy: .public) wins, \(replay.period.id, privacy: .public))")
        }
        #endif
        cameraCurve = curve

        let lastLanding = landings.last?.time ?? pacing.open
        // A trailing empty day (a quiet weekend, a month ending quietly) has
        // no landing to anchor on, so the build cannot end before that day
        // has had its own full moment on screen.
        var candidateRevealStart = lastLanding + pacing.holdAfterLast
        if replay.countsByDay.last == 0, let lastDayStart = dayStartList.last {
            candidateRevealStart = max(candidateRevealStart, lastDayStart + pacing.emptyHold * compression)
        }
        revealStart = candidateRevealStart
        // Even when the finished tower fits at scale 1, the camera may have
        // had to rise during the build to keep the newest block in frame,
        // and that rise still has to ease back to 0, or it jumps.
        revealDuration = revealLength
        danceStart = revealStart + revealDuration
        danceDelays = delays
        let danceEnd = danceStart + (danceDelays.max() ?? 0) + pacing.danceWave
        closeStart = danceEnd
        duration = closeStart + Self.closeLength(pacing)
    }

    /// From the close's start to the end: the controls arriving, and one
    /// stagger more, so under Reduce Motion (where the title starts with the
    /// close) the range has arrived too.
    private static func closeLength(_ pacing: Pacing) -> Double {
        pacing.closeStagger + pacing.arrive
    }

    // MARK: - Evaluating

    private static func clamp01(_ v: Double) -> Double { min(max(v, 0), 1) }
    private static func smooth(_ p: Double) -> Double { let q = clamp01(p); return q * q * (3 - 2 * q) }

    func blockFrame(_ index: Int) -> CGRect {
        let b = replay.blocks[index]
        return GridConstants.blockFrame(column: b.column, row: b.row, columnSpan: b.columnSpan,
                                        rowSpan: b.rowSpan, cellSize: metrics.cell)
    }

    func camera(at t: Double) -> Camera {
        if reduceMotion { return Camera(rise: 0, scale: fitScale) }
        if t < revealStart { return Camera(rise: CGFloat(cameraCurve.value(at: t)), scale: 1) }
        guard revealDuration > 0 else { return Camera(rise: 0, scale: 1) }
        let e = CGFloat(Self.smooth((t - revealStart) / revealDuration))
        // **The TOP is interpolated, and the rise solved from it.**
        //
        // This lerped rise and scale separately. The screen top is their
        // product, `baseY - s * (H - rise)`, which is not monotone: sampled at
        // 402x874 a 60-win week's top climbed to -254pt and a 150-win month's
        // to -1171pt before coming back, so the reveal read as the camera
        // travelling down the tower and then pulling out, over the header and
        // the Dynamic Island.
        //
        // Now the top moves in a straight line from where the build left it
        // to where the fitted tower ends, so it never leaves that span, and
        // the base comes up from below into place.
        //
        // Scale is geometric, equal ratios per unit of progress, which is
        // what reads as an even zoom, and exactly 1 throughout when the tower
        // already fits.
        let h = towerHeight
        let scale = pow(fitScale, e)
        let startTop = metrics.baseY - (h - finalRise)
        // `fitTopY` whenever the tower had to shrink. When it fits at scale 1
        // it is the tower's own top, so the rise eases out to 0 on the curve
        // rather than clamping to 0 part way through.
        let endTop = metrics.baseY - fitScale * h
        let top = startTop + (endTop - startTop) * e
        let rise = max(0, h - (metrics.baseY - top) / scale)
        return Camera(rise: rise, scale: scale)
    }

    func pose(_ index: Int, at t: Double) -> BlockPose {
        var p = BlockPose()
        if reduceMotion {
            let o = Self.clamp01((t - starts[index]) / pacing.closeFade)
            p.visible = o > 0
            p.opacity = o
            return p
        }
        let start = starts[index]
        guard t >= start else { return p }
        p.visible = true
        let T = fallTimes[index]
        let since = t - start
        if since < T {
            // Constant acceleration, arriving at full speed. No ease out.
            let q = since / T
            p.fallOffset = -fallDistances[index] * CGFloat(1 - q * q)
        } else {
            let dt = since - T
            if dt < pacing.squashTime {
                let mass = CGFloat(replay.blocks[index].win.size.massTier)
                let env = CGFloat(exp(-dt / pacing.squashDecay) * cos(2 * .pi * dt / pacing.squashPeriod))
                // The tower's own impact deformation, so a replay landing
                // squashes as deep as a drop on the Wins tab.
                p.scaleY = 1 - GridConstants.squashScaleY(mass: mass) * env
                p.scaleX = 1 + GridConstants.squashScaleX(mass: mass) * env
            }
        }
        let wave = (t - danceStart - danceDelays[index]) / pacing.danceWave
        if wave > 0, wave < 1 {
            p.lift = GridConstants.danceLift * CGFloat(sin(.pi * wave))
            p.tilt = GridConstants.danceTilt * sin(2 * .pi * wave) * (1 - wave)
                * (replay.blocks[index].column < 2 ? -1 : 1)
        }
        return p
    }

    func screenTop(ofBlock index: Int, at t: Double) -> CGFloat {
        let c = camera(at: t)
        let f = blockFrame(index)
        let pose = pose(index, at: t)
        return metrics.baseY - c.scale * (f.minY + f.height - c.rise) + c.scale * (pose.fallOffset + pose.lift)
    }

    /// When a block first appears: the start of its fall, or of its fade
    /// under Reduce Motion. What the live replay waits on photographs for.
    func appearTime(ofBlock index: Int) -> Double { starts[index] }

    /// When a day starts in the build, compressed as the build is.
    func dayStart(_ day: Int) -> Double { dayStarts[day] }

    // MARK: The count, the title and the close

    /// How many blocks have landed by `t`: the count during the build.
    func count(at t: Double) -> Int {
        Self.upperBound(landingTimes, t)
    }

    /// The count and its roll. A landing changes it at once, and the change
    /// is drawn over `rollTime`, cut short to the gap before the NEXT change,
    /// so a roll has always finished when the next one starts: in a busy
    /// month, landings 50ms apart roll quickly rather than jumping mid-slide.
    /// Landings at one instant (a day under Reduce Motion) are one change.
    func countRoll(at t: Double) -> CountRoll {
        let n = count(at: t)
        guard n > 0 else { return CountRoll(count: 0, previous: 0, progress: 1) }
        let changedAt = landingTimes[n - 1]
        let before = Self.lowerBound(landingTimes, changedAt)
        let nextChange = n < landingTimes.count ? landingTimes[n] : Double.infinity
        let length = min(pacing.rollTime, nextChange - changedAt)
        let progress = length > 1e-9 ? Self.clamp01((t - changedAt) / length) : 1
        return CountRoll(count: n, previous: before, progress: progress)
    }

    /// The digit positions of a roll, right-aligned, most significant first.
    /// 9 to 10 is `[1 arriving from nothing, 0 replacing 9]`; 12 to 13 moves
    /// only the last position.
    static func digitSlots(_ roll: CountRoll) -> [DigitSlot] {
        let new = Array(String(roll.count))
        let old = roll.progress < 1 ? Array(String(roll.previous)) : new
        let width = max(new.count, old.count)
        return (0..<width).map { i in
            let n = i - (width - new.count)
            let o = i - (width - old.count)
            return DigitSlot(new: n >= 0 ? new[n] : nil, old: o >= 0 ? old[o] : nil)
        }
    }

    /// How far through its travel a rolling digit is, eased out: the leaving
    /// digit is this many line heights above its place, the arriving one
    /// this many short of arriving from a line below.
    func rollEase(_ progress: Double) -> Double {
        let q = 1 - Self.clamp01(progress)
        return 1 - q * q
    }

    /// How open a position gaining a digit is (9 to 10): fully by the middle
    /// of the roll, while its digit is still in the lower half of its travel.
    static func rollOpening(_ e: Double) -> Double { clamp01(e / 0.5) }

    /// The count and its word at the open. Faded in, so the first frame is
    /// the ground alone.
    func countOpacity(at t: Double) -> Double { Self.smooth(t / pacing.headerFade) }

    /// The date under the count (0), and a Settings preview's "Sample" after
    /// it (1), arriving as the reveal starts.
    func titleArrival(_ item: Int, at t: Double) -> Arrival {
        arrival(from: revealStart + Double(item) * pacing.closeStagger, at: t)
    }

    /// The close: the controls arriving under the tower.
    func closeArrival(at t: Double) -> Arrival {
        arrival(from: closeStart, at: t)
    }

    /// Up `arriveSlide` with opacity over `arrive`, on an ease-out cubic: most
    /// of the travel early, a long soft settle. Opacity only under Reduce
    /// Motion.
    private func arrival(from start: Double, at t: Double) -> Arrival {
        let p = Self.clamp01((t - start) / pacing.arrive)
        let e = 1 - pow(1 - p, 3)
        return Arrival(opacity: e, offset: reduceMotion ? 0 : pacing.arriveSlide * CGFloat(1 - e))
    }

    /// The number of values `<= x` in a sorted array.
    private static func upperBound(_ values: [Double], _ x: Double) -> Int {
        var lo = 0, hi = values.count
        while lo < hi { let mid = (lo + hi) / 2; if values[mid] <= x { lo = mid + 1 } else { hi = mid } }
        return lo
    }

    /// The number of values `< x` in a sorted array.
    private static func lowerBound(_ values: [Double], _ x: Double) -> Int {
        var lo = 0, hi = values.count
        while lo < hi { let mid = (lo + hi) / 2; if values[mid] < x { lo = mid + 1 } else { hi = mid } }
        return lo
    }

    func phase(at t: Double) -> Phase {
        if t < pacing.open { return .opening }
        if t < revealStart { return .building }
        if t < danceStart { return .revealing }
        if t < closeStart { return .dancing }
        return .closed
    }
}

// MARK: - Where a block is drawn

extension ReplayScript {
    /// A block's rect in FRAME coordinates at `t`: where `ReplayFrame` draws
    /// it, through the tower's own offset, the camera's scale about the base
    /// and its rise. The dance's tilt and the landing squash are left out;
    /// both are over by the close, which is the only time anything asks.
    func screenRect(ofBlock index: Int, at t: Double) -> CGRect {
        let c = camera(at: t)
        let f = blockFrame(index)
        let pose = pose(index, at: t)
        let x = metrics.frame.width / 2 + (f.minX - gridWidth / 2) * c.scale
        let y = metrics.baseY - c.scale * (f.minY + f.height - c.rise) + c.scale * (pose.fallOffset + pose.lift)
        return CGRect(x: x, y: y, width: f.width * c.scale, height: f.height * c.scale)
    }

    /// The block under a tap at `point`, in frame coordinates.
    ///
    /// A finished month rests at a scale near 0.11, where a block is drawn
    /// about 9pt across, far under a finger. So every visible block answers
    /// to at least a 44pt square about its centre, and where those overlap
    /// the nearest centre wins. A tap inside a block's drawn rect is always
    /// that block, however big its neighbour's target is.
    func block(at point: CGPoint, t: Double, minimumTarget: CGFloat = 44) -> Int? {
        var best: (index: Int, distance: CGFloat)?
        for i in replay.blocks.indices where pose(i, at: t).visible {
            let r = screenRect(ofBlock: i, at: t)
            if r.contains(point) { return i }
            let target = r.insetBy(dx: min(0, (r.width - minimumTarget) / 2),
                                   dy: min(0, (r.height - minimumTarget) / 2))
            guard target.contains(point) else { continue }
            let d = hypot(point.x - r.midX, point.y - r.midY)
            if best == nil || d < best!.distance { best = (i, d) }
        }
        return best?.index
    }
}
