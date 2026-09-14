import Accelerate
import AVFoundation

/// The replay's landings as one stereo track for the saved video, and the one
/// rule for which landings make a sound at all.
///
/// **One rule, two players.** `ReplayFeedback` chooses which of the live
/// replay's landings sound with `landingTimes`, and the video's track is mixed
/// by the same rule. The landings themselves can differ: the live script is
/// laid out for the screen and may be the reduced-motion one, while the video
/// always uses the card's full-motion script.
///
/// **The video always carries the landings, even with sounds off in
/// Settings.** A saved video is a file posted and played somewhere else; the
/// in-app mute is about Strata making noise on your phone, and a silent video
/// would be a different thing from the replay it was saved from.
enum ReplayAudioMix {

    /// The landings that sound: in time order, each one kept unless `limit`
    /// already sounded in the second before it (a half-open window, so a
    /// landing exactly one second after another does not count it). Earliest
    /// first, so a burst plays its start and goes quiet, rather than
    /// thinning evenly into noise.
    static func landingTimes(_ landings: [ReplayScript.Landing], limitPerSecond limit: Int) -> [ReplayScript.Landing] {
        var kept: [ReplayScript.Landing] = []
        for l in landings.sorted(by: { $0.time < $1.time }) {
            // The same comparison the window is defined by, `time > t - 1`,
            // so float rounding cannot let a 13th in at the edge.
            let inWindow = kept.reversed().prefix { $0.time > l.time - 1 }.count
            if inWindow < limit { kept.append(l) }
        }
        return kept
    }

    /// One landing per instant, the heaviest (the earliest block of that
    /// mass on a tie), in time order.
    ///
    /// Reduce Motion lands a whole day at one moment, so a busy day was up
    /// to 12 impacts and ticks in a single frame: one loud click, not a
    /// patter. A day there is one landing, felt at its weightiest block.
    static func heaviestPerInstant(_ landings: [ReplayScript.Landing]) -> [ReplayScript.Landing] {
        var byTime: [Double: ReplayScript.Landing] = [:]
        for l in landings {
            if let kept = byTime[l.time], kept.mass > l.mass || (kept.mass == l.mass && kept.blockIndex < l.blockIndex) { continue }
            byTime[l.time] = l
        }
        return byTime.values.sorted { $0.time < $1.time }
    }

    /// The whole replay plus `tail` seconds, as a non-interleaved Float32
    /// stereo buffer at `SoundEngine.mixSampleRate`.
    static func mix(_ script: ReplayScript, tail: Double) -> AVAudioPCMBuffer? {
        let rate = SoundEngine.mixSampleRate
        let frames = AVAudioFrameCount(((script.duration + tail) * rate).rounded())
        guard frames > 0,
              let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2),
              let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let l = out.floatChannelData?[0], let r = out.floatChannelData?[1] else { return nil }
        out.frameLength = frames
        l.update(repeating: 0, count: Int(frames))
        r.update(repeating: 0, count: Int(frames))

        var cache: [Int: AVAudioPCMBuffer] = [:]
        for landing in landingTimes(script.landings, limitPerSecond: GridConstants.replayFeedbackPerSecond) {
            let key = landing.mass * 16 + landing.column
            guard let voice = cache[key]
                    ?? SoundEngine.impactBuffer(mass: landing.mass, column: landing.column,
                                                gain: GridConstants.replayImpactGain),
                  let vl = voice.floatChannelData?[0], let vr = voice.floatChannelData?[1] else { continue }
            cache[key] = voice
            let start = Int((landing.time * rate).rounded())
            let count = min(Int(voice.frameLength), Int(frames) - start)
            guard start >= 0, count > 0 else { continue }
            vDSP_vadd(l + start, 1, vl, 1, l + start, 1, vDSP_Length(count))
            vDSP_vadd(r + start, 1, vr, 1, r + start, 1, vDSP_Length(count))
        }
        // Soft clip, so a dense patch never distorts. A single landing peaks
        // near 0.16, where tanh is within 1% of straight.
        var n = Int32(frames)
        vvtanhf(l, l, &n)
        vvtanhf(r, r, &n)
        return out
    }
}
