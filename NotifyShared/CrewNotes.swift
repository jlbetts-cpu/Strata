import CryptoKit
import Foundation

/// **What the app and its notification extension agree on.** Compiled into
/// both; nothing here touches the app's models, so the extension stays small.

/// A ping: the nudge that makes a crew notification arrive even when Some
/// Wins was swiped away. When a win or a reaction is sent, the sender also
/// leaves one of these in iCloud's PUBLIC database, holding scrambled tags and
/// nothing else: no name, no title, no photo. Anyone with the app could list
/// public records, so the crew and the people are never there as themselves:
/// each is a one-way tag (`tag(_:)`) that only a phone already in the crew,
/// knowing the real ids, can match. Each phone has asked iCloud to
/// tell it about pings for its own crews, from anyone but itself and the
/// people it blocked, so every ping that reaches a phone is one it should
/// hear about. The extension then reads the real win, with permission, from
/// the crew's own zone and writes the words. The sender deletes a ping after
/// a day.
nonisolated enum CrewPingRecord {
    static let type = "Ping"
    /// The crew: the tag of its zone name.
    static let crew = "crew"
    /// Who sent it: the tag of their profile id.
    static let sender = "sender"
    /// Who it is for, when it is for one person: the tag of the owner of a
    /// reacted win.
    static let recipient = "recipient"
    /// "win" or "reaction".
    static let kind = "kind"
    /// The win it is about: its own random id, which names nothing else.
    static let win = "win"

    /// A crew's or a person's id, scrambled one way. Stable, so a subscription
    /// can match it; meaningless without the id it came from.
    static func tag(_ id: String) -> String {
        SHA256.hash(data: Data("somewins.ping.\(id)".utf8))
            .prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    static let fields = [crew, sender, recipient, kind, win]

    enum Kind: String { case win, reaction }

    /// What a ping says when the extension cannot reach iCloud to say more.
    static let fallbackWin = "A friend added a win"
    static let fallbackReaction = "A friend reacted to your win"
}

/// What the extension needs to put a ping into words: each crew's name, who
/// is in it, and the titles of your own wins, written by the app after every
/// refresh into the app group. Names only, never a photo.
nonisolated struct CrewNoteCache: Codable, Equatable {
    struct Member: Codable, Equatable {
        var profileID: String
        var name: String
    }

    struct Crew: Codable, Equatable {
        /// The crew as its notifications are titled.
        var title: String
        /// Where the crew's zone lives: its name, its owner as CloudKit names
        /// them, and whether you reach it through your shared database (a
        /// crew you joined) or your private one (a crew you started).
        var zoneName: String
        var zoneOwner: String
        var joined: Bool
        /// Each member by the tag a ping carries.
        var members: [String: Member]
        /// Your own wins in this crew, win id to title, for "Sam reacted to Gym".
        var myWins: [String: String]
    }

    var me: String
    /// Each crew by the tag a ping carries.
    var crews: [String: Crew]

    static let groupID = "group.JaydenBetts.Strata"
    static let containerID = "iCloud.JaydenBetts.Strata"

    static var url: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)?
            .appending(path: "crew-notes.json")
    }

    static func load(from url: URL? = CrewNoteCache.url) -> CrewNoteCache? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CrewNoteCache.self, from: data)
    }

    func save(to url: URL? = CrewNoteCache.url) {
        guard let url, let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    /// The words for a ping, from what is known. `title` is the win's title
    /// when the extension could read it; `emoji` the reaction's; `line` a
    /// reply's words; `tagsMe` whether the win names you among its people.
    ///
    /// The same sentences the app writes for itself (`CrewNotifications.Text`,
    /// 2026-10-05): a reply reads "Sam: so proud of you", and a win you were
    /// tagged in reads "Sam added you to Morning run".
    func words(kind: CrewPingRecord.Kind, crew crewTag: String, sender: String,
               winID: String, title: String?, emoji: String?,
               line: String? = nil, tagsMe: Bool = false) -> (title: String, body: String) {
        let crew = crews[crewTag]
        let name = crew?.members[sender].flatMap { $0.name.isEmpty ? nil : $0.name } ?? "A friend"
        let heading = crew?.title ?? "Some Wins"
        switch kind {
        case .win:
            let said = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if tagsMe {
                return (heading, said.isEmpty ? "\(name) added you to a win" : "\(name) added you to \(said)")
            }
            return (heading, said.isEmpty ? "\(name) added a win" : "\(name): \(said)")
        case .reaction:
            let words = (line ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !words.isEmpty { return (heading, "\(name): \(words)") }
            let mine = (crew?.myWins[winID] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let what = emoji.map { "reacted \($0)" } ?? "reacted"
            return (heading, mine.isEmpty ? "\(name) \(what) to your win"
                                          : "\(name) \(what) to \u{201C}\(mine)\u{201D}")
        }
    }
}
