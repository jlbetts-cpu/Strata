import Testing
import CoreGraphics
@testable import Strata

/// The window a block cuts out of a photograph, and how far it may be dragged
/// on the camera's review before it leaves the picture.
@Suite("Block crop")
struct BlockCropTests {

    @Test("a tall photo in a wide block can only move up and down")
    func onlyTheOverflowingAxisMoves() {
        // A portrait photograph, 3:4, in a block wider than it is tall.
        let crop = BlockCropOutline.crop(photo: CGSize(width: 3000, height: 4000), block: .medium)
        let range = BlockCropOutline.range(for: crop)
        #expect(crop.width == 1)          // the full width is used
        #expect(range.width == 0)         // so there is nothing to slide sideways
        #expect(range.height > 0)         // the height overflows, and that can move
    }

    @Test("the window dragged all the way stops flush with the edge")
    func theWindowStaysOnThePhotograph() {
        let crop = BlockCropOutline.crop(photo: CGSize(width: 3000, height: 4000), block: .medium)
        let range = BlockCropOutline.range(for: crop)
        // Pushed to the limit in each direction, the window's far edge lands
        // exactly on the photograph's: no further, and no band of nothing.
        #expect(abs((crop.minY - range.height) - 0) < 0.0001)
        #expect(abs((crop.maxY + range.height) - 1) < 0.0001)
    }

    @Test("a photo that already matches the block cannot be dragged at all")
    func anExactFitIsPinned() {
        // A photograph cut to the block's own shape fills it with nothing spare.
        let aspect = BlockSize.small.cropAspectRatio
        let crop = BlockCropOutline.crop(photo: CGSize(width: aspect * 1000, height: 1000),
                                         block: .small)
        let range = BlockCropOutline.range(for: crop)
        #expect(abs(range.width) < 0.0001)
        #expect(abs(range.height) < 0.0001)
    }

    @Test("the same photograph moves further in a squarer block")
    func aTighterWindowHasMoreRoom() {
        let photo = CGSize(width: 3000, height: 4000)
        let sizes = BlockSize.allCases.map { size -> (BlockSize, CGFloat) in
            (size, BlockCropOutline.range(for: BlockCropOutline.crop(photo: photo, block: size)).height)
        }
        // Whatever the shapes are, a block whose window is shorter has more of
        // the photograph left over to slide through it.
        for (size, room) in sizes {
            let window = BlockCropOutline.crop(photo: photo, block: size).height
            #expect(abs(room - (1 - window) / 2) < 0.0001)
        }
    }

    /// What a block of `blockSize` shows of `photo` with the window moved by
    /// `crop`, in photo fractions. **The block's own mapping**
    /// (`CachedImageView.visibleRect`, which draws the picture), so a sign
    /// flipped there fails here.
    private func visible(photo: CGSize, block blockSize: BlockSize, crop: CGPoint) -> CGRect {
        let height: CGFloat = 120
        return CachedImageView.visibleRect(crop: crop, photo: photo,
                                           frame: CGSize(width: height * blockSize.cropAspectRatio, height: height))
    }

    @Test("the window follows the finger, and the block shows exactly what the window framed")
    func theWindowFollowsTheFinger() {
        // Owner: "the slider to crop feels the wrong way". A landscape photo
        // in a 1x1 block slides sideways.
        let photo = CGSize(width: 4000, height: 3000)
        let window = BlockCropOutline.crop(photo: photo, block: .small)
        let range = BlockCropOutline.range(for: window)
        let review = CGSize(width: 390, height: 292.5)
        let right = BlockCropOutline.dragged(from: .zero, translation: CGSize(width: 40, height: 0),
                                             in: review, range: range)
        let down = BlockCropOutline.dragged(from: .zero, translation: CGSize(width: 0, height: 40),
                                            in: review, range: range)
        #expect(right.x > 0)                       // finger right, window right
        #expect(abs(right.x - 40 / 390) < 0.0001)  // by exactly as far as the finger went
        #expect(down.y == 0)                       // no vertical room in this photo
        // Review: the hairline (BlockCropOutline.body) against the saved block.
        let shown = visible(photo: photo, block: .small, crop: right)
        #expect(abs(shown.minX - (window.minX + right.x)) < 0.001)
        #expect(abs(shown.width - window.width) < 0.001)
        // The picture inside the block moved left: its right-hand part shows.
        #expect(shown.midX > 0.5)
        // Dragged past the end it stops flush.
        let far = BlockCropOutline.dragged(from: .zero, translation: CGSize(width: 4000, height: 0),
                                           in: review, range: range)
        #expect(far.x == range.width)
        let back = BlockCropOutline.dragged(from: far, translation: CGSize(width: -8000, height: 0),
                                            in: review, range: range)
        #expect(back.x == -range.width)
    }

    @Test("a tall photo's window follows the finger down, and the block agrees")
    func theWindowFollowsTheFingerDown() {
        let photo = CGSize(width: 3000, height: 4000)
        let window = BlockCropOutline.crop(photo: photo, block: .medium)
        let range = BlockCropOutline.range(for: window)
        let moved = BlockCropOutline.dragged(from: .zero, translation: CGSize(width: 0, height: 30),
                                             in: CGSize(width: 300, height: 400), range: range)
        #expect(moved.y > 0)
        let shown = visible(photo: photo, block: .medium, crop: moved)
        #expect(abs(shown.minY - (window.minY + moved.y)) < 0.001)
        #expect(shown.midY > 0.5)
    }

    @Test("the picture moves the opposite way to the window, and a centred window does not move it")
    func thePictureMovesAgainstTheWindow() {
        let photo = CGSize(width: 4000, height: 3000)
        let frame = CGSize(width: 120, height: 120)
        #expect(CachedImageView.shift(crop: .zero, photo: photo, frame: frame) == .zero)
        let right = CachedImageView.shift(crop: CGPoint(x: 0.1, y: 0), photo: photo, frame: frame)
        #expect(right.width < 0)      // window right, picture left inside the block
        #expect(right.height == 0)
        // A centred window shows the middle of the photograph.
        let middle = CachedImageView.visibleRect(crop: .zero, photo: photo, frame: frame)
        #expect(abs(middle.midX - 0.5) < 0.0001)
        #expect(abs(middle.midY - 0.5) < 0.0001)
    }
}
