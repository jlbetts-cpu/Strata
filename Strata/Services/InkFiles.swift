import Foundation
import PencilKit
import UIKit

/// **Where ink lives: a folder beside the photographs, never inside them.**
///
/// The journal's sketch, a month drawing and its replay data are all files,
/// and the spec says they sit "beside the photographs". They do: this is
/// `Documents/strata-ink/`, the sibling of `ImageManager.imageDirectory`
/// (`Documents/strata-images/`), made the same way, on first use, so the
/// device backup iOS makes on its own carries them like the photographs.
///
/// **Not IN the photo folder, for three reasons each of which would lose a
/// drawing.** `ImageManager.pruneOrphans` deletes every plain file in that
/// folder that no win names, and a sketch is named by a journal entry, never
/// by a win, so the first launch sweep would take it. The derivative
/// migration bakes a 320 and a 640 copy of every original it finds there.
/// And `BackupExport.photographs` copies every original into the backup's
/// `photos/`, where the restore would report a sketch as a photograph no win
/// claims. A folder of its own is the one place none of those three reach.
///
/// Nothing here decides WHAT is drawn; `JournalSketches` and
/// `MonthDrawingStore` do, through this.
nonisolated struct InkFiles: Sendable {
    let directory: URL

    /// The phone's ink folder.
    static let shared: InkFiles = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return InkFiles(directory: docs.appendingPathComponent("strata-ink", isDirectory: true))
    }()

    init(directory: URL) {
        self.directory = directory
    }

    func url(_ name: String) -> URL { directory.appendingPathComponent(name) }

    func exists(_ name: String) -> Bool { FileManager.default.fileExists(atPath: url(name).path) }

    /// Writes atomically, making the folder on first use. A name is a
    /// basename only: anything that would climb out of the folder is refused.
    @discardableResult
    func write(_ data: Data, named name: String) throws -> URL {
        guard Self.isPlainName(name) else { throw CocoaError(.fileWriteInvalidFileName) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let target = url(name)
        try data.write(to: target, options: .atomic)
        return target
    }

    func read(_ name: String) -> Data? {
        guard Self.isPlainName(name) else { return nil }
        return try? Data(contentsOf: url(name))
    }

    func remove(_ name: String) {
        guard Self.isPlainName(name) else { return }
        try? FileManager.default.removeItem(at: url(name))
    }

    /// Every file in the folder, for the backup.
    func all() -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [])
            .filter { !$0.lastPathComponent.hasPrefix(".") }
    }

    static func isPlainName(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/")
    }
}

/// **The pen, in one place.** Every ink surface in the app draws with this
/// and nothing else: one black monoline at the house width, which is the
/// weight of the owner's month drawings (about 2.5pt at the size they show).
/// There is no colour and no width to choose (spec section 4, "Do not: a
/// colour picker"), so there is no `PKToolPicker` either.
enum InkPen {
    /// The line, in points at the canvas's own size.
    static let width: CGFloat = 2.5

    static var tool: PKInkingTool { PKInkingTool(.monoline, color: .black, width: width) }

    /// The eraser that undoes whole strokes, which is what a one-pen drawing
    /// wants: a stroke is the unit you drew, so it is the unit you remove.
    static var eraser: PKEraserTool { PKEraserTool(.vector) }
}

/// **A drawing as a picture, always in black.**
///
/// PencilKit draws black ink as white when the phone is dark, and
/// `PKDrawing.image` honours the CURRENT trait collection, so an export made
/// in dark mode came out white-on-clear and vanished on the light page. The
/// picture is made under a light trait, so the ink is always black, and is
/// then shown as a TEMPLATE image tinted with the page's ink, which follows
/// dark mode the way the owner's own drawings do (`Illustration.layer`).
enum InkExport {
    /// The longest edge a doodle is sent at (spec 3: "1080 px longest edge at
    /// most"), the same ceiling as a crew photograph (`ShareDerivative`).
    static let doodleLongestEdge: CGFloat = 1080

    /// The picture of `rect` of the drawing, at `scale` pixels a point.
    static func image(of drawing: PKDrawing, in rect: CGRect, scale: CGFloat) -> UIImage {
        var image = UIImage()
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            image = drawing.image(from: rect, scale: scale)
        }
        return image
    }

    static func png(of drawing: PKDrawing, in rect: CGRect, scale: CGFloat) -> Data? {
        image(of: drawing, in: rect, scale: scale).pngData()
    }

    /// The scale that fits `size` inside `longestEdge` pixels, never more
    /// than `ceiling` (a small doodle is not blown up).
    static func scale(fitting size: CGSize, longestEdge: CGFloat, ceiling: CGFloat = 3) -> CGFloat {
        let longest = max(size.width, size.height)
        guard longest > 0 else { return 1 }
        return min(ceiling, longestEdge / longest)
    }

    /// The drawing's own ink, with a pen's width of air round it, so the
    /// stroke's round caps are not shaved off at the edge.
    static func inkBounds(of drawing: PKDrawing) -> CGRect {
        drawing.bounds.insetBy(dx: -InkPen.width * 2, dy: -InkPen.width * 2)
    }

    /// A doodle for a crew: cropped to its ink, at most 1080px on its longest
    /// edge. Nil for an empty drawing.
    static func doodlePNG(_ drawing: PKDrawing) -> Data? {
        guard !drawing.strokes.isEmpty else { return nil }
        let rect = inkBounds(of: drawing)
        return png(of: drawing, in: rect, scale: scale(fitting: rect.size, longestEdge: doodleLongestEdge))
    }
}
