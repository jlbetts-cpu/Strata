import Foundation
import ImageIO
import UniformTypeIdentifiers

/// The copy of a photograph that goes to a crew.
///
/// 1080px on the long edge, which is more than a block or the photo viewer
/// ever draws on a phone, re-encoded so **nothing of the original file
/// survives**: no `{Exif}` (camera, lens, time to the second), no `{GPS}`
/// (where it was taken), no maker notes. Thumbnailing through ImageIO writes
/// a fresh image with only the orientation baked in, and the destination is
/// handed no properties at all. `CrewPayloadTests` reads one back and checks.
nonisolated enum ShareDerivative {
    static let longEdge: CGFloat = 1080

    static func jpeg(from data: Data, longEdge: CGFloat = longEdge, quality: CGFloat = 0.82) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return nil }
        let width = (props[kCGImagePropertyPixelWidth] as? CGFloat) ?? 0
        let height = (props[kCGImagePropertyPixelHeight] as? CGFloat) ?? 0
        // Never upscaled: a small photograph stays small rather than going soft.
        let edge = min(longEdge, max(width, height))
        guard edge > 0 else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: edge,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let out = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image,
                                   [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return out as Data
    }
}
