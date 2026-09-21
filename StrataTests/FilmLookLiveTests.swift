import Testing
import CoreImage
import Foundation
@testable import Strata

/// The two things that would break a live viewfinder, as assertions.
///
/// Both are real in the shipping still path too — they are simply invisible
/// there, because a still renders once. They are pinned here before any live
/// path exists, so the live path does not have to rediscover them.
struct FilmLookLiveTests {

    // MARK: - The white balance must not breathe

    /// The grey-world correction is capped at 7% and scaled by how neutral the
    /// scene already is. Neither could be asserted while the arithmetic was
    /// welded to a GPU readback.
    @Test("a neutral scene is left almost alone")
    func neutralScenesAreLeftAlone() throws {
        let g = try #require(FilmLookRenderer.neutralisingGains(
            means: [0.5, 0.5, 0.5], strength: 1))
        for gain in g { #expect(abs(gain - 1) < 0.0001) }
    }

    /// The failure mode this cap exists for: a lawn, a sunset, a team in blue.
    /// A strongly coloured scene must KEEP its colour.
    @Test("a strongly coloured scene keeps its colour")
    func colouredScenesKeepTheirColour() throws {
        // A lawn: green far above red and blue, spread well past 0.16.
        let lawn = try #require(FilmLookRenderer.neutralisingGains(
            means: [0.20, 0.55, 0.18], strength: 1))
        for gain in lawn {
            #expect(abs(gain - 1) < 0.0001,
                    "confidence did not fall to zero on a strongly coloured scene")
        }
        // A mild cast is corrected, so the confidence ramp is not just off.
        let mild = try #require(FilmLookRenderer.neutralisingGains(
            means: [0.48, 0.50, 0.52], strength: 1))
        #expect(mild.contains { abs($0 - 1) > 0.0005 })
    }

    @Test("the correction can never exceed seven percent")
    func theCapHolds() throws {
        // An extreme cast, at full strength, still inside the cap.
        let g = try #require(FilmLookRenderer.neutralisingGains(
            means: [0.02, 0.50, 0.02], strength: 1))
        for gain in g { #expect(gain >= 0.93 - 0.0001 && gain <= 1.07 + 0.0001) }
    }

    @Test("a black frame is not corrected at all")
    func blackFramesAreSkipped() {
        #expect(FilmLookRenderer.neutralisingGains(means: [0, 0, 0], strength: 1) == nil)
        #expect(FilmLookRenderer.neutralisingGains(means: [0.5, 0.5], strength: 1) == nil)
    }

    // MARK: - The grain must move with the scene

    /// `CIRandomGenerator` takes no seed: it is a deterministic function of
    /// position, so an untranslated field is identical every call. That is
    /// correct for a still and wrong for a viewfinder, where it would pin the
    /// grain to the glass.
    ///
    /// This asserts the property the live path depends on — that a phase
    /// actually changes the pixels — rather than asserting the call.
    @Test("moving the noise field changes the noise")
    func aPhaseChangesTheField() throws {
        let ctx = CIContext(options: [.useSoftwareRenderer: true])
        let box = CGRect(x: 0, y: 0, width: 8, height: 8)

        func sample(phase: CGPoint) throws -> [UInt8] {
            let noise = try #require(CIFilter.randomGenerator().outputImage)
                .transformed(by: CGAffineTransform(translationX: phase.x, y: phase.y))
                .cropped(to: box)
            var bytes = [UInt8](repeating: 0, count: 8 * 8 * 4)
            ctx.render(noise, toBitmap: &bytes, rowBytes: 8 * 4, bounds: box,
                       format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
            return bytes
        }

        let still = try sample(phase: .zero)
        // The same phase twice is identical, which is what keeps a
        // re-rendered photograph reproducible.
        #expect(try sample(phase: .zero) == still)
        // A different phase is a different field, which is what stops the
        // grain sitting still on a live viewfinder.
        #expect(try sample(phase: CGPoint(x: 137, y: 89)) != still)
    }
}
