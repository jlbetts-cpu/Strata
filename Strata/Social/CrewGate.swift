import Foundation

/// **Whether this phone may be in a crew, and what stands in the way**
/// (2026-10-08, the launch audit). Crews ship on in 1.0 and need iOS 26,
/// because the Declared Age Range the age rule rests on exists only there.
///
/// One answer for every way in: the Crews list, an invitation, a tapped
/// notification, the Crews button. An invitation used to join the crew and
/// write a Member record before the rules or the age had been asked, because
/// both were asked only by the list (`SocialStore.accept` now refuses
/// anything but `.open`, and `CrewRouter` holds the invitation meanwhile).
nonisolated enum CrewGate: Equatable, Sendable {
    /// Rules agreed, an age answered, and not a known child.
    case open
    /// Below iOS 26. Nothing of crews opens, and nothing is asked.
    case needsNewerOS
    /// Under 13: crews do not open (`CrewAge.opensCrews`).
    case tooYoung
    /// The crew rules have not been agreed to yet (`CrewRules`).
    case needsRules
    /// No age answer yet: Declared Age Range has not been asked.
    case needsAge

    /// The words for a phone below iOS 26: one calm sentence, no dash.
    static let newerOSWords = "Crews need iOS 26 or later."

    /// The order matters: a phone that cannot run crews is told only that,
    /// and a known child is never shown the rules for something they cannot
    /// join.
    static func check(osSupportsCrews: Bool, rulesAccepted: Bool, age: CrewAge) -> CrewGate {
        guard osSupportsCrews else { return .needsNewerOS }
        if !age.opensCrews { return .tooYoung }
        guard rulesAccepted else { return .needsRules }
        guard age != .unknown else { return .needsAge }
        return .open
    }

    /// Nothing the person can do in the app changes it: an invitation held
    /// for it is let go, never joined later.
    var isFinal: Bool { self == .needsNewerOS || self == .tooYoung }
}

extension CrewGate {
    /// This phone, now.
    @MainActor static var current: CrewGate {
        check(osSupportsCrews: CrewsFlag.osSupportsCrews, rulesAccepted: CrewRules.accepted, age: .current)
    }
}
