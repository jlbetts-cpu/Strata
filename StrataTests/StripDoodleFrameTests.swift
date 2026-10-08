import Testing
import UIKit
@testable import Strata

/// A doodle on a strip is drawn whole, its block's colour either side.
///
/// Self-test: sample the centre instead of the corner in `cornerColour` and
/// `theBandIsTheBlocksColour` fails with the doodle's ink as the band.
@Suite("StripDoodleFrame")
@MainActor
struct StripDoodleFrameTests {
    @Test("the band either side of a fitted doodle is its block's colour, not its ink")
    func theBandIsTheBlocksColour() {
        let side: CGFloat = 120
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { context in
            UIColor(red: 0.1, green: 0.7, blue: 0.4, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            UIColor.black.setFill()
            context.fill(CGRect(x: side * 0.3, y: side * 0.3, width: side * 0.4, height: side * 0.4))
        }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        image.cornerColour.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(r - 0.1) < 0.05 && abs(g - 0.7) < 0.05 && abs(b - 0.4) < 0.05,
                "sampled \(r), \(g), \(b)")
    }

    @Test("a frame is a doodle when the win has no photograph")
    func frameFlag() {
        let frame = PhotoStrip.Frame(id: UUID(), title: "", size: .small, picture: UIImage(), isDoodle: true)
        #expect(frame.isDoodle)
        #expect(!PhotoStrip.Frame(id: UUID(), title: "", size: .small, picture: UIImage()).isDoodle)
    }
}
