import CoreGraphics
import Foundation
import Testing
@testable import Strata

/// **The ground under the replay's tower, and when it leaves.**
///
/// The owner, 2026-10-01: "i dont think i like the lattice when it zooms out."
/// The surface exists so a tower reads as built into something while blocks are
/// still landing in it. Once the camera pulls back, the only part of it left in
/// sight is `TowerLattice.rowsAbove` hanging over a finished tower, in open air,
/// behind the count and the dates. See `ReplayFrame.surface`.
@Suite("Replay surface")
struct ReplaySurfaceTests {

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()
    private let frame = CGSize(width: 402, height: 874)

    private func script(_ kind: ReplayKind, wins n: Int, reduceMotion: Bool = false) -> ReplayScript {
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 9, day: 9))!
        let period = kind == .week ? ReplayPeriod.week(containing: anchor, calendar: calendar)
                                   : ReplayPeriod.month(containing: anchor, calendar: calendar)
        let sizes: [BlockSize] = [.small, .medium, .small, .hard, .small]
        let wins = (0..<n).map { i -> ReplayWin in
            let day = i % period.days.count
            return ReplayWin(id: UUID(), dateString: period.days[day],
                             completedAt: period.date(ofDay: day).addingTimeInterval(Double(3600 + i)),
                             title: "Win \(i)", category: .health, size: sizes[i % sizes.count],
                             photo: nil, crop: .zero)
        }
        return ReplayScript(replay: Replay(period: period, wins: wins),
                            metrics: .standard(frame: frame), reduceMotion: reduceMotion)
    }

    private func opacity(_ s: ReplayScript, at t: Double) -> Double {
        ReplayFrame.surfaceOpacity(fitScale: s.fitScale, revealStart: s.revealStart,
                                   revealDuration: s.revealDuration, t: t)
    }

    /// The whole build keeps its ground. This is the part that is not being
    /// changed: every frame in which a block is falling is a frame drawn on the
    /// same surface the Wins tab draws.
    @Test("the ground is at full strength for every frame of the build")
    func buildKeepsIt() {
        for s in [script(.week, wins: 22), script(.month, wins: 108)] {
            #expect(s.fitScale < 1, "this script has to zoom out or it tests nothing")
            var t = 0.0
            while t < s.revealStart {
                #expect(opacity(s, at: t) == 1,
                        "the ground went at \(t)s, before the reveal at \(s.revealStart)s")
                t += 0.05
            }
        }
    }

    /// And it is gone before the camera settles, which is the defect: 160pt of
    /// empty cells over a finished week, with the header printed across them.
    @Test("the ground is gone before the tower comes to rest")
    func restHasNone() {
        for s in [script(.week, wins: 22), script(.month, wins: 108)] {
            let settled = s.revealStart + s.revealDuration
            #expect(opacity(s, at: settled) == 0)
            #expect(opacity(s, at: s.duration) == 0)
            // Well before, not on the last frame of the zoom.
            #expect(opacity(s, at: s.revealStart + s.revealDuration * 0.8) == 0)
        }
    }

    /// A dissolve, not a cut: a saved video is read frame by frame, and one
    /// frame where a surface disappears is the thing that reads as a glitch.
    @Test("it dissolves, never steps")
    func dissolves() {
        for s in [script(.week, wins: 22), script(.month, wins: 108)] {
            var last = 1.0
            var biggestStep = 0.0
            var t = s.revealStart
            while t <= s.revealStart + s.revealDuration {
                let v = opacity(s, at: t)
                #expect(v <= last + 1e-9, "the ground came back at \(t)s")
                biggestStep = max(biggestStep, last - v)
                last = v
                t += 1.0 / 60
            }
            // One frame at 60fps may not carry more than a sixth of it.
            #expect(biggestStep < 1.0 / 6, "a \(biggestStep) step in one frame is a cut")
            #expect(s.revealDuration * ReplayFrame.surfaceStrike >= 0.5,
                    "the strike is \(s.revealDuration * ReplayFrame.surfaceStrike)s, short enough to read as a cut")
        }
    }

    /// A tower that fits never zooms out, so there is never a moment where the
    /// overhang is hanging over anything: it is the Wins tab's own case and it
    /// keeps the ground the whole way, including after the dance.
    @Test("a tower that never zooms out never loses its ground")
    func fittedKeepsIt() {
        let s = script(.week, wins: 3)
        #expect(s.fitScale == 1, "a 3-win week should fit; it rests at \(s.fitScale)")
        for t in stride(from: 0.0, through: s.duration, by: 0.1) {
            #expect(opacity(s, at: t) == 1, "the ground went at \(t)s on a tower that never zoomed")
        }
    }

    /// All-or-nothing by design: with Reduce Motion the camera sits at
    /// `fitScale` from the first frame, so there is no window to fade across.
    @Test("Reduce Motion gets the resting answer immediately")
    func reduceMotion() {
        let zoomed = script(.month, wins: 108, reduceMotion: true)
        #expect(zoomed.fitScale < 1)
        #expect(ReplayFrame.surfaceOpacity(fitScale: zoomed.fitScale, revealStart: zoomed.revealStart,
                                           revealDuration: zoomed.revealDuration, t: 0) == 1,
                "the time-only rule still ramps; the property is what short-circuits it")
        let fitted = script(.week, wins: 3, reduceMotion: true)
        #expect(fitted.fitScale == 1)
    }

    /// No tower can come to rest part way through the fade, which is the one
    /// thing a band in the camera's scale could not promise: a lattice frozen
    /// at 40% for good is a rendering fault, not a surface.
    @Test("every tower rests at exactly 0 or exactly 1")
    func noHalfFadedRest() {
        for n in [1, 2, 3, 5, 8, 13, 22, 40, 60] {
            let s = script(.week, wins: n)
            let v = opacity(s, at: s.duration)
            #expect(v == 0 || v == 1, "\(n) wins rests at \(v), fitScale \(s.fitScale)")
        }
        for n in [1, 20, 60, 108, 150] {
            let s = script(.month, wins: n)
            let v = opacity(s, at: s.duration)
            #expect(v == 0 || v == 1, "\(n) wins rests at \(v), fitScale \(s.fitScale)")
        }
    }
}
