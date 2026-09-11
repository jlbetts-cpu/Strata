import Testing
import CoreGraphics
import Foundation
@testable import Strata

/// The maker's thresholds and geometry. Pinned here because the camera cannot
/// run on the simulator, so these are the only checks the maker gets before a
/// device.
@Suite("HeadFraming")
struct HeadFramingTests {

    private func reading(x: CGFloat = 0.5, y: CGFloat = 0.46, height: CGFloat = 0.34,
                         yaw: Double? = 0, roll: Double? = 0, quality: Double? = 0.8) -> HeadFraming.Reading {
        let width = height * 0.8
        return HeadFraming.Reading(face: CGRect(x: x - width / 2, y: y - height / 2,
                                                width: width, height: height),
                                   yaw: yaw, roll: roll, quality: quality)
    }

    private func close(_ a: CGFloat, _ b: CGFloat, _ tolerance: CGFloat = 1e-6) -> Bool { abs(a - b) < tolerance }

    // MARK: - Hints

    @Test("a centred, level, well-lit face at the right distance is lined up")
    func linedUp() {
        #expect(HeadFraming.hint(for: reading()) == nil)
    }

    @Test("no face asks for one")
    func noFace() {
        #expect(HeadFraming.hint(for: nil) == .noFace)
    }

    @Test("too small asks to come closer, too big to move back")
    func distance() {
        #expect(HeadFraming.hint(for: reading(height: 0.2)) == .moveCloser)
        #expect(HeadFraming.hint(for: reading(height: 0.5)) == .moveBack)
    }

    /// **The camera must not be zoomed while this is measuring.**
    ///
    /// `hint(for:)` reads distance from the face's height as a FRACTION of the
    /// frame, so any crop multiplies it. The front camera starts at
    /// `CameraService.frontPortraitCrop` — 1.3x, which is kinder to a face in
    /// a photograph — and with that on, a face framed exactly on target reads
    /// 0.442 against a ceiling of 0.42 and the maker says "move back" however
    /// far back you go. Reported from a phone: "saying to move back a little
    /// even though im far away."
    ///
    /// `CameraService.attachFrames` now lifts the crop for the duration. This
    /// test is what says why, and fails if anybody puts it back.
    @Test("a crop would make a correctly framed face read as too close")
    func aCropBreaksTheDistanceHint() {
        let target = HeadFraming.Target.standard
        #expect(HeadFraming.hint(for: reading(height: target.height)) == nil,
                "a face on target should be lined up")

