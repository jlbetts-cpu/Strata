import Testing
import Foundation
import UIKit
@testable import Strata

/// **Why this exists.** Photographs stopped appearing on blocks anywhere in
/// the app while appearing perfectly in Memories. Traced on a running build:
/// the block's photograph view was built with the right file name, its body
/// was evaluated, and `.task` never ran — so the read was never requested.
/// Loading now happens because a view ASKS while drawing, which works in every
/// context SwiftUI has, including the ones with no appearance lifecycle.
@MainActor
@Suite("ThumbnailStore")
struct ThumbnailStoreTests {

    private func write(_ name: String) throws -> String {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
        let data = try #require(image.jpegData(compressionQuality: 0.9))
        let url = ImageManager.shared.imageDirectory.appendingPathComponent(name)
        try data.write(to: url)
        return name
    }

    @Test("asking for a photograph that is not in memory schedules the read and reports it")
    func askingLoads() async throws {
        let name = try write("thumbnail-store-test.jpg")
        defer { ImageManager.shared.deleteImage(fileName: name) }
        let store = ThumbnailStore.shared
        store.forgetInFlight()
        let before = store.version

        // The first ask comes back empty: nothing is in memory yet.
        #expect(store.image(for: name, width: 40) == nil)

        // And the read lands, which is what brings the drawing view back.
        for _ in 0..<40 where store.version == before {
            try? await Task.sleep(for: .milliseconds(50))
        }
        #expect(store.version != before, "the read never reported back")
        #expect(store.image(for: name, width: 40) != nil, "the photograph is not in memory")
    }

    @Test("a file that is not there is reported missing rather than waited on forever")
    func missingIsReported() async throws {
        let store = ThumbnailStore.shared
        store.forgetInFlight()
        let name = "no-such-photograph.jpg"
        #expect(store.state(for: name, width: 40).missing == false)
        for _ in 0..<40 where store.state(for: name, width: 40).missing == false {
            try? await Task.sleep(for: .milliseconds(50))
        }
        #expect(store.state(for: name, width: 40).missing, "a missing file never resolved")
    }
}
