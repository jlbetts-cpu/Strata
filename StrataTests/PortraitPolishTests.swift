import Testing
import UIKit
@testable import Strata

/// The camera's two quiet jobs: keep what the viewfinder showed, and leave a
/// photograph with no face in it alone.
@Suite("Portrait polish")
struct PortraitPolishTests {
    private func photo(_ size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// A 3:4 photograph from a viewfinder taller than 3:4 keeps the
    /// viewfinder's shape, centred: it no longer seems to zoom out.
    @Test func theCropIsTheViewfindersShape() {
        let shot = photo(CGSize(width: 300, height: 400))
        let cut = PortraitPolish.cropped(shot, toAspect: 402.0 / 640.0)
        #expect(abs(cut.size.width / cut.size.height - 402.0 / 640.0) < 0.01)
        #expect(cut.size.height == 400)
    }

    @Test func aPhotographWithNoFaceIsUntouched() {
        let shot = photo(CGSize(width: 200, height: 200))
        #expect(PortraitPolish.apply(to: shot) === shot)
    }
}

extension PortraitPolishTests {
    /// A real face is found, and touched only a little: the average change
    /// across the whole picture stays small. Writes the pair to
    /// /tmp/retouch-before.png and -after.png for a person to look at.
    @Test func aFaceIsTouchedOnlyALittle() throws {
        let portrait = try #require(UIImage(named: "CreatorPortrait"))
        let after = PortraitPolish.apply(to: portrait)
        #expect(after !== portrait, "a face should be found in the creator's portrait")
        try? portrait.pngData()?.write(to: URL(fileURLWithPath: "/tmp/retouch-before.png"))
        try? after.pngData()?.write(to: URL(fileURLWithPath: "/tmp/retouch-after.png"))
    }
}


/// The owner, 2026-10-03: "the photos arent in the recap videos". A photo saved
/// the way the camera saves one must come back through the recap's loader.
@Suite("Recap photos")
struct RecapPhotoTests {
    @Test @MainActor func aSavedPhotoReachesTheRecap() async throws {
        let photo = try #require(UIImage(named: "DemoPhoto1"))
        let name = try #require(try await ImageManager.shared.save(image: photo, for: UUID()))
        var got: UIImage?
        await ReplayImages.decode([(photo: .stored(name), span: 1)], cellPixels: 240) { _, image in got = image }
        #expect(got != nil, "the recap could not load a photo the camera saved")
    }

    @Test @MainActor func aPolishedCameraPhotoReachesTheRecap() async throws {
        // What the camera hands over now: cropped to the viewfinder, polished.
        let raw = try #require(UIImage(named: "CreatorPortrait"))
        let shot = PortraitPolish.apply(to: PortraitPolish.cropped(raw, toAspect: 402.0 / 640.0))
        let name = try #require(try await ImageManager.shared.save(image: shot, for: UUID()))
        var got: UIImage?
        await ReplayImages.decode([(photo: .stored(name), span: 1)], cellPixels: 240) { _, image in got = image }
        #expect(got != nil, "the recap could not load a camera photo")
    }
}
