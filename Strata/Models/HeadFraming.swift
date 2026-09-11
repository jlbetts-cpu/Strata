import CoreGraphics
import Foundation

/// The arithmetic behind making a head: is the face where it should be, are
/// the eyes open or shut, is that a smile or raised brows, how to line one
/// expression up with the next, and where to crop.
///
/// Pure, over plain geometry, so every threshold can be tested without a
/// camera — the simulator has none, and the maker is otherwise unverifiable
/// here. `HeadCaptureEngine` turns Vision's observations into these inputs.
///
/// Frame coordinates are NORMALISED with a TOP-LEFT origin, the way SwiftUI
/// draws, unless a function says it takes Vision's landmark space.
nonisolated enum HeadFraming {

    /// One frame's reading of the face.
    nonisolated struct Reading: Equatable, Sendable {
        /// The face's bounding box in the frame, 0...1, top-left origin.
        var face: CGRect
        /// Radians. Turning the head left and right.
        var yaw: Double? = nil
        /// Radians. Tilting the head towards a shoulder.
        var roll: Double? = nil
        /// Vision's face capture quality, 0...1 — blur, light and pose in one.
        var quality: Double? = nil
    }

    /// Where the face should be in the frame: its height and its centre, as
    /// shares of the frame. The maker derives it from where it draws the
    /// outline, so "lined up" means inside the outline on the screen.
    nonisolated struct Target: Equatable, Sendable {
        var height: CGFloat
        var centreY: CGFloat
        static let standard = Target(height: 0.34, centreY: 0.46)
    }

    /// What to tell somebody lining up, most important first. Nil means they
    /// are lined up.
    nonisolated enum Hint: Equatable, Sendable {
        case noFace, moveCloser, moveBack, moveIntoOutline, faceCamera, levelHead, moreLight

        var caption: String {
            switch self {
            case .noFace:          return "Move your head into the outline"
            case .moveCloser:      return "Move a little closer"
            case .moveBack:        return "Move back a little"
            case .moveIntoOutline: return "Move into the outline"
            case .faceCamera:      return "Face the camera"
            case .levelHead:       return "Keep your head level"
            case .moreLight:       return "Find a little more light"
            }
        }
    }

    // MARK: - Lining up

    /// How far from the target height a face may be and still fit.
    static let heightTolerance: CGFloat = 0.08
    /// How far its centre may sit above or below the target's.
    static let centreYTolerance: CGFloat = 0.12
    static let centreX: ClosedRange<CGFloat> = 0.38...0.62
    /// About 20 degrees. Past it, one side of the face is foreshortened
    /// enough that the cut-out stops looking like the person head-on.
    static let maxYaw = 0.35
    /// About 14 degrees.
    static let maxRoll = 0.25
    /// Below this Vision is usually describing a dark or blurred frame.
    static let minQuality = 0.25

    /// Distance first, because moving closer or back also moves where the
    /// face sits; then position; then pose; light last, because a frame that
    /// is wrong in every way is also usually rated low quality, and "more
    /// light" is the least useful thing to say to somebody half out of shot.
    static func hint(for reading: Reading?, target: Target = .standard) -> Hint? {
        guard let reading else { return .noFace }
        let face = reading.face
        if face.height < target.height - heightTolerance { return .moveCloser }
        if face.height > target.height + heightTolerance { return .moveBack }
        if !centreX.contains(face.midX) || abs(face.midY - target.centreY) > centreYTolerance {
            return .moveIntoOutline
        }
        if let yaw = reading.yaw, abs(yaw) > maxYaw { return .faceCamera }
        if let roll = reading.roll, abs(roll) > maxRoll { return .levelHead }
        if let quality = reading.quality, quality < minQuality { return .moreLight }
        return nil
    }

    // MARK: - Eyes

    /// How open one eye is: the height of its landmark outline over its width.
    ///
    /// The same idea as the eye aspect ratio (Soukupová & Čech, 2016), taken
    /// over Vision's eye contour rather than dlib's six points.
    static func openness(of eye: [CGPoint]) -> Double? {
        guard eye.count >= 4,
              let minX = eye.map(\.x).min(), let maxX = eye.map(\.x).max(),
              let minY = eye.map(\.y).min(), let maxY = eye.map(\.y).max(),
              maxX - minX > 0 else { return nil }
        return Double((maxY - minY) / (maxX - minX))
    }

    /// Both eyes, averaged. A wink is not a blink, so both must be readable.
    static func openness(left: [CGPoint], right: [CGPoint]) -> Double? {
        guard let l = openness(of: left), let r = openness(of: right) else { return nil }
        return (l + r) / 2
    }

    /// Whether a most-open and a most-shut frame are an actual blink: an
    /// absolute gap, so a squint is not taken for one, and a proportion, so
    /// narrow eyes still count. Thick-framed glasses tend to fail both, and
    /// the head is then saved without blinking rather than blinking wrong.
    static func isRealBlink(open: Double, shut: Double) -> Bool {
        open - shut >= 0.08 && shut <= open * 0.6
    }

    /// The opening's centre, half-width, half-height and tilt, from its
    /// outline. The corners are the outline's leftmost and rightmost points;
    /// the height is measured across the line between them, not straight up,
    /// so a tilted eye is not read as a tall one.
    static func eyeShape(outline: [CGPoint]) -> (centre: CGPoint, rx: CGFloat, ry: CGFloat, angle: Double)? {
        guard outline.count >= 4,
              let inner = outline.min(by: { $0.x < $1.x }),
              let outer = outline.max(by: { $0.x < $1.x }) else { return nil }
        let angle = atan2(Double(outer.y - inner.y), Double(outer.x - inner.x))
        let rx = hypot(outer.x - inner.x, outer.y - inner.y) / 2
        let mid = CGPoint(x: (inner.x + outer.x) / 2, y: (inner.y + outer.y) / 2)
        let s = CGFloat(sin(angle)), c = CGFloat(cos(angle))
        let across = outline.map { -($0.x - mid.x) * s + ($0.y - mid.y) * c }
        guard let low = across.min(), let high = across.max(), rx > 0, high > low else { return nil }
        let shift = (high + low) / 2
        let centre = CGPoint(x: mid.x - shift * s, y: mid.y + shift * c)
        return (centre, rx, (high - low) / 2, angle)
    }

    // MARK: - Expressions

    /// Mouth width over the distance between the eyes' centres. It grows with
    /// a smile and not with distance from the camera, which a raw width would.
    static func smileWidth(outerLips: [CGPoint], left: [CGPoint], right: [CGPoint]) -> Double? {
        guard let minX = outerLips.map(\.x).min(), let maxX = outerLips.map(\.x).max(),
              let l = centre(of: left), let r = centre(of: right) else { return nil }
        let eyes = hypot(r.x - l.x, r.y - l.y)
        guard eyes > 0 else { return nil }
        return Double((maxX - minX) / eyes)
    }

    /// How far the brows sit above the eyes, in Vision's face-box units (y
    /// up). Grows when the brows go up; does not change with distance.
    static func browRaise(brows: [CGPoint], eyes: [CGPoint]) -> Double? {
        guard !brows.isEmpty, !eyes.isEmpty else { return nil }
        let brow = brows.map(\.y).reduce(0, +) / CGFloat(brows.count)
        let eye = eyes.map(\.y).reduce(0, +) / CGFloat(eyes.count)
        return Double(brow - eye)
    }

    /// Whether the widest-mouth frame is a smile rather than a neutral mouth
    /// that happened to be measured a little wider.
    static func isRealSmile(neutral: Double, smile: Double) -> Bool {
        smile - neutral >= 0.06
    }

    /// Whether the highest-brows frame is raised brows rather than a neutral
    /// face measured on a good frame. Brows go up by roughly a twentieth of
    /// the face's height; half of that is the least worth keeping.
    static func isRealBrowRaise(neutral: Double, raised: Double) -> Bool {
        raised - neutral >= 0.025
    }

    /// How open the mouth is: the inner lips' height over the distance between
    /// the eyes' centres, so it does not change with distance from the camera.
    static func mouthOpenness(innerLips: [CGPoint], left: [CGPoint], right: [CGPoint]) -> Double? {
        guard let minY = innerLips.map(\.y).min(), let maxY = innerLips.map(\.y).max(),
              let l = centre(of: left), let r = centre(of: right) else { return nil }
        let eyes = hypot(r.x - l.x, r.y - l.y)
        guard eyes > 0 else { return nil }
        return Double((maxY - minY) / eyes)
    }

    /// Whether the most-open-mouth frame is a surprised face rather than a
    /// neutral one caught mid-word. A dropped jaw opens the inner lips by
    /// roughly a third of the eye distance; a quarter of that is kept.
    static func isRealSurprise(neutral: Double, surprised: Double) -> Bool {
        surprised - neutral >= 0.12
    }

    static func centre(of points: [CGPoint]) -> CGPoint? {
        guard !points.isEmpty else { return nil }
        let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
    }

    // MARK: - Cropping

    /// How far the whole head reaches, as a multiple of the face box's height.
    /// Vision's box runs from about the brows to the chin; hair adds roughly
    /// half as much again above it.
    static let headOverFace: CGFloat = 1.5

    /// The square to crop from a frame, in PIXELS, so the head fills
    /// `contentHeight` of it with the chin at `chin`. May extend past the
    /// frame; the renderer fills that with transparency.
    static func crop(face: CGRect, in size: CGSize, contentHeight: CGFloat, chin: CGFloat) -> CGRect {
        let facePixels = CGRect(x: face.minX * size.width, y: face.minY * size.height,
                                width: face.width * size.width, height: face.height * size.height)
        let side = facePixels.height * headOverFace / contentHeight
        return CGRect(x: facePixels.midX - side / 2, y: facePixels.maxY - chin * side,
                      width: side, height: side)
    }

    /// The crop for another expression, lined up with a reference crop BY THE
    /// EYES.
    ///
    /// A smile moves the chin and raised brows move the face box, so cropping
    /// each expression by its own box would make the head jump every time it
    /// changed face. The eyes barely move between expressions, so the crop is
    /// carried from the reference by where the eyes are and how far apart.
    static func alignedCrop(reference: CGRect,
                            referenceEyes: (CGPoint, CGPoint),
                            eyes: (CGPoint, CGPoint)) -> CGRect {
        let referenceMid = midpoint(referenceEyes), mid = midpoint(eyes)
        let referenceSpan = distance(referenceEyes), span = distance(eyes)
        guard referenceSpan > 0, span > 0 else { return reference }
        let scale = span / referenceSpan
        let dx = (reference.midX - referenceMid.x) * scale
        let dy = (reference.midY - referenceMid.y) * scale
        let width = reference.width * scale, height = reference.height * scale
        return CGRect(x: mid.x + dx - width / 2, y: mid.y + dy - height / 2, width: width, height: height)
    }

    private static func midpoint(_ pair: (CGPoint, CGPoint)) -> CGPoint {
        CGPoint(x: (pair.0.x + pair.1.x) / 2, y: (pair.0.y + pair.1.y) / 2)
    }

    private static func distance(_ pair: (CGPoint, CGPoint)) -> CGFloat {
        hypot(pair.1.x - pair.0.x, pair.1.y - pair.0.y)
    }
}
