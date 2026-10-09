import Foundation

/// **A crew's days, as numbers.** Who posted how many wins on which crew day,
/// counted on this phone from what it fetched.
///
/// Counts only: never a title, never a photograph. A crew's wins leave the
/// cloud after two weeks (`CrewDay.keptDays`; it was a few days until the
/// owner asked for recent days on 2026-10-05); what is kept is the tally, on
/// the phone, so the crew's streak and its chart outlive the pictures (the
/// owner, 2026-10-02: "it should show some statistics").
///
/// A phone fills in every day the cloud still holds when it refreshes, so a
/// phone opened once every couple of days misses nothing.
nonisolated struct CrewHistory: Codable, Equatable, Sendable {
    /// Crew day (`yyyy-MM-dd`, the crew's zone) to profile id to wins.
    var days: [String: [String: Int]] = [:]

    /// What the cloud holds now, written over the days it covers.
    ///
    /// The days from `rewrite` on are the cloud's to say: a withdrawn win
    /// comes off the count, and a day that had wins and has none now is
    /// emptied. Days from `cutoff` up to `rewrite` are filled in from the
    /// cloud only where this phone has no count yet. Days before `cutoff` are
    /// no longer in the cloud and are kept as they were last seen.
    ///
    /// **Why the older days only fill in.** When a crew's window grew from
    /// three days to fourteen (2026-10-05), the cloud still held only three:
    /// written over from the new cutoff, days 4 to 14 would have read as
    /// empty and every crew's streak would have broken on the update. A
    /// phone new to the crew still fills all fourteen.
    mutating func record(_ wins: [SharedWin], from cutoff: String, rewritingFrom rewrite: String? = nil,
                         through today: String) {
        let rewrite = max(rewrite ?? cutoff, cutoff)
        let known = Set(days.keys)
        for day in days.keys where day >= rewrite && day <= today { days[day] = nil }
        for win in wins where win.crewDay >= cutoff && win.crewDay <= today {
            if win.crewDay < rewrite, known.contains(win.crewDay) { continue }
            days[win.crewDay, default: [:]][win.senderProfileID.uuidString, default: 0] += 1
        }
    }

    /// The days a refresh rewrites outright: today and the two before it,
    /// where a win is still likely to be withdrawn or arrive late.
    static func rewriteFrom(_ today: String, in zone: TimeZone) -> String? {
        CrewDay.day(today, offsetBy: -2, in: zone)
    }

    /// Every win the crew posted, by day: what the chart draws.
    var totals: [String: Int] {
        days.mapValues { $0.values.reduce(0, +) }
    }

    /// **The days the crew kept**: half the people in it that day posted a
    /// win, and never fewer than two (the unification pass, 2026-10-09:
    /// "a shared crew streak with forgiving freezes"). It was everyone, so
    /// one person's quiet day was the whole crew's loss, and the bigger the
    /// crew the less often a day ever counted. A crew of two still needs
    /// both; a crew of one, its one.
    ///
    /// "In it that day" is the people in the crew now who had joined by the
    /// end of that day: someone who joined on Thursday never broke Tuesday.
    /// Each join day is worked out once, not once per day per person.
    func keptDays(members: [CrewMember], zone: TimeZone) -> Set<String> {
        let joined = members.map { ($0.profileID.uuidString, CrewDay.string(for: $0.joinedAt, in: zone)) }
        var kept: Set<String> = []
        for (day, posted) in days {
            let expected = joined.filter { $0.1 <= day }
            guard !expected.isEmpty else { continue }
            let in_ = expected.filter { (posted[$0.0] ?? 0) > 0 }.count
            if in_ >= Self.needed(of: expected.count) { kept.insert(day) }
        }
        return kept
    }

    /// How many of `people` keep a day: half, rounded up, at least two.
    static func needed(of people: Int) -> Int {
        min(people, max(2, (people + 1) / 2))
    }

    /// Days in a row the crew kept, ending today, or yesterday while today
    /// is still open: a streak is not broken by a morning.
    ///
    /// Two rest days in any seven bridge it (`Streaks.Rest`): a crew needs
    /// everyone on the same day, and one person's bad day should never be the
    /// crew's loss.
    static func streak(_ full: Set<String>, today: String, zone: TimeZone) -> Int {
        Streaks.Rest.current(full, today: today, restsPerWeek: Streaks.Rest.crew)
    }

    /// The longest run there has been.
    static func best(_ full: Set<String>, zone: TimeZone) -> Int {
        Streaks.Rest.longest(full, restsPerWeek: Streaks.Rest.crew)
    }

    /// The people who have not posted yet today, in the order they joined.
    func waiting(today: String, members: [CrewMember]) -> [CrewMember] {
        let posted = days[today] ?? [:]
        return members.filter { (posted[$0.profileID.uuidString] ?? 0) == 0 }
    }
}
