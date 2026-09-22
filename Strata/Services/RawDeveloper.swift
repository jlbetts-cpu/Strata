import CoreImage
import ImageIO
import UIKit
import os

/// **Develops a Bayer RAW into a picture, without Apple finishing it first.**
///
/// The owner's blueprint for a real film emulation opens with this: a
/// photograph the phone has already processed has multi-frame fusion,
/// aggressive sharpening and local tone mapping baked into it, and a film look
/// laid over that is a look laid over another look. The way past it is to ask
/// the sensor for its own data and do the developing here.
///
/// **What this turns off, and why each one.**
///
/// `localToneMapAmount` is the important one. It is Smart HDR's local
/// operator: it lifts shadows and pulls highlights down per REGION, which is
/// what makes an iPhone photograph look flat and evenly lit and unlike
/// anything a negative does. A film look's whole tonal argument is a single
/// global curve with a toe and a shoulder, and a local operator fights it
/// everywhere.
///
/// `sharpnessAmount` and `detailAmount` go to nearly nothing because the
/// clinical edge is the other half of what people mean by digital, and because
/// a sharpener finds grain and turns it into speckle.
///
/// `boostAmount` is left near its default deliberately, and that is a
/// judgement rather than an oversight. It is Apple's global tone curve, and
/// taking it to zero hands back a flat linear image that every one of the four
/// looks would have to be retuned against — four looks tuned by eye, on a
/// machine with no camera. The win from RAW is the fusion, the sharpening and
/// the local operator, and those are all off. The global curve can come off
/// later, with a phone in hand.
///
/// Noise reduction stays ON and stays moderate. A single RAW frame in a dim
/// room is a noisy frame and there is no second exposure to average with; the
/// colour noise reduction is higher than the luminance one because blotchy
/// colour is uglier than grain, and grain is what the look is adding anyway.
nonisolated final class RawDeveloper: @unchecked Sendable {
    static let shared = RawDeveloper()
    private static let log = Logger(subsystem: "JaydenBetts.Strata", category: "raw")

    private let context = CIContext(options: [
        .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3) as Any,
        .workingFormat: CIFormat.RGBAh,
        .cacheIntermediates: false
    ])
    private let outputSpace = CGColorSpace(name: CGColorSpace.displayP3)

    /// Nil whenever anything at all goes wrong, because the caller always has
    /// an ordinary photograph in hand as well and a lost shot is worse than an
    /// unfinished one.
    func develop(_ dng: Data, mirrored: Bool) -> UIImage? {
        guard let filter = CIRAWFilter(imageData: dng, identifierHint: nil) else {
            Self.log.error("raw: the data would not open as a RAW, keeping the processed photo")
            return nil
        }

        // Off: everything that makes a photograph look finished.
        filter.localToneMapAmount = 0
        filter.sharpnessAmount = 0
        filter.detailAmount = 0.1
        filter.extendedDynamicRangeAmount = 0
        // On, and moderate: a single frame has no second exposure to average.
        filter.luminanceNoiseReductionAmount = 0.35
        filter.colorNoiseReductionAmount = 0.8
        filter.isGamutMappingEnabled = true

        guard var image = filter.outputImage else {
            Self.log.error("raw: the develop produced nothing, keeping the processed photo")
            return nil
        }

        // **The selfie has to be flipped by hand here.** Mirroring is a
        // property of a capture CONNECTION and it is applied to the processed
        // photograph; RAW is sensor data and arrives as the lens saw it. So
        // every front-camera RAW would come back as the face other people see
        // rather than the one that was framed, which is the single most
        // common "why do I look wrong in this photo" complaint and is the
        // reason the processed path mirrors at all.
        if mirrored {
            image = image
                .transformed(by: CGAffineTransform(scaleX: -1, y: 1))
                .transformed(by: CGAffineTransform(translationX: image.extent.width, y: 0))
        }

        // **Eight bits, not sixteen, and the difference is 48 megabytes.**
        //
        // A 12 megapixel RGBAh image is 97MB of memory; the same image as
        // RGBA8 is 48MB. The owner is expecting thousands of photographs
        // through this app, and a capture already holds the DNG, the ordinary
        // photograph AND this one at the same moment.
        //
        // Nothing is lost by it. `CIRAWFilter` has already applied a tone
        // curve, so what comes out here is display referred, and the only
        // things downstream are a grade whose own working format is 16 bit
        // float and a JPEG, which is 8 bit by definition. Sixteen bits would
        // buy headroom that nothing between here and the disk can spend.
        guard let cg = context.createCGImage(image, from: image.extent,
                                             format: .RGBA8, colorSpace: outputSpace) else {
            Self.log.error("raw: the develop would not render, keeping the processed photo")
            return nil
        }
        Self.log.notice("""
            raw: developed \(Int(image.extent.width), privacy: .public)x\(Int(image.extent.height), privacy: .public), local tone map off, sharpening off
            """)
        return UIImage(cgImage: cg, scale: 1, orientation: .up)
    }
}
