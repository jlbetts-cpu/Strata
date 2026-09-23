import Testing
import SwiftUI
@testable import Strata

/// **The blades, checked as geometry.**
///
/// The shutter is open for a fifth of a second and a simulator has no camera,
/// so the failure mode here is one nobody would catch by looking: the shape
/// is fine in the middle of the sweep and wrong at the ends.
@Suite("The shutter's blades")
struct IrisShutterTests {

    private let frame = CGRect(x: 0, y: 0, width: 393, height: 852)

    private func path(_ openness: CGFloat, blades: Int = 6) -> Path {
        IrisShutter(openness: openness, blades: blades).path(in: frame)
    }

    /// Filled means covered by the blades. The shape is drawn even-odd — the
    /// whole frame, minus the opening — so that is how it has to be asked.
    private func covered(_ point: CGPoint, _ openness: CGFloat, blades: Int = 6) -> Bool {
        path(openness, blades: blades).contains(point, eoFill: true)
    }

    private var corners: [CGPoint] {
        [CGPoint(x: 1, y: 1),
         CGPoint(x: frame.maxX - 1, y: 1),
         CGPoint(x: 1, y: frame.maxY - 1),
         CGPoint(x: frame.maxX - 1, y: frame.maxY - 1)]
    }

    /// **The bug this exists for.** A hexagon sized by its CIRCUMRADIUS
    /// reaches the corners with its vertices and cuts inside them with its
    /// edges, so a shutter that is meant to be wide open leaves four dark
    /// wedges in the corners of the viewfinder — permanently, on every frame
    /// the camera ever shows. Dividing by cos(pi/n) puts the flats on the
    /// diagonal instead.
    @Test("Wide open, the blades cover nothing at all, corners included")
    func openCoversNothing() {
        for corner in corners {
            #expect(!covered(corner, 1.0), "a corner is covered at full openness")
        }
        #expect(!covered(CGPoint(x: frame.midX, y: frame.midY), 1.0))
    }

    /// True for any blade count, because the lab has a stepper on it and a
    /// three-bladed iris cuts the deepest corners of all.
    @Test("No blade count leaves a corner covered when open")
    func openCoversNothingAtAnyBladeCount() {
        for blades in 3...10 {
            for corner in corners {
                #expect(!covered(corner, 1.0, blades: blades),
                        "\(blades) blades cover a corner at full openness")
            }
        }
    }

    @Test("Shut, the blades cover everything")
    func shutCoversEverything() {
        #expect(covered(CGPoint(x: frame.midX, y: frame.midY), 0))
        for corner in corners {
            #expect(covered(corner, 0))
        }
    }

    /// The middle of the frame is the last thing to go dark, so it is the
    /// clearest test of the direction of travel.
    @Test("The centre goes dark late and the edges go dark early")
    func itClosesInward() {
        let centre = CGPoint(x: frame.midX, y: frame.midY)
        let nearEdge = CGPoint(x: frame.midX, y: 8)
        #expect(!covered(centre, 0.5))
        #expect(covered(nearEdge, 0.5), "an edge is still clear halfway shut")
        // The centre is the LAST thing the blades reach — at 2% open there
        // is still a pinhole of picture in the middle of the frame. The
        // first version of this line asserted the opposite of its own
        // message and the test caught it.
        #expect(!covered(centre, 0.02), "the centre went dark before the edges did")
    }

    /// Nothing may un-cover as the shutter closes. A rotating polygon can do
    /// exactly that at a point near a blade's edge if the spin outruns the
    /// shrink, and it would read as a flicker.
    @Test("Every point, once covered, stays covered all the way shut")
    func coverageOnlyGrows() {
        let steps = stride(from: 1.0, through: 0.0, by: -0.05).map { CGFloat($0) }
        var samples: [CGPoint] = []
        for x in stride(from: 10, to: frame.maxX, by: 47) {
            for y in stride(from: 10, to: frame.maxY, by: 71) {
                samples.append(CGPoint(x: x, y: y))
            }
        }
        for point in samples {
            var wasCovered = false
            for step in steps {
                let now = covered(point, step)
                if wasCovered {
                    #expect(now, "\(point) uncovered again at openness \(step)")
                }
                wasCovered = wasCovered || now
            }
        }
    }

    /// The blink's own timing: shut faster than it opens, because a leaf
    /// shutter is driven closed and returns. Matched or reversed, it reads as
    /// a crossfade rather than as a mechanism.
    @Test("It shuts faster than it opens")
    func springsShutAndReturns() {
        #expect(ShutterBlink.shutDuration < ShutterBlink.openDuration)
        #expect(ShutterBlink.total < 0.30, "a ritual you wait for is a delay")
        #expect(ShutterBlink.darkDuration > 0, "no dark frame means no exposure")
    }
}
