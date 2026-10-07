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
        #expect(held.drawn.allSatisfy { $0 == 1 } && held.erased.allSatisfy { $0 == 0 })
        #expect(held.groundOpacity == 1)
    }

    @Test("rubbed out in the same order, then the ground fades and it is finished")
    func ends() {
        let rubbing = LaunchDraw.frame(at: LaunchDraw.start + LaunchDraw.drawing + LaunchDraw.hold + LaunchDraw.erasing * 0.3)
        #expect(rubbing.erased[0] > 0 && rubbing.erased[4] == 0)
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
