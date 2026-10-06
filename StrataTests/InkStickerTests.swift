import Testing
import Foundation
import PencilKit
import UIKit
@testable import Strata

/// **Stickers on drawings** (the owner, 2026-10-06: "make it so you can add
/// stickers to doodles when you are drawing them"), for all four: a crew
/// doodle, a block's doodle, the journal's sketch and the month drawing.
@MainActor
@Suite("Stickers on drawings", .serialized)
struct InkStickerTests {
    /// A store holding one solid red sticker, 60 by 40, and its name.
    private func redSticker() throws -> (store: StickerStore, name: String) {
        let store = StickerStore(directory: FileManager.default.temporaryDirectory
            .appending(path: "ink-stickers-\(UUID().uuidString)", directoryHint: .isDirectory))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let red = UIGraphicsImageRenderer(size: CGSize(width: 60, height: 40), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 60, height: 40))
        }
        return (store, try #require(store.add(red)))
    }

    /// Every pixel of `image`, premultiplied RGBA.
    private func pixels(_ image: UIImage) throws -> (bytes: [UInt8], width: Int, height: Int) {
        let cg = try #require(image.cgImage)
        var bytes = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        let context = try #require(CGContext(data: &bytes, width: cg.width, height: cg.height, bitsPerComponent: 8,
                                             bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        return (bytes, cg.width, cg.height)
    }

    private func count(_ image: UIImage, where test: (UInt8, UInt8, UInt8, UInt8) -> Bool) throws -> Int {
        let p = try pixels(image)
        var n = 0
        for i in stride(from: 0, to: p.bytes.count, by: 4) where test(p.bytes[i], p.bytes[i + 1], p.bytes[i + 2], p.bytes[i + 3]) {
            n += 1
        }
        return n
    }

    private let isRed: (UInt8, UInt8, UInt8, UInt8) -> Bool = { r, g, b, a in a > 200 && r > 200 && g < 60 && b < 60 }

    // MARK: - The placement

    @Test("a placement scales with its canvas, and its tilt and size stay inside their limits")
    func placement() {
        let sticker = InkSticker(name: "a.png", x: 100, y: 50, size: 80, rotation: 0.2)
        let doubled = sticker.scaled(by: 2)
        #expect(doubled.x == 200 && doubled.y == 100 && doubled.size == 160 && doubled.rotation == 0.2)
        let drawn = sticker.drawnSize(for: CGSize(width: 60, height: 40))
        #expect(drawn.width == 80 && abs(drawn.height - 80.0 * 40 / 60) < 0.001)
        var wild = sticker
        wild.rotation = 3
        wild.size = 5
        let kept = wild.clamped(toCanvas: CGSize(width: 300, height: 300))
        #expect(kept.rotation == InkSticker.rotationLimit, "a sticker leans a little, never spins")
        #expect(kept.size == InkSticker.minimumSize)
    }

    // MARK: - Undo

    @Test("undo takes off a sticker just put on, and a stroke and a sticker undo in the order made")
    func undoRemovesASticker() {
        let ink = InkController()
        ink.canvasSize = CGSize(width: 300, height: 400)
        #expect(ink.isEmpty)
        let placed = ink.place("a.png")
        #expect(ink.stickers == [placed])
        #expect(!ink.isEmpty, "a sticker alone is something to send")
        #expect(abs(placed.x - 150) < 0.01 && abs(placed.y - 200) < 0.01, "it lands in the middle of the page")
        #expect(abs(placed.size - 300 * InkController.stickerShare) < 0.01)
        #expect(ink.canUndo)
        ink.undo()
        #expect(ink.stickers.isEmpty)
        #expect(!ink.canUndo)

        // A stroke, then a sticker: the sticker goes first, then the stroke.
        let before = ink.drawing
        ink.record(before)
        ink.place("a.png")
        #expect(ink.undoDepth == 2)
        ink.undo()
        #expect(ink.stickers.isEmpty)
        #expect(ink.undoDepth == 1)
        ink.undo()
        #expect(!ink.canUndo)
    }

    @Test("a sticker moved is one step, dragged off it comes off, and undo puts it back")
    func moveAndPeelOff() throws {
        let ink = InkController()
        ink.canvasSize = CGSize(width: 300, height: 300)
        let placed = ink.place("a.png")
        let depth = ink.undoDepth
        ink.beginMoving(placed.id)
        for dx in stride(from: 0.0, through: 60, by: 10) {
            var next = placed
            next.x += dx
            ink.move(next)
        }
        ink.endMoving(placed.id)
        #expect(ink.undoDepth == depth + 1, "a whole drag is one step")
        let moved = try #require(ink.stickers.first)
        #expect(abs(moved.x - (placed.x + 60)) < 0.01)
        ink.undo()
        #expect(ink.stickers == [placed])

        // Let go past the edge: off it comes, and one undo brings it back.
        ink.beginMoving(placed.id)
        var off = placed
        off.x = -20
        ink.move(off)
        let peeled = try #require(ink.stickers.first)
        #expect(ink.isOffPage(peeled))
        ink.endMoving(placed.id)
        #expect(ink.stickers.isEmpty)
        ink.undo()
        #expect(ink.stickers == [placed])

        // Hold, Remove: one step too.
        ink.remove(placed.id)
        #expect(ink.stickers.isEmpty)
        ink.undo()
        #expect(ink.stickers == [placed])
    }

    @Test("a drawing opened to edit brings its stickers, and undo cannot reach past them")
    func loadKeepsStickers() {
        let ink = InkController()
        let sticker = InkSticker(name: "a.png", x: 10, y: 10, size: 50)
        ink.load(InkTests.drawing(strokes: [40]), stickers: [sticker])
        #expect(ink.stickers == [sticker])
        #expect(!ink.canUndo)
    }

    // MARK: - The picture

    @Test("the picture carries the sticker in colour under the ink, and the ink alone to tint")
    func compositeKeepsColour() throws {
        let (store, name) = try redSticker()
        let rect = CGRect(x: 0, y: 0, width: 200, height: 200)
        let sticker = InkSticker(name: name, x: 100, y: 100, size: 120)
        let data = try #require(InkExport.png(of: InkTests.drawing(strokes: [180], width: 12), stickers: [sticker],
                                              in: rect, scale: 2, images: store.image))
        #expect(InkLayers.chunk(in: data) != nil, "the masks did not ride in the picture")

        // The picture as any reader sees it (and as the photo check reads
        // it): the whole drawing, the sticker in its colour.
        let plain = try #require(UIImage(data: data))
        #expect(try count(plain, where: isRed) > 1000, "the sticker is not in the picture")

        let layers = try #require(InkLayers.decode(data, scale: 2))
        let stickers = try #require(layers.stickers)
        #expect(try count(stickers, where: isRed) > 1000, "the sticker layer lost its colour")
        // The ink layer is ink only: nothing where the sticker shows alone.
        let ink = try pixels(layers.ink)
        let corner = ((ink.height / 2 + 60) * ink.width + ink.width / 2) * 4
        #expect(ink.bytes[corner + 3] == 0, "the sticker would be tinted as ink")
        #expect(try count(layers.ink, where: { _, _, _, a in a > 200 }) > 500, "the ink is missing")
        // Where only ink is (the line at y 20, above the sticker): ink in
        // the ink layer, nothing in the stickers'.
        let line = (40 * ink.width + 200) * 4
        #expect(ink.bytes[line + 3] > 200, "the line is not in the ink layer")
        #expect(try pixels(stickers).bytes[line + 3] == 0, "ink leaked into the stickers' layer")
    }

    @Test("a drawing without stickers, or with one whose file is gone, is the plain picture it always was")
    func noStickerNoChunk() throws {
        let drawing = InkTests.drawing(strokes: [80])
        let rect = CGRect(x: 0, y: 0, width: 120, height: 120)
        let plain = try #require(InkExport.png(of: drawing, stickers: [], in: rect, scale: 2))
        #expect(InkLayers.chunk(in: plain) == nil)
        let missing = InkSticker(name: "not-on-this-phone.png", x: 50, y: 50, size: 40)
        let skipped = try #require(InkExport.png(of: drawing, stickers: [missing], in: rect, scale: 2,
                                                 images: { _ in nil }))
        #expect(InkLayers.chunk(in: skipped) == nil, "a missing sticker should be skipped without a word")
        let decoded = try #require(InkLayers.decode(skipped, scale: 2))
        #expect(decoded.stickers == nil)
    }

    @Test("a crew doodle is cropped to its ink and its stickers, in colour")
    func crewDoodle() throws {
        let (store, name) = try redSticker()
        // A sticker well below and right of a short line.
        let doodle = InkDoodle(drawing: InkTests.drawing(strokes: [40]),
                               stickers: [InkSticker(name: name, x: 300, y: 300, size: 90)],
                               canvas: CGSize(width: 400, height: 400))
        let data = try #require(InkExport.doodlePNG(doodle, images: store.image))
        let image = try #require(UIImage(data: data))
        #expect(image.size.height * image.scale > 3 * 280, "the crop left the sticker out")
        #expect(try count(image, where: isRed) > 1000)
        // Only a sticker is still a doodle to send.
        let alone = InkDoodle(drawing: PKDrawing(), stickers: doodle.stickers)
        #expect(InkExport.doodlePNG(alone, images: store.image) != nil)
        #expect(InkExport.doodlePNG(InkDoodle(drawing: PKDrawing()), images: store.image) == nil)
    }

    // MARK: - Kept, for each place a drawing lives

    @Test("a block's doodle keeps its stickers, and one kept before stickers still reads")
    func blockRoundTrip() throws {
        let (store, name) = try redSticker()
        let files = InkTests.folder()
        let canvas = CGSize(width: 300, height: 300)
        let sticker = InkSticker(name: name, x: 150, y: 150, size: 100, rotation: 0.1)
        let saved = try #require(BlockDoodles.save(InkTests.drawing(strokes: [200], width: 20), stickers: [sticker],
                                                   canvas: canvas, replacing: nil, files: files, images: store.image))
        let kept = try #require(BlockDoodles.drawing(for: saved, files: files))
        #expect(kept.stickers == [sticker])
        #expect(kept.drawing.strokes.count == 1)

        // The block draws it in colour, and so does the crew's picture.
        let picture = try #require(BlockDoodles.picture(saved, files: files))
        let blockStickers = try #require(picture.stickers)
        #expect(try count(blockStickers, where: isRed) > 1000)
        let crewData = try #require(BlockDoodles.crewPicture(saved, colour: .health, files: files))
        let crew = try #require(UIImage(data: crewData))
        #expect(try count(crew, where: isRed) > 1000, "the crew's picture lost the sticker")

        // A doodle written before stickers: no stickers key at all.
        let old = "doodle-old.png"
        let json = try JSONSerialization.data(withJSONObject: [
            "strokes": InkTests.drawing(strokes: [30]).dataRepresentation().base64EncodedString(),
            "width": 300, "height": 300,
        ])
        try files.write(json, named: BlockDoodles.drawingName(for: old))
        let read = try #require(BlockDoodles.drawing(for: old, files: files))
        #expect(read.stickers.isEmpty)
        #expect(read.drawing.strokes.count == 1)

        // A sticker alone is a doodle.
        #expect(BlockDoodles.save(PKDrawing(), stickers: [sticker], canvas: canvas, replacing: nil,
                                  files: files, images: store.image) != nil)
    }

    @Test("a journal sketch keeps its stickers beside its strokes, and an old sketch still reads")
    func journalRoundTrip() throws {
        let (store, name) = try redSticker()
        let files = InkTests.folder()
        let sticker = InkSticker(name: name, x: 120, y: 300, size: 80)
        let saved = try #require(JournalSketches.save(InkTests.drawing(strokes: [100]), stickers: [sticker],
                                                      width: 300, day: "2026-10-06", replacing: nil,
                                                      files: files, images: store.image))
        #expect(JournalSketches.stickers(for: saved, files: files) == [sticker])
        #expect(JournalSketches.drawing(for: saved, files: files)?.strokes.count == 1)
        // The picture reaches down to the sticker, which sits under the ink.
        let picture = try #require(InkImageCache.picture(at: files.url(saved), scale: JournalSketches.scale))
        #expect(picture.ink.size.height > 300, "the sketch was cropped above its sticker")
        let sketchStickers = try #require(picture.stickers)
        #expect(try count(sketchStickers, where: isRed) > 1000)

        // A sketch saved before stickers: its strokes file is a bare drawing.
        let plain = try #require(JournalSketches.save(InkTests.drawing(strokes: [50]), width: 300,
                                                      day: "2026-10-05", replacing: nil, files: files))
        // It is a bare drawing, as every sketch before stickers was.
        let raw = try #require(files.read(JournalSketches.drawingName(for: plain)))
        #expect((try? PKDrawing(data: raw)) != nil, "a sketch without stickers is written as it always was")
        #expect(JournalSketches.stickers(for: plain, files: files).isEmpty)
    }

    @Test("a month drawing keeps its stickers, and a record from before them still decodes")
    func monthRoundTrip() throws {
        let (stickerStore, name) = try redSticker()
        let store = MonthDrawingStore(files: InkTests.folder())
        let sticker = InkSticker(name: name, x: 150, y: 200, size: 90, rotation: -0.1)
        store.save(InkTests.drawing(strokes: [60]), stickers: [sticker], canvas: CGSize(width: 300, height: 450),
                   bringsToLife: true, for: "2026-10", images: stickerStore.image)
        let saved = try #require(store.drawing(for: "2026-10"))
        #expect(saved.stickers == [sticker])
        #expect(MonthDrawingStore(files: store.files).drawing(for: "2026-10")?.stickers == [sticker])
        let picture = try #require(InkImageCache.picture(at: store.files.url(saved.picture), scale: 3))
        let monthStickers = try #require(picture.stickers)
        #expect(try count(monthStickers, where: isRed) > 1000)

        // A record written before stickers and lines.
        let old = """
        {"strokes":"\(PKDrawing().dataRepresentation().base64EncodedString())",
         "canvasWidth":300,"canvasHeight":450,"bringsToLife":true,"picture":"month-2026-09-1.png"}
        """
        let decoded = try JSONDecoder().decode(MonthDrawing.self, from: Data(old.utf8))
        #expect(decoded.stickers == nil)
        #expect(decoded.bringsToLife)
    }

    @Test("the replay pops the stickers in once the lines are drawn, and holds still after")
    func replayPops() {
        let timing = InkReplayTiming(lengths: [100, 100], stickers: 2)
        #expect(timing.pop(of: 0, at: timing.drawDuration - 0.01) == 0, "a sticker came before the lines")
        #expect(timing.pop(of: 0, at: timing.drawDuration + InkReplayTiming.stickerPop) == 1)
        #expect(timing.pop(of: 1, at: timing.drawDuration + InkReplayTiming.stickerPop) < 1,
                "the second lands a beat after the first")
        #expect(timing.pop(of: 1, at: timing.playDuration) == 1)
        #expect(timing.playDuration > timing.drawDuration)
        #expect(InkReplayTiming.popScale(1) == 1 && InkReplayTiming.popScale(0) < 1)
        // A drawing with none plays exactly as long as its lines.
        #expect(InkReplayTiming(lengths: [100]).playDuration == InkReplayTiming(lengths: [100]).drawDuration)
    }

    // MARK: - Wiring

    @Test("every ink canvas has the sticker button, and every editor hands its stickers back")
    func wiring() throws {
        let canvas = SourceSweep.code(try SourceSweep.read("Strata/Views/Ink/InkCanvas.swift"))
        let controls = try #require(canvas.components(separatedBy: "struct InkControls").dropFirst().first)
        #expect(controls.contains("GlassIconButton(systemName: \"face.smiling\""), "the sticker button is gone")
        #expect(controls.contains("StickerPicker(current: nil, purpose: .drawing"))
        #expect(canvas.contains("InkStickerLayer(controller: controller, interactive: false)"))
        #expect(canvas.contains("InkStickerLayer(controller: controller, interactive: true)"))

        // The four editors all draw on `InkCanvas`, so all four have the
        // button; each hands its stickers back or saves them.
        for path in ["Strata/Views/Crews/DoodleSheet.swift", "Strata/Views/Ink/BlockDoodleSheet.swift",
                     "Strata/Views/Ink/JournalSketchEditor.swift", "Strata/Views/Ink/MonthDrawingEditor.swift"] {
            let editor = SourceSweep.code(try SourceSweep.read(path))
            #expect(editor.contains("InkCanvas(controller: ink"), "\(path) no longer draws on the one canvas")
            #expect(editor.contains("stickers: ink.stickers"), "\(path) drops its stickers")
        }

        // Shown in colour, under the tinted ink: never through the template.
        let block = SourceSweep.code(try SourceSweep.read("Strata/Views/Ink/BlockDoodleSheet.swift"))
        #expect(block.contains("if let stickers = picture.stickers"))
        let image = try #require(canvas.components(separatedBy: "struct InkImage").dropFirst().first)
        #expect(image.contains("if let stickers = picture.stickers"))

        // The picker for a drawing leaves Emoji out; the journal's keeps it.
        let picker = SourceSweep.code(try SourceSweep.read("Strata/Views/StickerPicker.swift"))
        #expect(picker.contains("if let onEmoji {"))

        // Chrome casts no shadow, and a sticker is no exception.
        let layer = SourceSweep.code(try SourceSweep.read("Strata/Views/Ink/InkStickerLayer.swift"))
        #expect(!layer.contains(".shadow("))
    }
}
