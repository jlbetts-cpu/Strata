import CloudKit
import Foundation
import os

/// **Crews in the app's public CloudKit database, sealed end to end** (the
/// unification pass, 2026-10-09; the reasoning, in plain words, is
/// `tasks/unification-log.md` §1).
///
/// It replaces the zone-and-share cloud, which kept every crew in its
/// starter's private iCloud: a full iCloud stopped crews from starting
/// ("Quota exceeded") and every friend's post counted against the starter's
/// storage. Here a crew counts against nobody's iCloud.
///
/// **One record type, `CrewItem`, in the public default zone**: `crew` (the
/// crew's random ID, queryable), `kind` (the crew record type, queryable),
/// `box` (every other field, sealed with the crew's key, bound to the
/// record's name) and `a`/`b` (photos, heads and drawings, each sealed).
/// Security roles do the rest: anyone may create, only a record's creator
/// may change or delete it, and what anyone may read is sealed.
///
/// **No zones, no change feed**, so: one query for everything changed in
/// all of this phone's crews since it last looked, an occasional full list
/// of names to notice deletions, and the crew on screen asking for its own
/// changes. Ending a crew is a mark on its record; removing someone is a
/// removal record; both are read by every phone, which forgets and tidies
/// its own posts.
@MainActor
final class PublicCrewCloud: CrewCloud {
    private static let log = Logger(subsystem: "Strata", category: "crews.public")
    static let recordType = CrewItemRecord.type
    /// A removal's kind: the starter's word that someone is out.
    static let removalKind = "Removal"
    /// A member's change to the crew's name or picture. The crew record is
    /// its starter's and only they may write it; anyone may rename the crew
    /// (the owner's call, 2026-10-02), so a member's change is their own
    /// record, one each, and the newest one wins.
    static let editKind = "CrewEdit"
    static let editedAtKey = "editedAt"
    static let endedKey = "_ended"
    private static let creatorKey = "_creator"
    private static let editorKey = "_editor"

    let container: CKContainer
    private var database: CKDatabase { container.publicCloudDatabase }
    private(set) var myProfileID: UUID
    private var prepared = false
    private let directory: URL
    let keys: CrewKeyStore

    /// Every record of every crew, as fields, by "Type/name".
    private var cache: [CrewID: [String: RecordFields]] = [:]
    /// When each crew last asked for changes (server time, less a margin).
    private var since: [CrewID: Date] = [:]
    /// When the names of every record were last listed, to notice deletions.
    private var listedAt: Date = .distantPast
    static let listEvery: TimeInterval = 600
    /// What a "since" query overlaps the last one by: clocks and the
    /// server's index are not instant.
    static let overlap: TimeInterval = 120

    init(containerID: String? = nil, me: UUID? = nil, directory: URL? = nil, keys: CrewKeyStore = CrewKeyStore()) {
        container = CKContainer(identifier: containerID ?? SharedModelContainer.cloudKitContainerID)
        myProfileID = me ?? ProfileStore.profileID
        self.directory = directory ?? SocialStore.defaultDirectory
        self.keys = keys
        loadCache()
    }

    // MARK: Account and identity

    private func requireAccount() async throws {
        guard try await container.accountStatus() == .available else { throw CrewError.notSignedIn }
    }

    /// This phone's iCloud user, asked once a session.
    private var meRecordName: String?
    private func me() async throws -> String {
        if let meRecordName { return meRecordName }
        let name = try await container.userRecordID().recordName
        meRecordName = name
        return name
    }

