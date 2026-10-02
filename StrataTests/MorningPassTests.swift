import Foundation
import Testing
@testable import Strata

/// **The morning pass, 2026-10-02, pinned.**
///
/// Open items from `docs/design-review/` that became reachable once the review
/// agents finished: what VoiceOver says for a photograph and a map block, the
/// future days of the month, and a block that presses with nowhere to go.
@Suite("Morning pass, 2026-10-02")
struct MorningPassTests {

    @Test("an untitled photograph is spoken with its day, not as a bare \"Photo\"")
    func untitledPhotoHasADay() {
        var parts = DateComponents()
        parts.year = 2026; parts.month = 9; parts.day = 21; parts.hour = 12
        let date = Calendar.current.date(from: parts)!
        let untitled = GalleryPhoto(fileName: "a.jpg", title: nil, date: date, dateString: "2026-09-21")
        let titled = GalleryPhoto(fileName: "b.jpg", title: "Ran 5k", date: date, dateString: "2026-09-21")
        #expect(untitled.spokenName.hasPrefix("Photo, "))
        #expect(untitled.spokenName.contains("21"))
        #expect(untitled.spokenName != "Photo")
        #expect(titled.spokenName.hasPrefix("Ran 5k, "))
    }

    @Test("no photograph label falls back to the bare word")
    func noBareFallbackLeft() throws {
        for file in ["Views/PhotoGalleryGrid.swift", "Views/PhotoViewer.swift"] {
            let text = try source(file)
            #expect(!text.contains(".accessibilityLabel(photo.title ?? \"Photo\")"), "\(file)")
            #expect(text.contains(".accessibilityLabel(photo.spokenName)"), "\(file)")
        }
    }

    @Test("a day still to come is hidden from VoiceOver; a past empty day is not")
    func futureDaysAreNotStops() throws {
        let text = try source("Views/MonthCalendarView.swift")
        #expect(text.contains(".accessibilityHidden(isFuture)"))
        #expect(!text.contains("to come\""))
    }

    @Test("a block with no tap does not press")
    func noPressWithoutADestination() throws {
        let block = try source("Views/FlippableBlockView.swift")
        #expect(block.contains("including: onTap == nil ? .subviews : .all"))
        let album = try source("Views/DayAlbumDetailView.swift")
        #expect(album.contains("canTapBlock: { $0.log.imageFileName != nil }"))
    }

    @Test("a map block says its place's name once known")
    func mapBlockSaysItsName() throws {
        let text = try source("Views/MemoriesMapView.swift")
        #expect(text.contains(".accessibilityLabel(spokenName)"))
        #expect(text.contains("PlaceNames.shared.name(for: place)"))
    }

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent("Strata").appendingPathComponent(path),
                          encoding: .utf8)
    }
}
