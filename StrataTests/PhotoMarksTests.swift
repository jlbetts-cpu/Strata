import Foundation
import PencilKit
import SwiftUI
import Testing
import UIKit
@testable import Strata

/// The camera's review as an editor (the owner, 2026-10-13: "the editing for
/// the photo confirm screen like you should be able to doodle, the filters
/// should be a button in a row add stickers add the head ... you should be
/// able to move the crop like zoom in").
@MainActor
@Suite("The camera's review as an editor")
struct PhotoMarksTests {
    private func code(_ path: String) throws -> String { SourceSweep.code(try SourceSweep.read(path)) }

    /// A flat mid-grey photograph, so a mark on it can be found.
    private func photo(_ size: CGSize = CGSize(width: 600, height: 800)) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(white: 0.4, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// A straight pen line across a canvas, at `y` of its height.
    private func line(on canvas: CGSize, y: CGFloat) -> PKDrawing {
        let points = stride(from: 0.1, through: 0.9, by: 0.05).map { t in
            PKStrokePoint(location: CGPoint(x: canvas.width * t, y: canvas.height * y), timeOffset: t,
                          size: CGSize(width: 8, height: 8), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        return PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .black),
                                            path: PKStrokePath(controlPoints: points, creationDate: .now))])
    }

    private func grey(of image: UIImage, at point: CGPoint) throws -> CGFloat {
        let cg = try #require(image.cgImage)
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try #require(CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let part = try #require(cg.cropping(to: CGRect(x: point.x - 1, y: point.y - 1, width: 3, height: 3)))
        context.draw(part, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return (CGFloat(pixel[0]) + CGFloat(pixel[1]) + CGFloat(pixel[2])) / 3 / 255
    }

    // MARK: Baked in

    @Test("a line drawn on the review is drawn into the photograph, where it was drawn, in the block's white ink")
    func baked() throws {
        let picture = photo()
        // Drawn on a canvas a third of the photograph's size, as a phone's is.
        let canvas = CGSize(width: 200, height: 200 * 800 / 600)
        let marks = InkDoodle(drawing: line(on: canvas, y: 0.75), stickers: [], canvas: canvas)
        let made = PhotoMarks.composite(picture, marks: marks)
        #expect(made.size == picture.size && made.scale == picture.scale, "the photograph changed size")
        #expect(try grey(of: made, at: CGPoint(x: 300, y: 600)) > 0.85, "no ink where the line was drawn")
        #expect(abs(try grey(of: made, at: CGPoint(x: 300, y: 200)) - 0.4) < 0.05, "the photograph changed where nothing was drawn")
        #expect(abs(try grey(of: made, at: CGPoint(x: 20, y: 600)) - 0.4) < 0.05, "the line ran past where it was drawn")
    }

    @Test("nothing drawn changes nothing, and has no layer to show")
    func empty() {
        let picture = photo()
        let none = InkDoodle(drawing: PKDrawing(), stickers: [], canvas: CGSize(width: 200, height: 266))
        #expect(PhotoMarks.composite(picture, marks: none) === picture)
        #expect(PhotoMarks.layer(none) == nil)
        // A canvas never laid out is nothing to draw from.
        let unlaid = InkDoodle(drawing: line(on: CGSize(width: 10, height: 10), y: 0.5), stickers: [], canvas: .zero)
        #expect(PhotoMarks.composite(picture, marks: unlaid) === picture)
    }

    @Test("the layer shown on the review is the photograph's shape, clear where nothing is drawn")
    func layer() throws {
        let canvas = CGSize(width: 300, height: 400)
        let marks = InkDoodle(drawing: line(on: canvas, y: 0.5), stickers: [], canvas: canvas)
        let layer = try #require(PhotoMarks.layer(marks, width: 600))
        #expect(layer.size == CGSize(width: 600, height: 800))
        let cg = try #require(layer.cgImage)
        #expect(cg.alphaInfo != .none && cg.alphaInfo != .noneSkipLast && cg.alphaInfo != .noneSkipFirst,
                "the layer is opaque: it would hide the photograph")
    }

    // MARK: The review

    @Test("the box holds still: the photograph is moved on the screen's own measure, and held inside the box")
    func photoMovesUnderTheBox() throws {
        let overlay = try code("Strata/Views/HeadSticker.swift")
        #expect(overlay.contains("DragGesture(minimumDistance: 6, coordinateSpace: .global)"),
                "measured in the photograph's own space, a drag that moves the photograph chases itself")
        #expect(overlay.contains("crop = CachedImageView.held(moved, photo: photo, frame: box, zoom: zoom)"))
        let camera = try code("Strata/Views/CameraView.swift")
        #expect(camera.contains("CropBox(box: box, radius: CropBox.radius(for: box), ground: .black, ink: AppColors.drawingInkOnBlock)"))
        #expect(!camera.contains("BlockCropOutline(crop:"), "the hairline window is back on the review")
        // At rest the photograph is the size it always was: the box is the block's part of it.
        #expect(camera.contains("let box = CGSize(width: fitted.width * window.width, height: fitted.height * window.height)"))
    }

    @Test("a pinch that begins on the head sizes the head; anywhere else it zooms the photograph")
    func pinchRouting() throws {
        let overlay = try code("Strata/Views/HeadSticker.swift")
        #expect(overlay.contains("if pinching?.from != from { pinching = (from, isOnHead(from, in: size)) }"))
        #expect(overlay.contains("zoom = PhotoWindow.zoom(zoom * pinch.magnification / max(before, 0.01))"))
        #expect(overlay.contains("guard pinching?.head == true else {"))
    }

    @Test("the looks are one tool of four, and a plain Use Photo is still one press")
    func tools() throws {
        let camera = try code("Strata/Views/CameraView.swift")
        for word in ["reviewTool(\"Looks\")", "reviewTool(\"Doodle\")", "reviewTool(\"Sticker\")", "reviewTool(\"Head\")"] {
            #expect(camera.contains(word), "\(word) is not on the review")
        }
        #expect(camera.contains(".opacity(choosingLook ? 0 : 1)") && camera.contains(".opacity(choosingLook ? 1 : 0)"),
                "the tools and the looks do not share one slot, so the photograph is resized when the looks open")
        #expect(camera.contains("keep(image)"))
    }

    @Test("Use Photo draws the marks in over the look, hands on the zoom, and Retake lets all of it go")
    func kept() throws {
        let camera = try code("Strata/Views/CameraView.swift")
        #expect(camera.contains("let finished = drawnOn.map { PhotoMarks.composite(graded, marks: $0) } ?? graded"))
        #expect(camera.contains("onCaptured(finished, size, place, window, held)"))
        #expect(camera.contains("Task { await PhotoLibrarySaver.save(finished) }"), "the camera roll gets a photograph without the marks")
        let clear = try #require(camera.range(of: "private func clearReview() {"))
        let body = camera[clear.upperBound...].prefix(400)
        for gone in ["sticker = nil", "crop = .zero", "zoom = 1", "marks = nil", "markLayer = nil", "choosingLook = false"] {
            #expect(body.contains(gone), "Retake keeps \(gone)")
        }
        // The zoom reaches the win: the sheet opens holding it.
        #expect(try code("Strata/Views/AddWinSheet.swift").contains("zoom = pinched"))
        #expect(try code("Strata/Views/MainAppView.swift").contains("initialZoom: draft.zoom"))
        #expect(try code("Strata/Views/PlannedBlocks.swift").contains("onCaptured(shot.item, shot.photo, shot.size, shot.place, shot.crop, shot.zoom)"))
    }
}
