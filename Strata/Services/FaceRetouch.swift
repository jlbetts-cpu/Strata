import CoreImage
import CoreImage.CIFilterBuiltins
import Vision
#if targetEnvironment(simulator)
import CoreML
#endif

/// **The camera's touch on a face: what a good light and a kind lens would
/// do, and nothing a person could point at.**
///
/// The owner, 2026-10-03: "the camera people want to use if they want to
/// check themselves out or take a selfie... effortless attraction no need for
/// filters just clean... make sure not to overdo it it must be optimized",
/// and "it has to be live... without anyone noticing".
///
/// Every step is one a portrait photographer would do with light or a lens,
/// never with a brush, and each is a fraction of what would be visible on
/// its own:
///
/// 1. **Clearer skin.** A small blur, scaled to the face, a third of it laid
///    over the skin. Texture quietens; edges (eyes, lashes, brows, lips, the
///    face's outline) survive, because a third of a small blur is not enough
///    to remove a line.
/// 2. **Even tone.** A touch less saturation in the skin's reds, the
///    blotchiness a face picks up in the cold or after a run.
/// 3. **Soft light.** A sixth of a stop on the face, as a window would give.
/// 4. **Rested eyes.** A tenth of a stop under each eye, where shadow sits.
/// 5. **Clear eyes.** The eyes themselves a little crisper.
///
/// **Nothing is reshaped**: no slimming, no enlarging, nothing that changes
/// who someone is. One function, used live on the viewfinder and on the
/// photograph, so what you see is what you keep.
enum FaceRetouch {
    /// One face, in the image's own coordinates (Core Image's: origin bottom
    /// left). The eyes are where Vision put them, or nil.
    struct Face: Equatable {
        var box: CGRect
        var leftEye: CGPoint?
        var rightEye: CGPoint?

        /// Moves part of the way to `other`, so a face found five times a
        /// second glides rather than jumps.
        func easing(to other: Face, by t: CGFloat) -> Face {
            func mix(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * t }
            func mix(_ a: CGPoint?, _ b: CGPoint?) -> CGPoint? {
                guard let a, let b else { return b ?? a }
                return CGPoint(x: mix(a.x, b.x), y: mix(a.y, b.y))
            }
            return Face(box: CGRect(x: mix(box.minX, other.box.minX), y: mix(box.minY, other.box.minY),
                                    width: mix(box.width, other.box.width), height: mix(box.height, other.box.height)),
                        leftEye: mix(leftEye, other.leftEye), rightEye: mix(rightEye, other.rightEye))
        }

        func applying(_ t: CGAffineTransform) -> Face {
            Face(box: box.applying(t), leftEye: leftEye?.applying(t), rightEye: rightEye?.applying(t))
        }
    }

    // The amounts. Each is below what reads as an effect on its own.
    static let skinShare: CGFloat = 0.34
    static let blurShare: CGFloat = 0.0055
    static let faceLift: CGFloat = 0.12
    static let underEyeLift: CGFloat = 0.10
    static let skinSaturation: CGFloat = 0.95
    static let eyeSharpness: CGFloat = 0.35

