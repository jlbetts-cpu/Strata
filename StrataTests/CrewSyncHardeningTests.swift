import CloudKit
import Testing
import Foundation
@testable import Strata

/// **A full iCloud, a busy server and a quiet crew** (the 2026-10-08 launch
/// audit): a post waits rather than vanishes, CloudKit's "wait" is obeyed,
/// a live change reads one crew, and a quiet crew is asked less often.
@MainActor
@Suite("Crew sync hardening", .serialized)
struct CrewSyncHardeningTests {
    let world = FakeCrewWorld()
    let jayden = UUID()
    let sam = UUID()

    func store(_ me: UUID) -> (SocialStore, FakeCrewCloud) {
        let suite = "sync-hardening-\(UUID().uuidString)"
        let cloud = FakeCrewCloud(world: world, me: me)
        let store = SocialStore(cloud: cloud, defaults: UserDefaults(suiteName: suite)!,
                                directory: FileManager.default.temporaryDirectory.appending(path: suite))
        store.isEnabled = { true }
        store.derive = { $0 }
        return (store, cloud)
    }

    func win(_ title: String = "Gym") -> OwnWin {
        OwnWin(winID: UUID(), title: title, colour: .health, icon: .health, blockSize: .small,
               photoJPEG: nil, cropX: nil, cropY: nil, createdAt: .now, updatedAt: .now)
    }

