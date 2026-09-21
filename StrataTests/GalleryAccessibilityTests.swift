import Testing
import Foundation
@testable import Strata

/// What VoiceOver is told about a photograph.
///
/// Found while rebuilding the gallery on the Apollo branch: every untitled
/// photograph carried the literal label "Photo", so swiping a month read
/// "Photo, Photo, Photo" several hundred times. A label identical for every
/// element in a collection is the same as no label at all.
struct GalleryAccessibilityTests {

    private func photo(title: String?, date: Date) -> GalleryPhoto {
        GalleryPhoto(fileName: UUID().uuidString + ".jpg",
                     title: title,
                     date: date,
                     dateString: DateUtils.dateString(from: date))
    }

    @Test("a named win says its name")
    func namedWinsSayTheirName() {
        let p = photo(title: "Morning run", date: Date())
        #expect(p.accessibilityName == "Morning run")
    }

    @Test("two untitled photographs never say the same thing")
    func untitledPhotographsAreDistinguishable() {
        let a = photo(title: nil, date: Date(timeIntervalSince1970: 1_700_000_000))
        let b = photo(title: nil, date: Date(timeIntervalSince1970: 1_700_090_000))
        #expect(a.accessibilityName != b.accessibilityName,
                "every untitled photograph reads the same to VoiceOver")
        #expect(a.accessibilityName != "Photo")
    }

    @Test("an empty title is treated as no title")
    func emptyTitlesFallBack() {
        let p = photo(title: "", date: Date())
        #expect(!p.accessibilityName.isEmpty)
    }
}
