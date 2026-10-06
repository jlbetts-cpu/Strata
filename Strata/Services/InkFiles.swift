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
/// weight of the owner's own drawings at the size they show. There is no
/// colour and no width to choose (spec section 4, "Do not: a colour
/// picker"), so there is no `PKToolPicker` either.
nonisolated enum InkPen {
    /// The line as it is SEEN, in points where the drawing is shown.
    ///
    /// **1.5, and it was 2.5** (2026-10-05, the owner: a thinner pen
    /// everywhere). His own drawings, measured on screen: the October
    /// scarecrow's lines are about 1.3pt (4px at 3x) and the crews drawing's
    /// about 1.7pt, so 2.5 drew nearly twice his weight. 1.5 sits between the
    /// two. It needs a tool of 0.75, inside the calibration below (between
    /// its 0.71 and 1.46 measurements) and clear of the 0.5 floor.
    static let width: CGFloat = 1.5

    /// **The pen for a canvas drawn bigger than it is shown**, so the line
    /// lands at `width` where it is seen: the month editor (shown at 290) and
    /// the journal's sketch editor (shown at `JournalSketches.shownHeight`).
    static func width(onCanvasOfHeight canvas: CGFloat, shownAt shown: CGFloat) -> CGFloat {
        guard canvas > 0, shown > 0 else { return width }
        return width * canvas / shown
    }

    /// **The month drawing's line, on the page: the owner's own.** His
    /// October scarecrow measures 1.3pt where it is shown (4px at 3x). The
    /// month editor is larger than the art it makes, so its pen is wider by
    /// that ratio (about 2.3pt under the finger) and lands at his weight.
    static let monthLine: CGFloat = 1.3

    /// **A doodle's line on the tower's block.** White on a colour, at a
    /// block's size, needs a little more than the page's 1.5 to read. The
    /// doodle sheet draws the block much bigger than the tower shows it (a
    /// Quick block's canvas is about four times its tower height), so its
    /// pen is wider by that ratio and the line lands at this on the tower.
    static let blockLine: CGFloat = 1.8

    static func blockWidth(onCanvasOfHeight canvas: CGFloat, shownAt shown: CGFloat) -> CGFloat {
        guard canvas > 0, shown > 0 else { return blockLine }
        return blockLine * canvas / shown
    }

    static func monthWidth(onCanvasOfHeight canvas: CGFloat, shownAt shown: CGFloat) -> CGFloat {
        guard canvas > 0, shown > 0 else { return monthLine }
        return monthLine * canvas / shown
    }

    /// **The tool is not set to the line it draws, and that was measured.**
    /// Each point is recorded at the tool's width plus 2, and PencilKit draws
    /// a line TWICE the tool's width: twice the recorded size less 2.
    ///
    /// **Re-measured 2026-10-05, and the first fit was wrong.** It read
    /// `1.35 * (size - 1.6)` off three widths (tool 0.5, 2.5 and 4.8 drawing
    /// 1.3, 4.2 and 7pt), and set to a 1.5pt line it drew 1.87 where the
    /// sketch is shown. Measured again on the iOS 26.3 simulator with real
    /// touches (`-strataPenLine` on the sketch editor, the recorded size read
    /// back from the saved `.drawing`, the line's width read off a 3x
    /// screenshot weighted by coverage): tool 0.71, 1.46, 2.17 and 3.30
    /// recorded 2.71, 3.45, 4.17 and 5.30 and drew 1.43, 2.92, 4.35 and
    /// 6.61pt, which is 2.0 times the tool to within 0.03pt at every one, and
    /// did not change with the stroke's speed. Every pen the app sets (1.5 on
    /// a doodle, up to about 3.5 in the two editors) is inside that range.
    /// Unverified on a device: check `lineWidth` there before trusting it.
    static func toolWidth(forLine line: CGFloat) -> CGFloat { max(0.5, line / 2) }

    /// The line PencilKit draws for a point of this recorded size, so the
    /// replay (`InkReplay`) lands at the weight the picture does.
    static func lineWidth(forPointSize size: CGFloat) -> CGFloat { max(0.5, 2 * (size - 2)) }

    /// The size a point is recorded at for a line of this width: for drawings
    /// made in code (`InkSamples`), so they look like a finger's.
    static func pointSize(forLine line: CGFloat) -> CGFloat { line / 2 + 2 }

    static var tool: PKInkingTool {
        PKInkingTool(.monoline, color: .black, width: toolWidth(forLine: width))
    }

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
