import CoreGraphics
import Foundation

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

    struct Metrics: Equatable {
        var frame: CGSize
        var cell: CGFloat
        /// Screen y of the tower's base.
        var baseY: CGFloat
        /// While following, the top of the tower is held at this screen y.
        var followY: CGFloat
        /// After the reveal, the finished tower's top may come no higher.
        var fitTopY: CGFloat

        /// Same cell as the Wins tab at this width. The three lines were
        /// set by photographing frozen frames at 402x874:
        /// - `followY` 0.24 holds the tower's top a clear gap under the
        ///   running label (label ink ends near 0.19).
        /// - `baseY` 0.75 (was 0.72) and `fitTopY` 0.17 (was 0.22): the
        ///   finished week sat at 0.43 scale with an empty band above it and
        ///   below the close; now 0.50, top just under the header, and the
        ///   close still hangs 40pt under the base with room for controls.
        static func standard(frame: CGSize) -> Metrics {
            let cell = GridConstants.cellSize(forGridWidth: frame.width - GridConstants.horizontalPadding * 2)
            return Metrics(frame: frame, cell: cell,
                           baseY: (frame.height * 0.75).rounded(),
                           followY: (frame.height * 0.24).rounded(),
                           fitTopY: (frame.height * 0.17).rounded())
        }
    }

    struct Pacing {
        var buildBudget: Double
        var buildCap: Double
        var air: Double
        var emptyHold: Double
        var reveal: Double
        var reduceMotionSpan: Double
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
        let labelFade = 0.22
        let labelSlide: CGFloat = 8
        let danceWave = 0.6
        let closeFade = 0.3
        let closeStagger = 0.08
        let squashTime = 0.35
        /// How long the header takes to fade in.
        let headerFade = 0.5
        /// The squash-and-stretch settle: an exponentially decaying cosine.
        let squashDecay = 0.08
        let squashPeriod = 0.22

        static func of(_ kind: ReplayKind) -> Pacing {
            switch kind {
            case .week: Pacing(buildBudget: 10, buildCap: 12.5, air: 0.35, emptyHold: 0.45, reveal: 1.0, reduceMotionSpan: 4)
            case .month: Pacing(buildBudget: 18, buildCap: 22, air: 0.12, emptyHold: 0.2, reveal: 1.4, reduceMotionSpan: 6)
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

    struct LabelState: Equatable {
        var current: Int?
        var currentOpacity: Double
        var currentSlide: CGFloat
        var previous: Int?
        var previousOpacity: Double
        var previousSlide: CGFloat
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
            cameraCurve = MonotoneCurve(points: [(0, 0)])
            finalRise = 0
            revealStart = pacing.open + pacing.reduceMotionSpan + pacing.closeFade
            revealDuration = 0
            danceStart = revealStart
            danceDelays = Array(repeating: 0, count: n)
            closeStart = revealStart
            duration = closeStart + pacing.closeFade + 2 * pacing.closeStagger
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

        // Drop start times, walking the days.
        var t = pacing.open
        var dayStartList: [Double] = []
        var startList = Array(repeating: 0.0, count: n)
        var i = 0
        for count in replay.countsByDay {
            dayStartList.append(t)
            if count == 0 { t += pacing.emptyHold; continue }
            if i > 0 { t += pacing.air }
            for _ in 0..<count { startList[i] = t; t += gap; i += 1 }
        }
        dayStarts = dayStartList
        starts = startList

        // Camera targets and fall distances, block by block in drop order.
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

        landings = (0..<n).map {
            Landing(time: startList[$0] + times[$0], mass: replay.blocks[$0].win.size.massTier,
                    column: replay.blocks[$0].column, blockIndex: $0)
        }.sorted { $0.time < $1.time }

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
        cameraCurve = curve

        let lastLanding = landings.last?.time ?? pacing.open
        // A trailing empty day (a quiet weekend, a month ending quietly) has
        // no landing to anchor on, so the build cannot end before that day
        // has had its own full moment on screen.
        var candidateRevealStart = lastLanding + pacing.holdAfterLast
        if replay.countsByDay.last == 0, let lastDayStart = dayStartList.last {
            candidateRevealStart = max(candidateRevealStart, lastDayStart + pacing.emptyHold)
        }
        revealStart = candidateRevealStart
        // Even when the finished tower fits at scale 1, the camera may have
        // had to rise during the build to keep the newest block in frame,
        // and that rise still has to ease back to 0, or it jumps.
        revealDuration = (fitScale < 1 || finalRise > 0) ? pacing.reveal : 0
        danceStart = revealStart + revealDuration

        let rowDelay = GridConstants.danceRowDelay
        let travel = Double(replay.rows) * rowDelay
        let squeeze = travel > GridConstants.danceTravelCap ? GridConstants.danceTravelCap / travel : 1
        danceDelays = replay.blocks.map { Double($0.row) * rowDelay * squeeze }
        let danceEnd = danceStart + (danceDelays.max() ?? 0) + pacing.danceWave
        closeStart = danceEnd
        duration = closeStart + pacing.closeFade + 2 * pacing.closeStagger
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
                p.scaleY = 1 - 0.025 * mass * env
                p.scaleX = 1 + 0.015 * mass * env
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

    func label(at t: Double) -> LabelState {
        // In reduce motion there is no reveal to leave at, so the label
        // instead leaves when the close arrives; otherwise it would sit at
        // full opacity beside the count forever.
        let leavingStart = reduceMotion ? closeStart : revealStart
        let leaving = Self.clamp01((t - leavingStart) / pacing.labelFade)
        guard let k = dayStarts.lastIndex(where: { $0 <= t }) else {
            return LabelState(current: nil, currentOpacity: 0, currentSlide: 0, previous: nil, previousOpacity: 0, previousSlide: 0)
        }
        let p = Self.smooth((t - dayStarts[k]) / pacing.labelFade)
        let slide = pacing.labelSlide
        return LabelState(current: k,
                          currentOpacity: p * (1 - leaving),
                          currentSlide: slide * CGFloat(1 - p),
                          previous: k > 0 && p < 1 ? k - 1 : nil,
                          previousOpacity: (1 - p) * (1 - leaving),
                          previousSlide: -slide * CGFloat(p))
    }

    func headerOpacity(at t: Double) -> Double { Self.smooth(t / pacing.headerFade) }

    func closeOpacity(_ item: Int, at t: Double) -> Double {
        let start = closeStart + Double(item) * pacing.closeStagger
        let p = Self.clamp01((t - start) / pacing.closeFade)
        return 1 - (1 - p) * (1 - p) // ease out
    }

    func phase(at t: Double) -> Phase {
        if t < pacing.open { return .opening }
        if t < revealStart { return .building }
        if t < danceStart { return .revealing }
        if t < closeStart { return .dancing }
        return .closed
    }
}