    /// The identity record that makes two phones on one iCloud account one
    /// person, kept in the private database where it always was (a few
    /// bytes), and the crew keys' backup beside it.
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
            await restoreKeys()
            await clearLegacyZones()
        } catch {
            Self.log.error("identity not settled: \(error)")
        }
    }

    func reset() {
        cache.removeAll()
        since.removeAll()
        listedAt = .distantPast
        prepared = false
        keys.removeAll()
        pendingSave?.cancel()
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

    // MARK: Keys, backed up privately

    private static let keysRecordName = "crew-keys"

    /// Writes every crew key this phone holds into one small private record
    /// (best effort: a full iCloud refuses it, and the keys stay here).
    private func backUpKeys() async {
        let id = CKRecord.ID(recordName: Self.keysRecordName)
        let record = (try? await container.privateCloudDatabase.record(for: id)) ?? CKRecord(recordType: "CrewKeys", recordID: id)
        var text: [String] = []
        for (crew, key) in keys.all { text.append("\(crew.rawValue).\(key.linkText)") }
        record["keys"] = text.sorted().joined(separator: ",") as NSString
        do {
            _ = try await container.privateCloudDatabase.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
        } catch {
            Self.log.notice("crew keys not backed up: \(error)")
        }
    }

    /// Takes in the keys another phone of yours backed up.
    private func restoreKeys() async {
        let id = CKRecord.ID(recordName: Self.keysRecordName)
        guard let record = try? await container.privateCloudDatabase.record(for: id),
              let text = record["keys"] as? String else { return }
        for item in text.split(separator: ",") {
            guard let dot = item.lastIndex(of: ".") else { continue }
            let crew = CrewID(rawValue: String(item[..<dot]))
            if keys.key(for: crew) == nil, let key = CrewKey(linkText: String(item[item.index(after: dot)...])) {
                keys.set(key, for: crew)
            }
        }
    }

    // MARK: The old zones, cleared once

    private static let legacyKey = "crews.legacyZonesCleared"

    /// **The crews of builds up to 113 lived in zones in the starter's
    /// private iCloud** and counted against it. Once, the zones this phone
    /// started are deleted, which gives the space back, and the ones it
    /// joined are left. Test crews do not carry over (the unification log,
    /// §1, "Old crews").
    private func clearLegacyZones() async {
        guard !UserDefaults.standard.bool(forKey: Self.legacyKey) else { return }
        do {
            let mine = try await container.privateCloudDatabase.allRecordZones()
                .map(\.zoneID).filter { $0.zoneName.hasPrefix("crew-") }
            if !mine.isEmpty {
                _ = try await container.privateCloudDatabase.modifyRecordZones(saving: [], deleting: mine)
            }
            let joined = try await container.sharedCloudDatabase.allRecordZones()
                .map(\.zoneID).filter { $0.zoneName.hasPrefix("crew-") }
            if !joined.isEmpty {
                _ = try await container.sharedCloudDatabase.modifyRecordZones(saving: [], deleting: joined)
            }
            // The old silent pushes on the private and shared databases
            // fired for every change to your own wins too.
            _ = try? await container.privateCloudDatabase.modifySubscriptions(saving: [], deleting: ["crews-private"])
            _ = try? await container.sharedCloudDatabase.modifySubscriptions(saving: [], deleting: ["crews-shared"])
            UserDefaults.standard.set(true, forKey: Self.legacyKey)
            try? FileManager.default.removeItem(at: directory.appending(path: "cloud-cache.json"))
        } catch {
            Self.log.notice("old crew zones not cleared yet: \(error)")
        }
    }

    // MARK: Crews

    /// A new crew is a key and a link; its records are written by
    /// `SocialStore` through `save`, as before.
    func createZone(_ crew: Crew) async throws -> URL {
        try await requireAccount()
        let key = CrewKey.new()
        keys.set(key, for: crew.id)
        since[crew.id] = .distantPast
        Task { await backUpKeys() }
        return CrewInviteLink.url(crew: crew.id, key: key)
    }

    func shareURL(for crew: CrewID) async throws -> URL {
        guard let key = keys.key(for: crew) else { throw CrewError.unknownCrew }
        return CrewInviteLink.url(crew: crew, key: key)
    }

    /// Joining is keeping the key: the crew is read with it, and `SocialStore`
    /// writes your Member record. A crew that is not there (ended, or a
    /// mistyped link) leaves no key behind.
    func accept(_ invite: CrewInvite) async throws -> CrewID {
        try await requireAccount()
        guard let (crew, key) = CrewInviteLink.read(invite.url) else { throw CrewError.unknownCrew }
        let had = keys.key(for: crew)
        keys.set(key, for: crew)
        do {
            try await sync(crew, full: true)
        } catch {
            if had == nil { keys.set(nil, for: crew) }
            throw error
        }
        guard let found = cachedCrew(crew), !isEnded(crew) else {
            if had == nil { forget(crew) }
            throw CrewError.unknownCrew
        }
        Task { await backUpKeys() }
        return found.id
    }

    func fetchCrews() async throws -> [Crew] {
        try await requireAccount()
        await refreshBans()
        let mine = Array(keys.all.keys)
        let listing = Date().timeIntervalSince(listedAt) > Self.listEvery
        do {
            try await syncAll(mine, full: listing)
            if listing { listedAt = Date() }
        } catch {
            Self.log.error("crews sync failed: \(error)")
        }
        await subscribe(to: mine)
        var crews: [Crew] = []
        for crew in mine {
            if isEnded(crew) || isRemoved(myProfileID, from: crew) {
                await tidyAway(crew)
                continue
            }
            if let found = cachedCrew(crew) { crews.append(found) }
        }
        saveCache()
        return crews.sorted { $0.createdAt < $1.createdAt }
    }

    func fetchCrew(_ crew: CrewID) async throws -> Crew? {
        guard keys.key(for: crew) != nil, !isEnded(crew) else { return nil }
        return cachedCrew(crew)
    }

    func syncOnly(_ crew: CrewID) async throws -> Bool {
        guard keys.key(for: crew) != nil else { return false }
        let changed = try await sync(crew, full: false)
        if changed { saveCache() }
        return changed
    }

    func fetchWins(in crew: CrewID) async throws -> [SharedWin] {
        records(.sharedWin, in: crew).compactMap { fields in
            CrewRecords.sharedWin(fields, crew: crew).flatMap { keep(fields, from: $0.senderProfileID, in: crew) ? $0 : nil }
        }
    }

    func fetchReactions(in crew: CrewID) async throws -> [Reaction] {
        records(.reaction, in: crew).compactMap { fields in
            CrewRecords.reaction(fields, crew: crew).flatMap { keep(fields, from: $0.profileID, in: crew) ? $0 : nil }
        }
    }

    func fetchMessages(in crew: CrewID) async throws -> [CrewMessage] {
        records(.message, in: crew).compactMap { fields in
            CrewRecords.message(fields, crew: crew).flatMap { keep(fields, from: $0.senderProfileID, in: crew) ? $0 : nil }
        }
    }

    private func records(_ type: CrewRecordType, in crew: CrewID) -> [RecordFields] {
        (cache[crew] ?? [:]).filter { $0.key.hasPrefix(type.rawValue + "/") }.map(\.value)
    }

    /// A record is kept when its writer is the member it claims to be, and
    /// that member is neither removed nor banned.
    private func keep(_ fields: RecordFields, from profileID: UUID, in crew: CrewID) -> Bool {
        guard !isRemoved(profileID, from: crew) else { return false }
        if let writer = fields[Self.creatorKey]?.string, banned.contains(writer) { return false }
        guard let writer = fields[Self.creatorKey]?.string,
              let member = account(of: profileID, in: crew) else { return true }
        return writer == member
    }

    private func cachedCrew(_ crew: CrewID) -> Crew? {
        let records = cache[crew] ?? [:]
        guard var fields = records["\(CrewRecordType.crew.rawValue)/\(CrewRecords.crewRecordName)"] else { return nil }
        // A member's newer name or picture over the starter's, when newer
        // than the starter's own last change.
        if let edit = latestEdit(crew),
           (edit[Self.editedAtKey]?.date ?? .distantPast) > (fields[Self.editedAtKey]?.date ?? .distantPast) {
            fields["name"] = edit["name"]
            fields["photo"] = edit["photo"]
        }
        // The crew record's writer is its starter: a crew record claiming an
        // owner who did not write it is not believed.
        let members = records.filter { $0.key.hasPrefix(CrewRecordType.member.rawValue + "/") }
            .values.compactMap { fields -> CrewMember? in
                if let user = fields[Self.creatorKey]?.string, banned.contains(user) { return nil }
                guard let member = CrewRecords.member(fields), !isRemoved(member.profileID, from: crew) else { return nil }
                return member
            }
        return CrewRecords.crew(fields, id: crew, members: members)
    }

    private func isEnded(_ crew: CrewID) -> Bool {
        cache[crew]?["\(CrewRecordType.crew.rawValue)/\(CrewRecords.crewRecordName)"]?[Self.endedKey] != nil
    }

    private func isRemoved(_ profileID: UUID, from crew: CrewID) -> Bool {
        guard let removal = cache[crew]?["\(Self.removalKind)/\(profileID.uuidString)"] else { return false }
        // Only the starter's word removes anyone.
        let starter = cache[crew]?["\(CrewRecordType.crew.rawValue)/\(CrewRecords.crewRecordName)"]?[Self.creatorKey]?.string
        return starter != nil && removal[Self.creatorKey]?.string == starter
    }

    /// Who wrote a member's record, as an iCloud user: what reports and
    /// authenticity are checked against.
    func account(of profileID: UUID, in crew: CrewID) -> String? {
        cache[crew]?["\(CrewRecordType.member.rawValue)/\(profileID.uuidString)"]?[Self.creatorKey]?.string
    }

    /// Who last changed the crew's name or picture, for a report of either.
    func lastEditor(of crew: CrewID) -> String? {
        let starter = crewRecord(crew)
        if let edit = latestEdit(crew),
           (edit[Self.editedAtKey]?.date ?? .distantPast) > (starter?[Self.editedAtKey]?.date ?? .distantPast) {
            return edit[Self.creatorKey]?.string
        }
        return starter?[Self.editorKey]?.string
    }

    // MARK: Writing

    static func recordName(crew: CrewID, kind: String, name: String) -> String {
        CrewItemRecord.name(crew: crew.rawValue, kind: kind, name: name)
    }

    func save(_ fields: RecordFields, type: CrewRecordType, name: String, in crew: CrewID) async throws {
        if type == .crew, let starter = crewRecord(crew)?[Self.creatorKey]?.string,
           let writer = try? await me(), starter != writer {
            var edit = fields.filter { $0.key == "name" || $0.key == "photo" }
            edit[Self.editedAtKey] = .date(Date())
            try await write(edit, kind: Self.editKind, name: writer, in: crew)
            return
        }
        var fields = fields
        if type == .crew { fields[Self.editedAtKey] = .date(Date()) }
        try await write(fields, kind: type.rawValue, name: name, in: crew)
    }

    private func crewRecord(_ crew: CrewID) -> RecordFields? {
        cache[crew]?["\(CrewRecordType.crew.rawValue)/\(CrewRecords.crewRecordName)"]
    }

    /// The newest change to the crew's name or picture by anyone still in
    /// it, starter included (their own crew record's modification counts as
    /// theirs through `editedAt` when they set it).
    private func latestEdit(_ crew: CrewID) -> RecordFields? {
        (cache[crew] ?? [:]).filter { $0.key.hasPrefix(Self.editKind + "/") }.values
            .filter { fields in
                guard let writer = fields[Self.creatorKey]?.string else { return false }
                return !banned.contains(writer) && !isRemovedAccount(writer, from: crew)
            }
            .max { ($0[Self.editedAtKey]?.date ?? .distantPast) < ($1[Self.editedAtKey]?.date ?? .distantPast) }
    }

    private func isRemovedAccount(_ account: String, from crew: CrewID) -> Bool {
        (cache[crew] ?? [:]).contains { key, fields in
            key.hasPrefix(CrewRecordType.member.rawValue + "/") && fields[Self.creatorKey]?.string == account
                && (CrewRecords.member(fields).map { isRemoved($0.profileID, from: crew) } ?? false)
        }
    }

    private func write(_ fields: RecordFields, kind: String, name: String, in crew: CrewID) async throws {
        guard let key = keys.key(for: crew) else { throw CrewError.unknownCrew }
        let recordName = Self.recordName(crew: crew, kind: kind, name: name)
        let record = CKRecord(recordType: Self.recordType, recordID: CKRecord.ID(recordName: recordName))
        record["crew"] = crew.rawValue as NSString
        record["kind"] = kind as NSString
        // The cache's bookkeeping (who wrote it, who edited it) is the
        // server's to say, never sealed into the post.
        let posted = fields.filter { $0.key == Self.endedKey || !$0.key.hasPrefix("_") }
        let sealed = try CrewItemBox.seal(posted, key: key, recordName: recordName, folder: directory.appending(path: "Outgoing"))
        record["box"] = sealed.box as NSData
        for (slot, url) in sealed.assets { record[slot] = CKAsset(fileURL: url) }
        defer { for url in sealed.assets.values { try? FileManager.default.removeItem(at: url) } }
        let result = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
        if case .failure(let error)? = result.saveResults[record.recordID] { throw error }
        var kept = fields
        if let known = cache[crew]?["\(kind)/\(name)"]?[Self.creatorKey] {
            kept[Self.creatorKey] = known
        } else if let writer = try? await me() {
            kept[Self.creatorKey] = .string(writer)
        }
        cache[crew, default: [:]]["\(kind)/\(name)"] = kept
        saveCache()
    }

    func delete(type: CrewRecordType, name: String, in crew: CrewID) async throws {
        try await remove(kind: type.rawValue, name: name, in: crew)
    }

    private func remove(kind: String, name: String, in crew: CrewID) async throws {
        let id = CKRecord.ID(recordName: Self.recordName(crew: crew, kind: kind, name: name))
        let result = try await database.modifyRecords(saving: [], deleting: [id])
        if case .failure(let error)? = result.deleteResults[id],
           (error as? CKError)?.code != .unknownItem { throw error }
        cache[crew]?["\(kind)/\(name)"] = nil
        saveCache()
    }

    /// Leaving: every record of yours in the crew goes, then its key.
    func leave(_ crew: CrewID) async throws {
        try await deleteMine(in: crew)
        forget(crew)
    }

    /// Ending: the starter's crew record is marked, which every phone reads
    /// as the end; then their own records go.
    func endCrew(_ crew: CrewID) async throws {
        guard var fields = cache[crew]?["\(CrewRecordType.crew.rawValue)/\(CrewRecords.crewRecordName)"],
              let starter = fields[Self.creatorKey]?.string,
              starter == (try? await me()) else {
            // A crew whose record never reached the server (a start that
            // failed half way) has nothing to mark: its key just goes.
            if cache[crew]?["\(CrewRecordType.crew.rawValue)/\(CrewRecords.crewRecordName)"] == nil {
                forget(crew)
                return
            }
            throw CrewError.notOwner
        }
        fields[Self.endedKey] = .date(Date())
        fields[Self.creatorKey] = nil
        try await write(fields, kind: CrewRecordType.crew.rawValue, name: CrewRecords.crewRecordName, in: crew)
        try? await deleteMine(in: crew, keepingCrewRecord: true)
        forget(crew)
    }

    /// The starter's removal: one record every phone reads.
    func removeParticipant(_ profileID: UUID, from crew: CrewID) async throws {
        try await write(["profileID": .uuid(profileID)], kind: Self.removalKind, name: profileID.uuidString, in: crew)
    }

    /// Every record this phone's iCloud user wrote in a crew.
    private func deleteMine(in crew: CrewID, keepingCrewRecord: Bool = false) async throws {
        let me = try await me()
        let mine = (cache[crew] ?? [:]).filter { key, fields in
            fields[Self.creatorKey]?.string == me
                && !(keepingCrewRecord && key == "\(CrewRecordType.crew.rawValue)/\(CrewRecords.crewRecordName)")
        }.keys
        let ids = mine.compactMap { key -> CKRecord.ID? in
            guard let slash = key.firstIndex(of: "/") else { return nil }
            return CKRecord.ID(recordName: Self.recordName(crew: crew, kind: String(key[..<slash]),
                                                           name: String(key[key.index(after: slash)...])))
        }
        guard !ids.isEmpty else { return }
        for chunk in stride(from: 0, to: ids.count, by: 200).map({ Array(ids[$0..<min($0 + 200, ids.count)]) }) {
            _ = try await database.modifyRecords(saving: [], deleting: chunk)
        }
    }

    /// A crew that ended, or that you were removed from: your posts go and
    /// the crew is forgotten on this phone.
    private func tidyAway(_ crew: CrewID) async {
        try? await deleteMine(in: crew)
        forget(crew)
    }

    private func forget(_ crew: CrewID) {
        keys.set(nil, for: crew)
        cache[crew] = nil
        since[crew] = nil
        saveCache()
        Task { await backUpKeys() }
    }

    // MARK: Syncing

    /// Everything changed in `crews` since each last asked; with `full`,
    /// also the list of every record's name, to notice deletions.
    private func syncAll(_ crews: [CrewID], full: Bool) async throws {
        guard !crews.isEmpty else { return }
        // A crew never synced on this phone is read whole; the rest only for
        // what changed. Deletions are found by a names-only listing, which
        // never downloads a box or a photo again.
        let fresh = crews.filter { since[$0] == nil || since[$0] == .distantPast }
        let known = crews.filter { !fresh.contains($0) }
        if !fresh.isEmpty {
            _ = try await read(NSPredicate(format: "crew IN %@", fresh.map(\.rawValue)))
        }
        if let start = known.compactMap({ since[$0] }).min() {
            let cutoff = start.addingTimeInterval(-Self.overlap)
            _ = try await read(NSPredicate(format: "crew IN %@ AND modificationDate > %@",
                                           known.map(\.rawValue), cutoff as NSDate))
        }
        let now = Date()
        for crew in crews { since[crew] = now }
        if full, !known.isEmpty {
            dropMissing(try await listNames(NSPredicate(format: "crew IN %@", known.map(\.rawValue))), in: known)
        }
    }

    /// Every record's name a query matches, and nothing else: no box, no
    /// photo is downloaded.
    private func listNames(_ predicate: NSPredicate) async throws -> [CrewID: Set<String>] {
        let query = CKQuery(recordType: Self.recordType, predicate: predicate)
        let keys = ["crew", "kind"]
        var seen: [CrewID: Set<String>] = [:]
        func note(_ results: [(CKRecord.ID, Result<CKRecord, Error>)]) {
            for (id, result) in results {
                guard let record = try? result.get(), let crew = record["crew"] as? String,
                      let kind = record["kind"] as? String else { continue }
                let prefix = "\(crew)~\(kind)~"
                guard id.recordName.hasPrefix(prefix) else { continue }
                seen[CrewID(rawValue: crew), default: []].insert("\(kind)/\(id.recordName.dropFirst(prefix.count))")
            }
        }
        var page = try await database.records(matching: query, desiredKeys: keys, resultsLimit: CKQueryOperation.maximumResults)
        note(page.matchResults)
        while let cursor = page.queryCursor {
            page = try await database.records(continuingMatchFrom: cursor, desiredKeys: keys,
                                              resultsLimit: CKQueryOperation.maximumResults)
            note(page.matchResults)
        }
        return seen
    }

    @discardableResult
    private func sync(_ crew: CrewID, full: Bool) async throws -> Bool {
        let last = since[crew] ?? .distantPast
        let cutoff = full || last == .distantPast ? Date.distantPast : last.addingTimeInterval(-Self.overlap)
        let predicate = cutoff == .distantPast
            ? NSPredicate(format: "crew == %@", crew.rawValue)
            : NSPredicate(format: "crew == %@ AND modificationDate > %@", crew.rawValue, cutoff as NSDate)
        let before = cache[crew]
        let seen = try await read(predicate)
        since[crew] = Date()
        if cutoff == .distantPast { dropMissing(seen, in: [crew]) }
        return cache[crew] != before
    }

    /// Reads every page a query matches into the cache. Returns the names
    /// it saw, by crew.
    private func read(_ predicate: NSPredicate) async throws -> [CrewID: Set<String>] {
        let query = CKQuery(recordType: Self.recordType, predicate: predicate)
        var seen: [CrewID: Set<String>] = [:]
        var page = try await database.records(matching: query, resultsLimit: CKQueryOperation.maximumResults)
        while true {
            for (_, result) in page.matchResults {
                guard let record = try? result.get() else { continue }
                if let (crew, key) = take(record) { seen[crew, default: []].insert(key) }
            }
            guard let cursor = page.queryCursor else { break }
            page = try await database.records(continuingMatchFrom: cursor, resultsLimit: CKQueryOperation.maximumResults)
        }
        return seen
    }

    /// Opens one record into the cache. A box that will not open (a wrong
    /// or missing key) is skipped, never shown.
    private func take(_ record: CKRecord) -> (CrewID, String)? {
        guard let crewText = record["crew"] as? String, let kind = record["kind"] as? String,
              let sealed = record["box"] as? Data else { return nil }
        let crew = CrewID(rawValue: crewText)
        guard let key = keys.key(for: crew) else { return nil }
        let recordName = record.recordID.recordName
        let prefix = "\(crew.rawValue)~\(kind)~"
        guard recordName.hasPrefix(prefix) else { return nil }
        let name = String(recordName.dropFirst(prefix.count))
        let cacheKey = "\(kind)/\(name)"
        var sources: [String: URL] = [:]
        for slot in CrewItemBox.slots { if let url = (record[slot] as? CKAsset)?.fileURL { sources[slot] = url } }
        let type = CrewRecordType(rawValue: kind)
        let folder = type == .member ? "Heads" : "Photos"
        let tag = record.recordChangeTag ?? "0"
        guard var fields = try? CrewItemBox.open(sealed, assets: sources, key: key, recordName: recordName,
                                                 into: directory.appending(path: "\(folder)/\(crew.rawValue)"),
                                                 stem: type == .crew ? "crew-picture-\(tag)" : "\(name)-\(tag)",
                                                 family: type == .crew ? "crew-picture-" : "\(name)-") else {
            Self.log.notice("crew item not opened: \(recordName, privacy: .public)")
            return nil
        }
        if let creator = record.creatorUserRecordID { fields[Self.creatorKey] = .string(creator.recordName) }
        if type == .crew, let editor = record.lastModifiedUserRecordID {
            fields[Self.editorKey] = .string(editor.recordName)
        }
        cache[crew, default: [:]][cacheKey] = fields
        return (crew, cacheKey)
    }

    /// After a full listing, whatever the server no longer has goes, with
    /// the files it brought.
    private func dropMissing(_ seen: [CrewID: Set<String>], in crews: [CrewID]) {
        for crew in crews {
            let present = seen[crew] ?? []
            for (key, fields) in cache[crew] ?? [:] where !present.contains(key) {
                for asset in fields.values.compactMap(\.asset) { try? FileManager.default.removeItem(at: asset) }
                cache[crew]?[key] = nil
            }
        }
    }

    // MARK: The silent push that says a crew changed

    static let subscriptionID = "crews-public"
    private static let subscribedKey = "crews.subscribedTo"

    /// One query subscription on `CrewItem` for every crew this phone is
    /// in, silent, so a friend's post refreshes the crews in the background.
    /// Saved again only when the set of crews changes.
    private func subscribe(to crews: [CrewID]) async {
        let ids = crews.map(\.rawValue).sorted()
        guard ids != (UserDefaults.standard.stringArray(forKey: Self.subscribedKey) ?? []) else { return }
        do {
            if ids.isEmpty {
                _ = try await database.modifySubscriptions(saving: [], deleting: [Self.subscriptionID])
            } else {
                let subscription = CKQuerySubscription(recordType: Self.recordType,
                                                       predicate: NSPredicate(format: "crew IN %@", ids),
                                                       subscriptionID: Self.subscriptionID,
                                                       options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion])
                let info = CKSubscription.NotificationInfo()
                info.shouldSendContentAvailable = true
                subscription.notificationInfo = info
                _ = try await database.modifySubscriptions(saving: [subscription], deleting: [])
            }
            UserDefaults.standard.set(ids, forKey: Self.subscribedKey)
        } catch {
            Self.log.notice("crew subscription not saved: \(error)")
        }
    }

    // MARK: Bans (public, read only)

    private var banned = Set(UserDefaults.standard.stringArray(forKey: PublicCrewCloud.bansKey) ?? [])
    private var bansCheckedAt = Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: PublicCrewCloud.bansCheckedKey))
    private static let bansKey = "crews.bans"
    private static let bansCheckedKey = "crews.bansCheckedAt"
    static let bansInterval: TimeInterval = 86_400
    static let bansOnOpenInterval: TimeInterval = 300
    private static let bansPageLimit = 100

    func refreshModeration(force: Bool) async -> Bool { await refreshBans(force: force) }

    @discardableResult
    func refreshBans(force: Bool = false) async -> Bool {
        let elapsed = Date().timeIntervalSince(bansCheckedAt)
        guard elapsed > (force ? Self.bansOnOpenInterval : Self.bansInterval) else { return false }
        let query = CKQuery(recordType: "Ban", predicate: NSPredicate(value: true))
        let keys = ["account"]
        var found: Set<String> = []
        func keep(_ results: [(CKRecord.ID, Result<CKRecord, Error>)]) {
            for (_, result) in results {
                if let account = (try? result.get())?["account"] as? String { found.insert(account) }
            }
        }
        do {
            var page = try await database.records(matching: query, desiredKeys: keys,
                                                  resultsLimit: CKQueryOperation.maximumResults)
            keep(page.matchResults)
            var pages = 1
            while let cursor = page.queryCursor, pages < Self.bansPageLimit {
                page = try await database.records(continuingMatchFrom: cursor, desiredKeys: keys,
                                                  resultsLimit: CKQueryOperation.maximumResults)
                keep(page.matchResults)
                pages += 1
            }
        } catch {
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

    // MARK: Pings (public, unchanged)

    func ping(_ fields: [String: String]) async throws -> String {
        let name = "ping-\(UUID().uuidString)"
        let record = CKRecord(recordType: CrewPingRecord.type, recordID: CKRecord.ID(recordName: name))
        for (key, value) in fields { record[key] = value as NSString }
        let result = try await database.modifyRecords(saving: [record], deleting: [])
        if case .failure(let error)? = result.saveResults[record.recordID] { throw error }
        return name
    }

    func deletePings(_ names: [String]) async {
        guard !names.isEmpty else { return }
        do {
            _ = try await database.modifyRecords(saving: [], deleting: names.map { CKRecord.ID(recordName: $0) })
        } catch {
            Self.log.notice("pings not deleted: \(error)")
        }
    }

    func listen(for plan: CrewPingPlan) async throws {
        let ids = [CrewPingPlan.winsID, CrewPingPlan.reactionsID]
        let removed = try await database.modifySubscriptions(saving: [], deleting: ids)
        for (id, result) in removed.deleteResults {
            if case .failure(let error) = result, (error as? CKError)?.code != .unknownItem {
                Self.log.notice("ping subscription \(id, privacy: .public) not removed: \(error)")
            }
        }
        var saving: [CKSubscription] = []
        if !plan.winCrews.isEmpty {
            saving.append(Self.subscription(CrewPingPlan.winsID, plan.winsPredicate, fallback: CrewPingRecord.fallbackWin))
        }
        if !plan.reactionCrews.isEmpty {
            saving.append(Self.subscription(CrewPingPlan.reactionsID, plan.reactionsPredicate,
                                            fallback: CrewPingRecord.fallbackReaction))
        }
        guard !saving.isEmpty else { return }
        let saved = try await database.modifySubscriptions(saving: saving, deleting: [])
        for (_, result) in saved.saveResults {
            if case .failure(let error) = result { throw error }
        }
    }

    private static func subscription(_ id: String, _ predicate: NSPredicate, fallback: String) -> CKQuerySubscription {
        let subscription = CKQuerySubscription(recordType: CrewPingRecord.type, predicate: predicate,
                                               subscriptionID: id, options: [.firesOnRecordCreation])
        let info = CKSubscription.NotificationInfo()
        info.alertBody = fallback
        info.soundName = "default"
        info.shouldSendMutableContent = true
        info.desiredKeys = CrewPingRecord.fields
        subscription.notificationInfo = info
        return subscription
    }

    /// The notification extension reads a crew's items from the public
    /// database by name, opened with the key in the app group; there is no
    /// zone to point it at.
    func zoneLocation(of crew: CrewID) -> (owner: String, joined: Bool)? {
        keys.key(for: crew) == nil ? nil : ("public", true)
    }

    // MARK: The cache, on disk

    nonisolated private struct Saved: Codable, Sendable {
        var cache: [String: [String: RecordFields]]
        var since: [String: Date]
    }

    private var cacheURL: URL { directory.appending(path: "public-crews-cache.json") }

    private func loadCache() {
        guard let data = try? Data(contentsOf: cacheURL),
              let saved = try? JSONDecoder().decode(Saved.self, from: data) else { return }
        for (key, records) in saved.cache { cache[CrewID(rawValue: key)] = records }
        for (key, date) in saved.since { since[CrewID(rawValue: key)] = date }
    }

    private func saveCache() {
        var saved = Saved(cache: [:], since: [:])
        for (crew, records) in cache { saved.cache[crew.rawValue] = records }
        for (crew, date) in since { saved.since[crew.rawValue] = date }
        pendingSave?.cancel()
        let url = cacheURL, folder = directory, log = Self.log
        pendingSave = Task.detached(priority: .utility) {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try JSONEncoder().encode(saved).write(to: url, options: .atomic)
            } catch {
                log.error("crew cache not written: \(error)")
            }
        }
    }

    private var pendingSave: Task<Void, Never>?
}

