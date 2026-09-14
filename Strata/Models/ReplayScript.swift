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

        var keys: [(x: Double, y: Double)] = [(0, 0)]
        for k in 0..<n { keys.append((max(0, startList[k] + times[k] - pacing.cameraLead), Double(rises[k]))) }
        cameraCurve = MonotoneCurve(points: keys)
        finalRise = rises.max() ?? 0

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
