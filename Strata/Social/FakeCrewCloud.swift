import Foundation

/// Every crew zone in a pretend iCloud, shared by any number of pretend
/// phones. Tests make two `FakeCrewCloud`s on one world to play two friends.
@MainActor
final class FakeCrewWorld {
    struct Zone {
        var owner: UUID
        var participants: Set<UUID>
        var url: URL
        /// "Type/name" to fields.
        var records: [String: RecordFields] = [:]
    }

    var zones: [CrewID: Zone] = [:]

    func records(of type: CrewRecordType, in crew: CrewID) -> [String: RecordFields] {
        var out: [String: RecordFields] = [:]
        for (key, fields) in zones[crew]?.records ?? [:] where key.hasPrefix(type.rawValue + "/") {
            out[String(key.dropFirst(type.rawValue.count + 1))] = fields
        }
        return out
    }
}

/// A `CrewCloud` that keeps everything in memory.
///
/// `offline` makes every call throw, so the outbox can be watched holding a
/// write. `calls` counts every call, so a test can prove the flag being off
/// means NOTHING was asked of the cloud.
@MainActor
final class FakeCrewCloud: CrewCloud {
    struct Offline: Error {}

    let world: FakeCrewWorld
    let myProfileID: UUID
    var offline = false
    private(set) var calls = 0

    init(world: FakeCrewWorld? = nil, me: UUID = UUID()) {
        self.world = world ?? FakeCrewWorld()
        self.myProfileID = me
    }

    private func touch() throws {
        calls += 1
        if offline { throw Offline() }
    }

    func createZone(_ crew: Crew) async throws -> URL {
        try touch()
        let url = URL(string: "https://www.icloud.com/share/\(crew.id.rawValue)")!
        world.zones[crew.id] = FakeCrewWorld.Zone(owner: myProfileID, participants: [myProfileID], url: url)
        return url
    }

    func shareURL(for crew: CrewID) async throws -> URL {
        try touch()
        guard let zone = world.zones[crew] else { throw CrewError.unknownCrew }
        return zone.url
    }

    func accept(_ invite: CrewInvite) async throws -> CrewID {
        try touch()
        guard let (id, _) = world.zones.first(where: { $0.value.url == invite.url }) else {
            throw CrewError.unknownCrew
        }
        world.zones[id]?.participants.insert(myProfileID)
        return id
    }

    func fetchCrews() async throws -> [Crew] {
        try touch()
        return world.zones.compactMap { id, zone -> Crew? in
            guard zone.participants.contains(myProfileID),
                  let fields = zone.records["\(CrewRecordType.crew.rawValue)/\(CrewRecords.crewRecordName)"]
            else { return nil }
            let members = world.records(of: .member, in: id).values
                .compactMap(CrewRecords.member)
                .filter { zone.participants.contains($0.profileID) }
            return CrewRecords.crew(fields, id: id, members: members)
        }
        .sorted { $0.createdAt < $1.createdAt }
    }

    func fetchWins(in crew: CrewID) async throws -> [SharedWin] {
        try touch()
        guard world.zones[crew]?.participants.contains(myProfileID) == true else { throw CrewError.unknownCrew }
        return world.records(of: .sharedWin, in: crew).values.compactMap { CrewRecords.sharedWin($0, crew: crew) }
    }

    func save(_ fields: RecordFields, type: CrewRecordType, name: String, in crew: CrewID) async throws {
        try touch()
        guard world.zones[crew]?.participants.contains(myProfileID) == true else { throw CrewError.unknownCrew }
        world.zones[crew]?.records["\(type.rawValue)/\(name)"] = fields
    }

    func delete(type: CrewRecordType, name: String, in crew: CrewID) async throws {
        try touch()
        world.zones[crew]?.records["\(type.rawValue)/\(name)"] = nil
    }

    func leave(_ crew: CrewID) async throws {
        try touch()
        world.zones[crew]?.participants.remove(myProfileID)
    }

    func endCrew(_ crew: CrewID) async throws {
        try touch()
        guard world.zones[crew]?.owner == myProfileID else { throw CrewError.notOwner }
        world.zones[crew] = nil
    }

    func removeParticipant(_ profileID: UUID, from crew: CrewID) async throws {
        try touch()
        guard world.zones[crew]?.owner == myProfileID else { throw CrewError.notOwner }
        world.zones[crew]?.participants.remove(profileID)
        world.zones[crew]?.records["\(CrewRecordType.member.rawValue)/\(profileID.uuidString)"] = nil
    }
}
