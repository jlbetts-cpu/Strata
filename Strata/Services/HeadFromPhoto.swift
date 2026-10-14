import ImageIO
import UIKit
import Vision

/// **A head from one photo you choose** (the owner, 2026-10-14: "make the
/// head making a must"; the plan's §5 call 2, taken: a second way that needs
/// no camera, so a person whose camera is off or whose face the maker cannot
/// line up is never stuck). The picker needs no permission
/// (`PhotosPicker` runs out of process).
///
/// **The capture's own pipeline, fed a still.** A camera frame becomes a
/// `Take` in `captureOutput`; a photo becomes one here, measured the same way
/// (the face's box, both eyes' outlines, the jawline and the chin), and then
/// goes through the same lift, crop and cut as the camera's open frame. The
/// result is a head with one face: it does not blink or smile, which the rig
/// already supports and the preview already says (`previewCaption`).
///
/// Off the main actor, like everything else in the engine. **Cannot run in
/// the simulator**: subject lifting is not there. Untested on a phone.
nonisolated extension HeadCaptureEngine {

    /// The longest side a chosen photo is read at: a camera frame's 1920, so
    /// the cut is made from the same number of pixels as a capture's.
    static let photoLongEdge: CGFloat = 1920

    /// One chosen photo, upright and at most `photoLongEdge`, measured as a
    /// frame is. Nil when no face is in it, or not both eyes.
    static func take(fromPhoto data: Data) -> Take? {
        guard let image = upright(data, longEdge: photoLongEdge) else { return nil }
        let size = CGSize(width: image.width, height: image.height)
        let landmarks = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
        guard (try? handler.perform([landmarks])) != nil,
              // The biggest face is the person in the photo, as on camera.
              let face = (landmarks.results ?? []).max(by: { $0.boundingBox.height < $1.boundingBox.height }),
              face.landmarks?.leftEye != nil, face.landmarks?.rightEye != nil else { return nil }
        let box = CGRect(x: face.boundingBox.minX, y: 1 - face.boundingBox.maxY,
                         width: face.boundingBox.width, height: face.boundingBox.height)
        let contour = face.landmarks?.faceContour?.pointsInImage(imageSize: size)
            .map { CGPoint(x: $0.x, y: size.height - $0.y) } ?? []
        let eyes = eyeOutlines(face, size: size)
        let chin: CGPoint? = {
            guard eyes.count == 2,
                  let a = HeadFraming.centre(of: eyes[0]),
                  let b = HeadFraming.centre(of: eyes[1]) else { return nil }
            return HeadFraming.chin(contour: contour, eyes: (a, b))
        }()
        let take = Take(image: image, face: box, score: 1, eyes: eyes,
                        smileWidth: nil, browRaise: nil, mouthOpen: nil,
                        chin: chin, wink: nil, contour: contour)
        return take.eyeCentres == nil ? nil : take
    }

    /// The head, from one take: the camera's open-frame path in `make()`,
    /// with nothing after it to line up. Nil when the lift or the cut fails.
    static func payload(fromPhoto take: Take) -> HeadStore.Payload? {
        guard let eyes = take.eyeCentres, let lifted = lift(take) else { return nil }
        let size = CGSize(width: take.image.width, height: take.image.height)
        let crop = HeadFraming.crop(face: take.face, in: size, contentHeight: HeadStore.contentHeight,
                                    chin: HeadStore.chin, eyes: eyes, chinPoint: take.chin,
                                    crownReach: crownReach(of: lifted, take: take))
        guard let neutral = cutOut(take, lifted: lifted, crop: crop, side: HeadStore.side,
                                   chin: HeadStore.chin, paintsEyes: true) else { return nil }
        return HeadStore.Payload(faces: [.neutral: HeadStore.Face(png: neutral.png, eyes: neutral.eyes)],
                                 shut: nil).derived()
    }

    /// Decoded upright (a phone photo is usually stored sideways with an
    /// orientation flag) and no larger than `longEdge`, in one pass.
    static func upright(_ data: Data, longEdge: CGFloat) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: longEdge,
        ]
        guard let decoded = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        // **Redrawn as 8-bit sRGB**, the shape a camera frame arrives in: a
        // HEIC from the library can be 10-bit or wide gamut, and the cut and
        // the eye painting read pixels as four bytes.
        let width = decoded.width, height = decoded.height
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(decoded, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
