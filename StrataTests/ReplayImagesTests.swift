import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import Strata

@Suite("Replay images")
struct ReplayImagesTests {

    @Test("a photograph is decoded for its largest block, never more than the two cells every one used to get")
    func decodeSide() {
        #expect(ReplayImages.decodeSide(cellPixels: 267, span: 1) == 356)
        #expect(ReplayImages.decodeSide(cellPixels: 267, span: 2) == 534)
        // A 1x1's decode is under half the pixels of the old two-cell one.
        let small = ReplayImages.decodeSide(cellPixels: 267, span: 1)
        let old = CGFloat(267 * 2)
        #expect((small * small) / (old * old) < 0.45)
    }

    @Test("a 3:4 photograph still fills a square block at one pixel per pixel")
    func smallBlockStaysSharp() {
        let cell: CGFloat = 237 // the Share card's cell at 3x
        let longest = ReplayImages.decodeSide(cellPixels: cell, span: 1)
        #expect(longest * 3 / 4 >= cell - 0.5)
    }

    @Test("one decode per photograph, sized by the largest block that shows it")
    @MainActor func perPhotoSizes() async {
        let r = ReplaySample.replay(.month, now: Date(timeIntervalSince1970: 1_789_300_000))
        var spans: [ReplayPhoto: Int] = [:]
        for b in r.blocks { if let p = b.win.photo { spans[p] = max(spans[p] ?? 0, max(b.columnSpan, b.rowSpan)) } }
        #expect(spans.values.contains(1) && spans.values.contains(2), "the sample month needs both sizes to test this")
        let cellPixels: CGFloat = 120
        let images = await ReplayImages.load(r, cellPixels: cellPixels)
        for (photo, span) in spans {
            guard let image = images[photo] else { Issue.record("\(photo.key) did not load"); continue }
            let longest = max(image.size.width * image.scale, image.size.height * image.scale)
            let side = ReplayImages.decodeSide(cellPixels: cellPixels, span: span)
            #expect(abs(longest - side) <= 1, "\(photo.key) for a span of \(span) decoded at \(longest)px, wanted \(side)px")
        }
    }
}

@Suite("Replay video export failures")
struct ReplayExportFailureTests {
    @Test("an encoder error after a cancel is reported as the cancel, not a failed save")
    func errorRacingACancelIsTheCancel() {
        let encoder = ReplayVideoExporter.Failure.writer("encoder invalidated")
        if case .cancelled = ReplayVideoExporter.failure(encoder, cancelRequested: true) as? ReplayVideoExporter.Failure {} else {
            Issue.record("a writer error after cancel() should come out as .cancelled")
        }
        if case .writer(let why) = ReplayVideoExporter.failure(encoder, cancelRequested: false) as? ReplayVideoExporter.Failure {
            #expect(why == "encoder invalidated")
        } else {
            Issue.record("without a cancel the original error must come through")
        }
    }
}
