import CryptoKit
import Foundation

/// **The crew's evening, at one moment** (the unification pass, 2026-10-09:
/// "a soft evening nudge, synchronized across a crew").
///
/// The app's rule is one cue a day (`EveningCheckIn`), so this is not a
/// second notification: it is the evening check-in itself, for someone in a
/// crew, moved to a minute every phone in that crew works out the same way,
/// and worded about the crew. Everyone's arrives together, so the chat comes
/// alive at once, with no server deciding it.
///
/// The minute is the crew's id and the crew's day, hashed onto 7:00 to 8:55pm
/// in the crew's zone, in five-minute steps: a different moment each evening,
/// the same one on every phone. A phone where that lands outside 5 to 10pm
/// locally (a friend abroad) keeps its own 7pm.
nonisolated enum CrewEvening {
    static let firstMinute = 19 * 60
    static let steps = 24
    static let step = 5

    static func minuteOfDay(crew: String, day: String) -> Int {
        let digest = SHA256.hash(data: Data("\(crew)|\(day)".utf8))
        let bytes = Array(digest)
        let n = (Int(bytes[0]) << 8) | Int(bytes[1])
        return firstMinute + (n % steps) * step
    }

    /// When the crew's evening is today, or nil when it falls outside this
    /// phone's evening.
    static func time(crew: String, zone: TimeZone, now: Date, calendar: Calendar = .current) -> Date? {
        let day = CrewDay.string(for: now, in: zone)
        guard let start = CrewDay.start(of: day, in: zone) else { return nil }
        let at = start.addingTimeInterval(Double(minuteOfDay(crew: crew, day: day)) * 60)
        let hour = calendar.component(.hour, from: at)
        guard (17..<22).contains(hour), calendar.isDate(at, inSameDayAs: now) else { return nil }
        return at
    }

    /// Warm, about the crew, never about who has or has not posted.
    static func line(crewName: String) -> String { "\(crewName) is sharing tonight's wins." }
}
