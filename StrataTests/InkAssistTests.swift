import Testing
import Foundation
import PencilKit
import UIKit
@testable import Strata

/// **The pen's quiet help** (`InkAssist`, approved by the owner 2026-10-06):
/// a held stroke that is nearly a line or nearly an ellipse snaps to it, a
/// scribble is left alone, and every other stroke is smoothed by less than a
/// point and a half. The strokes here are made the way a finger makes them:
/// wobble on a line, a loop that misses its own start, a zigzag.
@MainActor
@Suite("Ink assist")
struct InkAssistTests {

    /// A deterministic wobble, so a failure reproduces.
    static func wobble(_ i: Int, amplitude: CGFloat) -> CGFloat {
        amplitude * (sin(CGFloat(i) * 1.7) * 0.6 + sin(CGFloat(i) * 0.53 + 1) * 0.4)
    }

    /// 220pt across, drifting up to 3pt either side of the line.
    static var wobblyLine: [CGPoint] {
        (0...110).map { i in
            let t = CGFloat(i) / 110
            return CGPoint(x: 40 + 220 * t, y: 300 + 40 * t + wobble(i, amplitude: 3))
        }
    }

    /// A loop about 160 by 110, drawn round 350 degrees with its radius
    /// wandering by 5% and an end that misses its start.
    static var roughLoop: [CGPoint] {
        (0...140).map { i in
            let t = CGFloat(i) / 140 * 2 * .pi * (350 / 360)
            let r = 1 + wobble(i, amplitude: 0.05)
            return CGPoint(x: 200 + 80 * r * cos(t), y: 300 + 55 * r * sin(t))
        }
    }

    /// Back and forth across 120pt, never a line and never a loop.
    static var scribble: [CGPoint] {
        (0...120).map { i in
            let t = CGFloat(i)
            return CGPoint(x: 100 + t * 1.2 + 30 * sin(t * 0.4), y: 200 + 45 * sin(t * 0.23) * cos(t * 0.11))
        }
    }

    // MARK: - Snap

    @Test("a wobbly, nearly straight stroke snaps to the line between its ends")
    func lineSnaps() throws {
        let points = Self.wobblyLine
        let shape = try #require(InkAssist.shape(for: points))
        #expect(shape == .line(from: points.first!, to: points.last!))
    }

    @Test("a rough closed loop snaps to an ellipse near its own size")
    func loopSnapsToEllipse() throws {
        let shape = try #require(InkAssist.shape(for: Self.roughLoop))
        guard case let .ellipse(center, radii, _) = shape else {
            Issue.record("expected an ellipse, got \(shape)")
            return
        }
        #expect(abs(center.x - 200) < 6 && abs(center.y - 300) < 6)
        let big = max(radii.width, radii.height), small = min(radii.width, radii.height)
        #expect(abs(big - 80) < 8)
        #expect(abs(small - 55) < 8)
    }

    @Test("a loop that is nearly round becomes a circle")
    func roundLoopIsACircle() throws {
        let points = (0...120).map { i -> CGPoint in
            let t = CGFloat(i) / 120 * 2 * .pi
            return CGPoint(x: 100 + 60 * cos(t), y: 100 + 64 * sin(t))
        }
        let shape = try #require(InkAssist.shape(for: points))
        guard case let .ellipse(_, radii, _) = shape else { Issue.record("not an ellipse"); return }
        #expect(radii.width == radii.height)
    }

    @Test("a scribble does not snap to anything")
    func scribbleStays() {
        #expect(InkAssist.shape(for: Self.scribble) == nil)
    }

    @Test("an open arc is neither a line nor an ellipse")
    func arcStays() {
        let arc = (0...80).map { i -> CGPoint in
            let t = CGFloat(i) / 80 * .pi * 0.9
            return CGPoint(x: 200 + 100 * cos(t), y: 300 - 100 * sin(t))
        }
        #expect(InkAssist.shape(for: arc) == nil)
    }

