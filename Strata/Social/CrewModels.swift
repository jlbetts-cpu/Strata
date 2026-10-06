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

    var errorDescription: String? {
        switch self {
        case .tooManyCrews: "You're in five crews already."
        case .crewFull: "That crew already has eight people."
        case .flagOff: "Crews are off on this phone."
        case .notOwner: "Only the person who started the crew can do that."
        case .notSignedIn: "Sign in to iCloud in Settings to use crews."
        case .unknownCrew: "This phone lost track of that crew. Try again in a moment."
        case .photoNotAllowed: "That photo stays with you."
        case .photoNeeded: "Choose a photo for the crew first."
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

/// One person's reaction to one win, in one crew.
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
    /// **A reply**: a short line with the emoji, shown only to whoever posted
    /// the win (and to you), and only on the crew day it was written
    /// (`SocialStore.replies`). Nil for a plain reaction.
    var line: String? = nil
    /// **A doodle**: a one-pen drawing on this phone (`InkCanvas`), a PNG of
    /// at most 1080px, carried on the record's `sketch` asset. Seen like a
    /// reply's line: by whoever posted the win and by its writer, only on the
    /// crew day it was drawn (`SocialStore.doodles`), and cleared by the
    /// writer's phone when that day ends (`SocialStore.prune`).
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
