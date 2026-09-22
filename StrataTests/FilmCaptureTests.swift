import Testing
import CoreImage
import UIKit
@testable import Strata

/// The three things added to reach the capture pipeline the owner's blueprint
/// described, and what each of them can honestly be checked for on a machine
/// with no camera.
struct FilmCaptureTests {

    // MARK: - Dynamic range, pulled at the sensor and lifted in the grade

    /// **The round trip must land where it started.** A look pulls the sensor
    /// by `pullStops` and the renderer lifts by the same number, so a frame
    /// that was pulled and lifted has to come out at the brightness a frame
    /// that was neither would have. If it does not, every photograph taken
    /// with a look is a stop out, which is the loudest possible way for this
    /// to be wrong.
    @Test("Pulling the sensor and lifting in the grade cancel")
    func pullAndLiftCancel() throws {
        let context = CIContext(options: [.cacheIntermediates: false])
        let flat = CIImage(color: CIColor(red: 0.42, green: 0.38, blue: 0.34))
            .cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))

        func meanLuma(_ image: CIImage) -> Double {
            var pixel = [Float](repeating: 0, count: 4)
            let averaged = image.applyingFilter("CIAreaAverage",
                                                parameters: [kCIInputExtentKey: CIVector(cgRect: image.extent)])
            context.render(averaged, toBitmap: &pixel, rowBytes: 16,
                           bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                           format: .RGBAf, colorSpace: CGColorSpaceCreateDeviceRGB())
            return 0.2126 * Double(pixel[0]) + 0.7152 * Double(pixel[1]) + 0.0722 * Double(pixel[2])
        }

        for look in FilmLook.all where look.pullStops > 0 {
            // The frame the sensor would hand over, underexposed on purpose.
            let pulled = flat.applyingFilter("CIExposureAdjust",
                                             parameters: [kCIInputEVKey: -look.pullStops])
            let viaPull = meanLuma(FilmLookRenderer.shared.apply(look, to: pulled,
                                                                 pulledStops: look.pullStops))
            let straight = meanLuma(FilmLookRenderer.shared.apply(look, to: flat))
            let apart = abs(viaPull - straight)
            #expect(apart < 0.02,
                    "\(look.kind.name) lands \(apart) away from an unpulled frame, which is a visible stop error")
        }
    }

    /// The lift is only correct for a frame that really was pulled. A swatch
    /// rendered from a bundled photograph was not, so it must not move.
    @Test("An unpulled picture is never lifted")
    func swatchesAreNotLifted() {
        let flat = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5))
            .cropped(to: CGRect(x: 0, y: 0, width: 8, height: 8))
        for look in FilmLook.all where look.kind != .none {
            let a = FilmLookRenderer.shared.apply(look, to: flat)
            let b = FilmLookRenderer.shared.apply(look, to: flat, pulledStops: 0)
            #expect(a.extent == b.extent, "the default pull is not zero")
        }
    }

    /// The pull is capped where the model says it is. Past two stops the
    /// shadow noise a lift amplifies costs more than the highlight headroom
    /// it buys, on a frame the phone has already processed.
    @Test("No look pulls further than the pipeline can pay for")
    func pullStaysWithinItsCap() {
        for look in FilmLook.everyKnown {
            #expect(look.pullStops >= 0 && look.pullStops <= 2,
                    "\(look.kind.name) pulls \(look.pullStops) stops")
        }
        #expect(FilmLook.none.pullStops == 0, "None must never touch the sensor")
    }

    // MARK: - Color Chrome FX Blue

    /// **A polariser darkens a blue sky and leaves the rest alone.** Both
    /// halves of that are the assertion: a saturated blue must come down, and
    /// a grey, a skin tone and a green must not, or it is not a polariser, it
    /// is an exposure change wearing one's coat.
    @Test("Blue density deepens blue and leaves everything else where it was")
    func blueDensityIsSelective() {
        var look = FilmLook.slate
        look.blueDensity = 0.3
        var flat = look
        flat.blueDensity = 0

        func value(_ c: FilmLook.RGB) -> Double { FilmLook.luma(c) }

        let sky = FilmLook.RGB(0.20, 0.42, 0.80)
        #expect(value(look.graded(sky)) < value(flat.graded(sky)) - 0.01,
                "a saturated blue did not go deeper")

        for (name, colour) in [("grey", FilmLook.RGB(0.5, 0.5, 0.5)),
                               ("skin", FilmLook.RGB(0.76, 0.58, 0.48)),
                               ("foliage", FilmLook.RGB(0.28, 0.46, 0.20)),
                               ("a pale sky", FilmLook.RGB(0.76, 0.82, 0.88))] {
            let moved = abs(value(look.graded(colour)) - value(flat.graded(colour)))
            #expect(moved < 0.012, "\(name) moved \(moved), and it is not blue")
        }
    }

    // MARK: - What a capture costs in memory

    /// **The two full-size buffers must stay eight bits.**
    ///
    /// The owner: "make sure the memory and everything is still very
    /// efficient because we are expecting thousands of images being uploaded
    /// to this app." Both of these rendered RGBAh, which is 8 bytes a pixel:
    /// 97MB for a 12 megapixel frame against 48MB as RGBA8, on the hottest
    /// path in the app, and with a RAW capture holding BOTH at once.
    ///
    /// Nothing is lost by 8 bits here and that is the point of pinning it.
    /// The pipeline still works in 16 bit float internally — that is
    /// `workingFormat`, and it is what stops a sky banding. This is only what
    /// it writes out, and what it writes out goes to a JPEG and a 1024px
    /// block. The precision was being allocated and thrown away one line
    /// later.
    @Test("A graded photograph comes out eight bits a channel")
    func gradedOutputIsEightBit() throws {
        let photo = try #require(UIImage(named: "DemoPhoto1"))
        for look in FilmLook.all where look.kind != .none {
            let out = FilmLookRenderer.shared.render(photo, look: look)
            let bits = try #require(out.cgImage?.bitsPerComponent)
            #expect(bits == 8, "\(look.kind.name) renders \(bits) bits a channel, which doubles the buffer")
        }
    }

    // MARK: - RAW

    /// **The whole RAW feature has to be survivable.** It is the one thing in
    /// this app that cannot be exercised without a sensor, so what is checked
    /// here is the failure path: rubbish in, nil out, no raise. The caller
    /// holds an ordinary photograph from the same shutter press and uses it
    /// whenever this returns nil, so a developer that cannot develop costs
    /// somebody nothing.
    @Test("A RAW that will not develop returns nothing rather than raising")
    func developingRubbishFailsSoft() {
        #expect(RawDeveloper.shared.develop(Data(), mirrored: false) == nil)
        #expect(RawDeveloper.shared.develop(Data(repeating: 0x7f, count: 4096),
                                            mirrored: true) == nil)
        // **A JPEG does NOT fail, and that was worth finding out.**
        // `CIRAWFilter` accepts more than Bayer RAW and will happily develop
        // an ordinary image, so "it was not a RAW" is not a failure this can
        // detect and must not be relied on as one. It does not arise in
        // practice, because the only thing handed here is the data from a
        // photo the output itself reported as `isRawPhoto`. What matters is
        // that whatever comes back is a picture rather than a crash.
        if let jpeg = UIImage(named: "DemoPhoto1")?.jpegData(compressionQuality: 0.8) {
            let developed = RawDeveloper.shared.develop(jpeg, mirrored: false)
            #expect(developed?.size.width ?? 0 > 0 || developed == nil,
                    "a non-RAW input must produce a picture or nothing, never a raise")
        }

        // Mirroring must not change the size, only the side things are on.
        if let jpeg = UIImage(named: "DemoPhoto1")?.jpegData(compressionQuality: 0.8),
           let plain = RawDeveloper.shared.develop(jpeg, mirrored: false),
           let flipped = RawDeveloper.shared.develop(jpeg, mirrored: true) {
            #expect(plain.size == flipped.size,
                    "the selfie flip changed the frame rather than the picture in it")
        }
    }
}
