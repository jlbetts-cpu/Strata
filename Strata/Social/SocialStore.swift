import SwiftData
import CloudKit
import CryptoKit
import Foundation
import Observation
import UIKit
import UserNotifications
import os

/// Your crews, today's shared wins in each, and every write still on its way.
///
/// **Beside SwiftData, never inside it.** Nothing here takes a `ModelContext`,
/// and a friend's win is never a `Habit` or a `HabitLog`: it lives in
/// `winsByCrew` and in the crew's CloudKit zone, so it cannot reach your
/// tower, your streaks, Memories, Replays, the widget or a backup.
///
/// The policy lives here and only here: the caps, the crew day, what is
/// allowed to leave the phone, the outbox and pruning. `CrewCloud` only moves
/// records.
@MainActor
@Observable
final class SocialStore {
    private static let log = Logger(subsystem: "Strata", category: "crews")

    /// The phone's store. Its cloud is chosen once, at first use: the fake
    /// one behind `-strataSeedCrew`, otherwise CloudKit.
    static let shared: SocialStore = {
        let store = SocialStore(cloud: makeCloud(), defaults: .standard, directory: defaultDirectory)
        store.photosAllowed = { CrewAge.current.sendsPhotos }
        store.photoCheck = { await CrewSafety.photoIsFine($0) }
        store.incomingPolicy = { CrewSafety.incoming }
        store.incomingCheck = { await CrewSafety.verdict($0) }
        store.joinGate = { CrewGate.current }
        store.announces = true
        // On since 2026-10-05: the notification extension ships with the app
        // now that its app ID is linked to the iCloud container and the app
        // group, so a ping arrives as "Sam added Morning run" on the lock
        // screen however long the app has been closed, not only when iOS
        // happens to wake it.
        store.sendsPings = true
        store.throttles = true
        NotificationCenter.default.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { _ in
            Task { @MainActor in await SocialStore.shared.accountChanged() }
        }
        // The first word only: a crew needs to know it is Sam, not Sam's
        // surname (spec 4.2, "firstName").
        store.myHandle = { ProfileStore.shared.handle }
        store.myHandleSetAt = { ProfileStore.shared.handleSetAt }
        store.keepMyHandle = { ProfileStore.shared.keepHandle($0, at: $1) }
        store.forgetMyHandle = { ProfileStore.shared.forgetHandle() }
        store.myPhoto = { ProfileStore.shared.photoData }
        store.myFeatured = { FeaturedWins.decode(ProfileStore.shared.featuredShared) }
        store.myFirstName = {
            ProfileStore.shared.name.split(separator: " ").first.map(String.init) ?? ""
        }
        store.myHeadPack = {
            // Packing shrinks every face: off the main actor.
            guard let folder = HeadStore.shared.crewHeadDirectory else { return nil }
            return await Task.detached(priority: .utility) { CrewHeadPack.make(from: folder) }.value
        }
        // Every face in the head through the photo check (2026-10-08).
        store.headCheck = { await CrewHeadPack.passes($0, check: CrewSafety.photoIsFine) }
        // Keep, on "Sam added you to a win": a copy into your own record,
        // through the app's own logging path. SwiftData lives in the app
        // layer (`TaggedWinKeeper`), never in this file.
        store.keepTaggedWin = { await TaggedWinKeeper.keepFromCrew($0) }
        // A photo is offered first and can be added later; it is never what
        // stands between you and inviting people (the owner, 2026-10-02:
        // "why do I have to name or do a pfp to add people").
        store.requiresCrewPhoto = false
        // Blocks and mutes, the same on every phone on this iCloud account.
        let choices = NSUbiquitousKeyValueStore.default
        store.choicesCloud = choices
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: choices, queue: .main
        ) { _ in
            Task { @MainActor in SocialStore.shared.pullChoices() }
        }
        choices.synchronize()
        store.pullChoices()
        return store
    }()

    /// Replaced by the CloudKit adapter at launch (Task 3) and by the debug
    /// seed. A fake until then, so nothing can reach the network by accident.
    static var makeCloud: () -> CrewCloud = { FakeCrewCloud(me: ProfileStore.profileID) }

    nonisolated static var defaultDirectory: URL {
        (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory)
            .appending(path: "Crews", directoryHint: .isDirectory)
    }

    // MARK: State

    private(set) var crews: [Crew] = []
    /// The crews have been read from the cloud at least once this launch.
    /// Until then `crews` is empty because nothing has been asked, not
    /// because there are none (`CrewWidgetPublisher` waits on this).
    private(set) var hasFetchedCrews = false
    private(set) var winsByCrew: [CrewID: [SharedWin]] = [:]
    private(set) var reactionsByCrew: [CrewID: [Reaction]] = [:]
    /// Each crew's day chat as fetched, every day's lines it still holds.
    /// What a screen shows is `messages(in:)`: today's, and nobody blocked.
    private(set) var messagesByCrew: [CrewID: [CrewMessage]] = [:]
    /// Crews holding a friend's win you have not looked at.
    private(set) var unread: Set<CrewID> = []
    /// Crews whose chat has a friend's line you have not opened. The crew
    /// screen's chat button carries a dot for it; nothing else does, and
    /// nothing is ever said about who has read what.
    private(set) var unreadChats: Set<CrewID> = []
    /// **Tonight's stories, as each crew holds them** (`CrewStory`). Yours
    /// and your friends', waiting, open or past their end: what may be shown
    /// is the clock's to say (`StoryClock`), and the sweep in `prune` drops
    /// what has gone.
    private(set) var storiesByCrew: [CrewID: [CrewStory]] = [:]
    /// Stories opened on this phone, kept until their night has gone, so a
    /// ring goes grey and stays grey.
    private(set) var storiesSeen: Set<UUID> = []
    /// Friends whose story you hid for tonight, with the night it was.
    private(set) var storiesHidden: [UUID: String] = [:]
    /// **Reactions to your stories, kept on this phone** (the spec, 6.4:
    /// "reactions are copied to the poster's phone when read, so they
    /// outlive the night"). Keyed by the win, with the night they came on.
    @ObservationIgnored private(set) var storyReactionsKept: [UUID: StoryReactionsKept] = [:]
    /// Your stories as posted from this phone (`StoryLedgerEntry`).
    @ObservationIgnored var storyLedger: [UUID: StoryLedgerEntry] = [:]
    /// Bumped when a story is taken off, so a post still waiting on its
    /// photo check knows not to put it back.
    @ObservationIgnored var storyGeneration: [UUID: Int] = [:]
    /// Crews being left: nothing new is written to them meanwhile.
    @ObservationIgnored var leavingCrews: Set<CrewID> = []
    /// A personal chat being started, per friend, so two quick replies make
    /// one chat (the review, 2026-10-16).
    @ObservationIgnored var personalStarting: [UUID: Task<Crew?, Never>] = [:]
    /// Bumped whenever `outbox` changes, so a block's back can say "Not sent
    /// yet" and stop saying it.
    private(set) var outboxRevision = 0
    /// Bumped when the activity corner is looked at (`ActivityFeed`).
    var activityRevision = 0
    /// The newest thing in Activity, kept against a cheap fingerprint of
    /// what it was gathered from, so the corner's dot is not a whole feed
    /// rebuilt on every render of the Crews list (the second reader,
    /// 2026-10-17).
    @ObservationIgnored var activityNewest: (key: [Int], newest: Double)?
    private(set) var isRefreshing = false

    let cloud: CrewCloud
    let defaults: UserDefaults
    let directory: URL
    @ObservationIgnored private var outbox: CrewOutbox

    /// Whether crews are on. Injected so a test can prove "off" touches
    /// nothing. **Off below iOS 26** (2026-10-08, `CrewsFlag.isUsable`):
    /// crews do not open there, so nothing of them syncs or sends either.
    @ObservationIgnored var isEnabled: () -> Bool = { CrewsFlag.isUsable }
    /// **What stands between this phone and a crew** (`CrewGate`,
    /// 2026-10-08). Joining and starting refuse anything but `.open`, so an
    /// invitation can no longer join a crew before the rules and the age
    /// were asked. Open in tests that are about something else; the phone's
    /// store reads `CrewGate.current`.
    @ObservationIgnored var joinGate: () -> CrewGate = { .open }
    /// Whether this person may send photographs (13 to 15 may not; spec 9.1).
    @ObservationIgnored var photosAllowed: () -> Bool = { true }
    /// What you called yourself, for your Member record.
    @ObservationIgnored var myFirstName: () -> String = { "" }
    /// Your username (`Handle`), told to your crews on your member record.
    @ObservationIgnored var myHandle: () -> String? = { nil }
    /// When it was claimed, and where a new one is kept (`ProfileStore`;
    /// a test's own).
    @ObservationIgnored var myHandleSetAt: () -> Date? = { nil }
    @ObservationIgnored var keepMyHandle: (String, Date) -> Void = { _, _ in }
    @ObservationIgnored var forgetMyHandle: () -> Void = {}
    /// Your chosen photograph instead of a head, to send (`ProfileStore`).
    @ObservationIgnored var myPhoto: () -> Data? = { nil }
    /// Your featured wins as your crews are told them (`FeaturedWins`).
    @ObservationIgnored var myFeatured: () -> [FeaturedWins.Shared] = { [] }
    /// Friends' usernames that have been checked as theirs (`verifyHandle`),
    /// by profile, and when; only these are shown.
    var verifiedHandles: [UUID: String] = [:]
    @ObservationIgnored var handleChecked: [String: Date] = [:]
    /// Your head, packed to send, or nil for no head.
    @ObservationIgnored var myHeadPack: () async -> Data? = { nil }
    /// **The photo check, for a head** (2026-10-08): every face in the pack
    /// passes `CrewSafety.photoIsFine` or the head is not sent. A head is cut
    /// out of a photograph, and it went to crews unchecked.
    @ObservationIgnored var headCheck: (Data) async -> Bool = { _ in true }
    /// A crew must start with a photo (the owner, 2026-10-02). Off in tests
    /// that are about something else.
    @ObservationIgnored var requiresCrewPhoto = false
    /// **Keep, on a win you were tagged in**: writes a copy into your own
    /// record. Handed the crew's copy, photo and all; the app's `HabitLog`
    /// work is done by whoever sets this, so this file stays beside
    /// SwiftData and never inside it. Called once per win, however many
    /// times Keep is pressed or however many crews it arrived in.
    @ObservationIgnored var keepTaggedWin: (SharedWin) async -> Void = { _ in }
    /// Makes the copy of a photograph that is sent.
    @ObservationIgnored var derive: @Sendable (Data) -> Data? = { ShareDerivative.jpeg(from: $0) }

    /// The derivative, made OFF the main actor. Re-encoding a photograph to
    /// 1080px takes tens of milliseconds, and on the main actor it landed as a
    /// 54 to 92ms hitch exactly as a win was sent, which is when your block is
    /// falling (measured with `-strataPerfProbe`, 2026-10-02).
    private func derived(_ jpeg: Data, cut: CGRect? = nil) async -> Data? {
        let make = derive
        return await Task.detached(priority: .userInitiated) {
            // A zoomed photo is cut to its window first (`PhotoWindow.cut`).
            // **If the cut cannot be made, no photo goes.** Sending it whole
            // would show a crew what its owner zoomed in to leave out (found
            // by review, 2026-10-13): a win with no picture is the safe loss.
            guard let cut else { return make(jpeg) }
            guard let piece = PhotoWindow.jpeg(jpeg, cutTo: cut) else { return nil }
            return make(piece)
        }.value
    }
    /// The photo check before anything is sent (`CrewSafety.photoIsFine`).
    @ObservationIgnored var photoCheck: (Data) async -> Bool = { _ in true }
    /// A photo the check held back, for a quiet word to the sender.
    private(set) var heldBackPhoto: UUID?
    /// Today, injectable for pruning and the crew day.
    @ObservationIgnored var now: () -> Date = Date.init

    var me: UUID { cloud.myProfileID }

    /// Signed out of iCloud, or into another account: nothing of the old
    /// account's crews may stay on the phone (the 2026-10-02 audit).
    ///
    /// **Only when it really changed.** iOS posts `CKAccountChanged` for far
    /// more than a sign-in or out (a token refresh, iCloud settings, coming
    /// back from the background), and wiping on every one emptied the crews
    /// list, closed the open crew with "This crew has ended." and threw away
    /// writes still waiting to send, until the next refresh brought it all
    /// back (the owner, 2026-10-05: "chats randomly disapearing... then they
    /// come back"). The account is asked who it is, and only a different
    /// user, or none, clears anything.
    func accountChanged() async {
        guard isEnabled() else { return }
        let was = defaults.string(forKey: Self.accountKey)
        switch await cloud.account() {
        case .unknown:
            return
        case .signedIn(let who):
            defaults.set(who, forKey: Self.accountKey)
            // Back after signing out: what this phone kept for this account
            // comes back with it.
            if was == nil { takeBackSetAside(for: who) }
            // First seen (a phone updated from before this was kept): the
            // crews on it are this account's.
            guard let was, was != who else { return }
        case .signedOut:
            defaults.removeObject(forKey: Self.accountKey)
            // **Kept aside, not deleted** (the rare-bug hunt, 2026-10-16):
            // the crews' day counts are kept on this phone for good, and the
            // cloud holds two weeks; signing out and back in reset every
            // streak and dropped every line written offline.
            if let was { setAside(for: was) }
        }
        cloud.reset()
        // **Another account's username is not this one's** (the username
        // review): kept, the new account would show @them and write it into
        // its member records while the claim stays the old account's.
        forgetMyHandle()
        verifiedHandles = [:]
        handleChecked = [:]
        for crew in crews { forget(crew.id) }
        crews = []
        winsByCrew = [:]
        reactionsByCrew = [:]
        messagesByCrew = [:]
        storiesByCrew = [:]
        storyReactionsKept = [:]
        storyLedger = [:]
        unreadChats = []
        outbox = CrewOutbox()
        persistOutbox()
        sent = [:]
        try? FileManager.default.removeItem(at: directory)
        await refresh()
    }

    /// Where an account's crew history and unsent lines wait while it is
    /// signed out of this phone.
    private func asideFolder(for account: String) -> URL {
        let safe = account.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == "_" }
        return directory.deletingLastPathComponent().appending(path: "crews-kept-\(String(String.UnicodeScalarView(safe)))")
    }

    private func setAside(for account: String) {
        let aside = asideFolder(for: account)
        try? FileManager.default.createDirectory(at: aside, withIntermediateDirectories: true)
        // The history as this phone holds it now, whatever reached the disk.
        let keyed = Dictionary(uniqueKeysWithValues: history.map { ($0.key.rawValue, $0.value) })
        if !keyed.isEmpty { try? JSONEncoder().encode(keyed).write(to: aside.appending(path: "history.json"), options: .atomic) }
        history = [:]
        // The unsent lines, and the photographs they point at (the second
        // reader, 2026-10-17): the outbox names its photos by file, and the
        // wipe that follows deletes the folder they are in.
        for name in ["outbox.json", "Photos"] {
            let from = directory.appending(path: name), to = aside.appending(path: name)
            guard FileManager.default.fileExists(atPath: from.path) else { continue }
            try? FileManager.default.removeItem(at: to)
            try? FileManager.default.copyItem(at: from, to: to)
        }
    }

    private func takeBackSetAside(for account: String) {
        let aside = asideFolder(for: account)
        guard FileManager.default.fileExists(atPath: aside.path) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: aside.appending(path: "history.json")),
           let kept = try? JSONDecoder().decode([String: CrewHistory].self, from: data) {
            // Merged under what has been counted since: a day this phone
            // knows again is its newer count, the rest come back.
            var next = history
            for (key, old) in kept {
                let id = CrewID(rawValue: key)
                var merged = next[id] ?? old
                for (day, counts) in old.days where merged.days[day] == nil { merged.days[day] = counts }
                next[id] = merged
            }
            history = next
            let keyed = Dictionary(uniqueKeysWithValues: next.map { ($0.key.rawValue, $0.value) })
            try? JSONEncoder().encode(keyed).write(to: directory.appending(path: "history.json"), options: .atomic)
        }
        // Photographs first, where the kept lines expect them; none written
        // since is replaced.
        let keptPhotos = aside.appending(path: "Photos")
        if let crewsKept = try? FileManager.default.contentsOfDirectory(at: keptPhotos, includingPropertiesForKeys: nil) {
            for crewFolder in crewsKept {
                let into = directory.appending(path: "Photos/\(crewFolder.lastPathComponent)")
                try? FileManager.default.createDirectory(at: into, withIntermediateDirectories: true)
                for file in (try? FileManager.default.contentsOfDirectory(at: crewFolder, includingPropertiesForKeys: nil)) ?? [] {
                    let target = into.appending(path: file.lastPathComponent)
                    if !FileManager.default.fileExists(atPath: target.path) { try? FileManager.default.copyItem(at: file, to: target) }
                }
            }
        }
        // Merged, not skipped when lines were written since: a line queued
        // now is newer than the same record's kept one, so it stays.
        let kept = CrewOutbox.load(from: aside.appending(path: "outbox.json"))
        if !kept.entries.isEmpty {
            var merged = kept
            for entry in outbox.entries { merged.put(entry) }
            outbox = merged
            persistOutbox()
        }
        try? FileManager.default.removeItem(at: aside)
    }

    init(cloud: CrewCloud, defaults: UserDefaults, directory: URL) {
        self.cloud = cloud
        self.defaults = defaults
        self.directory = directory
        self.outbox = CrewOutbox.load(from: directory.appending(path: "outbox.json"))
        self.history = (try? Data(contentsOf: directory.appending(path: "history.json")))
            .flatMap { try? JSONDecoder().decode([String: CrewHistory].self, from: $0) }
            .map { Dictionary(uniqueKeysWithValues: $0.map { (CrewID(rawValue: $0.key), $0.value) }) } ?? [:]
        self.blocked = Set((defaults.stringArray(forKey: Self.blockedKey) ?? []).compactMap(UUID.init(uuidString:)))
        let hidden = defaults.dictionary(forKey: CrewChoicesSync.Table.hidden.rawValue) as? CrewChoicesSync.Entries ?? [:]
        self.hiddenWins = Set(hidden.filter { CrewChoicesSync.value($0.value) == 1 }.keys.compactMap(UUID.init(uuidString:)))
        self.tagAnswers = defaults.dictionary(forKey: Self.tagAnswersKey) as? [String: Bool] ?? [:]
        self.storiesSeen = Set((defaults.stringArray(forKey: Self.storiesSeenKey) ?? []).compactMap(UUID.init(uuidString:)))
        self.storiesHidden = (defaults.dictionary(forKey: Self.storiesHiddenKey) as? [String: String] ?? [:])
            .reduce(into: [:]) { out, pair in if let id = UUID(uuidString: pair.key) { out[id] = pair.value } }
        self.storyReactionsKept = (try? Data(contentsOf: directory.appending(path: Self.storyReactionsFile)))
            .flatMap { try? JSONDecoder().decode([UUID: StoryReactionsKept].self, from: $0) } ?? [:]
        self.storyLedger = (try? Data(contentsOf: directory.appending(path: Self.storyLedgerFile)))
            .flatMap { try? JSONDecoder().decode([UUID: StoryLedgerEntry].self, from: $0) } ?? [:]
    }

    // MARK: Reading

    func crew(_ id: CrewID) -> Crew? { crews.first { $0.id == id } }

    /// Each crew's days as numbers (`CrewHistory`): its streak and its chart.
    private(set) var history: [CrewID: CrewHistory] = [:]

    #if DEBUG
    /// The debug seed's months of history, which no fake cloud could hold.
    func debugSetHistory(_ seeded: CrewHistory, for crew: CrewID) { history[crew] = seeded }
    #endif

    /// The cloud's wins, counted into each crew's history. Only for crews
    /// whose fetch worked: a failed fetch is not a day with no wins.
    private func recordHistory(_ wins: [CrewID: [SharedWin]], for crews: [Crew]) {
        var next = history
        for crew in crews {
            guard let held = wins[crew.id] else { continue }
            let today = CrewDay.string(for: now(), in: crew.timeZone)
            guard let cutoff = CrewDay.oldestKept(today: today, in: crew.timeZone) else { continue }
            next[crew.id, default: CrewHistory()].record(held, from: cutoff,
                                                         rewritingFrom: CrewHistory.rewriteFrom(today, in: crew.timeZone),
                                                         through: today)
        }
        guard next != history else { return }
        history = next
        let keyed = Dictionary(uniqueKeysWithValues: next.map { ($0.key.rawValue, $0.value) })
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(keyed).write(to: directory.appending(path: "history.json"), options: .atomic)
        } catch {
            Self.log.error("history not written: \(error)")
        }
    }

    /// Every shared win still held for a crew, oldest first.
    func wins(in crew: CrewID) -> [SharedWin] {
        (winsByCrew[crew] ?? []).sorted { $0.createdAt < $1.createdAt }.map { win in
            guard win.senderProfileID != me, let photo = win.photo, !photoIsShown(photo) else { return win }
            var hidden = win
            hidden.photo = nil
            return hidden
        }
    }

    // MARK: Photos that arrive

    /// **A friend's photograph is checked on THIS phone too** (the 2026-10-03
    /// audit: only the sender's phone checked, so a teen saw an adult's
    /// photo unblurred). Where the system's sensitive-content analysis is on
    /// (Sensitive Content Warning for adults, Communication Safety for
    /// children), every arriving photo is analysed once and a flagged one is
    /// never shown, not even in a notification; until it has been checked it
    /// is not shown either. Under sixteen with the analysis off, friends'
    /// photos are not shown at all. An adult with it off sees them as sent:
    /// that choice is theirs, made for every app.
    @ObservationIgnored var incomingPolicy: () -> CrewSafety.Incoming = { .show }
    /// A friend's photo, checked: nil when the check could not run, which is
    /// tried again next time rather than remembered.
    @ObservationIgnored var incomingCheck: (Data) async -> Bool? = { _ in true }
    @ObservationIgnored private lazy var photoVerdicts: [String: Bool] =
        defaults.dictionary(forKey: Self.verdictsKey) as? [String: Bool] ?? [:]
    /// ".v2": the verdicts kept before build 54 could be a check that failed
    /// to run, stored as flagged; every photo is checked once more.
    private static let verdictsKey = "crews.photoVerdicts.v2"
    /// Bumped as verdicts arrive, so the screens draw again.
    private(set) var verdictRevision = 0

    func photoIsShown(_ photo: URL) -> Bool {
        // Read, so a screen showing photos is told when a verdict lands.
        _ = verdictRevision
        return switch incomingPolicy() {
        case .show: true
        case .hide: false
        case .check: photoVerdicts[photo.lastPathComponent] == true
        }
    }

    /// Analyses every friend's photo not yet seen. After each refresh.
    func checkArrivedPhotos() async {
        guard incomingPolicy() == .check else { return }
        var changed = false
        for wins in winsByCrew.values {
            for win in wins where win.senderProfileID != me {
                guard let photo = win.photo, photoVerdicts[photo.lastPathComponent] == nil,
                      let data = try? Data(contentsOf: photo),
                      let verdict = await incomingCheck(data) else { continue }
                photoVerdicts[photo.lastPathComponent] = verdict
                changed = true
            }
        }
        // Their stories' photos, as their crew wins' are (the review,
        // 2026-10-15: the row and the viewer drew them unchecked).
        for stories in storiesByCrew.values {
            for story in stories where story.sender != me {
                guard let photo = story.win.photo, photoVerdicts[photo.lastPathComponent] == nil,
                      let data = try? Data(contentsOf: photo),
                      let verdict = await incomingCheck(data) else { continue }
                photoVerdicts[photo.lastPathComponent] = verdict
                changed = true
            }
        }
        // Their story page's drawing and stickers, as a doodle is.
        for stories in storiesByCrew.values {
            for story in stories where story.sender != me {
                guard let art = story.wordsArt, photoVerdicts[art.lastPathComponent] == nil,
                      let data = try? Data(contentsOf: art),
                      let verdict = await incomingCheck(data) else { continue }
                photoVerdicts[art.lastPathComponent] = verdict
                changed = true
            }
        }
        // A friend's doodle is checked on this phone too, as their photo is
        // (spec section 3: "the receiving phone checks it again"). Doodles
        // are chat messages now; an old one on a reaction is never shown,
        // so it is never checked either.
        for messages in messagesByCrew.values {
            for message in messages where message.senderProfileID != me {
                guard let sketch = message.sketch, photoVerdicts[sketch.lastPathComponent] == nil,
                      let data = try? Data(contentsOf: sketch),
                      let verdict = await incomingCheck(data) else { continue }
                photoVerdicts[sketch.lastPathComponent] = verdict
                changed = true
            }
        }
        // And a friend's sticker on a chat line (2026-10-06): it is lifted
        // out of a photograph, so it is checked as one.
        for reactions in reactionsByCrew.values {
            for reaction in reactions where reaction.profileID != me && (reaction.isSticker || reaction.isStickerOnAWin) {
                guard let sticker = reaction.sketch, photoVerdicts[sticker.lastPathComponent] == nil,
                      let data = try? Data(contentsOf: sticker),
                      let verdict = await incomingCheck(data) else { continue }
                photoVerdicts[sticker.lastPathComponent] = verdict
                changed = true
            }
        }
        // **A friend's head and profile photo** (2026-10-08). Both are faces
        // from a friend's camera, drawn in every crew's row of faces, and on
        // a phone that checks friends' photos they were drawn unchecked: the
        // one picture of a person a 13 to 15 year old saw without the check
        // their wins get. A head passes only if every picture in it does; a
        // check that could not run leaves it for next time, never "flagged".
        for crew in crews {
            for member in crew.members where member.profileID != me {
                if let photo = member.photo, photoVerdicts[photo.lastPathComponent] == nil,
                   let data = try? Data(contentsOf: photo), let verdict = await incomingCheck(data) {
                    photoVerdicts[photo.lastPathComponent] = verdict
                    changed = true
                }
                if let head = member.head, photoVerdicts[head.lastPathComponent] == nil,
                   let data = try? Data(contentsOf: head), let faces = CrewHeadPack.images(in: data) {
                    var verdict: Bool? = !faces.isEmpty
                    for face in faces where verdict == true {
                        verdict = await incomingCheck(face)
                    }
                    if let verdict {
                        photoVerdicts[head.lastPathComponent] = verdict
                        changed = true
                    }
                }
            }
        }
        guard changed else { return }
        defaults.set(photoVerdicts, forKey: Self.verdictsKey)
        verdictRevision += 1
    }

    /// The crew's wins for its current day: what its tower shows. Nothing
    /// from someone you blocked.
    func today(in crewID: CrewID) -> [SharedWin] {
        guard let crew = crew(crewID) else { return [] }
        return wins(in: crewID, on: CrewDay.string(for: now(), in: crew.timeZone))
    }

    /// One crew day's wins as you see them: without anyone you blocked or
    /// anything you hid.
    func wins(in crewID: CrewID, on day: String) -> [SharedWin] {
        wins(in: crewID).filter {
            $0.crewDay == day && !blocked.contains($0.senderProfileID) && !hiddenWins.contains($0.winID)
        }
    }

    /// Wins you hid for yourself (`hide`), on every phone you own.
    private(set) var hiddenWins: Set<UUID> = []

    /// Out of your sight, and nobody else's: a friend's photo you would
    /// rather not see again. The crew is not told.
    func hide(winID: UUID) {
        hiddenWins.insert(winID)
        note(.hidden, winID.uuidString, 1)
    }

    /// **Back in sight** (the owner, 2026-10-13: "when you hide a win in
    /// the crew you can unhide it which i found weird", and of how: "There
    /// was no way to unhide it"). The same choice, set back, on every phone.
    func unhide(winID: UUID) {
        hiddenWins.remove(winID)
        note(.hidden, winID.uuidString, 0)
    }

    /// The wins in a crew you hid for yourself, newest first: what the
    /// crew's card offers to show again.
    func hiddenWins(in crewID: CrewID) -> [SharedWin] {
        (winsByCrew[crewID] ?? []).filter { hiddenWins.contains($0.winID) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Whether you may take a win out of the crew for everyone: your own,
    /// or anyone's in a crew you started (the moderation App Review asks
    /// for, and what a Shared Album's owner can do).
    func canRemove(_ winID: UUID, from crewID: CrewID) -> Bool {
        guard let crew = crew(crewID),
              let win = winsByCrew[crewID]?.first(where: { $0.winID == winID }) else { return false }
        return win.senderProfileID == me || crew.ownerProfileID == me
    }

    /// Takes a win out of the crew, from everyone's phone. Yours, or, in a
    /// crew you started, anyone's.
    func remove(winID: UUID, from crewID: CrewID) async {
        guard canRemove(winID, from: crewID) else { return }
        if winsByCrew[crewID]?.first(where: { $0.winID == winID })?.senderProfileID == me {
            await withdraw(winID: winID, from: crewID)
            return
        }
        guard isEnabled() else { return }
        if let photo = winsByCrew[crewID]?.first(where: { $0.winID == winID })?.photo {
            try? FileManager.default.removeItem(at: photo)
        }
        winsByCrew[crewID]?.removeAll { $0.winID == winID }
        enqueue(.init(crew: crewID, type: .sharedWin, name: winID.uuidString, fields: nil))
        await flush()
    }

    /// A crew as you see it: without anyone you blocked.
    func visible(_ crewID: CrewID) -> Crew? {
        guard var crew = crew(crewID) else { return nil }
        crew.members.removeAll { blocked.contains($0.profileID) }
        return crew
    }

    // MARK: Blocking

    /// People you blocked. Their wins, heads and names disappear from every
    /// crew on this phone, and they are not told (spec 9.2).
    private(set) var blocked: Set<UUID> = []
    /// Crews this phone left or ended by its own hand, so the tower that
    /// closes behind it does not say "This crew has ended." to the person
    /// who just chose to go (the 2026-10-15 review: Block and Leave did).
    @ObservationIgnored private(set) var leftByChoice: Set<CrewID> = []
    private static let blockedKey = "crews.blocked"
    /// The iCloud user the crews on this phone belong to.
    static let accountKey = "crews.account"

    func block(_ profileID: UUID, name: String = "") {
        blocked.insert(profileID)
        defaults.set(blocked.map(\.uuidString).sorted(), forKey: Self.blockedKey)
        // Their name, kept so the Blocked list can say who it is after they
        // have left every crew you share.
        var names = blockedNames
        names[profileID.uuidString] = name
        defaults.set(names, forKey: Self.blockedNamesKey)
        note(.blocked, profileID.uuidString, 1, name: name)
        recomputeUnread()
        replan()
    }

    func unblock(_ profileID: UUID) {
        blocked.remove(profileID)
        defaults.set(blocked.map(\.uuidString).sorted(), forKey: Self.blockedKey)
        var names = blockedNames
        names[profileID.uuidString] = nil
        defaults.set(names, forKey: Self.blockedNamesKey)
        note(.blocked, profileID.uuidString, 0)
        recomputeUnread()
        replan()
    }

    private static let blockedNamesKey = "crews.blockedNames"
    /// Who each blocked person is, by name, as they were when blocked.
    var blockedNames: [String: String] {
        defaults.dictionary(forKey: Self.blockedNamesKey) as? [String: String] ?? [:]
    }

    func blockedName(_ profileID: UUID) -> String {
        let name = blockedNames[profileID.uuidString] ?? ""
        return name.isEmpty ? "Someone" : name
    }

    // MARK: Shared wins

    /// The people Add Win's With row offers: everyone in the chosen crews
    /// but you and anyone you blocked, each once, in the crews' order. Never
    /// your contacts (spec 1).
    func taggable(in chosen: Set<CrewID>) -> [CrewMember] {
        var seen: Set<UUID> = [me]
        var people: [CrewMember] = []
        for crew in crews where chosen.contains(crew.id) {
            for member in visible(crew.id)?.others(than: me) ?? [] where seen.insert(member.profileID).inserted {
                people.append(member)
            }
        }
        return people
    }

    /// Answers to "Sam added you to a win", by win id: true kept, false Not
    /// This One. On this phone only, and never sent: saying no is silent and
    /// the tagger is never told (spec 1).
    private(set) var tagAnswers: [String: Bool] = [:]
    private static let tagAnswersKey = "crews.tagAnswers"

    /// The first win tagging you that you have not answered, in one crew or
    /// in any. Never your own, never one from someone you blocked, never one
    /// you hid. One win sent to two crews you share is one question, because
    /// the answer is kept by win id.
    func tagToAsk(in crewID: CrewID? = nil) -> SharedWin? {
        let held = crewID.map { [$0: winsByCrew[$0] ?? []] } ?? winsByCrew
        return held.keys.sorted { $0.rawValue < $1.rawValue }
            .flatMap { held[$0] ?? [] }
            .filter {
                $0.withPeople.contains(me) && $0.senderProfileID != me
                    && !blocked.contains($0.senderProfileID) && !hiddenWins.contains($0.winID)
                    && tagAnswers[$0.winID.uuidString] == nil
            }
            .min { ($0.createdAt, $0.winID.uuidString) < ($1.createdAt, $1.winID.uuidString) }
    }

    /// Keep, or Not This One. The answer is written first, so a second press
    /// (or the same win arriving in another crew) never makes a second copy.
    func answer(_ win: SharedWin, keep: Bool) async {
        let key = win.winID.uuidString
        guard tagAnswers[key] == nil else { return }
        tagAnswers[key] = keep
        defaults.set(tagAnswers, forKey: Self.tagAnswersKey)
        if keep { await keepTaggedWin(win) }
    }

    /// The newest win in a crew, for its row in the list.
    func latest(in crew: CrewID) -> SharedWin? {
        winsByCrew[crew]?.max { $0.createdAt < $1.createdAt }
    }

    /// The crews a win of yours is still waiting to reach.
    func pendingCrews(for winID: UUID) -> Set<CrewID> {
        _ = outboxRevision
        return outbox.pendingCrews(for: winID)
    }

    /// The crews a win of yours is in, sent or on its way. The ledger is
    /// what this phone sent, kept on disk, so it is right before the first
    /// fetch and offline: an edit or a delete made then still reaches every
    /// copy, and the Edit sheet shows the right ticks.
    func crews(holding winID: UUID) -> Set<CrewID> {
        var held = Set(winsByCrew.compactMap { id, wins in wins.contains { $0.winID == winID } ? id : nil })
        held.formUnion(pendingCrews(for: winID))
        held.formUnion(sent[winID]?.crews ?? [])
        return held.filter { id in crews.isEmpty || crews.contains { $0.id == id } }
    }

    // MARK: The ledger

    struct Sent: Codable, Equatable {
        var crews: Set<CrewID>
        /// What was sent, so an edit that changed nothing sends nothing.
        var signature: String
        /// Who the win was with, as chosen on Add Win. Kept here because an
        /// edit is rebuilt from the `HabitLog`, which has no field for it:
        /// without this, renaming a tagged win untagged it everywhere.
        var with: [UUID]? = nil
    }

    /// Who a sent win was with, read before a delete so Undo can send it
    /// back the same (the second reader, 2026-10-17).
    func sentWith(_ winID: UUID) -> [UUID] { sent[winID]?.with ?? [] }

    @ObservationIgnored private var sentCache: [UUID: Sent]?
    private static let sentKey = "crews.sent"

    private var sent: [UUID: Sent] {
        get {
            if let sentCache { return sentCache }
            let loaded = (defaults.data(forKey: Self.sentKey))
                .flatMap { try? JSONDecoder().decode([UUID: Sent].self, from: $0) } ?? [:]
            sentCache = loaded
            return loaded
        }
        set {
            sentCache = newValue
            defaults.set(try? JSONEncoder().encode(newValue), forKey: Self.sentKey)
        }
    }

    private static func signature(_ win: OwnWin) -> String {
        [win.title, win.colour.rawValue, win.icon.rawValue, win.blockSize.rawValue,
         win.photoKey ?? "-", win.cropX.map { String($0) } ?? "-", win.cropY.map { String($0) } ?? "-"]
            .joined(separator: "|")
    }

    #if DEBUG
    /// `-strataSeedSentToCrew`: wins marked as sent to a crew, so the crew
    /// album on Memories can be photographed without a cloud.
    func debugMarkSent(_ ids: [UUID], to crew: CrewID) {
        var ledger = sent
        for id in ids {
            var entry = ledger[id] ?? Sent(crews: [], signature: "")
            entry.crews.insert(crew)
            ledger[id] = entry
        }
        sent = ledger
    }

    /// `-strataSeedSentToCrew`: every other photographed win marked as sent
    /// to the first crew, once the seeded crews have arrived.
    func debugMarkSentIfAsked(context: ModelContext) async {
        guard DebugHarness.argument("-strataSeedSentToCrew") != nil else { return }
        for _ in 0..<40 where crews.isEmpty { try? await Task.sleep(for: .milliseconds(150)) }
        guard let crew = crews.first else { return }
        let logs = (try? context.fetch(FetchDescriptor<HabitLog>(predicate: #Predicate { $0.imageFileName != nil }))) ?? []
        debugMarkSent(logs.enumerated().filter { $0.offset % 2 == 0 }.map(\.element.id), to: crew.id)
    }
    #endif

    /// Your wins a crew holds, from this phone's own ledger rather than the
    /// cloud, so it outlives the two weeks a crew keeps a win
    /// (`Album.monthShelf`'s "With your crew").
    func winsSent(to crew: CrewID) -> Set<UUID> {
        Set(sent.compactMap { $0.value.crews.contains(crew) ? $0.key : nil })
    }

    private func record(_ win: OwnWin, in crewIDs: Set<CrewID>) {
        var ledger = sent
        var entry = ledger[win.winID] ?? Sent(crews: [], signature: "")
        entry.crews.formUnion(crewIDs)
        entry.signature = Self.signature(win)
        if !win.withPeople.isEmpty { entry.with = win.withPeople }
        ledger[win.winID] = entry
        sent = ledger
    }

    private func unrecord(_ winID: UUID, from crewIDs: Set<CrewID>? = nil) {
        var ledger = sent
        if let crewIDs {
            ledger[winID]?.crews.subtract(crewIDs)
            if ledger[winID]?.crews.isEmpty == true { ledger[winID] = nil }
        } else {
            ledger[winID] = nil
        }
        sent = ledger
    }

    /// Every win of yours in any crew: for Reset All Data.
    var everythingSent: [UUID] { Array(sent.keys) }

    // MARK: Crews

    /// `personal`: a chat of two (`CrewPersonal`), which counts against no
    /// cap and wants no photo.
    func createCrew(name: String, photoJPEG: Data? = nil, personal: Bool = false) async throws -> (crew: Crew, invite: URL) {
        try requireOn()
        guard joinGate() == .open else { throw CrewError.notReady }
        guard CrewWords.isAcceptableName(name) else { throw CrewError.wordsRefused }
        await cloud.prepare()
        guard personal || groupCrewCount < CrewCaps.crews else { throw CrewError.tooManyCrews }
        // The photo first, so a refused one stops the crew before its zone
        // exists. 13 to 15 send no photos and start crews with faces.
        var picture: Data?
        if photosAllowed() {
            if let photoJPEG {
                guard let small = await derived(photoJPEG), await photoCheck(small) else { throw CrewError.photoNotAllowed }
                picture = small
            } else if requiresCrewPhoto, !personal {
                throw CrewError.photoNeeded
            }
        }
        let now = now()
        var crew = Crew(id: .new(),
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        ownerProfileID: me,
                        timeZoneIdentifier: TimeZone.current.identifier,
                        createdAt: now,
                        photo: nil,
                        members: [CrewMember(profileID: me, firstName: myFirstName(), head: nil, joinedAt: now, handle: myHandle())],
                        personal: personal ? true : nil)
        if let picture {
            let file = directory.appending(path: "Photos/\(crew.id.rawValue)/crew-\(UUID().uuidString).jpg")
            try write(picture, to: file)
            crew.photo = file
        }
        let url = try await cloud.createZone(crew)
        // A crew is all or nothing: a zone without its crew record is never
        // listed, so one left by a failed save would only cost a sync on
        // every refresh (2026-10-08, a full iCloud).
        do {
            try await cloud.save(CrewRecords.fields(crew), type: .crew, name: CrewRecords.crewRecordName, in: crew.id)
            try await cloud.save(CrewRecords.fields(crew.members[0]), type: .member,
                                 name: CrewRecords.name(of: crew.members[0]), in: crew.id)
        } catch {
            try? await cloud.endCrew(crew.id)
            throw error
        }
        crews.append(crew)
        winsByCrew[crew.id] = []
        // A refresh already in flight fetched before this zone existed.
        if isRefreshing { refreshAgain = true }
        await shareMyself()
        if announces { await CrewNotifications.askOnce() }
        Analytics.shared.signal(.crewCreated)
        return (crew, url)
    }

    /// The link that invites someone. Refused once the crew has eight.
    func inviteURL(for crewID: CrewID) async throws -> URL {
        try requireOn()
        guard let crew = crew(crewID) else { throw CrewError.unknownCrew }
        guard crew.members.count < CrewCaps.members else { throw CrewError.crewFull }
        // A personal chat is two people: its one link went, sealed, to the
        // other, and no other link is ever made (the review, 2026-10-16).
        guard !crew.isPersonal else { throw CrewError.crewFull }
        return try await cloud.shareURL(for: crewID)
    }

    /// Joins the crew an invitation is for, if there is room on both sides.
    ///
    /// **Only once the gate is open** (the 2026-10-08 audit): iOS 26, the
    /// rules agreed, an age answered and not under 13. It used to join the
    /// share and write a Member record first, and the rules and the age were
    /// asked only if the person later opened the Crews list. Nothing here
    /// touches the cloud before the check: `CrewRouter` holds the invitation
    /// while the rules and the age are asked, and lets it go on a no.
    /// Group crews only: a personal chat never counts toward a cap, a count,
    /// an invitation or a story's fan-out.
    var groupCrews: [Crew] { crews.filter { !$0.isPersonal } }

    /// **The other person in a message thread** (`isPersonal`): who is in it
    /// with you, or, before they have joined, who you started it with,
    /// named as the crew you share names them.
    func directFriend(_ crewID: CrewID) -> CrewMember? {
        guard let crew = crew(crewID), crew.isPersonal else { return nil }
        // Never someone blocked (the review, 2026-10-16): their thread
        // shows nobody, and the list leaves it out.
        if let other = crew.members.first(where: { $0.profileID != me }) {
            return blocked.contains(other.profileID) ? nil : other
        }
        guard let started = personalStarted.first(where: { $0.value.crew == crewID.rawValue }),
              let friend = UUID(uuidString: started.key), !blocked.contains(friend) else { return nil }
        return groupCrews.lazy.compactMap { $0.member(friend) }.first
    }

    /// Everyone you share a crew with, once each, for a new message: not
    /// you, not anyone blocked, named as a crew names them.
    var messageablePeople: [(member: CrewMember, crew: CrewID)] {
        var seen: Set<UUID> = [me]
        var out: [(member: CrewMember, crew: CrewID)] = []
        for crew in groupCrews {
            for member in crew.members where !seen.contains(member.profileID) && !blocked.contains(member.profileID) {
                seen.insert(member.profileID)
                out.append((member, crew.id))
            }
        }
        return out.sorted { $0.member.firstName.localizedCaseInsensitiveCompare($1.member.firstName) == .orderedAscending }
    }
    var groupCrewCount: Int { groupCrews.count }

    /// `personalFrom`: the friend a personal chat's invitation came from. The
    /// crew joined must then be a personal chat they started, with nobody in
    /// it but the two of you, or the join is turned away (the review,
    /// 2026-10-16: a forged invitation could put you in any crew).
    func accept(_ invite: CrewInvite, personal: Bool = false, personalFrom: UUID? = nil,
                personalName: String? = nil) async throws -> Crew {
        try requireOn()
        guard joinGate() == .open else { throw CrewError.notReady }
        if crews.isEmpty { await refresh() }
        // At the cap, a link to a crew you are ALREADY in still opens it
        // (the audit, 2026-10-08: it said "five crews already"). Which crew a
        // link is for is only known once it is accepted, and accepting one
        // you are in changes nothing; a new one is left again at once.
        let atCap = !personal && groupCrewCount >= CrewCaps.crews
        // Asked before the join begins: a refresh running alongside it
        // lists the crew being joined, and it then looked already joined.
        let before = Set(crews.map(\.id))
        let id = try await cloud.accept(invite)
        let wasIn = before.contains(id)
        if atCap, !wasIn {
            // **Turned away, not left** (the third read, 2026-10-10). In the
            // public database leaving deletes everything this ACCOUNT wrote
            // in the crew, so a phone at its cap opening a link to a crew
            // your other phone is in would have emptied you out of it, and
            // deleted the crew itself if you started it.
            await cloud.decline(id)
            throw CrewError.tooManyCrews
        }
        // **A join ends one of two ways, said to the cloud** (the fourth
        // read): settled, with your member record written, or turned away.
        // Left half done, its key reached your key backup, came back on the
        // next sync, and "that crew is full" became a ninth member.
        let crew: Crew
        do {
            let fetched = try await cloud.fetchCrews()
            guard let found = fetched.first(where: { $0.id == id }) else { throw CrewError.unknownCrew }
            // Accepting is where the second check happens: eight people were
            // already in it when the link was opened.
            guard found.members.filter({ $0.profileID != me }).count < CrewCaps.members else { throw CrewError.crewFull }
            if let from = personalFrom {
                // And named as they are in the crew you share: a chat that
                // calls itself Sam is Sam's (the review, 2026-10-16).
                guard found.isPersonal, found.ownerProfileID == from, !blocked.contains(from),
                      found.members.allSatisfy({ $0.profileID == from || $0.profileID == me }),
                      personalName == nil || found.member(from)?.firstName == personalName else {
                    throw CrewError.unknownCrew
                }
            }
            let member = CrewMember(profileID: me, firstName: myFirstName(), head: nil, joinedAt: now(), handle: myHandle())
            try await cloud.save(CrewRecords.fields(member), type: .member, name: CrewRecords.name(of: member), in: id)
            crew = found
        } catch {
            // Full, or not there: turned away. Anything else (no signal, a
            // full iCloud) and the join stands: the key is held, and the
            // next refresh writes the member record
            // (`repairMissingMembership`, the 2026-10-08 audit).
            let turnedAway = (error as? CrewError) == .crewFull || (error as? CrewError) == .unknownCrew
            if turnedAway, !wasIn { await cloud.decline(id) } else { await cloud.settle(id) }
            throw error
        }
        await cloud.settle(id)
        // A personal chat joined in the background says nothing and asks
        // nothing: no ping, no permission prompt out of nowhere.
        if !wasIn, personalFrom == nil { await pingJoined(id) }
        await refresh()
        await shareMyself()
        if announces, personalFrom == nil { await CrewNotifications.askOnce() }
        Analytics.shared.signal(.crewJoined)
        return self.crew(id) ?? crew
    }

    func rename(_ crewID: CrewID, to name: String) async throws {
        try requireOn()
        guard var crew = crew(crewID) else { throw CrewError.unknownCrew }
        guard CrewWords.isAcceptableName(name) else { throw CrewError.wordsRefused }
        crew.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        replace(crew)
        // Held over any refresh until it is saved: the live sync every few
        // seconds fetched the crew before the save landed and put the old
        // name back (the owner, 2026-10-03: "it goes back to the name it
        // just was").
        editing[crewID] = crew
        defer { editing[crewID] = nil }
        try await cloud.save(CrewRecords.fields(crew), type: .crew, name: CrewRecords.crewRecordName, in: crewID)
    }

    /// A new picture for the crew, or nil to go back to the members' faces.
    func setPhoto(_ crewID: CrewID, jpeg: Data?) async throws {
        try requireOn()
        guard var crew = crew(crewID) else { throw CrewError.unknownCrew }
        if let jpeg {
            // A crew's picture is a photograph like any other: the same age
            // rule and the same check (found 2026-10-02, privacy pass).
            guard photosAllowed(), let small = await derived(jpeg) else { throw CrewError.photoNotAllowed }
            guard await photoCheck(small) else { throw CrewError.photoNotAllowed }
            let url = directory.appending(path: "Photos/\(crewID.rawValue)/crew-\(UUID().uuidString).jpg")
            try write(small, to: url)
            crew.photo = url
        } else {
            crew.photo = nil
        }
        replace(crew)
        editing[crewID] = crew
        defer { editing[crewID] = nil }
        try await cloud.save(CrewRecords.fields(crew), type: .crew, name: CrewRecords.crewRecordName, in: crewID)
    }

    /// You, as your crews see you: your head (never under 16). Called on
    /// starting or joining a crew and whenever it changes.
    ///
    /// **No profile photograph is ever sent** (the owner, 2026-10-14: "remove
    /// the option for a pfp"). Every share writes `photo: nil`, which takes
    /// back one an older build sent; somebody without a head is the blank
    /// head on every phone.
    ///
    /// **Except the one you choose instead of a head** (the owner,
    /// 2026-10-16, reversing the above): your photograph goes in place of
    /// your head, on the same photo rule (never under 16) and through the
    /// same check as a win's photograph; held back, nothing goes.
    func shareMyself() async {
        guard isEnabled() else { return }
        if let photo = myPhoto() {
            var sentPhoto: Data?
            if photosAllowed(), let small = await derived(photo), await photoCheck(small) { sentPhoto = small }
            await setMyHead(nil, photo: sentPhoto)
            // Held back by the check (or a check that could not run): not
            // recorded as sent, so the next launch tries again (the review).
            if sentPhoto != nil || !photosAllowed() {
                defaults.set(selfDigest(pack: nil), forKey: Self.sentSelfKey)
            }
            return
        }
        let pack = await headToSend()
        var sent = pack
        // **The head is a photograph too** (the 2026-10-08 audit): checked
        // as one, every face of it, once per head. One the check holds back
        // is not sent, and is remembered so it is not checked again every
        // launch.
        if let pack, case let digest = Self.digest(pack), digest != defaults.string(forKey: Self.passedHeadKey) {
            if await headCheck(pack) {
                defaults.set(digest, forKey: Self.passedHeadKey)
            } else {
                sent = nil
                defaults.set(digest, forKey: Self.heldHeadKey)
            }
        }
        await setMyHead(sent, photo: nil)
        defaults.set(selfDigest(pack: pack), forKey: Self.sentSelfKey)
    }

    /// **Your head leaves the phone on the photo rule** (the 2026-10-08
    /// audit): 16 and over, never 13 to 15 or declined (`photosAllowed`). It
    /// went to every crew regardless of age, and a head is cut out of a
    /// photograph of you. Under the rule no head is sent, and one sent
    /// before is taken back.
    private func headToSend() async -> Data? {
        guard photosAllowed() else { return nil }
        return await myHeadPack()
    }

    static let heldHeadKey = "crews.heldHead"
    static let passedHeadKey = "crews.passedHead"

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// **You, sent again when you changed while this phone was not
    /// sending.** Once a launch, after the first refresh: a head made on a
    /// build that never sent it, or a change made with no signal, reaches
    /// your crews without anyone touching anything. Cheap when nothing
    /// changed: one digest compared.
    func shareMyselfIfChanged() async {
        guard isEnabled(), !checkedSelf, !crews.isEmpty else { return }
        checkedSelf = true
        // A photograph in place of a head: its own digest, and no head is
        // missing on purpose (the review: every launch re-sent it otherwise).
        if myPhoto() != nil {
            guard selfDigest(pack: nil) != defaults.string(forKey: Self.sentSelfKey) else { return }
            await shareMyself()
            return
        }
        let pack = await headToSend()
        let digest = selfDigest(pack: pack)
        // A head the check held back is missing on purpose.
        let heldBack = pack.map { Self.digest($0) == defaults.string(forKey: Self.heldHeadKey) } ?? false
        let mineMissingHead = pack != nil && !heldBack && crews.contains { $0.member(me).map { $0.head == nil } ?? false }
        guard digest != defaults.string(forKey: Self.sentSelfKey) || mineMissingHead else { return }
        await shareMyself()
    }

    @ObservationIgnored var checkedSelf = false
    static let sentSelfKey = "crews.sentSelf"

    /// The photo's slot stays in the digest, empty: somebody whose last
    /// share carried a photo digests differently now, so the next launch
    /// shares again and the photo is taken back from their crews.
    private func selfDigest(pack: Data?) -> String {
        var hasher = SHA256()
        hasher.update(data: pack ?? Data())
        hasher.update(data: Data([0]))
        hasher.update(data: myPhoto() ?? Data())
        // The photo rule too: a change in it takes a sent photograph back
        // (or sends it), as a head's does.
        hasher.update(data: Data([photosAllowed() ? 1 : 0]))
        hasher.update(data: Data(myFirstName().utf8))
        hasher.update(data: Data((myHandle() ?? "").utf8))
        hasher.update(data: Data((FeaturedWins.encode(myFeatured()) ?? "").utf8))
        hasher.update(data: Data(crews.map(\.id.rawValue).sorted().joined(separator: ",").utf8))
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// **Your score, told to your crews when it changes** (2026-10-15), on
    /// its own small record (`CrewRecordType.score`), so a friend's profile
    /// shows it. Never on the member record: that carries your head, and the
    /// review found writing it after every win re-sent the head to every crew
    /// and could overwrite a head change still on its way. Settled for a few
    /// seconds first, so a run of wins is one write, and only where the
    /// numbers moved.
    func noteMyScore(_ tally: WinsScore.Tally, settle: Duration = .seconds(3)) {
        guard isEnabled(), !crews.isEmpty else { return }
        scoreSoon?.cancel()
        scoreSoon = Task { @MainActor in
            try? await Task.sleep(for: settle)
            guard !Task.isCancelled else { return }
            var changed = false
            for crew in crews {
                guard let mine = crew.member(me), mine.score != tally.score || mine.wins != tally.wins else { continue }
                if let i = crews.firstIndex(where: { $0.id == crew.id }),
                   let j = crews[i].members.firstIndex(where: { $0.profileID == me }) {
                    crews[i].members[j].score = tally.score
                    crews[i].members[j].wins = tally.wins
                }
                enqueue(.init(crew: crew.id, type: .score, name: me.uuidString,
                              fields: CrewRecords.scoreFields(profileID: me, score: tally.score, wins: tally.wins)))
                changed = true
            }
            if changed { await flush() }
        }
    }
    @ObservationIgnored private(set) var scoreSoon: Task<Void, Never>?

    /// Something about you changed (your name, photo or head): your crews
    /// hear once things settle, so typing a name sends one update, not one a
    /// letter. Cheap to call from anywhere; does nothing while crews are off.
    static func noteMyselfChanged() {
        guard CrewsFlag.isOn else { return }
        shared.shareSoon?.cancel()
        shared.shareSoon = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await shared.shareMyself()
        }
    }

    @ObservationIgnored private var shareSoon: Task<Void, Never>?

    /// Reset All Data: every win of yours leaves every crew, and you are what
    /// the reset left (no name, no photo, no head).
    func withdrawEverything() async {
        guard isEnabled() else { return }
        for id in everythingSent { await deleteEverywhere(winID: id) }
        // And every reaction you gave, in every crew.
        for (crewID, reactions) in reactionsByCrew {
            for reaction in reactions where reaction.profileID == me {
                enqueue(.init(crew: crewID, type: .reaction, name: reaction.id, fields: nil))
            }
            reactionsByCrew[crewID]?.removeAll { $0.profileID == me }
        }
        // And every line you said.
        for (crewID, messages) in messagesByCrew {
            for message in messages where message.senderProfileID == me {
                enqueue(.init(crew: crewID, type: .message, name: CrewRecords.name(of: message), fields: nil))
            }
            messagesByCrew[crewID]?.removeAll { $0.senderProfileID == me }
        }
        await flush()
        await shareMyself()
    }

    /// Your head, as friends see it. Nil takes it away.
    func setMyHead(_ pack: Data?, photo: Data? = nil) async {
        guard isEnabled() else { return }
        for crew in crews {
            guard var mine = crew.member(me) else { continue }
            if let pack {
                let url = directory.appending(path: "Heads/\(crew.id.rawValue)/\(me.uuidString).head")
                do { try write(pack, to: url) } catch {
                    Self.log.error("could not keep my head for \(crew.id.rawValue, privacy: .public): \(error)")
                    continue
                }
                mine.head = url
            } else {
                mine.head = nil
            }
            if let photo {
                let url = directory.appending(path: "Heads/\(crew.id.rawValue)/\(me.uuidString).jpg")
                if (try? write(photo, to: url)) != nil { mine.photo = url }
            } else {
                mine.photo = nil
            }
            mine.firstName = myFirstName()
            mine.handle = myHandle()
            // Only wins this crew was sent (the review: every crew was told of
            // every featured win, sent there or not).
            let sentHere = Set((winsByCrew[crew.id] ?? []).filter { $0.senderProfileID == me }.map(\.winID))
            mine.featured = myFeatured().filter { sentHere.contains($0.win) }
            // Held here at once, not only after the next fetch: what this
            // phone shows of you, and what `shareMyselfIfChanged` compares,
            // is what was just sent.
            if let i = crews.firstIndex(where: { $0.id == crew.id }),
               let j = crews[i].members.firstIndex(where: { $0.profileID == me }) {
                crews[i].members[j] = mine
            }
            enqueue(.init(crew: crew.id, type: .member, name: CrewRecords.name(of: mine), fields: CrewRecords.fields(mine)))
        }
        await flush()
    }

    /// Leaves a crew someone else started: your wins and your Member record
    /// go from its zone first, then you go.
    func leave(_ crewID: CrewID) async throws {
        try requireOn()
        guard let crew = crew(crewID) else { throw CrewError.unknownCrew }
        if crew.isOwner(me) { return try await end(crewID) }
        // **The leaving is said first** (the fourth read). Your posts and
        // member record were deleted before the note that you left existed,
        // so a failure in between left you in the crew with your posts
        // gone, and your other phone, seeing no member and no note, wrote
        // you back. With the note down, anything that fails after it is
        // finished by the next refresh.
        try await cloud.willLeave(crewID)
        leavingCrews.insert(crewID)
        defer { leavingCrews.remove(crewID) }
        for win in winsByCrew[crewID] ?? [] where win.senderProfileID == me {
            try await cloud.delete(type: .sharedWin, name: CrewRecords.name(of: win), in: crewID)
        }
        // Your reactions leave with you as well (the 2026-10-03 audit: they
        // stayed on your friends' wins after you had gone).
        for reaction in reactionsByCrew[crewID] ?? [] where reaction.profileID == me {
            try? await cloud.delete(type: .reaction, name: reaction.id, in: crewID)
        }
        // And your lines in its chat.
        for message in messagesByCrew[crewID] ?? [] where message.senderProfileID == me {
            try? await cloud.delete(type: .message, name: CrewRecords.name(of: message), in: crewID)
        }
        // And your stories in it, whichever this phone posted there.
        var mine = Set((storiesByCrew[crewID] ?? []).filter { $0.sender == me }.map(\.id))
        for (winID, entry) in storyLedger where entry.crews.contains(crewID.rawValue) { mine.insert(winID) }
        for winID in mine {
            try? await cloud.delete(type: .story, name: winID.uuidString, in: crewID)
            storyLedger[winID]?.crews.remove(crewID.rawValue)
        }
        if !mine.isEmpty { persistStoryLedger() }
        // Your score goes with you; left behind it would show nobody, since
        // a crew's people are read from member records alone.
        try? await cloud.delete(type: .score, name: me.uuidString, in: crewID)
        try await cloud.delete(type: .member, name: me.uuidString, in: crewID)
        try await cloud.leave(crewID)
        leftByChoice.insert(crewID)
        notePersonalLeft(crew)
        forget(crewID)
    }

    /// Ends a crew you started, for everyone.
    func end(_ crewID: CrewID) async throws {
        try requireOn()
        guard let crew = crew(crewID) else { throw CrewError.unknownCrew }
        guard crew.isOwner(me) else { throw CrewError.notOwner }
        try await cloud.endCrew(crewID)
        notePersonalLeft(crew)
        leftByChoice.insert(crewID)
        forget(crewID)
    }

    /// Removes someone. Only the person who started the crew may.
    func remove(member profileID: UUID, from crewID: CrewID) async throws {
        try requireOn()
        guard var crew = crew(crewID) else { throw CrewError.unknownCrew }
        guard crew.isOwner(me) else { throw CrewError.notOwner }
        try await cloud.removeParticipant(profileID, from: crewID)
        crew.members.removeAll { $0.profileID == profileID }
        replace(crew)
        // Their wins and reactions leave this phone now and every phone's
        // view at the removal (`PublicCrewCloud.keep`). **Their records are
        // theirs to delete** (2026-10-10): in the public database only a
        // record's writer may, so the deletes this queued were each refused
        // by the server and retried until given up on. Their own phone
        // deletes them when it reads the removal (`tidyAway`).
        winsByCrew[crewID]?.removeAll { $0.senderProfileID == profileID }
        reactionsByCrew[crewID]?.removeAll { $0.profileID == profileID }
        messagesByCrew[crewID]?.removeAll { $0.senderProfileID == profileID }
        await flush()
    }

    // MARK: Wins

    /// Sends a win to the crews chosen for it. Nothing is asked: the choice
    /// was made on the checkboxes, or is the one you made last time.
    func post(_ win: OwnWin, to chosen: Set<CrewID>) async {
        guard isEnabled() else { return }
        let win = withTags(win)
        let photo = await checkedPhoto(for: win)
        // **The crew with the most people first** (found by review,
        // 2026-10-13): a win's ping is skipped for a crew whose people have
        // all heard (`pingIfNew`), so the order decides how many are told
        // twice, and a set has none. Largest first tells the fewest twice.
        let ordered = chosen.sorted { a, b in
            let (x, y) = (crew(a)?.members.count ?? 0, crew(b)?.members.count ?? 0)
            return x != y ? x > y : a.rawValue < b.rawValue
        }
        for crewID in ordered {
            guard let crew = crew(crewID) else { continue }
            let shared = sharedWin(win, in: crew, photo: photo.flatMap { copy($0, to: crewID, win: win.winID) })
            upsertLocal(shared)
            enqueue(.init(crew: crewID, type: .sharedWin, name: CrewRecords.name(of: shared), fields: CrewRecords.fields(shared)))
        }
        record(win, in: chosen.filter { crew($0) != nil })
        nudgeLive()
        await flush()
        for crewID in chosen { await pingMilestone(crewID) }
    }

    /// An edit: every copy changes, in every crew it is in. An edit that
    /// changed nothing a crew sees (a save that only touched a note, say)
    /// sends nothing.
    func update(_ win: OwnWin) async {
        guard isEnabled() else { return }
        let holding = crews(holding: win.winID)
        // A win on tonight's story changes there too (R3), crews or none.
        if isOnStory(win.winID) { await updateStory(win) }
        guard !holding.isEmpty else { return }
        guard sent[win.winID]?.signature != Self.signature(win) else { return }
        let win = withTags(win)
        let photo = await checkedPhoto(for: win)
        for crewID in holding {
            guard let crew = crew(crewID) else { continue }
            let existing = winsByCrew[crewID]?.first { $0.winID == win.winID }
            var shared = sharedWin(win, in: crew, photo: photo.flatMap { copy($0, to: crewID, win: win.winID) })
            // A win stays in the day it was first sent to.
            if let existing { shared.crewDay = existing.crewDay }
            upsertLocal(shared)
            enqueue(.init(crew: crewID, type: .sharedWin, name: CrewRecords.name(of: shared), fields: CrewRecords.fields(shared)))
            // The picture it had, once nothing shows it: a redrawn doodle, a
            // replaced photograph, or one taken off (`copy`).
            if let old = existing?.photo, old != shared.photo {
                try? FileManager.default.removeItem(at: old)
            }
        }
        record(win, in: [])
        await flush()
    }

    /// The Edit screen's checkboxes: send to the crews newly ticked, pull back
    /// from the ones unticked.
    func setCrews(for win: OwnWin, to chosen: Set<CrewID>) async {
        guard isEnabled() else { return }
        let holding = crews(holding: win.winID)
        let added = chosen.subtracting(holding)
        for crewID in holding.subtracting(chosen) { await withdraw(winID: win.winID, from: crewID) }
        if !added.isEmpty { await post(win, to: added) }
    }

    /// A win rebuilt from its `HabitLog` (an edit, or a crew ticked on the
    /// Edit sheet) carries no tags: it gets back the ones it was sent with.
    private func withTags(_ win: OwnWin) -> OwnWin {
        guard win.withPeople.isEmpty else { return win }
        var win = win
        win.withPeople = sent[win.winID]?.with
            ?? winsByCrew.values.lazy.compactMap { $0.first { $0.winID == win.winID } }.first?.withPeople
            ?? []
        return win
    }

    /// Unticking a crew deletes that crew's copy.
    func withdraw(winID: UUID, from crewID: CrewID) async {
        guard isEnabled() else { return }
        winsByCrew[crewID]?.removeAll { $0.winID == winID }
        enqueue(.init(crew: crewID, type: .sharedWin, name: winID.uuidString, fields: nil))
        unrecord(winID, from: [crewID])
        await flush()
    }

    /// Deleting a win deletes every copy of it, everywhere.
    func deleteEverywhere(winID: UUID) async {
        guard isEnabled() else { return }
        // **Every delete queued before anything waits** (the rare-bug hunt,
        // 2026-10-16): the story's withdrawal sends before it returns, and
        // an app killed during that send never queued the crews' deletes,
        // so friends saw a deleted win for two weeks. The outbox is on disk.
        for crewID in crews(holding: winID) {
            winsByCrew[crewID]?.removeAll { $0.winID == winID }
            enqueue(.init(crew: crewID, type: .sharedWin, name: winID.uuidString, fields: nil))
        }
        unrecord(winID)
        // Off tonight's story as well, at once (R3).
        if isOnStory(winID) { await withdrawStory(winID: winID) }
        await flush()
    }

    /// Removing a photograph removes it from every copy. The win stays: the
    /// photo removal rule (CLAUDE.md) is that a photo is never the win.
    func removePhotoEverywhere(winID: UUID) async {
        guard isEnabled() else { return }
        let onStory = isOnStory(winID)
        for crewID in crews(holding: winID) {
            guard var shared = winsByCrew[crewID]?.first(where: { $0.winID == winID }) else { continue }
            if let photo = shared.photo { try? FileManager.default.removeItem(at: photo) }
            shared.photo = nil
            shared.updatedAt = now()
            upsertLocal(shared)
            enqueue(.init(crew: crewID, type: .sharedWin, name: winID.uuidString, fields: CrewRecords.fields(shared)))
        }
        // The story's after the crews' are queued, as a delete is.
        if onStory { await removeStoryPhoto(winID: winID) }
        await flush()
    }

    // MARK: Reactions

    /// Everyone's reactions to a win, oldest first, without anyone you blocked.
    func reactions(to winID: UUID, in crewID: CrewID) -> [Reaction] {
        (reactionsByCrew[crewID] ?? [])
            .filter { $0.winID == winID && !blocked.contains($0.profileID) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// Whether this phone may write in a crew: replies, doodles and the
    /// chat. Not while the age is unknown; they can still read the chat.
    /// **Declined may, as 13 to 15 may** (2026-10-08, `CrewAge.rule`): the
    /// privacy policy treats them as 13 to 15, so the app does too.
    @ObservationIgnored var canReply: () -> Bool = { CrewAge.current.writesInCrews }

    /// `refusedSketch`: the photo check held a doodle back. `throttled`: a
    /// second write inside the gap (`CrewSendThrottle`), dropped quietly.
    /// `dailyLimit`: 200 lines in this crew today.
    enum ReplyOutcome { case sent, refusedWords, refusedSketch, notAllowed, throttled, dailyLimit }

    /// **Whether writes to a crew are paced** (`CrewSendThrottle`,
    /// 2026-10-08). The phone's own store is; a test's is not, unless it is
    /// about the pace.
    @ObservationIgnored var throttles = false
    private static let throttleKey = "crews.sendThrottle"
    @ObservationIgnored private lazy var throttle: CrewSendThrottle =
        defaults.data(forKey: Self.throttleKey).flatMap { try? JSONDecoder().decode(CrewSendThrottle.self, from: $0) }
        ?? CrewSendThrottle()

    /// Nil when a write of `kind` to `crew` may go now, and counts it;
    /// otherwise what to answer instead.
    private func paced(_ kind: CrewSendThrottle.Kind, in crew: Crew, item: UUID? = nil) -> ReplyOutcome? {
        guard throttles else { return nil }
        let day = CrewDay.string(for: now(), in: crew.timeZone)
        switch throttle.verdict(kind, crew: crew.id.rawValue, day: day, at: now(), item: item?.uuidString) {
        case .tooFast: return .throttled
        case .dailyLimit: return .dailyLimit
        case .allowed:
            throttle.record(kind, crew: crew.id.rawValue, day: day, at: now(), item: item?.uuidString)
            defaults.set(try? JSONEncoder().encode(throttle), forKey: Self.throttleKey)
            return nil
        }
    }

    // MARK: The day chat

    /// **A crew's chat, as this phone shows it**: today's lines only, in the
    /// crew's zone, oldest first; nobody you blocked; and a friend's doodle
    /// only once this phone's own photo check has passed it, as a friend's
    /// photo is. The cloud may still hold yesterday's until each writer's
    /// phone deletes its own; none of it is ever shown.
    func messages(in crewID: CrewID) -> [CrewMessage] {
        guard let crew = crew(crewID) else { return [] }
        let today = CrewDay.string(for: now(), in: crew.timeZone)
        // **A message to one person keeps** (the owner, 2026-10-16: "I need
        // just a way to message individuals"): a crew's chat is today's, a
        // conversation is the two weeks the cloud holds, as Messages keeps
        // what was said.
        let oldest = crew.isPersonal ? (CrewDay.oldestKept(today: today, in: crew.timeZone) ?? today) : today
        let people = Set(crew.members.map(\.profileID))
        return (messagesByCrew[crewID] ?? [])
            .filter { message in
                // A drawing an older build threw onto the tower is not a
                // line in the chat (`CrewMessage.isToss`), so nothing that
                // reads this list (the chat, its dot, its alerts, a line's
                // reactions) ever meets one. Nothing shows them any more.
                !message.isToss
                    && message.crewDay >= oldest && message.crewDay <= today && people.contains(message.senderProfileID)
                    && !blocked.contains(message.senderProfileID)
                    // Hidden for you (`hide`): a line's id shares the set a
                    // win's does, synced the same way to your other phones.
                    && !hiddenWins.contains(message.messageID)
                    && (message.text.isEmpty || message.isStrip || CrewWords.isAcceptable(message.text))
                    && (message.senderProfileID == me || message.sketch.map(photoIsShown) ?? true)
                    // A line of yours deleted a moment ago, while its Undo stands.
                    && !deletingLines.contains(message.messageID)
            }
            .sorted { ($0.createdAt, $0.messageID.uuidString) < ($1.createdAt, $1.messageID.uuidString) }
    }

    /// **A line in the crew's chat.** Words only, up to 280, checked here
    /// first (`CrewWords`); `quoting` a win in this crew makes it a reply
    /// to it. It clears when the crew's day ends (`prune`).
    @discardableResult
    func send(_ text: String, in crewID: CrewID, quoting winID: UUID? = nil, storyQuote: String? = nil) async -> ReplyOutcome {
        let words = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(CrewMessage.textLimit))
        guard canReply(), isEnabled(), let crew = crew(crewID), !words.isEmpty else { return .notAllowed }
        // A win in this crew, or **one of today's lines** (Reply on a line,
        // 2026-10-14): `quoteWinID` holds either, as a reaction's `winID`
        // does, since a line's id is never a win's.
        // And a story this crew holds (Tonight's Story: it was refused here,
        // so a reply to a story never went, found 2026-10-16).
        if let winID, !holdsWinOrStory(winID, in: crewID),
           !messages(in: crewID).contains(where: { $0.messageID == winID }) { return .notAllowed }
        guard CrewWords.isAcceptable(words) else { return .refusedWords }
        if let held = paced(.message, in: crew) { return held }
        Analytics.shared.signal(.crewMessageSent)
        let message = CrewMessage(messageID: UUID(), crewID: crewID, senderProfileID: me,
                                  crewDay: CrewDay.string(for: now(), in: crew.timeZone), text: words,
                                  quoteWinID: winID, createdAt: now(), storyQuote: storyQuote)
        keep(message)
        await flush()
        return .sent
    }

    /// **A doodle in the crew's chat**, quoting the win it was drawn for if
    /// there is one. The PNG passes the photo check a crew photo passes
    /// (`photoCheck`, `CrewSafety.photoIsFine` on the phone) before it is
    /// sent, and the receiving phone checks it again (`checkArrivedPhotos`).
    @discardableResult
    func sendDoodle(_ png: Data, in crewID: CrewID, quoting winID: UUID? = nil) async -> ReplyOutcome {
        await sendSketch(png, text: "", in: crewID, quoting: winID)
    }

    /// **Your photo strip in the crew's chat** (`CrewStripShare`): a
    /// picture, marked, checked and paced as a doodle is, gone at the crew's
    /// midnight like every line.
    @discardableResult
    func sendStrip(_ png: Data, in crewID: CrewID) async -> ReplyOutcome {
        // A strip is photographs. It went out for anyone who could write
        // (found by review, 2026-10-12), which a 13 to 15 year old can.
        guard photosAllowed() else { return .notAllowed }
        return await sendSketch(png, text: CrewMessage.stripMarker, in: crewID, quoting: nil)
    }

    /// **A plan the crew can see** (`GroupPlan`): a line in the chat like
    /// any other, so it is sealed, paced, checked and cleared as one. The
    /// plan as it went, or nil with why it did not.
    func sendPlan(title: String, when: GroupPlan.When, in crewID: CrewID) async -> (outcome: ReplyOutcome, plan: GroupPlan?) {
        guard let crew = crew(crewID) else { return (.notAllowed, nil) }
        let day = CrewDay.string(for: now(), in: crew.timeZone)
        guard let line = GroupPlan.line(title: title, when: when, sentOn: day) else { return (.notAllowed, nil) }
        let outcome = await send(line, in: crewID)
        guard outcome == .sent else { return (outcome, nil) }
        let sent = (messagesByCrew[crewID] ?? []).last { $0.senderProfileID == me && $0.text == line }
        return (.sent, sent?.groupPlan)
    }

    /// What a sticker's line says where nothing draws it as a picture.
    static let stickerWord = CrewMessage.stickerWord

    /// **A sticker in the chat**, drawn as the picture it is
    /// (`CrewMessage.pictureMarker`). Checked and paced as a doodle is.
    @discardableResult
    func sendSticker(_ png: Data, in crewID: CrewID) async -> ReplyOutcome {
        // A sticker is cut out of a photograph (`react(.sticker)` says the
        // same): not from someone who may not send one (spec 9.1; found by
        // review, 2026-10-12).
        guard photosAllowed() else { return .notAllowed }
        return await sendSketch(png, text: CrewMessage.pictureMarker + Self.stickerWord, in: crewID, quoting: nil)
    }

    /// **A photograph of yours, brought back to the crew it went to**
    /// (`CrewLookBack`), with its line under it.
    @discardableResult
    func sendPicture(_ data: Data, caption: String, in crewID: CrewID) async -> ReplyOutcome {
        guard photosAllowed() else { return .notAllowed }
        return await sendSketch(data, text: CrewMessage.pictureMarker + caption, in: crewID, quoting: nil)
    }

    /// A doodle with `text` beside it: none for the chat's, the marker for a
    /// strip. The gate, the photo check and the file are the same for both,
    /// and both count against `CrewSendThrottle`.
    private func sendSketch(_ png: Data, text: String, in crewID: CrewID, quoting winID: UUID?) async -> ReplyOutcome {
        guard canReply(), isEnabled(), let crew = crew(crewID), !png.isEmpty else { return .notAllowed }
        if let winID, !(winsByCrew[crewID] ?? []).contains(where: { $0.winID == winID }) { return .notAllowed }
        if let held = paced(.message, in: crew) { return held }
        guard await photoCheck(png) else { return .refusedSketch }
        let id = UUID()
        let url = directory.appending(path: "Photos/\(crewID.rawValue)/message-\(id.uuidString).png")
        do { try write(png, to: url) } catch {
            Self.log.error("doodle for \(crewID.rawValue, privacy: .public) not kept: \(error)")
            return .notAllowed
        }
        let message = CrewMessage(messageID: id, crewID: crewID, senderProfileID: me,
                                  crewDay: CrewDay.string(for: now(), in: crew.timeZone), text: text,
                                  quoteWinID: winID, sketch: url, createdAt: now())
        keep(message)
        await flush()
        return .sent
    }

    private func keep(_ message: CrewMessage) {
        nudgeLive()
        messagesByCrew[message.crewID, default: []].append(message)
        enqueue(.init(crew: message.crewID, type: .message, name: CrewRecords.name(of: message),
                      fields: CrewRecords.fields(message)))
    }

    /// **Reply, on a friend's win: a line in the crew's chat that quotes
    /// it** (the owner, 2026-10-05). It used to be a line on your reaction,
    /// seen only by the win's owner; now the crew sees it, and the owner is
    /// still told ("Sam: so proud", `CrewNotifications`).
    @discardableResult
    ///
    /// **On your own win too** (the owner, 2026-10-13: "there is no way to
    /// reply or add doodle to own win"). It was refused: a reply answered a
    /// friend. A line about your own win is a line in the crew's chat that
    /// quotes it, as any line is.
    func reply(_ line: String, to winID: UUID, in crewID: CrewID) async -> ReplyOutcome {
        guard holdsWinOrStory(winID, in: crewID) else { return .notAllowed }
        return await send(line, in: crewID, quoting: winID)
    }

    /// **Doodle, on a friend's win**: a doodle in the crew's chat that
    /// quotes it. The same gate as a reply, and the photo check both ways.
    @discardableResult
    func doodle(_ png: Data, to winID: UUID, in crewID: CrewID) async -> ReplyOutcome {
        // On your own win too, as a reply is.
        guard holdsWinOrStory(winID, in: crewID) else { return .notAllowed }
        return await sendDoodle(png, in: crewID, quoting: winID)
    }

    // MARK: The chat's own lines

    /// **A win, said in the chat** (the plus row's Win, the owner's
    /// 2026-10-13 "a button in the chat's plus row must do its thing IN the
    /// chat"). Add a Win opens over the chat, and once the win has reached
    /// this crew a line quoting it lands under it: its title, its photo on
    /// the bubble. An ordinary line on the record (`text` and `quoteWinID`),
    /// so no new iCloud field; an older build sees "↪ Gym / Gym".
    @discardableResult
    func sendWinLine(_ winID: UUID, in crewID: CrewID) async -> ReplyOutcome {
        guard let win = winsByCrew[crewID]?.first(where: { $0.winID == winID }),
              win.senderProfileID == me else { return .notAllowed }
        return await send(CrewMessage.winLineText(win.title), in: crewID, quoting: winID)
    }

    /// Whether `message` is a win said in the chat (`sendWinLine`).
    func isWinLine(_ message: CrewMessage) -> Bool {
        guard let quote = message.quoteWinID else { return false }
        return CrewMessage.isWinLine(text: message.text, sender: message.senderProfileID, sketch: message.sketch != nil,
                                     quoting: winsByCrew[message.crewID]?.first(where: { $0.winID == quote }))
    }

    /// **Reply on a line**: a line that quotes one of today's, by its id in
    /// `quoteWinID`. A line gone meanwhile (deleted, or the day ended) sends
    /// the words as a plain line rather than refusing them.
    @discardableResult
    func send(_ text: String, in crewID: CrewID, answering lineID: UUID) async -> ReplyOutcome {
        let there = messages(in: crewID).contains { $0.messageID == lineID }
        return await send(text, in: crewID, quoting: there ? lineID : nil)
    }

    /// Lines of yours deleted a moment ago: off every screen on this phone
    /// while "Line deleted · Undo" stands, and only then taken out of the
    /// crew's chat (`deleteLine`). Undo puts one back (`keepLine`).
    private(set) var deletingLines: Set<UUID> = []

    /// Whether a line of yours may be deleted. **Not a plan's line**: his
    /// rule is that a plan's line never leaves the chat (2026-10-13); the
    /// research's question 5 on it is his to answer.
    func canDelete(_ message: CrewMessage) -> Bool {
        message.senderProfileID == me && message.groupPlan == nil && !message.isToss
    }

    /// The first half of Delete: the line leaves the screen at once.
    func holdBack(line id: UUID) {
        deletingLines.insert(id)
    }

    /// Undo: it comes back as it was.
    func keepLine(_ id: UUID) {
        deletingLines.remove(id)
    }

    /// **Delete on your own line** (M2, the owner's 2026-10-13 hold menu):
    /// out of everyone's chat with nothing left in its place, its doodle or
    /// picture with it. Only the writer's phone may delete a record, which is
    /// why only your own lines offer it. Your reaction to it, if any, goes
    /// at the next prune as an orphan's does.
    func deleteLine(_ id: UUID, in crewID: CrewID) async {
        deletingLines.remove(id)
        guard var list = messagesByCrew[crewID], let i = list.firstIndex(where: { $0.messageID == id }),
              canDelete(list[i]) else { return }
        let message = list.remove(at: i)
        messagesByCrew[crewID] = list
        if let sketch = message.sketch { try? FileManager.default.removeItem(at: sketch) }
        // A line still waiting to go is replaced by its delete (`put`), so a
        // line deleted offline never reaches anyone.
        enqueue(.init(crew: crewID, type: .message, name: CrewRecords.name(of: message), fields: nil))
        nudgeLive()
        await flush()
    }

    /// **A line of yours that has not gone** (M1): still in the outbox, a
    /// while after it was written. A line goes in well under a second on any
    /// signal, so ten seconds is a line that is stuck, not one on its way.
    /// Lines of yours the outbox gave up on: still unsent, not forgotten.
    private var givenUpLines: Set<String> = []

    func isUnsent(_ message: CrewMessage, now: Date) -> Bool {
        _ = outboxRevision
        guard message.senderProfileID == me,
              now.timeIntervalSince(message.createdAt) >= CrewMessage.unsentAfter else { return false }
        if givenUpLines.contains(CrewRecords.name(of: message)) { return true }
        return outbox.entries.contains {
            $0.crew == message.crewID && $0.type == .message && $0.name == CrewRecords.name(of: message) && $0.fields != nil
        }
    }

    /// Try Again on a line that did not go: its write, asked for once more,
    /// whatever wait an earlier failure set. A write the outbox gave up on is
    /// put back.
    func retry(_ message: CrewMessage) async {
        guard message.senderProfileID == me,
              messagesByCrew[message.crewID]?.contains(where: { $0.messageID == message.messageID }) == true else { return }
        givenUpLines.remove(CrewRecords.name(of: message))
        enqueue(.init(crew: message.crewID, type: .message, name: CrewRecords.name(of: message),
                      fields: CrewRecords.fields(message)))
        retryAfter = .distantPast
        nudgeLive()
        await flush()
    }

    /// Whether a friend has said something in the crew's chat today that you
    /// have not opened.
    ///
    /// **And a friend's reaction to one of your lines** (the owner,
    /// 2026-10-06: "the chat notification changes like understand the
    /// connection of all the elements"). A reaction is something new in the
    /// chat as much as a line is, so it lights the same dot, and through it
    /// the crew's row, the Crews button and the app's badge.
    func hasUnreadChat(_ crewID: CrewID) -> Bool {
        let seen = Set(chatSeen[crewID.rawValue] ?? [])
        return chatNews(in: crewID).contains { !seen.contains($0) }
    }

    /// Everything a friend has put in today's chat, as the keys the seen list
    /// keeps: their lines, and their reactions to your lines.
    private func chatNews(in crewID: CrewID) -> [String] {
        let lines = messages(in: crewID)
        let mine = Set(lines.filter { $0.senderProfileID == me }.map(\.messageID))
        // Not a win's own line: the win notified as a win, and the tower
        // shows it (review, 2026-10-14; what 3662613 meant).
        let theirLines = lines.filter { $0.senderProfileID != me && !isWinLine($0) }.map(\.messageID.uuidString)
        let reactions = messageReactions(in: crewID)
            .filter { mine.contains($0.key) }
            .flatMap(\.value)
            .filter { $0.profileID != me }
            .map(Self.seenKey)
        return theirLines + reactions
    }

    private static func seenKey(_ reaction: Reaction) -> String {
        "r:\(reaction.winID.uuidString):\(reaction.profileID.uuidString):\(reaction.emoji)"
    }

    /// The chat is open: everything in it now has been seen. **Kept per
    /// crew, as the lines seen**, not as a time, so a friend whose clock
    /// runs slow still lights the dot. Only today's lines are remembered,
    /// so the list stays a day long.
    func markChatSeen(_ crewID: CrewID) {
        var seen = chatSeen
        seen[crewID.rawValue] = messages(in: crewID).map(\.messageID.uuidString) + chatNews(in: crewID)
        defaults.set(seen, forKey: Self.chatSeenKey)
        if unreadChats.contains(crewID) { unreadChats.remove(crewID) }
        // The badge on the app's icon follows at once, as the dots do.
        updateBadge()
        if announces { CrewNotifications.chatOpened(crewID) }
    }

    /// **The first line you have not seen** (the chat research, 2026-10-15,
    /// item 7): a friend's, newer than what this phone last marked seen. Read
    /// as the chat opens, before it marks them, so the thread can say where
    /// you left off. Kept on this phone; nobody learns you read anything.
    func firstUnseenMessage(in crewID: CrewID) -> UUID? {
        let seen = Set(chatSeen[crewID.rawValue] ?? [])
        guard !seen.isEmpty else { return nil }
        return messages(in: crewID).first {
            $0.senderProfileID != me && !seen.contains($0.messageID.uuidString)
        }?.messageID
    }

    private static let chatSeenKey = "crews.chatSeen"
    private var chatSeen: [String: [String]] {
        defaults.dictionary(forKey: Self.chatSeenKey) as? [String: [String]] ?? [:]
    }

    private func isToday(_ date: Date, in crewID: CrewID) -> Bool {
        guard let zone = crew(crewID)?.timeZone else { return false }
        return CrewDay.string(for: date, in: zone) == CrewDay.string(for: now(), in: zone)
    }

    func myReaction(to winID: UUID, in crewID: CrewID) -> String? {
        reactionsByCrew[crewID]?.first { $0.winID == winID && $0.profileID == me }?.emoji
    }

    /// React to a win, the way a Tapback works: a new emoji replaces yours,
    /// the same one again takes it back. Your own wins take no reactions
    /// from you.
    ///
    /// **The same emoji again never unsends a reply** (the cohesion pass,
    /// 2026-10-05). The record is one per person per win and carries both
    /// the emoji and today's line, so "take the emoji back" used to delete
    /// the record and the words went with it: a double-tap's ❤️ on a win you
    /// had already replied to with ❤️ silently erased what you wrote. Now:
    /// - no line today: the same emoji takes the reaction back, as before;
    /// - a line today: nothing changes. The emoji is the reply's own mark
    ///   (a record without one is not a reaction, `CrewRecords.reaction`),
    ///   so it cannot come off while the words stand, and the words are not
    ///   something a tap on an emoji should be able to take back.
    /// A line from an earlier day is already gone from every screen
    /// (`replies`, `prune`), so it does not hold the record.
    func react(_ emoji: String, to winID: UUID, in crewID: CrewID) async {
        // **Your own win takes your reaction too** (the owner, 2026-10-13,
        // from a tester: "be able to react to their own wins like on the
        // crew tower"). It was refused. Nobody is told of it: a reaction's
        // ping goes to the win's owner, and never from the owner to
        // themselves (`pingIfNew`).
        guard isEnabled(), let crew = crew(crewID), holdsWinOrStory(winID, in: crewID) else { return }
        // Too fast is dropped quietly: the reaction already showing stays.
        guard paced(.reaction, in: crew, item: winID) == nil else { return }
        Analytics.shared.signal(.crewReaction)
        let name = Reaction.name(winID: winID, profileID: me)
        var list = reactionsByCrew[crewID] ?? []
        let previous = list.first { $0.id == name }
        if let previous, previous.emoji == emoji, previous.line != nil, isToday(previous.createdAt, in: crewID) {
            return
        }
        list.removeAll { $0.id == name }
        if previous?.emoji == emoji {
            // A sticker taken back (its star, on the bar) takes its picture.
            if let previous, previous.isStickerOnAWin, let old = previous.sketch {
                try? FileManager.default.removeItem(at: old)
            }
            reactionsByCrew[crewID] = list
            enqueue(.init(crew: crewID, type: .reaction, name: name, fields: nil))
        } else {
            var reaction = Reaction(winID: winID, crewID: crewID, profileID: me, emoji: emoji, createdAt: now())
            // A sticker's picture goes with the sticker (`react(sticker:)`).
            if let previous, previous.isStickerOnAWin, let old = previous.sketch {
                try? FileManager.default.removeItem(at: old)
            } else if let previous, isToday(previous.createdAt, in: crewID) {
                // A new emoji keeps today's reply and doodle under it.
                reaction.line = previous.line
                reaction.sketch = previous.sketch
            }
            list.append(reaction)
            reactionsByCrew[crewID] = list
            enqueue(.init(crew: crewID, type: .reaction, name: name, fields: CrewRecords.fields(reaction)))
        }
        nudgeLive()
        await flush()
    }

    /// **One of your stickers, on a friend's win** (`Reaction
    /// .stickerStandIn`). Made small, checked as a doodle is before it
    /// leaves, and never from someone who may not send photographs: a
    /// sticker is cut out of one. It replaces your reaction, as an emoji
    /// does; an emoji after it replaces it.
    @discardableResult
    func react(sticker png: Data, to winID: UUID, in crewID: CrewID) async -> ReplyOutcome {
        guard isEnabled(), let crew = crew(crewID), holdsWinOrStory(winID, in: crewID),
              photosAllowed() else { return .notAllowed }
        if let held = paced(.reaction, in: crew, item: winID) { return held }
        let side = CGFloat(Reaction.stickerSide)
        guard let small = await Task.detached(priority: .userInitiated, operation: {
            Self.stickerPNG(png, longestEdge: side)
        }).value else { return .notAllowed }
        guard await photoCheck(small) else { return .refusedSketch }
        let url = directory.appending(
            path: "Photos/\(crewID.rawValue)/reaction-\(winID.uuidString)-\(UUID().uuidString.prefix(8)).png")
        do { try write(small, to: url) } catch {
            Self.log.error("sticker for \(crewID.rawValue, privacy: .public) not kept: \(error)")
            return .notAllowed
        }
        Analytics.shared.signal(.crewReaction)
        // Read after the awaits: the list may have moved meanwhile.
        let name = Reaction.name(winID: winID, profileID: me)
        var list = reactionsByCrew[crewID] ?? []
        let previous = list.first { $0.id == name }
        list.removeAll { $0.id == name }
        if let previous, previous.isStickerOnAWin, let old = previous.sketch { try? FileManager.default.removeItem(at: old) }
        let reaction = Reaction(winID: winID, crewID: crewID, profileID: me, emoji: Reaction.stickerStandIn,
                                createdAt: now(), sketch: url)
        list.append(reaction)
        reactionsByCrew[crewID] = list
        enqueue(.init(crew: crewID, type: .reaction, name: name, fields: CrewRecords.fields(reaction)))
        nudgeLive()
        await flush()
        return .sent
    }

    // MARK: Reactions to chat lines

    /// **Today's chat lines' reactions, by line** (the owner, 2026-10-06:
    /// "make it so you can react to chat messages with stickers and emojis").
    ///
    /// Only for lines `messages(in:)` shows, so a reaction is never shown
    /// under a line nobody can see, and never under a win: a win's id is
    /// never a line's. Oldest first, nobody you blocked, and a friend's
    /// sticker only once this phone's photo check has passed it, as a
    /// friend's doodle is (a sticker is lifted out of a photograph).
    func messageReactions(in crewID: CrewID) -> [UUID: [Reaction]] {
        let lines = Set(messages(in: crewID).map(\.messageID))
        guard !lines.isEmpty else { return [:] }
        var out: [UUID: [Reaction]] = [:]
        for reaction in reactionsByCrew[crewID] ?? [] where lines.contains(reaction.winID) {
            guard !blocked.contains(reaction.profileID) else { continue }
            if reaction.isSticker, reaction.profileID != me,
               !(reaction.sketch.map(photoIsShown) ?? false) { continue }
            out[reaction.winID, default: []].append(reaction)
        }
        return out.mapValues { $0.sorted { ($0.createdAt, $0.id) < ($1.createdAt, $1.id) } }
    }

    /// Yours on a line, if you reacted.
    func myReaction(toMessage messageID: UUID, in crewID: CrewID) -> Reaction? {
        reactionsByCrew[crewID]?.first { $0.winID == messageID && $0.profileID == me }
    }

    /// **React to a friend's line**, the way a win's reaction works: a new
    /// pick replaces yours, the same one again takes it back. Your own lines
    /// take none from you, as your own wins do not.
    ///
    /// **A sticker** is made small (`Reaction.stickerSide`), passes the photo
    /// check a doodle passes before it leaves (`photoCheck`), and is never
    /// sent by someone who may not send photographs (13 to 15,
    /// `photosAllowed`): it is cut out of one. The emoji is for everyone,
    /// as a win's reactions are.
    @discardableResult
    func react(_ pick: Reaction.Pick, toMessage messageID: UUID, in crewID: CrewID) async -> ReplyOutcome {
        // **Your own line takes your heart too** (the owner, 2026-10-13: a
        // hold on your own line offers "Reply, Heart, Copy, Delete", and a
        // double tap hearts "yours or a friend's"). It was refused, as your
        // own win once was. Nobody is told: a line's reaction pings no one.
        guard isEnabled(), let crew = crew(crewID),
              messages(in: crewID).contains(where: { $0.messageID == messageID }) else { return .notAllowed }
        let name = Reaction.name(winID: messageID, profileID: me)
        let mark = pick.mark
        guard !mark.isEmpty else { return .notAllowed }
        if let held = paced(.reaction, in: crew, item: messageID) { return held }
        var sketch: URL?
        if reactionsByCrew[crewID]?.first(where: { $0.id == name })?.emoji != mark,
           case .sticker(_, let png) = pick {
            guard photosAllowed() else { return .notAllowed }
            let side = CGFloat(Reaction.stickerSide)
            guard let small = await Task.detached(priority: .userInitiated, operation: {
                Self.stickerPNG(png, longestEdge: side)
            }).value else { return .notAllowed }
            guard await photoCheck(small) else { return .refusedSketch }
            let url = directory.appending(
                path: "Photos/\(crewID.rawValue)/reaction-\(messageID.uuidString)-\(UUID().uuidString.prefix(8)).png")
            do { try write(small, to: url) } catch {
                Self.log.error("sticker for \(crewID.rawValue, privacy: .public) not kept: \(error)")
                return .notAllowed
            }
            sketch = url
        }
        // Read again after the awaits: the list may have moved meanwhile.
        var list = reactionsByCrew[crewID] ?? []
        let previous = list.first { $0.id == name }
        list.removeAll { $0.id == name }
        // Yours, so its picture is yours to clear.
        if let old = previous?.sketch { try? FileManager.default.removeItem(at: old) }
        if previous?.emoji == mark {
            if let sketch { try? FileManager.default.removeItem(at: sketch) }
            reactionsByCrew[crewID] = list
            enqueue(.init(crew: crewID, type: .reaction, name: name, fields: nil))
        } else {
            let reaction = Reaction(winID: messageID, crewID: crewID, profileID: me, emoji: mark,
                                    createdAt: now(), sketch: sketch)
            list.append(reaction)
            reactionsByCrew[crewID] = list
            enqueue(.init(crew: crewID, type: .reaction, name: name, fields: CrewRecords.fields(reaction)))
        }
        nudgeLive()
        await flush()
        return .sent
    }

    /// A sticker as it is sent: no longer than `longestEdge` pixels, clear
    /// where it was clear, as a PNG. Nil for data that is not a picture.
    nonisolated static func stickerPNG(_ png: Data, longestEdge: CGFloat) -> Data? {
        guard let image = UIImage(data: png), image.size.width > 0, image.size.height > 0 else { return nil }
        let pixels = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let k = min(1, longestEdge / max(pixels.width, pixels.height))
        let size = CGSize(width: max(1, (pixels.width * k).rounded()), height: max(1, (pixels.height * k).rounded()))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).pngData { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    // MARK: Syncing

    /// Everything, from the cloud: on foreground, on opening the list, while a
    /// crew is on screen, and when a notification arrives.
    func refresh() async {
        guard isEnabled() else { return }
        // A refresh asked for while one is running is not dropped: the running
        // one goes round again once it finishes. Dropping it lost a crew made
        // between the first one's fetch and its write (2026-10-02, the seed).
        if isRefreshing { refreshAgain = true; return }
        isRefreshing = true
        defer { isRefreshing = false }
        repeat {
            refreshAgain = false
            await refreshOnce()
        } while refreshAgain
        await payHandleReleases()
        await checkHandles()
        if sendsPings {
            writeNoteCache()
            await listenForPings()
            await retryPings()
            await deleteOldPings()
        }
        if announces {
            await CrewNotifications.announce(self)
            await CrewNotifications.announceReactions(self)
            await CrewNotifications.announceMessages(self)
            await shareMyselfIfChanged()
            await CrewSafety.sendPending()
            await checkArrivedPhotos()
        }
    }

    /// **The crew on screen, kept live.** One zone's changes, asked for every
    /// few seconds while it is open: when a friend reacts, the badge moves
    /// on your phone within seconds, not at the next full refresh (the
    /// owner, 2026-10-02: "update immediately... on everyones end"). A
    /// silent push is only a nudge and iOS delays it at will; this does not
    /// wait for one. Nothing changed costs one small request.
    ///
    /// **A change reads that one crew, not every crew** (the 2026-10-08
    /// audit). Any change used to start a full `refresh()`: every zone
    /// listed and synced, the share fetched, pings replanned, every few
    /// seconds while a friend was typing. The zone's records are already
    /// here once `syncOnly` returns, so only that crew is rebuilt from them
    /// (`refreshCrew`). A crew that is gone, or a full refresh asked for
    /// meanwhile, still goes the whole way.
    ///
    /// Returns whether anything changed, which the crew screen paces its
    /// next ask by (`CrewLivePace`). Asks nothing while CloudKit has said to
    /// wait (`syncRetryAfter`).
    @discardableResult
    func refreshLive(_ crewID: CrewID) async -> Bool {
        guard isEnabled(), !isRefreshing, now() >= syncRetryAfter else { return false }
        await flush()
        await retryPings()
        let changed: Bool
        do {
            changed = try await cloud.syncOnly(crewID)
        } catch {
            Self.log.error("live sync of \(crewID.rawValue, privacy: .public) failed: \(error)")
            noteBackoff(error)
            // Ended, or you were removed: the full refresh says so.
            if Self.ckErrors(error).contains(where: { $0.code == .zoneNotFound || $0.code == .userDeletedZone }) {
                await refresh()
            }
            return false
        }
        guard changed else { return false }
        // A full refresh started meanwhile reads this zone too: it goes round
        // once more rather than racing this one.
        if isRefreshing { refreshAgain = true; return true }
        isRefreshing = true
        refreshAgain = false
        let found = await refreshCrew(crewID)
        isRefreshing = false
        if !found || refreshAgain {
            await refresh()
        } else if announces {
            await CrewNotifications.announce(self)
            await CrewNotifications.announceReactions(self)
            await CrewNotifications.announceMessages(self)
            await checkArrivedPhotos()
        }
        return true
    }

    /// Whether this store says what is new as notifications. The phone's own
    /// store does; a test's or a debug friend's never does.
    @ObservationIgnored var announces = false

    /// **A crew was opened: the developer's bans are read again** if they
    /// have not been in the last few minutes (2026-10-08). They are read
    /// once a day otherwise; a ban that changed anything refreshes, so a
    /// banned account's wins leave the crew you are looking at.
    func crewOpened(_ crewID: CrewID) async {
        guard isEnabled(), crew(crewID) != nil else { return }
        if await cloud.refreshModeration(force: true) { await refresh() }
    }

    /// **Bumped when you post, say or react** (2026-10-08): the crew screen
    /// goes back to asking every 3 seconds (`CrewLivePace`), since an
    /// answer is likeliest just after you did something.
    private(set) var liveNudge = 0

    /// **A push arrived** (`StrataAppDelegate`). The crew on screen reads
    /// itself at once (its live loop watches `livePush`), which is one small
    /// request; every crew is read too, but not more than twice a minute
    /// while one is open, since a busy chat pushes for every line.
    func pushed() async {
        guard liveCrew != nil else { return await refresh() }
        livePush += 1
        guard now().timeIntervalSince(lastPushRefresh) > 30 else { return }
        lastPushRefresh = now()
        await refresh()
    }

    /// Bumped by a push while a crew is on screen.
    private(set) var livePush = 0
    /// The crew on screen, set by its live loop.
    @ObservationIgnored var liveCrew: CrewID?
    @ObservationIgnored private var lastPushRefresh = Date.distantPast
    private func nudgeLive() { liveNudge &+= 1 }

    @ObservationIgnored private var refreshAgain = false
    /// Crews whose name or picture is being saved right now.
    @ObservationIgnored private var editing: [CrewID: Crew] = [:]
    /// **Not before: CloudKit asked this phone to wait** (2026-10-08). Set
    /// from `retryAfterSeconds` when a sync or a write is refused as rate
    /// limited, zone busy or service unavailable; until then neither the
    /// live sync nor a full refresh asks anything.
    @ObservationIgnored private var syncRetryAfter: Date = .distantPast

    private func noteBackoff(_ error: Error) {
        guard let wait = Self.serverBackoff(error) else { return }
        syncRetryAfter = max(syncRetryAfter, now().addingTimeInterval(wait))
    }

    /// One crew's wins, reactions and chat as fetched, with this phone's
    /// writes still on their way laid over them. Nil wins: the fetch failed,
    /// which is not a day with no wins.
    private struct Held {
        var wins: [SharedWin]?
        var reactions: [Reaction]
        var messages: [CrewMessage]
        var stories: [CrewStory]
    }

    /// **Your crews the moment the app opens**, from what this phone last
    /// read (`CrewCloud.cachedCrews`), before the trip to iCloud: an update
    /// opens cold, and the list stood empty, saying to start a crew, until
    /// that trip came back. Only once an account has been seen here, so a
    /// changed account (whose cache `reset` cleared) never shows the last
    /// one's crews.
    private func seedFromCache() async {
        guard crews.isEmpty, let known = defaults.string(forKey: Self.accountKey) else { return }
        // **Only the account that read them** (the review, 2026-10-16): an
        // iCloud signed out, or another one signed in, while the app was
        // closed never sees the last one's crews. Not sure yet is allowed:
        // that is the update this is for.
        switch await cloud.account() {
        case .signedOut: return
        case .signedIn(let who) where who != known: return
        default: break
        }
        let cached = cloud.cachedCrews()
        guard !cached.isEmpty else { return }
        var wins: [CrewID: [SharedWin]] = [:], reactions: [CrewID: [Reaction]] = [:]
        var messages: [CrewID: [CrewMessage]] = [:], stories: [CrewID: [CrewStory]] = [:]
        for crew in cached {
            let held = await held(in: crew)
            wins[crew.id] = held.wins ?? []
            reactions[crew.id] = held.reactions
            messages[crew.id] = held.messages
            stories[crew.id] = held.stories
        }
        // A refresh that finished meanwhile knows better.
        guard crews.isEmpty else { return }
        crews = Self.personalNamedFromShared(cached.map(withEdits), me: me)
        winsByCrew = wins
        reactionsByCrew = reactions
        messagesByCrew = messages
        storiesByCrew = stories
    }

    /// **A conversation the other person left is ended** (the review,
    /// 2026-10-16): a thread with only you in it and no invitation out was
    /// a row reading "New Crew" with your own face. Made a minute ago, or
    /// with its invitation still waiting, it is left alone.
    private func endThreadsLeftAlone() async {
        let waiting = Set(personalStarted.values.map(\.crew))
        for crew in crews where crew.isPersonal && crew.members.count == 1 && crew.isOwner(me)
            && !waiting.contains(crew.id.rawValue) && now().timeIntervalSince(crew.createdAt) > 600 {
            try? await end(crew.id)
        }
    }

    /// A read of the crews has failed this launch: the list stops waiting
    /// and says what it can (signed out, or empty) rather than spin.
    var crewsLoadFailed = false

    /// Whether this phone holds the key to any crew: the list waits quietly
    /// for the first read rather than offering to start one.
    var holdsCrewKeys: Bool { !(cloud.heldCrews() ?? []).isEmpty }

    private func held(in crew: Crew) async -> Held {
        let people = Set(crew.members.map(\.profileID))
        var wins: [SharedWin]?
        do {
            var fetched = try await cloud.fetchWins(in: crew.id)
            // A write of ours still on its way wins over what the
            // cloud has: it is newer.
            for entry in outbox.entries where entry.crew == crew.id && entry.type == .sharedWin {
                fetched.removeAll { $0.winID.uuidString == entry.name }
                if let fields = entry.fields, let mine = CrewRecords.sharedWin(fields, crew: crew.id) {
                    fetched.append(mine)
                }
            }
            // Only people in the crew: someone removed is gone with
            // their wins, whoever's phone had not yet deleted them
            // (the 2026-10-03 audit: they came back as "A friend").
            // And out of every tag: someone removed from a crew is
            // dropped from its tags (shared wins, spec 1).
            wins = fetched.filter { people.contains($0.senderProfileID) }
                .map { win -> SharedWin in
                    var win = win
                    win.withPeople.removeAll { !people.contains($0) }
                    return win
                }
                .sorted { ($0.createdAt, $0.winID.uuidString) < ($1.createdAt, $1.winID.uuidString) }
        } catch {
            Self.log.error("fetching wins in \(crew.id.rawValue, privacy: .public) failed: \(error)")
        }
        var reactions = (try? await cloud.fetchReactions(in: crew.id)) ?? reactionsByCrew[crew.id] ?? []
        for entry in outbox.entries where entry.crew == crew.id && entry.type == .reaction {
            reactions.removeAll { $0.id == entry.name }
            if let fields = entry.fields, let mine = CrewRecords.reaction(fields, crew: crew.id) { reactions.append(mine) }
        }
        // The day chat, the same way: a failed fetch keeps what was
        // held, a line of ours still on its way wins, and only members'.
        var messages = (try? await cloud.fetchMessages(in: crew.id)) ?? messagesByCrew[crew.id] ?? []
        for entry in outbox.entries where entry.crew == crew.id && entry.type == .message {
            messages.removeAll { $0.messageID.uuidString == entry.name }
            if let fields = entry.fields, let mine = CrewRecords.message(fields, crew: crew.id) {
                messages.append(mine)
            }
        }
        // Stories, the same way again: a failed fetch keeps what was held.
        var stories = (try? await cloud.fetchStories(in: crew.id)) ?? storiesByCrew[crew.id] ?? []
        for entry in outbox.entries where entry.crew == crew.id && entry.type == .story {
            stories.removeAll { $0.id.uuidString == entry.name }
            if let fields = entry.fields, let mine = CrewRecords.story(fields, crew: crew.id) { stories.append(mine) }
        }
        stories = stories.filter { people.contains($0.sender) }
            .map { story -> CrewStory in
                var story = story
                story.win.withPeople.removeAll { !people.contains($0) }
                return story
            }
            .sorted { ($0.win.createdAt, $0.id.uuidString) < ($1.win.createdAt, $1.id.uuidString) }
        return Held(wins: wins,
                    reactions: reactions.filter { people.contains($0.profileID) }.sorted { $0.id < $1.id },
                    messages: messages.filter { people.contains($0.senderProfileID) }
                        .sorted { ($0.createdAt, $0.messageID.uuidString) < ($1.createdAt, $1.messageID.uuidString) },
                    stories: stories)
    }

    /// **In a fixed order**, members, wins and reactions alike. A fetch
    /// hands them back in dictionary order, so an unchanged crew compared
    /// as changed on every refresh and the whole crew screen redrew: a
    /// 96ms hitch every 15 seconds with nobody posting (measured with
    /// `-strataPerfProbe`, 2026-10-02).
    private static func ordered(_ crew: Crew) -> Crew {
        var crew = crew
        crew.members.sort { ($0.joinedAt, $0.profileID.uuidString) < ($1.joinedAt, $1.profileID.uuidString) }
        return crew
    }

    /// A name or picture still being saved wins over what was fetched.
    private func withEdits(_ crew: Crew) -> Crew {
        guard let edit = editing[crew.id] else { return crew }
        var crew = crew
        crew.name = edit.name
        crew.photo = edit.photo
        return crew
    }

    /// **One crew, rebuilt from the records its zone sync just brought**
    /// (2026-10-08). False when the crew is not there to rebuild (ended,
    /// removed, or not yet known here): the caller then does a full refresh.
    private func refreshCrew(_ crewID: CrewID) async -> Bool {
        guard crews.contains(where: { $0.id == crewID }),
              let fetched = try? await cloud.fetchCrew(crewID) else { return false }
        var crew = withEdits(Self.ordered(fetched))
        if crew.isPersonal, let named = Self.personalNamedFromShared([crew] + groupCrews, me: me).first { crew = named }
        let held = await held(in: crew)
        // Read again after the awaits: the list may have moved meanwhile.
        guard let i = crews.firstIndex(where: { $0.id == crewID }) else { return false }
        if crews[i] != crew { crews[i] = crew }
        let wins = held.wins ?? winsByCrew[crewID] ?? []
        if winsByCrew[crewID] != wins { winsByCrew[crewID] = wins }
        if reactionsByCrew[crewID] != held.reactions { reactionsByCrew[crewID] = held.reactions }
        if messagesByCrew[crewID] != held.messages { messagesByCrew[crewID] = held.messages }
        if storiesByCrew[crewID] != held.stories { storiesByCrew[crewID] = held.stories }
        keepStoryReactions()
        if let counted = held.wins { recordHistory([crewID: counted], for: [crew]) }
        recomputeUnread()
        prune()
        return true
    }

    private func refreshOnce() async {
        await seedFromCache()
        // CloudKit said to wait: nothing is asked until it has passed.
        guard now() >= syncRetryAfter else { return }
        await cloud.prepare()
        // Who the crews belong to, kept before any change can be announced.
        if defaults.string(forKey: Self.accountKey) == nil, case .signedIn(let who) = await cloud.account() {
            defaults.set(who, forKey: Self.accountKey)
        }
        await flush()
        do {
            let fetched = try await cloud.fetchCrews().map(Self.ordered)
            var wins: [CrewID: [SharedWin]] = [:]
            var counted: [CrewID: [SharedWin]] = [:]
            var reactions: [CrewID: [Reaction]] = [:]
            var messages: [CrewID: [CrewMessage]] = [:]
            var stories: [CrewID: [CrewStory]] = [:]
            for crew in fetched {
                let held = await held(in: crew)
                stories[crew.id] = held.stories
                wins[crew.id] = held.wins ?? winsByCrew[crew.id] ?? []
                counted[crew.id] = held.wins
                reactions[crew.id] = held.reactions
                messages[crew.id] = held.messages
            }
            // Writes for crews that are gone (ended, or you were removed) can
            // never be sent: drop them rather than retry them for ever.
            // A crew made in the last minute may not be in a fetch that began
            // before it existed: never forget one of those.
            let fresh = Set(crews.filter { now().timeIntervalSince($0.createdAt) < 60 }.map(\.id))
            // **A crew that could not be read is not a crew that is gone**
            // (2026-10-10, the owner: crews "disappear" with a new build).
            // The cloud returns the crews it could build this time. One it
            // still holds the key to but could not read (no signal on a
            // cold start, a cache that would not open) was missing from
            // that list, and this forgot it: its photos, its place in the
            // list and the streak this phone had counted for it, which is
            // kept nowhere else. Now only a crew the cloud has let go of is
            // forgotten, and one it could not read stays as it was.
            let fetchedIDs = Set(fetched.map(\.id))
            let unread = (cloud.heldCrews() ?? []).subtracting(fetchedIDs)
            let known = fetchedIDs.union(fresh).union(unread)
            for gone in Set(outbox.entries.map(\.crew)).subtracting(known) { outbox.drop(crew: gone) }
            for gone in Set(crews.map(\.id)).subtracting(known) { forget(gone) }
            for crew in crews where unread.contains(crew.id) {
                wins[crew.id] = winsByCrew[crew.id] ?? []
                reactions[crew.id] = reactionsByCrew[crew.id]
                messages[crew.id] = messagesByCrew[crew.id]
                stories[crew.id] = storiesByCrew[crew.id]
            }
            let merged = Self.personalNamedFromShared((fetched.map(withEdits) + crews.filter { unread.contains($0.id) })
                .sorted { $0.createdAt < $1.createdAt }, me: me)
            if crews != merged { crews = merged }
            crewsLoadFailed = false
            await endThreadsLeftAlone()
            await repairMissingMembership(in: fetched)
            if winsByCrew != wins { winsByCrew = wins }
            if reactionsByCrew != reactions { reactionsByCrew = reactions }
            if messagesByCrew != messages { messagesByCrew = messages }
            if storiesByCrew != stories {
                let hadStory = storiesByCrew.values.contains { $0.contains { $0.sender != me } }
                storiesByCrew = stories
                // A friend's story tonight moves the evening's cue to 8pm
                // (`EveningCheckIn.storyEvening`): decided again when the
                // first one arrives.
                if announces, !hadStory, stories.values.contains(where: { $0.contains { $0.sender != me } }) {
                    Task { @MainActor in await EveningCheckIn.update(context: SharedModelContainer.shared.mainContext) }
                }
            }
            keepStoryReactions()
            if !hasFetchedCrews { hasFetchedCrews = true }
            recordHistory(counted, for: fetched)
            for gone in CrewChoice.load(defaults).subtracting(known) { CrewChoice.forget(gone, defaults) }
            recomputeUnread()
            prune()
            await settlePersonals()
        } catch {
            Self.log.error("fetching crews failed: \(error)")
            noteBackoff(error)
            crewsLoadFailed = true
            // **iCloud not ready yet is not signed out** (the 2026-10-16
            // update report): right after an install it answers "could not
            // determine" for a moment. Asked again shortly, a few times,
            // rather than at the next return to the app.
            if case CrewError.notSignedIn = error, transientRetries < 3, case .unknown = await cloud.account() {
                transientRetries += 1
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(4))
                    await self?.refresh()
                }
            }
        }
    }

    /// Retries after iCloud said it could not tell yet, this launch.
    @ObservationIgnored private var transientRetries = 0

    /// Crews this session has tried to write your Member record into.
    @ObservationIgnored private var memberRepairs: Set<CrewID> = []

    /// **A crew you are in with no Member record of yours** (the crews audit,
    /// 2026-10-08). Joining accepts the share first and writes the Member
    /// record second; when the second step failed (the starter's iCloud full,
    /// the connection gone) you were in the crew with no record, and since
    /// only members' wins are kept, everything you sent vanished for everyone.
    /// Written here, once a crew a session, so it can never loop.
    private func repairMissingMembership(in fetched: [Crew]) async {
        for crew in fetched where !crew.isOwner(me) && crew.member(me) == nil && !memberRepairs.contains(crew.id) {
            memberRepairs.insert(crew.id)
            let member = CrewMember(profileID: me, firstName: myFirstName(), head: nil, joinedAt: now(), handle: myHandle())
            do {
                try await cloud.save(CrewRecords.fields(member), type: .member,
                                     name: CrewRecords.name(of: member), in: crew.id)
                refreshAgain = true
            } catch {
                Self.log.error("membership repair failed: \(error)")
            }
        }
    }

    /// Sends whatever is waiting. A failure keeps the write for next time and
    /// is logged, never swallowed.
    func flush() async {
        guard isEnabled(), !outbox.isEmpty, now() >= retryAfter else { return }
        // **One flush at a time, in order.** Two at once could reach the
        // server in either order, so an older photo could land after a newer
        // edit (the 2026-10-02 audit). A flush asked for mid-flush runs again.
        if flushing { flushAgain = true; return }
        flushing = true
        defer { flushing = false }
        repeat {
            flushAgain = false
            for entry in outbox.entries {
                // A crew whose iCloud is full: its saves wait, uncounted.
                // Deletes still go, since they are what makes room.
                if entry.fields != nil, let until = quotaWait[entry.crew], now() < until { continue }
                do {
                    if let fields = entry.fields {
                        try await cloud.save(fields, type: entry.type, name: entry.name, in: entry.crew)
                        if fullCrews.contains(entry.crew) {
                            fullCrews.remove(entry.crew)
                            quotaWait[entry.crew] = nil
                        }
                        await pingIfNew(entry.type, fields, in: entry.crew)
                    } else {
                        try await cloud.delete(type: entry.type, name: entry.name, in: entry.crew)
                    }
                    outbox.removeIfUnchanged(entry)
                } catch {
                    Self.log.error("\(entry.type.rawValue, privacy: .public) to \(entry.crew.rawValue, privacy: .public) not sent: \(error)")
                    // **A full iCloud is a wait, not a failure** (the
                    // 2026-10-08 audit). The live sync flushes every few
                    // seconds, so twenty counted tries took about a minute
                    // and the post was dropped without a word. It waits now,
                    // uncounted, and the crew screen says why
                    // (`fullCrews`). Other crews, on other people's iCloud,
                    // carry on.
                    if Self.isQuotaExceeded(error) {
                        quotaWait[entry.crew] = now().addingTimeInterval(Self.quotaPause(error))
                        if !fullCrews.contains(entry.crew) { fullCrews.insert(entry.crew) }
                        continue
                    }
                    // **No signal is not a failure** (the 2026-10-03 audit). A
                    // dropped connection, a busy server or a rate limit says
                    // nothing about the write, and counting them gave up on
                    // a win posted offline after about a minute of the live
                    // sync's retries. Those wait, for as long as CloudKit
                    // asks, and the rest of the queue waits with them.
                    if let wait = Self.transientWait(error) {
                        retryAfter = now().addingTimeInterval(wait)
                        noteBackoff(error)
                        break
                    }
                    outbox.noteFailure(entry)
                }
            }
            for gone in outbox.dropHopeless() {
                Self.log.error("gave up on \(gone.type.rawValue, privacy: .public) to \(gone.crew.rawValue, privacy: .public)")
                // A line of yours that will not go keeps saying so, and
                // Try Again puts it back (review, 2026-10-14).
                if gone.type == .message, gone.fields != nil { givenUpLines.insert(gone.name) }
            }
            persistOutbox()
        } while flushAgain
    }

    @ObservationIgnored private var flushing = false
    @ObservationIgnored private var flushAgain = false
    /// Not before: set by a transient failure.
    @ObservationIgnored private var retryAfter: Date = .distantPast

    /// **Crews whose starter's iCloud is full** (2026-10-08): a save came
    /// back `quotaExceeded`. New wins wait in the outbox until a save goes
    /// through again; the crew screen says so in one line (`fullWords`).
    private(set) var fullCrews: Set<CrewID> = []
    static let fullWords = "Crews are full for a moment, so new wins wait to send."
    /// When a full crew's saves are next tried.
    @ObservationIgnored private var quotaWait: [CrewID: Date] = [:]

    /// A CloudKit error and, for a partial failure, each item's own.
    nonisolated static func ckErrors(_ error: Error) -> [CKError] {
        guard let ck = error as? CKError else { return [] }
        return [ck] + (ck.partialErrorsByItemID?.values.compactMap { $0 as? CKError } ?? [])
    }

    nonisolated static func isQuotaExceeded(_ error: Error) -> Bool {
        ckErrors(error).contains { $0.code == .quotaExceeded }
    }

    /// Starting a crew on a full iCloud: the crew lives in the starter's own
    /// storage, so it is their space that has run out, never the app's.
    static let fullToStartWords = CrewErrorWords.yourICloudFull

    /// How long a full crew's saves wait: what CloudKit says, at least half
    /// a minute, since room comes back only when someone deletes something.
    nonisolated static func quotaPause(_ error: Error) -> TimeInterval {
        max(ckErrors(error).compactMap(\.retryAfterSeconds).max() ?? 60, 30)
    }

    /// **How long CloudKit asked everyone to wait** (2026-10-08): rate
    /// limited, zone busy or service unavailable, from `retryAfterSeconds`.
    /// Nil for anything else. What `syncRetryAfter` is set from.
    nonisolated static func serverBackoff(_ error: Error) -> TimeInterval? {
        let busy = ckErrors(error).filter {
            $0.code == .requestRateLimited || $0.code == .zoneBusy || $0.code == .serviceUnavailable
        }
        guard !busy.isEmpty else { return nil }
        return max(busy.compactMap(\.retryAfterSeconds).max() ?? 5, 1)
    }

    /// How long to wait before trying again, when `error` says nothing about
    /// the write itself (no network, a busy or limited server, iCloud signed
    /// out for now). Nil for a real failure, which counts.
    nonisolated static func transientWait(_ error: Error) -> TimeInterval? {
        if error is URLError { return 5 }
        guard let ck = error as? CKError else { return nil }
        switch ck.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable,
             .requestRateLimited, .zoneBusy, .notAuthenticated, .accountTemporarilyUnavailable:
            return max(ck.retryAfterSeconds ?? 5, 1)
        default:
            return nil
        }
    }

    /// A crew keeps two weeks (`CrewDay.keptDays`), not an archive: anything
    /// older goes, and so do the oldest photos past `photoCap`. Whoever opens
    /// the crew next does the deleting.
    func prune() {
        sweepStories()
        for crew in crews {
            let today = CrewDay.string(for: now(), in: crew.timeZone)
            guard var cutoff = CrewDay.oldestKept(today: today, in: crew.timeZone) else { continue }
            // **At most `photoCap` photos in the window.** Fifteen days of a
            // crew posting far more than a photo a day each would fill the
            // starter's iCloud, and then every post fails. Past the cap the
            // window starts later: whole days go, oldest first, so a day is
            // never shown with half its photos missing.
            let photoDays = (winsByCrew[crew.id] ?? []).filter { $0.photo != nil && $0.crewDay >= cutoff }
                .map(\.crewDay).sorted(by: >)
            if photoDays.count > Self.photoCap {
                let last = photoDays[Self.photoCap - 1]
                // The day the cap falls in goes too, unless it ends there.
                cutoff = last != photoDays[Self.photoCap] ? last
                    : (CrewDay.day(last, offsetBy: 1, in: crew.timeZone) ?? last)
                cutoff = min(cutoff, today)
            }
            // Reactions go with their wins, and a reaction whose win has gone
            // (withdrawn, deleted) goes too, whoever made it.
            //
            // **And a chat line's go with the line** (2026-10-06): a reaction
            // to today's line is live, and one to a line whose day has ended
            // goes with it, its sticker and all. Without this every line's
            // reactions were orphans of no win, deleted the moment they came.
            // **A conversation's lines keep two weeks** (the review,
            // 2026-10-16: this cleared a message thread at midnight like a
            // crew's chat, and deleted your lines from the cloud with it).
            let lineCutoff = crew.isPersonal ? (CrewDay.oldestKept(today: today, in: crew.timeZone) ?? today) : today
            let live = Set((winsByCrew[crew.id] ?? []).filter { $0.crewDay >= cutoff }.map(\.winID))
                .union((messagesByCrew[crew.id] ?? []).filter { $0.crewDay >= lineCutoff }.map(\.messageID))
                // A story's reactions live while it does; the poster's phone
                // has kept its own copy by then (`keepStoryReactions`).
                .union((storiesByCrew[crew.id] ?? []).filter { now() < $0.endsAt }.map(\.id))
            let orphans = (reactionsByCrew[crew.id] ?? []).filter { !live.contains($0.winID) }
            if !orphans.isEmpty, winsByCrew[crew.id] != nil {
                reactionsByCrew[crew.id]?.removeAll { !live.contains($0.winID) }
                for reaction in orphans where reaction.profileID == me {
                    if let sticker = reaction.sketch { try? FileManager.default.removeItem(at: sticker) }
                    enqueue(.init(crew: crew.id, type: .reaction, name: reaction.id, fields: nil))
                }
            }
            // **Old replies and doodles clear when the day ends.** Nothing
            // writes them on a reaction any more (they are chat messages
            // now), but a record from an older build may still carry one.
            // Only the writer's phone may change a reaction record, so each
            // phone clears its own; no screen shows them.
            for (index, reaction) in (reactionsByCrew[crew.id] ?? []).enumerated()
            // **Not a sticker on a win** (found by review, 2026-10-13): it
            // is a star with its picture in `sketch`, and this took the
            // picture off it at the crew's midnight, leaving a star nobody
            // chose on a win that stays two weeks.
            where reaction.profileID == me && !reaction.isSticker && !reaction.isStickerOnAWin
                && (reaction.line != nil || reaction.sketch != nil)
                && CrewDay.string(for: reaction.createdAt, in: crew.timeZone) < today {
                var cleared = reaction
                cleared.line = nil
                if let sketch = reaction.sketch { try? FileManager.default.removeItem(at: sketch) }
                cleared.sketch = nil
                reactionsByCrew[crew.id]?[index] = cleared
                enqueue(.init(crew: crew.id, type: .reaction, name: reaction.id, fields: CrewRecords.fields(cleared)))
            }
            // **The chat clears at the crew's midnight.** Each phone deletes
            // its own lines (only a record's writer may), doodle and all;
            // anyone else's leave this phone's list, and no screen shows
            // another day's line before then (`messages(in:)`).
            let ended = (messagesByCrew[crew.id] ?? []).filter { $0.crewDay < lineCutoff }
            if !ended.isEmpty {
                messagesByCrew[crew.id]?.removeAll { $0.crewDay < lineCutoff }
                for message in ended where message.senderProfileID == me {
                    if let sketch = message.sketch { try? FileManager.default.removeItem(at: sketch) }
                    enqueue(.init(crew: crew.id, type: .message, name: CrewRecords.name(of: message), fields: nil))
                }
            }
            let old = (winsByCrew[crew.id] ?? []).filter { $0.crewDay < cutoff }
            guard !old.isEmpty else { continue }
            winsByCrew[crew.id]?.removeAll { $0.crewDay < cutoff }
            for win in old {
                if let photo = win.photo { try? FileManager.default.removeItem(at: photo) }
                // Each phone deletes its own (only a record's writer may):
                // a friend's old win queued here was refused by the server
                // and queued again on every refresh (the 2026-10-10 review).
                guard win.senderProfileID == me else { continue }
                enqueue(.init(crew: crew.id, type: .sharedWin, name: win.winID.uuidString, fields: nil))
            }
        }
    }

    /// The most photos a crew holds at once (about 90 MB).
    static let photoCap = 300

    // MARK: Unread

    func markSeen(_ crewID: CrewID) {
        var seen = lastSeen
        seen[crewID.rawValue] = now().timeIntervalSince1970
        defaults.set(seen, forKey: Self.lastSeenKey)
        unread.remove(crewID)
        // Read on screen: its notifications leave the lock screen and the
        // badge counts one fewer crew (the 2026-10-03 audit).
        if announces {
            CrewNotifications.removeDelivered(for: crewID)
            updateBadge()
        }
    }

    /// The app's badge: how many crews have something new. Only the phone's
    /// own store sets it; a test's never does.
    private func updateBadge() {
        guard announces else { return }
        // Crews with anything new: a win or a reaction to yours, or a line or
        // a reaction in the chat. The same set the Crews button's dot reads.
        let count = unread.union(unreadChats).count
        Task { try? await UNUserNotificationCenter.current().setBadgeCount(count) }
    }

    private static let lastSeenKey = "crews.lastSeen"
    private var lastSeen: [String: Double] {
        defaults.dictionary(forKey: Self.lastSeenKey) as? [String: Double] ?? [:]
    }

    private func recomputeUnread() {
        let seen = lastSeen
        let fresh = Set(crews.compactMap { crew -> CrewID? in
            let since = Date(timeIntervalSince1970: seen[crew.id.rawValue] ?? 0)
            let mine = Set((winsByCrew[crew.id] ?? []).filter { $0.senderProfileID == me }.map(\.winID))
            // Only what the tower shows: today's wins. An edit to a past day's
            // win is not something new on screen.
            let day = CrewDay.string(for: now(), in: crew.timeZone)
            let newWin = (winsByCrew[crew.id] ?? []).contains {
                $0.crewDay == day && $0.senderProfileID != me && !blocked.contains($0.senderProfileID) && $0.updatedAt > since
            }
            let newReaction = (reactionsByCrew[crew.id] ?? []).contains {
                mine.contains($0.winID) && $0.profileID != me && !blocked.contains($0.profileID) && $0.createdAt > since
            }
            return newWin || newReaction ? crew.id : nil
        })
        if unread != fresh { unread = fresh }
        let chats = Set(crews.map(\.id).filter { hasUnreadChat($0) })
        if unreadChats != chats { unreadChats = chats }
        updateBadge()
    }

    // MARK: Alerts

    /// Shared with the notification code through the app group, so the
    /// choice holds even where the app is not running.
    static let groupDefaults = UserDefaults(suiteName: "group.JaydenBetts.Strata")
    private static let mutedKey = "crews.mutedUntil"
    private static let quietReactionsKey = "crews.reactionAlertsOff"

    /// How long a crew is quiet for, as Messages and WhatsApp offer it.
    enum Mute: CaseIterable, Identifiable {
        case hour, eightHours, week, always
        var id: Self { self }
        var words: String {
            switch self {
            case .hour: "For 1 Hour"
            case .eightHours: "For 8 Hours"
            case .week: "For 1 Week"
            case .always: "Until I Turn It Back On"
            }
        }
        var interval: TimeInterval? {
            switch self {
            case .hour: 3600
            case .eightHours: 8 * 3600
            case .week: 7 * 86_400
            case .always: nil
            }
        }
    }

    /// When a crew's alerts come back. Nil: they are on. `distantFuture`:
    /// muted until you turn them back on.
    func mutedUntil(_ crewID: CrewID) -> Date? {
        _ = outboxRevision
        let stamps = Self.groupDefaults?.dictionary(forKey: Self.mutedKey) as? [String: Double] ?? [:]
        guard let stamp = stamps[crewID.rawValue] else { return nil }
        let until = Date(timeIntervalSince1970: stamp)
        return until > now() ? until : nil
    }

    func isMuted(_ crewID: CrewID) -> Bool { mutedUntil(crewID) != nil }

    // **Heads per crew: removed 2026-10-14.** The switch that hid a crew's
    // heads on this phone (2026-10-03) went when the head became who you
    // are (the owner: "the heads dont need to be an option in the settings
    // for crew"). Its key, `crews.headsHidden`, is cleared once by
    // `RetiredHeadSwitches`.

    func mute(_ crewID: CrewID, _ length: Mute?) {
        var stamps = Self.groupDefaults?.dictionary(forKey: Self.mutedKey) as? [String: Double] ?? [:]
        if let length {
            stamps[crewID.rawValue] = length.interval.map { now().addingTimeInterval($0).timeIntervalSince1970 }
                ?? Date.distantFuture.timeIntervalSince1970
        } else {
            stamps[crewID.rawValue] = nil
        }
        Self.groupDefaults?.set(stamps, forKey: Self.mutedKey)
        note(.muted, crewID.rawValue, stamps[crewID.rawValue] ?? 0)
        outboxRevision += 1
        replan()
    }

    /// The old name, still what the list's swipe and Crew Info's switch say.
    func hidesAlerts(_ crewID: CrewID) -> Bool { isMuted(crewID) }
    func setHidesAlerts(_ hide: Bool, for crewID: CrewID) { mute(crewID, hide ? .always : nil) }

    /// Whether you hear when someone in this crew reacts to your win.
    func reactionAlerts(_ crewID: CrewID) -> Bool {
        _ = outboxRevision
        return !(Self.groupDefaults?.stringArray(forKey: Self.quietReactionsKey) ?? []).contains(crewID.rawValue)
    }

    func setReactionAlerts(_ on: Bool, for crewID: CrewID) {
        var off = Set(Self.groupDefaults?.stringArray(forKey: Self.quietReactionsKey) ?? [])
        if on { off.remove(crewID.rawValue) } else { off.insert(crewID.rawValue) }
        Self.groupDefaults?.set(off.sorted(), forKey: Self.quietReactionsKey)
        note(.reactionsOff, crewID.rawValue, on ? 0 : 1)
        outboxRevision += 1
        replan()
    }

    // MARK: Pings

    /// Whether this store leaves pings and listens for them
    /// (`CrewPingRecord`). The phone's own store does; a test turns it on to
    /// watch it, and a debug friend never does.
    @ObservationIgnored var sendsPings = false
    private static let pingedKey = "crews.pings.done"
    private static let sentPingsKey = "crews.pings.sent"
    private static let planKey = "crews.pings.plan"

    /// What this phone wants iCloud to tell it about, now.
    func pingPlan() -> CrewPingPlan {
        let heard = crews.map(\.id).filter { !isMuted($0) }
        let tag = CrewPingRecord.tag
        return CrewPingPlan(winCrews: heard.map { tag($0.rawValue) },
                            reactionCrews: heard.filter { reactionAlerts($0) }.map { tag($0.rawValue) },
                            me: tag(me.uuidString),
                            excluding: blocked.map { tag($0.uuidString) })
    }

    /// Whether iCloud is sending this phone pings: then they are what
    /// notifies, and the app's own notifications would only repeat them.
    var pingsLive: Bool { sendsPings && defaults.data(forKey: Self.planKey) != nil }

    /// Whether iCloud is sending this phone the chat's pings too: the plan
    /// it was last told is this build's, which asks for them
    /// (`CrewPingPlan.crewID`). Then the app's own chat alert stands down
    /// (`CrewNotifications.announceMessages`).
    var chatPingsLive: Bool {
        sendsPings && defaults.data(forKey: Self.planKey)
            .flatMap { try? JSONDecoder().decode(CrewPingPlan.self, from: $0) } != nil
    }

    /// Tells iCloud the plan when it has changed since it last heard it. A
    /// timed mute ending is a change too, so every refresh asks.
    func listenForPings() async {
        guard sendsPings, !crews.isEmpty || defaults.data(forKey: Self.planKey) != nil else { return }
        let plan = pingPlan()
        let told = defaults.data(forKey: Self.planKey).flatMap { try? JSONDecoder().decode(CrewPingPlan.self, from: $0) }
        guard plan != told else { return }
        // Not again for a while after iCloud said no: every refresh comes
        // through here, and an open crew refreshes every few seconds.
        if let failed = lastListenFailure, now().timeIntervalSince(failed) < 600 { return }
        do {
            try await cloud.listen(for: plan)
            defaults.set(try? JSONEncoder().encode(plan), forKey: Self.planKey)
            lastListenFailure = nil
            AlertCheck.note(.listen, ok: true, "\(plan.winCrews.count) crews")
        } catch {
            // **Then this phone is not subscribed, and says so** (found by
            // review, 2026-10-10). The old plan used to stay written down:
            // `listen` takes the subscriptions away before it saves the new
            // ones, so after a failure there were none, the app still
            // believed pings were arriving, and its own notifications stayed
            // off. With the plan forgotten they carry on, and a later
            // refresh asks again.
            defaults.removeObject(forKey: Self.planKey)
            lastListenFailure = now()
            Self.log.notice("ping subscriptions not saved: \(error)")
            AlertCheck.note(.listen, ok: false, String(describing: error))
        }
    }

    @ObservationIgnored private var lastListenFailure: Date?

    /// **Check Again** (`AlertCheckSection`): the subscriptions asked for
    /// now, as if the plan had changed, past the ten-minute wait a refusal
    /// sets.
    func checkAlertsNow() async {
        lastListenFailure = nil
        defaults.removeObject(forKey: Self.planKey)
        await listenForPings()
    }

    private func replan() {
        guard sendsPings else { return }
        Task { await listenForPings() }
    }

    /// After a win or a reaction reaches the crew: one ping, the first time
    /// only. An edit to a win, or a changed emoji, is not news.
    private func pingIfNew(_ type: CrewRecordType, _ fields: RecordFields, in crewID: CrewID) async {
        guard sendsPings else { return }
        if type == .message { return await pingMessage(fields, in: crewID) }
        guard let winID = fields["winID"]?.uuid else { return }
        var ping = [CrewPingRecord.crew: CrewPingRecord.tag(crewID.rawValue),
                    CrewPingRecord.sender: CrewPingRecord.tag(me.uuidString),
                    CrewPingRecord.win: winID.uuidString]
        let key: String
        switch type {
        case .sharedWin:
            // A win sent long after it was made (a phone offline all day)
            // is not worth waking anyone for.
            guard let made = fields["createdAt"]?.date, now().timeIntervalSince(made) < 6 * 3600 else { return }
            ping[CrewPingRecord.kind] = CrewPingRecord.Kind.win.rawValue
            // **Every crew it went to is told, once a person** (found
            // 2026-10-12). The key had no crew in it, so a win sent to three
            // crews left one ping, under whichever crew saved first, and a
            // friend who was only in the other two was never told. Now each
            // crew is pinged unless everyone in it has heard already from an
            // earlier one, so someone in two of your crews is still told
            // once (and a phone that does get two folds them: the
            // notification extension, by the win).
            guard let crew = crew(crewID) else { return }
            let people = Set(crew.members.map(\.profileID.uuidString)).subtracting([me.uuidString])
            let heard = told(about: winID)
            // Nobody listed is not "everybody has heard": a friend who
            // joined a moment ago may not be on this phone's list yet.
            guard people.isEmpty || !people.isSubset(of: heard) else { return }
            key = "win-\(winID.uuidString)-\(CrewPingRecord.tag(crewID.rawValue))"
            // **Told only once it is on its way** (found by review,
            // 2026-10-13): marked before the ping was sent, a ping that
            // failed for good left its people "told", and the next crew they
            // were in was skipped for them.
            if await leave(ping, key: key) { remember(people.union(heard), toldAbout: winID) }
            return
        case .reaction:
            guard let owner = winsByCrew[crewID]?.first(where: { $0.winID == winID })?.senderProfileID
                    ?? storiesByCrew[crewID]?.first(where: { $0.id == winID })?.sender,
                  owner != me else { return }
            ping[CrewPingRecord.kind] = CrewPingRecord.Kind.reaction.rawValue
            ping[CrewPingRecord.recipient] = CrewPingRecord.tag(owner.uuidString)
            key = Self.pingKey(winID: winID, carriesLine: fields["line"]?.string.map { !$0.isEmpty } ?? false)
        // The chat's ping is its own (`pingMessage`); a crew's record and a
        // member's are not news (joining is, and says so itself: `pingJoined`),
        // and nor is a score.
        // A story is not news either: its friends learn of it at 8pm, from
        // the row, never from a ping (the spec, 1.2: "no new notification").
        case .crew, .member, .message, .score, .story, .personal:
            return
        }
        await leave(ping, key: key)
    }

    /// **A line in the crew's chat pings the crew** (2026-10-10, the owner:
    /// "I think we should lean on push notifications"). It used to leave
    /// none: the only alert was the app's own, which needs the app to be
    /// woken, and iOS wakes a closed app when it pleases. A doodle and a
    /// photo strip are lines; a drawing thrown onto the tower is not.
    ///
    /// **One a minute a crew, from this phone**: someone typing four short
    /// lines is one tap on a friend's shoulder, not four. A strip always
    /// goes: it is the goal reached, once a day.
    private func pingMessage(_ fields: RecordFields, in crewID: CrewID) async {
        guard let id = fields["messageID"]?.uuid, fields["senderProfileID"]?.uuid == me else { return }
        let text = fields["text"]?.string ?? ""
        guard text != CrewMessage.tossMarker else { return }
        guard let made = fields["createdAt"]?.date, now().timeIntervalSince(made) < 3600 else { return }
        // **A win said in the chat rings nothing** (2026-10-14): the win
        // itself already told the crew (`pingIfNew`, `.sharedWin`), and the
        // line that quotes it is the same news a second time.
        if let quote = fields["quoteWinID"]?.uuid,
           CrewMessage.isWinLine(text: text, sender: me, sketch: fields["sketch"] != nil,
                                 quoting: winsByCrew[crewID]?.first(where: { $0.winID == quote })) { return }
        let isStrip = text == CrewMessage.stripMarker
        if !isStrip, let last = lastMessagePing[crewID], now().timeIntervalSince(last) < Self.messagePingGap { return }
        lastMessagePing[crewID] = now()
        await leave([CrewPingRecord.crew: CrewPingRecord.tag(crewID.rawValue),
                     CrewPingRecord.sender: CrewPingRecord.tag(me.uuidString),
                     CrewPingRecord.kind: CrewPingRecord.Kind.message.rawValue,
                     CrewPingRecord.win: id.uuidString], key: "message-\(id.uuidString)")
    }

    static let messagePingGap: TimeInterval = 60
    @ObservationIgnored private var lastMessagePing: [CrewID: Date] = [:]

    /// **You joined: the crew is told**, once. Your profile id rides in the
    /// ping so a friend's phone, which has not met you yet, can read your
    /// name off your own member record.
    private func pingJoined(_ crewID: CrewID) async {
        guard sendsPings else { return }
        await leave([CrewPingRecord.crew: CrewPingRecord.tag(crewID.rawValue),
                     CrewPingRecord.sender: CrewPingRecord.tag(me.uuidString),
                     CrewPingRecord.kind: CrewPingRecord.Kind.joined.rawValue,
                     CrewPingRecord.win: me.uuidString], key: "joined-\(crewID.rawValue)")
    }

    /// **A streak milestone: the crew is told, by whoever's win made it**
    /// (`CrewStats.milestoneToday`). Every phone that posts after it sees
    /// the same milestone, so the ping goes under a name they would all
    /// give it, and the server keeps the first (`CrewCloud.pingOnce`).
    /// Celebrated, never warned about: nothing is ever sent for a day
    /// missed.
    private func pingMilestone(_ crewID: CrewID) async {
        guard sendsPings, let crew = crew(crewID), crew.members.count > 1,
              let days = CrewStats.milestoneToday(for: crew, store: self) else { return }
        let today = CrewDay.string(for: now(), in: crew.timeZone)
        let key = "milestone-\(crewID.rawValue)-\(today)"
        var done = defaults.dictionary(forKey: Self.pingedKey) as? [String: Double] ?? [:]
        guard done[key] == nil else { return }
        let tag = CrewPingRecord.tag(crewID.rawValue)
        do {
            let name = "ping-milestone-\(tag)-\(today)"
            let first = try await cloud.pingOnce([CrewPingRecord.crew: tag,
                                                  CrewPingRecord.sender: CrewPingRecord.tag(me.uuidString),
                                                  CrewPingRecord.kind: CrewPingRecord.Kind.milestone.rawValue,
                                                  CrewPingRecord.win: String(days)],
                                                 named: name)
            done[key] = now().timeIntervalSince1970
            defaults.set(done, forKey: Self.pingedKey)
            // Deleted later with this phone's other pings, when it was the
            // one that left it: a ping is news for a day, not a record.
            if first {
                var sent = defaults.dictionary(forKey: Self.sentPingsKey) as? [String: Double] ?? [:]
                sent[name] = now().timeIntervalSince1970
                defaults.set(sent, forKey: Self.sentPingsKey)
            }
        } catch {
            Self.log.notice("milestone ping not sent: \(error)")
        }
    }

    private static let toldKey = "crews.pings.told"

    /// Who has been told of a win, across the crews it went to. Kept a day:
    /// a win is news for less.
    private func told(about winID: UUID) -> Set<String> {
        let table = defaults.dictionary(forKey: Self.toldKey) as? [String: [String: Any]] ?? [:]
        return Set(table[winID.uuidString]?["who"] as? [String] ?? [])
    }

    private func remember(_ people: Set<String>, toldAbout winID: UUID) {
        let at = now().timeIntervalSince1970
        var table = (defaults.dictionary(forKey: Self.toldKey) as? [String: [String: Any]] ?? [:])
            .filter { ($0.value["at"] as? Double ?? 0) >= at - 86_400 }
        table[winID.uuidString] = ["at": at, "who": people.sorted()]
        defaults.set(table, forKey: Self.toldKey)
    }

    /// One ping, the first time only for its key, kept for another try when
    /// there was no signal. True when this call sent it or kept it to try
    /// again; false when it was already left, or failed for good.
    @discardableResult
    private func leave(_ ping: [String: String], key: String) async -> Bool {
        let done = defaults.dictionary(forKey: Self.pingedKey) as? [String: Double] ?? [:]
        guard done[key] == nil, !pendingPings.contains(where: { $0.key == key }) else { return false }
        do {
            try await sendPing(ping, key: key)
            AlertCheck.note(.send, ok: true, ping[CrewPingRecord.kind] ?? "")
            return true
        } catch {
            Self.log.notice("ping not sent: \(error)")
            AlertCheck.note(.send, ok: false, String(describing: error))
            // No signal or a busy server says nothing about the ping: it is
            // kept and tried again (`CrewPingRetry`). Anything else is not.
            guard let server = Self.transientWait(error),
                  let wait = CrewPingRetry.wait(afterAttempts: 1, serverSays: server) else { return false }
            let at = now().timeIntervalSince1970
            var pending = pendingPings
            pending.append(CrewPingRetry(key: key, fields: ping, attempts: 1, notBefore: at + wait, firstTried: at))
            pendingPings = pending
            return true
        }
    }

    /// One ping saved, and remembered as sent: by its key, so it is never
    /// sent twice, and by its record name, so it is deleted later.
    private func sendPing(_ ping: [String: String], key: String) async throws {
        let name = try await cloud.ping(ping)
        var done = defaults.dictionary(forKey: Self.pingedKey) as? [String: Double] ?? [:]
        done[key] = now().timeIntervalSince1970
        defaults.set(done, forKey: Self.pingedKey)
        var sent = defaults.dictionary(forKey: Self.sentPingsKey) as? [String: Double] ?? [:]
        sent[name] = now().timeIntervalSince1970
        defaults.set(sent, forKey: Self.sentPingsKey)
    }

    private static let pendingPingsKey = "crews.pings.pending"

    /// Pings waiting for another try, kept on disk.
    private var pendingPings: [CrewPingRetry] {
        get {
            defaults.data(forKey: Self.pendingPingsKey)
                .flatMap { try? JSONDecoder().decode([CrewPingRetry].self, from: $0) } ?? []
        }
        set {
            if newValue.isEmpty {
                defaults.removeObject(forKey: Self.pendingPingsKey)
            } else {
                defaults.set(try? JSONEncoder().encode(newValue), forKey: Self.pendingPingsKey)
            }
        }
    }

    /// The pings due another try, tried. After every flush the live sync
    /// makes and every refresh; cheap when nothing waits.
    func retryPings() async {
        guard sendsPings, !retryingPings, defaults.data(forKey: Self.pendingPingsKey) != nil else { return }
        retryingPings = true
        defer { retryingPings = false }
        let at = now()
        let waiting = pendingPings
        var left: [CrewPingRetry] = []
        for var retry in waiting where !retry.isStale(at: at) {
            guard retry.isDue(at: at) else { left.append(retry); continue }
            do {
                try await sendPing(retry.fields, key: retry.key)
            } catch {
                Self.log.notice("ping not sent again: \(error)")
                retry.attempts += 1
                guard let server = Self.transientWait(error),
                      let wait = CrewPingRetry.wait(afterAttempts: retry.attempts, serverSays: server) else { continue }
                retry.notBefore = now().timeIntervalSince1970 + wait
                left.append(retry)
            }
        }
        // A ping that failed while these were being tried is kept too.
        let arrived = pendingPings.filter { new in !waiting.contains { $0.key == new.key } }
        pendingPings = left + arrived
    }

    @ObservationIgnored private var retryingPings = false

    /// **Which "first time" a reaction record's ping is** (the cohesion
    /// pass, 2026-10-05). A reply is its own news, with its own key: it used
    /// to share the reaction's, so a friend who reacted 🔥 and then wrote
    /// "so proud of you" under it sent one ping for the emoji and nothing for
    /// the words, which are the part worth waking a phone for. Still on the
    /// reaction KIND, so it reaches every phone through the subscription it
    /// already has (`CrewPingPlan.reactionsPredicate`); the extension reads
    /// the record's line and says "Sam: so proud of you".
    nonisolated static func pingKey(winID: UUID, carriesLine: Bool) -> String {
        (carriesLine ? "reply-" : "reaction-") + winID.uuidString
    }

    /// This phone's pings, gone once iCloud has had time to send them: a
    /// ping is only ever a nudge, and the alert goes out the moment it is
    /// saved. Ten minutes leaves room for a slow delivery.
    static let pingLifetime: TimeInterval = 600

    func deleteOldPings() async {
        let cutoff = now().timeIntervalSince1970 - Self.pingLifetime
        var sent = defaults.dictionary(forKey: Self.sentPingsKey) as? [String: Double] ?? [:]
        let old = sent.filter { $0.value < cutoff }.map(\.key)
        if !old.isEmpty {
            await cloud.deletePings(old)
            for name in old { sent[name] = nil }
            defaults.set(sent, forKey: Self.sentPingsKey)
        }
        // What was pinged is remembered a little longer than a crew day, so
        // a win edited later that day is still known not to be news.
        let done = (defaults.dictionary(forKey: Self.pingedKey) as? [String: Double] ?? [:])
            .filter { $0.value >= now().timeIntervalSince1970 - 3 * 86_400 }
        defaults.set(done, forKey: Self.pingedKey)
    }

    /// The names the notification extension needs (`CrewNoteCache`): each
    /// crew's title, its members' first names, your own wins' titles, and
    /// where its zone is. Never a photo.
    func noteCache() -> CrewNoteCache {
        var out: [String: CrewNoteCache.Crew] = [:]
        for crew in crews {
            guard let zone = cloud.zoneLocation(of: crew.id) else { continue }
            let members = Dictionary(crew.members.map {
                (CrewPingRecord.tag($0.profileID.uuidString),
                 CrewNoteCache.Member(profileID: $0.profileID.uuidString, name: $0.shortName))
            }, uniquingKeysWith: { first, _ in first })
            let mine = Dictionary((winsByCrew[crew.id] ?? []).filter { $0.senderProfileID == me }
                .map { ($0.winID.uuidString, $0.title) }, uniquingKeysWith: { first, _ in first })
            out[CrewPingRecord.tag(crew.id.rawValue)] = .init(
                title: crew.displayName(excluding: me), zoneName: crew.id.rawValue, zoneOwner: zone.owner,
                joined: zone.joined, members: members, myWins: mine,
                plans: planKeys(in: crew.id).sorted())
        }
        return CrewNoteCache(me: me.uuidString, crews: out)
    }

    /// Today's plans `crew` can see, by key: the ones proposed in today's
    /// chat and the ones you are in that are for today. What a friend's win
    /// is read against, to say "Sam just did Workout".
    func planKeys(in crewID: CrewID) -> Set<String> {
        guard let crew = crew(crewID) else { return [] }
        let today = CrewDay.string(for: now(), in: crew.timeZone)
        let proposed = messages(in: crewID).compactMap(\.groupPlan).filter { $0.isFor(today) }
        let mine = GroupPlanBook.plans(in: crewID, on: today, me: me)
        return Set((proposed + mine).map { CrewNoteCache.planKey(PlanTime.title($0.title)) })
    }

    private func writeNoteCache() {
        let cache = noteCache()
        guard cache != CrewNoteCache.load() else { return }
        cache.save()
    }

    // MARK: Choices on every phone

    /// iCloud's key-value store, where blocks and mutes meet your other
    /// phones (`CrewChoicesSync`). Nil keeps them on this phone only.
    @ObservationIgnored var choicesCloud: KeyValueCloud?
    private static let choicesAdoptedKey = "crews.sync.adopted"

    private func entries(_ table: CrewChoicesSync.Table) -> CrewChoicesSync.Entries {
        defaults.dictionary(forKey: table.rawValue) as? CrewChoicesSync.Entries ?? [:]
    }

    /// A choice made on this phone: stamped, kept, and sent.
    private func note(_ table: CrewChoicesSync.Table, _ key: String, _ value: Double, name: String? = nil) {
        var mine = entries(table)
        mine[key] = CrewChoicesSync.entry(value, at: now().timeIntervalSince1970, name: name)
        mine = pruned(table, mine)
        defaults.set(mine, forKey: table.rawValue)
        guard let choicesCloud else { return }
        let remote = choicesCloud.dictionary(forKey: table.rawValue) as? CrewChoicesSync.Entries ?? [:]
        choicesCloud.set(pruned(table, CrewChoicesSync.merge(mine, remote)), forKey: table.rawValue)
    }

    /// **A night's watching is kept three days, then let go, everywhere.**
    /// The prune used to run on this phone's copy only, and the merge with
    /// iCloud put every old entry straight back, so the shared table only
    /// grew (the second reader, 2026-10-17). It shares iCloud's one megabyte
    /// with blocks and mutes; full, a block made on one phone would stop
    /// reaching the other. So the merged table is pruned too, both ways.
    private func pruned(_ table: CrewChoicesSync.Table, _ entries: CrewChoicesSync.Entries) -> CrewChoicesSync.Entries {
        guard table == .storiesSeen else { return entries }
        let old = now().timeIntervalSince1970 - 3 * 86_400
        return entries.filter { CrewChoicesSync.stamp($0.value) >= old }
    }

    /// What your other phones chose, merged with this one's, newest first,
    /// and put into effect. At launch and whenever iCloud says it changed.
    func pullChoices() {
        adoptChoicesMadeBeforeSync()
        for table in CrewChoicesSync.Table.allCases {
            let remote = choicesCloud?.dictionary(forKey: table.rawValue) as? CrewChoicesSync.Entries ?? [:]
            let merged = pruned(table, CrewChoicesSync.merge(entries(table), remote))
            defaults.set(merged, forKey: table.rawValue)
            // Ahead of iCloud, or smaller than it (a prune): either way, sent.
            if let choicesCloud, CrewChoicesSync.isAhead(merged, of: remote) || merged.count < remote.count {
                choicesCloud.set(merged, forKey: table.rawValue)
            }
            apply(table, merged)
        }
        recomputeUnread()
        outboxRevision += 1
        replan()
    }

    /// Blocks and mutes from before this sync existed join it stamped as
    /// old as can be, so anything decided on another phone since wins.
    private func adoptChoicesMadeBeforeSync() {
        guard !defaults.bool(forKey: Self.choicesAdoptedKey) else { return }
        defaults.set(true, forKey: Self.choicesAdoptedKey)
        var blockedEntries = entries(.blocked)
        for id in blocked where blockedEntries[id.uuidString] == nil {
            blockedEntries[id.uuidString] = CrewChoicesSync.entry(1, at: 0, name: blockedNames[id.uuidString])
        }
        defaults.set(blockedEntries, forKey: CrewChoicesSync.Table.blocked.rawValue)
        var mutedEntries = entries(.muted)
        for (crew, until) in Self.groupDefaults?.dictionary(forKey: Self.mutedKey) as? [String: Double] ?? [:]
        where mutedEntries[crew] == nil {
            mutedEntries[crew] = CrewChoicesSync.entry(until, at: 0)
        }
        defaults.set(mutedEntries, forKey: CrewChoicesSync.Table.muted.rawValue)
        var quietEntries = entries(.reactionsOff)
        for crew in Self.groupDefaults?.stringArray(forKey: Self.quietReactionsKey) ?? [] where quietEntries[crew] == nil {
            quietEntries[crew] = CrewChoicesSync.entry(1, at: 0)
        }
        defaults.set(quietEntries, forKey: CrewChoicesSync.Table.reactionsOff.rawValue)
    }

    private func apply(_ table: CrewChoicesSync.Table, _ merged: CrewChoicesSync.Entries) {
        switch table {
        case .blocked:
            let on = merged.filter { CrewChoicesSync.value($0.value) == 1 }
            blocked = Set(on.keys.compactMap(UUID.init(uuidString:)))
            defaults.set(blocked.map(\.uuidString).sorted(), forKey: Self.blockedKey)
            var names = blockedNames.filter { on[$0.key] != nil }
            for (id, entry) in on { if let name = CrewChoicesSync.name(entry), !name.isEmpty { names[id] = name } }
            defaults.set(names, forKey: Self.blockedNamesKey)
        case .muted:
            let stamps = merged.compactMapValues { entry -> Double? in
                let until = CrewChoicesSync.value(entry)
                return until > 0 ? until : nil
            }
            Self.groupDefaults?.set(stamps, forKey: Self.mutedKey)
        case .reactionsOff:
            let off = merged.filter { CrewChoicesSync.value($0.value) == 1 }.keys.sorted()
            Self.groupDefaults?.set(off, forKey: Self.quietReactionsKey)
        case .hidden:
            hiddenWins = Set(merged.filter { CrewChoicesSync.value($0.value) == 1 }.keys.compactMap(UUID.init(uuidString:)))
        case .storiesSeen:
            let watched = Set(merged.filter { CrewChoicesSync.value($0.value) == 1 }.keys.compactMap(UUID.init(uuidString:)))
            if !watched.isSubset(of: storiesSeen) {
                storiesSeen.formUnion(watched)
                defaults.set(storiesSeen.map(\.uuidString), forKey: Self.storiesSeenKey)
            }
        }
    }

    // MARK: Test and debug seams

    /// Puts crews and wins in place without a cloud round trip. Debug seeds
    /// and tests only.
    func adopt(crews: [Crew], wins: [CrewID: [SharedWin]]) {
        self.crews = crews
        self.winsByCrew = wins
        recomputeUnread()
    }

    /// A friend's reaction arriving, as a refresh would deliver it.
    func receive(_ reaction: Reaction) {
        var list = reactionsByCrew[reaction.crewID] ?? []
        list.removeAll { $0.id == reaction.id }
        list.append(reaction)
        reactionsByCrew[reaction.crewID] = list
        recomputeUnread()
    }

    /// A friend's line arriving, as a refresh would deliver it.
    func receive(_ message: CrewMessage) {
        var list = messagesByCrew[message.crewID] ?? []
        list.removeAll { $0.messageID == message.messageID }
        list.append(message)
        messagesByCrew[message.crewID] = list
        recomputeUnread()
    }

    /// A friend's win arriving, as a refresh would deliver it.
    func receive(_ win: SharedWin) {
        upsertLocal(win)
        recomputeUnread()
    }

    var outboxEntries: [CrewOutbox.Entry] { outbox.entries }

    // MARK: Private

    private func requireOn() throws {
        guard isEnabled() else { throw CrewError.flagOff }
    }

    private func replace(_ crew: Crew) {
        if let i = crews.firstIndex(where: { $0.id == crew.id }) { crews[i] = crew }
    }

    private func forget(_ crewID: CrewID) {
        crews.removeAll { $0.id == crewID }
        UserDefaults.standard.removeObject(forKey: EveningCheckIn.crewEveningKey)
        // And tonight's cue is decided again, without this crew: taken back
        // outright, it cost the day its only cue when it was the plain one.
        if announces {
            Task { @MainActor in await EveningCheckIn.update(context: SharedModelContainer.shared.mainContext) }
        }
        if let wins = winsByCrew.removeValue(forKey: crewID) {
            for photo in wins.compactMap(\.photo) { try? FileManager.default.removeItem(at: photo) }
        }
        reactionsByCrew[crewID] = nil
        messagesByCrew[crewID] = nil
        for story in storiesByCrew.removeValue(forKey: crewID) ?? [] where story.sender == me {
            if let photo = story.win.photo { try? FileManager.default.removeItem(at: photo) }
        }
        unreadChats.remove(crewID)
        history[crewID] = nil
        unread.remove(crewID)
        outbox.drop(crew: crewID)
        persistOutbox()
        CrewChoice.forget(crewID, defaults)
        var ledger = sent
        for (id, _) in ledger { ledger[id]?.crews.remove(crewID); if ledger[id]?.crews.isEmpty == true { ledger[id] = nil } }
        sent = ledger
        CrewNotifications.removeDelivered(for: crewID)
        try? FileManager.default.removeItem(at: directory.appending(path: "Photos/\(crewID.rawValue)"))
        try? FileManager.default.removeItem(at: directory.appending(path: "Heads/\(crewID.rawValue)"))
    }

    private func upsertLocal(_ win: SharedWin) {
        var list = winsByCrew[win.crewID] ?? []
        if let i = list.firstIndex(where: { $0.winID == win.winID }) { list[i] = win } else { list.append(win) }
        winsByCrew[win.crewID] = list
    }

    private func enqueue(_ entry: CrewOutbox.Entry) {
        outbox.put(entry)
        persistOutbox()
    }

    private func persistOutbox() {
        do { try outbox.write(to: directory.appending(path: "outbox.json")) } catch {
            Self.log.error("outbox not written: \(error)")
        }
        outboxRevision += 1
    }

    /// The derivative, once per post, or nothing when photos may not leave
    /// or the check held it back.
    private func checkedPhoto(for win: OwnWin) async -> Data? {
        guard photosAllowed(), let jpeg = win.photoJPEG,
              let small = await derived(jpeg, cut: win.photoCut) else { return nil }
        guard await photoCheck(small) else {
            heldBackPhoto = win.winID
            return nil
        }
        return small
    }

    func clearHeldBackPhoto() { heldBackPhoto = nil }

    /// The derivative, kept where this crew's photos live.
    ///
    /// **A new file for every picture, never the same name again.** This
    /// wrote "<win>.jpg" each time, so a redrawn doodle (or a new photograph)
    /// landed at the path the crew block was already showing: `CrewPhotoView`
    /// keys its cache and its load on the URL, the block's look compared
    /// equal, and your own crew tower kept drawing the old doodle until the
    /// app was relaunched (the owner, 2026-10-06: doodles should "work well
    /// in crew"). A friend's phone was already right, since what it unpacks
    /// is named by the record's change tag. `update` removes the old file.
    /// `stem`: "story-" for a story's copy, whose name must never begin
    /// with the win's own id: opening that win's crew record again clears
    /// every file named for it (the review, 2026-10-15).
    private func copy(_ data: Data, to crewID: CrewID, win: UUID, stem: String = "") -> URL? {
        let url = directory.appending(
            path: "Photos/\(crewID.rawValue)/\(stem)\(win.uuidString)-\(UUID().uuidString.prefix(8)).jpg")
        do { try write(data, to: url); return url } catch {
            Self.log.error("photo for \(crewID.rawValue, privacy: .public) not kept: \(error)")
            return nil
        }
    }

    private func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    private func sharedWin(_ win: OwnWin, in crew: Crew, photo: URL?) -> SharedWin {
        // Only this crew's people, each once, never you and never anyone you
        // blocked, and three at most: a tag of someone in another crew must
        // not tell this one who they are (the privacy policy: "only your
        // crew sees who a win was with").
        var seen: Set<UUID> = []
        let people = win.withPeople.filter {
            $0 != me && !blocked.contains($0) && crew.member($0) != nil && seen.insert($0).inserted
        }
        return SharedWin(winID: win.winID,
                  crewID: crew.id,
                  senderProfileID: me,
                  crewDay: CrewDay.string(for: win.createdAt, in: crew.timeZone),
                  title: win.title,
                  colour: win.colour,
                  icon: win.icon,
                  blockSize: win.blockSize,
                  photo: photo,
                  cropX: win.cropX,
                  cropY: win.cropY,
                  createdAt: win.createdAt,
                  updatedAt: win.updatedAt,
                  withPeople: Array(people.prefix(CrewCaps.withPeople)))
    }
}

// MARK: - Tonight's Story: what other screens ask

extension SocialStore {
    /// A win a reaction can land on: one in the crew's list, or a story the
    /// crew holds (Tonight's Story, R10).
    func holdsWinOrStory(_ winID: UUID, in crewID: CrewID) -> Bool {
        winsByCrew[crewID]?.contains(where: { $0.winID == winID }) == true
            || storiesByCrew[crewID]?.contains(where: { $0.id == winID }) == true
    }

    /// A story the crew holds, by its win, while it has not ended: what a
    /// reply to it quotes in the chat.
    func storyWin(_ winID: UUID, in crewID: CrewID) -> SharedWin? {
        guard var win = storiesByCrew[crewID]?.first(where: { $0.id == winID && now() < $0.endsAt })?.win else { return nil }
        if win.senderProfileID != me, let photo = win.photo, !photoIsShown(photo) { win.photo = nil }
        return win
    }
}

// MARK: - Tonight's Story

/// Reactions to one of your stories, as your phone last read them, by crew.
nonisolated struct StoryReactionsKept: Codable, Equatable, Sendable {
    /// The night the story was on, for the sweep.
    var day: String
    var byCrew: [String: [Reaction]] = [:]
}

/// **One of your stories, as this phone posted it** (the review, 2026-10-15:
/// which wins were on a story lived only in what the last refresh read, so a
/// delete before the first refresh, or a crew that could not be read, left
/// the story up). Kept on disk, so taking it off reaches every crew it went
/// to, and an edit that changed nothing is not sent again.
nonisolated struct StoryLedgerEntry: Codable, Equatable, Sendable {
    var crews: Set<String>
    var day: String
    var endsAt: Date
    var signature: String
}

extension SocialStore {
    static let storiesSeenKey = "crewStoriesSeen"
    static let storiesHiddenKey = "crewStoriesHidden"
    static let storyReactionsFile = "story-reactions.json"
    static let storyLedgerFile = "story-ledger.json"
    /// Where a kept reaction's sticker is copied, out of the cloud's cache,
    /// which clears its files when a crew's records are opened again.
    static let storyStickersFolder = "StoryStickers"

    /// **Puts one of today's wins on Tonight's Story** (R1 to R4): written
    /// into every crew you are in, sealed with each crew's key, with the
    /// photo only if you may send one (13 to 15 send the block alone, as
    /// they do to a crew). Only a win of today, by your own clock.
    func postStory(_ win: OwnWin) async {
        guard isEnabled(), !crews.isEmpty else { return }
        let zone = TimeZone.current
        let existing = storyLedger[win.winID].flatMap { now() < $0.endsAt ? $0 : nil }
        let day = existing?.day ?? CrewDay.string(for: win.createdAt, in: zone)
        guard existing != nil || StoryClock.canPost(winMadeAt: win.createdAt, at: now(), in: zone),
              let ends = existing?.endsAt ?? StoryClock.endsAt(of: day, in: zone), now() < ends else { return }
        let win = withTags(win)
        let signature = Self.signature(win)
        // An edit that changed nothing a friend sees sends nothing (a note,
        // another win of the same habit): no new photo to every crew.
        let targets = groupCrews.filter { !leavingCrews.contains($0.id) }
        if let existing, existing.signature == signature,
           Set(targets.map(\.id.rawValue)).isSubset(of: existing.crews) { return }
        // **Taken off while this waited** (the review: an edit's post waited on
        // the photo check, a delete landed meanwhile, and the post wrote the
        // story back for a win that no longer existed).
        let generation = storyGeneration[win.winID, default: 0]
        let photo = await checkedPhoto(for: win)
        guard storyGeneration[win.winID, default: 0] == generation else { return }
        var sentTo: Set<String> = []
        // Group crews only: a friend in a personal chat with you is in a crew
        // with you too, and saw it there.
        for crew in groupCrews where !leavingCrews.contains(crew.id) {
            var shared = sharedWin(win, in: crew, photo: photo.flatMap { copy($0, to: crew.id, win: win.winID, stem: "story-") })
            shared.crewDay = day
            let words = storyWords(on: day)
            let story = CrewStory(win: shared, endsAt: ends, line: storyLine(on: day),
                                  low: words.low.isEmpty ? nil : words.low,
                                  buffalo: words.buffalo.isEmpty ? nil : words.buffalo,
                                  wordsPhoto: words.photo, wordsArt: storyArt(words))
            let old = storiesByCrew[crew.id]?.first { $0.id == story.id }
            var held = storiesByCrew[crew.id] ?? []
            held.removeAll { $0.id == story.id }
            held.append(story)
            storiesByCrew[crew.id] = held
            if let was = old?.win.photo, was != shared.photo { try? FileManager.default.removeItem(at: was) }
            enqueue(.init(crew: crew.id, type: .story, name: story.id.uuidString, fields: CrewRecords.fields(story)))
            sentTo.insert(crew.id.rawValue)
        }
        storyLedger[win.winID] = StoryLedgerEntry(crews: sentTo.union(existing?.crews ?? []), day: day,
                                                  endsAt: ends, signature: signature)
        persistStoryLedger()
        nudgeLive()
        await flush()
    }

    /// An edit to a win on the story: the story changes with it, on the
    /// night it was posted to.
    func updateStory(_ win: OwnWin) async { await postStory(win) }

    static let storyLinesKey = "crewStoryLines"

    /// Your line for the night of `day`, if you wrote one.
    func storyLine(on day: String) -> String? {
        (defaults.dictionary(forKey: Self.storyLinesKey) as? [String: String])?[day]
    }

    /// **Your line for tonight**, onto every story of yours that is up, in
    /// every crew it went to; kept for a story marked later the same night.
    /// Empty takes it off. Checked as every word a crew sees is.
    @discardableResult
    func setStoryLine(_ raw: String, on day: String) async -> ReplyOutcome {
        let line = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(StoryLine.limit))
        guard line.isEmpty || CrewWords.isAcceptable(line) else { return .refusedWords }
        keepStoryLine(line, on: day)
        let t = now()
        for (crewID, stories) in storiesByCrew {
            for story in stories where story.sender == me && story.day == day && t < story.endsAt {
                var changed = story
                changed.line = line.isEmpty ? nil : line
                storiesByCrew[crewID]?.removeAll { $0.id == story.id }
                storiesByCrew[crewID]?.append(changed)
                enqueue(.init(crew: crewID, type: .story, name: story.id.uuidString, fields: CrewRecords.fields(changed)))
            }
        }
        nudgeLive()
        await flush()
        return .sent
    }

    /// The line kept for the night, and nothing sent.
    func keepStoryLine(_ line: String, on day: String) {
        var lines = defaults.dictionary(forKey: Self.storyLinesKey) as? [String: String] ?? [:]
        lines[day] = line.isEmpty ? nil : line
        // Only the last few nights are worth keeping.
        if lines.count > 7 { for key in lines.keys.sorted().dropLast(7) { lines[key] = nil } }
        defaults.set(lines, forKey: Self.storyLinesKey)
    }

    /// Off the story, from every crew it went to, read this time or not (R3).
    func withdrawStory(winID: UUID) async {
        guard isEnabled() else { return }
        dropStoryArt(holding: winID)
        storyGeneration[winID, default: 0] &+= 1
        var crewIDs = Set(storyLedger[winID]?.crews.map(CrewID.init(rawValue:)) ?? [])
        for (crewID, stories) in storiesByCrew where stories.contains(where: { $0.id == winID && $0.sender == me }) {
            crewIDs.insert(crewID)
        }
        for crewID in crewIDs where crew(crewID) != nil {
            if let story = storiesByCrew[crewID]?.first(where: { $0.id == winID }), let photo = story.win.photo {
                try? FileManager.default.removeItem(at: photo)
            }
            storiesByCrew[crewID]?.removeAll { $0.id == winID }
            enqueue(.init(crew: crewID, type: .story, name: winID.uuidString, fields: nil))
        }
        if storyLedger.removeValue(forKey: winID) != nil { persistStoryLedger() }
        nudgeLive()
        await flush()
    }

    /// Whether this win of yours is on a story that has not ended: the
    /// ledger first, which this phone keeps, then what the crews hold.
    func isOnStory(_ winID: UUID) -> Bool {
        let t = now()
        if let entry = storyLedger[winID] { return Self.ownStoryLive(day: entry.day, endsAt: entry.endsAt, at: t) }
        return storiesByCrew.values.contains {
            $0.contains { $0.id == winID && $0.sender == me && Self.ownStoryLive(day: $0.day, endsAt: $0.endsAt, at: t) }
        }
    }

    /// **Your story is the night's, by your own clock** (the second reader,
    /// 2026-10-17). The sealed end moved to noon where the day ends last, so
    /// friends far west get their whole night; read by that end alone, your
    /// own story carried yesterday's wins through all of today. Yours ends at
    /// your own 9am, as it does for anyone watching where you are.
    nonisolated static func ownStoryLive(day: String, endsAt: Date, at t: Date, in zone: TimeZone = .current) -> Bool {
        guard t < endsAt, let window = StoryClock.window(of: day, endsAt: endsAt, in: zone) else { return false }
        return t < window.upperBound
    }

    /// Your story tonight, each win once, oldest first.
    var myStory: [CrewStory] {
        let t = now()
        var seen: Set<UUID> = []
        return crews.flatMap { storiesByCrew[$0.id] ?? [] }
            .filter { $0.sender == me && Self.ownStoryLive(day: $0.day, endsAt: $0.endsAt, at: t) && seen.insert($0.id).inserted }
            .sorted { ($0.win.createdAt, $0.id.uuidString) < ($1.win.createdAt, $1.id.uuidString) }
    }

    /// Friends with a story waiting or open, in the row's order. **A
    /// friend's photo is checked here as a crew win's is** (the review: the
    /// row and the viewer drew it straight, so a 13 to 15 phone with the
    /// analysis off saw it): unshown, the story is the block.
    func storyPeople(at moment: Date? = nil, in zone: TimeZone = .current) -> [StoryPerson] {
        let checked = storiesByCrew.mapValues { stories in
            stories.map { story -> CrewStory in
                guard story.sender != me else { return story }
                var shown = story
                if let photo = story.win.photo, !photoIsShown(photo) { shown.win.photo = nil }
                // The page's drawing and stickers, as their doodle is.
                if let art = story.wordsArt, !photoIsShown(art) { shown.wordsArt = nil }
                return shown
            }
        }
        return StoryPerson.gather(checked, crewOrder: crews.compactMap { visible($0.id)?.id }, me: me,
                                  blocked: blocked, hidden: storiesHidden, hiddenWins: hiddenWins, seen: storiesSeen,
                                  now: moment ?? StoryClock.now(now(), in: zone), zone: zone)
    }

    /// **A reply to a friend's story** (the owner, 2026-10-16: "reply to
    /// stories and it go to your personal chat"). Into your one-to-one
    /// crew with them when there is one (`personalCrew(with:)`), quoting the
    /// story; until there is, into the crew the story came from, as before.
    /// The outcome, and where it went, said back to you ("Sent to Sam", or
    /// the crew's name when there could be no personal chat): the review,
    /// 2026-10-16, a private reply must never go to a crew unannounced.
    /// **A doodle on a story goes where a typed reply goes** (the audit,
    /// 2026-10-16: the words went to your conversation with them and the
    /// drawing to the whole crew, with "Sent" saying neither): to them.
    func doodleToStory(_ png: Data, story: CrewStory) async -> (outcome: ReplyOutcome, to: String) {
        let friend = crew(story.win.crewID)?.member(story.sender)?.firstName ?? ""
        if let personal = await startPersonal(with: story.sender) {
            return (await sendDoodle(png, in: personal.id), friend.isEmpty ? "your chat" : friend)
        }
        return (await doodle(png, to: story.id, in: story.win.crewID), crew(story.win.crewID)?.displayName(excluding: me) ?? "the crew")
    }

    func replyToStory(_ text: String, story: CrewStory) async -> (outcome: ReplyOutcome, to: String) {
        let title = String(story.win.title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(StoryLine.limit))
        let quote = title.isEmpty ? "a win" : title
        let friend = crew(story.win.crewID)?.member(story.sender)?.firstName ?? ""
        if let personal = await startPersonal(with: story.sender) {
            let outcome = await send(text, in: personal.id, quoting: holdsWinOrStory(story.id, in: personal.id) ? story.id : nil,
                                     storyQuote: quote)
            return (outcome, friend.isEmpty ? "your chat" : friend)
        }
        let outcome = await send(text, in: story.win.crewID, quoting: story.id, storyQuote: quote)
        return (outcome, crew(story.win.crewID)?.displayName(excluding: me) ?? "the crew")
    }

    /// A quick reaction from a story's reply bar: on the story itself, so it
    /// lands on the poster's block as a tower reaction does.
    func reactToStory(_ emoji: String, story: CrewStory) async {
        await react(emoji, to: story.id, in: story.win.crewID)
    }

    /// Your personal chat with them: one you are both in, or the one you
    /// started and they have not joined yet.
    func personalCrew(with friend: UUID) -> Crew? {
        if let both = crews.first(where: { $0.isPersonal && $0.member(friend) != nil && visible($0.id) != nil }) {
            return both
        }
        guard let start = personalStarted[friend.uuidString] else { return nil }
        return crew(CrewID(rawValue: start.crew))
    }

    /// A story opened on this phone: its ring goes grey.
    func markStorySeen(_ id: UUID) {
        guard storiesSeen.insert(id).inserted else { return }
        defaults.set(storiesSeen.map(\.uuidString), forKey: Self.storiesSeenKey)
        note(.storiesSeen, id.uuidString, 1)
    }

    /// Hide Their Story, for the night it is on (R11). Their head stays.
    func hideStory(of profileID: UUID, day: String) {
        storiesHidden[profileID] = day
        persistStoriesHidden()
    }

    private func persistStoriesHidden() {
        defaults.set(Dictionary(uniqueKeysWithValues: storiesHidden.map { ($0.key.uuidString, $0.value) }),
                     forKey: Self.storiesHiddenKey)
    }

    func persistStoryLedger() {
        write(json: storyLedger, to: Self.storyLedgerFile, what: "story ledger")
    }

    private func write<T: Encodable>(json value: T, to file: String, what: String) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(value).write(to: directory.appending(path: file), options: .atomic)
        } catch {
            Self.log.error("\(what, privacy: .public) not kept: \(error)")
        }
    }

    /// **Copies friends' reactions to your stories onto this phone**, so
    /// they stay on your block after the night, when their records have gone
    /// (R12). While the story is on, a reaction taken back comes off. After
    /// its end nothing comes off: a friend's phone clears its reaction once
    /// the story has gone, and your phone may read that before its own sweep
    /// (the review: one opened at 1pm lost the night's reactions). A sticker
    /// is copied out of the cloud's cache, which clears its files.
    func keepStoryReactions() {
        let t = now()
        var changed = false
        for (crewID, stories) in storiesByCrew {
            for story in stories where story.sender == me {
                let theirs = (reactionsByCrew[crewID] ?? []).filter { $0.winID == story.id && $0.profileID != me }
                    .map(keptCopy)
                var kept = storyReactionsKept[story.id] ?? StoryReactionsKept(day: story.day)
                let held = kept.byCrew[crewID.rawValue] ?? []
                let next: [Reaction]
                if t < story.endsAt {
                    next = theirs
                } else {
                    next = held + theirs.filter { new in !held.contains { $0.id == new.id } }
                }
                guard next != held else { continue }
                kept.byCrew[crewID.rawValue] = next
                storyReactionsKept[story.id] = kept
                changed = true
            }
        }
        if changed { write(json: storyReactionsKept, to: Self.storyReactionsFile, what: "story reactions") }
    }

    /// A reaction whose sticker now lives in this phone's own folder.
    private func keptCopy(_ reaction: Reaction) -> Reaction {
        guard let sticker = reaction.sketch else { return reaction }
        let folder = directory.appending(path: Self.storyStickersFolder)
        guard !sticker.path.hasPrefix(folder.path) else { return reaction }
        let kept = folder.appending(path: "\(reaction.id.replacingOccurrences(of: "/", with: "-"))-\(sticker.lastPathComponent)")
        if !FileManager.default.fileExists(atPath: kept.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? FileManager.default.copyItem(at: sticker, to: kept)
        }
        var copy = reaction
        copy.sketch = FileManager.default.fileExists(atPath: kept.path) ? kept : nil
        return copy
    }

    /// Kept reactions to your stories, by win, for your tower.
    var keptStoryReactions: [UUID: [Reaction]] {
        storyReactionsKept.mapValues { $0.byCrew.values.flatMap { $0 } }
    }

    /// **The sweep** (R4), from `prune`: a story past its end leaves every
    /// phone's list, and the poster's phone deletes its records, from every
    /// crew the ledger says it went to, and its photo. What was opened or
    /// hidden is forgotten once its night is.
    func sweepStories() {
        let t = now()
        for (crewID, stories) in storiesByCrew {
            let gone = stories.filter { t >= $0.endsAt }
            guard !gone.isEmpty else { continue }
            storiesByCrew[crewID]?.removeAll { t >= $0.endsAt }
            for story in gone where story.sender == me {
                if let photo = story.win.photo { try? FileManager.default.removeItem(at: photo) }
                enqueue(.init(crew: crewID, type: .story, name: story.id.uuidString, fields: nil))
            }
        }
        let ended = storyLedger.filter { t >= $0.value.endsAt }
        if !ended.isEmpty {
            for (winID, entry) in ended {
                for raw in entry.crews where crew(CrewID(rawValue: raw)) != nil {
                    enqueue(.init(crew: CrewID(rawValue: raw), type: .story, name: winID.uuidString, fields: nil))
                }
                storyLedger[winID] = nil
            }
            persistStoryLedger()
        }
        guard hasFetchedCrews else { return }
        // The words pages' own marks too (`StoryPerson.wordsKey`): left
        // out, the sweep forgot them and a watched words page lit again.
        let live = Set(storiesByCrew.values.flatMap { $0.map(\.id) })
            .union(storyPeople(at: t).compactMap(\.wordsKey))
            .union([StoryPerson(profileID: me, stories: myStory, phase: .open, watched: false).wordsKey].compactMap { $0 })
        if !storiesSeen.isSubset(of: live) {
            storiesSeen.formIntersection(live)
            defaults.set(storiesSeen.map(\.uuidString), forKey: Self.storiesSeenKey)
        }
        let yesterday = CrewDay.day(CrewDay.string(for: t, in: .current), offsetBy: -1, in: .current) ?? ""
        if storiesHidden.values.contains(where: { $0 < yesterday }) {
            storiesHidden = storiesHidden.filter { $0.value >= yesterday }
            persistStoriesHidden()
        }
        // Kept reactions last as long as a crew keeps a win's (two weeks).
        let today = CrewDay.string(for: t, in: .current)
        if let cutoff = CrewDay.oldestKept(today: today, in: .current),
           storyReactionsKept.values.contains(where: { $0.day < cutoff }) {
            for kept in storyReactionsKept.values where kept.day < cutoff {
                for sticker in kept.byCrew.values.flatMap({ $0 }).compactMap(\.sketch) {
                    try? FileManager.default.removeItem(at: sticker)
                }
            }
            storyReactionsKept = storyReactionsKept.filter { $0.value.day >= cutoff }
            write(json: storyReactionsKept, to: Self.storyReactionsFile, what: "story reactions")
        }
    }

    /// A photo taken off a story win comes off the story too.
    func removeStoryPhoto(winID: UUID) async {
        storyGeneration[winID, default: 0] &+= 1
        dropStoryArt(holding: winID)
        for (crewID, stories) in storiesByCrew {
            guard var story = stories.first(where: { $0.id == winID && $0.sender == me }), story.win.photo != nil else { continue }
            if let photo = story.win.photo { try? FileManager.default.removeItem(at: photo) }
            story.win.photo = nil
            story.win.updatedAt = now()
            storiesByCrew[crewID]?.removeAll { $0.id == winID }
            storiesByCrew[crewID]?.append(story)
            enqueue(.init(crew: crewID, type: .story, name: winID.uuidString, fields: CrewRecords.fields(story)))
        }
        // The next edit is sent whole, with the photo gone from its signature.
        if storyLedger[winID] != nil { storyLedger[winID]?.signature = ""; persistStoryLedger() }
        await flush()
    }
}

