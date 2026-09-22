import Testing
import AVFoundation
import CoreGraphics
@testable import Strata

/// **The lens model, checked on a machine with no lenses.**
///
/// The camera opened `builtInWideAngleCamera` and nothing else, so on a phone
/// with three cameras the ultra-wide and the telephoto were never used: 0.5x
/// did not exist and 2x was a digital crop of the main sensor. It opens the
/// virtual device now, which hands over between the real lenses by itself as
/// the zoom factor crosses its switchover points.
///
/// The catch is that `videoZoomFactor` counts from a virtual device's WIDEST
/// lens, so factor 1.0 is the 0.5x view and the familiar 1x lives at the first
/// switchover. Everything this camera publishes is divided by that base. Get
/// the division wrong and every number on screen is wrong by a lens, so the
/// mapping is arithmetic and lives here.
struct CameraLensTests {

    /// An iPhone Pro: ultra-wide, wide, telephoto. The wide takes over at
    /// device factor 2 and the telephoto at 6, so 1x is device 2 and the
    /// telephoto reads as 3x.
    @Test("A three lens phone reads 0.5x, 1x and its telephoto")
    func threeLenses() {
        let stops = CameraService.stops(base: 2, switchovers: [2, 6],
                                        minZoom: 0.5, maxZoom: 8)
        #expect(stops.count == 3)
        #expect(abs(stops[0] - 0.5) < 0.001, "the ultra-wide must read as 0.5x, got \(stops[0])")
        #expect(abs(stops[1] - 1.0) < 0.001, "the wide must read as 1x, got \(stops[1])")
        #expect(abs(stops[2] - 3.0) < 0.001, "the telephoto must read as 3x, got \(stops[2])")
    }

    /// Two lenses, no telephoto.
    @Test("A two lens phone reads 0.5x and 1x")
    func twoLenses() {
        let stops = CameraService.stops(base: 2, switchovers: [2], minZoom: 0.5, maxZoom: 8)
        #expect(stops.count == 2)
        #expect(abs(stops[0] - 0.5) < 0.001)
        #expect(abs(stops[1] - 1.0) < 0.001)
    }

    /// **One lens must collapse to exactly what it was**, because that is
    /// every older phone, every iPad and the front camera, and none of them
    /// should notice this change happened.
    @Test("One lens is one stop, and the control hides itself")
    func oneLens() {
        let stops = CameraService.stops(base: 1, switchovers: [], minZoom: 1, maxZoom: 8)
        #expect(stops == [1], "a single lens phone gained a stop it does not have")
    }

    /// A stop outside the usable range is not a stop. A telephoto beyond the
    /// ceiling, or a wide below the floor, must not be offered.
    @Test("Stops outside what the lens will do are dropped")
    func stopsAreClamped() {
        let stops = CameraService.stops(base: 2, switchovers: [2, 6],
                                        minZoom: 0.5, maxZoom: 2)
        #expect(stops.count == 2, "the 3x telephoto is past the 2x ceiling and was offered anyway")
    }

    @Test("Tapping the control walks up the lenses and wraps")
    func cyclingTheStops() {
        let stops: [CGFloat] = [0.5, 1, 3]
        #expect(CameraService.stop(after: 0.5, in: stops) == 1)
        #expect(CameraService.stop(after: 1, in: stops) == 3)
        #expect(CameraService.stop(after: 3, in: stops) == 0.5, "the top must wrap to the widest")
    }

    /// A pinch leaves the lens between two stops. A tap from there should
    /// tidy UP rather than jump back, or the control would undo the gesture
    /// that was just made.
    @Test("From between two stops, a tap goes to the one above")
    func fromBetweenStops() {
        let stops: [CGFloat] = [0.5, 1, 3]
        #expect(CameraService.stop(after: 0.8, in: stops) == 1)
        #expect(CameraService.stop(after: 2.4, in: stops) == 3)
        #expect(CameraService.stop(after: 6.0, in: stops) == 0.5,
                "past the last stop there is nothing above, so it wraps")
    }

    /// The one case with no answer must still have one.
    @Test("An empty or broken stop list still answers 1x")
    func degenerateInput() {
        #expect(CameraService.stop(after: 1, in: []) == 1)
        #expect(CameraService.stops(base: 0, switchovers: [2], minZoom: 1, maxZoom: 8) == [1])
    }
}
