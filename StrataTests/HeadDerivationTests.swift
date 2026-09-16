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
        #expect(patched.fits, "flat relit skin fits: \(patched.ringDifference)")
        let pixels = try #require(HeadDerivation.pixels(patched.image))
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
        let patch = try #require(HeadDerivation.lidPatch(open: neutral, shut: closed, eyes: eyes))
        #expect(patch.fits, "in place: \(patch.ringDifference)")
        let patched = patch.image
        let outside = HeadDerivation.difference(patched, neutral) { x, y in
            eyes.allSatisfy { hypot(($0.x - x) / ($0.rx * 3), ($0.y - y) / ($0.rx * 2.5)) > 1 }
        }
        #expect((outside ?? 99) < 1, "outside the eyes \(String(describing: outside))")
        let inside = HeadDerivation.difference(patched, closed) { x, y in
            eyes.contains { hypot(($0.x - x) / $0.rx, ($0.y - y) / $0.ry) < 0.8 }
        }
        #expect((inside ?? 99) < 4, "inside the eyes \(String(describing: inside))")
    }

    /// The creator's closed face moved `dx`, `dy` pixels and relit, as a
    /// blink frame that Vision lined up badly would be.
    private func shifted(_ name: String, dx: CGFloat, dy: CGFloat, light: CGFloat = 0) throws -> CGImage {
        let image = try #require(UIImage(named: name)?.cgImage)
        let w = image.width, h = image.height
        let context = try #require(CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: dx, y: -dy, width: CGFloat(w), height: CGFloat(h)))
        if light > 0 {
            context.setBlendMode(.sourceAtop)
            context.setFillColor(red: 1, green: 1, blue: 1, alpha: light)
            context.fill(CGRect(x: 0, y: 0, width: w, height: h))
        }
        return try #require(context.makeImage())
    }

    private let creatorEyes = [HeadRig.Eye(x: 0.3999, y: 0.5176, rx: 0.0385, ry: 0.0192),
                               HeadRig.Eye(x: 0.6018, y: 0.5265, rx: 0.0385, ry: 0.0192)]

    @Test("a blink 3px off is refused: neutral keeps the raw frame, brows and surprised get no blink")
    func aShiftedBlinkIsRefused() throws {
        let neutral = try #require(UIImage(named: "HeadNeutral")?.cgImage)
        let relit = try shifted("HeadNeutralClosed", dx: 0, dy: 0, light: 0.06)
        let inPlace = try #require(HeadDerivation.lidPatch(open: neutral, shut: relit, eyes: creatorEyes))
        #expect(inPlace.fits, "relit in place \(inPlace.ringDifference)")
        for (dx, dy) in [(3.0, 0.0), (0.0, 3.0), (-3.0, 0.0), (0.0, -3.0)] {
            let moved = try shifted("HeadNeutralClosed", dx: dx, dy: dy, light: 0.06)
            let patch = try #require(HeadDerivation.lidPatch(open: neutral, shut: moved, eyes: creatorEyes))
            #expect(!patch.fits, "3px (\(dx), \(dy)) \(patch.ringDifference)")
        }
        func png(_ name: String) throws -> Data { try #require(UIImage(named: name)?.pngData()) }
        let moved = try #require(HeadDerivation.pngData(try shifted("HeadNeutralClosed", dx: 0, dy: 3)))
        let payload = HeadStore.Payload(faces: [
            .neutral: .init(png: try png("HeadNeutral"), eyes: creatorEyes),
            .browsUp: .init(png: try png("HeadNeutralBrowsUp"), eyes: creatorEyes),
            .surprised: .init(png: try png("HeadRest"), eyes: creatorEyes)
        ], shut: moved)
        let derived = payload.derived()
        #expect(derived.faces.values.allSatisfy { $0.shut == nil })
        let rig = try #require(HeadStore.rig(from: derived))
        #expect(rig.shutFaces == [.neutral], "neutral blinks on the raw frame")
        #expect(rig.shut(on: .browsUp) == nil && rig.shut(on: .surprised) == nil)
    }

    @Test("light is matched on the cheek, so a brows face's patch is not pale")
    func lightMatchIgnoresTheBrows() throws {
        // Raised brows and the rest face differ from the blink ABOVE the eyes;
        // matched there, the gain would be wrong and the oval would come back.
        for name in ["HeadNeutralBrowsUp", "HeadRest"] {
            let base = try #require(UIImage(named: name)?.cgImage)
            let relit = try shifted("HeadNeutralClosed", dx: 0, dy: 0, light: 0.06)
            let patch = try #require(HeadDerivation.lidPatch(open: base, shut: relit, eyes: creatorEyes))
            let unlit = try #require(UIImage(named: "HeadNeutralClosed")?.cgImage)
            let reference = try #require(HeadDerivation.lidPatch(open: base, shut: unlit, eyes: creatorEyes))
            // Relit or not, the pasted lids come out the same.
            let inside = HeadDerivation.difference(patch.image, reference.image) { x, y in
                self.creatorEyes.contains { hypot(($0.x - x) / ($0.rx * 1.4), ($0.y - y) / ($0.ry * 2)) < 1 }
            }
            #expect((inside ?? 99) < 3, "\(name) lids differ by \(String(describing: inside))")
            // Nothing above the brow cap is touched.
            let above = HeadDerivation.difference(patch.image, base) { x, y in
                y < (self.creatorEyes.map { $0.y - $0.ry * HeadDerivation.lidCapY }.min() ?? 0) - 0.02
                    && abs(x - 0.5) < 0.25
            }
            #expect((above ?? 99) < 0.5, "\(name) above the cap \(String(describing: above))")
        }
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
        // The rest face's cheeks sit differently from the blink's, so its
        // patch measures over the limit and it is given no blink: refused,
        // not pasted with a seam.
        #expect(derived.faces[.smile]?.shut == nil && derived.faces[.wink]?.shut == nil)
        // The creator's brows ARE neutral with brows, so the seam is clean.
        let neutralImage = try #require(UIImage(named: "HeadNeutral")?.cgImage)
        let browsImage = try #require(UIImage(named: "HeadNeutralBrowsUp")?.cgImage)
        let seam = HeadDerivation.seamDifference(neutral: neutralImage, brows: browsImage, neutralEyes: eyes)
        #expect(derived.rawBrows != nil, "seam \(String(describing: seam))")
        #expect((seam ?? 99) <= HeadDerivation.seamLimit)
        #expect(derived.popsIn.isSuperset(of: [.smile, .wink]))
        let rig = try #require(HeadStore.rig(from: derived))
        #expect(rig.shutFaces.isSuperset(of: [.neutral, .browsUp]))
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
