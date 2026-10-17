import Foundation

/// **What is waiting on you, socially, in one place** (the owner's add-on to
/// the launch pass: "the Crews top-left corner becomes your notifications ...
/// one calm place for everything waiting on you socially: friend requests,
/// crew invites, someone reacting to or replying to your win, a friend doing
/// a plan you share, a new person joining your crew").
///
/// Built from what this phone already holds, nothing new in iCloud: newest
/// first, grouped so a busy crew never floods it (every reaction on one win
/// is one line), each one a tap from where it happened. No counts anywhere:
/// "Sam and Ana reacted", never "12 reactions".
nonisolated struct ActivityItem: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable { case reacted, replied, message, joined, planned }
    let id: String
    let kind: Kind
    let crewID: CrewID
    /// Who, newest first.
    let people: [UUID]
    let date: Date
    /// What they did, after their names: "reacted ❤️ to Walk".
    let words: String
    /// The win it is about, to open it there.
    let winID: UUID?
    /// **What it gathers, one each, for a tap to open out** (the owner,
    /// 2026-10-17: "collapse them into one row ... Tap to expand and see each
    /// one"). Empty for a row that is one thing.
    var children: [ActivityItem] = []
}

nonisolated enum ActivityFeed {
    /// How far back it looks: a week, inside the two the cloud keeps.
    static let days: TimeInterval = 7 * 86_400

    static func gather(crews: [Crew], wins: [CrewID: [SharedWin]], messages: [CrewID: [CrewMessage]],
                       reactions: [CrewID: [Reaction]], stories: [CrewID: [CrewStory]],
                       me: UUID, blocked: Set<UUID>, now: Date) -> [ActivityItem] {
        let since = now.addingTimeInterval(-days)
        // Your wins and stories, by id, with the words that name them.
        var mine: [UUID: String] = [:]
        for list in wins.values { for win in list where win.senderProfileID == me { mine[win.winID] = title(win) } }
        for list in stories.values { for story in list where story.sender == me && mine[story.id] == nil {
            mine[story.id] = title(story.win)
        } }
        var items: [ActivityItem] = []

        // **Reactions to yours: one line a win a day, across crews** (the
        // owner, 2026-10-17: "grouped within a sensible window of time so old
        // and new don't merge"). The window is the day, which is how the sheet
        // already reads (Today, Yesterday, Earlier) and how Instagram groups
        // likes on one post; each person's reaction is a child to open out.
        func day(_ date: Date) -> String { DateUtils.dateString(from: date) }
        var byWin: [String: [(Reaction, CrewID)]] = [:]
        for crew in crews {
            for reaction in reactions[crew.id] ?? [] where mine[reaction.winID] != nil
                && reaction.profileID != me && !blocked.contains(reaction.profileID) && reaction.createdAt >= since {
                byWin["\(reaction.winID)|\(day(reaction.createdAt))", default: []].append((reaction, crew.id))
            }
        }
        for (key, list) in byWin {
            let newest = list.sorted { $0.0.createdAt > $1.0.createdAt }
            let winID = newest[0].0.winID
            var emoji: [String] = []
            for (r, _) in newest where !emoji.contains(r.emoji) && !r.isSticker { emoji.append(r.emoji) }
            let marks = emoji.prefix(3).joined()
            let what = mine[winID] ?? "your win"
            let one = newest.map { r, crew in
                ActivityItem(id: "r1-\(r.winID)-\(r.profileID)-\(r.createdAt.timeIntervalSince1970)", kind: .reacted,
                             crewID: crew, people: [r.profileID], date: r.createdAt,
                             words: "reacted\(r.isSticker ? "" : " " + r.emoji) to \(what)", winID: r.winID)
            }
            let people = unique(newest.map(\.0.profileID))
            items.append(ActivityItem(id: "r-\(key)", kind: .reacted, crewID: newest[0].1,
                                      people: people, date: newest[0].0.createdAt,
                                      words: "reacted\(marks.isEmpty ? "" : " " + marks) to \(what)",
                                      winID: winID, children: people.count > 1 ? one : []))
        }

        for crew in crews {
            let lines = (messages[crew.id] ?? []).filter {
                $0.senderProfileID != me && !blocked.contains($0.senderProfileID) && $0.createdAt >= since && !$0.isToss
            }
            if crew.isPersonal {
                // A conversation: its newest line from them.
                if let last = lines.max(by: { $0.createdAt < $1.createdAt }) {
                    items.append(ActivityItem(id: "m-\(crew.id.rawValue)", kind: .message, crewID: crew.id,
                                              people: [last.senderProfileID], date: last.createdAt,
                                              words: "sent you \(said(last))", winID: nil))
                }
                continue
            }
            // Replies to yours, one line a win.
            let replies = Dictionary(grouping: lines.filter { $0.quoteWinID.map { mine[$0] != nil } ?? false }, by: { $0.quoteWinID! })
            for (winID, list) in replies {
                let newest = list.sorted { $0.createdAt > $1.createdAt }
                let words = newest[0].text.trimmingCharacters(in: .whitespacesAndNewlines)
                items.append(ActivityItem(id: "q-\(crew.id.rawValue)-\(winID)", kind: .replied, crewID: crew.id,
                                          people: unique(newest.map(\.senderProfileID)), date: newest[0].createdAt,
                                          words: "replied to \(mine[winID] ?? "your win")" + (words.isEmpty ? "" : ": \(words)"),
                                          winID: winID))
            }
            // Plans someone made in a crew of yours.
            for line in lines {
                guard let plan = line.groupPlan else { continue }
                items.append(ActivityItem(id: "p-\(line.messageID)", kind: .planned, crewID: crew.id,
                                          people: [line.senderProfileID], date: line.createdAt,
                                          words: "planned \(plan.title) in \(crew.displayName(excluding: me))", winID: nil))
            }
            // Someone new in a crew of yours: everyone who joined it that
            // day on one line.
            let joiners = crew.members.filter { member in
                member.profileID != me && !blocked.contains(member.profileID)
                    && member.joinedAt >= since && member.joinedAt > crew.createdAt.addingTimeInterval(60)
            }
            for (joinDay, group) in Dictionary(grouping: joiners, by: { day($0.joinedAt) }) {
                let newest = group.sorted { $0.joinedAt > $1.joinedAt }
                let crewName = crew.displayName(excluding: me)
                let one = newest.map { member in
                    ActivityItem(id: "j-\(crew.id.rawValue)-\(member.profileID)", kind: .joined, crewID: crew.id,
                                 people: [member.profileID], date: member.joinedAt, words: "joined \(crewName)", winID: nil)
                }
                items.append(ActivityItem(id: "j-\(crew.id.rawValue)-\(joinDay)", kind: .joined, crewID: crew.id,
                                          people: newest.map(\.profileID), date: newest[0].joinedAt,
                                          words: "joined \(crewName)", winID: nil,
                                          children: newest.count > 1 ? one : []))
            }
        }
        return byPerson(items).sorted { $0.date > $1.date }
    }

    /// **One person, several of your wins, one day: one line** ("Ana reacted
    /// to 3 of your wins"), as Instagram folds one person's likes. Only rows
    /// that are that person alone are folded; a row several people share
    /// keeps its own line.
    static func byPerson(_ items: [ActivityItem]) -> [ActivityItem] {
        var keep: [ActivityItem] = []
        var solo: [String: [ActivityItem]] = [:]
        for item in items {
            if item.kind == .reacted, item.people.count == 1, item.winID != nil {
                solo["\(item.people[0])|\(DateUtils.dateString(from: item.date))", default: []].append(item)
            } else {
                keep.append(item)
            }
        }
        for (key, group) in solo {
            guard group.count > 1 else { keep.append(contentsOf: group); continue }
            let newest = group.sorted { $0.date > $1.date }
            keep.append(ActivityItem(id: "rp-\(key)", kind: .reacted, crewID: newest[0].crewID, people: newest[0].people,
                                     date: newest[0].date, words: "reacted to \(group.count) of your wins",
                                     winID: nil, children: newest))
        }
        return keep
    }

    private static func title(_ win: SharedWin) -> String {
        let words = win.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !words.isEmpty { return words }
        return win.photo != nil ? "your photo" : "your win"
    }

    private static func said(_ line: CrewMessage) -> String {
        if line.isStrip { return "a strip" }
        if line.isSticker { return "a sticker" }
        if line.isPicture { return "a photo" }
        if line.sketch != nil { return "a doodle" }
        let words = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return words.isEmpty ? "a message" : "a message: \(words)"
    }

    private static func unique(_ ids: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        return ids.filter { seen.insert($0).inserted }
    }
}

