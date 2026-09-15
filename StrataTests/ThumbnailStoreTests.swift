import Testing
import Foundation
import Observation
import UIKit
@testable import Strata

/// **Why this exists.** Photographs stopped appearing on blocks anywhere in
/// the app while appearing perfectly in Memories. Traced on a running build:
/// the block's photograph view was built with the right file name, its body
/// was evaluated, and `.task` never ran — so the read was never requested.
/// Loading now happens because a view ASKS while drawing, which works in every
/// context SwiftUI has, including the ones with no appearance lifecycle.
///
/// Since 2026-09-15 each photograph has its own observed slot, reads are
/// capped, widths are bucketed, and a picture still alive survives the cache
/// evicting it. Each of those has a test below that fails if it is undone.
@MainActor
@Suite("ThumbnailStore", .serialized)
struct ThumbnailStoreTests {

    private func write(_ name: String, side: CGFloat = 40) throws -> String {
        let size = CGSize(width: side, height: side)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        let data = try #require(image.jpegData(compressionQuality: 0.9))
        let url = ImageManager.shared.imageDirectory.appendingPathComponent(name)
        try data.write(to: url)
        return name
    }

    private func waitForImage(_ name: String, width: CGFloat) async -> UIImage? {
        let store = ThumbnailStore.shared
        for _ in 0..<60 {
            if let image = store.image(for: name, width: width) { return image }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return nil
    }

    /// Lets every read already scheduled land.
    private func drain() async {
        for _ in 0..<60 where ThumbnailStore.shared.inFlightForTesting > 0 {
            try? await Task.sleep(for: .milliseconds(25))
        }
    }

    @Test("asking for a photograph that is not in memory schedules the read and reports it")
    func askingLoads() async throws {
        let name = try write("thumbnail-store-test.jpg")
        defer { ImageManager.shared.deleteImage(fileName: name) }
        let store = ThumbnailStore.shared
        store.forgetInFlight()
        let before = store.generationForTesting(name, width: 40)

        // The first ask comes back empty: nothing is in memory yet.
        #expect(store.image(for: name, width: 40) == nil)

        // And the read lands, which is what brings the drawing view back.
        for _ in 0..<40 where store.generationForTesting(name, width: 40) == before {
            try? await Task.sleep(for: .milliseconds(50))
        }
        #expect(store.generationForTesting(name, width: 40) != before, "the read never reported back")
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

    /// The one global `version` invalidated every image view in the app when
    /// any photograph landed. A view must now hear about its own photograph
    /// and nothing else.
    @Test("a landing invalidates only the views that asked for that photograph")
    func observationIsPerPhotograph() async throws {
        let mine = try write("thumbnail-store-mine.jpg")
        let other = try write("thumbnail-store-other.jpg")
        defer {
            ImageManager.shared.deleteImage(fileName: mine)
            ImageManager.shared.deleteImage(fileName: other)
        }
        let store = ThumbnailStore.shared
        store.forgetInFlight()
        await drain()

        final class Flag: @unchecked Sendable { var fired = false }

        // A view drawing a photograph already in memory: it reads its slot
        // and schedules nothing.
        #expect(await waitForImage(mine, width: 40) != nil)
        let quiet = Flag()
        withObservationTracking {
            _ = store.image(for: mine, width: 40)
        } onChange: {
            quiet.fired = true
        }
        // Somebody else's photograph arrives.
        #expect(await waitForImage(other, width: 40) != nil)
        #expect(!quiet.fired, "a view was invalidated by a photograph it never asked for")

        // A view asking for a photograph that is not in memory is told when
        // THAT one lands.
        ImageManager.shared.emptyThumbnailCacheForBenchmark()
        let asked = Flag()
        withObservationTracking {
            _ = store.image(for: mine, width: 40)
        } onChange: {
            asked.fired = true
        }
        for _ in 0..<60 where !asked.fired {
            try? await Task.sleep(for: .milliseconds(25))
        }
        #expect(asked.fired, "a view was not told its own photograph landed")
    }

    @Test("widths are rounded up to a bucket, never down")
    func widthsBucketUp() {
        #expect(ThumbnailStore.bucket(1) == 128)
        #expect(ThumbnailStore.bucket(128) == 128)
        #expect(ThumbnailStore.bucket(128.4) == 256)
        #expect(ThumbnailStore.bucket(222) == 256)
        #expect(ThumbnailStore.bucket(264) == 384)
        #expect(ThumbnailStore.bucket(390) == 512)
        #expect(ThumbnailStore.bucket(1024) == 1024)
        #expect(ThumbnailStore.bucket(1206) == 1206)
        for pixels in stride(from: CGFloat(1), through: 1400, by: 7.3) {
            #expect(CGFloat(ThumbnailStore.bucket(pixels)) >= pixels, "\(pixels) would decode softer")
        }
    }

    @Test("two nearby widths share one decode")
    func nearbyWidthsShareADecode() async throws {
        let name = try write("thumbnail-store-bucket.jpg", side: 600)
        defer { ImageManager.shared.deleteImage(fileName: name) }
        let store = ThumbnailStore.shared
        store.forgetInFlight()
        ImageManager.shared.emptyThumbnailCacheForBenchmark()
        #expect(await waitForImage(name, width: 222) != nil)
        // 255px is the same bucket: in memory already, no read.
        #expect(store.image(for: name, width: 255) != nil)
        #expect(store.inFlightForTesting == 0)
    }

    /// A fling asks for every cell it passes. Past the cap the asks wait, and
    /// the waiting ones are asked again (their slot bumps) as places free.
    @Test("reads past the in-flight cap wait and are asked again")
    func inFlightIsCapped() async throws {
        let store = ThumbnailStore.shared
        store.forgetInFlight()
        await drain()
        let cap = ThumbnailStore.maxInFlight
        let names = (0..<(cap + 12)).map { "no-such-capped-\($0).jpg" }
        // Synchronously, so nothing can land in between.
        for name in names { _ = store.image(for: name, width: 40) }
        #expect(store.inFlightForTesting == cap)
        #expect(store.deferredForTesting == 12)

        let waiting = names.suffix(12)
        #expect(waiting.allSatisfy { store.generationForTesting($0, width: 40) == 0 })
        await drain()
        for _ in 0..<40 where store.deferredForTesting > 0 {
            try? await Task.sleep(for: .milliseconds(25))
        }
        #expect(store.deferredForTesting == 0)
        #expect(waiting.allSatisfy { store.generationForTesting($0, width: 40) > 0 },
                "a deferred ask was never asked again")
        // Asked again, it is read.
        _ = store.image(for: waiting.last!, width: 40)
        for _ in 0..<40 where !store.state(for: waiting.last!, width: 40).missing {
            try? await Task.sleep(for: .milliseconds(25))
        }
        #expect(store.state(for: waiting.last!, width: 40).missing)
    }

    /// The filmstrip dimmed and re-faded after a switch to dark mode because
    /// the cache evicted pictures that were on screen. A picture something
    /// still holds must come back without a read.
    @Test("a picture still on screen survives the cache evicting it")
    func livePictureSurvivesEviction() async throws {
        let name = try write("thumbnail-store-live.jpg")
        defer { ImageManager.shared.deleteImage(fileName: name) }
        let store = ThumbnailStore.shared
        store.forgetInFlight()
        let shown = try #require(await waitForImage(name, width: 40))

        ImageManager.shared.evictThumbnailCacheForTesting()
        let again = store.image(for: name, width: 40)
        #expect(again === shown, "an on-screen picture was dropped by eviction")
        #expect(store.inFlightForTesting == 0, "an on-screen picture was read again")
        _ = shown
    }
}
