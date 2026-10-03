import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// **The photograph's half of `FaceRetouch`**: the same touch the live
/// viewfinder shows, applied to the shot itself at full size, so what you saw
/// is what you keep. And the crop that keeps the shot the shape you framed.
enum PortraitPolish {
    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    /// The photograph with every face in it touched, or the photograph itself
    /// when there is no face, or anything fails.
    static func apply(to image: UIImage) -> UIImage {
        guard let source = upright(image) else { return image }
        let faces = FaceRetouch.detect(in: source, longEdge: 1024)
        guard !faces.isEmpty else { return image }
        let result = FaceRetouch.render(source, faces: faces)
        guard let cg = context.createCGImage(result, from: source.extent, format: .RGBA8,
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
        // Standard range, always: the camera's frame on a recent iPhone is
        // extended range, and redrawn as such it came out a kind of image the
        // rest of the app (thumbnails, recaps) was never shown reading.
        format.preferredRange = .standard
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
