import Foundation

/// A value in a crew record, typed the way CloudKit stores it. `uuid` is
/// written as a string; `asset` is a file on this phone that becomes a
/// `CKAsset`.
nonisolated enum CrewValue: Equatable, Codable, Sendable {
    case string(String)
    case date(Date)
    case double(Double)
    case int(Int)
    case uuid(UUID)
    case asset(URL)

    var string: String? { if case .string(let v) = self { v } else { nil } }
    var date: Date? { if case .date(let v) = self { v } else { nil } }
    var double: Double? { if case .double(let v) = self { v } else { nil } }
    var int: Int? { if case .int(let v) = self { v } else { nil } }
    var uuid: UUID? {
        switch self {
        case .uuid(let v): v
        case .string(let v): UUID(uuidString: v)
        default: nil
        }
    }
    /// The file, wherever this install keeps it (`CrewFiles.here`).
    var asset: URL? { if case .asset(let v) = self { CrewFiles.here(v) } else { nil } }
}

/// **A saved file path, moved to where this install lives.**
///
/// iOS can move an app's data container when the app updates: the folder
/// named by a long id in the middle of every path changes. Crews kept each
/// photograph and head as a full path, so after an update every one pointed
/// into a folder that was gone, and a crew's photos vanished with each build
/// and never came back, since a sync only fetches what changed (the owner,
/// 2026-10-03: "the photos are still not showing over updates"). Measured on
/// the simulator: one install moved the container from 73D56EDC... to
/// AF781242.... A path inside an app's data container is re-rooted at this
/// install's home; anything else is left alone.
nonisolated enum CrewFiles {
    static func here(_ url: URL, home: String = NSHomeDirectory()) -> URL {
        guard url.isFileURL else { return url }
        let path = url.path
        guard let marker = path.range(of: "/Containers/Data/Application/") else { return url }
        let rest = path[marker.upperBound...]
        guard let slash = rest.firstIndex(of: "/") else { return url }
        let inside = String(rest[rest.index(after: slash)...])
        return URL(fileURLWithPath: home).appending(path: inside)
    }
}

/// A record's fields. **A record is always written whole**: a key that is
/// absent is cleared on the server, which is how a removed photograph leaves
/// every copy of a win.
typealias RecordFields = [String: CrewValue]

nonisolated enum CrewRecordType: String, Codable, Sendable, CaseIterable {
    case crew = "Crew"
    case member = "Member"
    case sharedWin = "SharedWin"
    case reaction = "Reaction"
    /// A line in the crew's day chat (2026-10-05).
    case message = "CrewMessage"
}