// MARK: - Personal chats

extension SocialStore {
    /// **A personal chat shows the other person as the crew you share shows
    /// them** (the review, 2026-10-16): their name and head from their
    /// member record there, never from the chat, where they could write
    /// anyone's. Kept live, refresh by refresh.
    nonisolated static func personalNamedFromShared(_ crews: [Crew], me: UUID) -> [Crew] {
        let shared = crews.filter { !$0.isPersonal }
        return crews.map { crew in
            guard crew.isPersonal else { return crew }
            var named = crew
            for (i, member) in crew.members.enumerated() where member.profileID != me {
                if let there = shared.lazy.compactMap({ $0.member(member.profileID) }).first {
                    named.members[i].firstName = there.firstName
                    named.members[i].head = there.head
                    named.members[i].photo = there.photo
                }
            }
            return named
        }
    }
}

/// One personal chat you started, until the friend is in it.
nonisolated struct PersonalStart: Codable, Equatable, Sendable {
    var crew: String
    /// The invitation's record, and the crew it was left in.
    var invite: String
    var sharedCrew: String = ""
    var at: Date
}

extension SocialStore {
    static let personalStartedKey = "crews.personalStarted.v3"
    static let personalHandledKey = "crews.personalHandled.v3"
    static let personalLeftKey = "crews.personalLeft"
    /// How long an invitation waits before it is sealed and left again.
    static let personalWait: TimeInterval = 3 * 86_400

