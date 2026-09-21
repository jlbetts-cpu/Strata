import Testing
import CoreGraphics
@testable import Strata

/// **Where a cover fit crops from.**
///
/// Rendered both ways on four of the owner's own photographs at a real tile
/// size, the centre crop won three of four, and he took it: "I think centre
/// crop might look better."
///
/// These exist because the anchor was a SwiftUI DEFAULT rather than a
/// decision: `scaledToFill` centres and nothing said so. An implicit default
/// is exactly the thing a later refactor moves without noticing.
struct CropAnchorTests {

    /// A tall photograph into a wide tile: the crop is vertical, so the
    /// vertical anchor is what these measure.
    private let photo = CGSize(width: 900, height: 1200)
    private let tile = CGSize(width: 197, height: 148)

    @Test("a cover fit crops from the centre, not from one third down")
    func anchorsToTheCentre() {
        let r = CachedImageView.visibleRect(crop: .zero, photo: photo, frame: tile)
        // Centred means the discarded band is split evenly, so the visible
        // window's midpoint sits at 0.5 of the photograph.
        let midY = r.midY
        #expect(abs(midY - 0.5) < 0.001,
                "the window's centre is at \(midY) of the photograph, not 0.5")
        // And a third from the top would put it here. The difference is the
        // thing this test exists to keep.
        let oneThirdMid = (r.height / 2) + (1 - r.height) / 3
        #expect(abs(midY - oneThirdMid) > 0.02,
                "the centre and the one-third anchors are indistinguishable at this size, so this test proves nothing")
    }

    @Test("it is horizontally centred too, on a wide photograph")
    func anchorsToTheCentreHorizontally() {
        let wide = CGSize(width: 1600, height: 900)
        let square = CGSize(width: 148, height: 148)
        let r = CachedImageView.visibleRect(crop: .zero, photo: wide, frame: square)
        #expect(abs(r.midX - 0.5) < 0.001)
    }

    @Test("a drawn crop still moves the window off the centre")
    func aChosenCropStillWins() {
        // The anchor is where a crop of zero lands. Somebody who drags the
        // photograph in the camera's review still gets what they chose.
        let moved = CachedImageView.visibleRect(crop: CGPoint(x: 0, y: 0.1),
                                                photo: photo, frame: tile)
        #expect(moved.midY > 0.5)
    }
}