/// The kinds of record a crew zone holds, and EXACTLY what goes in them.
///
/// The key sets are the contract with every friend's phone. A note, a
/// caption, a place, a habit id, a plan item or a mood is never in one, and
/// `CrewRecordTests` fails the day someone adds a field "just for the
/// tooltip".
nonisolated enum CrewRecords {
    /// The one `Crew` record in a zone is always called this.
    static let crewRecordName = "crew"

    static let sharedWinKeys: Set<String> = [
        "winID", "senderProfileID", "crewDay", "title", "colour", "icon",
        "blockSize", "photo", "cropX", "cropY", "createdAt", "updatedAt",
        "withPeople",
    ]
    static let crewKeys: Set<String> = ["name", "ownerProfileID", "timeZoneIdentifier", "createdAt", "photo"]
    static let memberKeys: Set<String> = ["profileID", "firstName", "head", "photo", "joinedAt"]
    static let reactionKeys: Set<String> = ["winID", "profileID", "emoji", "createdAt", "line", "sketch"]
    /// The day chat's line: words, or a doodle, and the win it answers.
    static let messageKeys: Set<String> = ["messageID", "senderProfileID", "crewDay", "text",
                                           "quoteWinID", "sketch", "createdAt"]

    static func keys(of type: CrewRecordType) -> Set<String> {
        switch type {
        case .crew: crewKeys
        case .member: memberKeys
        case .sharedWin: sharedWinKeys
        case .reaction: reactionKeys
        case .message: messageKeys
        }
    }

    // MARK: SharedWin

    static func name(of win: SharedWin) -> String { win.winID.uuidString }

    static func fields(_ win: SharedWin) -> RecordFields {
        var fields: RecordFields = [
            "winID": .uuid(win.winID),
            "senderProfileID": .uuid(win.senderProfileID),
            "crewDay": .string(win.crewDay),
            "title": .string(win.title),
            "colour": .string(win.colour.rawValue),
            "icon": .string(win.icon.rawValue),
            "blockSize": .string(win.blockSize.rawValue),
            "createdAt": .date(win.createdAt),
            "updatedAt": .date(win.updatedAt),
        ]
        if let photo = win.photo { fields["photo"] = .asset(photo) }
        if let x = win.cropX { fields["cropX"] = .double(x) }
        if let y = win.cropY { fields["cropY"] = .double(y) }
        // Absent when nobody was tagged, as a missing photo is: a record is
        // written whole, so an absent key is an empty one.
        if !win.withPeople.isEmpty {
            fields["withPeople"] = .string(win.withPeople.map(\.uuidString).joined(separator: ","))
        }
        return fields
    }

    /// The people a record says a win was with: profile ids, each once, never
    /// the sender, and no more than `CrewCaps.withPeople` whatever the record
    /// claims.
    static func withPeople(_ raw: String?, sender: UUID) -> [UUID] {
        var seen: Set<UUID> = []
        var people: [UUID] = []
        for part in (raw ?? "").split(separator: ",") {
            guard let id = UUID(uuidString: part.trimmingCharacters(in: .whitespaces)),
                  id != sender, seen.insert(id).inserted else { continue }
            people.append(id)
            if people.count == CrewCaps.withPeople { break }
        }
        return people
    }

    static func sharedWin(_ fields: RecordFields, crew: CrewID) -> SharedWin? {
        guard let winID = fields["winID"]?.uuid,
              let sender = fields["senderProfileID"]?.uuid,
              let day = fields["crewDay"]?.string,
              let created = fields["createdAt"]?.date else { return nil }
        let title: String = fields["title"]?.string ?? ""
        let colour: HabitCategory = fields["colour"]?.string.flatMap { HabitCategory(rawValue: $0) } ?? .unlabeled
        let icon: HabitCategory = fields["icon"]?.string.flatMap { HabitCategory(rawValue: $0) } ?? .unlabeled
        let size: BlockSize = fields["blockSize"]?.string.flatMap { BlockSize(rawValue: $0) } ?? .small
        let updated: Date = fields["updatedAt"]?.date ?? created
        return SharedWin(winID: winID, crewID: crew, senderProfileID: sender, crewDay: day,
                         title: title, colour: colour, icon: icon, blockSize: size,
                         photo: fields["photo"]?.asset, cropX: fields["cropX"]?.double,
                         cropY: fields["cropY"]?.double, createdAt: created, updatedAt: updated,
                         withPeople: withPeople(fields["withPeople"]?.string, sender: sender))
    }

    // MARK: Reaction

    static func fields(_ reaction: Reaction) -> RecordFields {
        var fields: RecordFields = ["winID": .uuid(reaction.winID), "profileID": .uuid(reaction.profileID),
                                    "emoji": .string(reaction.emoji), "createdAt": .date(reaction.createdAt)]
        if let line = reaction.line, !line.isEmpty { fields["line"] = .string(line) }
        // An asset, as a win's photo is, and absent when there is none: a
        // record is written whole, so absent is how a doodle is cleared.
        if let sketch = reaction.sketch { fields["sketch"] = .asset(sketch) }
        return fields
    }

    static func reaction(_ fields: RecordFields, crew: CrewID) -> Reaction? {
        guard let win = fields["winID"]?.uuid, let who = fields["profileID"]?.uuid,
              let emoji = fields["emoji"]?.string, !emoji.isEmpty else { return nil }
        // One grapheme, whatever a record claims: a reaction is an emoji,
        // never a message.
        // A reply's line, as long as a line and no longer, and only if it
        // passes the same words check the sender's phone made.
        let line = fields["line"]?.string
            .map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Reaction.lineLimit)) }
            .flatMap { $0.isEmpty || !CrewWords.isAcceptable($0) ? nil : $0 }
        return Reaction(winID: win, crewID: crew, profileID: who, emoji: String(emoji.prefix(1)),
                        createdAt: fields["createdAt"]?.date ?? .distantPast, line: line,
                        sketch: fields["sketch"]?.asset)
    }

    // MARK: Message

    static func name(of message: CrewMessage) -> String { message.messageID.uuidString }

    static func fields(_ message: CrewMessage) -> RecordFields {
        var fields: RecordFields = [
            "messageID": .uuid(message.messageID),
            "senderProfileID": .uuid(message.senderProfileID),
            "crewDay": .string(message.crewDay),
            "text": .string(message.text),
            "createdAt": .date(message.createdAt),
        ]
        // Absent when there is none, as a win's photo is: a record is
        // written whole, so absent is empty.
        if let quote = message.quoteWinID { fields["quoteWinID"] = .uuid(quote) }
        if let sketch = message.sketch { fields["sketch"] = .asset(sketch) }
        return fields
    }

    /// A message as a phone may show it, whatever the record claims: words
    /// cut to `CrewMessage.textLimit`, refused words refused here too (the
    /// sending phone checked them, and a record written by anything else is
    /// checked again), and never empty.
    static func message(_ fields: RecordFields, crew: CrewID) -> CrewMessage? {
        guard let id = fields["messageID"]?.uuid,
              let sender = fields["senderProfileID"]?.uuid,
              let day = fields["crewDay"]?.string,
              let created = fields["createdAt"]?.date else { return nil }
        let text = String((fields["text"]?.string ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines).prefix(CrewMessage.textLimit))
        let sketch = fields["sketch"]?.asset
        guard !text.isEmpty || sketch != nil else { return nil }
        guard text.isEmpty || CrewWords.isAcceptable(text) else { return nil }
        return CrewMessage(messageID: id, crewID: crew, senderProfileID: sender, crewDay: day, text: text,
                           quoteWinID: fields["quoteWinID"]?.uuid, sketch: sketch, createdAt: created)
    }

    // MARK: Crew

    static func fields(_ crew: Crew) -> RecordFields {
        var fields: RecordFields = [
            "name": .string(crew.name),
            "ownerProfileID": .uuid(crew.ownerProfileID),
            "timeZoneIdentifier": .string(crew.timeZoneIdentifier),
            "createdAt": .date(crew.createdAt),
        ]
        if let photo = crew.photo { fields["photo"] = .asset(photo) }
        return fields
    }

    static func crew(_ fields: RecordFields, id: CrewID, members: [CrewMember]) -> Crew? {
        guard let owner = fields["ownerProfileID"]?.uuid else { return nil }
        return Crew(id: id,
                    name: fields["name"]?.string ?? "",
                    ownerProfileID: owner,
                    timeZoneIdentifier: fields["timeZoneIdentifier"]?.string ?? TimeZone.current.identifier,
                    createdAt: fields["createdAt"]?.date ?? .distantPast,
                    photo: fields["photo"]?.asset,
                    members: members)
    }

    // MARK: Member

    static func name(of member: CrewMember) -> String { member.profileID.uuidString }

    static func fields(_ member: CrewMember) -> RecordFields {
        var fields: RecordFields = [
            "profileID": .uuid(member.profileID),
            "firstName": .string(member.firstName),
            "joinedAt": .date(member.joinedAt),
        ]
        if let head = member.head { fields["head"] = .asset(head) }
        if let photo = member.photo { fields["photo"] = .asset(photo) }
        return fields
    }

    static func member(_ fields: RecordFields) -> CrewMember? {
        guard let id = fields["profileID"]?.uuid else { return nil }
        return CrewMember(profileID: id,
                          firstName: fields["firstName"]?.string ?? "",
                          head: fields["head"]?.asset,
                          joinedAt: fields["joinedAt"]?.date ?? .distantPast,
                          photo: fields["photo"]?.asset)
    }
}
