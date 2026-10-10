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
/// the crew's own zone and writes the words. The sender deletes its own pings
/// ten minutes after sending them (`SocialStore.pingLifetime`, 600 seconds),
/// at its next refresh.
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

    /// `message`, `joined` and `milestone` came with the push pass
    /// (2026-10-10, the owner: "I think we should lean on push
    /// notifications"): a line in the crew's chat (a doodle and a photo
    /// strip are lines too), someone joining, and a streak milestone. The
    /// `win` field carries what each is about: the message's id, the
    /// joiner's profile id, the number of days.
    enum Kind: String { case win, reaction, message, joined, milestone }

    /// The kinds a crew's own subscription hears (`CrewPingPlan.crewID`).
    static let crewKinds: [Kind] = [.message, .joined, .milestone]

    /// A photo strip and a drawing thrown onto the tower travel as chat
    /// lines whose words are these markers (`CrewMessage.stripMarker`,
    /// `tossMarker`); the extension has to tell them from words.
    static let stripMarker = "\u{2063}\u{2063}"
    static let tossMarker = "\u{2063}\u{2064}"

    /// The streaks a crew is told about (`CrewStats.milestones` is this
    /// list). Here, where the extension can read it: a ping is a plain
    /// record anyone can write, and one claiming "99999 days" is not shown.
    static let milestones: Set<Int> = [7, 14, 21, 30, 50, 75, 100, 150, 200, 250, 300, 365]

    /// What a ping says when the extension cannot reach iCloud to say more.
    static let fallbackWin = "A friend added a win"
    static let fallbackReaction = "A friend reacted to your win"
    static let fallbackCrew = "Something new in your crew"
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

    /// **A line in the crew's chat**, as its push reads: the line itself
    /// ("Sam: morning all"), a doodle or a strip named. Always the newest
    /// line, and one notification a crew: the newer push takes the older
    /// one's place rather than stacking under it (`NotificationService`).
    /// (It counted them at first, "3 new in Roommates". The count was of
    /// pushes, and a phone sends one a minute however many lines are
    /// written, so the number was wrong. Found by review, 2026-10-10.)
    func chatWords(crew crewTag: String, sender: String, text: String?, hasPicture: Bool) -> (title: String, body: String) {
        let crew = crews[crewTag]
        let name = crew?.members[sender].flatMap { $0.name.isEmpty ? nil : $0.name } ?? "A friend"
        let heading = crew?.title ?? "Some Wins"
        let said = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if said == CrewPingRecord.stripMarker { return (heading, "\(name) shared a photo strip") }
        if said.isEmpty { return (heading, hasPicture ? "\(name) sent a doodle" : "\(name) wrote in the chat") }
        return (heading, "\(name): \(String(said.prefix(140)))")
    }

    /// **Someone joined**: by the name on their own member record when the
    /// extension could read it, since this phone has not met them yet.
    func joinedWords(crew crewTag: String, sender: String, name read: String?) -> (title: String, body: String) {
        let crew = crews[crewTag]
        let known = crew?.members[sender].flatMap { $0.name.isEmpty ? nil : $0.name }
        let name = (read ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let who = !name.isEmpty ? name : known
        return (crew?.title ?? "Some Wins", who.map { "\($0) joined." } ?? "Someone new joined.")
    }

    /// **A streak milestone**, in the words the crew's own page uses
    /// (`CrewStats.streakLine`): what the crew built, never what it risks.
    func milestoneWords(crew crewTag: String, days: String) -> (title: String, body: String)? {
        guard let n = Int(days), CrewPingRecord.milestones.contains(n), crews[crewTag] != nil else { return nil }
        return (crews[crewTag]?.title ?? "Some Wins", "Look what your crew is building. \(n) days.")
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
        case .message:
            return chatWords(crew: crewTag, sender: sender, text: line, hasPicture: false)
        case .joined:
            return joinedWords(crew: crewTag, sender: sender, name: nil)
        case .milestone:
            return milestoneWords(crew: crewTag, days: winID) ?? (heading, CrewPingRecord.fallbackCrew)
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

/// **A busy chat rings once** (2026-10-10, found by review). Each phone
/// pings a crew's chat at most once a minute, but eight people talking is
/// still several pushes a minute, each with a sound. The extension notes
/// here, in the app group, when it last rang for a crew's chat: a push that
/// follows within `gap` still replaces the banner with the newest line, and
/// arrives without the sound. Opening the chat starts it again.
nonisolated enum CrewChatPending {
    private static let key = "crews.chatRang"
    /// Five minutes: a conversation is one interruption.
    static let gap: TimeInterval = 300
    static var shared: UserDefaults? { UserDefaults(suiteName: CrewNoteCache.groupID) }

    /// A chat push arrived for `crew`. True when this one should ring.
    static func rings(crew: String, now: Date = Date(), defaults: UserDefaults? = CrewChatPending.shared) -> Bool {
        var rang = defaults?.dictionary(forKey: key) as? [String: Double] ?? [:]
        let last = rang[crew] ?? 0
        guard now.timeIntervalSince1970 - last >= gap else { return false }
        rang[crew] = now.timeIntervalSince1970
        defaults?.set(rang, forKey: key)
        return true
    }

    /// The chat was opened: the next line rings.
    static func opened(crew: String, defaults: UserDefaults? = CrewChatPending.shared) {
        guard var rang = defaults?.dictionary(forKey: key) as? [String: Double], rang[crew] != nil else { return }
        rang[crew] = nil
        defaults?.set(rang, forKey: key)
    }
}
