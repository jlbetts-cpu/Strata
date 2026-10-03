import CloudKit
import Foundation
import os

/// Crews in iCloud: one zone and one zone-wide `CKShare` per crew.
///
/// **Why not SwiftData.** The spike (2026-10-02, iOS 26.5 SDK) found no sharing
/// API in SwiftData; the store mirrors to the private database only. So this
/// talks to CloudKit directly and keeps its own small cache beside the
/// private store, never in it.
///
/// - A crew you started is a zone in your **private** database.
/// - A crew you joined is the same zone, reached through your **shared**
///   database.
/// - Records are read with zone change tokens, so a refresh brings only what
///   changed and a photograph is downloaded once, not every fifteen seconds.
@MainActor
final class CloudKitCrewCloud: CrewCloud {
    private static let log = Logger(subsystem: "Strata", category: "crews.cloud")

    let container: CKContainer
    private(set) var myProfileID: UUID
    private var prepared = false
    private let directory: URL

    /// Where each crew's zone is and which database reaches it.
    private var zones: [CrewID: (id: CKRecordZone.ID, shared: Bool)] = [:]
    /// Crews made on this phone this run: a listing taken before one existed
    /// must never take it away.
    private var madeHere: Set<CrewID> = []
    /// Every record in every crew, as fields, keyed "Type/name".
    private var cache: [CrewID: [String: RecordFields]] = [:]
    private var tokens: [CrewID: CKServerChangeToken] = [:]

    init(containerID: String? = nil, me: UUID? = nil, directory: URL? = nil) {
        container = CKContainer(identifier: containerID ?? SharedModelContainer.cloudKitContainerID)
        myProfileID = me ?? ProfileStore.profileID
        self.directory = directory ?? SocialStore.defaultDirectory
        loadCache()
    }

    private static let creatorKey = "_creator"

    private func database(_ shared: Bool) -> CKDatabase {
        shared ? container.sharedCloudDatabase : container.privateCloudDatabase
    }

    private func requireAccount() async throws {
        guard try await container.accountStatus() == .available else { throw CrewError.notSignedIn }
    }

    private func zone(_ crew: CrewID) throws -> (id: CKRecordZone.ID, db: CKDatabase) {
        guard let zone = zones[crew] else { throw CrewError.unknownCrew }
        return (zone.id, database(zone.shared))
    }

    // MARK: Who you are

    /// **One person, however many phones.** `ProfileStore.profileID` is made
    /// per phone, so a second phone on the same iCloud account would join its
    /// crews as a second member (the 2026-10-02 audit). The first phone writes
    /// its id to a record in the PRIVATE database, which only that account's
    /// phones can read; a later phone finds it and adopts it, so the iCloud
    /// account is mapped TO the profile id rather than becoming it.
    func prepare() async {
        guard !prepared else { return }
        do {
            guard try await container.accountStatus() == .available else { return }
            let id = CKRecord.ID(recordName: "sturdy-identity")
            let db = container.privateCloudDatabase
            if let record = try? await db.record(for: id),
               let raw = record["profileID"] as? String, let theirs = UUID(uuidString: raw) {
                if theirs != myProfileID {
                    UserDefaults.standard.set(theirs.uuidString, forKey: ProfileStore.profileIDKey)
                    myProfileID = theirs
                }
            } else {
                let record = CKRecord(recordType: "Identity", recordID: id)
                record["profileID"] = myProfileID.uuidString as NSString
                _ = try await db.modifyRecords(saving: [record], deleting: [], savePolicy: .ifServerRecordUnchanged)
            }
            prepared = true
        } catch {
            Self.log.error("identity not settled: \(error)")
        }
    }

    func reset() {
        zones.removeAll()
        cache.removeAll()
        tokens.removeAll()
        prepared = false
        try? FileManager.default.removeItem(at: cacheURL)
    }

    // MARK: Crews

