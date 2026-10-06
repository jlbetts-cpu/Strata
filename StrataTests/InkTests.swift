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
        #expect(InkPen.width == 2.5)
        let controller = InkController()
        #expect(controller.pen.width == InkPen.width)
        #expect(controller.isEmpty)
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