    @Test("a snapped ellipse starts where the stroke started and closes on itself")
    func outlineStartsAtTheStroke() throws {
        let points = Self.roughLoop
        let shape = try #require(InkAssist.shape(for: points))
        let outline = InkAssist.outline(of: shape, start: points[0])
        let first = try #require(outline.first), last = try #require(outline.last)
        #expect(hypot(first.x - last.x, first.y - last.y) < 0.01)
        #expect(hypot(first.x - points[0].x, first.y - points[0].y) < 8)
    }

    /// **The self-test: the thresholds can fail.** Loosen them and the
    /// scribble snaps; tighten them and the wobbly line does not. A test of
    /// the scribble that would pass whatever the tolerance says nothing.
    @Test("a deliberately broken threshold is caught both ways")
    func brokenThresholdFails() {
        var loose = InkAssist.Tolerance.standard
        loose.lineRMS = 10; loose.lineMax = 10; loose.lineDetour = 10
        loose.ellipseMean = 10; loose.ellipseMax = 10; loose.ellipseSweep = 0; loose.ellipseGap = 10
        #expect(InkAssist.shape(for: Self.scribble, tolerance: loose) != nil)

        var strict = InkAssist.Tolerance.standard
        strict.lineRMS = 0.001; strict.lineMax = 0.001
        #expect(InkAssist.shape(for: Self.wobblyLine, tolerance: strict) == nil)
    }

    // MARK: - Smoothing

    @Test("smoothing keeps both ends and moves no point more than 1.5pt")
    func smoothingIsGentle() {
        // A line with 2pt of finger tremor on it, about 2pt between points.
        let raw = (0...100).map { i -> CGPoint in
            let tremor: CGFloat = i % 2 == 0 ? 1.5 : -1.5
            let y: CGFloat = 100 + Self.wobble(i, amplitude: 2) + tremor
            return CGPoint(x: 20 + CGFloat(i) * 2, y: y)
        }
        let smoothed = InkAssist.smooth(raw)
        #expect(smoothed.first == raw.first)
        #expect(smoothed.last == raw.last)
        let moved = zip(raw, smoothed).map { hypot($0.x - $1.x, $0.y - $1.y) }
        #expect(moved.max()! < 1.5)
        // And it did something: the tremor is smaller than it was.
        func roughness(_ p: [CGPoint]) -> CGFloat {
            var total: CGFloat = 0
            for i in 1..<(p.count - 1) {
                let bend: CGFloat = p[i - 1].y - 2 * p[i].y + p[i + 1].y
                total += abs(bend)
            }
            return total
        }
        #expect(roughness(smoothed) < roughness(raw) * 0.6)
    }

    @Test("the end of a stroke narrows; its start and middle do not")
    func taperIsAtTheEndOnly() {
        let points = (0...50).map { CGPoint(x: CGFloat($0) * 2, y: 0) }
        let factors = InkAssist.taper(points)
        #expect(factors.first == 1)
        #expect(factors[25] == 1)
        #expect(abs(factors.last! - 0.6) < 0.001)
        #expect(zip(factors.dropLast(), factors.dropFirst()).allSatisfy { $0 >= $1 })
        // A tick has no end to taper.
        #expect(InkAssist.taper([.zero, CGPoint(x: 4, y: 0), CGPoint(x: 8, y: 0)]).allSatisfy { $0 == 1 })
    }

    @Test("a still finger at the end reads as a hold; a lift on the move does not")
    func holdFromTimes() {
        let moving = (0...20).map { CGPoint(x: CGFloat($0) * 5, y: 0) }
        let times = (0...20).map { TimeInterval($0) * 0.016 }
        #expect(!InkAssist.heldAtEnd(moving, times: times))
        // The same stroke, the lift recorded 0.6s later where it stopped.
        let held = moving + [CGPoint(x: 100.5, y: 0.5)]
        #expect(InkAssist.heldAtEnd(held, times: times + [times.last! + 0.6]))
    }

    // MARK: - On a real stroke

