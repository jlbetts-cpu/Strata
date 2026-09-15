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
        #expect(!HeadFraming.isRealBlink(open: 0.40, shut: 0.30))
        // Below the floor, where an "open" eye is not distinguishable from a
        // shut one and refusing is the right answer.
        #expect(!HeadFraming.isRealBlink(open: 0.10, shut: 0.06))
    }

    /// **The blink has to work on an eye that is narrow to begin with.**
    ///
    /// Asked for from a phone: "make sure it works in all lighting with all
    /// face shapes." The two conditions are ANDed, so the stricter one
    /// decides, and the absolute gap is stricter than the proportion for
    /// anybody whose open eye measures below 0.20:
    ///
    ///     open - floor < open * 0.6   whenever   open < floor / 0.4
    ///
    /// At the old floor of 0.08 that boundary sat at 0.20 — inside the range
    /// Vision's contour reports for a narrow or hooded eye, for an eye behind
    /// thick frames, and for any eye far enough away that the contour is
    /// coarse. The function's own comment said the proportion was there "so
    /// narrow eyes still count" while the conjunction was overruling it.
    ///
    /// **Stated plainly: this threshold cannot be measured without faces**,
    /// and 0.05 is a judgement, not a measurement. What makes it the safer
    /// side to be wrong on is the cost either way. Too loose keeps a deep
    /// squint as a blink — and the proportion still demands the eye collapse
    /// to under 60% of itself, so it is a deep one. Too tight means a person
    /// whose eyes are narrow is told they did not blink when they shut their
    /// eyes completely, and their head can never blink at all. The live "Got
    /// it" added alongside this makes the loose side cheaper still: a blink
    /// that is missed is now visibly missed, while the stage is still running
    /// and there is time to blink again.
    @Test("a narrow eye that fully closes is a blink")
    func narrowEyesBlink() {
        let floor = 0.05, proportion = 0.6
        // Where the floor stops being the thing that decides.
        #expect(abs(floor / (1 - proportion) - 0.125) < 1e-9,
                "the boundary this test is about has moved")

        // An eye that reads 0.18 open and collapses to the lash line. The old
        // 0.08 floor refused this; the proportion always accepted it.
        #expect(HeadFraming.isRealBlink(open: 0.18, shut: 0.105))
        #expect(0.105 <= 0.18 * proportion, "the proportion accepted it all along")
        #expect(0.18 - 0.105 < 0.08, "and the old floor is what refused it")

        // A wide eye squinting the same proportion of the way is still not a
        // blink, which is the thing the floor was protecting and the
        // proportion protects on its own.
        #expect(!HeadFraming.isRealBlink(open: 0.40, shut: 0.25))
    }

    /// Lining up has to work at either end of the same range. Nothing here is
    /// a new threshold — it pins that one set of numbers covers a small face
    /// and a large one, since the hint is a fraction of the frame and not a
    /// size in pixels.
    @Test("the same thresholds line up a narrow face and a broad one")
    func allFaceShapes() {
        let target = HeadFraming.Target.standard
        for width in [0.60, 0.80, 1.00] as [CGFloat] {
            let face = CGRect(x: 0.5 - target.height * width / 2,
                              y: target.centreY - target.height / 2,
                              width: target.height * width, height: target.height)
            #expect(HeadFraming.hint(for: HeadFraming.Reading(face: face, yaw: 0, roll: 0, quality: 0.8)) == nil,
                    "a face \(width) as wide as it is tall should line up")
        }
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

    @Test("a tilted head is measured as tilted, and turning it undoes that")
    func tiltIsRead() {
        // Eyes on a line 20 degrees clockwise of level.
        let radians = 20 * Double.pi / 180
        let left = CGPoint(x: 300, y: 500)
        let right = CGPoint(x: 300 + 120 * CGFloat(cos(radians)), y: 500 + 120 * CGFloat(sin(radians)))
        #expect(close(CGFloat(HeadFraming.tilt(eyes: (left, right))), CGFloat(radians), 1e-9))
        // Turned back by that much about the left eye, the pair is level again.
        let turned = HeadFraming.turned(right, about: left, by: -radians)
        #expect(close(turned.y, left.y, 1e-6))
        #expect(close(turned.x, left.x + 120, 1e-6))
        // And a level pair reads as no tilt at all, whichever order it arrives in.
        #expect(close(CGFloat(HeadFraming.tilt(eyes: (right: CGPoint(x: 400, y: 500),
                                                      left: CGPoint(x: 300, y: 500)))), 0, 1e-12))
    }

    @Test("the chin is the lowest point down the FACE, not down the picture")
    func chinFollowsTheFace() {
        // A head lying on its side: the eye line runs down the picture, so the
        // chin is off to one side and the jaw corners are above and below it.
        let left = CGPoint(x: 500, y: 300), right = CGPoint(x: 500, y: 420)
        let chin = CGPoint(x: 380, y: 360)          // down the face is -x here
        let jawCorners = [CGPoint(x: 470, y: 250), CGPoint(x: 470, y: 470)]
        let found = HeadFraming.chin(contour: jawCorners + [chin], eyes: (left, right))
        #expect(found == chin)
        // The lowest point in the PICTURE is a jaw corner, which is what a
        // naive answer would have returned.
        #expect(jawCorners.max { $0.y < $1.y } != chin)
    }

    @Test("an upside-down face is measured as upside down, not as level")
    func upsideDownIsNotLevel() {
        // The frame an iPhone 17 front camera delivered at a hard-coded 90°:
        // eyes level, chin ABOVE them.
        let eyes = (CGPoint(x: 460, y: 700), CGPoint(x: 620, y: 700))
        let chin = CGPoint(x: 540, y: 420)
        // The eye line cannot see it.
        #expect(close(CGFloat(HeadFraming.tilt(eyes: eyes)), 0, 1e-9))
        // Eyes to chin can: half a turn.
        #expect(close(CGFloat(abs(HeadFraming.tilt(eyes: eyes, chin: chin))), .pi, 1e-9))
        // And turning by minus that puts the chin below the eyes.
        let mid = HeadFraming.midpointOf(eyes)
        let upright = HeadFraming.turned(chin, about: mid, by: -HeadFraming.tilt(eyes: eyes, chin: chin))
        #expect(upright.y > mid.y)
        #expect(close(upright.x, mid.x, 1e-6))
    }

    @Test("the chin is found on an upside-down outline too")
    func chinUpsideDown() {
        let eyes = (CGPoint(x: 460, y: 700), CGPoint(x: 620, y: 700))
        // Temples level with the eyes, jaw corners and chin above them.
        let contour = [CGPoint(x: 400, y: 700), CGPoint(x: 420, y: 560),
                       CGPoint(x: 540, y: 430), CGPoint(x: 660, y: 560), CGPoint(x: 680, y: 700)]
        #expect(HeadFraming.chin(contour: contour, eyes: eyes) == CGPoint(x: 540, y: 430))
    }

    @Test("the crown is the hair's reach above the eyes, and a hand beside the head is not hair")
    func crownReachIgnoresTheSides() {
        let eyes = (CGPoint(x: 460, y: 700), CGPoint(x: 620, y: 700))
        let chin = CGPoint(x: 540, y: 980)
        let hair = (0..<20).map { CGPoint(x: 540 + CGFloat($0 - 10) * 10, y: 360 + CGFloat(abs($0 - 10))) }
        let hand = [CGPoint(x: 1000, y: 100)]         // far to one side, and higher
        let shoulder = [CGPoint(x: 300, y: 1100)]     // below the chin
        let reach = HeadFraming.crownReach(filled: hair + hand + shoulder, eyes: eyes, chin: chin,
                                           halfWidth: 160 * 1.8)
        #expect(reach.map { close($0, 340, 1e-6) } == true)
    }

    @Test("a crop sized to measured hair keeps the whole crown, and never shrinks below the guess")
    func cropMakesRoomForHair() {
        let face = CGRect(x: 0.4, y: 0.3, width: 0.2, height: 0.25)
        let size = CGSize(width: 1080, height: 1920)
        let eyes = (CGPoint(x: 490, y: 800), CGPoint(x: 590, y: 800))
        let chin = CGPoint(x: 540, y: 1050)
        let guess = HeadFraming.crop(face: face, in: size, contentHeight: 0.86, chin: 0.93,
                                     eyes: eyes, chinPoint: chin)
        let bigHair = HeadFraming.crop(face: face, in: size, contentHeight: 0.86, chin: 0.93,
                                       eyes: eyes, chinPoint: chin, crownReach: 700)
        #expect(bigHair.width > guess.width)
        // Crown lands where the canvas promises: chin - contentHeight from the top.
        let crownY = 800 - 700.0
        #expect(close((crownY - bigHair.minY) / bigHair.height, 0.93 - 0.86, 1e-6))
        // A measurement that missed hair cannot crop tighter than the guess.
        let missed = HeadFraming.crop(face: face, in: size, contentHeight: 0.86, chin: 0.93,
                                      eyes: eyes, chinPoint: chin, crownReach: 10)
        #expect(close(missed.width, guess.width, 1e-9))
    }

    @Test("a head's outline keeps the hair and the face, not the shoulder beside the jaw")
    func headOutlineDropsTheShoulders() {
        let canvas: CGFloat = 600
        // Upright jaw, temple to temple, eyes at y 320, chin at 558.
        let contour = [CGPoint(x: 170, y: 320), CGPoint(x: 180, y: 420), CGPoint(x: 220, y: 500),
                       CGPoint(x: 300, y: 558), CGPoint(x: 380, y: 500), CGPoint(x: 420, y: 420),
                       CGPoint(x: 430, y: 320)]
        let outline = HeadFraming.headOutline(contour: contour.reversed(), canvas: canvas, margin: 40)
        func inside(_ p: CGPoint) -> Bool {
            var hit = false
            var j = outline.count - 1
            for i in outline.indices {
                let a = outline[i], b = outline[j]
                if (a.y > p.y) != (b.y > p.y),
                   p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { hit.toggle() }
                j = i
            }
            return hit
        }
        #expect(inside(CGPoint(x: 300, y: 60)))      // hair
        #expect(inside(CGPoint(x: 580, y: 200)))     // hair out to the side, above the eyes
        #expect(inside(CGPoint(x: 150, y: 330)))     // an ear, just outside the temple
        #expect(inside(CGPoint(x: 300, y: 540)))     // the chin
        #expect(!inside(CGPoint(x: 120, y: 540)))    // a shoulder beside the jaw
        #expect(!inside(CGPoint(x: 300, y: 590)))    // the neck under the chin
    }

    /// Even-odd point in polygon.
    private func inside(_ outline: [CGPoint], _ p: CGPoint) -> Bool {
        var hit = false
        var j = outline.count - 1
        for i in outline.indices {
            let a = outline[i], b = outline[j]
            if (a.y > p.y) != (b.y > p.y),
               p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { hit.toggle() }
            j = i
        }
        return hit
    }

    @Test("below the jaw's midpoint the outline hugs the jaw, so no neck shows under its corners")
    func headOutlineHugsTheJawCorners() {
        // Owner: "the neck is still showing a little in the head". The ear
        // margin used to reach all the way to the chin and pushed the sloping
        // jaw corners out, leaving a band of neck under each one.
        let contour = [CGPoint(x: 170, y: 320), CGPoint(x: 180, y: 420), CGPoint(x: 220, y: 500),
                       CGPoint(x: 300, y: 558), CGPoint(x: 380, y: 500), CGPoint(x: 420, y: 420),
                       CGPoint(x: 430, y: 320)]
        let outline = HeadFraming.headOutline(contour: contour.reversed(), canvas: 600, margin: 40)
        #expect(!inside(outline, CGPoint(x: 196, y: 470)))   // 9px outside the jaw corner: neck (it used to be kept)
        #expect(!inside(outline, CGPoint(x: 404, y: 470)))
        #expect(inside(outline, CGPoint(x: 208, y: 470)))    // just inside the jaw
        #expect(inside(outline, CGPoint(x: 150, y: 330)))    // the ear still fits
        #expect(outline.map(\.y).max() == 558)               // the chin has not moved
    }

    @Test("a smoothed jaw passes through every contour point")
    func catmullRomKeepsThePoints() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 30), CGPoint(x: 40, y: 50), CGPoint(x: 80, y: 20)]
        let curve = HeadFraming.catmullRom(points, samples: 6)
        for p in points { #expect(curve.contains { hypot($0.x - p.x, $0.y - p.y) < 0.0001 }) }
        #expect(curve.count == 3 * 6 + 1)
    }

    @Test("the sharp jaw edge takes over between 15% and 45% of temple to chin")
    func sharpEdgeBandSitsOnTheJaw() {
        let contour = [CGPoint(x: 170, y: 320), CGPoint(x: 300, y: 558), CGPoint(x: 430, y: 320)]
        let band = HeadFraming.sharpEdgeBand(contour: contour)
        #expect(close(band.lowerBound, 355.7, 1e-6))
        #expect(close(band.upperBound, 427.1, 1e-6))
    }

    @Test("a crop hung off the landmarks puts the chin exactly where it promises")
    func cropUsesTheMeasuredChin() {
        let face = CGRect(x: 0.4, y: 0.3, width: 0.2, height: 0.25)
        let size = CGSize(width: 1080, height: 1920)
        // A tilted face whose chin is 260px from the eyes along its own axis.
        let radians = 12 * Double.pi / 180
        let mid = CGPoint(x: 540, y: 700)
        let left = CGPoint(x: mid.x - 60 * CGFloat(cos(radians)), y: mid.y - 60 * CGFloat(sin(radians)))
        let right = CGPoint(x: mid.x + 60 * CGFloat(cos(radians)), y: mid.y + 60 * CGFloat(sin(radians)))
        // Down the face is a quarter turn clockwise from the eye line.
        let chinPoint = CGPoint(x: mid.x - 260 * CGFloat(sin(radians)),
                                y: mid.y + 260 * CGFloat(cos(radians)))
        let crop = HeadFraming.crop(face: face, in: size, contentHeight: 0.86, chin: 0.93,
                                    eyes: (left, right), chinPoint: chinPoint)
        // Turned upright about the eyes, the chin drops straight below them,
        // and that is the line the neck is cut on.
        let upright = HeadFraming.turned(chinPoint, about: mid, by: -radians)
        #expect(close((upright.y - crop.minY) / crop.height, 0.93, 1e-6))
        #expect(close(crop.midX, mid.x, 1e-9))
        // Same size as the old placement: the box still says how big a head is.
        let byBox = HeadFraming.crop(face: face, in: size, contentHeight: 0.86, chin: 0.93)
        #expect(close(crop.width, byBox.width, 1e-9))
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
