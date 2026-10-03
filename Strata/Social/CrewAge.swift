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
    /// Asked, and chose not to say (or the phone could not answer). Sends no
    /// photographs, as before; but sees friends' ones, because it is not a
    /// known child. It used to be stored as `teen`, and since build 51 that
    /// hid every friend's photo from an adult who had simply said no to the
    /// prompt (the owner, 2026-10-03: "when i updated it all the photos
    /// from the crew disappeared"). A real child's phone has Communication
    /// Safety on by default, which checks every photo instead
    /// (`CrewSafety.incoming`).
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

    var opensCrews: Bool { self != .under13 }
    /// Unknown sends no photos until an answer comes back.
    var sendsPhotos: Bool { self == .adult }
    /// Whether friends' photographs show without a check, when the phone's
    /// own analysis is off: everyone but a known child.
    var seesPhotosUnchecked: Bool { self != .under13 && self != .teen }

    /// From the lower bound of a declared range.
    static func from(lowerBound: Int?) -> CrewAge {
        guard let lowerBound else { return .teen }
        if lowerBound >= 16 { return .adult }
        if lowerBound >= 13 { return .teen }
        return .under13
    }
}
