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

/// **Your head's personality** (the owner, 2026-10-16: "customizing your
/// head's personality ... every personality is very expressive and a bit
/// cute"). Research (Duolingo's idle sets; Thomas and Johnston on timing;
/// Bitmoji's "one identity, many states"): a personality is timing and what
/// it reaches for, never a different face. Each one rescales the rests and
/// reweights the beats of the same life; the photograph is untouched.
nonisolated enum HeadPersonality: String, CaseIterable, Identifiable, Sendable {
    case calm, bouncy, cheeky, chill

    var id: String { rawValue }

    var name: String {
        switch self {
        case .calm: "Calm"
        case .bouncy: "Bouncy"
        case .cheeky: "Cheeky"
        case .chill: "Chill"
        }
    }

    /// What it is like, in a few words, for the picker.
    var line: String {
        switch self {
        case .calm: "Easy, looks around, smiles now and then."
        case .bouncy: "Quick to smile, nods along, always moving."
        case .cheeky: "Winks, raised eyebrows, the odd eye roll."
        case .chill: "Slow blinks, long looks, in no hurry."
        }
    }

    static let key = "headPersonality"

    /// Yours, on this phone.
    static var current: HeadPersonality {
        HeadPersonality(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .calm
    }

    /// How long between beats, as a share of the life's own.
    var restScale: Double {
        switch self {
        case .calm: 1
        case .bouncy: 0.6
        case .cheeky: 0.8
        case .chill: 1.5
        }
    }

    /// How much more (or less) it reaches for each beat.
    var weight: [HeadBeat.ID: Double] {
        switch self {
        case .calm: [:]
        case .bouncy: [.smile: 2.2, .nod: 2.5, .lift: 2, .tilt: 1.5, .turn: 1.3, .slowBlink: 0.4, .down: 0.6]
        case .cheeky: [.wink: 4, .peoplesEyebrow: 4, .sideEye: 3, .eyeRoll: 3, .doubleTake: 2.5, .brow: 2,
                       .browFlash: 2, .smile: 1.2, .down: 0.5]
        case .chill: [.slowBlink: 4, .down: 1.6, .glance: 1.3, .turn: 0.6, .smile: 0.8, .surprise: 0.3,
                      .doubleTake: 0.3, .wink: 0.5]
        }
    }
}

extension HeadLife {
    /// The same life, as this personality lives it.
    func personalised(_ personality: HeadPersonality) -> HeadLife {
        guard personality != .calm else { return self }
        var life = self
        for (beat, factor) in personality.weight {
            if let w = life.beatWeights[beat] { life.beatWeights[beat] = w * factor }
            else if factor > 1, life.movesHead { life.beatWeights[beat] = 0.02 * factor }
        }
        let scale = personality.restScale
        life.beatRest = (beatRest.lowerBound * scale)...(beatRest.upperBound * scale)
        life.firstBeat *= min(scale, 1)
        life.wander = (wander.lowerBound * scale)...(wander.upperBound * scale)
        if personality == .chill { life.maxYaw *= 0.7 }
        return life
    }
}
