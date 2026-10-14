import Foundation
import Testing
@testable import Strata

/// **Memories, split by size** (the owner, 2026-10-14: "keep the apple photos
/// look while splitting it into sizes"). `Album.sizeSections`.
struct MemoriesBySizeTests {
    private func photo(_ name: String, _ size: BlockSize, day: Int) -> GalleryPhoto {
        var p = GalleryPhoto(fileName: name, title: nil,
                             date: Date(timeIntervalSince1970: 1_790_000_000 - Double(day) * 86_400),
                             dateString: "2026-10-\(String(format: "%02d", 14 - day))")
        p.size = size
        return p
    }

    @Test("Deep, then Regular, then Quick, each in the month's own order")
    func order() {
        let month = GallerySection(id: "2026-10", title: "October", photos: [
            photo("a", .small, day: 0), photo("b", .hard, day: 1), photo("c", .medium, day: 2),
            photo("d", .hard, day: 3), photo("e", .small, day: 4)])
        let split = Album.sizeSections(month)
        #expect(split.map(\.title) == ["Deep", "Regular", "Quick"])
        #expect(split[0].photos.map(\.fileName) == ["b", "d"])
        #expect(split[2].photos.map(\.fileName) == ["a", "e"])
        #expect(Set(split.map(\.id)).count == split.count)
        #expect(split.allSatisfy { $0.id.hasPrefix("2026-10-") })
    }

    @Test("a size with no photographs has no section, and one size is one section")
    func empty() {
        let two = GallerySection(id: "m", title: "M", photos: [photo("a", .small, day: 0), photo("b", .hard, day: 1)])
        #expect(Album.sizeSections(two).map(\.title) == ["Deep", "Quick"])
        let one = GallerySection(id: "m", title: "M", photos: [photo("a", .medium, day: 0), photo("b", .medium, day: 1)])
        #expect(Album.sizeSections(one).count == 1)
    }
}
