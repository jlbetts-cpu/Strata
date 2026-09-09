import Foundation
import Testing
@testable import Strata

/// What counts as a repeated interest, and what a cover shows.
///
/// All of this is a value function over `WinRecord`, which is exactly why the
/// flattening step exists: these run with struct literals, no container and no
/// simulator.
struct AlbumTests {

    private static let calendar: Calendar = {
        var c = Calendar.current
        c.firstWeekday = 2
        return c
    }()

    /// 2026-09-07 is a Monday, so `day(0)` starts a week and `day(7)` starts
    /// the next one. Weeks matter to the span gate, so they are pinned rather
    /// than left to whenever the suite happens to run.
    private static let origin: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 9; c.day = 7; c.hour = 9
        return calendar.date(from: c)!
    }()

    private func date(_ dayOffset: Int, hour: Int = 9) -> Date {
        Self.calendar.date(byAdding: .init(day: dayOffset, hour: hour - 9), to: Self.origin)!
    }

    private func win(_ title: String,
                     day: Int,
                     hour: Int = 9,
                     photo: String? = "p\(UUID().uuidString).heic") -> WinRecord {
        let d = date(day, hour: hour)
        return WinRecord(
            dateString: DateUtils.dateString(from: d),
            completedAt: d,
            title: title,
            category: .health,
            size: .small,
            photoFileName: photo
        )
    }

    /// A title that clears every gate: 6 photos, 6 days, spanning two weeks.
    private func qualifyingRun(_ title: String) -> [WinRecord] {
        [0, 1, 2, 7, 8, 9].map { win(title, day: $0, photo: "\(title)-\($0).heic") }
    }

    private func curated(_ records: [WinRecord]) -> [Album] {
        Album.curatedAlbums(from: records, calendar: Self.calendar)
    }

    // MARK: - The key

    @Test func spellingsOfOneTitleCollapse() {
        #expect(Album.titleKey("Gym Session") == Album.titleKey("gym session"))
        #expect(Album.titleKey("  gym   session  ") == Album.titleKey("gym session"))
        #expect(Album.titleKey("Café") == Album.titleKey("cafe"))
    }

    @Test func differentTitlesDoNotCollapse() {
        #expect(Album.titleKey("gym") != Album.titleKey("gym session"))
    }

    @Test func theUnnamedPlaceholderIsNeverAnInterest() {
        #expect(!Album.isCuratable(Album.titleKey(QuickWinService.untitled)))
        #expect(!Album.isCuratable(Album.titleKey("   ")))
        #expect(Album.isCuratable(Album.titleKey("Gym session")))
    }

    @Test func unnamedWinsEarnNoCuratedAlbumHoweverManyThereAre() {
        let records = (0..<12).map { win(QuickWinService.untitled, day: $0) }
        #expect(curated(records).isEmpty)
    }

    // MARK: - The three gates

    @Test func aQualifyingRunEarnsExactlyOneCard() {
        let albums = curated(qualifyingRun("Gym session"))
        #expect(albums.count == 1)
        #expect(albums.first?.kind == .curated(Album.titleKey("Gym session")))
    }

    @Test func fourPhotographsIsNotEnough() {
        // Four days, two weeks — only the photo gate fails.
        let records = [0, 1, 7, 8].map { win("Gym", day: $0, photo: "g\($0).heic") }
        #expect(curated(records).isEmpty)
    }

    @Test func fivePhotographsIsEnough() {
        let records = [0, 1, 2, 7, 8].map { win("Gym", day: $0, photo: "g\($0).heic") }
        #expect(curated(records).count == 1)
    }

    /// Six photographs of one session is one session.
    @Test func manyPhotographsOnOneDayFailTheDayGate() {
        let records = (0..<6).map { win("Gym", day: 0, hour: 9 + $0, photo: "g\($0).heic") }
        #expect(curated(records).isEmpty)
    }

    /// Four times inside one week is a burst, not a habit.
    @Test func aRunInsideOneWeekFailsTheSpanGate() {
        let records = [0, 1, 2, 3, 4].map { win("Gym", day: $0, photo: "g\($0).heic") }
        #expect(curated(records).isEmpty)
    }

    @Test func winsWithoutPhotographsDoNotCount() {
        let photoless = [0, 1, 2, 7, 8, 9].map { win("Gym", day: $0, photo: nil) }
        #expect(curated(photoless).isEmpty)
    }

    // MARK: - Ordering and display

    @Test func busierInterestsComeFirst() {
        let quiet = qualifyingRun("Reading")
        let busy = qualifyingRun("Gym") + [win("Gym", day: 14, photo: "gym-extra.heic")]
        let albums = curated(quiet + busy)
        #expect(albums.count == 2)
        #expect(albums.first?.title == "Gym")
    }

    /// A partial order would make this suite flaky rather than red, so the
    /// tie-break down to the key itself is asserted.
    @Test func identicalRunsStillHaveADefiniteOrder() {
        let a = qualifyingRun("Alpha")
        let b = qualifyingRun("Beta")
        let forwards = curated(a + b).map(\.id)
        let backwards = curated(b + a).map(\.id)
        #expect(forwards == backwards)
    }

    @Test func theTitleShownIsTheSpellingYouActuallyUse() {
        var records = qualifyingRun("gym session")
        records.append(win("Gym Session", day: 10, photo: "odd.heic"))
        #expect(curated(records).first?.title == "gym session")
    }

    @Test func theSubtitleCountsPhotographs() {
        #expect(curated(qualifyingRun("Gym")).first?.subtitle == "6 PHOTOS")
    }

    // MARK: - Covers

    /// The fan's whole claim is "many days". Three prints from one session
    /// would say the opposite.
    @Test func aCoverTakesItsThreePrintsFromThreeDifferentDays() {
        var records = qualifyingRun("Gym")
        // Pile four more onto the newest day.
        records += (0..<4).map { win("Gym", day: 9, hour: 12 + $0, photo: "pile\($0).heic") }
        let cover = curated(records).first!.photoFileNames.prefix(3)
        let days = Set(cover.map { name -> String in
            let all = records.first { $0.photoFileName == name }!
            return all.dateString
        })
        #expect(cover.count == 3)
        #expect(days.count == 3)
    }

    // MARK: - Day albums

    private func days(_ records: [WinRecord], demoting prints: Set<String> = []) -> [Album] {
        Album.dayAlbums(from: records, calendar: Self.calendar,
                        now: date(9), demoting: prints)
    }

    @Test func aDayWithNoPhotographsProducesNoAlbum() {
        let records = [win("Walk", day: 0, photo: nil), win("Read", day: 0, photo: nil)]
        #expect(days(records).isEmpty)
    }

    @Test func aDayWithOnePhotographProducesOne() {
        let records = [win("Walk", day: 0, photo: nil), win("Read", day: 0, photo: "r.heic")]
        let albums = days(records)
        #expect(albums.count == 1)
        // Both wins count, even though only one is a photograph.
        #expect(albums.first?.winCount == 2)
    }

    @Test func daysComeBackNewestFirst() {
        let records = [win("A", day: 0), win("B", day: 3), win("C", day: 1)]
        let albums = days(records)
        #expect(albums.count == 3)
        #expect(albums.map(\.id) == ["day:\(records[1].dateString)",
                                    "day:\(records[2].dateString)",
                                    "day:\(records[0].dateString)"])
    }

    /// Demoted, never filtered: a day whose only photograph is already on a
    /// curated cover must still appear.
    @Test func aDayWhoseOnlyPhotographIsReusedStillAppears() {
        let records = [win("Gym", day: 0, photo: "shared.heic")]
        let albums = days(records, demoting: ["shared.heic"])
        #expect(albums.count == 1)
        #expect(albums.first?.photoFileNames == ["shared.heic"])
    }

    @Test func reusedPhotographsSinkBehindFreshOnes() {
        let records = [
            win("Gym", day: 0, hour: 12, photo: "shared.heic"),
            win("Walk", day: 0, hour: 9, photo: "fresh.heic")
        ]
        let albums = days(records, demoting: ["shared.heic"])
        #expect(albums.first?.photoFileNames == ["fresh.heic", "shared.heic"])
    }

    // MARK: - The carousel

    @Test func curatedCardsLeadTheCarousel() {
        let records = qualifyingRun("Gym") + [win("One off", day: 12, photo: "o.heic")]
        let shelf = Album.carousel(from: records, calendar: Self.calendar, now: date(12))
        guard case .curated = shelf.first?.kind else {
            Issue.record("expected a curated album first, got \(String(describing: shelf.first?.kind))")
            return
        }
    }

    @Test func curatedCardsAreCapped() {
        let records = ["Gym", "Reading", "Walk", "Cook", "Draw", "Swim"]
            .flatMap { qualifyingRun($0) }
        let shelf = Album.carousel(from: records, calendar: Self.calendar, now: date(9))
        let curatedCount = shelf.filter { if case .curated = $0.kind { return true }; return false }.count
        #expect(curatedCount == Album.maxCurated)
    }

    @Test func everyAlbumHasADistinctIdentity() {
        let records = qualifyingRun("Gym") + qualifyingRun("Reading")
        let shelf = Album.carousel(from: records, calendar: Self.calendar, now: date(9))
        #expect(Set(shelf.map(\.id)).count == shelf.count)
    }

    @Test func anEmptyRecordProducesAnEmptyCarousel() {
        #expect(Album.carousel(from: [], calendar: Self.calendar, now: Date()).isEmpty)
    }
}
