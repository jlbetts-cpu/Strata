import Testing
import Foundation
@testable import Strata

/// The maker's asks, and its one extra ask for a missed blink (owner,
/// 2026-09-16: "asks for one quick blink again before finishing, only then").
///
/// Self-test: make `askAll` loop while the blink is not caught and
/// `askedOnceOnly` fails; drop the cancel check after the wink and
/// `cancelAsksNothingMore` fails.
@MainActor
@Suite("HeadMakerFlow")
struct HeadMakerFlowTests {

    private final class Recorder {
        var steps: [HeadMakerModel.Step] = []
        var cancelAfter: HeadMakerModel.Step?
        var cancelled = false
    }

    private func run(blinkCaught: Bool, cancelAfter: HeadMakerModel.Step? = nil) async -> (Bool, Recorder) {
        let recorder = Recorder()
        recorder.cancelAfter = cancelAfter
        let made = await HeadMakerModel.askAll(from: .blink, ask: { ask in
            recorder.steps.append(ask.step)
            if ask.step == recorder.cancelAfter { recorder.cancelled = true }
        }, blinkCaught: { blinkCaught }, isCancelled: { recorder.cancelled })
        return (made, recorder)
    }

    @Test("a caught blink: five asks, no second blink, then the head is made")
    func caughtBlink() async {
        let (made, recorder) = await run(blinkCaught: true)
        #expect(made)
        #expect(recorder.steps == [.blink, .smile, .brows, .surprised, .wink])
    }

    @Test("a missed blink is asked for once more, at the end, and only once")
    func askedOnceOnly() async {
        let (made, recorder) = await run(blinkCaught: false)
        #expect(made)
        #expect(recorder.steps == [.blink, .smile, .brows, .surprised, .wink, .blinkAgain])
        #expect(recorder.steps.filter { $0 == .blinkAgain }.count == 1)
    }

    @Test("cancelled before the end: no second blink and no head")
    func cancelAsksNothingMore() async {
        let (made, recorder) = await run(blinkCaught: false, cancelAfter: .wink)
        #expect(!made)
        #expect(!recorder.steps.contains(.blinkAgain))
        let (madeAfterAgain, again) = await run(blinkCaught: false, cancelAfter: .blinkAgain)
        #expect(!madeAfterAgain)
        #expect(again.steps.last == .blinkAgain)
    }
}
