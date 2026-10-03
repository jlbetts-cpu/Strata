import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import Vision

/// **What the camera does for a face: a little, and only to the face.**
///
/// The owner, 2026-10-03: "the camera really needs to do that like snapchat
/// effect where it makes you look slightly better like your skin is a bit
/// clearer but its not noticable enough that you can be like omg filter... I
/// want the people on the camera to feel good about themselves".
///
/// So, per face Vision finds, inside a soft oval that fades out before the
/// hairline and the jaw:
///
/// - **Clearer skin.** A third of a gentle blur, scaled to the face, laid
///   over the photograph. Pores and small blemishes soften; eyes, lashes and
///   the edge of the face keep their detail, because a third of a small blur
///   is not enough to take a line away, only to quiet a texture.
/// - **A little light.** A sixth of a stop, the way a good window lights a
///   face, and no colour shift.
///
/// Nothing outside the faces is touched, and nothing is reshaped: no slimming,
/// no eye enlarging, nothing that changes who the person is. A photograph with
/// no face in it comes back exactly as it went in.
enum PortraitPolish {
    /// How much of the softened face is laid over the real one.
    static let skinShare: CGFloat = 0.34
    /// The blur's radius, as a share of the face's width.
    static let blurShare: CGFloat = 0.0055
    /// The light added to a face, in stops.
    static let lift: CGFloat = 0.17

    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    /// The photograph with every face in it polished, or the photograph
    /// itself when there is no face, or anything fails.
    static func apply(to image: UIImage) -> UIImage {
        guard let source = upright(image) else { return image }
        let faces = faceRects(in: source)
        guard !faces.isEmpty else { return image }

        let extent = source.extent
        var mask = CIImage(color: .black).cropped(to: extent)
        var widest: CGFloat = 0
        for face in faces {
            widest = max(widest, face.width)
            // An oval a little taller than the box Vision draws (which stops
            // at the brows), centred a touch high, fading over its outer half.
            let center = CIVector(x: face.midX, y: face.midY + face.height * 0.06)
            let radius = max(face.width, face.height) * 0.62
            let gradient = CIFilter.radialGradient()
            gradient.center = CGPoint(x: center.x, y: center.y)
            gradient.radius0 = Float(radius * 0.55)
            gradient.radius1 = Float(radius)
            gradient.color0 = CIColor.white
            gradient.color1 = CIColor.black
            guard let oval = gradient.outputImage?.cropped(to: extent) else { continue }
            // Vision's box is about square; a face is taller than it is wide.
            let stretched = oval
                .transformed(by: CGAffineTransform(translationX: -center.x, y: -center.y)
                    .concatenating(CGAffineTransform(scaleX: 0.86, y: 1.12))
                    .concatenating(CGAffineTransform(translationX: center.x, y: center.y)))
                .cropped(to: extent)
            mask = stretched.applyingFilter("CIMaximumCompositing", parameters: [kCIInputBackgroundImageKey: mask])
        }

        // Clearer skin: a small blur, a third of it.
        let soft = source.clampedToExtent()
            .applyingGaussianBlur(sigma: Double(max(widest * blurShare, 1)))
            .cropped(to: extent)
        let skinMask = mask.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: skinShare, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: skinShare, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: skinShare, w: 0),
        ])
        let smoothed = soft.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: source,
            kCIInputMaskImageKey: skinMask,
        ])

        // A little light, on the face only.
        let lit = smoothed.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: lift])
        let result = lit.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: smoothed,
            kCIInputMaskImageKey: mask,
        ])

        guard let cg = context.createCGImage(result, from: extent,
                                             format: .RGBA8,
                                             colorSpace: source.colorSpace ?? CGColorSpace(name: CGColorSpace.displayP3)!)
        else { return image }
        return UIImage(cgImage: cg, scale: image.scale, orientation: .up)
    }

    /// The photograph the way it is seen: its orientation applied, so the
    /// faces Vision finds and the pixels drawn agree.
    private static func upright(_ image: UIImage) -> CIImage? {
        guard let ci = CIImage(image: image) else { return nil }
        return ci.oriented(CGImagePropertyOrientation(image.imageOrientation))
            .transformed(by: .identity)
            .settingOrigin()
    }

    /// Faces, in the image's own pixel coordinates (origin bottom left, as
    /// Core Image has it). Found on a small copy: a face is a face at 1024px.
    private static func faceRects(in image: CIImage) -> [CGRect] {
        let extent = image.extent
        let scale = min(1, 1024 / max(extent.width, extent.height))
        let small = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(ciImage: small, options: [:])
        do { try handler.perform([request]) } catch { return [] }
        return (request.results ?? []).filter { $0.confidence > 0.6 }.map { face in
            let box = face.boundingBox
            return CGRect(x: extent.minX + box.minX * extent.width, y: extent.minY + box.minY * extent.height,
                          width: box.width * extent.width, height: box.height * extent.height)
        }
    }

    /// The photograph cut to the viewfinder's shape, centred, as the
    /// viewfinder showed it. The preview FILLS its frame from a wider sensor,
    /// so the full frame the camera saves had more round the edges than
    /// anyone framed, and the review seemed to zoom out (the owner,
    /// 2026-10-03: "the viewfinder should be accurate").
    static func cropped(_ image: UIImage, toAspect aspect: CGFloat) -> UIImage {
        let size = image.size
        guard aspect > 0, size.width > 0, size.height > 0 else { return image }
        let current = size.width / size.height
        guard abs(current - aspect) > 0.005 else { return image }
        let target = current > aspect
            ? CGSize(width: size.height * aspect, height: size.height)
            : CGSize(width: size.width, height: size.width / aspect)
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.preferredRange = .automatic
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(at: CGPoint(x: (target.width - size.width) / 2, y: (target.height - size.height) / 2))
        }
    }
}

private extension CIImage {
    /// Moves the image so its extent starts at zero, which the gradients and
    /// the final render assume.
    func settingOrigin() -> CIImage {
        transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
