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

    private func replay(_ kind: ReplayKind, wins n: Int, emptyDays: Set<Int> = []) -> Replay {
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 9, day: 9))!
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
        // The label has no reveal to leave at in reduce motion, so it must
        // still have left by the very end, beside the close.
        #expect(s.label(at: s.duration).currentOpacity == 0)
    }

    @Test("the running label follows the days and leaves at the reveal")
    func labels() {
        let r = replay(.week, wins: 14)
        let s = ReplayScript(replay: r, metrics: .standard(frame: frame), reduceMotion: false)
        #expect(s.label(at: 0).current == nil)
        let lastLanding = s.landings.last!.time
        #expect(s.label(at: lastLanding).current == 6)
        #expect(s.label(at: s.revealStart + 0.5).currentOpacity == 0)
    }

    @Test("the close arrives in order: count, sentence, controls")
    func closeOrder() {
        let s = script(.week, wins: 12)
        let t = s.closeStart + 0.1
        #expect(s.closeOpacity(0, at: t) > s.closeOpacity(1, at: t))
        #expect(s.closeOpacity(1, at: t) > s.closeOpacity(2, at: t))
        #expect(s.closeOpacity(2, at: s.duration) == 1)
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

    @Test("a trailing empty day still gets its moment, and a label never climbs back up once it starts leaving")
    func trailingEmptyDayShowsAndLabelsNeverReappear() {
        // A week with 8 small wins Monday to Thursday, Friday to Sunday empty.
        let r = replay(.week, wins: 8, emptyDays: [4, 5, 6])
        let s = ReplayScript(replay: r, metrics: .standard(frame: frame), reduceMotion: false)

        var sawSunday = false
        var t = 0.0
        while t < s.revealStart {
            if s.label(at: t).current == 6 { sawSunday = true; break }
            t += 1.0 / 60
        }
        #expect(sawSunday, "Sunday, the trailing empty day, never appeared before the reveal")

        var lastCurrent = Double.infinity
        var lastPrevious = Double.infinity
        var tt = s.revealStart
        while tt <= s.duration {
            let l = s.label(at: tt)
            #expect(l.currentOpacity <= lastCurrent + 1e-9)
            #expect(l.previousOpacity <= lastPrevious + 1e-9)
            lastCurrent = l.currentOpacity
            lastPrevious = l.previousOpacity
            tt += 1.0 / 60
        }
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
