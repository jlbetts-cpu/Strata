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
    var asset: URL? { if case .asset(let v) = self { v } else { nil } }
}

/// A record's fields. **A record is always written whole**: a key that is
/// absent is cleared on the server, which is how a removed photograph leaves
/// every copy of a win.
typealias RecordFields = [String: CrewValue]

nonisolated enum CrewRecordType: String, Codable, Sendable, CaseIterable {
    case crew = "Crew"
    case member = "Member"
    case sharedWin = "SharedWin"
}

/// The three kinds of record a crew zone holds, and EXACTLY what goes in them.
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
    ]
    static let crewKeys: Set<String> = ["name", "ownerProfileID", "timeZoneIdentifier", "createdAt", "photo"]
    static let memberKeys: Set<String> = ["profileID", "firstName", "head", "photo", "joinedAt"]

    static func keys(of type: CrewRecordType) -> Set<String> {
        switch type {
        case .crew: crewKeys
        case .member: memberKeys
        case .sharedWin: sharedWinKeys
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
        return fields
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
                         cropY: fields["cropY"]?.double, createdAt: created, updatedAt: updated)
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
