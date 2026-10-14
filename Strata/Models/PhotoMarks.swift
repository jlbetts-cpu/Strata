import PencilKit
import UIKit

/// **What is drawn and stuck on a photograph on the camera's review** (the
/// owner, 2026-10-13: "the editing for the photo confirm screen like you
/// should be able to doodle ... add stickers add the head").
///
/// His pick is that they are baked in: "they become part of the picture when
/// you press Use Photo, exactly as your head does today". So nothing here is
/// stored. The marks live in the review's own state as an `InkDoodle` (the
/// strokes, the stickers, and the canvas they were made on, which has the
/// photograph's shape), are shown over the photograph while it is being
/// judged, and are drawn into it once, at its own resolution.
///
/// The ink is the block doodle's own: white, as his pen is on a block
/// (`AppColors.drawingInkOnBlock`). One pen, one colour, as everywhere.
enum PhotoMarks {
    /// The ink's colour on a photograph, as `UIColor` for drawing.
    static let ink = UIColor(red: 1, green: 0.98, blue: 0.94, alpha: 1)

    /// The photograph with the marks drawn into it, at its own resolution.
    /// The photograph itself if there is nothing to draw.
    static func composite(_ photo: UIImage, marks: InkDoodle,
                          images: (String) -> UIImage? = InkStickers.image) -> UIImage {
        guard !marks.isEmpty, marks.canvas.width > 0, marks.canvas.height > 0 else { return photo }
        let size = photo.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = photo.scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            photo.draw(in: CGRect(origin: .zero, size: size))
            draw(marks, into: context.cgContext, size: size, pixels: photo.scale, images: images)
        }
    }

    /// The marks alone, clear round them, the photograph's shape: what the
    /// review lays over the photograph. Nil for nothing drawn.
    static func layer(_ marks: InkDoodle, width: CGFloat = 1200,
                      images: (String) -> UIImage? = InkStickers.image) -> UIImage? {
        guard !marks.isEmpty, marks.canvas.width > 0, marks.canvas.height > 0 else { return nil }
        let size = CGSize(width: width, height: width * marks.canvas.height / marks.canvas.width)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            draw(marks, into: context.cgContext, size: size, pixels: 1, images: images)
        }
    }

    /// Stickers as they are, then the ink over them, both scaled from the
    /// canvas they were made on to `size`.
    private static func draw(_ marks: InkDoodle, into context: CGContext, size: CGSize, pixels: CGFloat,
                             images: (String) -> UIImage?) {
        let k = size.width / marks.canvas.width
        context.saveGState()
        context.scaleBy(x: k, y: k)
        InkStickers.draw(marks.stickers, origin: .zero, images: images)
        context.restoreGState()
        guard !marks.drawing.strokes.isEmpty else { return }
        let whole = CGRect(origin: .zero, size: marks.canvas)
        // Black from the pen, as every export's is, tinted to the ink here.
        let pen = InkExport.image(of: marks.drawing, in: whole, scale: max(1, k * pixels))
        pen.withTintColor(ink, renderingMode: .alwaysOriginal).draw(in: CGRect(origin: .zero, size: size))
    }
}
