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
        store.myPhoto = { ProfileStore.shared.photo?.jpegData(compressionQuality: 0.85) }
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
    /// Bumped whenever `outbox` changes, so a block's back can say "Not sent
    /// yet" and stop saying it.
    private(set) var outboxRevision = 0
    private(set) var isRefreshing = false

    let cloud: CrewCloud
    private let defaults: UserDefaults
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
    /// Your head, packed to send, or nil for no head.
    @ObservationIgnored var myHeadPack: () async -> Data? = { nil }
    /// **The photo check, for a head** (2026-10-08): every face in the pack
    /// passes `CrewSafety.photoIsFine` or the head is not sent. A head is cut
    /// out of a photograph, and it went to crews unchecked.
    @ObservationIgnored var headCheck: (Data) async -> Bool = { _ in true }
    /// Your profile photograph as JPEG, or nil.
    @ObservationIgnored var myPhoto: () -> Data? = { nil }
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
    private func derived(_ jpeg: Data) async -> Data? {
        let make = derive
        return await Task.detached(priority: .userInitiated) { make(jpeg) }.value
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
            // First seen (a phone updated from before this was kept): the
            // crews on it are this account's.
            guard let was, was != who else { return }
        case .signedOut:
            defaults.removeObject(forKey: Self.accountKey)
        }
        cloud.reset()
        for crew in crews { forget(crew.id) }
        crews = []
        winsByCrew = [:]
        reactionsByCrew = [:]
        messagesByCrew = [:]
        unreadChats = []
        outbox = CrewOutbox()
        persistOutbox()
        sent = [:]
        try? FileManager.default.removeItem(at: directory)
        await refresh()
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
            for reaction in reactions where reaction.profileID != me && reaction.isSticker {
                guard let sticker = reaction.sketch, photoVerdicts[sticker.lastPathComponent] == nil,
                      let data = try? Data(contentsOf: sticker),
                      let verdict = await incomingCheck(data) else { continue }
                photoVerdicts[sticker.lastPathComponent] = verdict
                changed = true
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

    func createCrew(name: String, photoJPEG: Data? = nil) async throws -> (crew: Crew, invite: URL) {
        try requireOn()
        guard joinGate() == .open else { throw CrewError.notReady }
        await cloud.prepare()
        guard crews.count < CrewCaps.crews else { throw CrewError.tooManyCrews }
        // The photo first, so a refused one stops the crew before its zone
        // exists. 13 to 15 send no photos and start crews with faces.
        var picture: Data?
        if photosAllowed() {
            if let photoJPEG {
                guard let small = await derived(photoJPEG), await photoCheck(small) else { throw CrewError.photoNotAllowed }
                picture = small
            } else if requiresCrewPhoto {
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
                        members: [CrewMember(profileID: me, firstName: myFirstName(), head: nil, joinedAt: now)])
        if let picture {
            let file = directory.appending(path: "Photos/\(crew.id.rawValue)/crew-\(UUID().uuidString).jpg")
            try write(picture, to: file)
            crew.photo = file
        }
        let url = try await cloud.createZone(crew)
        try await cloud.save(CrewRecords.fields(crew), type: .crew, name: CrewRecords.crewRecordName, in: crew.id)
        try await cloud.save(CrewRecords.fields(crew.members[0]), type: .member,
                             name: CrewRecords.name(of: crew.members[0]), in: crew.id)
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
    func accept(_ invite: CrewInvite) async throws -> Crew {
        try requireOn()
        guard joinGate() == .open else { throw CrewError.notReady }
        if crews.isEmpty { await refresh() }
        guard crews.count < CrewCaps.crews else { throw CrewError.tooManyCrews }
        let id = try await cloud.accept(invite)
        let fetched = try await cloud.fetchCrews()
        guard let crew = fetched.first(where: { $0.id == id }) else { throw CrewError.unknownCrew }
        // Accepting is where the second check happens: eight people were
        // already in it when the link was opened.
        guard crew.members.filter({ $0.profileID != me }).count < CrewCaps.members else {
            try? await cloud.leave(id)
            throw CrewError.crewFull
        }
        let member = CrewMember(profileID: me, firstName: myFirstName(), head: nil, joinedAt: now())
        try await cloud.save(CrewRecords.fields(member), type: .member, name: CrewRecords.name(of: member), in: id)
        await refresh()
        await shareMyself()
        if announces { await CrewNotifications.askOnce() }
        Analytics.shared.signal(.crewJoined)
        return self.crew(id) ?? crew
    }

    func rename(_ crewID: CrewID, to name: String) async throws {
        try requireOn()
        guard var crew = crew(crewID) else { throw CrewError.unknownCrew }
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

    /// You, as your crews see you: your head, and your profile photo for
    /// when there is no head (never under 16). Called on starting or joining
    /// a crew and whenever either changes.
    func shareMyself() async {
        guard isEnabled() else { return }
        var photo: Data?
        let source = photosAllowed() ? myPhoto() : nil
        if let source, let small = await derived(source) {
            // Your own picture goes through the same check as a win's
            // photograph (the 2026-10-03 audit: it went unchecked).
            photo = await photoCheck(small) ? small : nil
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
        await setMyHead(sent, photo: photo)
        defaults.set(selfDigest(pack: pack, photo: source), forKey: Self.sentSelfKey)
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
        let source = photosAllowed() ? myPhoto() : nil
        let pack = await headToSend()
        let digest = selfDigest(pack: pack, photo: source)
        // A head the check held back is missing on purpose.
        let heldBack = pack.map { Self.digest($0) == defaults.string(forKey: Self.heldHeadKey) } ?? false
        let mineMissingHead = pack != nil && !heldBack && crews.contains { $0.member(me).map { $0.head == nil } ?? false }
        guard digest != defaults.string(forKey: Self.sentSelfKey) || mineMissingHead else { return }
        await shareMyself()
    }

    @ObservationIgnored var checkedSelf = false
    static let sentSelfKey = "crews.sentSelf"

    private func selfDigest(pack: Data?, photo: Data?) -> String {
        var hasher = SHA256()
        hasher.update(data: pack ?? Data())
        hasher.update(data: Data([0]))
        hasher.update(data: photo ?? Data())
        hasher.update(data: Data(myFirstName().utf8))
        hasher.update(data: Data(crews.map(\.id.rawValue).sorted().joined(separator: ",").utf8))
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

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
        try await cloud.delete(type: .member, name: me.uuidString, in: crewID)
        try await cloud.leave(crewID)
        forget(crewID)
    }

    /// Ends a crew you started, for everyone.
    func end(_ crewID: CrewID) async throws {
        try requireOn()
        guard let crew = crew(crewID) else { throw CrewError.unknownCrew }
        guard crew.isOwner(me) else { throw CrewError.notOwner }
        try await cloud.endCrew(crewID)
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
        // Their wins and reactions leave with them, from the crew's own
        // zone: the owner may delete anything in it.
        for win in winsByCrew[crewID] ?? [] where win.senderProfileID == profileID {
            enqueue(.init(crew: crewID, type: .sharedWin, name: CrewRecords.name(of: win), fields: nil))
        }
        for reaction in reactionsByCrew[crewID] ?? [] where reaction.profileID == profileID {
            enqueue(.init(crew: crewID, type: .reaction, name: reaction.id, fields: nil))
        }
        for message in messagesByCrew[crewID] ?? [] where message.senderProfileID == profileID {
            enqueue(.init(crew: crewID, type: .message, name: CrewRecords.name(of: message), fields: nil))
        }
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
        for crewID in chosen {
            guard let crew = crew(crewID) else { continue }
            let shared = sharedWin(win, in: crew, photo: photo.flatMap { copy($0, to: crewID, win: win.winID) })
            upsertLocal(shared)
            enqueue(.init(crew: crewID, type: .sharedWin, name: CrewRecords.name(of: shared), fields: CrewRecords.fields(shared)))
        }
        record(win, in: chosen.filter { crew($0) != nil })
        nudgeLive()
        await flush()
    }

    /// An edit: every copy changes, in every crew it is in. An edit that
    /// changed nothing a crew sees (a save that only touched a note, say)
    /// sends nothing.
    func update(_ win: OwnWin) async {
        guard isEnabled() else { return }
        let holding = crews(holding: win.winID)
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
        for crewID in crews(holding: winID) {
            winsByCrew[crewID]?.removeAll { $0.winID == winID }
            enqueue(.init(crew: crewID, type: .sharedWin, name: winID.uuidString, fields: nil))
        }
        unrecord(winID)
        await flush()
    }

    /// Removing a photograph removes it from every copy. The win stays: the
    /// photo removal rule (CLAUDE.md) is that a photo is never the win.
    func removePhotoEverywhere(winID: UUID) async {
        guard isEnabled() else { return }
        for crewID in crews(holding: winID) {
            guard var shared = winsByCrew[crewID]?.first(where: { $0.winID == winID }) else { continue }
            if let photo = shared.photo { try? FileManager.default.removeItem(at: photo) }
            shared.photo = nil
            shared.updatedAt = now()
            upsertLocal(shared)
            enqueue(.init(crew: crewID, type: .sharedWin, name: winID.uuidString, fields: CrewRecords.fields(shared)))
        }
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
    private func paced(_ kind: CrewSendThrottle.Kind, in crew: Crew) -> ReplyOutcome? {
        guard throttles else { return nil }
        let day = CrewDay.string(for: now(), in: crew.timeZone)
        switch throttle.verdict(kind, crew: crew.id.rawValue, day: day, at: now()) {
        case .tooFast: return .throttled
        case .dailyLimit: return .dailyLimit
        case .allowed:
            throttle.record(kind, crew: crew.id.rawValue, day: day, at: now())
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
        let people = Set(crew.members.map(\.profileID))
        return (messagesByCrew[crewID] ?? [])
            .filter { message in
                // A drawing thrown onto the tower is not a line in the chat
                // (`CrewMessage.isToss`): the tower shows it (`tosses(in:)`),
                // and so nothing that reads this list (the chat, its dot,
                // its alerts, a line's reactions) ever meets one.
                !message.isToss
                    && message.crewDay == today && people.contains(message.senderProfileID)
                    && !blocked.contains(message.senderProfileID)
                    && (message.text.isEmpty || CrewWords.isAcceptable(message.text))
                    && (message.senderProfileID == me || message.sketch.map(photoIsShown) ?? true)
            }
            .sorted { ($0.createdAt, $0.messageID.uuidString) < ($1.createdAt, $1.messageID.uuidString) }
    }

    /// **A line in the crew's chat.** Words only, up to 280, checked here
    /// first (`CrewWords`); `quoting` a win in this crew makes it a reply
    /// to it. It clears when the crew's day ends (`prune`).
    @discardableResult
    func send(_ text: String, in crewID: CrewID, quoting winID: UUID? = nil) async -> ReplyOutcome {
        let words = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(CrewMessage.textLimit))
        guard canReply(), isEnabled(), let crew = crew(crewID), !words.isEmpty else { return .notAllowed }
        if let winID, !(winsByCrew[crewID] ?? []).contains(where: { $0.winID == winID }) { return .notAllowed }
        guard CrewWords.isAcceptable(words) else { return .refusedWords }
        if let held = paced(.message, in: crew) { return held }
        Analytics.shared.signal(.crewMessageSent)
        let message = CrewMessage(messageID: UUID(), crewID: crewID, senderProfileID: me,
                                  crewDay: CrewDay.string(for: now(), in: crew.timeZone), text: words,
                                  quoteWinID: winID, createdAt: now())
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
        await sendSketch(png, text: "", in: crewID, quoting: winID, paced: true)
    }

    /// A doodle with `text` beside it: none for the chat's, the marker for a
    /// toss. The gate, the photo check and the file are the same for both.
    /// `paced`: counted against `CrewSendThrottle`. A toss is not: it is
    /// one a day already.
    private func sendSketch(_ png: Data, text: String, in crewID: CrewID, quoting winID: UUID?,
                            paced isPaced: Bool) async -> ReplyOutcome {
        guard canReply(), isEnabled(), let crew = crew(crewID), !png.isEmpty else { return .notAllowed }
        if let winID, !(winsByCrew[crewID] ?? []).contains(where: { $0.winID == winID }) { return .notAllowed }
        if isPaced, let held = paced(.message, in: crew) { return held }
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

    // MARK: Drawings on the tower

    /// **Today's drawings on a crew's tower**: one a person (`CrewTosses`),
    /// today's in the crew's zone, from people in the crew, nobody you
    /// blocked, and a friend's only once this phone's photo check has passed
    /// it, exactly as a doodle in the chat is. Midnight is the filter: the
    /// day ends and the list is empty, before anyone has deleted anything.
    func tosses(in crewID: CrewID) -> [CrewMessage] {
        guard let crew = crew(crewID) else { return [] }
        let today = CrewDay.string(for: now(), in: crew.timeZone)
        let people = Set(crew.members.map(\.profileID))
        return CrewTosses.oneEach((messagesByCrew[crewID] ?? []).filter { message in
            message.isToss && message.crewDay == today && people.contains(message.senderProfileID)
                && !blocked.contains(message.senderProfileID)
                && (message.senderProfileID == me || message.sketch.map(photoIsShown) ?? false)
        })
    }

    /// Your drawing on this crew's tower today, if you threw one. Read from
    /// everything held, not from `tosses(in:)`: one the check has not passed
    /// on a friend's phone is still yours, and still today's one.
    func myToss(in crewID: CrewID) -> CrewMessage? {
        guard let crew = crew(crewID) else { return nil }
        let today = CrewDay.string(for: now(), in: crew.timeZone)
        return CrewTosses.oneEach((messagesByCrew[crewID] ?? []).filter {
            $0.senderProfileID == me && $0.crewDay == today
        }).first
    }

    /// **Throws today's drawing onto a crew's tower**: a doodle in the
    /// crew's chat transport, marked (`CrewMessage.tossMarker`). One a day
    /// per crew; a second is refused here, before anything is written. The
    /// same gate as the chat (`canReply`) and the same photo check both ways.
    @discardableResult
    func toss(_ png: Data, in crewID: CrewID) async -> ReplyOutcome {
        guard myToss(in: crewID) == nil else { return .notAllowed }
        return await sendSketch(png, text: CrewMessage.tossMarker, in: crewID, quoting: nil, paced: false)
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
    func reply(_ line: String, to winID: UUID, in crewID: CrewID) async -> ReplyOutcome {
        guard let win = winsByCrew[crewID]?.first(where: { $0.winID == winID }),
              win.senderProfileID != me else { return .notAllowed }
        return await send(line, in: crewID, quoting: winID)
    }

    /// **Doodle, on a friend's win**: a doodle in the crew's chat that
    /// quotes it. The same gate as a reply, and the photo check both ways.
    @discardableResult
    func doodle(_ png: Data, to winID: UUID, in crewID: CrewID) async -> ReplyOutcome {
        guard let win = winsByCrew[crewID]?.first(where: { $0.winID == winID }),
              win.senderProfileID != me else { return .notAllowed }
        return await sendDoodle(png, in: crewID, quoting: winID)
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
        let theirLines = lines.filter { $0.senderProfileID != me }.map(\.messageID.uuidString)
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
        guard isEnabled(), let crew = crew(crewID),
              let win = winsByCrew[crewID]?.first(where: { $0.winID == winID }),
              win.senderProfileID != me else { return }
        // Too fast is dropped quietly: the reaction already showing stays.
        guard paced(.reaction, in: crew) == nil else { return }
        Analytics.shared.signal(.crewReaction)
        let name = Reaction.name(winID: winID, profileID: me)
        var list = reactionsByCrew[crewID] ?? []
        let previous = list.first { $0.id == name }
        if let previous, previous.emoji == emoji, previous.line != nil, isToday(previous.createdAt, in: crewID) {
            return
        }
        list.removeAll { $0.id == name }
        if previous?.emoji == emoji {
            reactionsByCrew[crewID] = list
            enqueue(.init(crew: crewID, type: .reaction, name: name, fields: nil))
        } else {
            var reaction = Reaction(winID: winID, crewID: crewID, profileID: me, emoji: emoji, createdAt: now())
            // A new emoji keeps today's reply and doodle under it.
            if let previous, isToday(previous.createdAt, in: crewID) {
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
        guard isEnabled(), let crew = crew(crewID),
              let line = messages(in: crewID).first(where: { $0.messageID == messageID }),
              line.senderProfileID != me else { return .notAllowed }
        let name = Reaction.name(winID: messageID, profileID: me)
        let mark = pick.mark
        guard !mark.isEmpty else { return .notAllowed }
        if let held = paced(.reaction, in: crew) { return held }
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
    }

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
        return Held(wins: wins,
                    reactions: reactions.filter { people.contains($0.profileID) }.sorted { $0.id < $1.id },
                    messages: messages.filter { people.contains($0.senderProfileID) }
                        .sorted { ($0.createdAt, $0.messageID.uuidString) < ($1.createdAt, $1.messageID.uuidString) })
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
        let crew = withEdits(Self.ordered(fetched))
        let held = await held(in: crew)
        // Read again after the awaits: the list may have moved meanwhile.
        guard let i = crews.firstIndex(where: { $0.id == crewID }) else { return false }
        if crews[i] != crew { crews[i] = crew }
        let wins = held.wins ?? winsByCrew[crewID] ?? []
        if winsByCrew[crewID] != wins { winsByCrew[crewID] = wins }
        if reactionsByCrew[crewID] != held.reactions { reactionsByCrew[crewID] = held.reactions }
        if messagesByCrew[crewID] != held.messages { messagesByCrew[crewID] = held.messages }
        if let counted = held.wins { recordHistory([crewID: counted], for: [crew]) }
        recomputeUnread()
        prune()
        return true
    }

    private func refreshOnce() async {
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
            for crew in fetched {
                let held = await held(in: crew)
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
            let known = Set(fetched.map(\.id)).union(fresh)
            for gone in Set(outbox.entries.map(\.crew)).subtracting(known) { outbox.drop(crew: gone) }
            for gone in Set(crews.map(\.id)).subtracting(known) { forget(gone) }
            let merged = fetched.map(withEdits)
            if crews != merged { crews = merged }
            if winsByCrew != wins { winsByCrew = wins }
            if reactionsByCrew != reactions { reactionsByCrew = reactions }
            if messagesByCrew != messages { messagesByCrew = messages }
            recordHistory(counted, for: fetched)
            for gone in CrewChoice.load(defaults).subtracting(known) { CrewChoice.forget(gone, defaults) }
            recomputeUnread()
            prune()
        } catch {
            Self.log.error("fetching crews failed: \(error)")
            noteBackoff(error)
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
    static let fullWords = "The crew's iCloud is full, so new wins wait to send."
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
            let live = Set((winsByCrew[crew.id] ?? []).filter { $0.crewDay >= cutoff }.map(\.winID))
                .union((messagesByCrew[crew.id] ?? []).filter { $0.crewDay >= today }.map(\.messageID))
            let orphans = (reactionsByCrew[crew.id] ?? []).filter { !live.contains($0.winID) }
            if !orphans.isEmpty, winsByCrew[crew.id] != nil {
                reactionsByCrew[crew.id]?.removeAll { !live.contains($0.winID) }
                for reaction in orphans where reaction.profileID == me {
                    if reaction.isSticker, let sticker = reaction.sketch { try? FileManager.default.removeItem(at: sticker) }
                    enqueue(.init(crew: crew.id, type: .reaction, name: reaction.id, fields: nil))
                }
            }
            // **Old replies and doodles clear when the day ends.** Nothing
            // writes them on a reaction any more (they are chat messages
            // now), but a record from an older build may still carry one.
            // Only the writer's phone may change a reaction record, so each
            // phone clears its own; no screen shows them.
            for (index, reaction) in (reactionsByCrew[crew.id] ?? []).enumerated()
            where reaction.profileID == me && !reaction.isSticker && (reaction.line != nil || reaction.sketch != nil)
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
            let ended = (messagesByCrew[crew.id] ?? []).filter { $0.crewDay < today }
            if !ended.isEmpty {
                messagesByCrew[crew.id]?.removeAll { $0.crewDay < today }
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

    // MARK: Heads, per crew

    /// Crews whose heads you have switched off: the tower shows only its
    /// wins and the bubble only the crew's picture (the owner, 2026-10-03:
    /// "a way to shut off the heads for individual crew chats"). Yours
    /// alone, never sent.
    private(set) var headsHidden: Set<CrewID> = Set(
        (UserDefaults.standard.stringArray(forKey: SocialStore.headsHiddenKey) ?? []).map(CrewID.init(rawValue:)))
    static let headsHiddenKey = "crews.headsHidden"

    func showsHeads(_ crewID: CrewID) -> Bool { !headsHidden.contains(crewID) }

    func setShowsHeads(_ on: Bool, for crewID: CrewID) {
        if on { headsHidden.remove(crewID) } else { headsHidden.insert(crewID) }
        UserDefaults.standard.set(headsHidden.map(\.rawValue).sorted(), forKey: Self.headsHiddenKey)
    }

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

    /// Tells iCloud the plan when it has changed since it last heard it. A
    /// timed mute ending is a change too, so every refresh asks.
    func listenForPings() async {
        guard sendsPings, !crews.isEmpty || defaults.data(forKey: Self.planKey) != nil else { return }
        let plan = pingPlan()
        let told = defaults.data(forKey: Self.planKey).flatMap { try? JSONDecoder().decode(CrewPingPlan.self, from: $0) }
        guard plan != told else { return }
        do {
            try await cloud.listen(for: plan)
            defaults.set(try? JSONEncoder().encode(plan), forKey: Self.planKey)
        } catch {
            // Before the Ping type is in iCloud, or offline: the app's own
            // notifications carry on, and the next refresh asks again.
            Self.log.notice("ping subscriptions not saved: \(error)")
        }
    }

    private func replan() {
        guard sendsPings else { return }
        Task { await listenForPings() }
    }

    /// After a win or a reaction reaches the crew: one ping, the first time
    /// only. An edit to a win, or a changed emoji, is not news.
    private func pingIfNew(_ type: CrewRecordType, _ fields: RecordFields, in crewID: CrewID) async {
        guard sendsPings, let winID = fields["winID"]?.uuid else { return }
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
            key = "win-\(winID.uuidString)"
        case .reaction:
            guard let owner = winsByCrew[crewID]?.first(where: { $0.winID == winID })?.senderProfileID,
                  owner != me else { return }
            ping[CrewPingRecord.kind] = CrewPingRecord.Kind.reaction.rawValue
            ping[CrewPingRecord.recipient] = CrewPingRecord.tag(owner.uuidString)
            key = Self.pingKey(winID: winID, carriesLine: fields["line"]?.string.map { !$0.isEmpty } ?? false)
        // **The chat leaves no ping.** Its alerts are the app's own, at most
        // one a crew an hour (`CrewNotifications.announceMessages`, which
        // for that reason is not gated on `pingsLive`); a ping would need
        // its own kind and subscription.
        case .crew, .member, .message:
            return
        }
        let done = defaults.dictionary(forKey: Self.pingedKey) as? [String: Double] ?? [:]
        guard done[key] == nil, !pendingPings.contains(where: { $0.key == key }) else { return }
        do {
            try await sendPing(ping, key: key)
        } catch {
            Self.log.notice("ping not sent: \(error)")
            // No signal or a busy server says nothing about the ping: it is
            // kept and tried again (`CrewPingRetry`). Anything else is not.
            guard let server = Self.transientWait(error),
                  let wait = CrewPingRetry.wait(afterAttempts: 1, serverSays: server) else { return }
            let at = now().timeIntervalSince1970
            var pending = pendingPings
            pending.append(CrewPingRetry(key: key, fields: ping, attempts: 1, notBefore: at + wait, firstTried: at))
            pendingPings = pending
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
                joined: zone.joined, members: members, myWins: mine)
        }
        return CrewNoteCache(me: me.uuidString, crews: out)
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
        defaults.set(mine, forKey: table.rawValue)
        guard let choicesCloud else { return }
        let remote = choicesCloud.dictionary(forKey: table.rawValue) as? CrewChoicesSync.Entries ?? [:]
        choicesCloud.set(CrewChoicesSync.merge(mine, remote), forKey: table.rawValue)
    }

    /// What your other phones chose, merged with this one's, newest first,
    /// and put into effect. At launch and whenever iCloud says it changed.
    func pullChoices() {
        adoptChoicesMadeBeforeSync()
        for table in CrewChoicesSync.Table.allCases {
            let remote = choicesCloud?.dictionary(forKey: table.rawValue) as? CrewChoicesSync.Entries ?? [:]
            let merged = CrewChoicesSync.merge(entries(table), remote)
            defaults.set(merged, forKey: table.rawValue)
            if let choicesCloud, CrewChoicesSync.isAhead(merged, of: remote) {
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
        if let wins = winsByCrew.removeValue(forKey: crewID) {
            for photo in wins.compactMap(\.photo) { try? FileManager.default.removeItem(at: photo) }
        }
        reactionsByCrew[crewID] = nil
        messagesByCrew[crewID] = nil
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
        guard photosAllowed(), let jpeg = win.photoJPEG, let small = await derived(jpeg) else { return nil }
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
    private func copy(_ data: Data, to crewID: CrewID, win: UUID) -> URL? {
        let url = directory.appending(
            path: "Photos/\(crewID.rawValue)/\(win.uuidString)-\(UUID().uuidString.prefix(8)).jpg")
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