    /// Personal chats you started and they have not joined, by friend.
    var personalStarted: [String: PersonalStart] {
        get { (defaults.data(forKey: Self.personalStartedKey)).flatMap { try? JSONDecoder().decode([String: PersonalStart].self, from: $0) } ?? [:] }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: Self.personalStartedKey) }
    }

    /// Invitations already settled, oldest first, by a fingerprint of what
    /// was sealed (so a new invitation is never mistaken for an old one).
    private var personalHandled: [String] {
        get { defaults.stringArray(forKey: Self.personalHandledKey) ?? [] }
        set { defaults.set(Array(newValue.suffix(200)), forKey: Self.personalHandledKey) }
    }

    /// Friends whose personal chat you left: their invitations are refused
    /// until you start one with them yourself.
    private var personalLeft: Set<String> {
        get { Set(defaults.stringArray(forKey: Self.personalLeftKey) ?? []) }
        set { defaults.set(Array(newValue), forKey: Self.personalLeftKey) }
    }

    static func fingerprint(_ invite: PersonalInvite) -> String {
        SHA256.hash(data: invite.sealed).prefix(12).map { String(format: "%02x", $0) }.joined()
    }

    /// A personal chat was left or ended by you: its other person's next
    /// invitation does not pull you back. Only once the leave has happened.
    func notePersonalLeft(_ crew: Crew) {
        guard crew.isPersonal else { return }
        var left = personalLeft
        for member in crew.members where member.profileID != me { left.insert(member.profileID.uuidString) }
        personalLeft = left
    }

    /// **Your personal chat with a friend, made if there is none** (the owner,
    /// 2026-10-16). A crew of two, and its invitation left in a crew you
    /// share, sealed to their key alone (`CrewSealedNote`). Nil when they
    /// cannot be reached that way (blocked, no crew in common, a phone too
    /// old to have published a key): the caller then says where it went.
    /// One start at a time per friend.
    func startPersonal(with friend: UUID) async -> Crew? {
        if let existing = personalCrew(with: friend) { return existing }
        if let running = personalStarting[friend] { return await running.value }
        let task = Task { @MainActor in await self.makePersonal(with: friend) }
        personalStarting[friend] = task
        let made = await task.value
        personalStarting[friend] = nil
        return made
    }

    private func makePersonal(with friend: UUID) async -> Crew? {
        guard isEnabled(), canReply(), friend != me, !blocked.contains(friend),
              groupCrews.contains(where: { $0.member(friend) != nil }) else { return nil }
        do {
            let made = try await createCrew(name: "", personal: true)
            guard await leaveInvitation(for: friend, to: made.crew, link: made.invite) else {
                try? await end(made.crew.id)
                return nil
            }
            // Starting one yourself undoes having left their last.
            var left = personalLeft
            left.remove(friend.uuidString)
            personalLeft = left
            return made.crew
        } catch {
            Self.log.error("personal chat not started: \(error)")
            return nil
        }
    }

    /// Seals the chat's link to the friend and leaves it in a crew you share,
    /// replacing any invitation of yours to them already waiting there.
    private func leaveInvitation(for friend: UUID, to chat: Crew, link: URL) async -> Bool {
        guard let shared = groupCrews.first(where: { $0.member(friend) != nil && visible($0.id) != nil }),
              let key = cloud.memberPublicKey(friend, in: shared.id),
              let note = try? JSONEncoder().encode(PersonalNote(to: friend, link: link.absoluteString)),
              let sealed = CrewSealedNote.seal(note, to: key, info: CrewSealedNote.info(from: me)) else { return false }
        let name = "\(me.uuidString)-\(chat.id.rawValue)"
        if let old = personalStarted[friend.uuidString], !old.sharedCrew.isEmpty, old.sharedCrew != shared.id.rawValue {
            enqueue(.init(crew: CrewID(rawValue: old.sharedCrew), type: .personal, name: old.invite, fields: nil))
        }
        var started = personalStarted
        started[friend.uuidString] = PersonalStart(crew: chat.id.rawValue, invite: name, sharedCrew: shared.id.rawValue, at: now())
        personalStarted = started
        let invite = PersonalInvite(from: me, sealed: sealed, createdAt: now())
        enqueue(.init(crew: shared.id, type: .personal, name: name, fields: CrewRecords.fields(invite)))
        await flush()
        return true
    }

    /// **After a refresh: join what was left for you, tidy what you left.**
    /// An invitation is acted on only when it comes from a member of the crew
    /// it was left in, opens with your key as from them, is for you, and is
    /// not from someone blocked or whose chat you left; what it opens must be
    /// a personal chat they started, named as they are here
    /// (`accept(personalFrom:personalName:)`). Yours is deleted once they are
    /// in, and sealed and left again if it has waited too long. If you both
    /// started one, the lower profile id's stands on both phones.
    func settlePersonals() async {
        var tidy: [(CrewID, String)] = []
        // Your own invitations: done, or waited long enough to send again.
        for (friend, start) in personalStarted {
            guard let chat = crew(CrewID(rawValue: start.crew)) else {
                var started = personalStarted
                started[friend] = nil
                personalStarted = started
                continue
            }
            if let id = UUID(uuidString: friend), chat.member(id) != nil {
                if !start.sharedCrew.isEmpty { tidy.append((CrewID(rawValue: start.sharedCrew), start.invite)) }
                var started = personalStarted
                started[friend] = nil
                personalStarted = started
            } else if let id = UUID(uuidString: friend),
                      blocked.contains(id) || !groupCrews.contains(where: { $0.member(id) != nil }) {
                // Nobody to send it to any more: stop asking, keep the chat.
                if !start.sharedCrew.isEmpty { tidy.append((CrewID(rawValue: start.sharedCrew), start.invite)) }
                var started = personalStarted
                started[friend] = nil
                personalStarted = started
            } else if now().timeIntervalSince(start.at) > Self.personalWait, let id = UUID(uuidString: friend),
                      let link = try? await cloud.shareURL(for: chat.id) {
                // The chat and every line in it stay; only the invitation is new.
                _ = await leaveInvitation(for: id, to: chat, link: link)
            }
        }
        var joinedNow: Set<UUID> = []
        for crew in groupCrews {
            guard let invites = try? await cloud.fetchPersonals(in: crew.id) else { continue }
            for invite in invites where invite.from != me {
                let print = Self.fingerprint(invite)
                guard crew.member(invite.from) != nil, !blocked.contains(invite.from),
                      !personalLeft.contains(invite.from.uuidString), !personalHandled.contains(print),
                      !joinedNow.contains(invite.from) else { continue }
                guard let opened = cloud.openSealed(invite.sealed, info: CrewSealedNote.info(from: invite.from)),
                      let note = try? JSONDecoder().decode(PersonalNote.self, from: opened) else {
                    // Not for you (sealed to someone else), or broken: done with.
                    personalHandled.append(print)
                    continue
                }
                guard note.to == me, let url = URL(string: note.link) else { personalHandled.append(print); continue }
                if crews.contains(where: { $0.isPersonal && $0.member(invite.from) != nil && $0.members.count == 2 }) {
                    personalHandled.append(print)
                    continue
                }
                let mine = personalStarted[invite.from.uuidString]
                // Both started one: the lower id's stands; the other waits.
                if mine != nil, me.uuidString < invite.from.uuidString { continue }
                do {
                    _ = try await accept(CrewInvite(url: url), personal: true, personalFrom: invite.from,
                                         personalName: crew.member(invite.from)?.firstName)
                    personalHandled.append(print)
                    joinedNow.insert(invite.from)
                    // In theirs: now yours can go, ended by the app, not left.
                    if let mine, let chat = self.crew(CrewID(rawValue: mine.crew)) {
                        try? await end(chat.id)
                        var left = personalLeft
                        left.remove(invite.from.uuidString)
                        personalLeft = left
                        if !mine.sharedCrew.isEmpty { tidy.append((CrewID(rawValue: mine.sharedCrew), mine.invite)) }
                        var started = personalStarted
                        started[invite.from.uuidString] = nil
                        personalStarted = started
                    }
                } catch {
                    // Final answers are settled; anything else is tried again.
                    if let crewError = error as? CrewError, [.unknownCrew, .crewFull, .tooManyCrews].contains(crewError) {
                        personalHandled.append(print)
                    }
                    Self.log.error("personal chat not joined: \(error)")
                }
            }
        }
        // No automatic clean-up of one-person chats (the review, 2026-10-16):
        // a second phone, a reinstall or a half-finished join all look like
        // one, and ending one deletes it for both. They are left as they are.
        for (crewID, name) in tidy {
            enqueue(.init(crew: crewID, type: .personal, name: name, fields: nil))
        }
        if !tidy.isEmpty { await flush() }
    }
}

