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

    /// A missing file used to be read again every time its view asked, and
    /// every read that found nothing bumped the slot, which made the view ask
    /// again: a read and a body per frame, for ever, holding a place in the
    /// flight. A view drawing it keeps asking here, as a body would.
    @Test("a missing file is read once, not once per frame")
    func missingIsNotReadAgain() async throws {
        let store = ThumbnailStore.shared
        store.forgetInFlight()
        await drain()
        let name = "no-such-photograph-loop.jpg"
        for _ in 0..<40 where !store.state(for: name, width: 40).missing {
            try? await Task.sleep(for: .milliseconds(25))
        }
        #expect(store.state(for: name, width: 40).missing)
        let settled = store.generationForTesting(name, width: 40)
        for _ in 0..<20 {
            _ = store.state(for: name, width: 40)
            try? await Task.sleep(for: .milliseconds(20))
        }
        #expect(store.generationForTesting(name, width: 40) == settled,
                "a missing file kept being read and kept redrawing its view")
        #expect(store.inFlightForTesting == 0)
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

    @Test("widths are rounded up to a bucket, never down, and never past 1.4x the pixels")
    func widthsBucketUp() {
        #expect(ThumbnailStore.bucket(1) == 128)
        #expect(ThumbnailStore.bucket(128) == 128)
        #expect(ThumbnailStore.bucket(128.4) == 144)
        #expect(ThumbnailStore.bucket(222) == 224)
        #expect(ThumbnailStore.bucket(389) == 432)
        #expect(ThumbnailStore.bucket(1024) == 1024)
        #expect(ThumbnailStore.bucket(1206) == 1206)
        for pixels in stride(from: CGFloat(1), through: 1400, by: 3.7) {
            let bucket = CGFloat(ThumbnailStore.bucket(pixels))
            #expect(bucket >= pixels, "\(pixels) would decode softer")
            if pixels >= 109 {
                #expect((bucket / pixels) * (bucket / pixels) < 1.4,
                        "\(pixels) decodes at \(bucket), too many extra pixels")
            }
        }
        // A caller with its own decode width (the map) gets exactly that.
        #expect(ThumbnailStore.bucket(264, exact: true) == 264)
        #expect(ThumbnailStore.bucket(263.2, exact: true) == 264)
    }

    @Test("two nearby widths share one decode")
    func nearbyWidthsShareADecode() async throws {
        let name = try write("thumbnail-store-bucket.jpg", side: 600)
        defer { ImageManager.shared.deleteImage(fileName: name) }
        let store = ThumbnailStore.shared
        store.forgetInFlight()
        ImageManager.shared.emptyThumbnailCacheForBenchmark()
        #expect(await waitForImage(name, width: 222) != nil)
        // 224px is the same bucket: in memory already, no read.
        #expect(store.image(for: name, width: 224) != nil)
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

    /// Asks from cells that scrolled away must not pile up without limit, and
    /// letting one go tells its view — which must happen AFTER the pass that
    /// asked, never inside it.
    @Test("the oldest asks are let go once the pass is over, and their views are told")
    func deferredIsCapped() async throws {
        let store = ThumbnailStore.shared
        store.forgetInFlight()
        await drain()
        // Far more than the queue holds, so it is still over the cap when the
        // trim runs even as the first reads land.
        let names = (0..<(ThumbnailStore.maxInFlight + ThumbnailStore.maxDeferred + 400))
            .map { "no-such-deferred-\($0).jpg" }
        // One pass, as a body would: nothing may be let go or invalidated.
        for name in names { _ = store.image(for: name, width: 40) }
        #expect(store.inFlightForTesting == ThumbnailStore.maxInFlight)
        let waiting = names[ThumbnailStore.maxInFlight...]
        #expect(waiting.allSatisfy { store.generationForTesting($0, width: 40) == 0 },
                "an ask was let go, and its view invalidated, during the pass")

        // The oldest go on the next turn. Only asks made before the overflow
        // was noticed can go; the rest are this pass's own and are kept.
        let oldest = names[ThumbnailStore.maxInFlight..<(ThumbnailStore.maxInFlight + 50)]
        for _ in 0..<40 where oldest.contains(where: { store.waitingNamesForTesting.contains($0) }) {
            try? await Task.sleep(for: .milliseconds(25))
        }
        let stillWaiting = store.waitingNamesForTesting
        #expect(oldest.allSatisfy { !stillWaiting.contains($0) }, "an old ask was kept over newer ones")
        #expect(oldest.allSatisfy { store.generationForTesting($0, width: 40) > 0 },
                "an ask was let go without telling the view that made it")
        #expect(store.deferredForTesting < ThumbnailStore.maxInFlight + ThumbnailStore.maxDeferred + 400)
        store.forgetInFlight()
        await drain()
    }

    /// A file that arrives after its log — a restore, or a save landing late —
    /// must not stay missing until something unrelated redraws.
    @Test("a photograph written after it was asked for wakes the views that asked")
    func arrivalWakesTheViews() async throws {
        let store = ThumbnailStore.shared
        store.forgetInFlight()
        await drain()
        let name = "thumbnail-store-late.jpg"
        for _ in 0..<40 where !store.state(for: name, width: 40).missing {
            try? await Task.sleep(for: .milliseconds(25))
        }
        #expect(store.state(for: name, width: 40).missing)
        let settled = store.generationForTesting(name, width: 40)

        _ = try write(name)
        defer { ImageManager.shared.deleteImage(fileName: name) }
        store.fileArrived(name)
        #expect(store.generationForTesting(name, width: 40) > settled,
                "the views that asked were never told the file arrived")
        #expect(await waitForImage(name, width: 40) != nil)
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

/// The photo viewer's strip draws only the cards near its middle. On a
/// phone about four either side fit; on an iPad many more, and a fixed
/// window left cards on screen undrawn.
@MainActor
@Suite("Filmstrip window")
struct FilmstripWindowTests {
    @Test("every card any part of which is on screen is drawn, at phone and iPad widths")
    func coversTheStrip() {
        let pitch = Filmstrip.pitch
        var undrawn: [String] = []
        for width in [320.0, 393, 440, 768, 1032, 1366] as [CGFloat] {
            for progress in stride(from: 0.0, through: 60.0, by: 0.25) {
                guard let range = Filmstrip.window(progress: progress, count: 61, width: width) else {
                    Issue.record("no window"); continue
                }
                for i in 0...60 {
                    // Card i's left edge, in the strip's coordinates.
                    let left = width / 2 - Filmstrip.card.width / 2 + CGFloat(Double(i) - progress) * pitch
                    let onScreen = left < width && left + Filmstrip.card.width > 0
                    if onScreen, !range.contains(i) {
                        undrawn.append("card \(i) at width \(width), progress \(progress)")
                    }
                }
                // The neighbours are always drawn, for VoiceOver.
                let centre = Int(progress.rounded())
                for n in [centre - 1, centre + 1] where (0...60).contains(n) && !range.contains(n) {
                    undrawn.append("neighbour \(n) at width \(width), progress \(progress)")
                }
            }
        }
        #expect(undrawn.isEmpty, "\(undrawn.count) on screen but not drawn, first: \(undrawn.first ?? "")")
    }
}
