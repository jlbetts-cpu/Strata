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

        // Reactions to yours: one line a win, across crews.
        var byWin: [UUID: [(Reaction, CrewID)]] = [:]
        for crew in crews {
            for reaction in reactions[crew.id] ?? [] where mine[reaction.winID] != nil
                && reaction.profileID != me && !blocked.contains(reaction.profileID) && reaction.createdAt >= since {
                byWin[reaction.winID, default: []].append((reaction, crew.id))
            }
        }
        for (winID, list) in byWin {
            let newest = list.sorted { $0.0.createdAt > $1.0.createdAt }
            var emoji: [String] = []
            for (r, _) in newest where !emoji.contains(r.emoji) && !r.isSticker { emoji.append(r.emoji) }
            let marks = emoji.prefix(3).joined()
            items.append(ActivityItem(id: "r-\(winID)", kind: .reacted, crewID: newest[0].1,
                                      people: unique(newest.map(\.0.profileID)), date: newest[0].0.createdAt,
                                      words: "reacted\(marks.isEmpty ? "" : " " + marks) to \(mine[winID] ?? "your win")",
                                      winID: winID))
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
            // Someone new in a crew of yours.
            for member in crew.members where member.profileID != me && !blocked.contains(member.profileID)
                && member.joinedAt >= since && member.joinedAt > crew.createdAt.addingTimeInterval(60) {
                items.append(ActivityItem(id: "j-\(crew.id.rawValue)-\(member.profileID)", kind: .joined, crewID: crew.id,
                                          people: [member.profileID], date: member.joinedAt,
                                          words: "joined \(crew.displayName(excluding: me))", winID: nil))
            }
        }
        return items.sorted { $0.date > $1.date }
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

    /// "Sam", "Sam and Ana", "Sam, Ana and Leo", "Sam, Ana and others".
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
        default: return "\(all[0]), \(all[1]) and others"
        }
    }
}
