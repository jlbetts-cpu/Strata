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
}
