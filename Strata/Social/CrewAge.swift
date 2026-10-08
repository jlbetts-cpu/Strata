import Foundation
import SwiftUI

/// Who may use crews, by age (the owner, 2026-10-02: "13+ with limits").
///
/// - Under 13: crews do not open.
/// - 13 to 15: crews work, and photographs never leave the phone; titles and
///   shapes do.
/// - 16 and over: everything.
///
/// The range comes from Apple's Declared Age Range, asked the first time
/// Crews is opened and kept. **Someone who declines to share is treated as 13
/// to 15**, the cautious answer that still lets them in.
nonisolated enum CrewAge: String, Sendable {
    case unknown
    case under13
    case teen
    case adult
    /// Asked, and chose not to say (or the phone could not answer).
    ///
    /// **Treated exactly as 13 to 15** (the 2026-10-08 audit), because that is
    /// what the privacy policy promises: "If you would rather not say, Some
    /// Wins treats you as 13 to 15". It had drifted: declined saw friends'
    /// photographs unchecked and could not write in the chat, neither of
    /// which a 13 to 15 does. Kept as its own case, not stored as `teen`, so
    /// it is asked again after ninety days (`needsAsking`) and the answer can
    /// change. Every rule reads `rule`, never the raw case.
    case declined

    static let key = "crews.age"

    static var current: CrewAge {
        CrewAge(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .unknown
    }

    static func save(_ age: CrewAge) {
        UserDefaults.standard.set(version, forKey: versionKey)
        UserDefaults.standard.set(age.rawValue, forKey: key)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: askedKey)
    }

    static let askedKey = "crews.ageAskedAt"
    /// Bumped when a stored answer may mean something it did not: version 2
    /// split "declined" out of "teen", so anyone stored as a teen is asked
    /// once more.
    static let versionKey = "crews.ageVersion"
    static let version = 2

    /// **Asked again, now and then.** An answer was kept for ever, so someone
    /// who declined to share, or a fifteen-year-old who has since turned
    /// sixteen, stayed held back for good (the 2026-10-03 audit). Anything
    /// short of a confirmed adult is asked again after ninety days.
    static func needsAsking(now: Date = Date(), defaults: UserDefaults = .standard) -> Bool {
        let age = CrewAge(rawValue: defaults.string(forKey: key) ?? "") ?? .unknown
        guard age != .unknown else { return true }
        guard age != .adult else { return false }
        if age == .teen, defaults.integer(forKey: versionKey) < version { return true }
        let asked = Date(timeIntervalSince1970: defaults.double(forKey: askedKey))
        return now.timeIntervalSince(asked) > 90 * 86_400
    }

    /// The age the rules treat this answer as: declined is 13 to 15.
    var rule: CrewAge { self == .declined ? .teen : self }

    var opensCrews: Bool { rule != .under13 }
    /// Photographs, and the head cut from one: 16 and over only. Unknown
    /// sends none until an answer comes back.
    var sendsPhotos: Bool { rule == .adult }
    /// Whether friends' photographs show without a check, when the phone's
    /// own analysis is off: everyone but a known child, or someone treated
    /// as one (13 to 15, and declined).
    var seesPhotosUnchecked: Bool { rule != .under13 && rule != .teen }
    /// Words in a crew's chat, replies and doodles: 13 and over, declined
    /// included, as 13 to 15 may. Not while the age is unknown.
    var writesInCrews: Bool { rule == .adult || rule == .teen }

    /// From the lower bound of a declared range.
    static func from(lowerBound: Int?) -> CrewAge {
        guard let lowerBound else { return .teen }
        if lowerBound >= 16 { return .adult }
        if lowerBound >= 13 { return .teen }
        return .under13
    }
}