// MARK: - Your username

extension SocialStore {
    enum HandleOutcome: Equatable {
        case saved
        case same
        case invalid(String)
        case taken
        case tooSoon(Date)
        case offline
    }

    /// **Claims a username and makes it yours** (`Handle`). The rules first;
    /// then once a month; then the public database, first come; then the old
    /// one is let go and your crews are told (your member record).
    func setHandle(_ text: String, now: Date = Date()) async -> HandleOutcome {
        let handle = Handle.normalized(text)
        let current = myHandle()
        if handle == current { return .same }
        if let problem = Handle.problem(handle) { return .invalid(problem) }
        if current != nil, let next = Handle.nextChange(after: myHandleSetAt(), now: now) { return .tooSoon(next) }
        do {
            guard try await cloud.claimHandle(handle) else { return .taken }
        } catch {
            return .offline
        }
        // Kept first, then the old one let go (the review: let go first, a
        // phone stopped in between advertised a name anyone could take).
        keepMyHandle(handle, now)
        if let old = current, old != handle { oweHandleRelease(old) }
        await payHandleReleases()
        // Your crews hear it on your member record.
        if isEnabled() { await shareMyself() }
        return .saved
    }
}

// MARK: - Usernames, kept honest

extension SocialStore {
    private static let owedReleasesKey = "crews.owedHandleReleases"

