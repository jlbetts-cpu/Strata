import Foundation

// MARK: - A drawing thrown onto a crew's tower

/// **One drawing a person a day, thrown onto a crew's tower** (the owner,
/// 2026-10-07: "the tower can kinda act like a bit of a shared canvas ... each
/// person in the group can throw in one drawing per day if they want to, it
/// disappears at midnight"; and, the same evening, "just keep it in the crew
/// chats that you made the doodle for ... like the crew tower").
///
/// **It travels as a chat doodle, marked.** A toss is a `CrewMessage` whose
/// `sketch` is the drawing and whose `text` is `tossMarker` and nothing else.
/// Not a new record type and not a new field: a field on a record type that
/// is already in production needs a schema deploy from the CloudKit console
/// before any phone can write it, and every existing phone would fail to
/// save until then. A marker in a field the schema already has costs
/// nothing, and the crew's day, the photo check both ways, blocking, the
/// writer's midnight delete (`SocialStore.prune`) and Report all come with
/// the message for free.
///
/// The marker is two invisible format characters (U+2063 INVISIBLE
/// SEPARATOR, U+2064 INVISIBLE PLUS). Nobody types them, `CrewWords` folds
/// them to nothing (so the filter passes them), and the record decoder's
/// whitespace trim does not touch them (they are category Cf, not Zs). A
/// build from before tosses reads one as a doodle with no visible words and
/// shows it in the chat, which is the honest fallback: it is still the
/// friend's drawing, in the crew it was made for.
///
/// **The chat never shows one** (`SocialStore.messages(in:)` leaves them
/// out, and with it the unread dot, the alerts and the line reactions, which
/// all read that list). The tower shows them (`SocialStore.tosses(in:)`).
extension CrewMessage {
    nonisolated static let tossMarker = "\u{2063}\u{2064}"

    /// A drawing thrown onto the tower, not a line in the chat.
    nonisolated var isToss: Bool { sketch != nil && text == Self.tossMarker }
}

nonisolated enum CrewTosses {
    /// **One a person a day**: each sender's first toss of the day, in the
    /// order they were thrown. A second from the same phone (a retry that
    /// raced, or a record written by anything else) is never shown.
    static func oneEach(_ messages: [CrewMessage]) -> [CrewMessage] {
        var seen: Set<UUID> = []
        return messages
            .filter(\.isToss)
            .sorted { ($0.createdAt, $0.messageID.uuidString) < ($1.createdAt, $1.messageID.uuidString) }
            .filter { seen.insert($0.senderProfileID).inserted }
    }
}

// MARK: - Tucked away, and already landed

/// **What this phone has done with today's drawings in one crew**: the ones
/// tucked into the bubble (the owner: "can be put back in the middle for
/// those that don't want it on their tower"), and the ones already seen
/// landing, so a relaunch places them rather than dropping them again.
///
/// Yours alone, like `CrewParking`: how the tower looks on your phone, kept
/// in `UserDefaults` per crew and never sent. **Per day**: both lists are
/// stored under the crew day they were made on and read back only for that
/// day, so midnight empties them without anything having to run at midnight.
nonisolated struct CrewTossShelf {
    let crewID: CrewID
    let defaults: UserDefaults

    init(crewID: CrewID, defaults: UserDefaults = .standard) {
        self.crewID = crewID
        self.defaults = defaults
    }

    private var tuckedKey: String { "crews.tossTucked.\(crewID.rawValue)" }
    private var landedKey: String { "crews.tossLanded.\(crewID.rawValue)" }

    /// The ids kept for `day`, in the order they were added. Another day's
    /// list reads as empty.
    private func read(_ key: String, on day: String) -> [UUID] {
        guard let stored = defaults.dictionary(forKey: key),
              stored["day"] as? String == day else { return [] }
        return (stored["ids"] as? [String] ?? []).compactMap(UUID.init(uuidString:))
    }

    private func write(_ ids: [UUID], _ key: String, on day: String) {
        defaults.set(["day": day, "ids": ids.map(\.uuidString)], forKey: key)
    }

    func tucked(on day: String) -> [UUID] { read(tuckedKey, on: day) }

    func tuck(_ id: UUID, on day: String) {
        var ids = tucked(on: day)
        guard !ids.contains(id) else { return }
        ids.append(id)
        write(ids, tuckedKey, on: day)
    }

    /// Back on the tower. It falls in again, from the top.
    func putBack(_ id: UUID, on day: String) {
        write(tucked(on: day).filter { $0 != id }, tuckedKey, on: day)
        write(landed(on: day).filter { $0 != id }, landedKey, on: day)
    }

    func landed(on day: String) -> [UUID] { read(landedKey, on: day) }

    func markLanded(_ id: UUID, on day: String) {
        var ids = landed(on: day)
        guard !ids.contains(id) else { return }
        ids.append(id)
        write(ids, landedKey, on: day)
    }
}
