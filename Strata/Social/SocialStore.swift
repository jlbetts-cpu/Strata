import Foundation
import Observation
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
        let cloud = makeCloud()
        return SocialStore(cloud: cloud, defaults: .standard, directory: defaultDirectory)
    }()

    /// Replaced by the CloudKit adapter at launch (Task 3) and by the debug
    /// seed. A fake until then, so nothing can reach the network by accident.
    static var makeCloud: () -> CrewCloud = { FakeCrewCloud(me: ProfileStore.profileID) }

    static var defaultDirectory: URL {
        (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory)
            .appending(path: "Crews", directoryHint: .isDirectory)
    }

    // MARK: State

    private(set) var crews: [Crew] = []
    private(set) var winsByCrew: [CrewID: [SharedWin]] = [:]
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
    /// Makes the copy of a photograph that is sent.
    @ObservationIgnored var derive: (Data) -> Data? = { ShareDerivative.jpeg(from: $0) }
    /// Today, injectable for pruning and the crew day.
    @ObservationIgnored var now: () -> Date = Date.init

    var me: UUID { cloud.myProfileID }

    init(cloud: CrewCloud, defaults: UserDefaults, directory: URL) {
        self.cloud = cloud
        self.defaults = defaults
        self.directory = directory
        self.outbox = CrewOutbox.load(from: directory.appending(path: "outbox.json"))
    }

    // MARK: Reading

    func crew(_ id: CrewID) -> Crew? { crews.first { $0.id == id } }

    /// Every shared win still held for a crew, oldest first.
    func wins(in crew: CrewID) -> [SharedWin] {
        (winsByCrew[crew] ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    /// The crew's wins for its current day: what its tower shows.
    func today(in crewID: CrewID) -> [SharedWin] {
        guard let crew = crew(crewID) else { return [] }
        let day = CrewDay.string(for: now(), in: crew.timeZone)
        return wins(in: crewID).filter { $0.crewDay == day }
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

    /// The crews a win of yours is in, sent or on its way.
    func crews(holding winID: UUID) -> Set<CrewID> {
        var held = Set(winsByCrew.compactMap { id, wins in wins.contains { $0.winID == winID } ? id : nil })
        held.formUnion(pendingCrews(for: winID))
        return held
    }

    // MARK: Crews

    func createCrew(name: String) async throws -> (crew: Crew, invite: URL) {
        try requireOn()
        guard crews.count < CrewCaps.crews else { throw CrewError.tooManyCrews }
        let now = now()
        let crew = Crew(id: .new(),
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        ownerProfileID: me,
                        timeZoneIdentifier: TimeZone.current.identifier,
                        createdAt: now,
                        photo: nil,
                        members: [CrewMember(profileID: me, firstName: myFirstName(), head: nil, joinedAt: now)])
        let url = try await cloud.createZone(crew)
        try await cloud.save(CrewRecords.fields(crew), type: .crew, name: CrewRecords.crewRecordName, in: crew.id)
        try await cloud.save(CrewRecords.fields(crew.members[0]), type: .member,
                             name: CrewRecords.name(of: crew.members[0]), in: crew.id)
        crews.append(crew)
        winsByCrew[crew.id] = []
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
        return self.crew(id) ?? crew
    }

    func rename(_ crewID: CrewID, to name: String) async throws {
        try requireOn()
        guard var crew = crew(crewID) else { throw CrewError.unknownCrew }
        crew.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        replace(crew)
        try await cloud.save(CrewRecords.fields(crew), type: .crew, name: CrewRecords.crewRecordName, in: crewID)
    }

    /// A new picture for the crew, or nil to go back to the members' faces.
    func setPhoto(_ crewID: CrewID, jpeg: Data?) async throws {
        try requireOn()
        guard var crew = crew(crewID) else { throw CrewError.unknownCrew }
        if let jpeg, let small = derive(jpeg) {
            let url = directory.appending(path: "Photos/\(crewID.rawValue)/crew-\(UUID().uuidString).jpg")
            try write(small, to: url)
            crew.photo = url
        } else {
            crew.photo = nil
        }
        replace(crew)
        try await cloud.save(CrewRecords.fields(crew), type: .crew, name: CrewRecords.crewRecordName, in: crewID)
    }

    /// Your head, as friends see it. Nil takes it away.
    func setMyHead(_ pack: Data?) async {
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
            mine.firstName = myFirstName()
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
        winsByCrew[crewID]?.removeAll { $0.senderProfileID == profileID }
    }

    // MARK: Wins

    /// Sends a win to the crews chosen for it. Nothing is asked: the choice
    /// was made on the checkboxes, or is the one you made last time.
    func post(_ win: OwnWin, to chosen: Set<CrewID>) async {
        guard isEnabled() else { return }
        let photo = sendablePhoto(for: win)
        for crewID in chosen {
            guard let crew = crew(crewID) else { continue }
            let shared = sharedWin(win, in: crew, photo: photo.flatMap { copy($0, to: crewID, win: win.winID) })
            upsertLocal(shared)
            enqueue(.init(crew: crewID, type: .sharedWin, name: CrewRecords.name(of: shared), fields: CrewRecords.fields(shared)))
        }
        await flush()
    }

    /// An edit: every copy changes, in every crew it is in.
    func update(_ win: OwnWin) async {
        guard isEnabled() else { return }
        let holding = crews(holding: win.winID)
        guard !holding.isEmpty else { return }
        let photo = sendablePhoto(for: win)
        for crewID in holding {
            guard let crew = crew(crewID) else { continue }
            let existing = winsByCrew[crewID]?.first { $0.winID == win.winID }
            var shared = sharedWin(win, in: crew, photo: photo.flatMap { copy($0, to: crewID, win: win.winID) })
            // A win stays in the day it was first sent to.
            if let existing { shared.crewDay = existing.crewDay }
            upsertLocal(shared)
            enqueue(.init(crew: crewID, type: .sharedWin, name: CrewRecords.name(of: shared), fields: CrewRecords.fields(shared)))
        }
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
        await flush()
    }

    /// Deleting a win deletes every copy of it, everywhere.
    func deleteEverywhere(winID: UUID) async {
        guard isEnabled() else { return }
        for crewID in crews(holding: winID) {
            winsByCrew[crewID]?.removeAll { $0.winID == winID }
            enqueue(.init(crew: crewID, type: .sharedWin, name: winID.uuidString, fields: nil))
        }
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

    // MARK: Syncing

    /// Everything, from the cloud: on foreground, on opening the list, while a
    /// crew is on screen, and when a notification arrives.
    func refresh() async {
        guard isEnabled(), !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await flush()
        do {
            let fetched = try await cloud.fetchCrews()
            var wins: [CrewID: [SharedWin]] = [:]
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
                    wins[crew.id] = held
                } catch {
                    Self.log.error("fetching wins in \(crew.id.rawValue, privacy: .public) failed: \(error)")
                    wins[crew.id] = winsByCrew[crew.id] ?? []
                }
            }
            if crews != fetched { crews = fetched }
            if winsByCrew != wins { winsByCrew = wins }
            let known = Set(fetched.map(\.id))
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
        guard isEnabled(), !outbox.isEmpty else { return }
        for entry in outbox.entries {
            do {
                if let fields = entry.fields {
                    try await cloud.save(fields, type: entry.type, name: entry.name, in: entry.crew)
                } else {
                    try await cloud.delete(type: entry.type, name: entry.name, in: entry.crew)
                }
                outbox.remove(entry)
            } catch {
                Self.log.error("\(entry.type.rawValue, privacy: .public) to \(entry.crew.rawValue, privacy: .public) not sent: \(error)")
                outbox.noteFailure(entry)
            }
        }
        persistOutbox()
    }

    /// A crew is a window on now, not an archive: anything older than the
    /// crew's previous day, plus two days of grace for a phone that was off,
    /// goes. Whoever opens the crew next does the deleting.
    func prune() {
        for crew in crews {
            let today = CrewDay.string(for: now(), in: crew.timeZone)
            guard let cutoff = CrewDay.day(today, offsetBy: -3, in: crew.timeZone) else { continue }
            let old = (winsByCrew[crew.id] ?? []).filter { $0.crewDay < cutoff }
            guard !old.isEmpty else { continue }
            winsByCrew[crew.id]?.removeAll { $0.crewDay < cutoff }
            for win in old {
                if let photo = win.photo { try? FileManager.default.removeItem(at: photo) }
                enqueue(.init(crew: crew.id, type: .sharedWin, name: win.winID.uuidString, fields: nil))
            }
        }
    }

    // MARK: Unread

    func markSeen(_ crewID: CrewID) {
        var seen = lastSeen
        seen[crewID.rawValue] = now().timeIntervalSince1970
        defaults.set(seen, forKey: Self.lastSeenKey)
        unread.remove(crewID)
    }

    private static let lastSeenKey = "crews.lastSeen"
    private var lastSeen: [String: Double] {
        defaults.dictionary(forKey: Self.lastSeenKey) as? [String: Double] ?? [:]
    }

    private func recomputeUnread() {
        let seen = lastSeen
        let fresh = Set(crews.compactMap { crew -> CrewID? in
            let since = Date(timeIntervalSince1970: seen[crew.id.rawValue] ?? 0)
            return (winsByCrew[crew.id] ?? []).contains { $0.senderProfileID != me && $0.updatedAt > since } ? crew.id : nil
        })
        if unread != fresh { unread = fresh }
    }

    // MARK: Hide Alerts

    /// Shared with the notification extension through the app group, so it
    /// can quiet a crew's notifications without the app running.
    static let groupDefaults = UserDefaults(suiteName: "group.JaydenBetts.Strata")
    private static let hiddenKey = "crews.hiddenAlerts"

    func hidesAlerts(_ crewID: CrewID) -> Bool {
        _ = outboxRevision
        return (Self.groupDefaults?.stringArray(forKey: Self.hiddenKey) ?? []).contains(crewID.rawValue)
    }

    func setHidesAlerts(_ hide: Bool, for crewID: CrewID) {
        var hidden = Set(Self.groupDefaults?.stringArray(forKey: Self.hiddenKey) ?? [])
        if hide { hidden.insert(crewID.rawValue) } else { hidden.remove(crewID.rawValue) }
        Self.groupDefaults?.set(hidden.sorted(), forKey: Self.hiddenKey)
        outboxRevision += 1
    }

    // MARK: Test and debug seams

    /// Puts crews and wins in place without a cloud round trip. Debug seeds
    /// and tests only.
    func adopt(crews: [Crew], wins: [CrewID: [SharedWin]]) {
        self.crews = crews
        self.winsByCrew = wins
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
        unread.remove(crewID)
        outbox.drop(crew: crewID)
        persistOutbox()
        CrewChoice.forget(crewID, defaults)
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

    /// The derivative, once per post, or nothing when photos may not leave.
    private func sendablePhoto(for win: OwnWin) -> Data? {
        guard photosAllowed(), let jpeg = win.photoJPEG else { return nil }
        return derive(jpeg)
    }

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