    /// **A username to let go, remembered until it is** (the review: a
    /// release that failed was never tried again, and the name stayed taken
    /// for good, Reset All Data's too).
    func oweHandleRelease(_ handle: String) {
        var owed = defaults.stringArray(forKey: Self.owedReleasesKey) ?? []
        if !owed.contains(handle) { owed.append(handle) }
        defaults.set(owed, forKey: Self.owedReleasesKey)
    }

    func payHandleReleases() async {
        let owed = defaults.stringArray(forKey: Self.owedReleasesKey) ?? []
        guard !owed.isEmpty else { return }
        var still: [String] = []
        for handle in owed where handle != myHandle() {
            if await !cloud.releaseHandle(handle) { still.append(handle) }
        }
        defaults.set(still, forKey: Self.owedReleasesKey)
    }

    /// **A friend's username is shown only once it is theirs** (the review):
    /// the claim's creator is the account that wrote their member record.
    /// Checked once a day each. Your own, written by another of your phones,
    /// is taken up here, so two phones of one account agree.
    func checkHandles(now: Date = Date()) async {
        for crew in crews {
            for member in crew.members {
                guard let handle = member.handle else {
                    if member.profileID != me { verifiedHandles[member.profileID] = nil }
                    continue
                }
                let key = "\(member.profileID.uuidString)|\(handle)"
                if let at = handleChecked[key], now.timeIntervalSince(at) < 86_400 { continue }
                guard let verdict = await cloud.verifyHandle(handle, of: member.profileID, in: crew.id) else { continue }
                handleChecked[key] = now
                if member.profileID == me {
                    if verdict, myHandle() == nil { keepMyHandle(handle, now) }
                } else {
                    verifiedHandles[member.profileID] = verdict ? handle : nil
                }
            }
        }
    }

