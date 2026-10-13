import Foundation
import Testing
@testable import Strata

/// The month's albums on Memories (`Album.monthShelf`,
/// `tasks/unification-log.md` §2).
@Suite("Memories: the month's albums")
struct MonthShelfTests {
    private func record(_ title: String, _ day: String, id: UUID = UUID(), photo: Bool = true) -> WinRecord {
        WinRecord(dateString: day, completedAt: DateUtils.date(from: day) ?? Date(), title: title,
                  category: .health, size: .small, photoFileName: photo ? "\(UUID()).jpg" : nil, id: id)
    }

    @Test("a crew album holds your wins sent to that crew, that month only")
    func crewAlbum() {
        let sent = (0..<4).map { _ in UUID() }
        var records = sent.enumerated().map { record("Run \($0.offset)", "2026-10-0\($0.offset + 1)", id: $0.element) }
        records.append(record("Run", "2026-09-30", id: UUID()))
        let crew = Album.ShelfCrew(id: "crew-1", name: "Ana's crew", wins: Set(sent))
        let shelf = Album.monthShelf(records: records, month: "2026-10", crews: [crew], moments: [])
        let album = try? #require(shelf.first)
        // "Shared with": the album is what you sent there, not who is in
        // the pictures (the owner, 2026-10-13, of "With Jolee").
        #expect(album?.title == "Shared with Ana's crew")
        #expect(album?.winCount == 4)
        #expect(album?.route == .crew("crew-1@2026-10"))
        // September is another month's page.
        #expect(Album.monthShelf(records: records, month: "2026-09", crews: [crew], moments: []).isEmpty)
    }

    @Test("two photographs to a crew is not yet an album")
    func crewNeedsThree() {
        let sent = [UUID(), UUID()]
        let records = sent.map { record("Run", "2026-10-02", id: $0) }
        let crew = Album.ShelfCrew(id: "crew-1", name: "Ana's crew", wins: Set(sent))
        #expect(Album.monthShelf(records: records, month: "2026-10", crews: [crew], moments: []).isEmpty)
    }

    @Test("an interest needs three photographs over two days")
    func interests() {
        let oneDay = (0..<5).map { _ in record("Gym", "2026-10-03") }
        #expect(Album.monthShelf(records: oneDay, month: "2026-10", crews: [], moments: []).isEmpty)
        let twoDays = [record("Gym", "2026-10-03"), record("gym", "2026-10-03"), record("Gym", "2026-10-05")]
        let shelf = Album.monthShelf(records: twoDays, month: "2026-10", crews: [], moments: [])
        #expect(shelf.count == 1)
        #expect(shelf.first?.title == "Gym")
        if case .curated(let key) = shelf.first?.kind {
            #expect(Album.splitMonth(key).month == "2026-10")
        } else {
            Issue.record("an interest album")
        }
    }

    @Test("moments first, and never more than five cards")
    func capped() {
        var records: [WinRecord] = []
        for title in ["A", "B", "C", "D", "E", "F", "G"] {
            records += [record("\(title) walk", "2026-10-01"), record("\(title) walk", "2026-10-02"),
                        record("\(title) walk", "2026-10-03")]
        }
        let moment = Album(id: "moment:x", kind: .moment("x"), title: "A year ago today", subtitle: "3 PHOTOS",
                           sortDate: Date(), photoFileNames: [], winCount: 3, haystack: "")
        let shelf = Album.monthShelf(records: records, month: "2026-10", crews: [], moments: [moment])
        #expect(shelf.count == Album.monthShelfMax)
        #expect(shelf.first?.id == "moment:x")
    }

    @Test("a shelf key splits into its title and month, and nothing else does")
    func keys() {
        let split = Album.splitMonth("gym session@2026-10")
        #expect(split.key == "gym session" && split.month == "2026-10")
        #expect(Album.splitMonth("gym session").month == nil)
        #expect(Album.splitMonth("me@home").month == nil)
    }

    /// The owner, 2026-10-12: "I got an album called 'With' nothing after it
    /// and it was lowkey a duplicate of the album before it which actually
    /// said who it was with."
    @Test("a crew with no name still names its album, and two crews with the same wins are one album")
    func noBareWithAndNoTwin() {
        let sent = (0..<4).map { _ in UUID() }
        let records = sent.enumerated().map { record("Run \($0.offset)", "2026-10-0\($0.offset + 1)", id: $0.element) }
        let named = Album.ShelfCrew(id: "crew-1", name: "Roommates", wins: Set(sent))
        let unnamed = Album.ShelfCrew(id: "crew-2", name: "  ", wins: Set(sent))
        // The same four wins went to both crews: one album, the first crew's.
        let shelf = Album.monthShelf(records: records, month: "2026-10", crews: [unnamed, named], moments: [])
        #expect(shelf.map(\.title) == ["Shared with Roommates"])
        // Alone, a crew with no name of its own is never "With" and nothing.
        let alone = Album.monthShelf(records: records, month: "2026-10", crews: [unnamed], moments: [])
        #expect(alone.map(\.title) == ["Shared with Your Crew"])
        #expect(!alone.contains { $0.title.trimmingCharacters(in: .whitespaces).hasSuffix("with") })
        // A crew holding different wins is its own album.
        let more = (0..<3).map { _ in UUID() }
        let extra = more.enumerated().map { record("Read \($0.offset)", "2026-10-1\($0.offset)", id: $0.element) }
        let other = Album.ShelfCrew(id: "crew-3", name: "Run Club", wins: Set(more))
        let both = Album.monthShelf(records: records + extra, month: "2026-10", crews: [named, other], moments: [])
        #expect(Set(both.map(\.title)) == ["Shared with Roommates", "Shared with Run Club"])
        // No crew album says a person is in the pictures.
        #expect(!both.contains { $0.title.hasPrefix("With ") })
    }
}
