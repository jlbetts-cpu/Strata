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

    static let key = "crews.age"

    static var current: CrewAge {
        CrewAge(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .unknown
    }

    static func save(_ age: CrewAge) {
        UserDefaults.standard.set(age.rawValue, forKey: key)
    }

    var opensCrews: Bool { self != .under13 }
    /// Unknown sends no photos until an answer comes back.
    var sendsPhotos: Bool { self == .adult }

    /// From the lower bound of a declared range.
    static func from(lowerBound: Int?) -> CrewAge {
        guard let lowerBound else { return .teen }
        if lowerBound >= 16 { return .adult }
        if lowerBound >= 13 { return .teen }
        return .under13
    }
}
