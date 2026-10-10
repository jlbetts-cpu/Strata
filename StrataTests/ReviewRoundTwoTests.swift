import Foundation
import Testing
@testable import Strata

/// The fixes from the 2026-10-10 independent review that are pure enough to
/// pin (`tasks/unification-log.md`, "The review").
@Suite("Review, round two")
struct ReviewRoundTwoTests {
    // MARK: A photo's place while standing still

    @Test("a fix measured while updates run is current, however long you stand still")
    func standingStill() {
        let began = Date(timeIntervalSince1970: 1_000)
        let measured = began.addingTimeInterval(5)
        #expect(LocationService.isCurrent(measured: measured, now: began.addingTimeInterval(400),
                                          maxAge: 30, runningSince: began))
    }

    @Test("a fix from before the updates began is judged by its age")
    func cachedFix() {
        let began = Date(timeIntervalSince1970: 1_000)
        let old = began.addingTimeInterval(-600)
        #expect(!LocationService.isCurrent(measured: old, now: began.addingTimeInterval(2), maxAge: 30, runningSince: began))
        #expect(LocationService.isCurrent(measured: began.addingTimeInterval(-10), now: began.addingTimeInterval(2),
                                          maxAge: 30, runningSince: began))
        #expect(!LocationService.isCurrent(measured: began, now: began.addingTimeInterval(100), maxAge: 30, runningSince: nil))
    }

    // MARK: The crew's evening survives a win after seven

    @Test("a win at ten past seven keeps the crew's 8:25")
    func crewEveningAfterSeven() throws {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_791_500_000))
        let morningWin = try #require(calendar.date(bySettingHour: 7, minute: 0, second: 0, of: day))
        let now = try #require(calendar.date(bySettingHour: 19, minute: 10, second: 0, of: day))
        let crew = try #require(calendar.date(bySettingHour: 20, minute: 25, second: 0, of: day))
        // Without the crew's time, seven has passed and there is none.
        #expect(EveningCheckIn.when(winsToday: 2, firstWin: morningWin, now: now, morningHour: 8, morningMinute: 0,
                                    cueSeenToday: false, goal: 3) == nil)
        #expect(EveningCheckIn.when(winsToday: 2, firstWin: morningWin, now: now, morningHour: 8, morningMinute: 0,
                                    cueSeenToday: false, goal: 3, evening: crew) == crew)
        // Once the crew's time has passed too, none.
        #expect(EveningCheckIn.when(winsToday: 2, firstWin: morningWin, now: crew.addingTimeInterval(60),
                                    morningHour: 8, morningMinute: 0, cueSeenToday: false, goal: 3, evening: crew) == nil)
    }

    // MARK: A strip that did not send says so

    @MainActor
    @Test("every way a strip can fail to send has words")
    func stripWords() {
        for outcome: SocialStore.ReplyOutcome in [.refusedSketch, .dailyLimit, .throttled, .notAllowed, .refusedWords] {
            #expect(!CrewStripActivity.words(for: outcome).isEmpty)
        }
        #expect(CrewStripActivity.words(for: .sent).isEmpty)
    }

    // MARK: Squatting

    @Test("a box says how many files it came with before any is downloaded, and nothing to the wrong key")
    func fileCount() throws {
        let key = CrewKey.new()
        let folder = FileManager.default.temporaryDirectory.appending(path: "count-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let photo = folder.appending(path: "p.jpg")
        try Data(repeating: 3, count: 64).write(to: photo)
        let with = try CrewItemBox.seal(["title": .string("Run"), "photo": .asset(photo)], key: key,
                                        recordName: "crew-1~SharedWin~a", folder: folder.appending(path: "out"))
        let without = try CrewItemBox.seal(["title": .string("Run")], key: key,
                                           recordName: "crew-1~SharedWin~b", folder: folder.appending(path: "out"))
        #expect(CrewItemBox.fileCount(with.box, key: key, recordName: "crew-1~SharedWin~a") == 1)
        #expect(CrewItemBox.fileCount(without.box, key: key, recordName: "crew-1~SharedWin~b") == 0)
        #expect(CrewItemBox.fileCount(with.box, key: CrewKey.new(), recordName: "crew-1~SharedWin~a") == nil)
    }
}
