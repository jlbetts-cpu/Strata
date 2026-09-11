import AVFoundation
import CoreImage
import QuartzCore
import UIKit
import Vision

/// Reads the front camera while a head is being made.
///
/// Lining up, it looks at about ten frames a second and says what to change.
/// During the blink, the smile and the raised brows it looks at every frame
/// and keeps only the best of each — most open eyes, most shut, widest smile,
/// highest brows — as images with their eye outlines, so seconds of video
/// never sit in memory. Then it lifts the person out, paints the eyes ready
/// for drawn irises, and crops every face to the same place.
///
/// `nonisolated` and queue-confined: the app's default isolation is the main
/// actor, and none of this may run there.
nonisolated final class HeadCaptureEngine: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {

    nonisolated enum Phase: Sendable { case idle, lining, blink, smile, brows, surprised }
    nonisolated enum Slot: Sendable { case open, shut, smile, brows, surprised }

    nonisolated struct Update: Sendable {
        let hint: HeadFraming.Hint?
        /// The frame's size in pixels, so the view can map the outline onto
        /// an aspect-filled preview.
        let frameSize: CGSize
        /// During an expression phase: whether what has been kept so far is
        /// really the expression that was asked for. Always false while
        /// lining up.
        ///
        /// Which phase this was measured in. The maker checks it before
        /// acting: a stage now ENDS when its expression lands, so an update
        /// from the phase just finished, delivered a moment late, would end
        /// the next stage the instant it began and silently drop an
        /// expression. Cheap to prevent, and close to undiagnosable from a
        /// phone.
        var phase: Phase = .idle
        /// **Before this existed the engine said nothing for seven seconds.**
        /// Both callbacks below were gated on `.lining`, so from the moment
        /// the shutter was pressed until the head came out, the maker ran a
        /// blind timer and reported to nobody. From a phone: "idk if it is
        /// working."
        var caught: Bool = false
    }

    /// One kept frame and what was measured on it.
    nonisolated struct Take: @unchecked Sendable {
        let image: CGImage
        /// Normalised, top-left origin.
        let face: CGRect
        let score: Double
        /// Both eyes' outlines in the frame's PIXELS, top-left origin: what the
        /// eyes are painted from, and what lines every expression up.
        let eyes: [[CGPoint]]
        let smileWidth: Double?
        let browRaise: Double?
        let mouthOpen: Double?

        var eyeCentres: (CGPoint, CGPoint)? {
            guard eyes.count == 2,
                  let a = HeadFraming.centre(of: eyes[0]),
                  let b = HeadFraming.centre(of: eyes[1]) else { return nil }
            return a.x < b.x ? (a, b) : (b, a)
        }
    }

    /// A finished face.
    nonisolated struct Made: Sendable {
        let png: Data
        let eyes: [HeadRig.Eye]
    }

    let output = AVCaptureVideoDataOutput()
    var onUpdate: (@Sendable (Update) -> Void)?

    private let queue = DispatchQueue(label: "strata.head.capture", qos: .userInitiated)
    private let lock = NSLock()
    private var phase: Phase = .idle
    private var target = HeadFraming.Target.standard
    private var kept: [Slot: Take] = [:]
    private var lastLining: CFTimeInterval = 0
    /// What was last published, so a boolean that has not changed does not
    /// hop to the main actor thirty times a second.
    private var lastCaught = false
    private let context = CIContext(options: [.cacheIntermediates: false])

    override init() {
        super.init()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: queue)
    }

    func begin(_ next: Phase) {
        lock.lock()
        defer { lock.unlock() }
        phase = next
        lastCaught = false
        switch next {
        case .blink: kept[.open] = nil; kept[.shut] = nil
        case .smile: kept[.smile] = nil
        case .brows: kept[.brows] = nil
        case .surprised: kept[.surprised] = nil
        case .idle, .lining: break
        }
    }

    func setTarget(_ next: HeadFraming.Target) {
        lock.lock()
        target = next
        lock.unlock()
    }

    var takes: [Slot: Take] {
        lock.lock()
        defer { lock.unlock() }
        return kept
    }

    /// Whether a slot holds a REAL expression rather than a neutral face that
    /// happened to measure a little further one way.
    ///
    /// **This is the only copy of that judgement, and it has to be.** Two
    /// callers need the same answer: the maker asks it live, to tell somebody
    /// their smile landed and to move on the moment it did; and `make()` asks
    /// it at the end, to decide whether the expression is worth keeping. Two
    /// copies would mean a tick on screen followed by a head that cannot
    /// smile — feedback that lies is worse than none.
    ///
    /// When a measure is missing the take is kept, which is what `make()` did
    /// inline before this existed: an unmeasurable face is not evidence the
    /// expression was not made.
    func caught(_ slot: Slot) -> Bool {
        lock.lock()
        let kept = self.kept
        lock.unlock()
        guard let neutral = kept[.open] else { return false }
        switch slot {
        case .open:
            return true
        case .shut:
            guard let shut = kept[.shut] else { return false }
            return HeadFraming.isRealBlink(open: neutral.score, shut: shut.score)
        case .smile:
            guard let take = kept[.smile] else { return false }
            guard let base = neutral.smileWidth, let wide = take.smileWidth else { return true }
            return HeadFraming.isRealSmile(neutral: base, smile: wide)
        case .brows:
            guard let take = kept[.brows] else { return false }
            guard let base = neutral.browRaise, let raised = take.browRaise else { return true }
            return HeadFraming.isRealBrowRaise(neutral: base, raised: raised)
        case .surprised:
            guard let take = kept[.surprised] else { return false }
            guard let base = neutral.mouthOpen, let wide = take.mouthOpen else { return true }
            return HeadFraming.isRealSurprise(neutral: base, surprised: wide)
        }
    }

    /// The slot an expression phase is filling. Nil for the phases that fill
    /// none.
    static func slot(for phase: Phase) -> Slot? {
        switch phase {
        case .blink:     return .shut
        case .smile:     return .smile
        case .brows:     return .brows
        case .surprised: return .surprised
        case .idle, .lining: return nil
        }
    }

    // MARK: - Frames

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lock.lock()
        let phase = self.phase
        let target = self.target
        lock.unlock()
        guard phase != .idle else { return }

        let size = CGSize(width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer))
        if phase == .lining {
            // Guidance does not need thirty answers a second, and the phone
            // stays cooler without them.
            let now = CACurrentMediaTime()
            guard now - lastLining >= 0.1 else { return }
            lastLining = now
        }

        let landmarks = VNDetectFaceLandmarksRequest()
        let quality = VNDetectFaceCaptureQualityRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up)
        do {
            try handler.perform(phase == .lining ? [landmarks, quality] : [landmarks])
        } catch {
            return
        }

        // The biggest face is the person holding the phone.
        guard let face = (landmarks.results ?? []).max(by: { $0.boundingBox.height < $1.boundingBox.height }) else {
            if phase == .lining { onUpdate?(Update(hint: .noFace, frameSize: size, phase: .lining)) }
            return
        }
        let box = CGRect(x: face.boundingBox.minX, y: 1 - face.boundingBox.maxY,
                         width: face.boundingBox.width, height: face.boundingBox.height)

        if phase == .lining {
            let score = (quality.results ?? [])
                .max(by: { $0.boundingBox.height < $1.boundingBox.height })?
                .faceCaptureQuality
            let reading = HeadFraming.Reading(face: box, yaw: face.yaw?.doubleValue,
                                              roll: face.roll?.doubleValue, quality: score.map(Double.init))
            onUpdate?(Update(hint: HeadFraming.hint(for: reading, target: target),
                             frameSize: size, phase: .lining))
            return
        }

        guard let marks = face.landmarks,
              let left = marks.leftEye?.normalizedPoints,
              let right = marks.rightEye?.normalizedPoints else { return }
        let smile = marks.outerLips.flatMap {
            HeadFraming.smileWidth(outerLips: $0.normalizedPoints, left: left, right: right)
        }
        let brows = (marks.leftEyebrow?.normalizedPoints ?? []) + (marks.rightEyebrow?.normalizedPoints ?? [])
        let raise = HeadFraming.browRaise(brows: brows, eyes: left + right)
        let mouth = marks.innerLips.flatMap {
            HeadFraming.mouthOpenness(innerLips: $0.normalizedPoints, left: left, right: right)
        }
        let measured = (box: box, face: face, size: size, smile: smile, raise: raise, mouth: mouth)

        switch phase {
        case .idle, .lining:
            return
        case .blink:
            guard let openness = HeadFraming.openness(left: left, right: right) else { return }
            offer(openness, to: .open, higherIsBetter: true, buffer: buffer, measured: measured)
            offer(openness, to: .shut, higherIsBetter: false, buffer: buffer, measured: measured)
        case .smile:
            guard let smile else { return }
            offer(smile, to: .smile, higherIsBetter: true, buffer: buffer, measured: measured)
        case .brows:
            guard let raise else { return }
            offer(raise, to: .brows, higherIsBetter: true, buffer: buffer, measured: measured)
        case .surprised:
            guard let mouth else { return }
            offer(mouth, to: .surprised, higherIsBetter: true, buffer: buffer, measured: measured)
        }

        // Say so the moment it lands, and only then. Published on the CHANGE
        // rather than per frame: the answer is one boolean and this runs at
        // the camera's full rate.
        guard let slot = Self.slot(for: phase) else { return }
        let landed = caught(slot)
        lock.lock()
        let changed = landed != lastCaught
        lastCaught = landed
        lock.unlock()
        if changed { onUpdate?(Update(hint: nil, frameSize: size, phase: phase, caught: landed)) }
    }

    private func offer(_ score: Double, to slot: Slot, higherIsBetter: Bool, buffer: CVPixelBuffer,
                       measured: (box: CGRect, face: VNFaceObservation, size: CGSize,
                                  smile: Double?, raise: Double?, mouth: Double?)) {
        lock.lock()
        let current = kept[slot]?.score
        lock.unlock()
        if let current, higherIsBetter ? score <= current : score >= current { return }
        guard let image = context.createCGImage(CIImage(cvPixelBuffer: buffer),
                                                from: CGRect(origin: .zero, size: measured.size)) else { return }
        let take = Take(image: image, face: measured.box, score: score,
                        eyes: Self.eyeOutlines(measured.face, size: measured.size),
                        smileWidth: measured.smile, browRaise: measured.raise, mouthOpen: measured.mouth)
        lock.lock()
        kept[slot] = take
        lock.unlock()
    }

    private static func eyeOutlines(_ face: VNFaceObservation, size: CGSize) -> [[CGPoint]] {
        [face.landmarks?.leftEye, face.landmarks?.rightEye].compactMap { region in
            region?.pointsInImage(imageSize: size).map { CGPoint(x: $0.x, y: size.height - $0.y) }
        }
    }

    // MARK: - Making a face

    /// Lifts the person out of a kept frame, crops it to `crop` (pixels), and —
    /// for a face that will have drawn irises — paints the eyes ready for them.
    ///
    /// `VNGenerateForegroundInstanceMaskRequest` is the subject lifting behind
    /// touch-and-hold in Photos. It finds every foreground object, so only the
    /// instance under the face is kept. Below the chin the head fades out, so
    /// it ends at the neck rather than at a pair of shoulders cut by the square.
    ///
    /// **Does not run in the simulator** (no inference context there).
    static func cutOut(_ take: Take, crop: CGRect, side: CGFloat, chin: CGFloat, paintsEyes: Bool) -> Made? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: take.image, orientation: .up)
        guard (try? handler.perform([request])) != nil,
              let observation = request.results?.first else { return nil }
        let instances = instance(at: CGPoint(x: take.face.midX, y: take.face.midY), in: observation)
        guard let masked = try? observation.generateMaskedImage(ofInstances: instances, from: handler,
                                                                croppedToInstancesExtent: false) else { return nil }
        let lifted = CIImage(cvPixelBuffer: masked)
        guard let cutout = CIContext().createCGImage(lifted, from: lifted.extent) else { return nil }

        let size = CGSize(width: take.image.width, height: take.image.height)
        let scale = side / crop.width
        func toCanvas(_ point: CGPoint) -> CGPoint {
            CGPoint(x: (point.x - crop.minX) * scale, y: (point.y - crop.minY) * scale)
        }

        // Both eyes or neither: one painted eye beside one real one reads as
        // broken, so a face where either eye cannot be sampled keeps its own.
        var openings: [(outline: [CGPoint], sclera: HeadRig.RGB, iris: HeadRig.RGB)] = []
        if paintsEyes {
            for eye in take.eyes {
                guard let colours = sampleColours(in: take.image, outline: eye) else { continue }
                openings.append((eye.map(toCanvas), colours.sclera, colours.iris))
            }
            if openings.count != 2 { openings = [] }
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let head = renderer.image { rendererContext in
            let cg = rendererContext.cgContext
            UIImage(cgImage: cutout).draw(in: CGRect(x: -crop.minX * scale, y: -crop.minY * scale,
                                                     width: size.width * scale, height: size.height * scale))
            cg.saveGState()
            cg.setBlendMode(.destinationOut)
            let fade = [UIColor.black.withAlphaComponent(0).cgColor, UIColor.black.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: fade, locations: [0, 1]) {
                cg.drawLinearGradient(gradient,
                                      start: CGPoint(x: 0, y: side * (chin - 0.01)),
                                      end: CGPoint(x: 0, y: side * min(chin + 0.05, 1)),
                                      options: [.drawsAfterEndLocation])
            }
            cg.restoreGState()
            for opening in openings {
                paint(opening.outline, sclera: opening.sclera, in: cg)
            }
        }
        guard let png = head.pngData() else { return nil }

        let eyes: [HeadRig.Eye] = openings.compactMap { opening in
            let fractions = opening.outline.map { CGPoint(x: $0.x / side, y: $0.y / side) }
            guard let shape = HeadFraming.eyeShape(outline: fractions) else { return nil }
            return HeadRig.Eye(x: shape.centre.x, y: shape.centre.y, rx: shape.rx, ry: shape.ry,
                               angle: shape.angle, outline: fractions, iris: opening.iris)
        }
        return Made(png: png, eyes: eyes.count == 2 ? eyes.sorted { $0.x < $1.x } : [])
    }

    /// Paints one eye's opening with the person's own eye-white, ready for a
    /// drawn iris: a soft edge so it meets the lid instead of being cut into
    /// it, and a little shade from the upper lid, without which the white
    /// reads as a sticker.
    private static func paint(_ outline: [CGPoint], sclera: HeadRig.RGB, in cg: CGContext) {
        guard outline.count >= 3 else { return }
        let path = CGMutablePath()
        path.addLines(between: outline)
        path.closeSubpath()
        let colour = UIColor(red: sclera.r, green: sclera.g, blue: sclera.b, alpha: 1).cgColor

        cg.saveGState()
        cg.setShadow(offset: .zero, blur: 1.5, color: colour)
        cg.setFillColor(colour)
        cg.addPath(path)
        cg.fillPath()
        cg.restoreGState()

        cg.saveGState()
        cg.addPath(path)
        cg.clip()
        let box = path.boundingBox
        let shade = [UIColor.black.withAlphaComponent(0.22).cgColor, UIColor.black.withAlphaComponent(0).cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: shade, locations: [0, 1]) {
            cg.drawLinearGradient(gradient, start: CGPoint(x: box.midX, y: box.minY),
                                  end: CGPoint(x: box.midX, y: box.minY + box.height * 0.55), options: [])
        }
        cg.restoreGState()
    }

    /// The eye's white and its iris, sampled from inside its own outline.
    ///
    /// **Measured on thirteen people's faces, not one.** The first version
    /// took the brightest third of the pixels as the white, and on almost
    /// every face that was eyelid and skin: the "white" came out
    /// 0.41/0.27/0.21 on one face and 0.20/0.13/0.10 on another. So:
    /// - the outline is shrunk 20% towards its middle first, clear of the
    ///   lashes and lids Vision's contour runs along;
    /// - the white is the pixels that are bright AND colourless, because skin
    ///   is never colourless and a white always nearly is;
    /// - the result is pulled most of the way to grey and kept inside a
    ///   natural brightness, so a dim photo still gets a white that reads as
    ///   an eye rather than a patch;
    /// - the iris is the darker middle of the pixels, skipping the darkest,
    ///   which are the pupil and the lashes.
    private static func sampleColours(in image: CGImage, outline rawOutline: [CGPoint]) -> (sclera: HeadRig.RGB, iris: HeadRig.RGB)? {
        guard rawOutline.count >= 4, let middle = HeadFraming.centre(of: rawOutline) else { return nil }
        let outline = rawOutline.map { CGPoint(x: middle.x + ($0.x - middle.x) * 0.8, y: middle.y + ($0.y - middle.y) * 0.8) }
        guard let minX = outline.map(\.x).min(), let maxX = outline.map(\.x).max(),
              let minY = outline.map(\.y).min(), let maxY = outline.map(\.y).max() else { return nil }
        let box = CGRect(x: floor(minX), y: floor(minY), width: ceil(maxX - minX) + 1, height: ceil(maxY - minY) + 1)
            .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard box.width >= 4, box.height >= 2, let patch = image.cropping(to: box) else { return nil }

        let width = patch.width, height = patch.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = pixels.withUnsafeMutableBytes { raw in
            guard let context = CGContext(data: raw.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(patch, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }

        let polygon = CGMutablePath()
        polygon.addLines(between: outline)
        polygon.closeSubpath()
        var samples: [(luminance: Double, rgb: HeadRig.RGB)] = []
        for y in 0..<height {
            for x in 0..<width {
                let point = CGPoint(x: box.minX + CGFloat(x) + 0.5, y: box.minY + CGFloat(y) + 0.5)
                guard polygon.contains(point) else { continue }
                let i = (y * width + x) * 4
                let r = Double(pixels[i]) / 255, g = Double(pixels[i + 1]) / 255, b = Double(pixels[i + 2]) / 255
                samples.append((0.2126 * r + 0.7152 * g + 0.0722 * b, HeadRig.RGB(r: r, g: g, b: b)))
            }
        }
        guard samples.count >= 12 else { return nil }
        let count = samples.count

        func mean(_ slice: ArraySlice<(luminance: Double, rgb: HeadRig.RGB)>) -> HeadRig.RGB {
            let n = Double(slice.count)
            return HeadRig.RGB(r: slice.map(\.rgb.r).reduce(0, +) / n,
                               g: slice.map(\.rgb.g).reduce(0, +) / n,
                               b: slice.map(\.rgb.b).reduce(0, +) / n)
        }
        func saturation(_ c: HeadRig.RGB) -> Double {
            let high = max(c.r, c.g, c.b), low = min(c.r, c.g, c.b)
            return high > 0 ? (high - low) / high : 0
        }

        // The white: bright and colourless, the top quarter by that score.
        let whitest = samples.sorted { $0.luminance - 0.9 * saturation($0.rgb) > $1.luminance - 0.9 * saturation($1.rgb) }
        let raw = mean(whitest[..<max(count / 4, 3)])
        let rawLuminance = 0.2126 * raw.r + 0.7152 * raw.g + 0.0722 * raw.b
        let luminance = min(max(rawLuminance * 1.15, 0.55), 0.86)
        let grey = 0.65
        let sclera = HeadRig.RGB(r: raw.r * (1 - grey) + luminance * grey,
                                 g: raw.g * (1 - grey) + luminance * grey,
                                 b: raw.b * (1 - grey) + luminance * grey)

        // The iris: the darker middle, past the pupil and lashes.
        let darkest = samples.sorted { $0.luminance < $1.luminance }
        let iris = mean(darkest[(count * 15 / 100)..<max(count * 45 / 100, count * 15 / 100 + 1)])
        return (sclera, iris)
    }

    /// The instance label under a point, or every instance if the point lands
    /// on background (a face box's centre can fall on a soft edge of a mask).
    private static func instance(at point: CGPoint, in observation: VNInstanceMaskObservation) -> IndexSet {
        let mask = observation.instanceMask
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(mask) else { return observation.allInstances }
        let width = CVPixelBufferGetWidth(mask)
        let height = CVPixelBufferGetHeight(mask)
        let row = CVPixelBufferGetBytesPerRow(mask)
        let x = min(max(Int(point.x * CGFloat(width)), 0), width - 1)
        let y = min(max(Int(point.y * CGFloat(height)), 0), height - 1)
        let label = base.assumingMemoryBound(to: UInt8.self)[y * row + x]
        return label == 0 ? observation.allInstances : IndexSet(integer: Int(label))
    }
}
