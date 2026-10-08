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
    private static let editorKey = "_editor"
    /// The cache entry holding a crew's participants' iCloud first names.
    private static let namesKey = "_names"

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

    func account() async -> CrewAccount {
        do {
            switch try await container.accountStatus() {
            case .available: return .signedIn(try await container.userRecordID().recordName)
            case .noAccount: return .signedOut
            default: return .unknown
            }
        } catch {
            return .unknown
        }
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
        await refreshBans()
        for (crewID, _) in zones {
            do {
                try await sync(crewID)
            } catch let error as CKError where error.code == .zoneNotFound || error.code == .userDeletedZone {
                // Ended by its owner, or you were removed: it is gone.
                forget(crewID)
                continue
            }
            // A crew synced before names were kept has its share already
            // behind its change token: asked for once.
            if cache[crewID]?[Self.namesKey] == nil, let share = try? await share(for: crewID) {
                keepNames(of: share, in: crewID)
            }
            if let crew = cachedCrew(crewID) { crews.append(crew) }
        }
        saveCache()
        return crews.sorted { $0.createdAt < $1.createdAt }
    }

    /// **One crew from the cache, no request** (2026-10-08): the live sync
    /// has just brought its zone up to date with `syncOnly`.
    func fetchCrew(_ crew: CrewID) async throws -> Crew? {
        guard zones[crew] != nil else { return nil }
        return cachedCrew(crew)
    }

    private func cachedCrew(_ crewID: CrewID) -> Crew? {
        let records = cache[crewID] ?? [:]
        guard let fields = records["\(CrewRecordType.crew.rawValue)/\(CrewRecords.crewRecordName)"] else { return nil }
        let names = records[Self.namesKey] ?? [:]
        let members = records.filter { $0.key.hasPrefix(CrewRecordType.member.rawValue + "/") }
            .values.compactMap { fields -> CrewMember? in
                // Someone the developer has banned is in no crew, on any
                // phone; their wins and reactions go with them, because
                // the store keeps only members' (see `refreshBans`).
                if let user = fields[Self.creatorKey]?.string, banned.contains(user) { return nil }
                guard var member = CrewRecords.member(fields) else { return nil }
                if member.firstName.isEmpty, let user = fields[Self.creatorKey]?.string,
                   let given = names[user]?.string {
                    member.firstName = given
                }
                return member
            }
        return CrewRecords.crew(fields, id: crewID, members: members)
    }

    // MARK: Moderation

    /// iCloud accounts the developer has banned: public `Ban` records, which
    /// only the Moderator role may write (the schema says so), naming the
    /// account by its user record.
    ///
    /// **Read once a day, and when a crew opens** (the 2026-10-08 audit). It
    /// was read every hour by every phone, capped at 400 results, so the
    /// 401st ban never reached anyone. It pages through every result now,
    /// asks for the `account` field and nothing else, and keeps what it read
    /// on disk so a relaunch does not read it again.
    private var banned = Set(UserDefaults.standard.stringArray(forKey: CloudKitCrewCloud.bansKey) ?? [])
    private var bansCheckedAt = Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: CloudKitCrewCloud.bansCheckedKey))
    private static let bansKey = "crews.bans"
    private static let bansCheckedKey = "crews.bansCheckedAt"
    static let bansInterval: TimeInterval = 86_400
    /// The least time between two reads asked for by opening a crew, so
    /// going in and out of one does not read them each time.
    static let bansOnOpenInterval: TimeInterval = 300
    /// Pages read at most: far past any ban list this app will have.
    private static let bansPageLimit = 100

    func refreshModeration(force: Bool) async -> Bool {
        await refreshBans(force: force)
    }

    /// True when the list changed.
    @discardableResult
    func refreshBans(force: Bool = false) async -> Bool {
        let since = Date().timeIntervalSince(bansCheckedAt)
        guard since > (force ? Self.bansOnOpenInterval : Self.bansInterval) else { return false }
        let db = container.publicCloudDatabase
        let query = CKQuery(recordType: "Ban", predicate: NSPredicate(value: true))
        let keys = ["account"]
        var found: Set<String> = []
        func keep(_ results: [(CKRecord.ID, Result<CKRecord, Error>)]) {
            for (_, result) in results {
                if let account = (try? result.get())?["account"] as? String { found.insert(account) }
            }
        }
        do {
            var page = try await db.records(matching: query, desiredKeys: keys,
                                            resultsLimit: CKQueryOperation.maximumResults)
            keep(page.matchResults)
            var pages = 1
            while let cursor = page.queryCursor, pages < Self.bansPageLimit {
                page = try await db.records(continuingMatchFrom: cursor, desiredKeys: keys,
                                            resultsLimit: CKQueryOperation.maximumResults)
                keep(page.matchResults)
                pages += 1
            }
        } catch {
            // Before the Ban type is deployed, or offline: nobody is banned
            // that was not already, and it is asked again in an hour.
            Self.log.notice("bans not read: \(error)")
            bansCheckedAt = Date().addingTimeInterval(3600 - Self.bansInterval)
            UserDefaults.standard.set(bansCheckedAt.timeIntervalSince1970, forKey: Self.bansCheckedKey)
            return false
        }
        bansCheckedAt = Date()
        UserDefaults.standard.set(bansCheckedAt.timeIntervalSince1970, forKey: Self.bansCheckedKey)
        guard found != banned else { return false }
        banned = found
        UserDefaults.standard.set(found.sorted(), forKey: Self.bansKey)
        return true
    }

    /// The iCloud account behind a member of a crew, as CloudKit recorded
    /// who wrote their Member record: what a report names, because a
    /// profile id is only what the app says.
    func account(of profileID: UUID, in crew: CrewID) -> String? {
        cache[crew]?["\(CrewRecordType.member.rawValue)/\(profileID.uuidString)"]?[Self.creatorKey]?.string
    }

    /// The account that last changed a crew's name or picture.
    func lastEditor(of crew: CrewID) -> String? {
        cache[crew]?["\(CrewRecordType.crew.rawValue)/\(CrewRecords.crewRecordName)"]?[Self.editorKey]?.string
    }

    func fetchWins(in crew: CrewID) async throws -> [SharedWin] {
        (cache[crew] ?? [:]).filter { $0.key.hasPrefix(CrewRecordType.sharedWin.rawValue + "/") }
            .values.compactMap { fields in
                CrewRecords.sharedWin(fields, crew: crew).flatMap { authentic(fields, as: $0.senderProfileID, in: crew) ? $0 : nil }
            }
    }

    func fetchReactions(in crew: CrewID) async throws -> [Reaction] {
        (cache[crew] ?? [:]).filter { $0.key.hasPrefix(CrewRecordType.reaction.rawValue + "/") }
            .values.compactMap { fields in
                CrewRecords.reaction(fields, crew: crew).flatMap { authentic(fields, as: $0.profileID, in: crew) ? $0 : nil }
            }
    }

    /// The day chat, fetched and cached like the other types: a line, and
    /// a doodle copied out of CloudKit's cache as a photo is (`fields(of:)`).
    /// Checked against its sender as a win is, so nobody can speak as
    /// someone else.
    func fetchMessages(in crew: CrewID) async throws -> [CrewMessage] {
        (cache[crew] ?? [:]).filter { $0.key.hasPrefix(CrewRecordType.message.rawValue + "/") }
            .values.compactMap { fields in
                CrewRecords.message(fields, crew: crew).flatMap { authentic(fields, as: $0.senderProfileID, in: crew) ? $0 : nil }
            }
    }

    /// **Whether a record was written by the person it says it is from.**
    /// A member can write to the crew's zone, and the sender on a win is a
    /// field the app fills in, so a changed app could post as someone else
    /// (the 2026-10-03 audit). CloudKit records who really wrote each record;
    /// a win or a reaction whose writer is not the writer of that person's
    /// own Member record is dropped. A record not yet synced (one of this
    /// phone's own, just saved) carries no writer and is trusted: it is ours.
    private func authentic(_ fields: RecordFields, as profileID: UUID, in crew: CrewID) -> Bool {
        guard let writer = fields[Self.creatorKey]?.string,
              let member = account(of: profileID, in: crew) else { return true }
        return writer == member
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

    // MARK: Pings

    func ping(_ fields: [String: String]) async throws -> String {
        let name = "ping-\(UUID().uuidString)"
        let record = CKRecord(recordType: CrewPingRecord.type, recordID: CKRecord.ID(recordName: name))
        for (key, value) in fields { record[key] = value as NSString }
        let result = try await container.publicCloudDatabase.modifyRecords(saving: [record], deleting: [])
        if case .failure(let error)? = result.saveResults[record.recordID] { throw error }
        return name
    }

    func deletePings(_ names: [String]) async {
        guard !names.isEmpty else { return }
        do {
            _ = try await container.publicCloudDatabase.modifyRecords(
                saving: [], deleting: names.map { CKRecord.ID(recordName: $0) })
        } catch {
            Self.log.notice("pings not deleted: \(error)")
        }
    }

    /// Two query subscriptions in the public database, one for wins and one
    /// for reactions, each a visible alert that the notification extension
    /// puts into words. The old ones go first: a subscription's predicate
    /// cannot be changed, only replaced.
    func listen(for plan: CrewPingPlan) async throws {
        let db = container.publicCloudDatabase
        let ids = [CrewPingPlan.winsID, CrewPingPlan.reactionsID]
        let removed = try await db.modifySubscriptions(saving: [], deleting: ids)
        for (id, result) in removed.deleteResults {
            if case .failure(let error) = result, (error as? CKError)?.code != .unknownItem {
                Self.log.notice("ping subscription \(id, privacy: .public) not removed: \(error)")
            }
        }
        var saving: [CKSubscription] = []
        if !plan.winCrews.isEmpty {
            saving.append(Self.subscription(CrewPingPlan.winsID, plan.winsPredicate,
                                            fallback: CrewPingRecord.fallbackWin))
        }
        if !plan.reactionCrews.isEmpty {
            saving.append(Self.subscription(CrewPingPlan.reactionsID, plan.reactionsPredicate,
                                            fallback: CrewPingRecord.fallbackReaction))
        }
        guard !saving.isEmpty else { return }
        let saved = try await db.modifySubscriptions(saving: saving, deleting: [])
        for (_, result) in saved.saveResults {
            if case .failure(let error) = result { throw error }
        }
    }

    private static func subscription(_ id: String, _ predicate: NSPredicate, fallback: String) -> CKQuerySubscription {
        let subscription = CKQuerySubscription(recordType: CrewPingRecord.type, predicate: predicate,
                                               subscriptionID: id, options: [.firesOnRecordCreation])
        let info = CKSubscription.NotificationInfo()
        // Shown as it is only if the extension cannot run at all; the
        // extension replaces it with names.
        info.alertBody = fallback
        info.soundName = "default"
        info.shouldSendMutableContent = true
        info.desiredKeys = CrewPingRecord.fields
        subscription.notificationInfo = info
        return subscription
    }

    func zoneLocation(of crew: CrewID) -> (owner: String, joined: Bool)? {
        zones[crew].map { ($0.id.ownerName, $0.shared) }
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

    private func keepNames(of share: CKShare, in crew: CrewID) {
        var names: RecordFields = [:]
        for participant in share.participants {
            guard let user = participant.userIdentity.userRecordID?.recordName,
                  let given = participant.userIdentity.nameComponents?.givenName,
                  !given.isEmpty else { continue }
            names[user] = .string(given)
        }
        cache[crew, default: [:]][Self.namesKey] = names
    }

    func syncOnly(_ crew: CrewID) async throws -> Bool {
        guard zones[crew] != nil else { return false }
        let changed = try await sync(crew)
        if changed { saveCache() }
        return changed
    }

    /// Brings one crew's cache up to date from its change token. True when
    /// a record came or went.
    @discardableResult
    private func sync(_ crew: CrewID) async throws -> Bool {
        let (zoneID, db) = try zone(crew)
        var more = true
        var changed = false
        while more {
            let changes = try await db.recordZoneChanges(inZoneWith: zoneID, since: tokens[crew])
            if !changes.modificationResultsByID.isEmpty || !changes.deletions.isEmpty { changed = true }
            for (id, result) in changes.modificationResultsByID {
                guard case .success(let modification) = result else { continue }
                let record = modification.record
                // The crew's share: who is in it, by their iCloud first
                // names, for a member who never gave Some Wins a name. Messages
                // names a group by its people; with no name to go on it fell
                // back to "New Crew" (the owner, 2026-10-02).
                if let share = record as? CKShare {
                    keepNames(of: share, in: crew)
                    continue
                }
                guard let type = CrewRecordType(rawValue: record.recordType) else { continue }
                var fields = fields(of: record, type: type, crew: crew)
                // Who wrote a Member record is how a profile id is matched to
                // a share participant when someone is removed. Kept in the
                // cache only; `save` writes the type's own keys and no other.
                // Kept for EVERY record now, not only members: a win or a
                // reaction is checked against the member it claims to be
                // from (`authentic`).
                if let creator = record.creatorUserRecordID {
                    fields[Self.creatorKey] = .string(creator.recordName)
                }
                // Who last changed the crew's name or picture, for a report
                // of either: any member may change them.
                if type == .crew, let editor = record.lastModifiedUserRecordID {
                    fields[Self.editorKey] = .string(editor.recordName)
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
        return changed
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
                // A doodle is a PNG (its ink on clear, `InkExport`).
                let suffix = type == .member && key == "head" ? "head" : (key == "sketch" ? "png" : "jpg")
                // Named by key as well: a Member record has a head AND a
                // photo, and one path for both let each overwrite the other.
                // And by the record's change tag, so a new head is a new
                // file: a phone that had unpacked the old one under the same
                // name kept drawing it forever (2026-10-02).
                let tag = record.recordChangeTag ?? "0"
                // "crew-picture", never "crew": the store writes its own
                // "crew-<uuid>.jpg" in this folder, and the sweep below must
                // not reach it.
                let stem = type == .crew ? "crew-picture" : "\(record.recordID.recordName)-\(key)"
                let url = directory.appending(path: "\(folder)/\(crew.rawValue)/\(stem)-\(tag).\(suffix)")
                do {
                    let manager = FileManager.default
                    let parent = url.deletingLastPathComponent()
                    try manager.createDirectory(at: parent, withIntermediateDirectories: true)
                    if !manager.fileExists(atPath: url.path) {
                        try manager.copyItem(at: source, to: url)
                    }
                    // The versions before this one, and anything unpacked
                    // from them, go.
                    for old in (try? manager.contentsOfDirectory(atPath: parent.path)) ?? []
                    where old.hasPrefix("\(stem)-") && old != url.lastPathComponent
                        && old != url.deletingPathExtension().lastPathComponent {
                        try? manager.removeItem(at: parent.appending(path: old))
                    }
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
        case .asset(let url): CKAsset(fileURL: CrewFiles.here(url))
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
