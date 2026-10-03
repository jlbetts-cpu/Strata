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