/// **What goes into a `CrewItem`, sealed**: every field but the files as one
/// JSON box, and each file sealed on its own into a numbered slot. Pure, so
/// it is tested without CloudKit.
nonisolated enum CrewItemBox {
    static let slots = ["a", "b"]
    private static let slotKey = "_slots"

    struct Sealed { var box: Data; var assets: [String: URL] }

    /// Seals `fields` for the record named `recordName`; files go to
    /// `folder` as sealed copies for upload.
    static func seal(_ fields: RecordFields, key: CrewKey, recordName: String, folder: URL) throws -> Sealed {
        var plain: RecordFields = [:]
        var assets: [String: URL] = [:]
        var slotOf: [String] = []
        for (name, value) in fields.sorted(by: { $0.key < $1.key }) {
            if case .asset(let url) = value {
                guard slotOf.count < slots.count else { continue }
                let slot = slots[slotOf.count]
                let data = try Data(contentsOf: CrewFiles.here(url))
                let sealed = try key.seal(data, context: "\(recordName)#\(slot)")
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let out = folder.appending(path: "\(UUID().uuidString).sealed")
                try sealed.write(to: out, options: .atomic)
                assets[slot] = out
                slotOf.append(name)
            } else {
                plain[name] = value
            }
        }
        plain[slotKey] = .string(slotOf.joined(separator: ","))
        let json = try JSONEncoder().encode(plain)
        return Sealed(box: try key.seal(json, context: recordName), assets: assets)
    }

    /// Opens a box and its files; each file is written opened to `folder`,
    /// named `stem-<field>.<ext>`.
    static func open(_ box: Data, assets: [String: URL], key: CrewKey, recordName: String,
                     into folder: URL, stem: String, family: String? = nil) throws -> RecordFields {
        let json = try key.open(box, context: recordName)
        var fields = try JSONDecoder().decode(RecordFields.self, from: json)
        let names = (fields[slotKey]?.string ?? "").split(separator: ",").map(String.init)
        fields[slotKey] = nil
        for (index, name) in names.enumerated() where index < slots.count {
            let slot = slots[index]
            guard let source = assets[slot] else { continue }
            let sealed = try Data(contentsOf: source)
            let data = try key.open(sealed, context: "\(recordName)#\(slot)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let ext = name == "head" ? "head" : (name == "sketch" ? "png" : "jpg")
            let out = folder.appending(path: "\(stem)-\(name).\(ext)")
            if !FileManager.default.fileExists(atPath: out.path) { try data.write(to: out, options: .atomic) }
            fields[name] = .asset(out)
        }
        // An older version's files, superseded by this one, go.
        if let family, !names.isEmpty,
           let present = try? FileManager.default.contentsOfDirectory(atPath: folder.path) {
            for file in present where file.hasPrefix(family) && !file.hasPrefix(stem) {
                try? FileManager.default.removeItem(at: folder.appending(path: file))
            }
        }
        return fields
    }
}