    static func stroke(_ points: [CGPoint], size: CGFloat = InkPen.pointSize(forLine: InkPen.width)) -> PKStroke {
        let control = points.enumerated().map { i, p in
            PKStrokePoint(location: p, timeOffset: TimeInterval(i) * 0.01,
                          size: CGSize(width: size, height: size), opacity: 1, force: 1,
                          azimuth: 0, altitude: .pi / 2)
        }
        return PKStroke(ink: PKInk(.monoline, color: .black),
                        path: PKStrokePath(controlPoints: control, creationDate: Date()))
    }

    @Test("a held stroke snaps in the same ink and width; an unheld one is only smoothed")
    func assistedStroke() throws {
        let stroke = Self.stroke(Self.wobblyLine)
        let held = InkAssist.assisted(stroke, held: true)
        #expect(held.snapped)
        #expect(held.stroke.ink.inkType == .monoline)
        let size = try #require(stroke.path.first?.size.width)
        #expect(Array(held.stroke.path).allSatisfy { abs($0.size.width - size) < 0.001 })

        let loose = InkAssist.assisted(stroke, held: false)
        #expect(!loose.snapped)
        let before = Array(stroke.path.interpolatedPoints(by: .distance(4))).map(\.location)
        let after = Array(loose.stroke.path.interpolatedPoints(by: .distance(4))).map(\.location)
        // Never moved noticeably: each point of the drawn line is still
        // within 1.5pt of the smoothed one.
        for p in before {
            let nearest = after.map { hypot($0.x - p.x, $0.y - p.y) }.min() ?? .infinity
            #expect(nearest < 1.5 + 2)  // plus half the 4pt sampling step
        }
    }

    // MARK: - The canvas, read as source

    static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appending(path: path), encoding: .utf8)
    }

    @Test("the canvas has a two-finger tap that undoes, beside the undo button")
    func twoFingerTapExists() throws {
        let canvas = try Self.source("Strata/Views/Ink/InkCanvas.swift")
        #expect(canvas.contains("UITapGestureRecognizer("))
        #expect(canvas.contains("numberOfTouchesRequired = 2"))
        #expect(canvas.contains("controller.undo()"))
        // The visible button stays: a hidden gesture is never the only way in.
        #expect(canvas.contains("accessibilityLabel: \"Undo\""))
    }

    @Test("a snap records its own undo step, and PencilKit's manager records nothing")
    func snapRegistersUndo() throws {
        let canvas = try Self.source("Strata/Views/Ink/InkCanvas.swift")
        let snap = try #require(canvas.range(of: "if result.snapped {"))
        let after = canvas[snap.upperBound...].prefix(200)
        #expect(after.contains("controller.record(after)"))
        #expect(canvas.contains("disableUndoRegistration()"))
    }

    @Test("two undo steps for a snap: the freehand stroke first, then nothing")
    func historyOrder() {
        let controller = InkController()
        let empty = PKDrawing()
        let freehand = PKDrawing(strokes: [Self.stroke(Self.wobblyLine)])
        controller.record(empty)
        controller.record(freehand)
        #expect(controller.undoDepth == 2)
        controller.undo()
        #expect(controller.drawing.strokes.count == 1)
        controller.undo()
        #expect(controller.drawing.strokes.isEmpty)
        #expect(!controller.canUndo)
    }

    @Test("zoom: one finger draws, the page never scrolls at 1, and it zooms to 4")
    func zoomSetup() throws {
        let canvas = try Self.source("Strata/Views/Ink/InkCanvas.swift")
        #expect(canvas.contains("canvas.minimumZoomScale = 1"))
        #expect(canvas.contains("canvas.maximumZoomScale = Self.maximumZoom"))
        #expect(canvas.contains("canvas.drawingPolicy = .anyInput"))
        let view = OwnUndoCanvas(frame: CGRect(x: 0, y: 0, width: 300, height: 450))
        view.layoutIfNeeded()
        #expect(view.contentSize == CGSize(width: 300, height: 450))
    }
}
