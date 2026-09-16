import Testing
import CoreGraphics
import UIKit
@testable import Strata

/// The mask that ends a made head: Core Image runs in the simulator, so the
/// alpha a real cut leaves can be pinned here even though capture cannot.
///
/// Expected values were measured with the identical Core Image graph off
/// device. Self-test: put `jawMarginReach` back to 1 and `jawEdgeSigma` to
/// 0.012 and the first probe reads 0.67.
@Suite("Head cut")
@MainActor
struct HeadCutTests {

    private func alphas(of image: UIImage) -> (Int, Int) -> Double {
        let side = 600
        var buffer = [UInt8](repeating: 0, count: side * side * 4)
        buffer.withUnsafeMutableBytes { raw in
            let context = CGContext(data: raw.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                    bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: side, height: side))
        }
        let copy = buffer
        // Bitmap memory row 0 is the top row.
        return { x, y in Double(copy[(y * side + x) * 4 + 3]) / 255 }
    }

    @Test("under the jaw the edge is sharp and tight; the ear keeps its soft edge")
    func theJawEdgeLeavesNoNeck() throws {
        let side: CGFloat = 600
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let white = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        }
        let contour = [CGPoint(x: 170, y: 320), CGPoint(x: 180, y: 420), CGPoint(x: 220, y: 500),
                       CGPoint(x: 300, y: 558), CGPoint(x: 380, y: 500), CGPoint(x: 420, y: 420),
                       CGPoint(x: 430, y: 320)]
        let outline = HeadFraming.headOutline(contour: contour.reversed(), canvas: side, margin: 40)
        let band = HeadFraming.sharpEdgeBand(contour: contour)
        let cut = try #require(HeadCaptureEngine.masked(white, to: outline, side: side,
                                                         sharpFrom: band.lowerBound, sharpBy: band.upperBound))
        let alpha = alphas(of: cut)
        #expect(alpha(195, 480) < 0.10)   // 15px outside the jaw corner (was 0.67)
        #expect(alpha(300, 564) < 0.15)   // 6px below the chin (was 0.33)
        // 5px inside the chin (was 0.75). 0.95 through the same Core Image
        // graph on macOS; 0.89 in the iOS 26.3 simulator.
        #expect(alpha(300, 553) > 0.85)
        #expect(alpha(150, 330) > 0.90)   // the ear
        #expect(alpha(120, 540) < 0.02)   // a shoulder

        // The probes can tell: the same outline with the soft hair edge all
        // the way down (the sharp band pushed off the canvas) leaves more
        // below the chin and less inside it.
        let soft = try #require(HeadCaptureEngine.masked(white, to: outline, side: side,
                                                          sharpFrom: side * 2, sharpBy: side * 3))
        let softAlpha = alphas(of: soft)
        #expect(softAlpha(300, 564) > alpha(300, 564) + 0.1)
        #expect(softAlpha(300, 553) < alpha(300, 553) - 0.05)
    }
}
