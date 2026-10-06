import PencilKit
import SwiftUI
import UIKit

/// **The doodles on blocks** (`HabitLog.doodleFileName`): each one two files
/// in `InkFiles`, beside the journal's sketches. The picture, "doodle-<id>.png",
/// black ink on nothing at the canvas's shape, which a block tints white
/// (`BlockDoodleImage`); and its strokes, "doodle-<id>.drawing", with the
/// canvas they were drawn on, so Edit opens them to draw on again.
///
/// A block holds a photograph OR a doodle, never both (the owner's pick,
/// 2026-10-06, "Photo or doodle").
///
/// **Stickers on a doodle** (the owner, 2026-10-06: "make it so you can add
/// stickers to doodles when you are drawing them") are kept in the strokes'
/// file beside them, and drawn into the picture in their own colours under
/// the ink (`InkLayers`), so the block tints only the ink white.
@MainActor
enum BlockDoodles {
    /// Pixels a point: crisp on a Deep block, small on disk.
    static let scale: CGFloat = 3

    private struct Strokes: Codable {
        var strokes: Data
        var width: Double
        var height: Double
        /// Optional, so a doodle kept before there were stickers still reads.
        var stickers: [InkSticker]? = nil
    }

    static func drawingName(for png: String) -> String {
        (png as NSString).deletingPathExtension + ".drawing"
    }

    /// Writes the doodle and returns its name, removing `old`. Nil for an
    /// empty drawing, which removes `old` too: rubbed out is no doodle. A
    /// sticker alone is a doodle.
    static func save(_ drawing: PKDrawing, stickers: [InkSticker] = [], canvas: CGSize,
                     replacing old: String?, files: InkFiles = .shared,
                     images: (String) -> UIImage? = InkStickers.image) -> String? {
        guard !drawing.strokes.isEmpty || !stickers.isEmpty, canvas.width > 0, canvas.height > 0,
              let png = InkExport.png(of: drawing, stickers: stickers,
                                      in: CGRect(origin: .zero, size: canvas), scale: scale, images: images),
              let strokes = try? JSONEncoder().encode(
                Strokes(strokes: drawing.dataRepresentation(),
                        width: canvas.width, height: canvas.height,
                        stickers: stickers.isEmpty ? nil : stickers))
        else {
            if let old { remove(old, files: files) }
            return nil
        }
        let name = "doodle-\(UUID().uuidString.prefix(8)).png"
        do {
            try files.write(png, named: name)
            try files.write(strokes, named: drawingName(for: name))
        } catch {
            NSLog("[doodle] did not save: \(error)")
            files.remove(name)
            files.remove(drawingName(for: name))
            return old
        }
        if let old, old != name { remove(old, files: files) }
        return name
    }

    /// The strokes, their stickers and the canvas they were drawn on, to edit.
    static func drawing(for png: String, files: InkFiles = .shared)
        -> (drawing: PKDrawing, canvas: CGSize, stickers: [InkSticker])? {
        guard let data = files.read(drawingName(for: png)),
              let kept = try? JSONDecoder().decode(Strokes.self, from: data),
              let drawing = try? PKDrawing(data: kept.strokes) else { return nil }
        return (drawing, CGSize(width: kept.width, height: kept.height), kept.stickers ?? [])
    }

    static func remove(_ png: String, files: InkFiles = .shared) {
        files.remove(png)
        files.remove(drawingName(for: png))
        cache.removeObject(forKey: png as NSString)
    }

    /// The picture, decoded once and kept: a tower draws many blocks. Its
    /// ink to tint white, and its stickers as they are (`InkLayers`).
    static func picture(_ png: String, files: InkFiles = .shared) -> InkPicture? {
        if let hit = cache.object(forKey: png as NSString) { return hit }
        guard let data = files.read(png), let picture = InkLayers.decode(data, scale: 1) else { return nil }
        cache.setObject(picture, forKey: png as NSString)
        return picture
    }

    /// The picture's ink.
    static func image(_ png: String, files: InkFiles = .shared) -> UIImage? {
        picture(png, files: files)?.ink
    }

    private static let cache = NSCache<NSString, InkPicture>()

    /// **The doodled block as one picture, for a crew** (the owner,
    /// 2026-10-06: "make doodles show on crew tower and replays too"). A
    /// friend's phone draws a crew win from its photograph, so a doodle goes
    /// as one: the block's colour with the white ink on it, at the shape it
    /// was drawn. No new field on the crew's record, so no CloudKit schema
    /// change, and every friend's phone shows it as it stands.
    static func crewPicture(_ png: String, colour: HabitCategory, files: InkFiles = .shared) -> Data? {
        guard let ink = image(png, files: files) else { return nil }
        // The picture was written at `scale` pixels a point.
        let size = CGSize(width: ink.size.width * ink.scale / scale, height: ink.size.height * ink.scale / scale)
        guard size.width > 0, size.height > 0 else { return nil }
        let block = ZStack {
            Rectangle().fill(EtherealFill.fill(colour.style.baseColor))
            BlockDoodleImage(fileName: png, files: files)
        }
        .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: block)
        renderer.scale = 2
        return renderer.uiImage?.jpegData(compressionQuality: 0.9)
    }
}
