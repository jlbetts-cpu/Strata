import Foundation

// MARK: - Crews
//
// A crew is up to eight people, you included, who share a tower for the day.
// Everything in this folder lives BESIDE SwiftData, never inside it: a
// friend's win is never a `Habit` or a `HabitLog`, so it can never reach your
// own tower, your streaks, Memories, Replays, the widget or a backup. See
// `docs/superpowers/specs/2026-10-02-crews-design.md`.

/// A crew's identity, which is also the name of its CloudKit zone.
nonisolated struct CrewID: Hashable, Codable, Sendable, Identifiable {
    let rawValue: String
    var id: String { rawValue }

    init(rawValue: String) { self.rawValue = rawValue }

    /// A fresh one. The prefix keeps a crew zone recognisable among any other
    /// zone the container ever holds.
    static func new() -> CrewID { CrewID(rawValue: "crew-" + UUID().uuidString) }
}

/// The two numbers the owner chose (2026-10-02): eight people a crew, you
/// included, and five crews a person. Enforced in `SocialStore`, at the point
/// an invitation is made and again where one is accepted, never in a view.
nonisolated enum CrewCaps {
    static let members = 8
    static let crews = 5
    /// The people one win can be "with" (shared wins, the owner,
    /// 2026-10-05: "pick up to 3"). Held in `SocialStore` where a win is
    /// sent, and again in `CrewRecords` where one is read, so a record that
    /// claims ten people still asks no more than three.
    static let withPeople = 3
}

nonisolated enum CrewError: LocalizedError, Equatable, Sendable {
    /// You are already in five crews.
    case tooManyCrews
    /// The crew already has eight people.
    case crewFull
    /// Crews are switched off. Nothing may touch the network.
    case flagOff
    /// Only the person who started the crew may do this.
    case notOwner
    /// No iCloud account on this phone.
    case notSignedIn
    /// The crew is not one this phone knows.
    case unknownCrew
    /// A photograph that may not be sent: under 16, or held back by the check.
    case photoNotAllowed
    /// A crew starts with a photo (the owner, 2026-10-02), except for 13 to 15.
    case photoNeeded
    /// **Not yet, on this phone** (2026-10-08): the rules, the age, or iOS
    /// 26 still stand in the way (`CrewGate`). Joining or starting a crew
    /// waits for them; nothing is written to any crew first.
    case notReady

    var errorDescription: String? {
        switch self {
        case .tooManyCrews: "You're in five crews already."
        case .crewFull: "That crew already has eight people."
        case .flagOff: "Crews are off on this phone."
        case .notOwner: "Only the person who started the crew can do that."
        case .notSignedIn: "Sign in to iCloud in Settings to use crews."
        case .unknownCrew: "This phone can't find that crew right now. Try again in a moment."
        case .photoNotAllowed: "That photo stays with you."
        case .photoNeeded: "Choose a photo for the crew first."
        case .notReady: "Crews open once the crew rules and your age are set."
        }
    }
}

nonisolated struct CrewMember: Identifiable, Codable, Equatable, Sendable {
    /// `ProfileStore.profileID` on their phone. The iCloud account is mapped
    /// TO this, never the other way round.
    let profileID: UUID
    /// What they typed into Profile. Nothing is ever read from your contacts.
    var firstName: String
    /// Their compact head (`CrewHeadPack`), cached on this phone, if they
    /// have one.
    var head: URL?
    var joinedAt: Date
    /// Their profile photograph, for someone with no head: drawn filling the
    /// same circle a head sits in, so the two read as one set (the owner,
    /// 2026-10-02, "everyone in a circle"). Never sent under 16.
    var photo: URL? = nil

    var id: UUID { profileID }

    /// The first word of what they called themselves, or nothing.
    var shortName: String {
        firstName.split(separator: " ").first.map(String.init) ?? ""
    }

    /// "S" for Sam: the circle a member with no head is drawn as.
    var initial: String {
        shortName.first.map { String($0).uppercased() } ?? ""
    }
}

