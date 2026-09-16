import CoreGraphics
import Foundation
import Testing
@testable import Strata

@Suite("Replay script")
struct ReplayScriptTests {

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()
    private let frame = CGSize(width: 402, height: 874)
    /// Every frame the corridor must hold at: the phone the camera was tuned
    /// on, an iPhone SE, a Pro Max, and the Share card the video is drawn at.
    static let sweepFrames: [CGSize] = [CGSize(width: 402, height: 874), CGSize(width: 375, height: 667),
                                                CGSize(width: 440, height: 956), ReplayCard.size]

    private func replay(_ kind: ReplayKind, wins n: Int, emptyDays: Set<Int> = [],
                        anchor: DateComponents = DateComponents(year: 2026, month: 9, day: 9)) -> Replay {
        let anchor = calendar.date(from: anchor)!
        let period = kind == .week ? ReplayPeriod.week(containing: anchor, calendar: calendar)
                                   : ReplayPeriod.month(containing: anchor, calendar: calendar)
        let usable = period.days.indices.filter { !emptyDays.contains($0) }
        let sizes: [BlockSize] = [.small, .medium, .small, .hard, .small]
        let wins = (0..<n).map { i -> ReplayWin in
            let day = usable[i % usable.count]
            return ReplayWin(id: UUID(), dateString: period.days[day],
                             completedAt: period.date(ofDay: day).addingTimeInterval(Double(3600 + i)),
                             title: "Win \(i)", category: .health, size: sizes[i % sizes.count],
                             photo: nil, crop: .zero)
        }
        return Replay(period: period, wins: wins)
    }

    private func script(_ kind: ReplayKind, wins n: Int, reduceMotion: Bool = false) -> ReplayScript {
        ReplayScript(replay: replay(kind, wins: n), metrics: .standard(frame: frame), reduceMotion: reduceMotion)
    }

    @Test("monotone curve never overshoots and never goes down")
    func curve() {
        let c = MonotoneCurve(points: [(0, 0), (1, 0), (1.2, 10), (1.4, 10.5), (3, 80), (3.1, 80)])
        var last = -Double.infinity
        for i in 0...400 {
            let v = c.value(at: Double(i) / 100)
            #expect(v >= last - 1e-9)
            #expect(v <= 80 + 1e-9)
            last = v
        }
        #expect(c.value(at: 1.2) == 10)
        #expect(c.value(at: 99) == 80)
    }

    @Test("the whole replay never runs past its cap, for any count, wins spread over every day",
          arguments: [(ReplayKind.week, 1), (.week, 60), (.week, 150), (.week, 400),
                      (.month, 1), (.month, 150), (.month, 300), (.month, 600), (.month, 1000)])
    func durationNeverPassesTheCap(kind: ReplayKind, wins: Int) {
        let s = script(kind, wins: wins)
        #expect(s.duration <= s.pacing.totalCap + 1e-9, "\(kind) \(wins) wins ran \(s.duration)s against \(s.pacing.totalCap)")
    }

    @Test("a 31-day month of 1000 wins still ends on its cap")
    func longMonthNeverPassesTheCap() {
        // October 2026: 31 days, so a day more of air and holds than September.
        let r = replay(.month, wins: 1000, anchor: DateComponents(year: 2026, month: 10, day: 9))
        #expect(r.period.days.count == 31)
        let s = ReplayScript(replay: r, metrics: .standard(frame: frame), reduceMotion: false)
        #expect(s.duration <= s.pacing.totalCap + 1e-9, "ran \(s.duration)s against \(s.pacing.totalCap)")
        // Compressed, not cut: every block still lands before the reveal.
        #expect((s.landings.last?.time ?? 0) <= s.revealStart)
    }

    @Test("a replay that already fits is never padded to the cap")
    func shortReplayIsNotPadded() {
        #expect(script(.week, wins: 1).duration < 10)
        #expect(script(.month, wins: 1).duration < 10)
    }

