import AVFoundation
import Foundation
import Testing
@testable import Strata

/// The rendered landings a live drop plays from.
///
/// A landing used to be synthesised on the main thread at the moment of
/// impact, freshly jittered every time. The pool renders them ahead and must
/// keep the two things that made that worth doing: it is the same voice, and
/// it does not repeat itself back to back, including on a key's first hits.
@Suite("Impact pool")
struct ImpactPoolTests {

    @Test("an unfilled key hands out nothing rather than a lone variant")
    func unfilledKeyIsNil() {
        let pool = SoundEngine.ImpactPool()
        #expect(pool.buffer(mass: 3, column: 2) == nil)
    }

    @Test("a pooled landing is the same length and level as the voice rendered directly")
    func sameVoice() throws {
        let pool = SoundEngine.ImpactPool()
        pool.warmNow()
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

    /// The window the first version left open: one variant rendered, the
    /// second still rendering, so the first two hits were the same buffer.
    @Test("from the very first hit, no landing repeats the one before it")
    func noBackToBackRepeatFromTheFirstHit() throws {
        for mass in 1...3 {
            for column in 0..<4 {
                let pool = SoundEngine.ImpactPool()
                pool.warmNow()
                var previous: AVAudioPCMBuffer?
                var seen: [ObjectIdentifier: AVAudioPCMBuffer] = [:]
                for _ in 0..<30 {
                    let b = try #require(pool.buffer(mass: mass, column: column))
                    #expect(b !== previous, "mass \(mass) column \(column) repeated")
                    seen[ObjectIdentifier(b)] = b
                    previous = b
                }
                // The round robin actually uses every variant: a random pick
                // that avoids only the last one misses one of three over 30
                // draws with probability about 2^-28.
                #expect(seen.count == SoundEngine.ImpactPool.variants)
                // And the variants are different sounds, not three copies of
                // one render: jitter and a fresh contact burst each time.
                let firsts = seen.values.map { $0.floatChannelData![0][2000] }
                #expect(Set(firsts).count == firsts.count, "variants are identical")
            }
        }
    }
}
