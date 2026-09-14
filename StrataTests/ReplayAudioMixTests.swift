import AVFoundation
import Foundation
import Testing
@testable import Strata

@Suite("Replay audio mix")
struct ReplayAudioMixTests {
    private func landing(_ t: Double, index: Int = 0) -> ReplayScript.Landing {
        .init(time: t, mass: 1, column: 0, blockIndex: index)
    }

    @Test("no more than the limit in any one second, earliest kept")
    func limit() {
        let many = (0..<60).map { landing(Double($0) * 0.02, index: $0) } // 60 in 1.2s
        let kept = ReplayAudioMix.landingTimes(many, limitPerSecond: 12)
        for l in kept {
            #expect(kept.filter { $0.time > l.time - 1 && $0.time <= l.time }.count <= 12)
        }
        #expect(kept.first?.time == 0)
    }

    @Test("sparse landings all play")
    func sparse() {
        let few = (0..<5).map { landing(Double($0) * 0.5, index: $0) }
        #expect(ReplayAudioMix.landingTimes(few, limitPerSecond: 12).count == 5)
    }

    @Test("a landing exactly one second after another does not count it")
    func halfOpenWindow() {
        let twelve = (0..<12).map { landing(Double($0) * 0.01, index: $0) }
        // At 0.99 all twelve are inside its second: silent.
        #expect(ReplayAudioMix.landingTimes(twelve + [landing(0.99, index: 12)], limitPerSecond: 12).count == 12)
        // At 1.0 the first is exactly a second back and out: it sounds.
        #expect(ReplayAudioMix.landingTimes(twelve + [landing(1.0, index: 12)], limitPerSecond: 12).count == 13)
    }

    private static let now = Date(timeIntervalSince1970: 1_789_000_000)

    private func script(_ kind: ReplayKind) -> ReplayScript {
        ReplayScript(replay: ReplaySample.replay(kind, now: Self.now),
                     metrics: .standard(frame: ReplayCard.size), reduceMotion: false)
    }

    private func peak(_ buffer: AVAudioPCMBuffer, from: Double, to: Double) -> Float {
        let rate = buffer.format.sampleRate
        let a = max(0, Int(from * rate)), b = min(Int(buffer.frameLength), Int(to * rate))
        guard a < b, let l = buffer.floatChannelData?[0], let r = buffer.floatChannelData?[1] else { return 0 }
        var m: Float = 0
        for i in a..<b { m = max(m, abs(l[i]), abs(r[i])) }
        return m
    }

    @Test("the mix runs the replay plus its tail, silent until the first landing, sounding at each kept one")
    func mixShape() throws {
        let s = script(.week)
        let mix = try #require(ReplayAudioMix.mix(s, tail: 2))
        let rate = mix.format.sampleRate
        #expect(mix.format.channelCount == 2)
        #expect(abs(Double(mix.frameLength) / rate - (s.duration + 2)) < 1.0 / rate + 1e-9)
        let kept = ReplayAudioMix.landingTimes(s.landings, limitPerSecond: GridConstants.replayFeedbackPerSecond)
        let first = try #require(kept.first)
        #expect(peak(mix, from: 0, to: first.time - 0.001) == 0)
        for l in kept {
            #expect(peak(mix, from: l.time, to: l.time + 0.05) > 0.01, "landing at \(l.time) is silent")
        }
        #expect(peak(mix, from: 0, to: s.duration + 2) < 1)
    }

    @Test("a busy month is limited, never clips, and saves the same sound twice")
    func monthMix() throws {
        let s = script(.month)
        let kept = ReplayAudioMix.landingTimes(s.landings, limitPerSecond: GridConstants.replayFeedbackPerSecond)
        for l in kept {
            #expect(kept.filter { $0.time > l.time - 1 && $0.time <= l.time }.count <= GridConstants.replayFeedbackPerSecond)
        }
        let a = try #require(ReplayAudioMix.mix(s, tail: 2))
        let b = try #require(ReplayAudioMix.mix(s, tail: 2))
        #expect(peak(a, from: 0, to: s.duration + 2) < 1)
        let n = Int(a.frameLength)
        let la = try #require(a.floatChannelData?[0]), lb = try #require(b.floatChannelData?[0])
        #expect(memcmp(la, lb, n * MemoryLayout<Float>.size) == 0)
    }

    @Test("the live replay sounds exactly the landings the video mixes")
    func liveAgrees() {
        let s = script(.month)
        let feedback = ReplayFeedback()
        let expected = Set(ReplayAudioMix.landingTimes(s.landings, limitPerSecond: GridConstants.replayFeedbackPerSecond)
            .map(\.blockIndex))
        #expect(feedback.sounding(s) == expected)
    }
}