    /// The image with every face touched, or the image itself when there are
    /// none. Lazy, as Core Image is: nothing is computed until it is drawn,
    /// and only at the size it is drawn at.
    static func render(_ image: CIImage, faces: [Face]) -> CIImage {
        guard !faces.isEmpty else { return image }
        let extent = image.extent
        var faceMask = CIImage.empty()
        var eyeMask = CIImage.empty()
        var underMask = CIImage.empty()
        var widest: CGFloat = 0
        for face in faces where face.box.width > 8 {
            widest = max(widest, face.box.width)
            // Vision's box stops at the brows and is about square; a face is
            // an oval a little taller, centred a touch high.
            let center = CGPoint(x: face.box.midX, y: face.box.midY + face.box.height * 0.06)
            faceMask = maximum(faceMask, oval(center: center,
                                              rx: face.box.width * 0.53, ry: face.box.height * 0.69,
                                              falloff: 0.45))
            let eyeR = face.box.width * 0.09
            for eye in [face.leftEye, face.rightEye].compactMap({ $0 }) {
                eyeMask = maximum(eyeMask, oval(center: eye, rx: eyeR * 1.3, ry: eyeR * 0.8, falloff: 0.6))
                let under = CGPoint(x: eye.x, y: eye.y - eyeR * 1.15)
                underMask = maximum(underMask, oval(center: under, rx: eyeR * 1.2, ry: eyeR * 0.55, falloff: 0.7))
            }
        }
        guard widest > 0 else { return image }
        faceMask = faceMask.cropped(to: extent)

        // 1, 2. Clearer, more even skin: a third of a small blur, a touch
        // less red, inside the face.
        let soft = image.clampedToExtent()
            .applyingGaussianBlur(sigma: Double(max(widest * blurShare, 0.8)))
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: skinSaturation])
            .cropped(to: extent)
        var result = soft.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: image,
            kCIInputMaskImageKey: scaled(faceMask, by: skinShare),
        ])

        // 3. Soft light on the face.
        result = result.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: faceLift])
            .applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: result,
                kCIInputMaskImageKey: faceMask,
            ])

        // 4. Rested eyes: light where the shadow under them sits.
        if !underMask.extent.isEmpty {
            result = result.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: underEyeLift])
                .applyingFilter("CIBlendWithMask", parameters: [
                    kCIInputBackgroundImageKey: result,
                    kCIInputMaskImageKey: underMask.cropped(to: extent),
                ])
        }

        // 5. Clear eyes.
        if !eyeMask.extent.isEmpty {
            result = result.applyingFilter("CISharpenLuminance", parameters: [
                kCIInputSharpnessKey: eyeSharpness,
                kCIInputRadiusKey: max(widest * 0.004, 1),
            ])
            .applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: result,
                kCIInputMaskImageKey: eyeMask.cropped(to: extent),
            ])
        }
        return result.cropped(to: extent)
    }

    /// Faces and eyes, found on a small copy of `image` (a face is a face at
    /// 480px, and the work is a fraction), in `image`'s own coordinates.
    static func detect(in image: CIImage, longEdge: CGFloat = 480) -> [Face] {
        let extent = image.extent
        guard extent.width > 0, extent.height > 0 else { return [] }
        let scale = min(1, longEdge / max(extent.width, extent.height))
        let small = image.transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY)
            .concatenating(CGAffineTransform(scaleX: scale, y: scale)))
        let request = VNDetectFaceLandmarksRequest()
        #if targetEnvironment(simulator)
        // The simulator has no Neural Engine, and Vision then fails with
        // "Could not create inference context". The CPU will do, for tests.
        if let cpu = (try? request.supportedComputeStageDevices)?[.main]?
            .first(where: { if case .cpu = $0 { return true } else { return false } }) {
            request.setComputeDevice(cpu, for: .main)
        }
        #endif
        let handler = VNImageRequestHandler(ciImage: small, options: [:])
        do { try handler.perform([request]) } catch { return [] }
        return (request.results ?? []).filter { $0.confidence > 0.5 }.map { face in
            let box = face.boundingBox
            let rect = CGRect(x: extent.minX + box.minX * extent.width, y: extent.minY + box.minY * extent.height,
                              width: box.width * extent.width, height: box.height * extent.height)
            func eye(_ region: VNFaceLandmarkRegion2D?) -> CGPoint? {
                guard let points = region?.normalizedPoints, !points.isEmpty else { return nil }
                let x = points.map(\.x).reduce(0, +) / CGFloat(points.count)
                let y = points.map(\.y).reduce(0, +) / CGFloat(points.count)
                return CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
            }
            return Face(box: rect, leftEye: eye(face.landmarks?.leftEye), rightEye: eye(face.landmarks?.rightEye))
        }
    }

    // MARK: - Masks

    /// A soft white oval on black: white inside, fading to black over the
    /// outer `falloff` of its radius.
    private static func oval(center: CGPoint, rx: CGFloat, ry: CGFloat, falloff: CGFloat) -> CIImage {
        let r = max(rx, ry, 1)
        let gradient = CIFilter.radialGradient()
        gradient.center = .zero
        gradient.radius0 = Float(r * (1 - falloff))
        gradient.radius1 = Float(r)
        gradient.color0 = CIColor.white
        gradient.color1 = CIColor.black
        let bounds = CGRect(x: -r, y: -r, width: r * 2, height: r * 2)
        return (gradient.outputImage ?? .empty()).cropped(to: bounds)
            .transformed(by: CGAffineTransform(scaleX: rx / r, y: ry / r)
                .concatenating(CGAffineTransform(translationX: center.x, y: center.y)))
    }

    private static func maximum(_ a: CIImage, _ b: CIImage) -> CIImage {
        if a.extent.isEmpty { return b }
        return b.applyingFilter("CIMaximumCompositing", parameters: [kCIInputBackgroundImageKey: a])
    }

    /// A mask's white turned down to `share`.
    private static func scaled(_ mask: CIImage, by share: CGFloat) -> CIImage {
        mask.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: share, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: share, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: share, w: 0),
        ])
    }
}
