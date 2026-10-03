import Foundation

/// **A crew's days, as numbers.** Who posted how many wins on which crew day,
/// counted on this phone from what it fetched.
///
/// Counts only: never a title, never a photograph. A crew's wins leave the
/// cloud after a few days (`SocialStore.prune`) and that stays true; what is
/// kept is the tally, on the phone, so the crew's streak and its chart outlive
/// the pictures (the owner, 2026-10-02: "the photos shouldnt be saved on the
/// cloud overnight but it should show some statistics").
///
/// A phone fills in every day the cloud still holds when it refreshes, so a
/// phone opened once every couple of days misses nothing.
nonisolated struct CrewHistory: Codable, Equatable, Sendable {
    /// Crew day (`yyyy-MM-dd`, the crew's zone) to profile id to wins.
    var days: [String: [String: Int]] = [:]

    /// What the cloud holds now, written over the days it covers.
    ///
    /// The days from `cutoff` on are the cloud's to say: a withdrawn win
    /// comes off the count, and a day that had wins and has none now is
    /// emptied. Days before `cutoff` are no longer in the cloud and are kept
    /// as they were last seen.
    mutating func record(_ wins: [SharedWin], from cutoff: String, through today: String) {
        for day in days.keys where day >= cutoff && day <= today { days[day] = nil }
        for win in wins where win.crewDay >= cutoff && win.crewDay <= today {
            days[win.crewDay, default: [:]][win.senderProfileID.uuidString, default: 0] += 1
        }
    }

    /// Every win the crew posted, by day: what the chart draws.
    var totals: [String: Int] {
        days.mapValues { $0.values.reduce(0, +) }
    }

    /// The days everyone who was in the crew that day posted a win.
    ///
    /// "Everyone" is the people in the crew now who had joined by the end of
    /// that day: someone who joined on Thursday never broke Tuesday. Each
    /// join day is worked out once, not once per day per person.
    func fullDays(members: [CrewMember], zone: TimeZone) -> Set<String> {
        let joined = members.map { ($0.profileID.uuidString, CrewDay.string(for: $0.joinedAt, in: zone)) }
        var full: Set<String> = []
        for (day, posted) in days {
            let expected = joined.filter { $0.1 <= day }
            if !expected.isEmpty, expected.allSatisfy({ (posted[$0.0] ?? 0) > 0 }) { full.insert(day) }
        }
        return full
    }

    /// Days in a row everyone posted, ending today, or yesterday while today
    /// is still open: a streak is not broken by a morning.
    static func streak(_ full: Set<String>, today: String, zone: TimeZone) -> Int {
        var day = full.contains(today) ? today : (CrewDay.day(today, offsetBy: -1, in: zone) ?? today)
        var count = 0
        while full.contains(day) {
            count += 1
            guard let before = CrewDay.day(day, offsetBy: -1, in: zone) else { break }
            day = before
        }
        return count
    }

    /// The longest run there has been.
    static func best(_ full: Set<String>, zone: TimeZone) -> Int {
        var best = 0
        var run = 0
        var previous: String?
        for day in full.sorted() {
            if let previous, CrewDay.day(previous, offsetBy: 1, in: zone) == day { run += 1 } else { run = 1 }
            best = max(best, run)
            previous = day
        }
        return best
    }

    /// The people who have not posted yet today, in the order they joined.
    func waiting(today: String, members: [CrewMember]) -> [CrewMember] {
        let posted = days[today] ?? [:]
        return members.filter { (posted[$0.profileID.uuidString] ?? 0) == 0 }
    }
}
