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
        #expect(patched.fits, "flat relit skin fits: \(patched.registration)")
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
        #expect(patch.fits, "in place: \(patch.registration)")
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
        if light != 0, let data = context.data {
            // Relit as an exposure change: every channel scaled.
            let bytes = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
            for i in 0..<(w * h) {
                let alpha = Double(bytes[i * 4 + 3])
                for c in 0..<3 { bytes[i * 4 + c] = UInt8(min(Double(bytes[i * 4 + c]) * (1 + light), alpha).rounded()) }
            }
        }
        return try #require(context.makeImage())
    }

    private let creatorEyes = [HeadRig.Eye(x: 0.3999, y: 0.5176, rx: 0.0385, ry: 0.0192),
                               HeadRig.Eye(x: 0.6018, y: 0.5265, rx: 0.0385, ry: 0.0192)]

    /// **A blink the way a real one differs from the open face**: the lower
    /// lid risen, crow's feet creased at the outer corners, relit, moved
    /// `dx`, `dy` and drawn at `side` pixels.
    private func realBlink(side: Int, dx: Int, dy: Int, light: CGFloat = 0.06) throws -> (open: CGImage, shut: CGImage) {
        let neutral = try #require(UIImage(named: "HeadNeutral")?.cgImage)
        let closed = try #require(UIImage(named: "HeadNeutralClosed")?.cgImage)
        func draw(_ image: CGImage, dx: Int = 0, dy: Int = 0) throws -> CGImage {
            let context = try #require(CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                                                 bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: dx, y: -dy, width: side, height: side))
            return try #require(context.makeImage())
        }
        let open = try draw(neutral)
        var pixels = try #require(HeadDerivation.pixels(try draw(closed)))
        let s = Double(side), rise = max(1, Int((2.0 * s / 480).rounded()))
        for eye in creatorEyes {
            let ex = Double(eye.x) * s, ey = Double(eye.y) * s, rx = Double(eye.rx) * s, ry = Double(eye.ry) * s
            // The lower lid rises: the band under the eye moves up.
            for y in Int(ey + ry * 0.6)..<Int(ey + ry * 3) {
                for x in Int(ex - rx * 1.5)..<Int(ex + rx * 1.5) {
                    for c in 0..<4 { pixels.bytes[(y * side + x) * 4 + c] = pixels.bytes[((y + rise) * side + x) * 4 + c] }
                }
            }
            // Crow's feet: three short creases out from the outer corner.
            let outward = ex < s / 2 ? -1.0 : 1.0
            for angle in [-0.35, 0.0, 0.35] {
                for step in 0..<Int(0.03 * s) {
                    let x = Int(ex + outward * (rx * 1.1 + Double(step) * cos(angle)))
                    let y = Int(ey + Double(step) * sin(angle))
                    for c in 0..<3 { pixels.bytes[(y * side + x) * 4 + c] = UInt8(Double(pixels.bytes[(y * side + x) * 4 + c]) * 0.85) }
                }
            }
        }
        // Relit: the camera's exposure a little different, a scale on every channel.
        if light != 0 {
            for i in 0..<(side * side) {
                let alpha = Double(pixels.bytes[i * 4 + 3])
                for c in 0..<3 {
                    pixels.bytes[i * 4 + c] = UInt8(min(Double(pixels.bytes[i * 4 + c]) * (1 + light), alpha).rounded())
                }
            }
        }
        var shut = try #require(HeadDerivation.image(pixels))
        shut = try draw(shut, dx: dx, dy: dy)
        return (open, shut)
    }

    @Test("a real-blink-like pair moved 0 to 4px is registered back and accepted, at 480 and 600px")
    func aRealBlinkIsRegistered() throws {
        for side in [480, 600] {
            for (dx, dy) in [(0, 0), (1, 0), (0, 2), (3, 0), (0, 3), (-4, 2), (2, -4), (4, 4)] {
                let pair = try realBlink(side: side, dx: dx, dy: dy)
                let patch = try #require(HeadDerivation.lidPatch(open: pair.open, shut: pair.shut, eyes: creatorEyes))
                let r = patch.registration
                // Undone to within the pixel the risen lid pulls it by.
                #expect(abs(r.dx + dx) <= 1 && abs(r.dy + dy) <= 1, "\(side) moved (\(dx), \(dy)) registered (\(r.dx), \(r.dy))")
                #expect(patch.fits, "\(side) (\(dx), \(dy)) ratio \(r.ratio)")
            }
        }
    }

    @Test("lids left more than 2px off are refused, either way, at 480 and 600px")
    func leftoverOverTwoPixelsIsRefused() throws {
        for side in [480, 600] {
            let pair = try realBlink(side: side, dx: 0, dy: 0)
            let best = try #require(HeadDerivation.register(open: pair.open, shut: pair.shut, eyes: creatorEyes))
            #expect(best.fits, "\(side) registered \(best.ratio)")
            for k in 3...8 {
                for (dx, dy) in [(0, k), (0, -k), (k, 0), (-k, 0)] {
                    let off = try #require(HeadDerivation.evaluate(open: pair.open, shut: pair.shut, eyes: creatorEyes,
                                                                   dx: best.dx + dx, dy: best.dy + dy))
                    #expect(!off.fits, "\(side) left (\(dx), \(dy)) off: \(off.ratio)")
                }
            }
        }
    }

    @Test("true shifts from the search edge +1 to +6px are found by the widened search, never pasted over 2px off")
    func pastTheSearchEdge() throws {
        for side in [480, 600] {
            // The first search reaches one opening half-height vertically.
            let reachY = Int((0.0192 * Double(side)).rounded())
            let reachX = max(1, Int((0.077 * Double(side) * 0.15).rounded()))
            for extra in 1...6 {
                for (dx, dy) in [(0, reachY + extra), (reachX + extra, 0)] {
                    let pair = try realBlink(side: side, dx: dx, dy: dy)
                    let r = try #require(HeadDerivation.register(open: pair.open, shut: pair.shut, eyes: creatorEyes))
                    let leftover = max(abs(r.dx + dx), abs(r.dy + dy))
                    if leftover > 2 { #expect(!r.fits, "\(side) true (\(dx), \(dy)) left \(leftover) off, ratio \(r.ratio)") }
                    // Found to within a pixel. Accepted, unless it sits exactly on the
                    // widened search's edge, where it is not used at all.
                    #expect(leftover <= 1 && (r.fits || r.onEdge),
                            "\(side) true (\(dx), \(dy)) found (\(r.dx), \(r.dy)) ratio \(r.ratio) edge \(r.onEdge)")
                }
            }
        }
    }

    @Test("a blink past even the widened search is not used at all: no lids, no moved frame, no raw frame")
    func pastTheWidenedSearchDoesNotBlink() throws {
        for side in [480, 600] {
            let pair = try realBlink(side: side, dx: 0, dy: 60)
            let r = try #require(HeadDerivation.register(open: pair.open, shut: pair.shut, eyes: creatorEyes))
            #expect(r.onEdge && !r.fits, "\(side) found (\(r.dx), \(r.dy)) edge \(r.onEdge)")
        }
        func png(_ image: CGImage) throws -> Data { try #require(HeadDerivation.pngData(image)) }
        let gross = try realBlink(side: 480, dx: 0, dy: 60)
        let payload = HeadStore.Payload(faces: [.neutral: .init(png: try png(gross.open), eyes: creatorEyes)],
                                        shut: try png(gross.shut))
        let derived = payload.derived()
        #expect(!derived.blinks)
        let rig = try #require(HeadStore.rig(from: derived))
        #expect(rig.shut == nil && rig.shutFaces.isEmpty)
    }

    @Test("raised brows and surprised are checked at neutral's offset on their own faces")
    func sharedRegistrationIsCheckedPerFace() throws {
        let pair = try realBlink(side: 480, dx: 2, dy: 3)
        let r = try #require(HeadDerivation.register(open: pair.open, shut: pair.shut, eyes: creatorEyes))
        let brows = try #require(UIImage(named: "HeadNeutralBrowsUp")?.cgImage)
        let onBrows = try #require(HeadDerivation.evaluate(open: brows, shut: pair.shut, eyes: creatorEyes, dx: r.dx, dy: r.dy))
        #expect(onBrows.fits, "brows at the shared offset \(onBrows.ratio)")
        // A face whose skin round the eyes does not match the blink is dropped.
        let smile = try #require(UIImage(named: "HeadSmile")?.cgImage)
        let onSmile = try #require(HeadDerivation.evaluate(open: smile, shut: pair.shut, eyes: creatorEyes, dx: r.dx, dy: r.dy))
        #expect(!onSmile.fits, "a grin's cheeks at the shared offset \(onSmile.ratio)")
    }

    @Test("a refused blink's fallback frame is moved and lit to match")
    func aRefusedBlinksFallback() throws {
        // The fallback: the whole relit frame, lit back to the open face.
        let pair = try realBlink(side: 600, dx: 0, dy: 3, light: 0.08)
        let r = try #require(HeadDerivation.register(open: pair.open, shut: pair.shut, eyes: creatorEyes))
        let frame = try #require(HeadDerivation.blinkFrame(open: pair.open, shut: pair.shut, eyes: creatorEyes, registration: r))
        func brightness(_ image: CGImage) throws -> Double {
            let p = try #require(HeadDerivation.pixels(image))
            var total = 0.0, count = 0
            for y in stride(from: 0, to: p.height, by: 2) {
                // Below the eyes: the cheeks and chin, where a blink does not change.
                guard Double(y) / Double(p.height) > 0.58 else { continue }
                for x in stride(from: 0, to: p.width, by: 2) {
                    let c = p.rgba(x, y)
                    guard c.3 > 250 else { continue }
                    total += (c.0 * 3 + c.1 * 6 + c.2) / 10
                    count += 1
                }
            }
            return total / Double(max(count, 1))
        }
        let open = try brightness(pair.open), fallback = try brightness(frame), raw = try brightness(pair.shut)
        #expect(abs(raw - open) > 8, "the raw frame really is relit: \(raw) vs \(open)")
        #expect(abs(fallback - open) < 1.5, "fallback \(fallback) vs open \(open)")
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
