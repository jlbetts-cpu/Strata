import Testing
import Foundation
import CoreGraphics
import UIKit
@testable import Strata

/// A made head's faces made as consistent as the creator's, from its own
/// captures; and the maker's second ask for a missed blink.
@Suite("HeadDerivation")
struct HeadDerivationTests {

    private func flat(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, side: Int = 120) -> CGImage {
        let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(red: r, green: g, blue: b, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        return context.makeImage()!
    }

    @Test("a lid patch is the blink inside the eye, lit to match, and the open face everywhere else")
    func lidPatchStaysInTheEye() throws {
        // The blink frame is relit 10% brighter and has a dark lid line.
        let open = flat(0.5, 0.5, 0.5)
        let side = 120
        let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        context.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
        // (36, 48) top-left is (36, 71) in the context's bottom-left space.
        context.fill(CGRect(x: 30, y: 70, width: 12, height: 3))
        let shut = context.makeImage()!
        let eye = HeadRig.Eye(x: 0.3, y: 0.4, rx: 0.06, ry: 0.02)
        let patched = try #require(HeadDerivation.lidPatch(open: open, shut: shut, eyes: [eye]))
        let pixels = try #require(HeadDerivation.pixels(patched))
        let centre = pixels.rgba(36, 48)
        #expect(centre.0 < 30, "the lid line \(centre)")
        // Beside the line, inside the patch: the blink's skin, lit back to the open face's.
        let beside = pixels.rgba(36, 52)
        #expect(abs(beside.0 - 127.5) < 4, "relit skin \(beside)")
        for (x, y) in [(5, 5), (110, 110), (100, 48), (36, 100)] {
            let p = pixels.rgba(x, y)
            #expect(abs(p.0 - 127.5) < 2, "(\(x), \(y)) \(p)")
        }
    }

    @Test("on the creator's own faces, a lid patch changes nothing outside the eyes")
    func lidPatchOnPerfectAssetsIsANoOp() throws {
        let neutral = try #require(UIImage(named: "HeadNeutral")?.cgImage)
        let closed = try #require(UIImage(named: "HeadNeutralClosed")?.cgImage)
        let eyes = [HeadRig.Eye(x: 0.3999, y: 0.5176, rx: 0.0385, ry: 0.0192),
                    HeadRig.Eye(x: 0.6018, y: 0.5265, rx: 0.0385, ry: 0.0192)]
        let patched = try #require(HeadDerivation.lidPatch(open: neutral, shut: closed, eyes: eyes))
        let outside = HeadDerivation.difference(patched, neutral) { x, y in
            eyes.allSatisfy { hypot(($0.x - x) / ($0.rx * 3), ($0.y - y) / ($0.rx * 2.5)) > 1 }
        }
        #expect((outside ?? 99) < 1, "outside the eyes \(String(describing: outside))")
        let inside = HeadDerivation.difference(patched, closed) { x, y in
            eyes.contains { hypot(($0.x - x) / $0.rx, ($0.y - y) / $0.ry) < 0.8 }
        }
        #expect((inside ?? 99) < 4, "inside the eyes \(String(describing: inside))")
    }

    @Test("the creator's grin and wink overlap neutral closely enough to pop in")
    func silhouettes() throws {
        let neutral = try #require(UIImage(named: "HeadNeutral")?.cgImage)
        #expect(HeadDerivation.silhouetteIoU(neutral, neutral) == 1)
        for name in ["HeadSmile", "HeadWink"] {
            let face = try #require(UIImage(named: name)?.cgImage)
            let overlap = HeadDerivation.silhouetteIoU(neutral, face)
            #expect(overlap >= GridConstants.headPopIoU, "\(name) \(overlap)")
        }
    }

    @Test("a made head's derived payload: shut on every face with drawn eyes, and brows banded when clean")
    func derivedPayload() throws {
        func png(_ name: String) throws -> Data { try #require(UIImage(named: name)?.pngData()) }
        let eyes = [HeadRig.Eye(x: 0.3999, y: 0.5176, rx: 0.0385, ry: 0.0192),
                    HeadRig.Eye(x: 0.6018, y: 0.5265, rx: 0.0385, ry: 0.0192)]
        let payload = HeadStore.Payload(faces: [
            .neutral: .init(png: try png("HeadNeutral"), eyes: eyes),
            .browsUp: .init(png: try png("HeadNeutralBrowsUp"), eyes: eyes),
            .surprised: .init(png: try png("HeadRest"), eyes: eyes),
            .smile: .init(png: try png("HeadSmile"), eyes: []),
            .wink: .init(png: try png("HeadWink"), eyes: [])
        ], shut: try png("HeadNeutralClosed"))
        let derived = payload.derived()
        #expect(derived.faces[.neutral]?.shut != nil)
        #expect(derived.faces[.browsUp]?.shut != nil)
        #expect(derived.faces[.surprised]?.shut != nil)
        #expect(derived.faces[.smile]?.shut == nil && derived.faces[.wink]?.shut == nil)
        // The creator's brows ARE neutral with brows, so the seam is clean.
        let neutralImage = try #require(UIImage(named: "HeadNeutral")?.cgImage)
        let browsImage = try #require(UIImage(named: "HeadNeutralBrowsUp")?.cgImage)
        let seam = HeadDerivation.seamDifference(neutral: neutralImage, brows: browsImage, neutralEyes: eyes)
        #expect(derived.rawBrows != nil, "seam \(String(describing: seam))")
        #expect((seam ?? 99) <= HeadDerivation.seamLimit)
        #expect(derived.popsIn.isSuperset(of: [.smile, .wink]))
        let rig = try #require(HeadStore.rig(from: derived))
        #expect(rig.shutFaces == [.neutral, .browsUp, .surprised])
    }

    // MARK: - The maker

    @Test("the maker asks for one more blink only when the blink was missed")
    @MainActor func blinkAgain() {
        #expect(HeadMakerModel.asksBlinkAgain(blinkCaught: false))
        #expect(!HeadMakerModel.asksBlinkAgain(blinkCaught: true))
        #expect(HeadMakerModel.phase(for: .blinkAgain) == .blinkAgain)
        #expect(HeadMakerModel.pip(for: .blinkAgain) == .blink)
        #expect(HeadMakerModel.pip(for: .smile) == .smile)
        #expect(HeadCaptureEngine.slot(for: .blinkAgain) == .shut)
        // Not a stage of its own: the pip row still counts five asks.
        #expect(!HeadMakerModel.sequence.contains { $0.step == .blinkAgain })
    }
}
