import Testing
import Foundation
@testable import Strata

/// **The launch draws the logo and rubs it out, then the crest arrives**
/// (the owner, 2026-10-06).
@Suite("Launch drawing")
struct LaunchDrawTests {
    @Test("the strokes draw one after another, in a hand's order, and all are drawn before any is rubbed out")
    func order() {
        let early = LaunchDraw.frame(at: LaunchDraw.start + LaunchDraw.drawing * 0.3)
        #expect(early.drawn[0] > 0 && early.drawn[4] == 0, "the body before the smile")
        let held = LaunchDraw.frame(at: LaunchDraw.start + LaunchDraw.drawing + LaunchDraw.hold / 2)
        #expect(held.drawn.allSatisfy { $0 == 1 } && held.wiped == 0)
        #expect(held.groundOpacity == 1)
    }

    @Test("an eraser scrubs across it, back and forth, then the ground fades and it is finished")
    func ends() {
        let rubbing = LaunchDraw.frame(at: LaunchDraw.start + LaunchDraw.drawing + LaunchDraw.hold + LaunchDraw.erasing * 0.3)
        #expect(rubbing.wiped > 0 && rubbing.wiped < 1)
        // Back and forth: the scrub's ends alternate top and bottom, and its
        // passes overlap (each step narrower than the eraser).
        let ys = LaunchDraw.scrub.map(\.1)
        #expect(zip(ys, ys.dropFirst()).allSatisfy { $0 != $1 })
        #expect(LaunchDraw.scrub.first!.0 < 0 && LaunchDraw.scrub.last!.0 > 1, "it crosses the whole mark")
        let end = LaunchDraw.frame(at: LaunchDraw.duration + 0.01)
        #expect(end.finished && end.groundOpacity == 0)
        #expect(LaunchDraw.duration < 2.5, "a launch is a breath, not a wait")
    }

    @Test("five strokes, the body heavy and the rest lighter, as the mark is drawn")
    func strokes() {
        #expect(LogoStrokes.all.count == LaunchDraw.shares.count)
        #expect(LogoStrokes.all.first?.heavy == true && LogoStrokes.all.dropFirst().allSatisfy { !$0.heavy })
        #expect(LogoStrokes.outer > LogoStrokes.inner)
    }

    @Test("the crest waits for the launch")
    func crestWaits() throws {
        let ring = SourceSweep.code(try SourceSweep.read("Strata/Views/GoalRing.swift"))
        #expect(ring.contains("LaunchMoment.shared.finished"))
        let handoff = SourceSweep.code(try SourceSweep.read("Strata/Views/LaunchHandoff.swift"))
        #expect(handoff.contains("LaunchMoment.shared.finish()"))
    }
}
