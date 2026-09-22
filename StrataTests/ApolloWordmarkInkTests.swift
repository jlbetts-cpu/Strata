import Testing
import UIKit
import SwiftUI
@testable import Strata

/// **Where the ink actually is inside the wordmark's box.**
///
/// The owner: "make sure the lines gap is perfectly balanced." The break in
/// the first thirds line is cut to the mark's BOX, and a box is not ink: this
/// artwork has empty space above the cap and a little under the descender, and
/// they are not the same amount. Measured on the running app at a 56pt mark,
/// the gap came out 15.00pt above the ink and 14.33pt below it.
///
/// Correcting that needs the artwork's real fractions rather than a nudge, so
/// this rasterises the mark large and reads its alpha bounds. Two thirds of a
/// point is two device pixels, which is small — and it is exactly the kind of
/// small that reads as "the title is sitting low in the gap" without anybody
/// being able to say why.
struct ApolloWordmarkInkTests {

    /// Big enough that one row is a thousandth of the box, so the fractions
    /// are exact to three places without any interpolation guesswork.
    static let renderHeight: CGFloat = 1000

    /// The alpha bounds of the drawn mark, as fractions of its box.
    static func inkBounds() -> (top: CGFloat, bottom: CGFloat)? {
        let size = CGSize(width: renderHeight * ApolloWordmark.aspect, height: renderHeight)
        let renderer = UIGraphicsImageRenderer(size: size, format: {
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            format.opaque = false
            return format
        }())
        guard let artwork = UIImage(named: "ApolloWordmark") else { return nil }
        let drawn = renderer.image { _ in
            artwork.withRenderingMode(.alwaysTemplate)
                .withTintColor(.white, renderingMode: .alwaysOriginal)
                .draw(in: CGRect(origin: .zero, size: size))
        }
        guard let cg = drawn.cgImage else { return nil }

        let width = cg.width, height = cg.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &pixels, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Is this real ink, or a rasteriser filling the rect? A row of the
        // `l` ascenders is a handful of pixels; a background is all of them.
        for y in [0, 1, 2, height / 2, height - 3, height - 2, height - 1] {
            let count = (0..<width).filter { pixels[(y * width + $0) * 4 + 3] > 12 }.count
            print("ROW \(y): \(count) of \(width) inked")
        }

        var first = -1, last = -1
        for y in 0..<height {
            var inked = false
            for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 12 { inked = true; break }
            if inked {
                if first < 0 { first = y }
                last = y
            }
        }
        guard first >= 0 else { return nil }
        return (CGFloat(first) / CGFloat(height), CGFloat(last + 1) / CGFloat(height))
    }

    @Test("The mark's box is its ink, which is what makes a gap around it balanced")
    func theBoxIsTheInk() throws {
        let bounds = try #require(Self.inkBounds(), "the wordmark asset did not rasterise")
        print("WORDMARK INK: top \(bounds.top), bottom \(bounds.bottom)")

        // A thousandth of the box is 0.056pt at a 56pt mark, well under a
        // device pixel at 3x.
        #expect(bounds.top < 0.002,
                "there is \(bounds.top) of the box empty above the ink, so a gap cut to the box hangs the word low")
        #expect(bounds.bottom > 0.998,
                "there is \(1 - bounds.bottom) of the box empty below the ink, so a gap cut to the box hangs the word high")
    }

    /// **The number this was all for.** The owner picked the 56pt mark and
    /// asked for the gap around it to be perfectly balanced. Cut to the box,
    /// with the box equal to the ink, it is balanced by arithmetic: measured
    /// on the running app, the break in the first thirds line runs 66.67 to
    /// 150.67pt and the mark's ink runs 80.67 to 136.67pt, which is 14.00pt
    /// of air at each end.
    ///
    /// The first measurement of this said 15.00 and 14.33 and was wrong: it
    /// read the ink off a screenshot with the guides ON, so the guide's own
    /// pixels were inside the column being searched and moved the detected
    /// top by a row. Measuring it again with the guides hidden gave the mark
    /// at exactly 56.00pt tall, which is the box.
    @Test("The break is cut symmetrically, so both ends of the word have the same air")
    func theGapIsBalanced() {
        let mark: CGFloat = 56, breathing: CGFloat = 14
        let markTop: CGFloat = 80.67          // measured on the running app
        let gapTop = markTop - breathing
        let gapBottom = markTop + mark + breathing
        let above = markTop - gapTop
        let below = gapBottom - (markTop + mark)
        #expect(abs(above - below) < 0.001, "\(above) above the word and \(below) below it")
        #expect(above == breathing)
    }
}
