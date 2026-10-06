import Testing
import Foundation
import PencilKit
import UIKit
@testable import Strata

/// **The one ink canvas** (`docs/superpowers/specs/2026-10-05-shared-wins-journal-doodles-design.md`,
/// sections 2 to 4): where ink files live, and a drawing turned into a
/// picture that stays black.
@MainActor
@Suite("Ink", .serialized)
struct InkTests {

    static func folder() -> InkFiles {
        InkFiles(directory: FileManager.default.temporaryDirectory
            .appending(path: "ink-\(UUID().uuidString)", directoryHint: .isDirectory))
    }

    /// A drawing of straight strokes, each `length` points long, laid one
    /// under another.
    static func drawing(strokes lengths: [CGFloat], width: CGFloat = InkPen.width) -> PKDrawing {
        let ink = PKInk(.monoline, color: .black)
        var strokes: [PKStroke] = []
        for (i, length) in lengths.enumerated() {
            let y = CGFloat(20 + i * 20)
            let steps = max(Int(length / 4), 1)
            let points = (0...steps).map { k in
                PKStrokePoint(location: CGPoint(x: 10 + length * CGFloat(k) / CGFloat(steps), y: y),
                              timeOffset: TimeInterval(k) * 0.01,
                              size: CGSize(width: width, height: width),
                              opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
            }
            strokes.append(PKStroke(ink: ink, path: PKStrokePath(controlPoints: points, creationDate: Date())))
        }
        return PKDrawing(strokes: strokes)
    }

    // MARK: - Files

    @Test("ink files live in their own folder, and a name cannot climb out of it")
    func filesStayInTheirFolder() throws {
        let files = Self.folder()
        try files.write(Data([1, 2, 3]), named: "a.png")
        #expect(files.exists("a.png"))
        #expect(files.read("a.png") == Data([1, 2, 3]))
        #expect(files.all().map(\.lastPathComponent) == ["a.png"])
        #expect(throws: (any Error).self) { try files.write(Data(), named: "../escape.png") }
        #expect(!InkFiles.isPlainName(".."))
        files.remove("a.png")
        #expect(!files.exists("a.png"))
    }

    @Test("the ink folder is a sibling of the photographs, never inside them")
    func besideThePhotographs() {
        // Inside, the launch sweep would delete every sketch (no win names
        // one) and the backup would count them as photographs.
        let ink = InkFiles.shared.directory.standardizedFileURL
        let photos = ImageManager.shared.imageDirectory.standardizedFileURL
        #expect(ink.deletingLastPathComponent() == photos.deletingLastPathComponent())
        #expect(ink != photos)
        #expect(!ink.path.hasPrefix(photos.path + "/"))
    }

    // MARK: - The picture

    @Test("the pen is one black monoline at the house width")
    func thePen() {
        #expect(InkPen.tool.inkType == .monoline)
        // **1.5, and it was 2.5** (2026-10-05). The owner's own drawings,
        // measured on screen: the October scarecrow's lines about 1.3pt (4px
        // at 3x) and the crews drawing about 1.7pt. 2.5 drew a line nearly
        // twice his; 1.5 sits between the two.
        #expect(InkPen.width == 1.5)
        let controller = InkController()
        #expect(controller.penWidth == InkPen.width)
        // The tool is set to DRAW 1.5, not to 1.5 (`InkPen.toolWidth`).
        #expect(controller.pen.width == InkPen.toolWidth(forLine: InkPen.width))
        #expect(controller.isEmpty)
    }

    /// **1.5 is inside the calibration, not past its end.** The tool-to-line
    /// fit was measured (re-measured on 2026-10-05, see `InkPen.toolWidth`)
    /// at tool widths 0.71, 1.46, 2.17 and 3.30. A 1.5pt line needs a tool of
    /// 0.75: between the first two measurements, so interpolated, and clear
    /// of the 0.5 floor that would clamp it.
    @Test("the house width is interpolated inside the measured tool widths")
    func penIsInsideTheCalibration() {
        let tool = InkPen.toolWidth(forLine: InkPen.width)
        #expect(tool > 0.5, "the tool is at its floor: the line is clamped, not set")
        #expect(tool >= 0.71 && tool <= 1.46, "the tool is outside the two measurements it is interpolated between")
        #expect(abs(InkPen.lineWidth(forPointSize: tool + 2) - InkPen.width) < 0.01)
        // The injection: a width under the calibration's floor clamps.
        #expect(InkPen.toolWidth(forLine: 0.5) == 0.5)
    }

    /// **A bigger canvas draws a wider pen, so the line LANDS at the house
    /// width where it is shown.** The month editor and the journal's sketch
    /// editor both draw on a canvas taller than the page shows the drawing,
    /// so the pen is widened by the same ratio.
    // The month lands at the owner's own line (1.3pt, measured off his
    // scarecrow); the journal is drawn at the size it is shown, so its pen is
    // the house width under the finger and on the page alike (the owner,
    // 2026-10-05: "the lines are a lot thicker on the drawing canvas").
    @Test("the month pen lands at the owner's line, and the journal draws what it shows")
    func penScalesToWhereItIsShown() {
        // The month: a 555pt canvas shown at 290.
        let month = InkPen.monthWidth(onCanvasOfHeight: 555, shownAt: MonthDrawingEditor.shownHeight)
        #expect(abs(month * MonthDrawingEditor.shownHeight / 555 - InkPen.monthLine) < 0.001)
        // The journal: shown at the size it is drawn.
        #expect(JournalSketches.shownScale(canvasHeight: 555) == 1)
        // A canvas shown at its own size draws the house width itself.
        #expect(InkPen.width(onCanvasOfHeight: 290, shownAt: 290) == InkPen.width)
        // The editors' widest pens are still inside the measured tools (3.30
        // at most): a tall phone's 600pt canvas asks the month for a 3.1pt
        // line and the journal for 3.75, tools 1.55 and 1.88.
        #expect(InkPen.toolWidth(forLine: InkPen.width(onCanvasOfHeight: 600, shownAt: 290)) <= 3.30)
        #expect(InkPen.toolWidth(forLine: InkPen.width(onCanvasOfHeight: 600,
                                                       shownAt: JournalSketches.shownHeight)) <= 3.30)
    }

    /// The journal sketch is shown at the size it is drawn: what you draw is
    /// what the note shows.
    @Test("a journal sketch is shown at the size it is drawn")
    func sketchShownScale() {
        #expect(JournalSketches.shownScale(canvasHeight: 555) == 1)
        #expect(JournalSketches.shownScale(canvasHeight: 0) == 1, "an unmeasured canvas is shown as drawn")
    }

    @Test("a doodle is cropped to its ink and never longer than 1080 pixels")
    func doodleSize() throws {
        let big = Self.drawing(strokes: [900, 600])
        let data = try #require(InkExport.doodlePNG(big))
        let image = try #require(UIImage(data: data))
        let longest = max(image.size.width * image.scale, image.size.height * image.scale)
        #expect(longest <= 1080.5)
        #expect(longest >= 1070, "a big doodle is sent at the ceiling, not shrunk past it")
        #expect(InkExport.doodlePNG(PKDrawing()) == nil, "nothing drawn is nothing sent")
        // A small doodle is not blown up past three times.
        #expect(InkExport.scale(fitting: CGSize(width: 40, height: 20), longestEdge: 1080) == 3)
    }

    @Test("the picture's ink is black even when the phone is dark")
    func inkStaysBlack() throws {
        let drawing = Self.drawing(strokes: [60], width: 8)
        var image = UIImage()
        UITraitCollection(userInterfaceStyle: .dark).performAsCurrent {
            image = InkExport.image(of: drawing, in: drawing.bounds, scale: 1)
        }
        #expect(try Self.darkestInk(image) < 40, "the ink came out light, which is what dark mode does to an export")
        // The injection, so this can fail: PencilKit's own export under a
        // dark trait is the light ink the export exists to avoid.
        var raw = UIImage()
        UITraitCollection(userInterfaceStyle: .dark).performAsCurrent {
            raw = drawing.image(from: drawing.bounds, scale: 1)
        }
        #expect(try Self.darkestInk(raw) > 128)
    }

    static func darkestInk(_ image: UIImage) throws -> Int {
        let cg = try #require(image.cgImage)
        let w = cg.width, h = cg.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = try #require(CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8,
                                         bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var darkest = 255, inked = 0
        for i in stride(from: 0, to: pixels.count, by: 4) where pixels[i + 3] > 200 {
            inked += 1
            darkest = min(darkest, Int(pixels[i]))
        }
        #expect(inked > 0)
        return darkest
    }
}
