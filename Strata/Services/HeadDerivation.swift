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

    /// One Core Image context for every mask: making one is the expensive part.
    private static let blurContext = CIContext(options: [.cacheIntermediates: false])

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
        return blurContext.createCGImage(blurred, from: input.extent, format: .L8, colorSpace: CGColorSpaceCreateDeviceGray())
    }

    /// Draws `top` over `base` through `gate` (white shows `top`).
    ///
    /// `ring`: pixels (by index) where the two pictures should already agree.
    /// When given, `top` is first scaled channel by channel so that they agree
    /// there: a frame seconds later is often lit a little differently, and
    /// without this a patch read as a pale oval painted round the eye.
    static func composite(base: CGImage, top: CGImage, gate: [UInt8],
                          ring: ((Int) -> Bool)? = nil) -> CGImage? {
        let w = base.width, h = base.height
        guard var under = pixels(base), let over = pixels(top, width: w, height: h),
              gate.count == w * h else { return nil }
        // Per channel, a gain: exposure is a scale, and a fitted lift was
        // unstable over the narrow range of skin on a cheek.
        var gain = [1.0, 1.0, 1.0]
        if let ring {
            var sumBase = [0.0, 0.0, 0.0], sumTop = [0.0, 0.0, 0.0]
            for i in 0..<(w * h) where ring(i) {
                guard under.bytes[i * 4 + 3] > 240, over.bytes[i * 4 + 3] > 240 else { continue }
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
            let a = Double(gate[i]) / 255
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

    /// `image` moved by whole pixels (positive is right and down), on a clear
    /// canvas of the same size.
    static func shifted(_ image: CGImage, dx: Int, dy: Int) -> CGImage? {
        guard dx != 0 || dy != 0 else { return image }
        let w = image.width, h = image.height
        guard let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(image, in: CGRect(x: dx, y: -dy, width: w, height: h))
        return context.makeImage()
    }

    /// A grey mask's samples, one per pixel.
    static func grey(_ mask: CGImage, side: Int) -> [UInt8]? {
        guard let p = pixels(mask, width: side, height: side) else { return nil }
        return (0..<(side * side)).map { p.bytes[$0 * 4] }
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

    /// The patch never reaches higher than this many opening half-heights
    /// above an eye's centre, so a raised brow is never pasted over with the
    /// blink frame's resting one.
    static let lidCapY: CGFloat = 1.9

    // **A blink is REGISTERED to the open face, not refused for having moved.**
    //
    // The first version compared the blink frame where it lay against an
    // absolute limit tuned on the creator's hand-painted closed photo, whose
    // skin round the eye never changes. A real blink moves: Vision's eye
    // centres on shut eyes drift toward the lash line, the lower lid rises,
    // crow's feet crease, and a second blink comes ten seconds later. Most
    // real blinks would have been refused, and the fallback moved and relit
    // the whole head on every blink.
    //
    // Now: search whole-pixel offsets within `lidSearch` of the eye's width for
    // the one where the ring round the eyes agrees best, paste there, and judge
    // what is left against the face's OWN texture: the open face against itself
    // moved `lidTextureShift` of an eye's width. A blink that still differs
    // more than `lidRatioLimit` times that is refused, and even then its whole
    // frame is moved to the best offset and lit to match (`blinkFrame`).

    /// How far to look for the blink, as a share of an eye's width.
    static let lidSearch: CGFloat = 0.15
    /// The open face moved this share of an eye's width: its own texture.
    static let lidTextureShift: CGFloat = 0.1
    /// The best-registered blink may differ this many times the face's own
    /// texture before it is refused: no more than the open face differs from
    /// itself moved a tenth of an eye. Measured on a real-blink-like pair
    /// (lower lid risen, crow's feet, relit 6%, moved up to 4px) at 480 and
    /// 600px: 0.39 to 0.40 once registered. Moved 18 to 20px, past the search:
    /// 1.32 to 2.50. See `HeadDerivationTests.aRealBlinkIsRegistered`.
    static let lidRatioLimit: Double = 1.0
    /// Half the box, in pixels, rings are compared over.
    static let ringBlur = 1

    /// Where a blink lands on the open face, and how well.
    struct Registration {
        let dx: Int
        let dy: Int
        /// Mean local luminance difference over the ring at the best offset,
        /// after the light match.
        let difference: Double
        /// The open face against itself, moved `lidTextureShift`.
        let texture: Double
        var ratio: Double { difference / max(texture, 0.5) }
        var fits: Bool { ratio <= HeadDerivation.lidRatioLimit }
    }

    /// A lid patch and its registration.
    struct LidPatch {
        let image: CGImage
        let registration: Registration
        var fits: Bool { registration.fits }
    }

    /// The masks a lid patch uses: the soft ellipse capped below the brows,
    /// the hard opening, the gain ring on the cheek, and the measured ring.
    private struct LidMasks {
        let gate: [UInt8]
        let gainRing: [Int]
        let measuredRing: [Int]
    }

    private static func lidMasks(eyes: [HeadRig.Eye], side: Int) -> LidMasks? {
        let s = CGFloat(side)
        let cap = eyes.map { $0.y - $0.ry * lidCapY }.min() ?? 0
        guard let softMask = mask(side: side, feather: lidFeather * Double(side), draw: { context in
                  context.clip(to: CGRect(x: -s, y: cap * s, width: s * 3, height: s * 2))
                  for eye in eyes { fillEye(eye, in: context, side: s) }
              }),
              let hardMask = mask(side: side, feather: 0, draw: { context in
                  for eye in eyes { fillOpening(eye, in: context, side: s) }
              }),
              let soft = grey(softMask, side: side), let hard = grey(hardMask, side: side) else { return nil }
        let centreLine = Int((eyes.map(\.y).max() ?? 0.5) * s)
        let capLine = Int(cap * s)
        var gain: [Int] = [], measured: [Int] = []
        for i in 0..<(side * side) where hard[i] == 0 {
            // Lit to match on the outer feather over the cheek, never the brows.
            if soft[i] > 4, soft[i] < 40, i / side > centreLine { gain.append(i) }
            // Registered on the whole outer feather below the cap.
            if soft[i] > 4, soft[i] < 60, i / side > capLine { measured.append(i) }
        }
        return LidMasks(gate: zip(soft, hard).map { max($0, $1) }, gainRing: gain, measuredRing: measured)
    }

    /// **Finds where `shut` lines up with `open` round the eyes.**
    static func register(open: CGImage, shut: CGImage, eyes: [HeadRig.Eye]) -> Registration? {
        guard !eyes.isEmpty, let masks = lidMasks(eyes: eyes, side: open.width) else { return nil }
        return register(open: open, shut: shut, eyes: eyes, masks: masks)
    }

    private static func register(open: CGImage, shut: CGImage, eyes: [HeadRig.Eye], masks: LidMasks) -> Registration? {
        let w = open.width, h = open.height
        guard let a = pixels(open), let b = pixels(shut, width: w, height: h) else { return nil }
        func luma(_ p: Pixels, _ i: Int) -> Double {
            (Double(p.bytes[i * 4]) * 3 + Double(p.bytes[i * 4 + 1]) * 6 + Double(p.bytes[i * 4 + 2])) / 10
        }
        func table(_ p: Pixels) -> [Double] {
            var sums = [Double](repeating: 0, count: (w + 1) * (h + 1))
            for y in 0..<h {
                var row = 0.0
                for x in 0..<w {
                    row += luma(p, y * w + x)
                    sums[(y + 1) * (w + 1) + x + 1] = sums[y * (w + 1) + x + 1] + row
                }
            }
            return sums
        }
        let sa = table(a), sb = table(b)
        let r = ringBlur
        func mean(_ sums: [Double], _ x: Int, _ y: Int) -> Double? {
            guard x - r >= 0, y - r >= 0, x + r < w, y + r < h else { return nil }
            let x0 = x - r, x1 = x + r + 1, y0 = y - r, y1 = y + r + 1
            return (sums[y1 * (w + 1) + x1] - sums[y0 * (w + 1) + x1] - sums[y1 * (w + 1) + x0]
                    + sums[y0 * (w + 1) + x0]) / Double((x1 - x0) * (y1 - y0))
        }
        func opaque(_ p: Pixels, _ x: Int, _ y: Int) -> Bool {
            x >= 0 && y >= 0 && x < w && y < h && p.bytes[(y * w + x) * 4 + 3] > 240
        }
        /// `other` moved by (dx, dy) against `a`: the light-matched mean difference.
        func compare(_ other: Pixels, _ sums: [Double], _ dx: Int, _ dy: Int) -> Double? {
            var sumA = 0.0, sumB = 0.0
            for i in masks.gainRing {
                let x = i % w, y = i / w
                guard opaque(a, x, y), opaque(other, x - dx, y - dy) else { continue }
                sumA += luma(a, i)
                sumB += luma(other, (y - dy) * w + x - dx)
            }
            let gain = sumB > 0 ? min(max(sumA / sumB, 0.7), 1.4) : 1
            var total = 0.0, count = 0
            for i in masks.measuredRing {
                let x = i % w, y = i / w
                guard opaque(a, x, y), opaque(other, x - dx, y - dy),
                      let ma = mean(sa, x, y), let mb = mean(sums, x - dx, y - dy) else { continue }
                total += abs(ma - mb * gain)
                count += 1
            }
            return count < 50 ? nil : total / Double(count)
        }
        let span = eyes.map { $0.rx * 2 }.reduce(0, +) / CGFloat(eyes.count) * CGFloat(w)
        let reach = max(1, Int((span * lidSearch).rounded()))
        var best: (dx: Int, dy: Int, difference: Double)?
        // Nearest first, and a farther offset has to be clearly better: on a
        // face with no texture to go by, the blink stays where it was.
        var offsets: [(Int, Int)] = []
        for dy in -reach...reach {
            for dx in -reach...reach { offsets.append((dx, dy)) }
        }
        offsets.sort { a, b in
            let da: Int = a.0 * a.0 + a.1 * a.1
            let db: Int = b.0 * b.0 + b.1 * b.1
            return da < db
        }
        for (dx, dy) in offsets {
            guard let d = compare(b, sb, dx, dy) else { continue }
            if best == nil || d < best!.difference - 0.05 { best = (dx, dy, d) }
        }
        let move = max(1, Int((span * lidTextureShift).rounded()))
        let texture = [compare(a, sa, move, 0), compare(a, sa, 0, move)].compactMap { $0 }
        guard let best, !texture.isEmpty else { return nil }
        return Registration(dx: best.dx, dy: best.dy, difference: best.difference,
                            texture: texture.reduce(0, +) / Double(texture.count))
    }

    /// **The eye regions of `shut`, registered and feathered onto `open`**: a
    /// soft ellipse round each eye, capped below the brows, joined with the
    /// hard opening so no painted eye is left at a lid's corner, lit to match
    /// on the cheek just below the eyes.
    static func lidPatch(open: CGImage, shut: CGImage, eyes: [HeadRig.Eye],
                         registration known: Registration? = nil) -> LidPatch? {
        guard !eyes.isEmpty, let masks = lidMasks(eyes: eyes, side: open.width),
              let registration = known ?? register(open: open, shut: shut, eyes: eyes, masks: masks),
              let moved = shifted(shut, dx: registration.dx, dy: registration.dy) else { return nil }
        let ring = Set(masks.gainRing)
        guard let made = composite(base: open, top: moved, gate: masks.gate, ring: { ring.contains($0) }) else {
            return nil
        }
        return LidPatch(image: made, registration: registration)
    }

    /// **A refused blink's whole frame**, moved to its best offset and lit to
    /// match the open face on the cheek, so a blink that cannot be pasted
    /// still does not shift or flash the head.
    static func blinkFrame(open: CGImage, shut: CGImage, eyes: [HeadRig.Eye], registration: Registration) -> CGImage? {
        guard let masks = lidMasks(eyes: eyes, side: open.width),
              let moved = shifted(shut, dx: registration.dx, dy: registration.dy) else { return nil }
        let ring = Set(masks.gainRing)
        let whole = [UInt8](repeating: 255, count: open.width * open.height)
        return composite(base: open, top: moved, gate: whole, ring: { ring.contains($0) })
    }

    private static func fillEye(_ eye: HeadRig.Eye, in context: CGContext, side: CGFloat) {
        let rx = eye.rx * side * lidReachX, ry = max(eye.ry * lidReachY, eye.rx * 0.8) * side
        context.saveGState()
        context.translateBy(x: eye.x * side, y: eye.y * side)
        context.rotate(by: CGFloat(eye.angle))
        context.fillEllipse(in: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
        context.restoreGState()
    }

    /// The opening itself, a touch larger: where the painted eye is.
    private static func fillOpening(_ eye: HeadRig.Eye, in context: CGContext, side: CGFloat) {
        let grow: CGFloat = 1.15
        if let outline = eye.outline, outline.count >= 3 {
            let path = CGMutablePath()
            path.addLines(between: outline.map { point in
                CGPoint(x: (eye.x + (point.x - eye.x) * grow) * side, y: (eye.y + (point.y - eye.y) * grow) * side)
            })
            path.closeSubpath()
            context.addPath(path)
            context.fillPath()
            return
        }
        context.saveGState()
        context.translateBy(x: eye.x * side, y: eye.y * side)
        context.rotate(by: CGFloat(eye.angle))
        let rx = eye.rx * side * grow, ry = eye.ry * side * grow
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
        }), let soft = grey(gate, side: side) else { return nil }
        // Lit to match where the band feathers into the face below it.
        return composite(base: neutral, top: brows, gate: soft, ring: { soft[$0] > 25 && soft[$0] < 230 })
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
        /// Where the blink landed on neutral, and whether it fitted.
        var lidRegistration: Registration?
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

        if let blink, let shut = cgImage(blink),
           let neutralPatch = lidPatch(open: neutral, shut: shut, eyes: neutralFace.eyes) {
            let registration = neutralPatch.registration
            derived.lidRegistration = registration
            if neutralPatch.fits, let png = pngData(neutralPatch.image) {
                derived.shut[.neutral] = png
                // The same blink, registered for neutral, on the other faces
                // that draw their eyes (they share neutral's eye alignment).
                if let brows = browsImage, !browsEyes.isEmpty,
                   let patched = lidPatch(open: brows, shut: shut, eyes: browsEyes, registration: registration),
                   let png = pngData(patched.image) {
                    derived.shut[.browsUp] = png
                }
                if let raw = faces[.surprised], !raw.eyes.isEmpty, let surprised = cgImage(raw.png),
                   let patched = lidPatch(open: surprised, shut: shut, eyes: raw.eyes, registration: registration),
                   let png = pngData(patched.image) {
                    derived.shut[.surprised] = png
                }
            } else if let frame = blinkFrame(open: neutral, shut: shut, eyes: neutralFace.eyes,
                                             registration: registration),
                      let png = pngData(frame) {
                // **Refused**: the whole blink frame, moved and lit to match,
                // for neutral only. The other faces get no blink rather than a
                // seam.
                derived.shut[.neutral] = png
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
