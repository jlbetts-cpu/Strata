import AVFoundation
import Foundation
import Testing
@testable import Strata

/// The rendered landings a live drop plays from.
///
/// A landing used to be synthesised on the main thread at the moment of
/// impact, freshly jittered every time. The pool renders them ahead and must
/// keep the two things that made that worth doing: it is the same voice, and
/// it does not repeat itself back to back.
@Suite("Impact pool")
struct ImpactPoolTests {

    @Test("a pooled landing is the same length and level as the voice rendered directly")
    func sameVoice() throws {
        let pool = SoundEngine.ImpactPool()
        let pooled = try #require(pool.buffer(mass: 2, column: 1))
        let direct = try #require(SoundEngine.impactBuffer(mass: 2, column: 1, gain: 1))
        #expect(pooled.frameLength == direct.frameLength)
        #expect(pooled.format.channelCount == 2)
        func peak(_ b: AVAudioPCMBuffer) -> Float {
            (0..<Int(b.frameLength)).reduce(Float(0)) { max($0, abs(b.floatChannelData![0][$1])) }
        }
        // The pool's copy is jittered (±6% level, ±8% decay); the direct one
        // is not. Within 15% is the same voice.
        let ratio = peak(pooled) / peak(direct)
        #expect(ratio > 0.85 && ratio < 1.15, "peak ratio \(ratio)")
    }

    @Test("once a key has its variants, no landing repeats the one before it")
    func noBackToBackRepeat() async throws {
        let pool = SoundEngine.ImpactPool()
        _ = pool.buffer(mass: 1, column: 0)
        // Variants are topped up on a background queue, one per hit.
        var seen = Set<ObjectIdentifier>()
        for _ in 0..<200 where seen.count < SoundEngine.ImpactPool.variants {
            if let b = pool.buffer(mass: 1, column: 0) { seen.insert(ObjectIdentifier(b)) }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(seen.count == SoundEngine.ImpactPool.variants)

        var previous: AVAudioPCMBuffer?
        for _ in 0..<40 {
            let b = try #require(pool.buffer(mass: 1, column: 0))
            #expect(b !== previous)
            previous = b
        }
    }
}
