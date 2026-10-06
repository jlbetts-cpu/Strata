import Foundation
import PencilKit
import SwiftData

/// **The day's sketch, as files.** A journal entry names its sketch by the
/// PNG's file name (`MoodLog.sketchFileName`); beside it, under the same stem,
/// is the `PKDrawing` it was made from, so a tap on the sketch opens the
/// strokes again rather than a picture of them.
///
/// **A new name every time it changes.** The picture is cached by path
/// (`InkImageCache`), so writing over the same name would leave the old one
/// on screen. The old pair is removed once the new one is safely written.
///
/// The PNG is the strip's full width and only as tall as its ink, so it sits
/// under the words exactly where it was drawn, left to right.
@MainActor
enum JournalSketches {
    /// Pixels a point: the phone's own, so the sketch is crisp at 1:1.
    static let scale: CGFloat = 3

    /// "sketch-2026-10-05-1A2B3C4D.png" for "…drawing" and back.
    static func drawingName(for png: String) -> String {
        (png as NSString).deletingPathExtension + ".drawing"
    }

    /// The part of the strip a sketch keeps: its full width, and from the top
    /// of its ink to the bottom.
    static func frame(of drawing: PKDrawing, width: CGFloat) -> CGRect {
        let ink = InkExport.inkBounds(of: drawing)
        let top = max(0, ink.minY)
        return CGRect(x: 0, y: top, width: max(width, 1), height: max(ink.maxY - top, 1))
    }

    /// Writes the sketch and returns its new name, removing `old`. Nil for an
    /// empty drawing, which removes `old` too: a sketch rubbed out is no
    /// sketch.
    static func save(_ drawing: PKDrawing, width: CGFloat, day: String, replacing old: String?,
                     files: InkFiles = .shared) -> String? {
        guard !drawing.strokes.isEmpty else {
            if let old { remove(old, files: files) }
            return nil
        }
        let stem = "sketch-\(day)-\(UUID().uuidString.prefix(8))"
        let png = stem + ".png"
        guard let picture = InkExport.png(of: drawing, in: frame(of: drawing, width: width), scale: scale)
        else { return old }
        do {
            try files.write(drawing.dataRepresentation(), named: drawingName(for: png))
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
        files.read(drawingName(for: png)).flatMap { try? PKDrawing(data: $0) }
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
