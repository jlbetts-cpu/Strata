import Foundation

/// **What two people share, on the page you talk to them on** (the owner,
/// 2026-10-17: "the profile is the relationship, so make it feel personal
/// ... what you share ... small moments from your history together. Keep it
/// calm and in our voice. Nothing that feels like a stats page or a score").
///
/// Cheers traded between you and things you both did the same day, from what
/// your shared crews still hold (two weeks), newest first, a few at most.
/// Words, never a tally. (b: Snapchat's friendship profile keeps shared
/// moments; Messages' details keep what was shared; neither counts.)
nonisolated enum BetweenYou {
    struct Moment: Identifiable, Equatable, Sendable {
        enum Kind: Equatable, Sendable { case youCheered, theyCheered, bothDid }
        let id: String
        let kind: Kind
        let words: String
        let date: Date
    }

    static let most = 4

    static func moments(me: UUID, friend: UUID, name: String,
                        wins: [SharedWin], reactions: [Reaction]) -> [Moment] {
        let byID = Dictionary(wins.map { ($0.winID, $0) }, uniquingKeysWith: { a, _ in a })
        var out: [Moment] = []
        var seen = Set<UUID>()
        for r in reactions.sorted(by: { $0.createdAt > $1.createdAt }) {
            guard let win = byID[r.winID], !seen.contains(win.winID) else { continue }
            let what = title(win)
            let mark = r.isSticker ? "" : " " + r.emoji
            if r.profileID == me, win.senderProfileID == friend {
                seen.insert(win.winID)
                out.append(Moment(id: "y-\(win.winID)", kind: .youCheered, words: "You cheered \(name)'s \(what)\(mark)", date: r.createdAt))
            } else if r.profileID == friend, win.senderProfileID == me {
                seen.insert(win.winID)
                out.append(Moment(id: "t-\(win.winID)", kind: .theyCheered, words: "\(name) cheered your \(what)\(mark)", date: r.createdAt))
            }
        }
        // The same thing, the same day: "You both went for a walk".
        let mine = wins.filter { $0.senderProfileID == me }
        let theirs = wins.filter { $0.senderProfileID == friend }
        var both = Set<String>()
        for a in mine {
            let key = normal(a.title)
            guard !key.isEmpty, !both.contains("\(a.crewDay)|\(key)") else { continue }
            if let b = theirs.first(where: { $0.crewDay == a.crewDay && normal($0.title) == key }) {
                both.insert("\(a.crewDay)|\(key)")
                out.append(Moment(id: "b-\(a.crewDay)-\(key)", kind: .bothDid,
                                  words: "You both did \(a.title.trimmingCharacters(in: .whitespacesAndNewlines))",
                                  date: max(a.createdAt, b.createdAt)))
            }
        }
        return Array(out.sorted { $0.date > $1.date }.prefix(most))
    }

    private static func title(_ win: SharedWin) -> String {
        let words = win.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return words.isEmpty ? (win.photo != nil ? "photo" : "win") : words
    }

    private static func normal(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
