import UIKit

/// **How far a block is zoomed into its photo** (the owner, 2026-10-13: "you
/// should be able to move the crop like zoom in that goes for all the
/// cropping like that shouldve been a feature").
///
/// A block is a window on its photo. `crop` already said where the window
/// sits (a fraction of the photo away from its middle); this is the second
/// number, how much of the photo the window takes. One is the photo filled
/// into the frame, which is every picture nobody pinched. The photo on disk
/// stays whole, so zooming back out is always possible.
nonisolated enum PhotoWindow {
    /// **Three, and not more.** A photo is kept at 2560 on its long side
    /// (`ImageManager.storedMaxDimension`), so at three a full-width block
    /// shows about 640 of its pixels across 1,100 of the screen's: soft, and
    /// still a photograph. Past that it is a blur with a name on it.
    static let maxZoom: CGFloat = 3

    static func zoom(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 1 }
        return min(max(value, 1), maxZoom)
    }

    // MARK: Where it is kept

    /// The zoom as `HabitLog.pendingXP` holds it: nothing at one, otherwise
    /// thousandths, **negative**.
    ///
    /// That field is dead (the XP system left in `b189dae`) and was kept for
    /// the schema, so the zoom rides in it and iCloud needs no new column
    /// deployed. Negative because the builds that did write XP wrote counts,
    /// which are never below zero: a log that still carries one from 2025
    /// cannot be read as a zoom.
    static func stored(_ zoom: CGFloat) -> Int? {
        let held = self.zoom(zoom)
        return held > 1.001 ? -Int((held * 1000).rounded()) : nil
    }

    static func zoom(stored: Int?) -> CGFloat {
        guard let stored, stored < -1000 else { return 1 }
        return zoom(CGFloat(-stored) / 1000)
    }

    // MARK: What a crew is sent

    /// **A zoomed photo, as a crew gets it**: the part of the photo to send
    /// (in fractions of it), and where the block's window sits on that part.
    /// Nil when nothing was zoomed, which sends exactly what was sent before.
    ///
    /// A crew's copy of a win has a crop and no zoom, and a new field there
    /// is a CloudKit deploy and a build every friend must have. So the photo
    /// is cut instead (his pick, "The cut picture"): to a piece the photo's
    /// own shape, one over the zoom on a side, centred on the window and held
    /// inside the photo. Filled into the same block with what is left of the
    /// crop, it shows the very window that was framed, on any build.
    static func cut(crop: CGPoint, zoom: CGFloat) -> (rect: CGRect, crop: CGPoint)? {
        let z = self.zoom(zoom)
        guard z > 1.001 else { return nil }
        let side = 1 / z
        func place(_ offset: CGFloat) -> (start: CGFloat, left: CGFloat) {
            let centre = min(max(0.5 + offset, 0), 1)
            let middle = min(max(centre, side / 2), 1 - side / 2)
            return (middle - side / 2, (centre - middle) * z)
        }
        let x = place(crop.x), y = place(crop.y)
        return (CGRect(x: x.start, y: y.start, width: side, height: side), CGPoint(x: x.left, y: y.left))
    }

    /// The cut as part of a photo's key, so moving or zooming sends it again.
    static func key(_ rect: CGRect) -> String {
        String(format: "%.3f,%.3f,%.3f", rect.minX, rect.minY, rect.width)
    }

    /// `data` cut to `rect` (fractions of the picture). Nil if it cannot be
    /// read, and the caller sends the photo whole.
    static func jpeg(_ data: Data, cutTo rect: CGRect) -> Data? {
        guard let image = UIImage(data: data), var whole = image.cgImage else { return nil }
        if image.imageOrientation != .up {
            // Stored photos are upright already (`ImageManager.resizeIfNeeded`);
            // anything else is drawn upright first, so the cut is the one seen.
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let size = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
            let upright = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
            guard let drawn = upright.cgImage else { return nil }
            whole = drawn
        }
        let w = CGFloat(whole.width), h = CGFloat(whole.height)
        let pixels = CGRect(x: (rect.minX * w).rounded(), y: (rect.minY * h).rounded(),
                            width: (rect.width * w).rounded(), height: (rect.height * h).rounded())
            .intersection(CGRect(x: 0, y: 0, width: w, height: h))
        guard pixels.width >= 1, pixels.height >= 1, let part = whole.cropping(to: pixels) else { return nil }
        return UIImage(cgImage: part).jpegData(compressionQuality: 0.92)
    }
}
