import Foundation

/// The launch roll's choreography, as a pure function of time.
///
/// No SwiftUI in here on purpose: the offline preview
/// (`ground-shots/scripts/roll/`) compiles this same file with `xcrun swift`
/// and draws its frames from it, so what was looked at before the build is
/// what the app plays.
///
/// The S tumbles in from the left like a rigid square: its square bounding
/// box pivots 90 degrees on its bottom corner in the direction of travel,
/// along an invisible floor at the bottom of the box's resting place, which
/// is centred on the screen. While it rolls it wears a block's material (the
/// block colour, the wash, the rim lit along its top edge) and each landing
/// cuts to the next block colour; the last landing, in the centre, resolves
/// to the flat white icon S at the icon's own angle. Then the S fades on
/// black, then the black fades.
enum LaunchRoll {
    /// Side of the tumbling square, in points: the S asset's larger side.
    static let side: Double = 128
    static let rolls = 3

    /// One roll: 90 degrees on the app's own fall curve
    /// (`GridConstants.dropFallCurve`, which is t squared): it tips from
    /// rest, gathers speed and lands at full speed. A falling thing does not
    /// ease into the ground, and that is the weight.
    static let rollDuration = 0.16
    /// Still on its face between rolls. No rebound: a block lands and stays.
    static let settleDuration = 0.04
    /// How far into the first roll the clock starts. The first roll pivots
    /// entirely off screen and only its last third reaches the edge, so
    /// the sequence begins as the square tips across it rather than on
    /// 0.1s of black.
    static let entry = 0.10
    /// White and still in the centre, before the fades.
    static let hold = 0.15

    static let markFade = 0.25
    static let groundFade = 0.30
    static let markFadeReduced = 0.12
    static let groundFadeReduced = 0.18

    struct Frame: Equatable {
        /// Landings so far. The square stands `rolls - landed` sides left of
        /// its resting place.
        var landed: Int
        /// The current roll's angle about its pivot, degrees clockwise.
        var tilt: Double
        /// Which fill: 0..<rolls index the block colours, `rolls` is white.
        var fill: Int
        var markOpacity: Double
        var groundOpacity: Double
        var finished: Bool

        /// Rotation of the S inside its square, degrees clockwise. Chosen so
        /// that after the last landing it is a whole number of turns, which
        /// is the icon's own angle.
        var restAngle: Double { Double(landed - LaunchRoll.rolls) * 90 }
        /// Horizontal offset of the square from its resting place, points.
        var offset: Double { Double(landed - LaunchRoll.rolls) * LaunchRoll.side }
    }

    static func duration(reduceMotion: Bool) -> Double {
        reduceMotion
            ? hold + markFadeReduced + groundFadeReduced
            : Double(rolls) * (rollDuration + settleDuration) - entry + hold + markFade + groundFade
    }

    static func frame(at t: Double, reduceMotion: Bool) -> Frame {
        if reduceMotion {
            let fades = hold
            return Frame(landed: rolls, tilt: 0, fill: rolls,
                         markOpacity: 1 - easeIn(progress(t, fades, markFadeReduced)),
                         groundOpacity: 1 - easeOut(progress(t, fades + markFadeReduced, groundFadeReduced)),
                         finished: t >= duration(reduceMotion: true))
        }
        let t = t + entry
        let step = rollDuration + settleDuration
        let rolling = Double(rolls) * step
        if t < rolling {
            let i = max(0, Int(t / step))
            let local = t - Double(i) * step
            if local < rollDuration {
                return Frame(landed: i, tilt: 90 * easeIn(local / rollDuration),
                             fill: i, markOpacity: 1, groundOpacity: 1, finished: false)
            }
            // Landed, and the fill has cut to the next colour.
            return Frame(landed: i + 1, tilt: 0,
                         fill: i + 1, markOpacity: 1, groundOpacity: 1, finished: false)
        }
        let fades = rolling + hold
        return Frame(landed: rolls, tilt: 0, fill: rolls,
                     markOpacity: 1 - easeIn(progress(t, fades, markFade)),
                     groundOpacity: 1 - easeOut(progress(t, fades + markFade, groundFade)),
                     finished: t - entry >= duration(reduceMotion: false))
    }

    private static func progress(_ t: Double, _ start: Double, _ length: Double) -> Double {
        min(max((t - start) / length, 0), 1)
    }
    static func easeIn(_ x: Double) -> Double { x * x }
    static func easeOut(_ x: Double) -> Double { 1 - (1 - x) * (1 - x) }
}
