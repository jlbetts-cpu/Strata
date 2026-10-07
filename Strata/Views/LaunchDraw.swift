import Foundation
import Observation

/// **The launch draws the logo and rubs it out** (the owner, 2026-10-06:
/// "when you first open the app it should look like its being drawn right in
/// the middle and then erased and then that middle progress comes in").
///
/// A pure function of time, as `LaunchRoll` is: each of the mark's strokes
/// (`LogoStrokes`) draws in the order a hand would (the body, the lens, the
/// eyes, the smile), holds, rubs out in the same order, and then the ground
/// fades, and the goal crest arrives where the middle of the header is
/// (`LaunchMoment`). Reduce Motion keeps the still mark and its fades.
enum LaunchDraw {
    /// Each stroke's share of the drawing, by its length.
    static let shares: [Double] = [0.5, 0.22, 0.06, 0.06, 0.16]
    static let start = 0.10
    static let drawing = 1.05
    static let hold = 0.28
    static let erasing = 0.5
    static let groundFade = 0.3

    struct Frame: Equatable {
        /// Per stroke, how much is drawn (0 to 1) and how much rubbed out.
        var drawn: [Double]
        var erased: [Double]
        var groundOpacity: Double
        var finished: Bool
    }

    static var duration: Double { start + drawing + hold + erasing + groundFade }

    static func frame(at t: Double) -> Frame {
        let drawn = phase(t - start, over: drawing)
        let erased = phase(t - start - drawing - hold, over: erasing)
        let fadeAt = start + drawing + hold + erasing
        let ground = 1 - min(1, max(0, (t - fadeAt) / groundFade))
        return Frame(drawn: drawn, erased: erased, groundOpacity: ground, finished: t >= duration)
    }

    /// Each stroke's progress when the whole pass is `t` into `total`, one
    /// after another, each eased in and out as a hand speeds up and slows.
    static func phase(_ t: Double, over total: Double) -> [Double] {
        var from = 0.0
        return shares.map { share in
            let span = share * total
            let p = span > 0 ? min(1, max(0, (t - from) / span)) : 1
            from += span
            return p * p * (3 - 2 * p)
        }
    }
}

/// **The launch has finished**, for what arrives after it: the goal crest
/// comes in once the logo has been rubbed out (`GoalCrest`).
@MainActor
@Observable
final class LaunchMoment {
    static let shared = LaunchMoment()
    private(set) var finished = false
    func finish() { if !finished { finished = true } }
}
