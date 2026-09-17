import CoreGraphics
import Foundation

/// **How alive a head is**, as data: everything that differs between a head
/// in chrome and a head that is the subject of its page.
///
/// - `.calm`: a header button, the sticker button, a sticker, the map marker.
///   Glances, side-eyes and brow flashes; the head itself never moves on its
///   own, the blink does not squash (a 33pt button that squashes reads as
///   pressed), and the eyes **never** rest on you.
/// - `.expressive`: Profile, the maker's preview, onboarding's head page, the
///   thank-you page. The creator's life: head turns and glances in 3D, a look
///   down at the words, a smile now and then, the crunch blink, and eyes that
///   rest on you for up to three seconds and then look away on purpose.
///
/// Every tunable (rests, holds, blink, contact, squash, yaw) is a
/// `GridConstants` token. A beat's choreography, when each cue lands inside
/// it, is authored data in `HeadDirector.resolve`, as `HeadTake.catalogue` is.
nonisolated struct HeadLife: Equatable, Sendable {
    var beatWeights: [HeadBeat.ID: Double]
    var beatRest: ClosedRange<Double>
    var firstBeat: Double
    var firstBeatAfterHello: Double
    /// How long the eyes rest on a point that is not you.
    var wander: ClosedRange<Double>
    /// After looking away, the chance the next fixation is you. 0 never.
    var contactShare: Double
    var contactHold: ClosedRange<Double>
    var microSaccades: Bool
    /// Nil: the lids close and nothing else moves.
    var blinkDepth: ClosedRange<Double>?
    var morphSquash: Bool
    var floats: Bool
    /// False: a pose only when a tap invites it.
    var movesHead: Bool
    var maxYaw: Double

    static let expressive = HeadLife(
        // The creator's six beats keep 80% of the weight in his proportions;
        // the made head's extras share the other 20%. Yaw moves in 36%.
        beatWeights: [.glance: 0.208, .turn: 0.152, .tilt: 0.144, .smile: 0.128, .down: 0.096, .brow: 0.072,
                      .sideEye: 0.04, .doubleTake: 0.03, .peoplesEyebrow: 0.03, .eyeRoll: 0.03,
                      .slowBlink: 0.03, .surprise: 0.02, .wink: 0.02],
        beatRest: GridConstants.headBeatRestExpressive,
        firstBeat: GridConstants.headFirstBeat,
        firstBeatAfterHello: GridConstants.headFirstBeatAfterHello,
        wander: GridConstants.headWanderExpressive,
        contactShare: GridConstants.headContactShare,
        contactHold: GridConstants.headContactHold,
        microSaccades: true,
        blinkDepth: GridConstants.headBlinkDepth,
        morphSquash: true,
        floats: true,
        movesHead: true,
        maxYaw: GridConstants.headMaxYaw)

    static let calm = HeadLife(
        beatWeights: [.glance: 0.4, .sideEye: 0.3, .browFlash: 0.3],
        beatRest: GridConstants.headBeatRestCalm,
        firstBeat: GridConstants.headBeatRestCalm.lowerBound,
        firstBeatAfterHello: GridConstants.headBeatRestCalm.lowerBound,
        wander: GridConstants.headWanderCalm,
        contactShare: 0,
        contactHold: GridConstants.headContactHold,
        microSaccades: false,
        blinkDepth: nil,
        morphSquash: false,
        floats: false,
        movesHead: false,
        maxYaw: GridConstants.headMaxYaw)
}