@MainActor
extension SocialStore {
    private static let activitySeenKey = "crews.activitySeen"

    /// Everything waiting on you (`ActivityFeed`).
    func activityFeed() -> [ActivityItem] {
        ActivityFeed.gather(crews: crews.compactMap { visible($0.id) }, wins: winsByCrew, messages: messagesByCrew,
                            reactions: reactionsByCrew, stories: storiesByCrew,
                            me: me, blocked: blocked, now: now())
    }

    /// Something there since you last looked: the corner's quiet dot.
    var hasNewActivity: Bool {
        _ = activityRevision
        let seen = defaults.double(forKey: Self.activitySeenKey)
        // Read here, so a change to any of them still redraws the dot.
        let key = [crews.count, blocked.count,
                   winsByCrew.values.reduce(0) { $0 + $1.count },
                   messagesByCrew.values.reduce(0) { $0 + $1.count },
                   reactionsByCrew.values.reduce(0) { $0 + $1.count },
                   storiesByCrew.values.reduce(0) { $0 + $1.count }]
        if let cached = activityNewest, cached.key == key { return cached.newest > seen }
        let newest = activityFeed().first?.date.timeIntervalSince1970 ?? 0
        activityNewest = (key, newest)
        return newest > seen
    }

    func markActivitySeen() {
        defaults.set(now().timeIntervalSince1970, forKey: Self.activitySeenKey)
        activityRevision &+= 1
    }

