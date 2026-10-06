import Foundation
import PencilKit
import SwiftData
import UIKit

/// **The day's sketch, as files.** A journal entry names its sketch by the
/// PNG's file name (`MoodLog.sketchFileName`); beside it, under the same stem,
/// is the `PKDrawing` it was made from, so a tap on the sketch opens the
/// strokes again rather than a picture of them.
///
/// **A new name every time it changes.** The picture is cached by path
/// (`InkImageCache`), so writing over the same name would leave the old one
/// on screen. The old pair is removed once the new one is safely written.
///
/// The PNG is the canvas's full width and only as tall as its ink, so it sits
/// under the words exactly where it was drawn, left to right.
///
/// **Drawn big, shown small** (2026-10-05). The sketch is drawn in a full
/// screen editor (`JournalSketchEditor`, the owner: "a little bigger canvas
/// for the journal like it is in the month") and shown under the note with
/// the whole canvas fitted to `shownHeight`, the month drawing's model. The
/// picture is WRITTEN at that shown scale, so its natural size in points is
/// its size on the page and the line lands at `InkPen.width` there. A sketch
/// from the old inline strip was written at 1:1 and still shows at 1:1.
///
/// **Stickers on the sketch** (the owner, 2026-10-06: "make it so you can add
/// stickers to doodles when you are drawing them") are drawn into the picture
/// in their own colours, under the ink (`InkLayers`), and kept with the
/// strokes: a sketch with stickers keeps its `.drawing` as `Kept`, strokes and
/// stickers together; one without is the bare `PKDrawing` it always was, so
/// every sketch saved before reads as it did.
@MainActor
enum JournalSketches {
    /// The strokes and their stickers, for a sketch that has stickers.
    private struct Kept: Codable {
        var strokes: Data
        var stickers: [InkSticker]
    }

    /// Pixels a point: the phone's own, so the sketch is crisp at 1:1.
    static let scale: CGFloat = 3

    /// The height a whole canvas is shown at under the note: room for a
    /// drawing to read, with the note still the page's subject. A sketch only
    /// as tall as its ink takes less.
    static let shownHeight: CGFloat = 240

    /// Shown points per canvas point: **one**, so what you draw is what you
    /// get. Drawing big and showing it shrunk meant a pen thick enough to
    /// land at 1.5pt was 3.5pt under the finger (the owner, 2026-10-05: "the
    /// lines are a lot thicker on the drawing canvas than they are in my
    /// drawings"). The sketch is written at the editor's scale, trimmed to its
    /// ink, and shown under the note at that size: the same line throughout.
    static func shownScale(canvasHeight: CGFloat) -> CGFloat { 1 }

    /// "sketch-2026-10-05-1A2B3C4D.png" for "…drawing" and back.
    static func drawingName(for png: String) -> String {
        (png as NSString).deletingPathExtension + ".drawing"
    }

    /// The part of the canvas a sketch keeps: its full width, and from the top
    /// of its ink (or a sticker) to the bottom.
    static func frame(of drawing: PKDrawing, width: CGFloat, stickers: [InkSticker] = [],
                      images: (String) -> UIImage? = InkStickers.image) -> CGRect {
        var ink = drawing.strokes.isEmpty ? CGRect.null : InkExport.inkBounds(of: drawing)
        ink = ink.union(InkStickers.bounds(of: stickers, images: images))
        guard !ink.isNull else { return CGRect(x: 0, y: 0, width: max(width, 1), height: 1) }
        let top = max(0, ink.minY)
        return CGRect(x: 0, y: top, width: max(width, 1), height: max(ink.maxY - top, 1))
    }

    /// Writes the sketch and returns its new name, removing `old`. Nil for an
    /// empty drawing, which removes `old` too: a sketch rubbed out is no
    /// sketch.
    static func save(_ drawing: PKDrawing, stickers: [InkSticker] = [], width: CGFloat, day: String,
                     replacing old: String?, shownScale: CGFloat = 1, files: InkFiles = .shared,
                     images: (String) -> UIImage? = InkStickers.image) -> String? {
        guard !drawing.strokes.isEmpty || !stickers.isEmpty else {
            if let old { remove(old, files: files) }
            return nil
        }
        let stem = "sketch-\(day)-\(UUID().uuidString.prefix(8))"
        let png = stem + ".png"
        let strokes = stickers.isEmpty ? drawing.dataRepresentation()
            : try? JSONEncoder().encode(Kept(strokes: drawing.dataRepresentation(), stickers: stickers))
        guard let strokes,
              let picture = InkExport.png(of: drawing, stickers: stickers,
                                          in: frame(of: drawing, width: width, stickers: stickers, images: images),
                                          scale: scale * shownScale, images: images)
        else { return old }
        do {
            try files.write(strokes, named: drawingName(for: png))
            try files.write(picture, named: png)
        } catch {
            NSLog("[journal] the sketch did not save: \(error)")
            files.remove(drawingName(for: png))
            return old
        }
        if let old { remove(old, files: files) }
        return png
    }

    /// The strokes behind a saved sketch, to edit.
    static func drawing(for png: String, files: InkFiles = .shared) -> PKDrawing? {
        guard let data = files.read(drawingName(for: png)) else { return nil }
        if let kept = try? JSONDecoder().decode(Kept.self, from: data) { return try? PKDrawing(data: kept.strokes) }
        return try? PKDrawing(data: data)
    }

    /// The stickers on a saved sketch, to edit: none for one saved without.
    static func stickers(for png: String, files: InkFiles = .shared) -> [InkSticker] {
        files.read(drawingName(for: png)).flatMap { try? JSONDecoder().decode(Kept.self, from: $0) }?.stickers ?? []
    }

    static func remove(_ png: String, files: InkFiles = .shared) {
        files.remove(png)
        files.remove(drawingName(for: png))
    }

    /// The files a backup carries for these entries: each sketch and its
    /// strokes, where they are on disk.
    static func files(for entries: [MoodLog], in files: InkFiles = .shared) -> [URL] {
        entries.compactMap(\.sketchFileName).flatMap { png in
            [png, drawingName(for: png)].filter(files.exists).map(files.url)
        }
    }
}

extension DayNotes {
    /// Names the day's sketch, or clears it, and saves. A sketch alone is
    /// something to keep, so a day with no row gets one.
    static func setSketch(_ fileName: String?, for dateString: String, context: ModelContext) {
        let name = fileName.flatMap { $0.isEmpty ? nil : $0 }
        let row: MoodLog
        if let existing = entry(for: dateString, context: context) {
            row = existing
        } else {
            guard name != nil else { return }
            row = entryOrNew(for: dateString, context: context)
        }
        guard row.sketchFileName != name else { return }
        row.sketchFileName = name
        do { try context.save() } catch { NSLog("[journal] the day's sketch did not save: \(error)") }
    }
}