    func createZone(_ crew: Crew) async throws -> URL {
        try await requireAccount()
        let zoneID = CKRecordZone.ID(zoneName: crew.id.rawValue, ownerName: CKCurrentUserDefaultName)
        _ = try await container.privateCloudDatabase.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)],
                                                                       deleting: [])
        zones[crew.id] = (zoneID, false)
        madeHere.insert(crew.id)
        let share = CKShare(recordZoneID: zoneID)
        share.publicPermission = .none
        share[CKShare.SystemFieldKey.title] = crew.name.isEmpty ? "Crew" : crew.name
        let saved = try await container.privateCloudDatabase.modifyRecords(saving: [share], deleting: [])
        // iCloud's own error, not a generic one: on a tester's phone it is the
        // only way to know what went wrong (2026-10-02, the first real test).
        switch saved.saveResults[share.recordID] {
        case .failure(let error)?: throw error
        case .success(let record)?:
            if let url = (record as? CKShare)?.url { return url }
        case nil: break
        }
        // Saved without its link yet: read it back.
        return try await shareURL(for: crew.id)
    }

    /// The zone-wide share of a crew, for the system's sharing sheet.
    func share(for crew: CrewID) async throws -> CKShare {
        let (zoneID, db) = try zone(crew)
        let id = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
        guard let share = try await db.record(for: id) as? CKShare else { throw CrewError.unknownCrew }
        return share
    }

    func shareURL(for crew: CrewID) async throws -> URL {
        guard let url = try await share(for: crew).url else { throw CrewError.unknownCrew }
        return url
    }

    func accept(_ invite: CrewInvite) async throws -> CrewID {
        try await requireAccount()
        let metadata: CKShare.Metadata
        if let given = invite.metadata as? CKShare.Metadata {
            metadata = given
        } else {
            metadata = try await container.shareMetadata(for: invite.url)
        }
        _ = try await container.accept(metadata)
        let zoneID = metadata.share.recordID.zoneID
        let crew = CrewID(rawValue: zoneID.zoneName)
        zones[crew] = (zoneID, true)
        return crew
    }

    func fetchCrews() async throws -> [Crew] {
        try await requireAccount()
        try await discoverZones()
        var crews: [Crew] = []
        for (crewID, _) in zones {
            do {
                try await sync(crewID)
            } catch let error as CKError where error.code == .zoneNotFound || error.code == .userDeletedZone {
                // Ended by its owner, or you were removed: it is gone.
                forget(crewID)
                continue
            }
            let records = cache[crewID] ?? [:]
            guard let fields = records["\(CrewRecordType.crew.rawValue)/\(CrewRecords.crewRecordName)"] else { continue }
            let members = records.filter { $0.key.hasPrefix(CrewRecordType.member.rawValue + "/") }
                .values.compactMap(CrewRecords.member)
            if let crew = CrewRecords.crew(fields, id: crewID, members: members) { crews.append(crew) }
        }
        saveCache()
        return crews.sorted { $0.createdAt < $1.createdAt }
    }

    func fetchWins(in crew: CrewID) async throws -> [SharedWin] {
        (cache[crew] ?? [:]).filter { $0.key.hasPrefix(CrewRecordType.sharedWin.rawValue + "/") }
            .values.compactMap { CrewRecords.sharedWin($0, crew: crew) }
    }

    func fetchReactions(in crew: CrewID) async throws -> [Reaction] {
        (cache[crew] ?? [:]).filter { $0.key.hasPrefix(CrewRecordType.reaction.rawValue + "/") }
            .values.compactMap { CrewRecords.reaction($0, crew: crew) }
    }

    // MARK: Records

    func save(_ fields: RecordFields, type: CrewRecordType, name: String, in crew: CrewID) async throws {
        let (zoneID, db) = try zone(crew)
        let record = CKRecord(recordType: type.rawValue, recordID: CKRecord.ID(recordName: name, zoneID: zoneID))
        // Written whole: every key of the type is set, and an absent one is
        // cleared, which is how a removed photograph leaves the record.
        for key in CrewRecords.keys(of: type) {
            record[key] = fields[key].map(Self.ckValue)
        }
        let result = try await db.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
        if case .failure(let error)? = result.saveResults[record.recordID] { throw error }
        cache[crew, default: [:]]["\(type.rawValue)/\(name)"] = fields
        saveCache()
    }

    func delete(type: CrewRecordType, name: String, in crew: CrewID) async throws {
        let (zoneID, db) = try zone(crew)
        let id = CKRecord.ID(recordName: name, zoneID: zoneID)
        let result = try await db.modifyRecords(saving: [], deleting: [id])
        if case .failure(let error)? = result.deleteResults[id],
           (error as? CKError)?.code != .unknownItem { throw error }
        cache[crew]?["\(type.rawValue)/\(name)"] = nil
        saveCache()
    }

    func leave(_ crew: CrewID) async throws {
        let (zoneID, _) = try zone(crew)
        // A participant leaves by deleting the zone from their SHARED
        // database: that removes them, and only them.
        _ = try await container.sharedCloudDatabase.modifyRecordZones(saving: [], deleting: [zoneID])
        forget(crew)
    }

    func endCrew(_ crew: CrewID) async throws {
        guard let zone = zones[crew], !zone.shared else { throw CrewError.notOwner }
        _ = try await container.privateCloudDatabase.modifyRecordZones(saving: [], deleting: [zone.id])
        forget(crew)
    }

    func removeParticipant(_ profileID: UUID, from crew: CrewID) async throws {
        guard let zone = zones[crew], !zone.shared else { throw CrewError.notOwner }
        let share = try await share(for: crew)
        let member = cache[crew]?["\(CrewRecordType.member.rawValue)/\(profileID.uuidString)"]
        if let user = member?[Self.creatorKey]?.string,
           let participant = share.participants.first(where: { $0.userIdentity.userRecordID?.recordName == user }) {
            share.removeParticipant(participant)
            _ = try await container.privateCloudDatabase.modifyRecords(saving: [share], deleting: [])
        }
        try await delete(type: .member, name: profileID.uuidString, in: crew)
    }

    // MARK: Syncing

    private func discoverZones() async throws {
        let mine = try await container.privateCloudDatabase.allRecordZones()
        let joined = try await container.sharedCloudDatabase.allRecordZones()
        var found: [CrewID: (CKRecordZone.ID, Bool)] = [:]
        for zone in mine where zone.zoneID.zoneName.hasPrefix("crew-") {
            found[CrewID(rawValue: zone.zoneID.zoneName)] = (zone.zoneID, false)
        }
        for zone in joined where zone.zoneID.zoneName.hasPrefix("crew-") {
            found[CrewID(rawValue: zone.zoneID.zoneName)] = (zone.zoneID, true)
        }
        // **Added to, never replaced.** The list's refresh lists the zones,
        // and a crew started while that listing was in flight was missing
        // from it; replacing the map dropped the crew the moment it was made,
        // and its first record failed with "could not be opened" (the first
        // real test, 2026-10-02). Only a zone missing from a listing AND not
        // made here this run is forgotten.
        for gone in Set(zones.keys).subtracting(found.keys).subtracting(madeHere) { forget(gone) }
        for (id, zone) in found { zones[id] = (id: zone.0, shared: zone.1) }
    }

    /// Brings one crew's cache up to date from its change token.
    private func sync(_ crew: CrewID) async throws {
        let (zoneID, db) = try zone(crew)
        var more = true
        while more {
            let changes = try await db.recordZoneChanges(inZoneWith: zoneID, since: tokens[crew])
            for (id, result) in changes.modificationResultsByID {
                guard case .success(let modification) = result else { continue }
                let record = modification.record
                guard let type = CrewRecordType(rawValue: record.recordType) else { continue }
                var fields = fields(of: record, type: type, crew: crew)
                // Who wrote a Member record is how a profile id is matched to
                // a share participant when someone is removed. Kept in the
                // cache only; `save` writes the type's own keys and no other.
                if type == .member, let creator = record.creatorUserRecordID {
                    fields[Self.creatorKey] = .string(creator.recordName)
                }
                cache[crew, default: [:]]["\(type.rawValue)/\(id.recordName)"] = fields
            }
            for deletion in changes.deletions {
                let key = "\(deletion.recordType)/\(deletion.recordID.recordName)"
                if let asset = cache[crew]?[key]?.values.compactMap(\.asset).first {
                    try? FileManager.default.removeItem(at: asset)
                }
                cache[crew]?[key] = nil
            }
            tokens[crew] = changes.changeToken
            more = changes.moreComing
        }
    }

    /// A record's fields, with any asset copied out of CloudKit's cache to a
    /// file of ours (CloudKit may evict its own copy at any time).
    private func fields(of record: CKRecord, type: CrewRecordType, crew: CrewID) -> RecordFields {
        var fields: RecordFields = [:]
        for key in CrewRecords.keys(of: type) {
            switch record[key] {
            case let value as String: fields[key] = .string(value)
            case let value as Date: fields[key] = .date(value)
            case let value as Double: fields[key] = .double(value)
            case let value as Int: fields[key] = .int(value)
            case let asset as CKAsset:
                guard let source = asset.fileURL else { continue }
                let folder = type == .member ? "Heads" : "Photos"
                let suffix = type == .member && key == "head" ? "head" : "jpg"
                // Named by key as well: a Member record has a head AND a
                // photo, and one path for both let each overwrite the other.
                let name = type == .crew ? "crew-\(record.recordChangeTag ?? "0")" : "\(record.recordID.recordName)-\(key)"
                let url = directory.appending(path: "\(folder)/\(crew.rawValue)/\(name).\(suffix)")
                do {
                    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                            withIntermediateDirectories: true)
                    if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
                    try FileManager.default.copyItem(at: source, to: url)
                    fields[key] = .asset(url)
                } catch {
                    Self.log.error("asset \(key, privacy: .public) not kept: \(error)")
                }
            default: break
            }
        }
        return fields
    }

    private static func ckValue(_ value: CrewValue) -> CKRecordValue {
        switch value {
        case .string(let v): v as NSString
        case .date(let v): v as NSDate
        case .double(let v): NSNumber(value: v)
        case .int(let v): NSNumber(value: v)
        case .uuid(let v): v.uuidString as NSString
        case .asset(let url): CKAsset(fileURL: url)
        }
    }

    private func forget(_ crew: CrewID) {
        zones[crew] = nil
        cache[crew] = nil
        tokens[crew] = nil
        saveCache()
    }

    // MARK: The cache on disk

    private struct Saved: Codable {
        var cache: [String: [String: RecordFields]]
        var tokens: [String: Data]
    }

    private var cacheURL: URL { directory.appending(path: "cloud-cache.json") }

    private func loadCache() {
        guard let data = try? Data(contentsOf: cacheURL),
              let saved = try? JSONDecoder().decode(Saved.self, from: data) else { return }
        for (key, records) in saved.cache { cache[CrewID(rawValue: key)] = records }
        for (key, data) in saved.tokens {
            if let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data) {
                tokens[CrewID(rawValue: key)] = token
            }
        }
    }

    private func saveCache() {
        var saved = Saved(cache: [:], tokens: [:])
        for (crew, records) in cache { saved.cache[crew.rawValue] = records }
        for (crew, token) in tokens {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
                saved.tokens[crew.rawValue] = data
            }
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(saved).write(to: cacheURL, options: .atomic)
        } catch {
            Self.log.error("crew cache not written: \(error)")
        }
    }
}