nonisolated struct Crew: Identifiable, Codable, Equatable, Sendable {
    let id: CrewID
    var name: String
    /// Who started it. Only they remove people or end the crew.
    let ownerProfileID: UUID
    /// The creator's zone: the crew day closes at THEIR midnight.
    let timeZoneIdentifier: String
    let createdAt: Date
    /// The crew's picture, cached on this phone. Nil draws the members' faces.
    var photo: URL?
    var members: [CrewMember]

    var timeZone: TimeZone { TimeZone(identifier: timeZoneIdentifier) ?? .current }

    func isOwner(_ profileID: UUID) -> Bool { ownerProfileID == profileID }

    func member(_ profileID: UUID) -> CrewMember? {
        members.first { $0.profileID == profileID }
    }

    /// Everyone but you, in the order they joined.
    func others(than me: UUID) -> [CrewMember] {
        members.filter { $0.profileID != me }.sorted { $0.joinedAt < $1.joinedAt }
    }

    /// The crew's name, or, unnamed, its people as Messages names a group:
    /// "Sam", "Sam & Ana", "Sam, Ana & Leo", "Sam, Ana & 3 more".
    func displayName(excluding me: UUID) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let names = others(than: me).map(\.shortName).filter { !$0.isEmpty }
        switch names.count {
        case 0: return "New Crew"
        case 1: return names[0]
        case 2: return "\(names[0]) & \(names[1])"
        case 3: return "\(names[0]), \(names[1]) & \(names[2])"
        default: return "\(names[0]), \(names[1]) & \(names.count - 2) more"
        }
    }
}

/// One win, as a crew sees it. One of these per win per crew it was posted to.
///
/// Its fields are the whole of what crosses to a friend. `CrewRecords` turns it
/// into a record, and `CrewRecordTests` fails the day anything is added.
nonisolated struct SharedWin: Identifiable, Codable, Equatable, Sendable {
    /// `HabitLog.id`, so an edit or a withdrawal finds every copy.
    let winID: UUID
    let crewID: CrewID
    let senderProfileID: UUID
    /// The crew's day, `yyyy-MM-dd`, in the crew's zone.
    var crewDay: String
    /// Empty stays empty: an unnamed win shows no text.
    var title: String
    /// `displayCategory`: the colour.
    var colour: HabitCategory
    /// `category`: `.unlabeled` means no icon.
    var icon: HabitCategory
    var blockSize: BlockSize
    /// A `ShareDerivative`, cached on this phone.
    var photo: URL?
    var cropX: Double?
    var cropY: Double?
    let createdAt: Date
    var updatedAt: Date
    /// **Who it was with**: up to three people in THIS crew, by profile id
    /// (shared wins, spec 1). Each of them is asked once whether to keep a
    /// copy. Never a name and never a contact: a phone draws the names from
    /// the crew's own Member records, so someone removed from the crew drops
    /// out of every tag with nothing to rewrite.
    var withPeople: [UUID] = []

    var id: UUID { winID }
}

/// Your own win, as `SocialStore` is handed it. Built from a `HabitLog` by the
/// caller, so nothing in this folder imports SwiftData.
nonisolated struct OwnWin: Sendable, Equatable {
    let winID: UUID
    var title: String
    var colour: HabitCategory
    var icon: HabitCategory
    var blockSize: BlockSize
    /// The photograph as it is on disk. `ShareDerivative` makes what is sent.
    var photoJPEG: Data?
    /// Which photograph that is (its file name): how an edit that changed
    /// nothing is told from one that changed the photo, without comparing
    /// bytes.
    var photoKey: String? = nil
    var cropX: Double?
    var cropY: Double?
    let createdAt: Date
    var updatedAt: Date
    /// The people chosen on Add Win's With row. Each crew is sent only the
    /// ones who are in it (`SocialStore.sharedWin`).
    var withPeople: [UUID] = []
}

/// **One line in a crew's day chat** (the owner, 2026-10-05).
///
/// Text and emoji, up to `textLimit` characters, or a doodle (`sketch`, a
/// PNG on this phone carried as an asset). It can quote a win
/// (`quoteWinID`): that is what Reply and Doodle on a win post now, in place
/// of a line on a reaction only the win's owner saw.
///
/// **It lives for the crew's day.** `crewDay` is the crew's `yyyy-MM-dd`,
/// in the crew's zone; no phone shows a message from another day
/// (`SocialStore.messages(in:)`), and each phone deletes its own when the
/// day ends (`SocialStore.prune`). No read receipts: nothing in it says who
/// has opened it.
nonisolated struct CrewMessage: Identifiable, Codable, Equatable, Sendable {
    let messageID: UUID
    let crewID: CrewID
    let senderProfileID: UUID
    let crewDay: String
    /// Empty for a doodle with no words. Never longer than `textLimit`.
    var text: String
    /// The win a reply or a doodle answers, shown as a small quoted line.
    var quoteWinID: UUID? = nil
    /// A doodle, cached on this phone.
    var sketch: URL? = nil
    let createdAt: Date

    var id: UUID { messageID }

    /// A line, not a letter: the owner's 280.
    static let textLimit = 280
}