        let crop: CGFloat = 1.3
        let asCropped = target.height * crop
        #expect(asCropped > target.height + HeadFraming.heightTolerance,
                "the arithmetic this test exists for no longer holds")
        #expect(HeadFraming.hint(for: reading(height: asCropped)) == .moveBack)

        // **The contradiction the person actually experiences.** With the crop
        // on, even the LARGEST face that passes the check is smaller than the
        // outline it is being asked to fill — so you line your head up inside
        // the outline, it looks right, and the app still says move back.
        let largestThatPasses = (target.height + HeadFraming.heightTolerance) / crop
        #expect(largestThatPasses < target.height,
                "with a crop there is no distance where the face both fills the outline and satisfies the check")
    }

    @Test("off to one side asks to move into the outline")
    func position() {
        #expect(HeadFraming.hint(for: reading(x: 0.2)) == .moveIntoOutline)
        #expect(HeadFraming.hint(for: reading(y: 0.7)) == .moveIntoOutline)
    }

    @Test("the target moves with the outline")
    func movingTarget() {
        let lower = HeadFraming.Target(height: 0.34, centreY: 0.62)
        #expect(HeadFraming.hint(for: reading(y: 0.62), target: lower) == nil)
        #expect(HeadFraming.hint(for: reading(y: 0.40), target: lower) == .moveIntoOutline)
    }

    @Test("turned or tilted asks to face the camera or level up")
    func pose() {
        #expect(HeadFraming.hint(for: reading(yaw: 0.5)) == .faceCamera)
        #expect(HeadFraming.hint(for: reading(roll: -0.4)) == .levelHead)
    }

    @Test("distance is said before light")
    func priority() {
        #expect(HeadFraming.hint(for: reading(height: 0.2, quality: 0.1)) == .moveCloser)
        #expect(HeadFraming.hint(for: reading(quality: 0.1)) == .moreLight)
    }

    // MARK: - Eyes

    private func eye(width: CGFloat, height: CGFloat) -> [CGPoint] {
        [CGPoint(x: 0, y: height / 2), CGPoint(x: width / 2, y: 0),
         CGPoint(x: width, y: height / 2), CGPoint(x: width / 2, y: height)]
    }

    @Test("openness is height over width")
    func opennessRatio() {
        #expect(HeadFraming.openness(of: eye(width: 10, height: 4)) == 0.4)
    }

    @Test("both eyes are needed")
    func bothEyes() {
        #expect(HeadFraming.openness(left: eye(width: 10, height: 4), right: []) == nil)
        // A tolerance, not `==`: (0.4 + 0.2) / 2 is 0.30000000000000004.
        let both = HeadFraming.openness(left: eye(width: 10, height: 4), right: eye(width: 10, height: 2))
        #expect(abs((both ?? 0) - 0.3) < 1e-9)
    }

    @Test("a real blink clears both the gap and the proportion")
    func blink() {
        #expect(HeadFraming.isRealBlink(open: 0.35, shut: 0.08))
        #expect(!HeadFraming.isRealBlink(open: 0.12, shut: 0.06))
        #expect(!HeadFraming.isRealBlink(open: 0.40, shut: 0.30))
    }

    @Test("an eye's shape: centre, radii and a level angle")
    func levelEyeShape() {
        let shape = HeadFraming.eyeShape(outline: eye(width: 10, height: 4).map {
            CGPoint(x: $0.x + 20, y: $0.y + 30)
        })
        #expect(shape != nil)
        #expect(close(shape!.centre.x, 25) && close(shape!.centre.y, 32))
        #expect(close(shape!.rx, 5) && close(shape!.ry, 2))
        #expect(abs(shape!.angle) < 1e-9)
    }

    @Test("a tilted eye is not read as a tall one")
    func tiltedEyeShape() {
        let tilt = CGFloat.pi / 12
        let rotated = eye(width: 10, height: 4).map { point -> CGPoint in
            let x = point.x - 5, y = point.y - 2
            return CGPoint(x: x * cos(tilt) - y * sin(tilt), y: x * sin(tilt) + y * cos(tilt))
        }
        let shape = HeadFraming.eyeShape(outline: rotated)
        #expect(shape != nil)
        #expect(close(CGFloat(shape!.angle), tilt, 1e-6))
        #expect(close(shape!.rx, 5, 1e-6) && close(shape!.ry, 2, 1e-6))
    }

    // MARK: - Expressions

    @Test("smile width does not change with distance")
    func smileScaleFree() {
        let lips = [CGPoint(x: 4, y: 10), CGPoint(x: 8, y: 10)]
        let left = [CGPoint(x: 3, y: 5)], right = [CGPoint(x: 9, y: 5)]
        let double = { (points: [CGPoint]) in points.map { CGPoint(x: $0.x * 2, y: $0.y * 2) } }
        let near = HeadFraming.smileWidth(outerLips: double(lips), left: double(left), right: double(right))
        let far = HeadFraming.smileWidth(outerLips: lips, left: left, right: right)
        #expect(near != nil && near == far)
    }

    @Test("brows above eyes, measured up")
    func browRaise() {
        let raise = HeadFraming.browRaise(brows: [CGPoint(x: 0, y: 0.8)], eyes: [CGPoint(x: 0, y: 0.6)])
        #expect(abs((raise ?? 0) - 0.2) < 1e-9)
        #expect(HeadFraming.browRaise(brows: [], eyes: [CGPoint(x: 0, y: 0.6)]) == nil)
    }

    @Test("only a real smile or a real raise is kept")
    func expressionThresholds() {
        #expect(HeadFraming.isRealSmile(neutral: 0.95, smile: 1.10))
        #expect(!HeadFraming.isRealSmile(neutral: 0.95, smile: 0.98))
        #expect(HeadFraming.isRealBrowRaise(neutral: 0.20, raised: 0.24))
        #expect(!HeadFraming.isRealBrowRaise(neutral: 0.20, raised: 0.21))
    }

    // MARK: - Crop

    @Test("the crop puts the chin where every head keeps it")
    func cropChin() {
        let face = CGRect(x: 0.4, y: 0.3, width: 0.2, height: 0.25)
        let size = CGSize(width: 1080, height: 1920)
        let crop = HeadFraming.crop(face: face, in: size, contentHeight: 0.86, chin: 0.93)
        let chinY = face.maxY * size.height
        #expect(close((chinY - crop.minY) / crop.height, 0.93, 1e-4))
        #expect(close(crop.midX, face.midX * size.width, 1e-4))
        #expect(close(crop.width, crop.height, 1e-4))
    }

    @Test("an expression lined up by the eyes keeps the same eyes in the same place")
    func alignedByEyes() {
        let reference = CGRect(x: 100, y: 200, width: 600, height: 600)
        let referenceEyes = (CGPoint(x: 340, y: 500), CGPoint(x: 460, y: 500))
        // Same eyes: same crop.
        let same = HeadFraming.alignedCrop(reference: reference, referenceEyes: referenceEyes, eyes: referenceEyes)
        #expect(same == reference)
        // Moved 30px right and 10% closer to the camera.
        let eyes = (CGPoint(x: 364, y: 500), CGPoint(x: 496, y: 500))
        let moved = HeadFraming.alignedCrop(reference: reference, referenceEyes: referenceEyes, eyes: eyes)
        #expect(close(moved.width, 660, 1e-6))
        // The left eye sits at the same fraction of both crops.
        #expect(close((referenceEyes.0.x - reference.minX) / reference.width,
                      (eyes.0.x - moved.minX) / moved.width, 1e-9))
        #expect(close((referenceEyes.0.y - reference.minY) / reference.height,
                      (eyes.0.y - moved.minY) / moved.height, 1e-9))
    }

    @Test("mouth openness does not change with distance")
    func mouthScaleFree() {
        let lips = [CGPoint(x: 5, y: 9), CGPoint(x: 6, y: 11)]
        let left = [CGPoint(x: 3, y: 5)], right = [CGPoint(x: 9, y: 5)]
        let double = { (points: [CGPoint]) in points.map { CGPoint(x: $0.x * 2, y: $0.y * 2) } }
        let near = HeadFraming.mouthOpenness(innerLips: double(lips), left: double(left), right: double(right))
        let far = HeadFraming.mouthOpenness(innerLips: lips, left: left, right: right)
        #expect(near != nil && near == far)
        #expect(abs((far ?? 0) - 2.0 / 6.0) < 1e-9)
    }

    @Test("only a real surprise is kept")
    func surpriseThreshold() {
        #expect(HeadFraming.isRealSurprise(neutral: 0.05, surprised: 0.35))
        #expect(!HeadFraming.isRealSurprise(neutral: 0.05, surprised: 0.12))
    }
}