    @Test("durations stay under the caps and are never padded", arguments: [1, 6, 30, 150, 400])
    func durations(n: Int) {
        let week = script(.week, wins: min(n, 150))
        let month = script(.month, wins: n)
        #expect(week.duration <= 18.0)
        #expect(month.duration <= 28.0)
        if n == 1 { #expect(week.duration < 10) }
    }

    @Test("every fall starts above the top of the frame")
    func fallsStartOffScreen() {
        for kind in [ReplayKind.week, .month] {
            let s = script(kind, wins: 120)
            for (i, landing) in s.landings.enumerated() where i % 7 == 0 {
                let index = landing.blockIndex
                // First visible instant.
                var t = 0.0
                while !s.pose(index, at: t).visible { t += 0.005 }
                let frameHeight = s.blockFrame(index).height
                #expect(s.screenTop(ofBlock: index, at: t) + frameHeight <= 0.5,
                        "block \(index) entered on screen at t=\(t)")
            }
        }
    }

    @Test("the camera never moves down during the build, and no block is clipped as it lands")
    func cameraFollows() {
        let s = script(.month, wins: 150)
        var last: CGFloat = 0
        var t = 0.0
        while t < s.revealStart {
            let c = s.camera(at: t)
            #expect(c.rise >= last - 0.001)
            #expect(c.scale == 1)
            last = c.rise
            t += 1.0 / 60
        }
        for landing in s.landings {
            #expect(s.screenTop(ofBlock: landing.blockIndex, at: landing.time) >= s.metrics.followY - 0.5)
        }
    }

