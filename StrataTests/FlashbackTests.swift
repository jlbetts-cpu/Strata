import Foundation
import Testing
@testable import Strata

/// On this day (`Flashback`). One test for each line of the rubric in
/// `docs/flashback.md` that a test can hold; the rest are looked at.
@Suite("Memories: on this day")
struct FlashbackTests {
    private let calendar = DateUtils.keyCalendar()

    private func day(_ key: String) -> Date { DateUtils.date(from: key)! }
    private func record(_ key: String, photo: Bool = true) -> WinRecord {
        WinRecord(dateString: key, completedAt: day(key), title: "Run", category: .health, size: .small,
                  photoFileName: photo ? "\(UUID()).jpg" : nil, id: UUID())
    }
    private func defaults() -> UserDefaults {
        let name = "flashback-\(UUID())"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    // Rubric 1.
    @Test("every day of 2024 to 2028: the same day of the month, and the title is the real gap")
    func honestDates() throws {
        var today = day("2024-01-01")
        let end = day("2028-12-31")
        var seen = 0
        while today <= end {
            for rung in Flashback.rungs(today: today, calendar: calendar) {
                let then = try #require(DateUtils.date(from: rung.day))
                #expect(calendar.component(.day, from: then) == calendar.component(.day, from: today), "\(rung.day) on \(DateUtils.dateString(from: today))")
                let gap = calendar.dateComponents([.year, .month, .day], from: then, to: today)
                #expect(gap.day == 0)
                switch rung.title {
                case Flashback.oneMonth: #expect(gap.year == 0 && gap.month == 1)
                case Flashback.sixMonths: #expect(gap.year == 0 && gap.month == 6)
                default:
                    #expect(gap.month == 0)
                    #expect(rung.title == Flashback.title(years: gap.year ?? 0))
                    #expect(calendar.component(.month, from: then) == calendar.component(.month, from: today))
                }
                seen += 1
            }
            today = calendar.date(byAdding: .day, value: 1, to: today)!
        }
        #expect(seen > 5000)
        // The two dates with no counterpart.
        let march31 = Flashback.rungs(today: day("2026-03-31"), calendar: calendar)
        #expect(!march31.contains { $0.title == Flashback.oneMonth })
        #expect(!Flashback.rungs(today: day("2026-05-31"), calendar: calendar).contains { $0.underAYear && $0.title == Flashback.sixMonths })
        // 29 February looks back only to another 29 February, and the last
        // one is further than the app looks.
        #expect(Flashback.rungs(today: day("2028-02-29"), calendar: calendar).filter { !$0.underAYear }.isEmpty)
        #expect(Flashback.rungs(today: day("2028-02-29"), calendar: calendar).map(\.day) == ["2027-08-29", "2028-01-29"])
    }

    // Rubric 2.
    @Test("a day with no photo is not a flashback")
    func needsAPhoto() {
        let today = day("2026-10-12")
        #expect(Flashback.album(records: [record("2026-09-12", photo: false)], today: today, calendar: calendar, lastUnderAYear: nil) == nil)
        #expect(Flashback.album(records: [], today: today, calendar: calendar, lastUnderAYear: nil) == nil)
        // A photo on another day of last month is not one either.
        #expect(Flashback.album(records: [record("2026-09-11")], today: today, calendar: calendar, lastUnderAYear: nil) == nil)
    }

    @Test("the furthest back with a photo wins")
    func furthestFirst() throws {
        let today = day("2026-10-12")
        let records = [record("2026-09-12"), record("2026-04-12"), record("2025-10-12"), record("2024-10-12", photo: false)]
        let found = try #require(Flashback.album(records: records, today: today, calendar: calendar, lastUnderAYear: nil))
        #expect(found.album.title == "A year ago today")
        #expect(found.album.subtitle == "12 OCT 2025")
        #expect(found.album.route == .day("2025-10-12"))
        let near = try #require(Flashback.album(records: [records[0], records[1]], today: today, calendar: calendar, lastUnderAYear: nil))
        #expect(near.album.title == "6 months ago today")
        #expect(near.album.subtitle == "12 APR")
    }

    // Rubric 3.
    @Test("a photo every day for two years: under a year, at most one card in seven days")
    func quiet() {
        var photoDays: Set<String> = []
        var cursor = day("2024-06-01")
        while cursor <= day("2026-12-31") {
            photoDays.insert(DateUtils.dateString(from: cursor))
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }
        // Only the rungs under a year, to count them alone.
        let recent = photoDays.filter { $0 >= "2026-01-01" }
        var last: String?
        var shown: [(today: Date, source: String)] = []
        var today = day("2026-08-01")
        for _ in 0..<90 {
            if let rung = Flashback.pick(photoDays: recent, today: today, calendar: calendar, lastUnderAYear: last) {
                #expect(rung.underAYear)
                shown.append((today, rung.day))
                last = DateUtils.dateString(from: today)
            }
            today = calendar.date(byAdding: .day, value: 1, to: today)!
        }
        #expect(shown.count >= 10)
        #expect(Set(shown.map(\.source)).count == shown.count)
        for (a, b) in zip(shown, shown.dropFirst()) {
            #expect((calendar.dateComponents([.day], from: a.today, to: b.today).day ?? 0) >= Flashback.quietDays)
        }
        // The same day, asked twice: the same card, not none.
        let once = Flashback.pick(photoDays: recent, today: day("2026-10-12"), calendar: calendar, lastUnderAYear: nil)
        let again = Flashback.pick(photoDays: recent, today: day("2026-10-12"), calendar: calendar, lastUnderAYear: "2026-10-12")
        #expect(once != nil && once == again)
        // A year ago is once a year, and is never held back.
        let year = Flashback.pick(photoDays: photoDays, today: day("2026-10-13"), calendar: calendar, lastUnderAYear: "2026-10-12")
        #expect(year?.title == "2 years ago today")
    }

    // Rubric 4 and 11.
    @Test("Remove hides it today; Never hides every one; both come back")
    func removing() throws {
        let store = defaults()
        let records = [record("2026-09-12"), record("2025-10-13")]
        func shelf(on today: String) -> [Album] {
            let moments = Flashback.album(records: records, today: day(today), calendar: calendar, lastUnderAYear: nil).map { [$0.album] } ?? []
            let removed = Set(RemovedAlbums.all(defaults: store).keys)
            return Album.monthShelf(records: records, month: String(today.prefix(7)), crews: [], moments: moments,
                                    hidden: { RemovedAlbums.isRemoved($0, today: today, in: removed) })
        }
        let card = try #require(shelf(on: "2026-10-12").first)
        let key = try #require(RemovedAlbums.remove(card.kind, title: card.title, never: false, today: "2026-10-12", defaults: store))
        #expect(shelf(on: "2026-10-12").isEmpty)
        // Its wins are untouched: the records are the same two.
        #expect(records.count == 2 && records.allSatisfy(\.hasPhoto))
        // Tomorrow's is another day's card.
        #expect(shelf(on: "2026-10-13").first?.title == "A year ago today")
        // Undo: back, and first.
        RemovedAlbums.showAgain(key, defaults: store)
        #expect(shelf(on: "2026-10-12").first == card)

        let never = try #require(RemovedAlbums.remove(card.kind, title: Flashback.familyName, never: true, today: "2026-10-12", defaults: store))
        var today = day("2026-10-12")
        for _ in 0..<400 {
            #expect(shelf(on: DateUtils.dateString(from: today)).isEmpty)
            today = calendar.date(byAdding: .day, value: 1, to: today)!
        }
        RemovedAlbums.showAgain(never, defaults: store)
        #expect(shelf(on: "2026-10-12").first == card)
    }

    // Rubric 6.
    @Test("the titles are a fixed set, with no long dash and nothing about missing")
    func titles() {
        var titles: Set<String> = []
        var today = day("2026-01-01")
        for _ in 0..<366 {
            Flashback.rungs(today: today, calendar: calendar).forEach { titles.insert($0.title) }
            today = calendar.date(byAdding: .day, value: 1, to: today)!
        }
        #expect(titles == ["A year ago today", "2 years ago today", "3 years ago today", "6 months ago today", "A month ago today"])
        for title in titles {
            #expect(!title.contains("\u{2014}") && !title.contains("\u{2013}"))
            #expect(!title.lowercased().contains("miss"))
        }
    }

    // Rubric 7, 8 and 12.
    @Test("one card, first on the shelf, from a single photo, in a month with no photos yet")
    func firstOnTheShelf() throws {
        let today = day("2026-10-01")
        // September has an album of its own; October has nothing yet.
        var records = [record("2026-09-01")]
        records += ["2026-10-02", "2026-10-03", "2026-10-04"].map { record($0) }
        let found = try #require(Flashback.album(records: [records[0]], today: today, calendar: calendar, lastUnderAYear: nil))
        #expect(found.album.winCount == 1)
        #expect(found.album.photoFileNames.count == 1)
        let empty = Album.monthShelf(records: [records[0]], month: "2026-10", crews: [], moments: [found.album])
        #expect(empty.map(\.id) == [found.album.id])
        let full = Album.monthShelf(records: records, month: "2026-10", crews: [], moments: [found.album])
        #expect(full.first?.id == found.album.id)
        #expect(full.filter { $0.id.hasPrefix("flashback:") }.count == 1)
        // The shelf itself adds none of its own.
        #expect(Album.monthShelf(records: records, month: "2026-10", crews: [], moments: []).allSatisfy { !$0.id.hasPrefix("flashback:") })
    }

    @Test("the evening's line is on the same ladder, in the same words")
    func eveningAgrees() {
        let today = day("2026-10-12")
        func c(_ title: String, _ key: String) -> PastWin.Candidate { .init(title: title, dateString: key) }
        let month = PastWin.pick(from: [c("Morning Run", "2026-09-12"), c("Laundry", "2026-08-30")], today: today, calendar: calendar)
        #expect(month?.line == "A month ago today: Morning Run")
        #expect(month?.dateString == "2026-09-12")
        // The furthest back first, as the card.
        let year = PastWin.pick(from: [c("Morning Run", "2026-09-12"), c("Gym", "2025-10-12")], today: today, calendar: calendar)
        #expect(year?.when == "A year ago today")
        let found = Flashback.album(records: [record("2026-09-12")], today: today, calendar: calendar, lastUnderAYear: nil)
        #expect(found?.album.title == month?.when)
    }

    @Test("the model's shelf drops the old three-photo look back, and the page shows a flashback alone")
    func wiring() throws {
        let model = SourceSweep.code(try SourceSweep.read("Strata/ViewModels/MemoriesViewModel.swift"))
        #expect(model.contains(#"!id.hasPrefix("onThisDay")"#))
        #expect(model.contains("moments.insert(found.album, at: 0)"))
        let page = SourceSweep.code(try SourceSweep.read("Strata/Views/MemoriesView.swift"))
        #expect(page.contains("if !pageIsEmpty, count > 0 || !vm.monthAlbums.isEmpty {"))
        // No drawing of its own: it is an `Album`, on the one shelf.
        let own = SourceSweep.code(try SourceSweep.read("Strata/Models/Flashback.swift"))
        #expect(!own.contains("import SwiftUI"))
    }
}
