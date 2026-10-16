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
    /// Which of the crew's keys the cached copy was sealed with
    /// (`CrewKey.mark`), for telling a record from before a re-key.
    private static let sealKey = "_sealedWith"
    /// A rekey record's own bytes, as cached (`CrewRekey`).
    private static let rawKey = "raw"

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

    /// The copy of this account's crew keys and identity that outlives the
    /// app on the phone (`CrewVault`).
    private let vault: CrewVault

    init(containerID: String? = nil, me: UUID? = nil, directory: URL? = nil, keys: CrewKeyStore = CrewKeyStore(),
         vault: CrewVault = .keychain) {
        container = CKContainer(identifier: containerID ?? SharedModelContainer.cloudKitContainerID)
        myProfileID = me ?? ProfileStore.profileID
        self.directory = directory ?? SocialStore.defaultDirectory
        self.keys = keys
        self.vault = vault
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

    /// **Who this account is in its crews**, settled before anything else:
    /// the one profile id that makes two phones on one iCloud account, or
    /// the same phone after the app was deleted, the same person.
    ///
    /// Kept in two places. The private database's record is the one every
    /// phone of yours has always read. The Keychain's (`CrewVault`) is new
    /// (2026-10-10): the private record needs iCloud storage, and with a
    /// full iCloud it was never written, so a reinstall made you a stranger
    /// to your own crews. That failure also stopped everything after it,
    /// every launch; now it is one line in the log.
    func prepare() async {
        guard !prepared else { return }
        do {
            guard try await container.accountStatus() == .available else { return }
            let account = try await me()
            func adopt(_ who: UUID) {
                guard who != myProfileID else { return }
                UserDefaults.standard.set(who.uuidString, forKey: ProfileStore.profileIDKey)
                myProfileID = who
            }
            let id = CKRecord.ID(recordName: "sturdy-identity")
            let db = container.privateCloudDatabase
            var theirs: UUID?
            var absent = false
            do {
                let record = try await db.record(for: id)
                theirs = (record["profileID"] as? String).flatMap(UUID.init(uuidString:))
            } catch let error as CKError where error.code == .unknownItem {
                absent = true
            } catch {
                Self.log.notice("identity not read from iCloud: \(error)")
            }
            // **A phone that has already been someone stays that someone**
            // (found by review, 2026-10-10). The Keychain's word is taken
            // only by a phone that has not yet acted under its own id: with
            // a full iCloud two phones of one account had each joined as
            // their own person, and one adopting the other's id now would
            // leave its old self behind in every crew as a second you.
            // Private iCloud's word is taken as it always was.
            let kept = vault.identity(for: account)
            if let theirs {
                adopt(theirs)
            } else if let kept, !hasActed {
                adopt(kept)
            } else if kept == nil, !absent {
                // Not read, and nothing kept here: another phone of yours
                // may already be someone. Never settled blind.
                return
            }
            var saved = false
            if theirs == nil {
                // Best effort: `.ifServerRecordUnchanged` on a new record
                // never writes over one that is there.
                let record = CKRecord(recordType: "Identity", recordID: id)
                record["profileID"] = myProfileID.uuidString as NSString
                do {
                    let result = try await db.modifyRecords(saving: [record], deleting: [], savePolicy: .ifServerRecordUnchanged)
                    if case .failure(let error)? = result.saveResults[id] { throw error }
                    saved = true
                } catch let error as CKError where error.code == .quotaExceeded {
                    // A full iCloud: the Keychain is where it is kept, once
                    // this phone is known to be you (below).
                    Self.log.notice("identity not saved to iCloud: it is full")
                } catch let error as CKError where error.code == .serverRecordChanged {
                    // Another phone of yours was first, a moment ago. Read
                    // again next time and be who it says.
                    Self.log.notice("identity settled elsewhere first")
                    return
                } catch {
                    Self.log.notice("identity not saved to iCloud yet: \(error)")
                }
            }
            // **Into the Keychain only when it is known to be you**: said by
            // private iCloud, saved there just now, or already yours in a
            // crew. An id made a moment ago on a phone that holds nothing is
            // not written (found by review): it travels to your other
            // phones, and one of them could have taken it for who you are.
            // Such a phone learns who it is from its crews
            // (`settleIdentityFromCrews`), or becomes someone by joining one.
            if theirs != nil || (kept == nil && (saved || hasActed)) {
                vault.setIdentity(myProfileID, for: account)
            }
            prepared = true
            await syncKeys()
            await clearLegacyZones()
        } catch {
            Self.log.error("identity not settled: \(error)")
        }
    }

    /// Whether this phone has been its own person in a crew: a member
    /// record under its id is in what it has read.
    private var hasActed: Bool {
        let mine = "\(CrewRecordType.member.rawValue)/\(myProfileID.uuidString)"
        return cache.values.contains { $0[mine] != nil }
    }

    /// **Who this account already is in its crews**, when this phone is
    /// nobody yet: the profile its own member records are filed under. A
    /// second phone whose Keychain had not caught up, or a reinstall with
    /// nothing kept, reads its crews, finds itself in them, and is that
    /// person, before anything can write it in as a second one
    /// (`SocialStore.repairMissingMembership`).
    private func settleIdentityFromCrews() {
        guard let account = meRecordName, !hasActed else { return }
        let prefix = CrewRecordType.member.rawValue + "/"
        var count: [UUID: Int] = [:]
        for (crew, records) in cache where keys.key(for: crew) != nil {
            for (key, fields) in records where key.hasPrefix(prefix) && fields[Self.creatorKey]?.string == account {
                if let id = UUID(uuidString: String(key.dropFirst(prefix.count))) { count[id, default: 0] += 1 }
            }
        }
        // The one in the most crews; the same answer on every phone.
        guard let who = count.max(by: { ($0.value, $1.key.uuidString) < ($1.value, $0.key.uuidString) })?.key,
              who != myProfileID else { return }
        UserDefaults.standard.set(who.uuidString, forKey: ProfileStore.profileIDKey)
        myProfileID = who
        if vault.identity(for: account) == nil { vault.setIdentity(who, for: account) }
        Self.log.notice("identity taken from this account's own member records")
    }

    /// Bumped by `reset`, so work that was waiting on iCloud when the
    /// account changed does not finish for the account that left.
    private var epoch = 0

    func reset() {
        epoch += 1
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
        wantsReseal.removeAll()
        rekeying.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.wantsRekeyKey)
        UserDefaults.standard.removeObject(forKey: Self.agreeTriedKey)
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
    /// iCloud Keychain (`CrewKeyWrap`), never the keys in the clear. A full
    /// iCloud refuses that write, so the same text is kept in the Keychain
    /// itself (`CrewVault`), and the two copies are read as one.
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
        // Known before anything is forgotten: what this phone wrote in a
        // crew it is about to drop can only be named with it (the fourth
        // read: on a cold launch it was not known yet, and nothing was
        // deleted).
        let started = epoch
        let account = try? await me()
        let id = CKRecord.ID(recordName: Self.keysRecordName)
        let db = container.privateCloudDatabase
        // **The copy in your private iCloud**, when it can be read. Nil
        // means it said nothing this time (no signal, or sealed by another
        // phone whose key has not reached this one): then it is not written
        // over blind either.
        var record: CKRecord?
        var stored = ""
        var cloud: String?
        do {
            let found = try await db.record(for: id)
            record = found
            stored = found["keys"] as? String ?? ""
            cloud = CrewKeyWrap.open(stored)
            if cloud == nil {
                // Sealed by another phone whose key has not reached this
                // one: left as it is, for a week. A key that never comes
                // (iCloud Keychain off, or lost) must not stop backups for
                // ever, so after that this phone's own keys replace it.
                let defaults = UserDefaults.standard
                let first = defaults.double(forKey: Self.unreadableSinceKey)
                let now = Date().timeIntervalSince1970
                if first == 0 { defaults.set(now, forKey: Self.unreadableSinceKey) }
                if first > 0, now - first > Self.unreadableFor { cloud = "" }
            }
            if cloud != nil { UserDefaults.standard.removeObject(forKey: Self.unreadableSinceKey) }
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: "CrewKeys", recordID: id)
            cloud = ""
        } catch {
            Self.log.notice("crew keys not read from iCloud: \(error)")
        }
        // **And the copy in the Keychain** (`CrewVault`, 2026-10-10), which
        // needs no iCloud storage and outlives the app on the phone. It was
        // the iCloud copy alone, and when that could not be read or written
        // (a full iCloud never takes it) a reinstall had nothing to restore.
        // **Signed out while that was waiting** (found by review): the
        // private read fails, and this used to stop there. Going on with
        // the Keychain's copy would have put the keys just cleared straight
        // back, for whoever signs in next.
        guard epoch == started else { return }
        let kept = account.flatMap { vault.keys(for: $0) }
        guard cloud != nil || account != nil else { return }
        // **A crew being joined is not this sync's to judge or to back up**
        // (the fourth read): its key went into the backup mid-join, and a
        // join then turned away came back from there on the next sync.
        let held = times(Self.keyedAtKey)
        var local = CrewKeyBackup.Local(keyedAt: held, leftAt: times(Self.leftAtKey))
        for (crew, key) in keys.all where !joining.contains(crew) { local.keys[crew.rawValue] = key.linkText }
        let merged = CrewKeyBackup.plan(local: local, cloud: cloud, vault: kept, now: Date().timeIntervalSince1970)
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
        for (crew, text) in merged.take where !joining.contains(CrewID(rawValue: crew)) {
            guard let key = CrewKey(linkText: text) else { continue }
            let id = CrewID(rawValue: crew)
            if keys.key(for: id) != nil {
                // Only the key the starter's newest rekey names: "later" is
                // each phone's own clock, and a phone left on the old key
                // could otherwise pull this one back to it.
                // (With no crew record here at all there is nothing to
                // judge by and nothing to lose: the backup's is taken.)
                let rekeys = rekeysSeen(id).seen
                guard crewRecord(id) == nil
                        || (rekeys.contains(where: \.fromStarter) && CrewRekey.isCurrent(key, seen: rekeys)) else { continue }
                // The crew's new key, from another phone of yours: the one
                // held is kept for reading, and the crew is read again.
                keys.advance(to: key, for: id)
                since[id] = .distantPast
                wantsReseal.insert(id)
            } else {
                keys.set(key, for: id)
            }
        }
        var keyed = merged.out.keyedAt
        for crew in joining { keyed[crew.rawValue] = held[crew.rawValue] }
        UserDefaults.standard.set(keyed, forKey: Self.keyedAtKey)
        UserDefaults.standard.set(merged.out.left, forKey: Self.leftAtKey)
        for chunk in stride(from: 0, to: mine.count, by: 200).map({ Array(mine[$0..<min($0 + 200, mine.count)]) }) {
            _ = try? await database.modifyRecords(saving: [], deleting: chunk)
        }
        let text = CrewKeyBackup.text(merged.out)
        // The Keychain first: it cannot be refused for want of storage.
        if let account, text != (kept ?? "") { vault.setKeys(text, for: account) }
        // Then your private iCloud, only when it was read.
        guard let record, let plain = cloud else { return }
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
        joinBefore[crew] = before.leftAt
        /// As it was before the link.
        func putBack() {
            joining.remove(crew)
            joinBefore[crew] = nil
            if let had {
                keys.set(had, for: crew)
                since[crew] = before.since
                setTime(before.keyedAt, for: crew, in: Self.keyedAtKey)
            } else {
                dropLocally(crew)
            }
            setTime(before.leftAt, for: crew, in: Self.leftAtKey)
        }
        if let had, cachedCrew(crew) != nil, !isEnded(crew) {
            // Already in it, with a key that works: the link's key is not
            // needed, and its tap still counts as joining (`settle`).
            _ = try? await sync(crew, full: false)
            // **Unless the crew has moved to a new key this phone missed**
            // (the re-key review): then a fresh link is the way back, and
            // it carries the key the starter's newest rekey names.
            let rekeys = rekeysSeen(crew).seen
            if key != had, rekeys.contains(where: \.fromStarter),
               !CrewRekey.isCurrent(had, seen: rekeys), CrewRekey.isCurrent(key, seen: rekeys) {
                keys.advance(to: key, for: crew)
                since[crew] = .distantPast
                wantsReseal.insert(crew)
                _ = try? await sync(crew, full: true)
            }
        } else {
            keys.set(key, for: crew)
            do {
                try await sync(crew, full: true)
            } catch {
                putBack()
                throw error
            }
            guard cachedCrew(crew) != nil, !isEnded(crew) else {
                // Not read, which is not the same as not there: a crew
                // whose picture failed to download once was called ended.
                let unread = readFailed.contains(crew)
                putBack()
                throw unread ? CKError(.networkFailure) : CrewError.unknownCrew
            }
        }
        return crew
    }

    /// **The join went through**: your member record is written. Every word
    /// of yours that you left, in view now, is answered by it
    /// (`CrewLeaving`) and tidied away when it can be; the key may be
    /// backed up.
    func settle(_ crew: CrewID) async {
        guard joining.contains(crew) else { return }
        let notes = myLeftNotes(in: crew).map(\.key)
        var answered = UserDefaults.standard.dictionary(forKey: Self.answeredKey) as? [String: [String]] ?? [:]
        answered[crew.rawValue] = notes
        UserDefaults.standard.set(answered, forKey: Self.answeredKey)
        joining.remove(crew)
        joinBefore[crew] = nil
        for key in notes { try? await remove(kind: Self.leftKind, name: String(key.dropFirst(Self.leftKind.count + 1)), in: crew) }
        await syncKeys()
    }

    /// A crew just read and not joined: off this phone, as it was before the
    /// link, files and all, and nothing in the crew touched
    /// (`CrewCloud.decline`).
    func decline(_ crew: CrewID) async {
        let leftBefore = joinBefore[crew] ?? nil
        joining.remove(crew)
        joinBefore[crew] = nil
        dropLocally(crew)
        setTime(leftBefore, for: crew, in: Self.leftAtKey)
        for folder in ["Photos", "Heads"] {
            try? FileManager.default.removeItem(at: directory.appending(path: "\(folder)/\(crew.rawValue)"))
        }
    }

    /// What `leftAt` was before a join began, to put back if it is declined.
    private var joinBefore: [CrewID: Double?] = [:]
    /// Crews whose last read did not bring everything.
    private var readFailed: Set<CrewID> = []

    /// Crews being joined, from the link's tap until `settle` or `decline`:
    /// not judged left, and not backed up, until the join is one or the
    /// other.
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
        settleIdentityFromCrews()
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
            // Still in it: what this phone owes the crew, after the checks
            // above, never before (a member record written into a crew
            // being left would have read as joining it again).
            if !joining.contains(crew) { await keepUp(crew) }
            if let found = cachedCrew(crew) {
                crews.append(found)
            } else {
                // **Held and not read: read whole next time** (found by
                // review). A crew whose own record fell out of what this
                // phone holds was never asked for again, since only changes
                // are, and it stayed missing for good.
                since[crew] = nil
            }
        }
        saveCache()
        return crews.sorted { $0.createdAt < $1.createdAt }
    }

    /// The crews this phone still holds a key to, whether or not they
    /// could be read this time (`SocialStore.refreshOnce`).
    func heldCrews() -> Set<CrewID>? { Set(keys.all.keys) }

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

    /// **Strict, unlike other kinds** (the review, 2026-10-16): an invitation
    /// is kept only when its `from` is a member of this crew with a record of
    /// their own, and the account that wrote the invitation is that member's.
    /// `keep` lets a record through when the profile has no member record;
    /// here that would let anyone in the crew claim to be anyone.
    func fetchPersonals(in crew: CrewID) async throws -> [PersonalInvite] {
        records(.personal, in: crew).compactMap { fields in
            guard let invite = CrewRecords.personal(fields), !isRemoved(invite.from, from: crew),
                  let writer = fields[Self.creatorKey]?.string, !banned.contains(writer),
                  let member = account(of: invite.from, in: crew), writer == member,
                  keep(fields, from: invite.from, in: crew) else { return nil }
            return invite
        }
    }

    func memberPublicKey(_ profileID: UUID, in crew: CrewID) -> String? {
        guard !isRemoved(profileID, from: crew),
              let account = account(of: profileID, in: crew), !banned.contains(account),
              let text = cache[crew]?["\(CrewRecordType.member.rawValue)/\(profileID.uuidString)"]?[CrewAgreement.field]?.string,
              CrewRekey.isKey(text) else { return nil }
        return text
    }

    func openSealed(_ data: Data, info: Data) -> Data? {
        CrewAgreement.existing().flatMap { CrewSealedNote.open(data, with: $0, info: info) }
    }

    func fetchStories(in crew: CrewID) async throws -> [CrewStory] {
        records(.story, in: crew).compactMap { fields in
            CrewRecords.story(fields, crew: crew).flatMap { keep(fields, from: $0.sender, in: crew) ? $0 : nil }
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
        if let writer = fields[Self.creatorKey]?.string,
           hasLeft(account: writer, memberAt: cache[crew]?["\(CrewRecordType.member.rawValue)/\(profileID.uuidString)"]?[Self.modKey]?.date, in: crew) {
            return false
        }
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
        // Both sides no later than the server took them: a starter's clock
        // an hour ahead would otherwise block every rename for an hour.
        let starterSaid = min(fields[Self.editedAtKey]?.date ?? .distantPast, fields[Self.modKey]?.date ?? .distantFuture)
        if let edit = latestEdit(crew), (edit[Self.editedAtKey]?.date ?? .distantPast) > starterSaid {
            fields["name"] = edit["name"]
            fields["photo"] = edit["photo"]
        }
        let members = CrewRecords.withScores(memberRecords(in: crew).map(\.member), from: records) { fields, profile in
            keep(fields, from: profile, in: crew)
        }
        return CrewRecords.crew(fields, id: crew, members: members)
    }

    /// **The member records that count**, by one rule, for the crew's list
    /// and for who is sent a new key (the re-key review, 2026-10-10: the two
    /// had separate rules, and a record the list hid was still handed the
    /// crew's next key). A record counts when:
    /// - it is filed under its own profile's name;
    /// - its writer is not banned, has not left, and is not the account of
    ///   anyone the starter removed, under any profile;
    /// - its profile was not removed;
    /// - if written since the crew's key last changed, it is sealed with
    ///   the key it changed to: one under the key before is someone holding
    ///   only the old key (`CrewRekey`).
    private func memberRecords(in crew: CrewID) -> [(fields: RecordFields, member: CrewMember)] {
        let current = keys.key(for: crew)
        let gone = removedAccounts(in: crew)
        let prefix = CrewRecordType.member.rawValue + "/"
        return (cache[crew] ?? [:]).compactMap { key, fields in
            guard key.hasPrefix(prefix), let member = CrewRecords.member(fields),
                  key == prefix + member.profileID.uuidString else { return nil }
            if let user = fields[Self.creatorKey]?.string {
                if banned.contains(user) || gone.contains(user) { return nil }
                if hasLeft(account: user, memberAt: fields[Self.modKey]?.date, in: crew) { return nil }
            }
            if outdated(fields, in: crew, current: current) { return nil }
            guard !isRemoved(member.profileID, from: crew) else { return nil }
            return (fields, member)
        }
    }

    /// Whether a record was written under a key the crew had already left:
    /// sealed with a key that is not the crew's now, and written after the
    /// re-key that replaced THAT key. (Against the crew's latest re-key
    /// alone, a record written under the first key after the first re-key
    /// counted again as soon as there was a second.)
    private func outdated(_ fields: RecordFields, in crew: CrewID, current: CrewKey?) -> Bool {
        guard let sealedWith = fields[Self.sealKey]?.string, sealedWith != current?.mark,
              let at = fields[Self.modKey]?.date, let replaced = replacedAt(mark: sealedWith, in: crew) else { return false }
        return at > replaced
    }

    /// When the key with this mark stopped being the crew's: the starter's
    /// re-key after the one that made it, or the first re-key for the key
    /// the crew began with.
    private func replacedAt(mark: String, in crew: CrewID) -> Date? {
        let rekeys = rekeysSeen(crew).seen.filter(\.fromStarter).sorted { $0.at < $1.at }
        guard let made = rekeys.firstIndex(where: { $0.box.mark == mark }) else { return rekeys.first?.at }
        return made + 1 < rekeys.count ? rekeys[made + 1].at : nil
    }

    /// The accounts of everyone the starter removed, as their removals say.
    private func removedAccounts(in crew: CrewID) -> Set<String> {
        guard let starter = crewRecord(crew)?[Self.creatorKey]?.string else { return [] }
        return Set((cache[crew] ?? [:]).filter { $0.key.hasPrefix(Self.removalKind + "/") && $0.value[Self.creatorKey]?.string == starter }
            .compactMap { $0.value["account"]?.string })
    }

    private func isEnded(_ crew: CrewID) -> Bool {
        cache[crew]?["\(CrewRecordType.crew.rawValue)/\(CrewRecords.crewRecordName)"]?[Self.endedKey] != nil
    }

    /// **Someone who left is gone from the crew the moment their note is
    /// read** (the fourth read). Their deleted records are only noticed by
    /// the listing every ten minutes, so a friend who had left stayed in
    /// the crew, wins and all, for that long. Their note arrives with the
    /// next change read, and it is newer than the member record they
    /// deleted.
    private func hasLeft(account: String, memberAt: Date?, in crew: CrewID) -> Bool {
        let noted = (cache[crew] ?? [:])
            .filter { $0.key.hasPrefix(Self.leftKind + "/") && $0.value[Self.creatorKey]?.string == account }
            .compactMap { $0.value[Self.modKey]?.date }.max()
        guard let noted else { return false }
        return noted > (memberAt ?? .distantPast)
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
        // The same comparison `cachedCrew` makes, so a report of the name on
        // screen names whoever wrote that name.
        let starterSaid = min(starter?[Self.editedAtKey]?.date ?? .distantPast, starter?[Self.modKey]?.date ?? .distantFuture)
        if let edit = latestEdit(crew), (edit[Self.editedAtKey]?.date ?? .distantPast) > starterSaid {
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
            // The read has to succeed: unread, the write could land after a
            // leaving it never saw, and read as a rejoin for good.
            try await sync(crew, full: false)
            if leftAt(crew) != nil { throw CrewError.unknownCrew }
        }
        var fields = fields
        if type == .crew { fields[Self.editedAtKey] = .date(Date()) }
        // Your member record carries the public key a new crew key is sent
        // to you with (`CrewAgreement`): the one already there, or yours.
        if type == .member, name == myProfileID.uuidString {
            // This phone's, always: one left there by a phone whose private
            // half this one does not hold would never be replaced, and a
            // new crew key locked to it could not be opened here.
            fields[CrewAgreement.field] = CrewAgreement.publicText().map { .string($0) }
                ?? cache[crew]?["\(type.rawValue)/\(name)"]?[CrewAgreement.field]
        }
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
        // **From someone in the crew, under the crew's key, and no later
        // than the server says it was written** (the re-key review): an
        // edit was taken from any account under any key the phone held, at
        // whatever time it claimed, so a removed person could rename the
        // crew for good with a date in the year 2100.
        let people = Set(memberRecords(in: crew).compactMap { $0.fields[Self.creatorKey]?.string })
        let current = keys.key(for: crew)
        return (cache[crew] ?? [:]).filter { $0.key.hasPrefix(Self.editKind + "/") }.values
            .compactMap { fields -> RecordFields? in
                guard let writer = fields[Self.creatorKey]?.string, people.contains(writer), !banned.contains(writer) else { return nil }
                if outdated(fields, in: crew, current: current) { return nil }
                var edit = fields
                if let said = fields[Self.editedAtKey]?.date, let took = fields[Self.modKey]?.date, said > took {
                    edit[Self.editedAtKey] = .date(took)
                }
                return edit
            }
            .max { ($0[Self.editedAtKey]?.date ?? .distantPast) < ($1[Self.editedAtKey]?.date ?? .distantPast) }
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
        kept[Self.sealKey] = .string(key.mark)
        // The server's own tag and time for what was just saved: without
        // them a record this phone wrote looked newer than everything until
        // read back, and each photo sent was downloaded again at once.
        kept[Self.tagKey] = nil
        kept[Self.modKey] = nil
        if case .success(let saved)? = result.saveResults[record.recordID] {
            if let tag = saved.recordChangeTag { kept[Self.tagKey] = .string(tag) }
            if let at = saved.modificationDate { kept[Self.modKey] = .date(at) }
        }
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
        if !leavingSaid.contains(crew) { try await willLeave(crew) }
        try await deleteMine(in: crew)
        leavingSaid.remove(crew)
        forget(crew)
    }

    /// **The note that you left, first, and it has to be written.** Last
    /// and best effort, a note that failed left a leaving your other phone
    /// would quietly undo; and written after your posts were deleted, a
    /// failure in between left you in the crew without them. With the note
    /// down, whatever fails after it is finished by the next refresh
    /// (`leftAt`, `tidyAway`).
    func willLeave(_ crew: CrewID) async throws {
        let me = try await me()
        try await write(["at": .date(Date())], kind: Self.leftKind, name: "\(me).\(Self.suffix())", in: crew)
        leavingSaid.insert(crew)
    }

    private var leavingSaid: Set<CrewID> = []

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
        // With the removed person's account, so no other record of theirs
        // counts as a member either (`memberRecords`).
        // Read first, so someone who joined a moment ago is among those
        // staying (below) and is sent the new key.
        try await sync(crew, full: false)
        var removal: RecordFields = ["profileID": .uuid(profileID)]
        if let account = account(of: profileID, in: crew) { removal["account"] = .string(account) }
        // And who is staying, as of now: the new key goes to them and to
        // nobody who turns up, with the old link, before it is made.
        // Someone left out of the last removal's "staying" (they turned up
        // with the old link) stays out of this one, unless they have since
        // joined properly, under the crew's key now.
        let before = newestRemoval(in: crew)?["staying"]?.string.map { Set($0.split(separator: ",").map(String.init)) }
        let mark = keys.key(for: crew)?.mark
        let staying = memberRecords(in: crew).filter { record in
            guard record.member.profileID != profileID else { return false }
            guard let before, let writer = record.fields[Self.creatorKey]?.string else { return true }
            return before.contains(writer) || record.fields[Self.sealKey]?.string == mark
        }.compactMap { $0.fields[Self.creatorKey]?.string }
        removal["staying"] = .string(Set(staying).sorted().joined(separator: ","))
        try await write(removal, kind: Self.removalKind, name: "\(profileID.uuidString).\(Self.suffix())", in: crew)
        // The removal stands whether or not the new key could be made; a
        // re-key that could not be is tried again at each refresh.
        setWantsRekey(crew, true)
        rekeyAsks[crew, default: 0] += 1
        await rekeyIfWanted(crew)
    }

    // MARK: A new key when someone is removed

    private static let wantsRekeyKey = "crews.wantsRekey"
    private static let agreeTriedKey = "crews.agreePublishedAt"
    private func wantsRekey(_ crew: CrewID) -> Bool {
        (UserDefaults.standard.stringArray(forKey: Self.wantsRekeyKey) ?? []).contains(crew.rawValue)
    }
    private func setWantsRekey(_ crew: CrewID, _ wants: Bool) {
        var all = Set(UserDefaults.standard.stringArray(forKey: Self.wantsRekeyKey) ?? [])
        if wants { all.insert(crew.rawValue) } else { all.remove(crew.rawValue) }
        UserDefaults.standard.set(all.sorted(), forKey: Self.wantsRekeyKey)
    }

    /// Crews being re-keyed right now: one at a time each, so two removals
    /// in a row do not both start from the same key and leave the crew on
    /// two.
    private var rekeying: Set<CrewID> = []

    /// A re-key that is owed, tried: after a removal, and at each refresh
    /// until it has been done (someone had no public key yet, or there was
    /// no signal).
    private func rekeyIfWanted(_ crew: CrewID) async {
        guard wantsRekey(crew), !rekeying.contains(crew),
              let me = meRecordName, crewRecord(crew)?[Self.creatorKey]?.string == me else { return }
        rekeying.insert(crew)
        defer { rekeying.remove(crew) }
        // **Owed until done, and a removal during the work is not lost.**
        // Cleared after the work, a second removal landing mid-save was
        // wiped by the first finishing. Cleared before it, the app closing
        // mid-save lost the re-key for good. So the flag stays set through
        // the work, and each removal is counted: it is cleared only if no
        // other removal came in while this one was being done.
        var rounds = 0
        while wantsRekey(crew), rounds < 3 {
            rounds += 1
            let asked = rekeyAsks[crew] ?? 0
            do {
                // Read first: someone who joined a moment ago must be counted.
                try await sync(crew, full: false)
                guard try await rekey(crew) else { return }
            } catch {
                Self.log.error("crew not re-keyed after a removal: \(error)")
                return
            }
            if (rekeyAsks[crew] ?? 0) == asked {
                setWantsRekey(crew, false)
                return
            }
        }
    }

    /// How many removals have asked for a re-key, this session.
    private var rekeyAsks: [CrewID: Int] = [:]

    /// The starter's newest removal, as cached.
    private func newestRemoval(in crew: CrewID) -> RecordFields? {
        guard let starter = crewRecord(crew)?[Self.creatorKey]?.string else { return nil }
        return (cache[crew] ?? [:]).filter { $0.key.hasPrefix(Self.removalKind + "/") && $0.value[Self.creatorKey]?.string == starter }
            .values.max { ($0[Self.modKey]?.date ?? .distantPast) < ($1[Self.modKey]?.date ?? .distantPast) }
    }

    /// The crew's members, each with their public key if it is one.
    private func keyHolders(in crew: CrewID) -> [(profile: UUID, agree: String?)] {
        // Those the newest removal says were staying (the second re-key
        // review: while a re-key was owed, someone joining by the old link
        // under another account counted as a member and was sent it).
        let me = meRecordName
        let staying = newestRemoval(in: crew)?["staying"]?.string.map { Set($0.split(separator: ",").map(String.init)) }
        return memberRecords(in: crew).filter { record in
            guard let staying, let writer = record.fields[Self.creatorKey]?.string else { return true }
            return staying.contains(writer) || writer == me
        }.map { record in
            (record.member.profileID, record.fields[CrewAgreement.field]?.string.flatMap { CrewRekey.isKey($0) ? $0 : nil })
        }
    }

    /// **The crew moves to a key the removed person never receives**
    /// (`CrewRekey`). Only when every member has published a public key: a
    /// member without one could not be sent the new key and would be locked
    /// out of their own crew, which is worse than what the re-key prevents.
    /// False when it could not be done yet.
    private func rekey(_ crew: CrewID) async throws -> Bool {
        guard let old = keys.key(for: crew), let mine = CrewAgreement.publicText() else { return false }
        let holders = keyHolders(in: crew)
        let published = holders.compactMap(\.agree)
        guard published.count == holders.count else {
            Self.log.notice("crew not re-keyed yet: \(holders.count - published.count) member(s) without a public key")
            return false
        }
        let new = CrewKey.new()
        let box = try CrewRekey.make(new: new, old: old, recipients: published + [mine], crew: crew.rawValue)
        // Larger than a phone will read: saving it would move this phone to
        // a key nobody else could ever learn.
        guard box.count <= CrewRekey.largest else {
            Self.log.error("crew not re-keyed: the record would be \(box.count) bytes")
            return false
        }
        let name = Self.suffix() + Self.suffix()
        let record = CKRecord(recordType: Self.recordType,
                              recordID: CKRecord.ID(recordName: Self.recordName(crew: crew, kind: CrewRekey.kind, name: name)))
        record["crew"] = crew.rawValue as NSString
        record["kind"] = CrewRekey.kind as NSString
        record["box"] = box as NSData
        let result = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
        guard case .success(let saved)? = result.saveResults[record.recordID] else {
            if case .failure(let error)? = result.saveResults[record.recordID] { throw error }
            return false
        }
        var fields: RecordFields = [Self.rawKey: .string(box.base64EncodedString())]
        if let me = meRecordName { fields[Self.creatorKey] = .string(me) }
        if let tag = saved.recordChangeTag { fields[Self.tagKey] = .string(tag) }
        if let at = saved.modificationDate { fields[Self.modKey] = .date(at) }
        cache[crew, default: [:]]["\(CrewRekey.kind)/\(name)"] = fields
        writtenAt["\(crew.rawValue)|\(CrewRekey.kind)/\(name)"] = Date()
        keys.advance(to: new, for: crew)
        setTime(Date().timeIntervalSince1970, for: crew, in: Self.keyedAtKey)
        saveCache()
        // The crew's own record and yours under the new key (`fetchCrews`
        // does both again if either does not go through now).
        await resealCrewRecord(crew)
        try? await resealMember(in: crew)
        Task { await syncKeys() }
        return true
    }

    /// The crew's own record under its key now, when this account started
    /// it: so someone invited from now on can open it, and an old link
    /// cannot and is told it is old.
    private func resealCrewRecord(_ crew: CrewID) async {
        guard let own = crewRecord(crew), let me = meRecordName, own[Self.creatorKey]?.string == me,
              own[Self.sealKey]?.string != keys.key(for: crew)?.mark else { return }
        try? await write(own, kind: CrewRecordType.crew.rawValue, name: CrewRecords.crewRecordName, in: crew)
    }

    /// The crew's rekey records as cached, and whether its starter is known.
    private func rekeysSeen(_ crew: CrewID) -> (seen: [CrewRekey.Seen], starterKnown: Bool) {
        let starter = crewRecord(crew)?[Self.creatorKey]?.string
        let seen = (cache[crew] ?? [:]).filter { $0.key.hasPrefix(CrewRekey.kind + "/") }.values.compactMap { fields -> CrewRekey.Seen? in
            guard let raw = fields[Self.rawKey]?.string.flatMap({ Data(base64Encoded: $0) }),
                  let box = CrewRekey.read(raw) else { return nil }
            return CrewRekey.Seen(box: box, fromStarter: starter != nil && fields[Self.creatorKey]?.string == starter,
                                  at: fields[Self.modKey]?.date ?? .distantPast)
        }
        return (seen, starter != nil)
    }

    /// What this phone learns from the crew's rekey records: true when its
    /// keys really changed, and the crew wants reading again.
    private func learnKeys(_ crew: CrewID) -> Bool {
        // Once the starter is known, nobody else's rekey records are kept:
        // they are believed for nothing, and anyone can write them.
        if let starter = crewRecord(crew)?[Self.creatorKey]?.string {
            for (key, fields) in cache[crew] ?? [:] where key.hasPrefix(CrewRekey.kind + "/") && fields[Self.creatorKey]?.string != starter {
                cache[crew]?[key] = nil
            }
        }
        let (seen, starterKnown) = rekeysSeen(crew)
        guard !seen.isEmpty else { return false }
        let before = keys.candidates(for: crew)
        let learned = CrewRekey.learn(seen, crew: crew.rawValue, current: keys.key(for: crew),
                                      older: keys.ring.older(for: crew.rawValue), mine: CrewAgreement.existing(),
                                      starterKnown: starterKnown)
        guard learned.changed else { return false }
        for key in learned.older { keys.remember(key, for: crew) }
        if let key = learned.current {
            keys.advance(to: key, for: crew)
            setTime(Date().timeIntervalSince1970, for: crew, in: Self.keyedAtKey)
            // Your member record under the new key, so it still counts
            // (`memberRecords`), and the key to your other phones.
            wantsReseal.insert(crew)
            Task { await syncKeys() }
        }
        guard keys.candidates(for: crew) != before else { return false }
        // Kept, so a re-read cut short (the app closed) is done next time.
        since[crew] = .distantPast
        saveCache()
        return true
    }

    /// How many rekey records a crew keeps: far more re-keys than a crew
    /// has in the two weeks its posts last, and a bound all the same.
    static let rekeysKept = 64
    /// And how many before its starter is known, when none can be vouched for.
    static let rekeysUnvouched = 24

    /// What this phone owes a crew it is in: a re-key the starter still
    /// owes it; the crew's own record under its key now; and your member
    /// record again, under a new key or with your public key, which a crew
    /// needs from everyone in it before it can be re-keyed.
    private func keepUp(_ crew: CrewID) async {
        await rekeyIfWanted(crew)
        await resealCrewRecord(crew)
        let key = "\(CrewRecordType.member.rawValue)/\(myProfileID.uuidString)"
        if let own = cache[crew]?[key], own[Self.creatorKey]?.string == meRecordName {
            // Looked at, never made here (`CrewAgreement.existing`): made
            // only when your member record is written.
            let mine = CrewAgreement.publicText(CrewAgreement.existing())
            let published = own[CrewAgreement.field]?.string
            // Nothing published, or a key this phone cannot open (another
            // phone's, with no shared iCloud Keychain; or a restored phone
            // without the private half): this phone's goes up. At most once
            // a day, whatever the reason: two such phones would otherwise
            // rewrite each other's at every refresh, and so would a phone
            // whose Keychain refuses to hold a key at all.
            if published == nil || mine == nil || published != mine {
                var tried = UserDefaults.standard.dictionary(forKey: Self.agreeTriedKey) as? [String: Double] ?? [:]
                let now = Date().timeIntervalSince1970
                let last = tried[crew.rawValue] ?? 0
                // A key is published and this phone has none: its own may
                // still be on its way from the iCloud Keychain, and making
                // one now could displace it there. Noted, and only acted on
                // if it is still so a day later.
                let waitsForKeychain = published != nil && mine == nil && last == 0
                if waitsForKeychain || now - last > 86_400 {
                    tried[crew.rawValue] = now
                    UserDefaults.standard.set(tried, forKey: Self.agreeTriedKey)
                    if !waitsForKeychain { wantsReseal.insert(crew) }
                }
            }
        }
        if wantsReseal.contains(crew), (try? await resealMember(in: crew)) != nil { wantsReseal.remove(crew) }
    }

    /// Crews where this phone's member record wants writing again: under a
    /// new key, or with its public key added.
    private var wantsReseal: Set<CrewID> = []

    /// Your member record, written again as it stands: sealed with the
    /// crew's key now, and carrying your public key.
    private func resealMember(in crew: CrewID) async throws {
        let key = "\(CrewRecordType.member.rawValue)/\(myProfileID.uuidString)"
        guard let mine = cache[crew]?[key], mine[Self.creatorKey]?.string == meRecordName else { return }
        var fields = mine.filter { !$0.key.hasPrefix("_") }
        if let text = CrewAgreement.publicText() { fields[CrewAgreement.field] = .string(text) }
        try await write(fields, kind: CrewRecordType.member.rawValue, name: myProfileID.uuidString, in: crew)
    }

    /// Every record this phone's iCloud user wrote in a crew.
    private func deleteMine(in crew: CrewID, keepingCrewRecord: Bool = false) async throws {
        _ = try await me()
        let ids = mineIDs(in: crew, keepingCrewRecord: keepingCrewRecord)
        guard !ids.isEmpty else { return }
        for chunk in stride(from: 0, to: ids.count, by: 200).map({ Array(ids[$0..<min($0 + 200, ids.count)]) }) {
            let result = try await database.modifyRecords(saving: [], deleting: chunk)
            // A delete the server refused is not a delete: the crew is not
            // forgotten on the strength of it, and the next refresh tries
            // again while the cache still names what is left.
            for (_, outcome) in result.deleteResults {
                if case .failure(let error) = outcome, (error as? CKError)?.code != .unknownItem { throw error }
            }
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
    ///
    /// **Not forgotten while the tidying could still succeed** (the
    /// regression check): the crew was forgotten whether or not the delete
    /// went through, and with the key and the cache gone nothing could name
    /// your posts again, so one dropped connection left them on the server
    /// for good. No signal or a busy server means try again next refresh.
    private func tidyAway(_ crew: CrewID, leftAt: Double? = nil) async {
        do {
            try await deleteMine(in: crew, keepingCrewRecord: true)
        } catch {
            if Self.mayPass(error) { return }
        }
        forget(crew, at: leftAt)
    }

    /// Whether an error is the kind that goes away: no signal, a busy or
    /// rate-limiting server. Anything else will not be different next time.
    static func mayPass(_ error: Error) -> Bool {
        guard let code = (error as? CKError)?.code else { return (error as NSError).domain == NSURLErrorDomain }
        switch code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy, .serverResponseLost:
            return true
        default:
            return false
        }
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
        for crew in crews where learnKeys(crew) {
            since[crew] = .distantPast
            _ = try await sync(crew, full: true)
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
        let changed = try await syncOnce(crew, full: full)
        // A re-key read in that pass: what its key opens was skipped, so
        // the crew is read whole with it (and once more, for a chain of
        // them; never round and round).
        var again = 0
        while again < 3, learnKeys(crew) {
            again += 1
            since[crew] = .distantPast
            _ = try await syncOnce(crew, full: true)
        }
        return changed || again > 0
    }

    private func syncOnce(_ crew: CrewID, full: Bool) async throws -> Bool {
        let last = since[crew] ?? .distantPast
        let cutoff = full || last == .distantPast ? Date.distantPast : last.addingTimeInterval(-Self.overlap)
        let predicate = cutoff == .distantPast
            ? NSPredicate(format: "crew == %@", crew.rawValue)
            : NSPredicate(format: "crew == %@ AND modificationDate > %@", crew.rawValue, cutoff as NSDate)
        let before = cache[crew]
        let result = try await read(predicate)
        if result.incomplete || result.failedFrom[crew] != nil { readFailed.insert(crew) } else { readFailed.remove(crew) }
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
        var withFiles: [CKRecord.ID: (crew: CrewID, at: Date, row: CKRecord)] = [:]
        var rekeyRows: [(crew: CrewID, cacheKey: String, record: CKRecord)] = []
        func arrived(_ crew: CrewID, _ at: Date?) {
            if let at { out.newest[crew] = max(out.newest[crew] ?? .distantPast, at) }
        }
        func note(_ record: CKRecord) {
            guard let crewText = record["crew"] as? String, let kind = record["kind"] as? String else { return }
            let crew = CrewID(rawValue: crewText)
            let prefix = "\(crewText)~\(kind)~"
            let recordName = record.recordID.recordName
            guard keys.key(for: crew) != nil, recordName.hasPrefix(prefix) else { return }
            let cacheKey = "\(kind)/\(recordName.dropFirst(prefix.count))"
            out.seen[crew, default: []].insert(cacheKey)
            if let tag = record.recordChangeTag, cache[crew]?[cacheKey]?[Self.tagKey]?.string == tag {
                arrived(crew, record.modificationDate)
                return
            }
            // A rekey record is not sealed with the crew's key (the people
            // who must read it hold different ones): kept as it is, and
            // read by `learnKeys`.
            // Rekey rows wait until every other row of this read is in: who
            // the starter is decides which of them are kept (after the loop).
            if kind == CrewRekey.kind {
                rekeyRows.append((crew, cacheKey, record))
                return
            }
            // With whichever of the crew's keys opens it: after a re-key the
            // two weeks before it are still under the key before.
            guard let sealed = record["box"] as? Data,
                  let files = keys.candidates(for: crew).lazy
                      .compactMap({ CrewItemBox.fileCount(sealed, key: $0, recordName: recordName) }).first else {
                Self.log.notice("crew item not opened: \(recordName, privacy: .public)")
                return
            }
            if files > 0 {
                withFiles[record.recordID] = (crew, record.modificationDate ?? .distantPast, record)
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
                guard let (crew, at, row) = withFiles[id] else { continue }
                /// Its files did not come. Waited for, for an hour; then the
                /// record is taken without them, so one picture that will
                /// never download does not hold "since" back for ever and
                /// get fetched again on every sync (the fourth read).
                /// **By the clock, not by a count** (the regression check):
                /// the open crew syncs every three seconds, so three tries
                /// were up in ten seconds of poor signal, and a friend's
                /// photo was given up on for good.
                func missed() {
                    let name = "\(id.recordName)|\(row.recordChangeTag ?? "")"
                    let first = fileFailures[name] ?? Date()
                    fileFailures[name] = first
                    if Date().timeIntervalSince(first) > Self.fileWait, take(row) != nil {
                        Self.log.notice("crew item kept without its files: \(id.recordName, privacy: .public)")
                        fileFailures[name] = nil
                        arrived(crew, at)
                    } else {
                        out.failedFrom[crew] = min(out.failedFrom[crew] ?? .distantFuture, at)
                    }
                }
                switch result {
                case .success(let record):
                    // Fetched and not opened (its file could not be kept, a
                    // full disk): asked for again, like one not fetched.
                    if take(record) != nil {
                        fileFailures["\(id.recordName)|\(row.recordChangeTag ?? "")"] = nil
                        arrived(crew, record.modificationDate)
                    } else {
                        missed()
                    }
                case .failure(let error):
                    // Deleted between the two reads: nothing to wait for.
                    if (error as? CKError)?.code == .unknownItem { continue }
                    missed()
                }
            }
        }
        // **Small, few, and the starter's** (the re-key reviews). A rekey
        // row is not sealed with the crew's key (the people who must read
        // it hold different ones), so anyone who knew a crew's id could
        // write one. Kept: the starter's, up to `rekeysKept`. Before the
        // starter is known (a first read whose crew record did not open
        // yet), the newest few of anyone's, for the keys before only; and
        // those never move "since", so the starter's own are read again.
        for row in rekeyRows.sorted(by: { ($0.record.modificationDate ?? .distantPast) > ($1.record.modificationDate ?? .distantPast) }) {
            let starter = crewRecord(row.crew)?[Self.creatorKey]?.string
            let writer = owner(row.record.creatorUserRecordID)
            let kept = (cache[row.crew] ?? [:]).keys.filter { $0.hasPrefix(CrewRekey.kind + "/") }.count
            let known = cache[row.crew]?[row.cacheKey] != nil
            guard starter == nil ? (known || kept < Self.rekeysUnvouched) : writer == starter,
                  known || kept < Self.rekeysKept,
                  let raw = row.record["box"] as? Data, CrewRekey.read(raw) != nil else { continue }
            var fields: RecordFields = [Self.rawKey: .string(raw.base64EncodedString())]
            if let writer { fields[Self.creatorKey] = .string(writer) }
            if let tag = row.record.recordChangeTag, starter != nil { fields[Self.tagKey] = .string(tag) }
            if let at = row.record.modificationDate { fields[Self.modKey] = .date(at) }
            cache[row.crew, default: [:]][row.cacheKey] = fields
            if starter != nil { arrived(row.crew, row.record.modificationDate) }
        }
        return out
    }

    /// Opens one record into the cache. A box that will not open (a wrong
    /// or missing key) is skipped, never shown.
    private func take(_ record: CKRecord) -> (CrewID, String)? {
        guard let crewText = record["crew"] as? String, let kind = record["kind"] as? String,
              let sealed = record["box"] as? Data else { return nil }
        let crew = CrewID(rawValue: crewText)
        let candidates = keys.candidates(for: crew)
        guard !candidates.isEmpty else { return nil }
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
        var opened: (fields: RecordFields, key: CrewKey)?
        for key in candidates {
            if let fields = try? CrewItemBox.open(sealed, assets: sources, key: key, recordName: recordName,
                                                  into: directory.appending(path: "\(folder)/\(crew.rawValue)"),
                                                  stem: Self.stem(type, name: name, tag: tag),
                                                  family: Self.family(type, name: name)) {
                opened = (fields, key)
                break
            }
        }
        guard var fields = opened?.fields, let key = opened?.key else {
            Self.log.notice("crew item not opened: \(recordName, privacy: .public)")
            return nil
        }
        // **The cache's own fields are the server's to say, never the
        // box's** (the re-key review): who wrote a record now decides whose
        // key is taken, and a box that named its own writer would only have
        // been overruled while the server always named one.
        fields = fields.filter { !$0.key.hasPrefix("_") || $0.key == Self.endedKey }
        fields[Self.sealKey] = .string(key.mark)
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

    /// What a record's files are called on this phone, and which older
    /// files a new version of it replaces.
    ///
    /// **A reaction's file is its own family** (found by review,
    /// 2026-10-13). A reaction is named for the win it is on, then who made
    /// it, so its file began with the win's id; and a win's files are swept
    /// by "everything that begins with the win's id". Opening a photo win
    /// after a friend's sticker on it deleted the sticker. The same went
    /// for a sticker on a chat line that carried a picture.
    nonisolated static func stem(_ type: CrewRecordType?, name: String, tag: String) -> String {
        switch type {
        case .crew: "crew-picture-\(tag)"
        case .reaction: "reaction-\(name)-\(tag)"
        // Its own family: a story's photo and the same win's crew copy
        // share a name, and a new file of one family clears the old ones.
        case .story: "story-\(name)-\(tag)"
        default: "\(name)-\(tag)"
        }
    }

    nonisolated static func family(_ type: CrewRecordType?, name: String) -> String {
        switch type {
        case .crew: "crew-picture-"
        case .reaction: "reaction-\(name)-"
        case .story: "story-\(name)-"
        default: "\(name)-"
        }
    }

    /// When each record's files first failed to arrive, by name and tag.
    private var fileFailures: [String: Date] = [:]
    static let fileWait: TimeInterval = 3600

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
            // **A crew this phone is in always has something on the server**
            // (its own record, your member record). A listing that shows
            // nothing at all for it is a listing that went wrong, or the
            // wrong database, never a crew emptied: nothing is dropped, and
            // the crew is read whole again (2026-10-10).
            guard let present = seen[crew], !present.isEmpty else {
                since[crew] = nil
                continue
            }
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

    /// A ping only one phone can leave: its name is the same on every
    /// phone, and the server takes the first. False when another phone was
    /// first.
    func pingOnce(_ fields: [String: String], named name: String) async throws -> Bool {
        let record = CKRecord(recordType: CrewPingRecord.type, recordID: CKRecord.ID(recordName: name))
        for (key, value) in fields { record[key] = value as NSString }
        let result = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .ifServerRecordUnchanged)
        if case .failure(let error)? = result.saveResults[record.recordID] {
            if (error as? CKError)?.code == .serverRecordChanged { return false }
            throw error
        }
        return true
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
        let ids = [CrewPingPlan.winsID, CrewPingPlan.reactionsID, CrewPingPlan.crewID]
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
        if !plan.winCrews.isEmpty {
            saving.append(Self.subscription(CrewPingPlan.crewID, plan.crewPredicate, fallback: CrewPingRecord.fallbackCrew))
        }
        guard !saving.isEmpty else { return }
        // **All of them or none** (found by review, 2026-10-10): the caller
        // takes a failure to mean this phone is not subscribed and lets the
        // app's own notifications carry on, so one refused while the others
        // were saved would have told every win twice.
        func undo() async { _ = try? await database.modifySubscriptions(saving: [], deleting: ids) }
        do {
            let saved = try await database.modifySubscriptions(saving: saving, deleting: [])
            for (_, result) in saved.saveResults {
                if case .failure(let error) = result {
                    await undo()
                    throw error
                }
            }
        } catch {
            await undo()
            throw error
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
