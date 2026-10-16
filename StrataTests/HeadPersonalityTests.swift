import Foundation
import Testing
@testable import Strata

/// **Your head's personality** (2026-10-16): timing and what it reaches for,
/// never a different face.
@Suite("Head personality")
struct HeadPersonalityTests {
    @Test("calm is the life as it was")
    func calmIsUnchanged() {
        #expect(HeadLife.expressive.personalised(.calm) == .expressive)
        #expect(HeadLife.calm.personalised(.calm) == .calm)
    }

    @Test("bouncy beats sooner and smiles more; chill waits longer and blinks slowly")
    func timingAndReach() {
        let base = HeadLife.expressive
        let bouncy = base.personalised(.bouncy)
        #expect(bouncy.beatRest.upperBound < base.beatRest.upperBound)
        #expect((bouncy.beatWeights[.smile] ?? 0) > (base.beatWeights[.smile] ?? 0))
        let chill = base.personalised(.chill)
        #expect(chill.beatRest.lowerBound > base.beatRest.lowerBound)
        #expect((chill.beatWeights[.slowBlink] ?? 0) > (base.beatWeights[.slowBlink] ?? 0))
        #expect(chill.maxYaw < base.maxYaw)
    }

    @Test("cheeky winks and raises an eyebrow far more often")
    func cheeky() {
        let base = HeadLife.expressive
        let cheeky = base.personalised(.cheeky)
        #expect((cheeky.beatWeights[.wink] ?? 0) >= (base.beatWeights[.wink] ?? 0) * 3.9)
        #expect((cheeky.beatWeights[.peoplesEyebrow] ?? 0) > (base.beatWeights[.peoplesEyebrow] ?? 0))
        // A head in chrome never moves itself, whatever the personality.
        #expect(HeadLife.calm.personalised(.cheeky).movesHead == false)
    }

    @Test("every personality has words with no long dash and no exclamation")
    func words() {
        for p in HeadPersonality.allCases {
            #expect(!p.line.contains("\u{2014}") && !p.line.contains("!"))
            #expect(!p.name.isEmpty)
        }
    }
}
