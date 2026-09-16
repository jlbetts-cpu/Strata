import CoreGraphics
import CoreImage
import Foundation
import UIKit

/// **Faces as consistent as the creator's, from what a person already
/// captured.**
///
/// The creator's shut eyes and raised brows are the SAME photograph as his
/// neutral face with only the lids or brows changed, so a blink moves the lids
/// and nothing else. A made head's are separate video frames seconds apart,
/// lined up only by the eyes: a 250ms blink could move the hair, the jaw or
/// the light, and read as a flicker rather than a blink. This builds the
/// creator's kind of face from the made one's own pixels:
///
/// - `lidPatch`: the eye regions of the blink frame, feathered onto a face.
///   Everything outside the eyes is that face's own pixels. Made for neutral,
///   raised brows and surprised — the faces with drawn irises. Never drawn,
///   never scaled: real lids from the real blink (no uncanny partial lids).
/// - `browBand`: the forehead of the raised-brows frame feathered onto
///   neutral, so a brow flash changes the brows and nothing else. Kept only
///   when its seam measures clean (`seamDifference`); otherwise the raw
///   capture stays.
/// - `silhouetteIoU`: how closely a face's outline matches neutral's, which
///   decides whether it may pop in (`GridConstants.headPopIoU`).
///
/// Works in canvas space on the saved PNGs, so heads made before this can be
/// migrated without the frames (`HeadStore`). Off the main actor.
nonisolated enum HeadDerivation {

    /// RGBA8, premultiplied, top-left origin.
    struct Pixels {
        let width: Int
        let height: Int
        var bytes: [UInt8]

        func rgba(_ x: Int, _ y: Int) -> (Double, Double, Double, Double) {
            let i = (y * width + x) * 4
            return (Double(bytes[i]), Double(bytes[i + 1]), Double(bytes[i + 2]), Double(bytes[i + 3]))
        }
    }

    static func pixels(_ image: CGImage, width: Int? = nil, height: Int? = nil) -> Pixels? {
        let w = width ?? image.width, h = height ?? image.height
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        let made = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                          bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return made ? Pixels(width: w, height: h, bytes: bytes) : nil
    }

    // MARK: - Masks

    /// A soft grey mask the size of `side`: white where `draw` fills, feathered
    /// by `feather` pixels. Top-left origin, like the canvas.
    static func mask(side: Int, feather: Double, draw: (CGContext) -> Void) -> CGImage? {
        guard let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        // Top-left origin, so canvas fractions draw where they are.
        context.translateBy(x: 0, y: CGFloat(side))
        context.scaleBy(x: 1, y: -1)
        context.setFillColor(gray: 1, alpha: 1)
        draw(context)
        guard let hard = context.makeImage() else { return nil }
        guard feather > 0 else { return hard }
        let input = CIImage(cgImage: hard)
        let blurred = input.clampedToExtent()
            .applyingGaussianBlur(sigma: feather)
            .cropped(to: input.extent)
        let ci = CIContext(options: [.cacheIntermediates: false])
        return ci.createCGImage(blurred, from: input.extent, format: .L8, colorSpace: CGColorSpaceCreateDeviceGray())
    }

    /// Draws `top` over `base` through `mask` (white shows `top`).
    ///
    /// `matchesLight`: `top` is first scaled, channel by channel, so that
    /// where the feather blends the two they agree. A frame seconds later is
    /// often lit a little differently, and without this a patch reads as a
    /// pale or dark oval painted round the eye (seen on the fixture, whose
    /// blink is relit 6%).
    static func composite(base: CGImage, top: CGImage, mask: CGImage, matchesLight: Bool = false) -> CGImage? {
        let w = base.width, h = base.height
        guard var under = pixels(base), let over = pixels(top, width: w, height: h),
              let gate = pixels(mask, width: w, height: h) else { return nil }
        var gain = [1.0, 1.0, 1.0, 1.0]
        if matchesLight {
            var sumBase = [0.0, 0.0, 0.0], sumTop = [0.0, 0.0, 0.0]
            for i in 0..<(w * h) {
                let a = gate.bytes[i * 4]
                // The outer edge of the feather: skin round the eye, not the lids
                // themselves, which are meant to differ.
                guard a > 8, a < 80, under.bytes[i * 4 + 3] > 240, over.bytes[i * 4 + 3] > 240 else { continue }
                for c in 0..<3 {
                    sumBase[c] += Double(under.bytes[i * 4 + c])
                    sumTop[c] += Double(over.bytes[i * 4 + c])
                }
            }
            for c in 0..<3 where sumTop[c] > 0 {
                gain[c] = min(max(sumBase[c] / sumTop[c], 0.7), 1.4)
            }
        }
        for i in 0..<(w * h) {
            let a = Double(gate.bytes[i * 4]) / 255
            guard a > 0 else { continue }
            let alpha = Double(over.bytes[i * 4 + 3])
            for c in 0..<4 {
                let j = i * 4 + c
                // Premultiplied: a colour may not exceed its own alpha.
                let lit = c == 3 ? Double(over.bytes[j]) : min(Double(over.bytes[j]) * gain[c], alpha)
                under.bytes[j] = UInt8(min(max((Double(under.bytes[j]) * (1 - a) + lit * a).rounded(), 0), 255))
            }
        }
        return image(under)
    }

    static func image(_ pixels: Pixels) -> CGImage? {
        let data = Data(pixels.bytes) as CFData
        guard let provider = CGDataProvider(data: data) else { return nil }
        return CGImage(width: pixels.width, height: pixels.height, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: pixels.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    // MARK: - Lids

    /// How far past the measured opening the lid patch reaches: the lids and
    /// lashes sit above and below the opening itself.
    static let lidReachX: CGFloat = 1.45
    static let lidReachY: CGFloat = 2.1
    /// The patch's feather, as a share of the canvas.
    static let lidFeather: Double = 0.012

    /// The eye regions of `shut`, feathered onto `open`.
    static func lidPatch(open: CGImage, shut: CGImage, eyes: [HeadRig.Eye]) -> CGImage? {
        guard !eyes.isEmpty else { return nil }
        let side = open.width
        guard let gate = mask(side: side, feather: lidFeather * Double(side), draw: { context in
            for eye in eyes { fillEye(eye, in: context, side: CGFloat(side)) }
        }) else { return nil }
        return composite(base: open, top: shut, mask: gate, matchesLight: true)
    }

    private static func fillEye(_ eye: HeadRig.Eye, in context: CGContext, side: CGFloat) {
        let rx = eye.rx * side * lidReachX, ry = max(eye.ry * lidReachY, eye.rx * 0.8) * side
        context.saveGState()
        context.translateBy(x: eye.x * side, y: eye.y * side)
        context.rotate(by: CGFloat(eye.angle))
        context.fillEllipse(in: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
        context.restoreGState()
    }

    // MARK: - Brows

    /// The band's feather, as a share of the canvas.
    static let browFeather: Double = 0.01

    /// Where the forehead band ends, from the top: just above the upper lids.
    static func browLine(eyes: [HeadRig.Eye]) -> CGFloat {
        let tops = eyes.map { $0.y - $0.ry * 1.3 }
        return (tops.min() ?? 0.4) - 0.004
    }

    /// The forehead of `brows` feathered onto `neutral`, down to the lids.
    static func browBand(neutral: CGImage, brows: CGImage, neutralEyes: [HeadRig.Eye]) -> CGImage? {
        let side = neutral.width
        let line = browLine(eyes: neutralEyes)
        guard let gate = mask(side: side, feather: browFeather * Double(side), draw: { context in
            context.fill(CGRect(x: -CGFloat(side), y: -CGFloat(side), width: CGFloat(side) * 3,
                                height: CGFloat(side) * (1 + line)))
        }) else { return nil }
        return composite(base: neutral, top: brows, mask: gate, matchesLight: true)
    }

    // MARK: - Measures

    /// Mean colour difference, 0...255 per channel averaged, between two
    /// faces over the pixels where BOTH are opaque and `inside(x, y)` holds
    /// (canvas fractions). A seam is clean when the two pictures agree along
    /// it: what is joined there is then the same picture.
    static func difference(_ a: CGImage, _ b: CGImage, where inside: (CGFloat, CGFloat) -> Bool) -> Double? {
        let side = 160
        guard let pa = pixels(a, width: side, height: side), let pb = pixels(b, width: side, height: side) else { return nil }
        var total = 0.0, count = 0
        for y in 0..<side {
            for x in 0..<side where inside(CGFloat(x) / CGFloat(side), CGFloat(y) / CGFloat(side)) {
                let ca = pa.rgba(x, y), cb = pb.rgba(x, y)
                guard ca.3 > 240, cb.3 > 240 else { continue }
                total += (abs(ca.0 - cb.0) + abs(ca.1 - cb.1) + abs(ca.2 - cb.2)) / 3
                count += 1
            }
        }
        return count == 0 ? nil : total / Double(count)
    }

    /// How different `brows` and `neutral` are along the brow band's seam.
    static func seamDifference(neutral: CGImage, brows: CGImage, neutralEyes: [HeadRig.Eye]) -> Double? {
        let line = browLine(eyes: neutralEyes)
        let band = CGFloat(browFeather * 1.5)
        return difference(neutral, brows) { _, y in abs(y - line) < band }
    }

    /// A seam this clean (mean channel difference) is kept.
    static let seamLimit: Double = 12

    /// Share of opaque pixels two faces have in common: intersection over union.
    static func silhouetteIoU(_ a: CGImage, _ b: CGImage) -> Double {
        let side = 150
        guard let pa = pixels(a, width: side, height: side), let pb = pixels(b, width: side, height: side) else { return 0 }
        var both = 0, either = 0
        for i in 0..<(side * side) {
            let oa = pa.bytes[i * 4 + 3] > 127, ob = pb.bytes[i * 4 + 3] > 127
            if oa && ob { both += 1 }
            if oa || ob { either += 1 }
        }
        return either == 0 ? 0 : Double(both) / Double(either)
    }

    // MARK: - A made head

    /// What derivation adds to a saved head.
    struct Derived {
        /// Per face: its shut eyes as a PNG.
        var shut: [HeadRig.Expression: Data] = [:]
        /// A banded raised-brows face and its eyes (neutral's), if the seam was clean.
        var brows: (png: Data, eyes: [HeadRig.Eye])?
        var popsIn: Set<HeadRig.Expression> = []
        /// Measured, for the record: seam difference and silhouette overlaps.
        var browSeam: Double?
        var overlap: [HeadRig.Expression: Double] = [:]
    }

    /// **Derives everything from the faces and the raw blink.** `faces` are
    /// the saved PNGs and their eyes; `blink` is the raw shut frame.
    static func derive(faces: [HeadRig.Expression: (png: Data, eyes: [HeadRig.Eye])], blink: Data?) -> Derived {
        var derived = Derived()
        guard let neutralFace = faces[.neutral], let neutral = cgImage(neutralFace.png) else { return derived }

        var browsImage: CGImage?
        var browsEyes: [HeadRig.Eye] = []
        if let raw = faces[.browsUp], let brows = cgImage(raw.png) {
            browsImage = brows
            browsEyes = raw.eyes
            let seam = seamDifference(neutral: neutral, brows: brows, neutralEyes: neutralFace.eyes)
            derived.browSeam = seam
            if let seam, seam <= seamLimit,
               let banded = browBand(neutral: neutral, brows: brows, neutralEyes: neutralFace.eyes),
               let png = pngData(banded) {
                derived.brows = (png, neutralFace.eyes)
                browsImage = banded
                browsEyes = neutralFace.eyes
            }
        }

        if let blink, let shut = cgImage(blink) {
            if let patched = lidPatch(open: neutral, shut: shut, eyes: neutralFace.eyes), let png = pngData(patched) {
                derived.shut[.neutral] = png
            }
            if let brows = browsImage, !browsEyes.isEmpty,
               let patched = lidPatch(open: brows, shut: shut, eyes: browsEyes), let png = pngData(patched) {
                derived.shut[.browsUp] = png
            }
            if let raw = faces[.surprised], !raw.eyes.isEmpty, let surprised = cgImage(raw.png),
               let patched = lidPatch(open: surprised, shut: shut, eyes: raw.eyes), let png = pngData(patched) {
                derived.shut[.surprised] = png
            }
        }

        for expression in [HeadRig.Expression.smile, .wink, .surprised] {
            guard let face = faces[expression], let image = cgImage(face.png) else { continue }
            let overlap = silhouetteIoU(neutral, image)
            derived.overlap[expression] = overlap
            if overlap >= GridConstants.headPopIoU { derived.popsIn.insert(expression) }
        }
        return derived
    }

    static func cgImage(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    static func pngData(_ image: CGImage) -> Data? {
        UIImage(cgImage: image).pngData()
    }
}
