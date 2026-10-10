import Foundation
import PencilKit
import SwiftUI
import Testing
import UIKit
@testable import Strata

/// **Marks follow their photos** (the owner, 2026-10-09: "where you draw or
/// paste is where it should go"). `StripDecorPlacement`.
@MainActor
@Suite("Strip doodles stay on their photos")
struct StripDecorPlacementTests {
    let a = UUID(), b = UUID(), c = UUID()

    func sticker(at p: CGPoint, size: Double = 40) -> InkSticker {
        InkSticker(name: "s", x: p.x, y: p.y, size: size)
    }

    func stroke(around p: CGPoint) -> PKStroke {
        let points = [CGPoint(x: p.x - 6, y: p.y - 4), CGPoint(x: p.x + 6, y: p.y + 4)].enumerated().map {
            PKStrokePoint(location: $0.element, timeOffset: Double($0.offset) * 0.05, size: CGSize(width: 3, height: 3),
                          opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        return PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: Date()))
    }

    func centre(_ r: CGRect) -> CGPoint { CGPoint(x: r.midX, y: r.midY) }

    @Test("a lone Quick that gains a partner keeps its sticker on it")
    func quickPairs() throws {
        let before = StripAnchors.of([(a, .small), (b, .medium)])
        let after = StripAnchors.of([(a, .small), (b, .medium), (c, .small)])
        let oldA = try #require(before.rect(a.uuidString)), newA = try #require(after.rect(a.uuidString))
        #expect(oldA.width > newA.width, "the full row became half a pair")
        let moved = StripDecorPlacement.move(PKDrawing(), stickers: [sticker(at: centre(oldA))], from: before, to: after)
        let s = try #require(moved.stickers.first)
        #expect(abs(s.x - newA.midX) < 0.5 && abs(s.y - newA.midY) < 0.5)
        #expect(s.size < 40, "smaller with its smaller photo")
        // And the Regular below it moved, with what was drawn on it.
        let oldB = try #require(before.rect(b.uuidString)), newB = try #require(after.rect(b.uuidString))
        let onB = StripDecorPlacement.move(PKDrawing(strokes: [stroke(around: centre(oldB))]), stickers: [],
                                           from: before, to: after)
        let bounds = onB.drawing.bounds
        #expect(abs(bounds.midY - newB.midY) < 1.5)
    }

    @Test("a photo taken off parks its marks, and they return with it")
    func parks() throws {
        let all = StripAnchors.of([(a, .medium), (b, .medium)])
        let without = StripAnchors.of([(b, .medium)])
        let onA = sticker(at: centre(try #require(all.rect(a.uuidString))))
        let onB = sticker(at: centre(try #require(all.rect(b.uuidString))))
        let off = StripDecorPlacement.move(PKDrawing(), stickers: [onA, onB], from: all, to: without)
        #expect(off.parkedStickers.map(\.id) == [onA.id])
        let newB = try #require(without.rect(b.uuidString))
        #expect(abs((off.stickers.first?.y ?? 0) - newB.midY) < 0.5, "B moved up into A's place, its sticker too")
        let back = StripDecorPlacement.move(PKDrawing(), stickers: off.parkedStickers, from: all, to: all)
        #expect(back.stickers.map(\.id) == [onA.id])
    }

    @Test("a mark on the foot moves with the foot; one on the paper above stays")
    func footAndPaper() {
        let before = StripAnchors.of([(a, .medium)])
        let after = StripAnchors.of([(a, .medium), (b, .hard)])
        let foot = sticker(at: CGPoint(x: 60, y: before.footTop + 20))
        let top = sticker(at: CGPoint(x: 60, y: 1))
        let moved = StripDecorPlacement.move(PKDrawing(), stickers: [foot, top], from: before, to: after)
        #expect(abs(moved.stickers[0].y - (after.footTop + 20)) < 0.5)
        #expect(moved.stickers[1].y == 1)
    }

    @Test("an unchanged strip is recognised, so its saved picture is used")
    func unchanged() {
        let one = StripAnchors.of([(a, .small), (b, .small)])
        #expect(one.matches(StripAnchors.of([(a, .small), (b, .small)])))
        #expect(!one.matches(StripAnchors.of([(b, .small), (a, .small), (c, .medium)])))
    }

    /// A ring drawn on the first photo before the third photo arrived, drawn
    /// before and after, for looking at (`STRATA_STRIP_SHOTS=<folder>`).
    @Test("the ring stays on its photo when a photo joins")
    func picture() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "decor-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let files = InkFiles(directory: folder)
        let colours: [UIColor] = [.systemTeal, .systemOrange, .systemPurple]
        let frames = [BlockSize.small, .medium, .small].enumerated().map { i, size in
            PhotoStrip.Frame(id: UUID(), title: "", size: size,
                             picture: UIGraphicsImageRenderer(size: CGSize(width: 60, height: 60)).image { ctx in
                                 colours[i].setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 60, height: 60))
                             })
        }
        let before = Array(frames.prefix(2))
        let layout = StripAnchors.of(before)
        let first = try #require(layout.rect(before[0].id.uuidString))
        let ring = (0...24).map { i -> PKStrokePoint in
            let t = Double(i) / 24 * 2 * .pi, r = min(first.width, first.height) * 0.3
            return PKStrokePoint(location: CGPoint(x: first.midX + r * cos(t), y: first.midY + r * sin(t)),
                                 timeOffset: Double(i) * 0.02, size: CGSize(width: 6, height: 6),
                                 opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        let stroke = PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: ring, creationDate: Date()))
        StripDecor.save(PKDrawing(strokes: [stroke]), stickers: [],
                        canvas: CGSize(width: StripDecor.canvasWidth, height: layout.footTop + 60),
                        anchors: layout, owner: .crew("t"), day: "2026-10-09", files: files)
        for (name, shown) in [("before", before), ("after", frames)] {
            let decor = StripDecor.picture(owner: .crew("t"), day: "2026-10-09", frames: shown, files: files)
            #expect(decor != nil)
            let renderer = ImageRenderer(content: StripView(frames: shown, day: "2026-10-09", signature: "Test",
                                                            paper: .white, width: 228, decor: decor).fixedSize())
            renderer.scale = 2
            if let out = ProcessInfo.processInfo.environment["STRATA_STRIP_SHOTS"], let png = renderer.uiImage?.pngData() {
                try png.write(to: URL(fileURLWithPath: out).appending(path: "decor-\(name).png"))
            }
        }
    }
}