    @Test("the camera never lurches during the build: no step over 12pt in a 60Hz frame, unless the tower itself grows faster",
          arguments: [(ReplayKind.month, 150, 0.0), (ReplayKind.week, 60, 0.5)])
    func cameraNeverLurches(kind: ReplayKind, wins: Int, tolerance: CGFloat) {
        // One keyframe per landing squeezed a two-row step into the 50ms
        // between two landings: the sample month moved 186pt in about 55ms at
        // t=3.62, and the film showed the tower dropping in one frame. Against
        // this test the old keys measured 82.6pt (month, 150) and 25.8pt
        // (week, 60).
        let s = script(kind, wins: wins)
        var worst: (step: CGFloat, t: Double) = (0, 0)
        var last = s.camera(at: 0).rise
        var t = 1.0 / 60
        while t < s.revealStart {
            let rise = s.camera(at: t).rise
            if rise - last > worst.step { worst = (rise - last, t) }
            last = rise
            t += 1.0 / 60
        }
        // The tower's own fastest growth: the most rise its landings demand
        // within any half second, per 60Hz frame. A camera that keeps every
        // block in frame cannot be slower than the tower for long.
        let followHeight = s.metrics.baseY - s.metrics.followY
        var top: CGFloat = 0
        var needs: [(time: Double, rise: CGFloat)] = []
        for k in s.replay.blocks.indices {
            let f = s.blockFrame(k)
            top = max(top, f.minY + f.height)
            if let landing = s.landings.first(where: { $0.blockIndex == k }) {
                needs.append((landing.time, max(0, top - followHeight)))
            }
        }
        var growth: CGFloat = 0
        for a in needs { for b in needs where b.time > a.time && b.time - a.time <= 0.5 {
            growth = max(growth, (b.rise - a.rise) / 0.5 / 60)
        } }
        // 12pt a frame is the limit. Where the tower itself grows faster
        // than that over half a second (the 150-win month: 12.4pt a frame),
        // the camera may exceed the tower's own rate by a fifth, for the ease
        // into and out of a climb, and no more.
        //
        // `tolerance` is stated per case rather than hidden in the limit: the
        // 60-win week's worst step is within half a point of 12 (the ease at
        // one corner), so it gets 0.5pt, and says so.
        let limit = max(12, growth * 1.2) + tolerance
        #expect(worst.step <= limit,
                "camera rose \(worst.step)pt in one frame at t=\(worst.t); the tower's own fastest growth is \(growth)pt a frame")
    }

    /// Wins of the given sizes on the given days, in that order.
    private func replay(_ kind: ReplayKind, sizes: [BlockSize], days: [Int]) -> Replay {
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 9, day: 9))!
        let period = kind == .week ? ReplayPeriod.week(containing: anchor, calendar: calendar)
                                   : ReplayPeriod.month(containing: anchor, calendar: calendar)
        let wins = sizes.indices.map { i -> ReplayWin in
            let day = days[i % days.count] % period.days.count
            return ReplayWin(id: UUID(), dateString: period.days[day],
                             completedAt: period.date(ofDay: day).addingTimeInterval(Double(3600 + i)),
                             title: "Win \(i)", category: .health, size: sizes[i], photo: nil, crop: .zero)
        }
        return Replay(period: period, wins: wins)
    }

    /// The two promises the build camera is built from, checked for every
    /// block: its fall starts above the frame, and it does not land above
    /// the follow line. Returns the worst of each so one expectation can
    /// carry the numbers.
    private func corridorWorst(_ s: ReplayScript) -> (onScreen: CGFloat, overFollow: CGFloat, block: Int) {
        var onScreen = -CGFloat.infinity, overFollow = -CGFloat.infinity, block = -1
        for landing in s.landings {
            let index = landing.blockIndex
            // First visible instant, by bisection: visible is false before
            // the fall starts and true from then on.
            var lo = 0.0, hi = landing.time
            for _ in 0..<40 { let mid = (lo + hi) / 2; if s.pose(index, at: mid).visible { hi = mid } else { lo = mid } }
            let bottom = s.screenTop(ofBlock: index, at: hi) + s.blockFrame(index).height
            if bottom > onScreen { onScreen = bottom; block = index }
            overFollow = max(overFollow, s.metrics.followY - s.screenTop(ofBlock: index, at: landing.time))
        }
        return (onScreen, overFollow, block)
    }

    @Test("every count from 1 to 400, both lengths and hard-heavy mixes, at every frame: falls start above the frame, nothing lands above the follow line",
          arguments: ReplayScriptTests.sweepFrames)
    func corridorHoldsForEveryCount(frame: CGSize) {
        // Every count at the frame the camera was tuned on; a subsample at
        // the others, always with 1, small counts, 150, 400 and past the
        // caps, and every hard-heavy mix.
        var counts = [1, 2, 3, 400]
        if frame == self.frame {
            counts += Array(stride(from: 4, to: 400, by: 7))
        } else {
            counts += [5, 8, 12, 20, 30, 45, 60, 90, 120, 150, 200, 250, 300, 350]
        }
        let metrics = ReplayScript.Metrics.standard(frame: frame)
        var cases: [(String, ReplayScript)] = []
        for n in counts {
            for kind in [ReplayKind.week, .month] {
                cases.append(("\(kind) \(n)", ReplayScript(replay: replay(kind, wins: n), metrics: metrics, reduceMotion: false)))
            }
        }
        // Hard-heavy: two-row blocks arriving fast are what make the tower
        // outgrow the camera and the corridor narrow.
        let hard = { (n: Int) in Array(repeating: BlockSize.hard, count: n) }
        let mixes: [(String, Replay)] = [
            ("month, 40 hard over 3 days", replay(.month, sizes: hard(40), days: [3, 4, 5])),
            ("week, 40 hard over 3 days", replay(.week, sizes: hard(40), days: [1, 2, 3])),
            ("month, 120 hard over 30 days", replay(.month, sizes: hard(120), days: Array(0..<30))),
            ("month, 150 hard in one day", replay(.month, sizes: hard(150), days: [12])),
            ("week, 60 alternating hard and small", replay(.week, sizes: (0..<60).map { $0 % 2 == 0 ? .hard : .small }, days: Array(0..<7))),
        ]
        // Past the old caps, where the build is compressed to fit the total.
        for n in [600, 1000] { cases.append(("month \(n)", ReplayScript(replay: replay(.month, wins: n), metrics: metrics, reduceMotion: false))) }
        for (name, r) in mixes {
            cases.append((name, ReplayScript(replay: r, metrics: metrics, reduceMotion: false)))
        }
        var failures: [String] = []
        var worstOnScreen: (CGFloat, String) = (-.infinity, ""), worstOver: (CGFloat, String) = (-.infinity, "")
        for (name, s) in cases {
            let w = corridorWorst(s)
            if w.onScreen > worstOnScreen.0 { worstOnScreen = (w.onScreen, name) }
            if w.overFollow > worstOver.0 { worstOver = (w.overFollow, name) }
            if w.onScreen > 0.5 { failures.append("\(name): block \(w.block) starts \(w.onScreen)pt on screen") }
            if w.overFollow > 0.5 { failures.append("\(name): a block lands \(w.overFollow)pt above the follow line") }
        }
        #expect(failures.isEmpty, "\(frame.width)x\(frame.height): \(failures.count) of \(cases.count) cases: \(failures.prefix(12)); worst start \(worstOnScreen), worst over follow \(worstOver)")
    }

    @Test("the camera starts rising no earlier than 0.75s before the first landing that needs it",
          arguments: [(ReplayKind.month, 150), (ReplayKind.week, 60), (ReplayKind.month, 30)])
    func cameraDoesNotRiseEarly(kind: ReplayKind, wins: Int) {
        let s = script(kind, wins: wins)
        let followHeight = s.metrics.baseY - s.metrics.followY
        var top: CGFloat = 0
        var firstNeed = Double.infinity
        for k in s.replay.blocks.indices {
            let f = s.blockFrame(k)
            top = max(top, f.minY + f.height)
            if top > followHeight, let landing = s.landings.first(where: { $0.blockIndex == k }) {
                firstNeed = min(firstNeed, landing.time)
            }
        }
        #expect(firstNeed.isFinite, "this case has to need the camera")
        var t = 0.0
        while t < s.revealStart, s.camera(at: t).rise <= 0.5 { t += 1.0 / 240 }
        #expect(t >= firstNeed - 0.75 - 1.0 / 240,
                "camera started rising at \(t), \(firstNeed - t)s before the first landing that needs it (\(firstNeed))")
    }

    @Test("every block is at rest before the reveal, and the whole tower is in frame after it")
    func revealFits() {
        let s = script(.month, wins: 150)
        for i in s.replay.blocks.indices {
            let p = s.pose(i, at: s.revealStart)
            #expect(p.visible && p.fallOffset == 0 && abs(p.scaleY - 1) < 0.01)
        }
        let end = s.camera(at: s.closeStart)
        #expect(end.rise == 0)
        #expect(s.metrics.baseY - end.scale * s.towerHeight >= s.metrics.fitTopY - 0.5)
        #expect(end.scale < 1)
    }

    @Test("the reveal pulls out: the top stays between the fit line and the base, the zoom only shrinks, nothing jumps",
          arguments: [(ReplayKind.month, 150), (ReplayKind.week, 60)])
    func revealNeverOvershoots(kind: ReplayKind, wins: Int) {
        let s = script(kind, wins: wins)
        let m = s.metrics
        let h = s.towerHeight
        func top(_ t: Double) -> CGFloat {
            let c = s.camera(at: t)
            return m.baseY - c.scale * (h - c.rise)
        }
        #expect(s.revealDuration > 0 && s.fitScale < 1, "this case has to exercise a real reveal")

        // Continuity with the last build frame.
        let lastBuild = s.revealStart - 1.0 / 60
        #expect(abs(top(s.revealStart) - top(lastBuild)) < 5)
        #expect(abs(s.camera(at: s.revealStart).rise - s.camera(at: lastBuild).rise) < 5)

        var lastScale = CGFloat.infinity
        var lastTop = top(s.revealStart)
        var worstTop = lastTop
        var t = s.revealStart
        let end = s.danceStart + 1.0 / 60
        while t <= end {
            let c = s.camera(at: t)
            let y = top(t)
            worstTop = min(worstTop, y)
            #expect(y <= m.baseY, "top at \(y) fell below the base at t=\(t)")
            #expect(c.scale <= lastScale + 1e-9, "zoom went back in at t=\(t)")
            #expect(abs(y - lastTop) <= 40, "top jumped from \(lastTop) to \(y) at t=\(t)")
            lastScale = c.scale
            lastTop = y
            t += 1.0 / 60
        }
        // One expectation for the bound, carrying the worst value, rather
        // than one failure per frame.
        #expect(worstTop >= m.fitTopY - 0.5, "the top reached \(worstTop), above fitTopY \(m.fitTopY)")
        // And it lands exactly where it was going.
        #expect(abs(top(s.danceStart) - (m.baseY - s.fitScale * h)) < 0.5)
        #expect(s.camera(at: s.danceStart).rise < 0.5)
    }

    @Test("a replay landing squashes by the tower's own tokens, scaled by mass", arguments: [BlockSize.small, .medium, .hard])
    func landingSquashMatchesTheTower(size: BlockSize) {
        let r = replay(.week, sizes: [size], days: [0])
        let s = ReplayScript(replay: r, metrics: .standard(frame: frame), reduceMotion: false)
        let landing = s.landings[0]
        let mass = CGFloat(size.massTier)
        // The instant of impact: the decaying cosine's envelope is exactly 1.
        let p = s.pose(landing.blockIndex, at: landing.time)
        #expect(abs((1 - p.scaleY) - GridConstants.squashScaleY(mass: mass)) < 1e-6,
                "squashed \(1 - p.scaleY), the tower squashes \(GridConstants.squashScaleY(mass: mass))")
        #expect(abs((p.scaleX - 1) - GridConstants.squashScaleX(mass: mass)) < 1e-6)
        // And it settles: nothing is left once the squash time has passed.
        let after = s.pose(landing.blockIndex, at: landing.time + s.pacing.squashTime + 0.01)
        #expect(after.scaleX == 1 && after.scaleY == 1)
    }

    @Test("a week that already fits never zooms")
    func smallWeekHolds() {
        let s = script(.week, wins: 4)
        #expect(s.fitScale == 1)
        #expect(s.camera(at: s.duration).scale == 1)
    }

    @Test("reduce motion: no falls, no camera, blocks fade in by day")
    func reduceMotion() {
        let s = script(.month, wins: 150, reduceMotion: true)
        for t in stride(from: 0.0, through: s.duration, by: 0.25) {
            #expect(s.camera(at: t).scale == s.fitScale)
            #expect(s.camera(at: t).rise == 0)
            for i in s.replay.blocks.indices where i % 11 == 0 {
                let p = s.pose(i, at: t)
                #expect(p.fallOffset == 0 && p.lift == 0 && p.tilt == 0)
            }
        }
        #expect(s.pose(0, at: s.closeStart).opacity == 1)
        // The count has counted every block, and the title has arrived, in
        // place: nothing slides under Reduce Motion.
        #expect(s.count(at: s.duration) == s.replay.count)
        #expect(s.titleArrival(1, at: s.duration).opacity == 1)
        for t in stride(from: s.revealStart, through: s.duration, by: 0.05) {
            #expect(s.titleArrival(0, at: t).offset == 0)
            #expect(s.closeArrival(at: t).offset == 0)
        }
    }

    @Test("the count is the number of blocks landed: 0 at the open, one more at each landing, all of them by the reveal")
    func countFollowsLandings() {
        let s = script(.week, wins: 14)
        #expect(s.count(at: 0) == 0)
        for (k, landing) in s.landings.enumerated() {
            // Landings at one instant count together.
            let atOnce = s.landings.filter { $0.time == landing.time }.count
            let before = s.landings.filter { $0.time < landing.time }.count
            #expect(s.count(at: landing.time - 1e-6) == before, "landing \(k)")
            #expect(s.count(at: landing.time) == before + atOnce, "landing \(k)")
        }
        #expect(s.count(at: s.revealStart) == 14)
        var last = 0
        for t in stride(from: 0.0, through: s.duration, by: 1.0 / 60) {
            let n = s.count(at: t)
            #expect(n >= last)
            last = n
        }
    }

    @Test("a digit roll takes rollTime, cut short to the gap after it, and is settled before the next landing")
    func rollTiming() {
        let s = script(.month, wins: 150)
        let times = Array(Set(s.landings.map(\.time))).sorted()
        for (k, time) in times.enumerated() {
            let gap = k + 1 < times.count ? times[k + 1] - time : .infinity
            let length = min(s.pacing.rollTime, gap)
            let start = s.countRoll(at: time)
            #expect(start.progress == 0 || length < 1e-9)
            #expect(start.previous == s.count(at: time - 1e-6))
            if length < gap {
                #expect(s.countRoll(at: time + length + 1e-9).progress == 1, "landing \(k) not settled after \(length)s")
            }
            if length > 1e-6 {
                let half = s.countRoll(at: time + length / 2)
                #expect(abs(half.progress - 0.5) < 1e-6)
            }
            if k + 1 < times.count {
                #expect(s.countRoll(at: times[k + 1] - 1e-9).progress > 0.999, "landing \(k)'s roll ran into the next")
            }
        }
        #expect(s.countRoll(at: 0) == ReplayScript.CountRoll(count: 0, previous: 0, progress: 1))
        // The digits hand over: never both above a third at once.
        for e in stride(from: 0.0, through: 1.0, by: 0.01) {
            let o = ReplayScript.rollOpacities(e)
            #expect(min(o.leaving, o.arriving) == 0, "at \(e) both digits show: \(o.leaving) \(o.arriving)")
            if o.arriving > 0 { #expect(ReplayScript.rollOpening(e) == 1, "a digit appeared in a slot still opening at \(e)") }
        }
        let start = ReplayScript.rollOpacities(0), end = ReplayScript.rollOpacities(1)
        #expect(start.leaving == 1 && start.arriving == 0 && end.leaving == 0 && end.arriving == 1)
        // The ease is monotone from 0 to 1.
        #expect(s.rollEase(0) == 0 && s.rollEase(1) == 1)
        #expect(s.rollEase(0.25) < s.rollEase(0.5) && s.rollEase(0.5) < s.rollEase(0.75))
    }

    @Test("only the digits that change roll")
    func digitSlots() {
        typealias Slot = ReplayScript.DigitSlot
        let nineToTen = ReplayScript.digitSlots(.init(count: 10, previous: 9, progress: 0.3))
        #expect(nineToTen == [Slot(new: "1", old: nil), Slot(new: "0", old: "9")])
        let twelve = ReplayScript.digitSlots(.init(count: 13, previous: 12, progress: 0.3))
        #expect(twelve == [Slot(new: "1", old: "1"), Slot(new: "3", old: "2")])
        #expect(!twelve[0].changes && twelve[1].changes)
        let settled = ReplayScript.digitSlots(.init(count: 13, previous: 12, progress: 1))
        #expect(settled.allSatisfy { !$0.changes })
        let jump = ReplayScript.digitSlots(.init(count: 104, previous: 99, progress: 0))
        #expect(jump == [Slot(new: "1", old: nil), Slot(new: "0", old: "9"), Slot(new: "4", old: "9")])
    }

    @Test("the date arrives with the reveal, a preview's Sample 80ms behind, eased out; the controls with the close")
    func titleAndClose() {
        let s = script(.week, wins: 12)
        #expect(s.titleArrival(0, at: s.revealStart - 0.01).opacity == 0)
        #expect(s.titleArrival(0, at: s.revealStart).offset == s.pacing.arriveSlide)
        let t = s.revealStart + 0.1
        #expect(s.titleArrival(0, at: t).opacity > s.titleArrival(1, at: t).opacity)
        // Eased out: more than halfway at a quarter of the time.
        #expect(s.titleArrival(0, at: s.revealStart + s.pacing.arrive / 4).opacity > 0.5)
        #expect(s.titleArrival(1, at: s.revealStart + s.pacing.closeStagger + s.pacing.arrive) == .init(opacity: 1, offset: 0))
        // The date is fully in before the controls start arriving.
        #expect(s.titleArrival(1, at: s.closeStart).opacity == 1)
        #expect(s.closeArrival(at: s.closeStart - 0.01).opacity == 0)
        #expect(s.closeArrival(at: s.duration) == .init(opacity: 1, offset: 0))
        var last = -1.0
        for t in stride(from: s.revealStart, through: s.duration, by: 1.0 / 60) {
            let o = s.titleArrival(0, at: t).opacity
            #expect(o >= last)
            last = o
        }
    }

    @Test("landings are in time order and one per block")
    func landingsList() {
        let s = script(.month, wins: 60)
        #expect(s.landings.count == 60)
        #expect(s.landings.map(\.time) == s.landings.map(\.time).sorted())
    }

    @Test("the fall accelerates: the second half covers three times the first")
    func gravityShape() {
        let s = script(.week, wins: 3)
        let i = s.landings[0].blockIndex
        var t0 = 0.0
        while !s.pose(i, at: t0).visible { t0 += 0.001 }
        let T = s.landings[0].time - t0
        let a = s.pose(i, at: t0).fallOffset
        let mid = s.pose(i, at: t0 + T / 2).fallOffset
        let firstHalf = mid - a
        let secondHalf = 0 - mid
        #expect(abs(secondHalf / firstHalf - 3) < 0.15)
    }

    @Test("a trailing empty day still gets its moment before the reveal")
    func trailingEmptyDayShows() {
        // A week with 8 small wins Monday to Thursday, Friday to Sunday empty.
        let r = replay(.week, wins: 8, emptyDays: [4, 5, 6])
        let s = ReplayScript(replay: r, metrics: .standard(frame: frame), reduceMotion: false)
        #expect(s.revealStart >= s.dayStart(6) + s.pacing.emptyHold - 1e-9,
                "the reveal at \(s.revealStart) cut Sunday, starting \(s.dayStart(6)), short")
        #expect(s.dayStart(6) > s.landings.last!.time)
    }

    @Test("a compressed build that ends on empty days: under the cap, the last day still shows, the corridor holds",
          arguments: [(ReplayKind.month, 600, 10), (.week, 400, 3)], ReplayScriptTests.sweepFrames)
    func capWithTrailingEmptyDays(shape: (ReplayKind, Int, Int), frame: CGSize) {
        let (kind, wins, busyDays) = shape
        // Every win in the first days; the rest of the period is empty, so
        // the build is compressed to fit the cap AND has to leave room for a
        // run of empty days after the last landing.
        let r = replay(kind, sizes: (0..<wins).map { [BlockSize.small, .medium, .small, .hard, .small][$0 % 5] },
                       days: Array(0..<busyDays))
        #expect(r.countsByDay.suffix(from: busyDays).allSatisfy { $0 == 0 })
        let s = ReplayScript(replay: r, metrics: .standard(frame: frame), reduceMotion: false)
        let lastDay = r.period.days.count - 1
        let size = "\(frame.width)x\(frame.height)"

        #expect(s.duration <= s.pacing.totalCap + 1e-9, "ran \(s.duration)s against \(s.pacing.totalCap)")
        #expect((s.landings.last?.time ?? .infinity) <= s.revealStart)

        #expect(s.dayStart(lastDay) < s.revealStart, "the last day never had its moment before the reveal at \(s.revealStart)s")

        let w = corridorWorst(s)
        #expect(w.onScreen <= 0.5, "\(size): block \(w.block) starts \(w.onScreen)pt on screen")
        #expect(w.overFollow <= 0.5, "\(size): a block lands \(w.overFollow)pt above the follow line")
    }

    @Test("laid out from the screen: controls on the bottom margin, the finished tower filling the space with even air, the video using the controls' room",
          arguments: [(CGSize(width: 375, height: 667), 20.0, 0.0), (CGSize(width: 402, height: 874), 62.0, 34.0),
                      (CGSize(width: 440, height: 956), 62.0, 34.0)])
    func layoutFromTheScreen(shape: (CGSize, Double, Double)) {
        let (size, topValue, bottomValue) = shape
        let top = CGFloat(topValue), bottom = CGFloat(bottomValue)
        let copy: CGFloat = 76
        let m = ReplayScript.Metrics.standard(frame: size, topInset: top, topCopy: copy, bottomInset: bottom, controlsHeight: 44)
        let air = GridConstants.gapWide
        // The controls sit on the bottom margin, not hung from the tower.
        #expect(abs(size.height - (m.closeTop + 44) - max(bottom + GridConstants.gapWide, GridConstants.gapSection)) < 0.001)
        // The same air above the finished tower as below it.
        #expect(abs(m.closeTop - m.baseY - air) < 0.001)
        #expect(abs(m.fitTopY - (top + copy) - air) < 0.001)
        #expect(m.followY >= m.fitTopY)
        // A month that has to shrink fills the space exactly.
        let s = ReplayScript(replay: replay(.month, wins: 150), metrics: m, reduceMotion: false)
        let end = s.camera(at: s.duration)
        #expect(abs(m.baseY - end.scale * s.towerHeight - m.fitTopY) < 0.5)
        // The video: no controls, so the base takes their room.
        let card = ReplayScript.Metrics.standard(frame: size, topInset: top, topCopy: copy, bottomInset: bottom)
        #expect(card.baseY > m.baseY)
    }

    @Test("the camera eases its rise back to 0 even when the finished tower already fits at scale 1")
    func riseErasesWithoutAZoomJump() {
        let r = replay(.week, wins: 20)
        let cell: CGFloat = 80
        let towerHeight = GridConstants.gridHeight(rows: r.rows, cellSize: cell)
        let baseY: CGFloat = 800
        // Built directly, not through .standard: followY set so the tower had
        // to make the camera rise during the build, fitTopY set so the same
        // tower fits at scale 1 once finished.
        let metrics = ReplayScript.Metrics(frame: frame, cell: cell, baseY: baseY,
                                           followY: baseY - (towerHeight - 50),
                                           fitTopY: baseY - (towerHeight + 50))
        let s = ReplayScript(replay: r, metrics: metrics, reduceMotion: false)
        #expect(s.fitScale == 1)

        var t = max(0, s.revealStart - 1.0)
        var last = s.camera(at: t).rise
        let end = s.revealStart + s.revealDuration + 1.0
        while t <= end {
            let rise = s.camera(at: t).rise
            #expect(abs(rise - last) <= 5, "camera rise jumped from \(last) to \(rise) at t=\(t)")
            last = rise
            t += 1.0 / 60
        }
    }
}