    @Test func aFullICloudIsAWaitNotAFailure() {
        let full = CKError(.quotaExceeded)
        #expect(SocialStore.isQuotaExceeded(full))
        #expect(SocialStore.transientWait(full) == nil)
        #expect(SocialStore.quotaPause(full) >= 30)
        // Inside a partial failure, as a batch save reports it.
        let partial = CKError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey:
            [CKRecord.ID(recordName: "x"): CKError(.quotaExceeded)]])
        #expect(SocialStore.isQuotaExceeded(partial))
        #expect(!SocialStore.isQuotaExceeded(CKError(.networkFailure)))
    }

    @Test func aPostToAFullCrewWaitsUncountedAndSaysSo() async throws {
        let (a, cloud) = store(jayden)
        var clock = Date()
        a.now = { clock }
        let (crew, _) = try await a.createCrew(name: "One")
        cloud.saveError = CKError(.quotaExceeded)
        let mine = win()
        await a.post(mine, to: [crew.id])
        #expect(a.fullCrews == [crew.id])
        // Far past the twenty tries that used to drop it.
        for _ in 0..<30 {
            clock = clock.addingTimeInterval(120)
            await a.flush()
        }
        let waiting = try #require(a.outboxEntries.first { $0.name == mine.winID.uuidString })
        #expect(waiting.attempts == 0)
        #expect(a.pendingCrews(for: mine.winID) == [crew.id])
        // Room again: it goes, and the line goes with it.
        cloud.saveError = nil
        clock = clock.addingTimeInterval(120)
        await a.flush()
        #expect(a.pendingCrews(for: mine.winID).isEmpty)
        #expect(a.fullCrews.isEmpty)
        #expect(world.records(of: .sharedWin, in: crew.id)[mine.winID.uuidString] != nil)
        #expect(!SocialStore.fullWords.contains("\u{2014}"))
    }

    /// A full iCloud refuses a new crew (the owner's phone, build 109): no
    /// crew is listed, no empty zone is left behind for every refresh to
    /// sync, and the words name the person's own storage, plainly.
    @Test func aCrewThatCannotBeSavedLeavesNothingBehind() async throws {
        let (a, cloud) = store(jayden)
        cloud.saveError = CKError(.quotaExceeded)
        await #expect(throws: CKError.self) { _ = try await a.createCrew(name: "One") }
        #expect(a.crews.isEmpty)
        #expect(world.zones.isEmpty)
        cloud.saveError = nil
        let (crew, _) = try await a.createCrew(name: "One")
        #expect(a.crews.map(\.id) == [crew.id])
        #expect(world.zones.count == 1)
        #expect(SocialStore.fullToStartWords.contains("iCloud storage is full"))
        #expect(!SocialStore.fullToStartWords.contains("\u{2014}"))
    }

    /// The crews audit (2026-10-08): a join that accepted the share but could
    /// not write its Member record left the friend in a crew where nothing
    /// they sent was kept. The next refresh writes it.
    @Test func aHalfFinishedJoinIsMendedByTheNextRefresh() async throws {
        let (a, _) = store(jayden)
        let (b, bCloud) = store(sam)
        let (crew, link) = try await a.createCrew(name: "One")
        bCloud.saveError = CKError(.quotaExceeded)
        await #expect(throws: (any Error).self) { _ = try await b.accept(CrewInvite(url: link)) }
        #expect(world.records(of: .member, in: crew.id)[sam.uuidString] == nil)
        bCloud.saveError = nil
        await b.refresh()
        #expect(world.records(of: .member, in: crew.id)[sam.uuidString] != nil)
    }

    /// At the cap, a link to a crew you are already in still opens it.
    @Test func aLinkToACrewYouAreInOpensItAtTheCap() async throws {
        let (a, _) = store(jayden)
        let (b, _) = store(sam)
        var first: (crew: Crew, invite: URL)?
        for n in 0..<CrewCaps.crews {
            let made = try await a.createCrew(name: "Crew \(n)")
            if first == nil { first = made }
            _ = try await b.accept(CrewInvite(url: made.invite))
        }
        #expect(b.crews.count == CrewCaps.crews)
        let again = try await b.accept(CrewInvite(url: try #require(first).invite))
        #expect(again.id == first?.crew.id)
        // A new one is still refused, and left again.
        let (c, _) = store(UUID())
        let extra = try await c.createCrew(name: "Extra")
        await #expect(throws: CrewError.tooManyCrews) { _ = try await b.accept(CrewInvite(url: extra.invite)) }
        #expect(world.zones[extra.crew.id]?.participants.contains(sam) == false)
    }

    /// Every crew error reads as a sentence that says what to do, never as
    /// CloudKit's own text (the owner, 2026-10-08).
    @Test func crewErrorsArePlainWords() {
        #expect(CrewErrorWords.say(CKError(.quotaExceeded), while: .starting) == CrewErrorWords.yourICloudFull)
        #expect(CrewErrorWords.say(CKError(.quotaExceeded), while: .joining) == CrewErrorWords.starterICloudFull)
        #expect(CrewErrorWords.say(CKError(.networkUnavailable), while: .starting) == CrewErrorWords.offline)
        #expect(CrewErrorWords.say(URLError(.notConnectedToInternet), while: .inviting) == CrewErrorWords.offline)
        #expect(CrewErrorWords.say(CKError(.zoneNotFound), while: .joining) == CrewErrorWords.ended)
        #expect(CrewErrorWords.say(CrewError.tooManyCrews, while: .starting).contains("start another"))
        let partial = CKError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey:
            [CKRecord.ID(recordName: "x"): CKError(.quotaExceeded)]])
        #expect(CrewErrorWords.say(partial, while: .starting) == CrewErrorWords.yourICloudFull)
        let odd = NSError(domain: "CKErrorDomain", code: 999, userInfo: [NSLocalizedDescriptionKey: "Error saving record <CKRecordID: 0x1>"])
        for doing in [CrewErrorWords.Doing.starting, .joining, .inviting] {
            let line = CrewErrorWords.say(odd, while: doing)
            #expect(!line.contains("CKRecord") && !line.contains("Error") && !line.contains("\u{2014}"), "\(line)")
        }
        // No screen prints CloudKit's own text after a colon any more.
        for file in ["Strata/Views/Crews/CrewsListView.swift", "Strata/Views/Crews/CrewSharing.swift",
                     "Strata/Social/StrataAppDelegate.swift"] {
            let code = (try? SourceSweep.code(SourceSweep.read(file))) ?? ""
            #expect(!code.contains("error.localizedDescription"), "\(file)")
        }
    }

    @Test func cloudKitsWaitIsReadFromTheError() {
        let limited = CKError(.requestRateLimited, userInfo: [CKErrorRetryAfterKey: 30.0])
        #expect(SocialStore.serverBackoff(limited) == 30)
        #expect(SocialStore.serverBackoff(CKError(.zoneBusy)) != nil)
        #expect(SocialStore.serverBackoff(CKError(.serviceUnavailable)) != nil)
        #expect(SocialStore.serverBackoff(CKError(.networkFailure)) == nil)
        #expect(SocialStore.serverBackoff(CKError(.quotaExceeded)) == nil)
    }

    @Test func nothingIsAskedWhileCloudKitSaysWait() async throws {
        let (a, cloud) = store(jayden)
        let (b, _) = store(sam)
        var clock = Date()
        a.now = { clock }
        let (crew, link) = try await a.createCrew(name: "One")
        _ = try await b.accept(CrewInvite(url: link))
        await a.refresh()
        _ = await a.refreshLive(crew.id)
        // A rate limit on a write: CloudKit says thirty seconds.
        cloud.saveError = CKError(.requestRateLimited, userInfo: [CKErrorRetryAfterKey: 30.0])
        await a.post(win(), to: [crew.id])
        cloud.saveError = nil
        await b.post(win("Run"), to: [crew.id])
        let before = cloud.calls
        #expect(await a.refreshLive(crew.id) == false)
        await a.refresh()
        #expect(cloud.calls == before, "neither the live sync nor a refresh asked anything")
        clock = clock.addingTimeInterval(31)
        #expect(await a.refreshLive(crew.id))
        #expect(a.wins(in: crew.id).contains { $0.title == "Run" })
    }

    @Test func aLiveChangeReadsOnlyThatCrew() async throws {
        let (a, cloud) = store(jayden)
        let (b, _) = store(sam)
        let (one, link) = try await a.createCrew(name: "One")
        _ = try await a.createCrew(name: "Two")
        _ = try await b.accept(CrewInvite(url: link))
        await a.refresh()
        _ = await a.refreshLive(one.id)
        await b.post(win("Run"), to: [one.id])
        let before = cloud.calls
        #expect(await a.refreshLive(one.id))
        #expect(a.wins(in: one.id).contains { $0.title == "Run" })
        // The crew list once, then this crew's wins, reactions and chat:
        // never the other crew's.
        #expect(cloud.calls - before == 4)
    }

    @Test func aQuietCrewIsAskedLessOftenUntilSomethingMoves() {
        var pace = CrewLivePace()
        #expect(pace.interval == 3)
        pace.asked(changed: false)
        pace.asked(changed: false)
        #expect(pace.interval == 3)
        pace.asked(changed: false)
        #expect(pace.interval == 12)
        pace.asked(changed: false)
        #expect(pace.interval == 12)
        pace.asked(changed: true)
        #expect(pace.interval == 3)
        for _ in 0..<5 { pace.asked(changed: false) }
        pace.nudged()
        #expect(pace.interval == 3)
    }
}
