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
        // **One life, and a playful one** (the owner, 2026-10-16: "remove the
        // personalities and combine them, they all feel the same anyways ...
        // I wanted some new animations to expand the heads' expressions, make
        // it more playful"). The creator's looks still lead; the made head's
        // faces come round more often; and six moves of its own, a hop, a
        // wiggle, a bop, a peek, a giggle and a curious look round, take a
        // third of the beats between them.
        // The brows have three moves of their own (2026-10-16, "moving the
        // eyebrows to emote"): a waggle, one raised, and drawn together.
        beatWeights: [.glance: 0.12, .turn: 0.08, .tilt: 0.06, .smile: 0.09, .down: 0.03, .brow: 0.05,
                      .sideEye: 0.02, .doubleTake: 0.03, .peoplesEyebrow: 0.03, .eyeRoll: 0.03,
                      .slowBlink: 0.01, .surprise: 0.03, .wink: 0.04,
                      .hop: 0.06, .wiggle: 0.06, .bop: 0.05, .peek: 0.04, .giggle: 0.06, .curious: 0.05,
                      .browWiggle: 0.025, .skeptic: 0.02, .focus: 0.015],
        // A little sooner between beats than the creator's 1:1 rests.
        beatRest: (GridConstants.headBeatRestExpressive.lowerBound * 0.75)...(GridConstants.headBeatRestExpressive.upperBound * 0.75),
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
        // Faces only: a head in chrome never moves itself, but it smiles and
        // winks now (2026-10-16, "more playful").
        beatWeights: [.glance: 0.3, .sideEye: 0.2, .browFlash: 0.25, .smile: 0.15, .wink: 0.1, .browWiggle: 0.12],
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