    /// What to show after a friend's name: their checked username, or nothing.
    func shownHandle(of member: CrewMember) -> String? {
        if member.profileID == me { return myHandle() }
        guard let handle = member.handle, verifiedHandles[member.profileID] == handle else { return nil }
        return handle
    }
}

// MARK: - High, low, buffalo

extension SocialStore {
    private static let storyWordsKey = "crews.storyWords"

    /// The night's words for a day (the high is also `storyLine`).
    func storyWords(on day: String) -> StoryWords {
        let all = (defaults.data(forKey: Self.storyWordsKey)).flatMap { try? JSONDecoder().decode([String: StoryWords].self, from: $0) } ?? [:]
        var words = all[day] ?? StoryWords()
        words.high = storyLine(on: day) ?? words.high
        return words
    }

    /// The page's picture as a file: only the one that passed the check,
    /// only where photos may go, and only if it is still here.
    func storyArt(_ words: StoryWords) -> URL? {
        guard let name = words.art, name == words.artChecked, photosAllowed() else { return nil }
        let url = StoryPageFiles.directory.appending(path: name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func keepStoryWords(_ words: StoryWords, on day: String) {
        var all = (defaults.data(forKey: Self.storyWordsKey)).flatMap { try? JSONDecoder().decode([String: StoryWords].self, from: $0) } ?? [:]
        all[day] = words
        if all.count > 7 { for key in all.keys.sorted().dropLast(7) { all[key] = nil } }
        defaults.set(try? JSONEncoder().encode(all), forKey: Self.storyWordsKey)
    }

    /// **Your high, low and buffalo for tonight**, onto every story of yours
    /// that is up; each checked as every word a crew sees is, and cut to one
    /// line. Empty takes one off. Nothing is kept until all of it passes,
    /// and each story is written once (the review, 2026-10-16: the line went
    /// first and the rest after, twice the upload).
    @discardableResult
    func setStoryWords(_ raw: StoryWords, on day: String) async -> ReplyOutcome {
        func clean(_ s: String) -> String { String(s.trimmingCharacters(in: .whitespacesAndNewlines).prefix(StoryLine.limit)) }
        var words = StoryWords(high: clean(raw.high), low: clean(raw.low), buffalo: clean(raw.buffalo),
                               photo: raw.photo, art: raw.art, artChecked: nil, artWins: raw.artWins)
        for text in [words.high, words.low, words.buffalo] where !text.isEmpty && !CrewWords.isAcceptable(text) {
            return .refusedWords
        }
        // The page's picture is checked as a doodle is before it leaves, and
        // goes only where photos may (it can carry the photo strip). Checked
        // once: an unchanged picture keeps its verdict.
        if let name = words.art {
            guard photosAllowed() else { return .notAllowed }
            let before = storyWords(on: day)
            if before.art == name, before.artChecked == name {
                words.artChecked = name
            } else {
                let url = StoryPageFiles.directory.appending(path: name)
                guard let png = try? Data(contentsOf: url), await photoCheck(png) else { return .refusedSketch }
                words.artChecked = name
            }
        }
        keepStoryWords(words, on: day)
        keepStoryLine(words.high, on: day)
        let t = now()
        for (crewID, stories) in storiesByCrew {
            for story in stories where story.sender == me && story.day == day && t < story.endsAt {
                var changed = story
                changed.line = words.high.isEmpty ? nil : words.high
                changed.low = words.low.isEmpty ? nil : words.low
                changed.buffalo = words.buffalo.isEmpty ? nil : words.buffalo
                changed.wordsPhoto = words.photo
                changed.wordsArt = storyArt(words)
                guard changed != story else { continue }
                storiesByCrew[crewID]?.removeAll { $0.id == story.id }
                storiesByCrew[crewID]?.append(changed)
                enqueue(.init(crew: crewID, type: .story, name: story.id.uuidString, fields: CrewRecords.fields(changed)))
            }
        }
        nudgeLive()
        await flush()
        return .sent
    }

    /// **The page's picture goes when a photograph in its strip does** (the
    /// review, 2026-10-16: a photo taken off a story win comes off the story
    /// too). Called as a win is withdrawn or loses its photo.
    func dropStoryArt(holding winID: UUID) {
        var all = (defaults.data(forKey: Self.storyWordsKey)).flatMap { try? JSONDecoder().decode([String: StoryWords].self, from: $0) } ?? [:]
        for (day, words) in all where words.art != nil && (words.artWins ?? []).contains(winID) {
            var dropped = words
            dropped.art = nil
            dropped.artChecked = nil
            dropped.artWins = nil
            all[day] = dropped
            for (crewID, stories) in storiesByCrew {
                for story in stories where story.sender == me && story.day == day && story.wordsArt != nil {
                    var changed = story
                    changed.wordsArt = nil
                    storiesByCrew[crewID]?.removeAll { $0.id == story.id }
                    storiesByCrew[crewID]?.append(changed)
                    enqueue(.init(crew: crewID, type: .story, name: story.id.uuidString, fields: CrewRecords.fields(changed)))
                }
            }
        }
        defaults.set(try? JSONEncoder().encode(all), forKey: Self.storyWordsKey)
    }
}
