import Foundation
import Testing
import UIKit
@testable import Strata

/// A strip's exported picture is cut to what is drawn, and never loses an
/// end (the owner, 2026-10-13: "when exporting strips sometimes the top gets
/// cut off a bit").
@MainActor
@Suite("A strip's export is cut to the strip")
struct StripTrimTests {
    /// A clear canvas with a filled band, `top` points from the top.
    private func canvas(width: Int = 100, height: Int = 100, top: Int, rows: Int) -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 20, y: top, width: 60, height: rows))
        }.cgImage
    }

    @Test("a band off the middle is kept where it is, not mirrored")
    func offCentre() throws {
        // Ink on rows 10 to 39: the crop must be those rows. Mirrored, it was
        // rows 60 to 89, which are empty.
        let image = try #require(canvas(top: 10, rows: 30))
        let cut = try #require(StripStory.trim(image, margin: 0))
        #expect(cut.width == 60 && cut.height == 30)
        // Its whole area averaged into one pixel of alpha: full when the
        // crop holds the band, nothing when it was taken from the other end.
        var alpha: UInt8 = 0
        let context = try #require(CGContext(data: &alpha, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 1,
                                             space: CGColorSpaceCreateDeviceGray(),
                                             bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue))
        context.interpolationQuality = .medium
        context.draw(cut, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        #expect(alpha > 200, "the crop is empty: it was taken from the wrong end")
    }

    @Test("the margin is kept on every side, and never past the canvas")
    func margin() throws {
        let image = try #require(canvas(top: 1, rows: 30))
        let cut = try #require(StripStory.trim(image, margin: 2))
        // Two to the left, right and below; one above, where the canvas ends.
        #expect(cut.width == 64 && cut.height == 33)
    }

    @Test("a centred band is unchanged by the fix")
    func centred() throws {
        let image = try #require(canvas(top: 35, rows: 30))
        let cut = try #require(StripStory.trim(image, margin: 2))
        #expect(cut.width == 64 && cut.height == 34)
    }
}