    /// **Who in a crew did a shared plan today** (the add-on: "see when a
    /// friend checks their part off"): crew-mates whose win today, on the
    /// crew's own day, has the plan's words. Read from what the crew already
    /// holds; joining a plan is never sent, so this is what can be known.
    func didToday(_ title: String, in crewID: CrewID) -> [UUID] {
        guard let crew = crew(crewID) else { return [] }
        let words = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !words.isEmpty else { return [] }
        let today = CrewDay.string(for: now(), in: crew.timeZone)
        var seen = Set<UUID>()
        return wins(in: crewID, on: today)
            .filter { $0.senderProfileID != me && !blocked.contains($0.senderProfileID)
                && $0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == words }
            .map(\.senderProfileID)
            .filter { seen.insert($0).inserted }
    }

    /// "Sam", "Sam and Ana", "Sam, Ana and Leo", "Kai, Leo and 2 others"
    /// (the owner's own wording for a grouped row, 2026-10-17).
    func names(_ people: [UUID], in crew: CrewID) -> String {
        let all = people.map { id -> String in
            let short = crews.lazy.compactMap { $0.member(id) }.first?.shortName ?? ""
            return short.isEmpty ? "A friend" : short
        }
        switch all.count {
        case 0: return "Someone"
        case 1: return all[0]
        case 2: return "\(all[0]) and \(all[1])"
        case 3: return "\(all[0]), \(all[1]) and \(all[2])"
        default: return "\(all[0]), \(all[1]) and \(all.count - 2) others"
        }
    }
}
