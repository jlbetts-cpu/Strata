import Foundation

/// **Tonight's Story** (the spec, `docs/superpowers/specs/2026-10-15-stories-and-friends-design.md`,
/// sections 1 to 3; the plan, `docs/superpowers/plans/2026-10-15-tonights-story.md`).
///
/// A story is not new content: it is your tower's blocks, shown to friends at
/// night. One of today's wins, marked on Add a Win, opens to your friends at
/// 8pm by each friend's own clock and is gone by 9am. Friends, for now, are
/// the people you share a crew with, so a story is written into each of your
/// crews, sealed with that crew's key as every crew item is, and a friend in
/// two of them sees it once.
nonisolated struct CrewStory: Identifiable, Codable, Equatable, Sendable {
    /// The win as a crew copy would carry it, except `crewDay`: here that is
    /// the POSTER's date, the night the story belongs to, wherever the crew
    /// keeps its own clock.
    var win: SharedWin
    /// The hard end, sealed in: noon on the poster's next day. No phone shows
    /// a story past it, whatever its own clock says, and the poster's phone
    /// deletes it then.
    let endsAt: Date

    var id: UUID { win.winID }
    var sender: UUID { win.senderProfileID }
    var day: String { win.crewDay }
}

/// **When a story is seen** (decided by the owner, 2026-10-15: "8pm fixed,
/// gone by 9am"). Every rule here is in the VIEWER's zone, so a friend in
/// another zone sees it at their own 8pm, and an early sleeper still finds
/// it at breakfast.
nonisolated enum StoryClock {
    /// 8pm, the hour the stories open.
    static let opensHour = 20
    /// 9am the next morning, the hour they go.
    static let closesHour = 9

    enum Phase: Equatable, Sendable {
        /// Marked for tonight, before 8pm: an unlit ring, and no count.
        case waiting
        case open
        case gone
    }

    /// When a story of `day` may be seen by a viewer in `zone`: from 8pm on
    /// that date to 9am the next, or to its sealed end if that comes first.
    static func window(of day: String, endsAt: Date, in zone: TimeZone) -> Range<Date>? {
        guard let start = CrewDay.start(of: day, in: zone) else { return nil }
        let calendar = calendar(zone)
        guard let opens = calendar.date(bySettingHour: opensHour, minute: 0, second: 0, of: start),
              let next = calendar.date(byAdding: .day, value: 1, to: start),
              let closes = calendar.date(bySettingHour: closesHour, minute: 0, second: 0, of: next) else { return nil }
        let end = min(closes, endsAt)
        return opens < end ? opens..<end : nil
    }

    static func phase(of story: CrewStory, at now: Date, in zone: TimeZone) -> Phase {
        guard now < story.endsAt, let window = window(of: story.day, endsAt: story.endsAt, in: zone) else { return .gone }
        if window.contains(now) { return .open }
        // Waiting means tonight: a story dated days ahead (a clock gone
        // wrong) never lights a ring for a night that is not coming.
        return now < window.lowerBound && window.lowerBound.timeIntervalSince(now) <= 86_400 ? .waiting : .gone
    }

    /// The sealed end the poster's phone writes: noon on the day after
    /// `day`, in the poster's zone, so the 9am close has three hours of
    /// slack for a friend a zone or two to the west.
    static func endsAt(of day: String, in zone: TimeZone) -> Date? {
        guard let start = CrewDay.start(of: day, in: zone),
              let next = calendar(zone).date(byAdding: .day, value: 1, to: start) else { return nil }
        return calendar(zone).date(bySettingHour: 12, minute: 0, second: 0, of: next)
    }

    /// Whether a win made at `createdAt` can still go on a story at `now`:
    /// only today's wins, until midnight.
    static func canPost(winMadeAt createdAt: Date, at now: Date, in zone: TimeZone) -> Bool {
        CrewDay.string(for: createdAt, in: zone) == CrewDay.string(for: now, in: zone)
    }

    /// The clock the story rules read. `-strataStoryHour 21` in a debug build
    /// moves today to that hour, so the row and the viewer can be seen at
    /// night in the middle of the afternoon.
    static func now(_ real: Date = Date(), in zone: TimeZone = .current) -> Date {
        #if DEBUG
        if let hour = DebugHarness.argument("-strataStoryHour").flatMap(Int.init), (0..<24).contains(hour) {
            return calendar(zone).date(bySettingHour: hour, minute: 30, second: 0, of: real) ?? real
        }
        #endif
        return real
    }

    private static func calendar(_ zone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }
}

/// **One friend in tonight's row**: their stories, each once whichever
/// crew it came from, oldest first, as the viewer pages them.
nonisolated struct StoryPerson: Identifiable, Equatable, Sendable {
    let profileID: UUID
    /// The crew each story was read from: where a reaction to it is written.
    let stories: [CrewStory]
    let phase: StoryClock.Phase
    /// Every story of theirs already watched to its end.
    let watched: Bool

    var id: UUID { profileID }
    var newest: Date { stories.map(\.win.createdAt).max() ?? .distantPast }
    /// The first photograph, the picture the head becomes at 8pm.
    var cover: CrewStory? { stories.first { $0.win.photo != nil } ?? stories.first }

    /// Friends' stories, gathered from every crew: each story once (a friend
    /// in two crews wrote it to both), only the ones that are waiting or
    /// open, never anyone blocked or hidden for that night, and never you.
    ///
    /// **The order the owner chose** (the spec, 1.4): open and unwatched
    /// first, newest first; then open and watched; then waiting.
    static func gather(_ storiesByCrew: [CrewID: [CrewStory]], crewOrder: [CrewID], me: UUID,
                       blocked: Set<UUID>, hidden: [UUID: String], seen: Set<UUID>,
                       now: Date, zone: TimeZone) -> [StoryPerson] {
        var byPerson: [UUID: [UUID: CrewStory]] = [:]
        for crewID in crewOrder {
            for story in storiesByCrew[crewID] ?? [] where story.sender != me
                && !blocked.contains(story.sender) && hidden[story.sender] != story.day {
                guard StoryClock.phase(of: story, at: now, in: zone) != .gone else { continue }
                // The first crew in the list keeps it: the same copy every
                // time, so a reaction always goes to the same place.
                if byPerson[story.sender]?[story.id] == nil { byPerson[story.sender, default: [:]][story.id] = story }
            }
        }
        let people = byPerson.map { sender, stories -> StoryPerson in
            let ordered = stories.values.sorted { ($0.win.createdAt, $0.id.uuidString) < ($1.win.createdAt, $1.id.uuidString) }
            let open = ordered.contains { StoryClock.phase(of: $0, at: now, in: zone) == .open }
            // Before 8pm nothing is shown, so nothing can be watched yet.
            let shown = open ? ordered.filter { StoryClock.phase(of: $0, at: now, in: zone) == .open } : ordered
            return StoryPerson(profileID: sender, stories: shown, phase: open ? .open : .waiting,
                               watched: open && shown.allSatisfy { seen.contains($0.id) })
        }
        return people.sorted { a, b in
            let rank: (StoryPerson) -> Int = { $0.phase == .open ? ($0.watched ? 1 : 0) : 2 }
            if rank(a) != rank(b) { return rank(a) < rank(b) }
            if a.newest != b.newest { return a.newest > b.newest }
            return a.profileID.uuidString < b.profileID.uuidString
        }
    }
}