/// One person's reaction to one win, in one crew. Or to one line of the
/// crew's chat, under the same record (`Reaction.Pick`, 2026-10-06).
///
/// **One per person per win**, like a Tapback: reacting again with another
/// emoji replaces it, and with the same one takes it back. Added at the
/// owner's word (2026-10-02), reversing the brief's "no likes": a crew should
/// be able to say "nice" without a feed or a comment thread.
nonisolated struct Reaction: Identifiable, Codable, Equatable, Sendable {
    let winID: UUID
    let crewID: CrewID
    let profileID: UUID
    var emoji: String
    var createdAt: Date
    /// **A reply, the old way.** Until 2026-10-05 a reply was a short line
    /// on the reaction, seen only by the win's owner. Replies post into the
    /// crew's chat now (`CrewMessage.quoteWinID`), so nothing writes this any
    /// more and nothing shows it. It is still READ, so a record from an older
    /// build decodes, and the writer's phone still clears its own at the end
    /// of the day (`SocialStore.prune`).
    var line: String? = nil
    /// **A doodle, the old way**: the same story as `line`. Doodles are chat
    /// messages now (`CrewMessage.sketch`); an old one is read harmlessly,
    /// never shown, and cleared by its writer's phone at the end of the day.
    var sketch: URL? = nil

    var id: String { Self.name(winID: winID, profileID: profileID) }

    /// The longest a reply can be: a line, not a message.
    static let lineLimit = 80

    static func name(winID: UUID, profileID: UUID) -> String {
        "\(winID.uuidString)-\(profileID.uuidString)"
    }

    /// The quick ones, in the Figma bar's order (Apollo, node 12839:5135).
    static let quick = ["🔥", "👑", "❤️"]
    /// Behind the bar's "+": a short, warm set, not the whole keyboard.
    static let more = ["👏", "💪", "🙌", "😂", "😮", "🥹", "🎉", "⚡️", "🌱", "🏆", "✨", "🫡"]
    /// What a double-tap on a block sends.
    static let doubleTap = "❤️"
}

// MARK: - Reactions to a chat line

/// **A reaction to a line in the crew's chat, with an emoji or one of your
/// stickers** (the owner, 2026-10-06: "make it so you can react to chat
/// messages with stickers and emojis").
///
/// **No new record and no new field.** It is a `Reaction` record whose
/// `winID` holds the line's `messageID`: both are UUIDs, so one is never the
/// other, and every place that reads a win's reactions already asks for that
/// win's id and so never meets a line's (`SocialStore.reactions(to:in:)`,
/// the alerts, the badge, the first-win invite). The CloudKit schema the
/// owner deployed stays exactly as it is.
///
/// One per person per line, as a win's is: a new pick replaces yours, the
/// same one again takes it back.
extension Reaction {
    /// **A sticker's mark**, the journal's own spelling of one
    /// (`StickerStore.symbol`, "sticker:<file>"), so a sticker is told from
    /// an emoji the same way on a day and on a line. The picture itself
    /// travels in `sketch`, the asset field an old doodle used, made small
    /// first (`stickerSide`): a sticker lives only on the phone that made
    /// it, and a friend's phone draws the copy that came with the reaction.
    static let stickerPrefix = "sticker:"
    /// The longest edge a sticker is sent at, in pixels: crisp at the 22pt a
    /// chip draws it, and a few kilobytes on the wire.
    static let stickerSide = 256

    /// What was picked on a line's bar.
    enum Pick: Equatable, Sendable {
        case emoji(String)
        /// One of your stickers, by its file name, and its picture.
        case sticker(name: String, png: Data)

        /// The reaction's `emoji` field for it.
        var mark: String {
            switch self {
            case .emoji(let emoji): String(emoji.prefix(1))
            case .sticker(let name, _): Reaction.stickerPrefix + name
            }
        }
    }

    /// The sticker's file name, if this reaction is a sticker.
    var stickerName: String? { Self.stickerName(in: emoji) }
    var isSticker: Bool { stickerName != nil }

    /// The name in a sticker's mark, and only a plain file name: a record
    /// can claim anything, and this is shown and compared, never opened.
    static func stickerName(in mark: String) -> String? {
        guard mark.hasPrefix(stickerPrefix) else { return nil }
        let name = String(mark.dropFirst(stickerPrefix.count))
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        guard (1...64).contains(name.count),
              name.unicodeScalars.allSatisfy({ $0.isASCII && allowed.contains($0) }) else { return nil }
        return name
    }
}
