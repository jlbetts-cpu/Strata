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
    /// **Your own word that you left**, one small sealed record that stays
    /// in the crew (found 2026-10-10 by the second review). Leaving deleted
    /// your records and the key, and a second phone of yours, which still
    /// held the key, saw you missing and wrote you back in. The key backup
    /// carries the leaving too, but only between phones that share an
    /// iCloud Keychain; this needs nothing but the crew itself. Joining
    /// again by a link takes it away.
    static let leftKind = "Left"
    static let editedAtKey = "editedAt"
    static let endedKey = "_ended"
    private static let creatorKey = "_creator"
    private static let editorKey = "_editor"
    /// The server's change tag of the copy in the cache, so a record read
    /// again unchanged is not opened or downloaded again.
    private static let tagKey = "_tag"
    /// When the server last took the record: what `CrewLeaving` compares.
    private static let modKey = "_modAt"

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

    /// Who wrote a record, as an account name. **CloudKit names your own
    /// records' writer `__defaultOwner__`**, not your account, on every read
    /// (found 2026-10-10 by review): compared with `me()` it never matched,
    /// so a starter could not end their own crew, nothing of yours was ever
    /// deleted on leaving, and your own fresh post failed its writer check
    /// for a cycle. `read` asks `me()` first, so it is known here.
    private func owner(_ id: CKRecord.ID?) -> String? {
        guard let name = id?.recordName else { return nil }
        return name == CKCurrentUserDefaultName ? (meRecordName ?? name) : name
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
            await syncKeys()
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
        // Another iCloud account may sign in next, in this same process.
        meRecordName = nil
        writtenAt.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.keyedAtKey)
        UserDefaults.standard.removeObject(forKey: Self.leftAtKey)
        UserDefaults.standard.removeObject(forKey: Self.unreadableSinceKey)
        UserDefaults.standard.removeObject(forKey: Self.answeredKey)
        joining.removeAll()
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
    private static let keyedAtKey = "crews.keyedAt"
    private static let leftAtKey = "crews.leftAt"

    private func times(_ key: String) -> [String: Double] {
        UserDefaults.standard.dictionary(forKey: key) as? [String: Double] ?? [:]
    }

    private func setTime(_ time: Double?, for crew: CrewID, in key: String) {
        var all = times(key)
        all[crew.rawValue] = time
        UserDefaults.standard.set(all, forKey: key)
    }

    private var syncingKeys = false
    private var keysChangedMeanwhile = false

    /// **This account's crew keys, merged with its other phones'**
    /// (`CrewKeyBackup`): keys they hold are taken, crews left anywhere are
    /// dropped here, and what is written back is sealed with a key from the
    /// iCloud Keychain (`CrewKeyWrap`), never the keys in the clear. Best
    /// effort: a full iCloud refuses the write, and the keys stay here.
    private func syncKeys() async {
        guard !syncingKeys else { keysChangedMeanwhile = true; return }
        syncingKeys = true
        defer {
            syncingKeys = false
            if keysChangedMeanwhile {
                keysChangedMeanwhile = false
                Task { await syncKeys() }
            }
        }
        let id = CKRecord.ID(recordName: Self.keysRecordName)
        let db = container.privateCloudDatabase
        let record: CKRecord
        do {
            record = try await db.record(for: id)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: "CrewKeys", recordID: id)
        } catch {
            // Not read (no signal): never written over blind.
            Self.log.notice("crew keys not read: \(error)")
            return
        }
        let stored = record["keys"] as? String ?? ""
        var plain = CrewKeyWrap.open(stored)
        if plain == nil {
            // Sealed by another phone whose key has not reached this one:
            // left as it is, for a week. A key that never comes (iCloud
            // Keychain off, or lost) must not stop backups for ever, so
            // after that this phone's own keys replace it.
            let defaults = UserDefaults.standard
            let first = defaults.double(forKey: Self.unreadableSinceKey)
            let now = Date().timeIntervalSince1970
            if first == 0 { defaults.set(now, forKey: Self.unreadableSinceKey) }
            guard first > 0, now - first > Self.unreadableFor else { return }
            plain = ""
        }
        UserDefaults.standard.removeObject(forKey: Self.unreadableSinceKey)
        guard let plain else { return }
        var local = CrewKeyBackup.Local(keyedAt: times(Self.keyedAtKey), leftAt: times(Self.leftAtKey))
        for (crew, key) in keys.all { local.keys[crew.rawValue] = key.linkText }
        let merged = CrewKeyBackup.merge(local: local, remote: CrewKeyBackup.parse(plain),
                                         now: Date().timeIntervalSince1970)
        // **Everything this decides is written before anything else is
        // awaited** (the third read): the times were written back wholesale
        // after a delete had been awaited, so a join that finished in that
        // moment had its time wiped and was forgotten on the next run.
        var mine: [CKRecord.ID] = []
        for crew in merged.forget {
            // Left on another phone of yours: what this phone wrote there
            // since goes too, named while the cache still says what it is.
            let id = CrewID(rawValue: crew)
            mine += mineIDs(in: id, keepingCrewRecord: true)
            dropLocally(id)
        }
        for (crew, text) in merged.take {
            if let key = CrewKey(linkText: text) { keys.set(key, for: CrewID(rawValue: crew)) }
        }
        UserDefaults.standard.set(merged.out.keyedAt, forKey: Self.keyedAtKey)
        UserDefaults.standard.set(merged.out.left, forKey: Self.leftAtKey)
        for chunk in stride(from: 0, to: mine.count, by: 200).map({ Array(mine[$0..<min($0 + 200, mine.count)]) }) {
            _ = try? await database.modifyRecords(saving: [], deleting: chunk)
        }
        let text = CrewKeyBackup.text(merged.out)
        guard text != plain || !stored.hasPrefix(CrewKeyWrap.prefix) else { return }
        // Nothing to say and nothing there: no record is made for it.
        guard !(text.isEmpty && stored.isEmpty) else { return }
        guard let sealed = CrewKeyWrap.seal(text, with: CrewKeyWrap.key()) else { return }
        record["keys"] = sealed as NSString
        do {
            _ = try await db.modifyRecords(saving: [record], deleting: [], savePolicy: .ifServerRecordUnchanged)
        } catch {
            Self.log.notice("crew keys not backed up: \(error)")
        }
    }

    private static let unreadableSinceKey = "crews.backupUnreadableSince"
    static let unreadableFor: TimeInterval = 7 * 86_400

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
        setTime(Date().timeIntervalSince1970, for: crew.id, in: Self.keyedAtKey)
        setTime(nil, for: crew.id, in: Self.leftAtKey)
        since[crew.id] = .distantPast
        Task { await syncKeys() }
        return CrewInviteLink.url(crew: crew.id, key: key)
    }

    func shareURL(for crew: CrewID) async throws -> URL {
        guard let key = keys.key(for: crew) else { throw CrewError.unknownCrew }
        return CrewInviteLink.url(crew: crew, key: key)
    }

    /// Joining is keeping the key: the crew is read with it, and `SocialStore`
    /// writes your Member record. A crew that is not there (ended, or a
    /// mistyped link) leaves no key behind.
    ///
    /// **A link never replaces a key that works** (found 2026-10-10 by
    /// review). It replaced the key first and checked after, so a link for a
    /// crew you were in with the wrong key after the `#` (a mangled paste, or
    /// one made on purpose by anyone who knew the crew's id) kept the wrong
    /// key, opened nothing, and emptied that crew off the phone.
    func accept(_ invite: CrewInvite) async throws -> CrewID {
        try await requireAccount()
        guard let (crew, key) = CrewInviteLink.read(invite.url) else { throw CrewError.unknownCrew }
        let had = keys.key(for: crew)
        let before = (since: since[crew], keyedAt: times(Self.keyedAtKey)[crew.rawValue],
                      leftAt: times(Self.leftAtKey)[crew.rawValue])
        // **Joined now, before anything is awaited** (the third read). The
        // key went in first and its time after the read, so a key sync that
        // ran in between saw a key older than the leaving, dropped it, and
        // the join failed with "this crew has ended" until tapped again.
        setTime(Date().timeIntervalSince1970, for: crew, in: Self.keyedAtKey)
        setTime(nil, for: crew, in: Self.leftAtKey)
        joining.insert(crew)
        defer { joining.remove(crew) }
        /// As it was before the link.
        func putBack() {
            if let had {
                keys.set(had, for: crew)
                since[crew] = before.since
                setTime(before.keyedAt, for: crew, in: Self.keyedAtKey)
            } else {
                dropLocally(crew)
            }
            setTime(before.leftAt, for: crew, in: Self.leftAtKey)
        }
        if had != nil, cachedCrew(crew) != nil, !isEnded(crew) {
            // Already in it, with a key that works: the link's key is not
            // needed, and its tap still counts as joining (below).
            _ = try? await sync(crew, full: false)
        } else {
            keys.set(key, for: crew)
            do {
                try await sync(crew, full: true)
            } catch {
                putBack()
                throw error
            }
            guard cachedCrew(crew) != nil, !isEnded(crew) else {
                putBack()
                throw CrewError.unknownCrew
            }
        }
        // Every word of yours that you left, in view now, is answered by
        // this join (`CrewLeaving`), and tidied away when it can be.
        let notes = myLeftNotes(in: crew).map(\.key)
        var answered = UserDefaults.standard.dictionary(forKey: Self.answeredKey) as? [String: [String]] ?? [:]
        answered[crew.rawValue] = notes
        UserDefaults.standard.set(answered, forKey: Self.answeredKey)
        for key in notes { try? await remove(kind: Self.leftKind, name: String(key.dropFirst(Self.leftKind.count + 1)), in: crew) }
        Task { await syncKeys() }
        return crew
    }

    /// A crew just read and not joined: off this phone, and nothing in the
    /// crew touched (`CrewCloud.decline`).
    func decline(_ crew: CrewID) async {
        dropLocally(crew)
    }

    /// Crews whose link is being opened right now: not judged left until
    /// the join has answered the notes it found.
    private var joining: Set<CrewID> = []
    private static let answeredKey = "crews.leftNotesAnswered"

    func fetchCrews() async throws -> [Crew] {
        try await requireAccount()
        await refreshBans()
        let listing = Date().timeIntervalSince(listedAt) > Self.listEvery
        // A crew left on another phone of yours is left here too, before
        // anything can put you back in it.
        if listing { await syncKeys() }
        let mine = Array(keys.all.keys)
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
            if let leftAt = leftAt(crew) {
                await tidyAway(crew, leftAt: leftAt)
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

    /// Your own notes that you left this crew, as cached.
    private func myLeftNotes(in crew: CrewID) -> [(key: String, fields: RecordFields)] {
        guard let me = meRecordName else { return [] }
        return (cache[crew] ?? [:]).filter { $0.key.hasPrefix(Self.leftKind + "/") && $0.value[Self.creatorKey]?.string == me }
            .map { ($0.key, $0.value) }
    }

    /// When this account left the crew, on any phone, or nil when it has
    /// not (`CrewLeaving`): the newest note's own time, as its writer's
    /// phone told it, so every phone records the same leaving.
    private func leftAt(_ crew: CrewID) -> Double? {
        guard !joining.contains(crew) else { return nil }
        let notes = myLeftNotes(in: crew)
        guard !notes.isEmpty else { return nil }
        let answered = Set((UserDefaults.standard.dictionary(forKey: Self.answeredKey) as? [String: [String]])?[crew.rawValue] ?? [])
        let mine = cache[crew]?["\(CrewRecordType.member.rawValue)/\(myProfileID.uuidString)"]
        let member: CrewLeaving.Member = mine == nil ? .none
            : (mine?[Self.modKey]?.date).map { .at($0) } ?? .justWritten
        let counted = notes.map { CrewLeaving.Note(name: $0.key, written: $0.fields[Self.modKey]?.date) }
        guard CrewLeaving.isLeft(notes: counted, answered: answered, member: member) else { return nil }
        return notes.compactMap { $0.fields["at"]?.date?.timeIntervalSince1970 }.max() ?? Date().timeIntervalSince1970
    }

    private func isRemoved(_ profileID: UUID, from crew: CrewID) -> Bool {
        // Only the starter's word removes anyone, under any name it was
        // written with (`removeParticipant`).
        guard let starter = cache[crew]?["\(CrewRecordType.crew.rawValue)/\(CrewRecords.crewRecordName)"]?[Self.creatorKey]?.string
        else { return false }
        let exact = "\(Self.removalKind)/\(profileID.uuidString)"
        return (cache[crew] ?? [:]).contains { key, fields in
            (key == exact || key.hasPrefix(exact + ".")) && fields[Self.creatorKey]?.string == starter
        }
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
            // **A name nobody can take first.** It was the writer's account
            // alone, which anyone who knew the crew's id could create ahead
            // of them, and the server then refused the real one for ever.
            let name = "\(writer).\(Self.suffix())"
            try await write(edit, kind: Self.editKind, name: name, in: crew)
            // One each: this writer's older changes go.
            let older = (cache[crew] ?? [:]).filter { key, fields in
                key.hasPrefix(Self.editKind + "/") && key != "\(Self.editKind)/\(name)"
                    && fields[Self.creatorKey]?.string == writer
            }.keys
            for key in older { try? await remove(kind: Self.editKind, name: String(key.dropFirst(Self.editKind.count + 1)), in: crew) }
            return
        }
        // **Your member record is never written into a crew you have left**
        // (the third read). Queued writes go out before a refresh reads the
        // crew, so a phone that had not yet seen your other phone's leaving
        // could write you back in, and a member record newer than the note
        // reads as a rejoin. The crew is read first, and a leaving in it
        // refuses the write; the refresh that follows tidies up.
        if type == .member, name == myProfileID.uuidString {
            _ = try? await sync(crew, full: false)
            if leftAt(crew) != nil { throw CrewError.unknownCrew }
        }
        var fields = fields
        if type == .crew { fields[Self.editedAtKey] = .date(Date()) }
        try await write(fields, kind: type.rawValue, name: name, in: crew)
    }

    private static func suffix() -> String { String(UUID().uuidString.prefix(8)) }

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
        // The cache's bookkeeping (who wrote it, who edited it) is the
        // server's to say, never sealed into the post.
        let posted = fields.filter { $0.key == Self.endedKey || !$0.key.hasPrefix("_") }
        let sealed = try CrewItemBox.seal(posted, key: key, recordName: recordName, folder: directory.appending(path: "Outgoing"))
        defer { for url in sealed.assets.values { try? FileManager.default.removeItem(at: url) } }
        // **A file that is going is cleared on the server's own copy** (the
        // third read). A blank set on a record never fetched may leave the
        // server's file where it is, and a photo someone took off must not
        // stay; so when a file is going the record is fetched, and the
        // blank is a change to it the server cannot miss. Never a delete
        // first: a save that then failed would have left the crew without
        // its own record, for everyone, with nothing to bring it back.
        let id = CKRecord.ID(recordName: recordName)
        let hadFiles = cache[crew]?["\(kind)/\(name)"]?.values.compactMap(\.asset).count ?? 0
        var record = CKRecord(recordType: Self.recordType, recordID: id)
        if hadFiles > sealed.assets.count, let onServer = try? await database.record(for: id) { record = onServer }
        record["crew"] = crew.rawValue as NSString
        record["kind"] = kind as NSString
        record["box"] = sealed.box as NSData
        for slot in CrewItemBox.slots {
            record[slot] = sealed.assets[slot].map { CKAsset(fileURL: $0) }
        }
        let result = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
        if case .failure(let error)? = result.saveResults[record.recordID] { throw error }
        var kept = fields
        if let known = cache[crew]?["\(kind)/\(name)"]?[Self.creatorKey] {
            kept[Self.creatorKey] = known
        } else if let writer = try? await me() {
            kept[Self.creatorKey] = .string(writer)
        }
        cache[crew, default: [:]]["\(kind)/\(name)"] = kept
        writtenAt["\(crew.rawValue)|\(kind)/\(name)"] = Date()
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
        // **The note first, and it has to be written** (the third read):
        // last and best effort, a note that failed left a leaving your other
        // phone would quietly undo. A leave that cannot say so fails here,
        // to be tried again.
        let me = try await me()
        try await write(["at": .date(Date())], kind: Self.leftKind, name: "\(me).\(Self.suffix())", in: crew)
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
        // Under a name nobody can take first (see `save`): a removal named
        // by the profile alone could be created ahead of the starter by the
        // person it was for, and then they could never be removed.
        try await write(["profileID": .uuid(profileID)], kind: Self.removalKind,
                        name: "\(profileID.uuidString).\(Self.suffix())", in: crew)
    }

    /// Every record this phone's iCloud user wrote in a crew.
    private func deleteMine(in crew: CrewID, keepingCrewRecord: Bool = false) async throws {
        _ = try await me()
        let ids = mineIDs(in: crew, keepingCrewRecord: keepingCrewRecord)
        guard !ids.isEmpty else { return }
        for chunk in stride(from: 0, to: ids.count, by: 200).map({ Array(ids[$0..<min($0 + 200, ids.count)]) }) {
            _ = try await database.modifyRecords(saving: [], deleting: chunk)
        }
    }

    /// The names of what this account wrote in a crew, from the cache.
    /// Never its word that it left, which is what keeps it out.
    private func mineIDs(in crew: CrewID, keepingCrewRecord: Bool) -> [CKRecord.ID] {
        guard let me = meRecordName else { return [] }
        let mine = (cache[crew] ?? [:]).filter { key, fields in
            fields[Self.creatorKey]?.string == me
                && !key.hasPrefix(Self.leftKind + "/")
                && !(keepingCrewRecord && key == "\(CrewRecordType.crew.rawValue)/\(CrewRecords.crewRecordName)")
        }.keys
        return mine.compactMap { key -> CKRecord.ID? in
            guard let slash = key.firstIndex(of: "/") else { return nil }
            return CKRecord.ID(recordName: Self.recordName(crew: crew, kind: String(key[..<slash]),
                                                           name: String(key[key.index(after: slash)...])))
        }
    }

    /// A crew that ended, or that you were removed from: your posts go and
    /// the crew is forgotten on this phone.
    ///
    /// **Never the crew's own record** (found 2026-10-10 by the second
    /// review): it carries the mark that says the crew ended, and the
    /// starter's second phone, tidying up, deleted it before every member
    /// had read it. They never saw the end, so their posts stayed.
    private func tidyAway(_ crew: CrewID, leftAt: Double? = nil) async {
        try? await deleteMine(in: crew, keepingCrewRecord: true)
        forget(crew, at: leftAt)
    }

    /// Leaving a crew for good, on every phone of yours: the key goes and
    /// the leaving is written down, so no older copy of the key brings the
    /// crew back (`CrewKeyBackup`).
    private func forget(_ crew: CrewID, at leftAt: Double? = nil) {
        setTime(leftAt ?? Date().timeIntervalSince1970, for: crew, in: Self.leftAtKey)
        dropLocally(crew)
        Task { await syncKeys() }
    }

    /// The crew off this phone, and nothing said about it.
    private func dropLocally(_ crew: CrewID) {
        keys.set(nil, for: crew)
        setTime(nil, for: crew, in: Self.keyedAtKey)
        var answered = UserDefaults.standard.dictionary(forKey: Self.answeredKey) as? [String: [String]] ?? [:]
        answered[crew.rawValue] = nil
        UserDefaults.standard.set(answered, forKey: Self.answeredKey)
        cache[crew] = nil
        since[crew] = nil
        saveCache()
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
            mark(try await read(NSPredicate(format: "crew IN %@", fresh.map(\.rawValue))))
        }
        // **Each crew from its own moment** (found 2026-10-10 by the second
        // review): one query from the oldest of them made a quiet crew's
        // three-week-old "since" re-read every row of a busy one, every
        // refresh. At most five crews, so at most five small queries.
        for crew in known {
            guard let start = since[crew] else { continue }
            mark(try await read(NSPredicate(format: "crew == %@ AND modificationDate > %@", crew.rawValue,
                                            start.addingTimeInterval(-Self.overlap) as NSDate)))
        }
        if full, !known.isEmpty {
            // Only a listing that saw every row can say what is gone.
            let listing = try await listNames(NSPredicate(format: "crew IN %@", known.map(\.rawValue)))
            if listing.complete { dropMissing(listing.seen, in: known) }
        }
    }

    /// **"Since" is the server's own time of the newest record read, never
    /// this phone's clock** (found 2026-10-10 by review). It was `Date()`
    /// taken after the read: a phone whose clock ran two minutes fast, or a
    /// first read that took longer than the overlap while a friend posted,
    /// asked next time for changes after a moment the missing post was
    /// before, and never saw it.
    ///
    /// **And never past a record that did not arrive.** A record whose
    /// fetch failed is asked for again next time: "since" stops a second
    /// short of the oldest one that failed.
    private func mark(_ result: ReadResult) {
        guard !result.incomplete else { return }
        for (crew, newest) in result.newest {
            var to = max(since[crew] ?? .distantPast, newest)
            if let failed = result.failedFrom[crew] { to = min(to, failed.addingTimeInterval(-1)) }
            since[crew] = to
        }
    }

    /// Every record's name a query matches, and nothing else: no box, no
    /// photo is downloaded.
    private func listNames(_ predicate: NSPredicate) async throws -> (seen: [CrewID: Set<String>], complete: Bool) {
        let query = CKQuery(recordType: Self.recordType, predicate: predicate)
        let keys = ["crew", "kind"]
        var seen: [CrewID: Set<String>] = [:]
        var complete = true
        func note(_ results: [(CKRecord.ID, Result<CKRecord, Error>)]) {
            for (id, result) in results {
                guard let record = try? result.get() else { complete = false; continue }
                guard let crew = record["crew"] as? String,
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
        return (seen, complete)
    }

    @discardableResult
    private func sync(_ crew: CrewID, full: Bool) async throws -> Bool {
        let last = since[crew] ?? .distantPast
        let cutoff = full || last == .distantPast ? Date.distantPast : last.addingTimeInterval(-Self.overlap)
        let predicate = cutoff == .distantPast
            ? NSPredicate(format: "crew == %@", crew.rawValue)
            : NSPredicate(format: "crew == %@ AND modificationDate > %@", crew.rawValue, cutoff as NSDate)
        let before = cache[crew]
        let result = try await read(predicate)
        mark(result)
        // Only a read that saw every row can say what is gone.
        if cutoff == .distantPast, !result.incomplete { dropMissing(result.seen, in: [crew]) }
        return cache[crew] != before
    }

    private struct ReadResult {
        /// Every record the server has that the query matched, by crew,
        /// whether or not this phone could open it.
        var seen: [CrewID: Set<String>] = [:]
        /// The newest server modification time of a record that is now in
        /// the cache, by crew. Not of one this phone could not open: a wrong
        /// key must not move "since" past records it never read.
        var newest: [CrewID: Date] = [:]
        /// The oldest record whose files could not be fetched, by crew.
        var failedFrom: [CrewID: Date] = [:]
        /// A row came back as an error: nothing is known about what it was.
        var incomplete = false
    }

    /// Reads every page a query matches into the cache.
    ///
    /// **Boxes first, photographs only for boxes that open** (2026-10-10).
    /// Anyone signed in to iCloud can write a `CrewItem` under a crew's id;
    /// without the key it is unreadable and is skipped, but the query used
    /// to bring every record's files down with it, so junk written at a crew
    /// would have been downloaded by every member on every sync. A record
    /// read again unchanged (`tagKey`) costs nothing but its row.
    private func read(_ predicate: NSPredicate) async throws -> ReadResult {
        // `owner` needs it, and `take` is not async. Without it nothing is
        // read: a record of yours taken in as somebody else's stays wrong.
        _ = try await me()
        let query = CKQuery(recordType: Self.recordType, predicate: predicate)
        let boxOnly = ["crew", "kind", "box"]
        var out = ReadResult()
        var withFiles: [CKRecord.ID: (crew: CrewID, at: Date)] = [:]
        func arrived(_ crew: CrewID, _ at: Date?) {
            if let at { out.newest[crew] = max(out.newest[crew] ?? .distantPast, at) }
        }
        func note(_ record: CKRecord) {
            guard let crewText = record["crew"] as? String, let kind = record["kind"] as? String else { return }
            let crew = CrewID(rawValue: crewText)
            let prefix = "\(crewText)~\(kind)~"
            let recordName = record.recordID.recordName
            guard let key = keys.key(for: crew), recordName.hasPrefix(prefix) else { return }
            let cacheKey = "\(kind)/\(recordName.dropFirst(prefix.count))"
            out.seen[crew, default: []].insert(cacheKey)
            if let tag = record.recordChangeTag, cache[crew]?[cacheKey]?[Self.tagKey]?.string == tag {
                arrived(crew, record.modificationDate)
                return
            }
            guard let sealed = record["box"] as? Data,
                  let files = CrewItemBox.fileCount(sealed, key: key, recordName: recordName) else {
                Self.log.notice("crew item not opened: \(recordName, privacy: .public)")
                return
            }
            if files > 0 {
                withFiles[record.recordID] = (crew, record.modificationDate ?? .distantPast)
            } else if take(record) != nil {
                arrived(crew, record.modificationDate)
            }
        }
        func page(_ results: [(CKRecord.ID, Result<CKRecord, Error>)]) {
            for (_, result) in results {
                switch result {
                case .success(let record): note(record)
                case .failure: out.incomplete = true
                }
            }
        }
        var next = try await database.records(matching: query, desiredKeys: boxOnly,
                                              resultsLimit: CKQueryOperation.maximumResults)
        while true {
            page(next.matchResults)
            guard let cursor = next.queryCursor else { break }
            next = try await database.records(continuingMatchFrom: cursor, desiredKeys: boxOnly,
                                              resultsLimit: CKQueryOperation.maximumResults)
        }
        let ids = Array(withFiles.keys)
        for chunk in stride(from: 0, to: ids.count, by: 50).map({ Array(ids[$0..<min($0 + 50, ids.count)]) }) {
            for (id, result) in try await database.records(for: chunk) {
                guard let (crew, at) = withFiles[id] else { continue }
                switch result {
                case .success(let record):
                    // Fetched and not opened (its file could not be kept, a
                    // full disk): asked for again, like one not fetched.
                    if take(record) != nil {
                        arrived(crew, record.modificationDate)
                    } else {
                        out.failedFrom[crew] = min(out.failedFrom[crew] ?? .distantFuture, at)
                    }
                case .failure(let error):
                    // Deleted between the two reads: nothing to wait for.
                    if (error as? CKError)?.code == .unknownItem { continue }
                    out.failedFrom[crew] = min(out.failedFrom[crew] ?? .distantFuture, at)
                }
            }
        }
        return out
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
        if let creator = owner(record.creatorUserRecordID) { fields[Self.creatorKey] = .string(creator) }
        if type == .crew, let editor = owner(record.lastModifiedUserRecordID) {
            fields[Self.editorKey] = .string(editor)
        }
        // A copy whose writer could not be named is read again next time.
        let unnamed = fields[Self.creatorKey]?.string == CKCurrentUserDefaultName
        if let tag = record.recordChangeTag, !unnamed { fields[Self.tagKey] = .string(tag) }
        if let at = record.modificationDate { fields[Self.modKey] = .date(at) }
        cache[crew, default: [:]][cacheKey] = fields
        return (crew, cacheKey)
    }

    /// When this phone last wrote each record, by "crew|Type/name".
    private var writtenAt: [String: Date] = [:]
    /// How long a record this phone just wrote is safe from `dropMissing`:
    /// the public database's queries trail its saves by a few seconds.
    static let settle: TimeInterval = 90

    /// After a full listing, whatever the server no longer has goes, with
    /// the files it brought. **Not what this phone wrote a moment ago**
    /// (found 2026-10-10 by review): a listing run straight after a save can
    /// come back without it, and the new crew, or the win just sent, was
    /// deleted here, photo and all, until the next sync put it back.
    private func dropMissing(_ seen: [CrewID: Set<String>], in crews: [CrewID]) {
        let now = Date()
        writtenAt = writtenAt.filter { now.timeIntervalSince($0.value) < Self.settle }
        for crew in crews {
            let present = seen[crew] ?? []
            for (key, fields) in cache[crew] ?? [:] where !present.contains(key) {
                if writtenAt["\(crew.rawValue)|\(key)"] != nil { continue }
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
        // **A cache that names you by iCloud's placeholder is read again
        // whole** (`owner`): a build from before the placeholder was
        // understood wrote it, and nothing else would ever re-read those
        // records, so its starter still could not end their crew.
        for (crew, records) in cache where records.values.contains(where: { $0[Self.creatorKey]?.string == CKCurrentUserDefaultName }) {
            since[crew] = nil
            for key in records.keys { cache[crew]?[key]?[Self.tagKey] = nil }
        }
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

    /// How many files a box says it came with, or nil for a box this key
    /// does not open. Asked before any file is downloaded.
    static func fileCount(_ box: Data, key: CrewKey, recordName: String) -> Int? {
        guard let json = try? key.open(box, context: recordName),
              let fields = try? JSONDecoder().decode(RecordFields.self, from: json) else { return nil }
        return (fields[slotKey]?.string ?? "").split(separator: ",").count
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
