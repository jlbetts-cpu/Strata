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
        store.announces = true
        // Off until the notification extension ships with it: its app ID
        // has to be linked to the iCloud container and the app group in the
        // developer portal first. Without the extension a ping's alert would
        // say only "A friend added a win", and the app's own, better
        // notifications would stand down for it.
        store.sendsPings = false
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
        store.myPhoto = { ProfileStore.shared.photo?.jpegData(compressionQuality: 0.85) }
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
    /// Crews holding a friend's win you have not looked at.
    private(set) var unread: Set<CrewID> = []
    /// Bumped whenever `outbox` changes, so a block's back can say "Not sent
    /// yet" and stop saying it.
    private(set) var outboxRevision = 0
    private(set) var isRefreshing = false

    let cloud: CrewCloud
    private let defaults: UserDefaults
    let directory: URL
    @ObservationIgnored private var outbox: CrewOutbox

    /// Whether crews are on. Injected so a test can prove "off" touches
    /// nothing.
    @ObservationIgnored var isEnabled: () -> Bool = { CrewsFlag.isOn }
    /// Whether this person may send photographs (13 to 15 may not; spec 9.1).
    @ObservationIgnored var photosAllowed: () -> Bool = { true }
    /// What you called yourself, for your Member record.
    @ObservationIgnored var myFirstName: () -> String = { "" }
    /// Your head, packed to send, or nil for no head.
    @ObservationIgnored var myHeadPack: () async -> Data? = { nil }
    /// Your profile photograph as JPEG, or nil.
    @ObservationIgnored var myPhoto: () -> Data? = { nil }
    /// A crew must start with a photo (the owner, 2026-10-02). Off in tests
    /// that are about something else.
    @ObservationIgnored var requiresCrewPhoto = false
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
    func accept(_ invite: CrewInvite) async throws -> Crew {
        try requireOn()
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
        let pack = await myHeadPack()
        await setMyHead(pack, photo: photo)
        defaults.set(selfDigest(pack: pack, photo: source), forKey: Self.sentSelfKey)
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
        let pack = await myHeadPack()
        let digest = selfDigest(pack: pack, photo: source)
        let mineMissingHead = pack != nil && crews.contains { $0.member(me).map { $0.head == nil } ?? false }
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
        winsByCrew[crewID]?.removeAll { $0.senderProfileID == profileID }
        reactionsByCrew[crewID]?.removeAll { $0.profileID == profileID }
        await flush()
    }

    // MARK: Wins

    /// Sends a win to the crews chosen for it. Nothing is asked: the choice
    /// was made on the checkboxes, or is the one you made last time.
    func post(_ win: OwnWin, to chosen: Set<CrewID>) async {
        guard isEnabled() else { return }
        let photo = await checkedPhoto(for: win)
        for crewID in chosen {
            guard let crew = crew(crewID) else { continue }
            let shared = sharedWin(win, in: crew, photo: photo.flatMap { copy($0, to: crewID, win: win.winID) })
            upsertLocal(shared)
            enqueue(.init(crew: crewID, type: .sharedWin, name: CrewRecords.name(of: shared), fields: CrewRecords.fields(shared)))
        }
        record(win, in: chosen.filter { crew($0) != nil })
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
        let photo = await checkedPhoto(for: win)
        for crewID in holding {
            guard let crew = crew(crewID) else { continue }
            let existing = winsByCrew[crewID]?.first { $0.winID == win.winID }
            var shared = sharedWin(win, in: crew, photo: photo.flatMap { copy($0, to: crewID, win: win.winID) })
            // A win stays in the day it was first sent to.
            if let existing { shared.crewDay = existing.crewDay }
            upsertLocal(shared)
            enqueue(.init(crew: crewID, type: .sharedWin, name: CrewRecords.name(of: shared), fields: CrewRecords.fields(shared)))
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

    func myReaction(to winID: UUID, in crewID: CrewID) -> String? {
        reactionsByCrew[crewID]?.first { $0.winID == winID && $0.profileID == me }?.emoji
    }

    /// React to a win, the way a Tapback works: a new emoji replaces yours,
    /// the same one again takes it back. Your own wins take no reactions
    /// from you.
    func react(_ emoji: String, to winID: UUID, in crewID: CrewID) async {
        guard isEnabled(), crew(crewID) != nil,
              let win = winsByCrew[crewID]?.first(where: { $0.winID == winID }),
              win.senderProfileID != me else { return }
        let name = Reaction.name(winID: winID, profileID: me)
        var list = reactionsByCrew[crewID] ?? []
        let previous = list.first { $0.id == name }
        list.removeAll { $0.id == name }
        if previous?.emoji == emoji {
            reactionsByCrew[crewID] = list
            enqueue(.init(crew: crewID, type: .reaction, name: name, fields: nil))
        } else {
            let reaction = Reaction(winID: winID, crewID: crewID, profileID: me, emoji: emoji, createdAt: now())
            list.append(reaction)
            reactionsByCrew[crewID] = list
            enqueue(.init(crew: crewID, type: .reaction, name: name, fields: CrewRecords.fields(reaction)))
        }
        await flush()
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
            await deleteOldPings()
        }
        if announces {
            await CrewNotifications.announce(self)
            await CrewNotifications.announceReactions(self)
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
    func refreshLive(_ crewID: CrewID) async {
        guard isEnabled(), !isRefreshing else { return }
        await flush()
        do {
            if try await cloud.syncOnly(crewID) { await refresh() }
        } catch {
            Self.log.error("live sync of \(crewID.rawValue, privacy: .public) failed: \(error)")
        }
    }

    /// Whether this store says what is new as notifications. The phone's own
    /// store does; a test's or a debug friend's never does.
    @ObservationIgnored var announces = false

    @ObservationIgnored private var refreshAgain = false
    /// Crews whose name or picture is being saved right now.
    @ObservationIgnored private var editing: [CrewID: Crew] = [:]

    private func refreshOnce() async {
        await cloud.prepare()
        // Who the crews belong to, kept before any change can be announced.
        if defaults.string(forKey: Self.accountKey) == nil, case .signedIn(let who) = await cloud.account() {
            defaults.set(who, forKey: Self.accountKey)
        }
        await flush()
        do {
            // **In a fixed order**, members, wins and reactions alike. A
            // fetch hands them back in dictionary order, so an unchanged crew
            // compared as changed on every refresh and the whole crew screen
            // redrew: a 96ms hitch every 15 seconds with nobody posting
            // (measured with `-strataPerfProbe`, 2026-10-02).
            let fetched = try await cloud.fetchCrews().map { crew -> Crew in
                var crew = crew
                crew.members.sort { ($0.joinedAt, $0.profileID.uuidString) < ($1.joinedAt, $1.profileID.uuidString) }
                return crew
            }
            var wins: [CrewID: [SharedWin]] = [:]
            var counted: [CrewID: [SharedWin]] = [:]
            for crew in fetched {
                do {
                    var held = try await cloud.fetchWins(in: crew.id)
                    // A write of ours still on its way wins over what the
                    // cloud has: it is newer.
                    for entry in outbox.entries where entry.crew == crew.id && entry.type == .sharedWin {
                        held.removeAll { $0.winID.uuidString == entry.name }
                        if let fields = entry.fields, let mine = CrewRecords.sharedWin(fields, crew: crew.id) {
                            held.append(mine)
                        }
                    }
                    // Only people in the crew: someone removed is gone with
                    // their wins, whoever's phone had not yet deleted them
                    // (the 2026-10-03 audit: they came back as "A friend").
                    let people = Set(crew.members.map(\.profileID))
                    wins[crew.id] = held.filter { people.contains($0.senderProfileID) }
                        .sorted { ($0.createdAt, $0.winID.uuidString) < ($1.createdAt, $1.winID.uuidString) }
                    counted[crew.id] = wins[crew.id]
                } catch {
                    Self.log.error("fetching wins in \(crew.id.rawValue, privacy: .public) failed: \(error)")
                    wins[crew.id] = winsByCrew[crew.id] ?? []
                }
            }
            var reactions: [CrewID: [Reaction]] = [:]
            for crew in fetched {
                var held = (try? await cloud.fetchReactions(in: crew.id)) ?? reactionsByCrew[crew.id] ?? []
                for entry in outbox.entries where entry.crew == crew.id && entry.type == .reaction {
                    held.removeAll { $0.id == entry.name }
                    if let fields = entry.fields, let mine = CrewRecords.reaction(fields, crew: crew.id) { held.append(mine) }
                }
                let people = Set(crew.members.map(\.profileID))
                reactions[crew.id] = held.filter { people.contains($0.profileID) }.sorted { $0.id < $1.id }
            }
            // Writes for crews that are gone (ended, or you were removed) can
            // never be sent: drop them rather than retry them for ever.
            // A crew made in the last minute may not be in a fetch that began
            // before it existed: never forget one of those.
            let fresh = Set(crews.filter { now().timeIntervalSince($0.createdAt) < 60 }.map(\.id))
            let known = Set(fetched.map(\.id)).union(fresh)
            for gone in Set(outbox.entries.map(\.crew)).subtracting(known) { outbox.drop(crew: gone) }
            for gone in Set(crews.map(\.id)).subtracting(known) { forget(gone) }
            // A name or picture still being saved wins over what was fetched.
            let merged = fetched.map { crew -> Crew in
                guard let edit = editing[crew.id] else { return crew }
                var crew = crew
                crew.name = edit.name
                crew.photo = edit.photo
                return crew
            }
            if crews != merged { crews = merged }
            if winsByCrew != wins { winsByCrew = wins }
            if reactionsByCrew != reactions { reactionsByCrew = reactions }
            recordHistory(counted, for: fetched)
            for gone in CrewChoice.load(defaults).subtracting(known) { CrewChoice.forget(gone, defaults) }
            recomputeUnread()
            prune()
        } catch {
            Self.log.error("fetching crews failed: \(error)")
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
                do {
                    if let fields = entry.fields {
                        try await cloud.save(fields, type: entry.type, name: entry.name, in: entry.crew)
                        await pingIfNew(entry.type, fields, in: entry.crew)
                    } else {
                        try await cloud.delete(type: entry.type, name: entry.name, in: entry.crew)
                    }
                    outbox.removeIfUnchanged(entry)
                } catch {
                    Self.log.error("\(entry.type.rawValue, privacy: .public) to \(entry.crew.rawValue, privacy: .public) not sent: \(error)")
                    // **No signal is not a failure** (the 2026-10-03 audit). A
                    // dropped connection, a busy server or a rate limit says
                    // nothing about the write, and counting them gave up on
                    // a win posted offline after about a minute of the live
                    // sync's retries. Those wait, for as long as CloudKit
                    // asks, and the rest of the queue waits with them.
                    if let wait = Self.transientWait(error) {
                        retryAfter = now().addingTimeInterval(wait)
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
            let live = Set((winsByCrew[crew.id] ?? []).filter { $0.crewDay >= cutoff }.map(\.winID))
            let orphans = (reactionsByCrew[crew.id] ?? []).filter { !live.contains($0.winID) }
            if !orphans.isEmpty, winsByCrew[crew.id] != nil {
                reactionsByCrew[crew.id]?.removeAll { !live.contains($0.winID) }
                for reaction in orphans where reaction.profileID == me {
                    enqueue(.init(crew: crew.id, type: .reaction, name: reaction.id, fields: nil))
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
        let count = unread.count
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
            key = "reaction-\(winID.uuidString)"
        case .crew, .member:
            return
        }
        var done = defaults.dictionary(forKey: Self.pingedKey) as? [String: Double] ?? [:]
        guard done[key] == nil else { return }
        do {
            let name = try await cloud.ping(ping)
            done[key] = now().timeIntervalSince1970
            defaults.set(done, forKey: Self.pingedKey)
            var sent = defaults.dictionary(forKey: Self.sentPingsKey) as? [String: Double] ?? [:]
            sent[name] = now().timeIntervalSince1970
            defaults.set(sent, forKey: Self.sentPingsKey)
        } catch {
            Self.log.notice("ping not sent: \(error)")
        }
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
    private func copy(_ data: Data, to crewID: CrewID, win: UUID) -> URL? {
        let url = directory.appending(path: "Photos/\(crewID.rawValue)/\(win.uuidString).jpg")
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
        SharedWin(winID: win.winID,
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
                  updatedAt: win.updatedAt)
    }
}
