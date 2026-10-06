import Testing
import Foundation
import PencilKit
@testable import Strata

/// **Your own month drawing** (`docs/superpowers/specs/2026-10-05-shared-wins-journal-doodles-design.md`,
/// section 4): one file a calendar month, "Use Original" as a delete, and the
/// draw-on replay's clock.
@MainActor
@Suite("Month drawing", .serialized)
struct MonthDrawingTests {

    private func store() -> MonthDrawingStore { MonthDrawingStore(files: InkTests.folder()) }
    private let canvas = CGSize(width: 300, height: 450)

    // MARK: - Storage

    @Test("a drawing is kept per calendar month, keyed year and month")
    func keyedByMonth() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let oct31 = calendar.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 23))!
        let nov1 = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 0))!
        let jan = calendar.date(from: DateComponents(year: 2027, month: 1, day: 3))!
        #expect(MonthDrawingStore.key(for: oct31, calendar: calendar) == "2026-10")
        #expect(MonthDrawingStore.key(for: nov1, calendar: calendar) == "2026-11")
        #expect(MonthDrawingStore.key(for: jan, calendar: calendar) == "2027-01")

        let store = store()
        store.save(InkTests.drawing(strokes: [60, 30]), canvas: canvas, bringsToLife: true, for: "2026-10")
        let october = try #require(store.drawing(for: "2026-10"))
        #expect(store.drawing(for: "2026-11") == nil, "another month shows its default")
        #expect(october.canvasSize == canvas)
        #expect(october.bringsToLife)
        #expect(try PKDrawing(data: october.strokes).strokes.count == 2)
        #expect(store.files.exists(october.picture))
        #expect(store.files.exists(MonthDrawingStore.recordName("2026-10")))
    }

    @Test("the switch is kept with the drawing, and a redraw replaces the picture")
    func redraw() throws {
        let store = store()
        store.save(InkTests.drawing(strokes: [60]), canvas: canvas, bringsToLife: true, for: "2026-10")
        let first = try #require(store.drawing(for: "2026-10")).picture
        store.save(InkTests.drawing(strokes: [20]), canvas: canvas, bringsToLife: false, for: "2026-10")
        let second = try #require(store.drawing(for: "2026-10"))
        #expect(!second.bringsToLife)
        #expect(second.picture != first, "a new picture under a new name, so no cached copy is stale")
        #expect(!store.files.exists(first))
        // A fresh store reads the same thing off disk.
        let again = MonthDrawingStore(files: store.files)
        #expect(again.drawing(for: "2026-10") == second)
    }

    @Test("Use Original deletes the month's files and nothing else")
    func useOriginal() throws {
        let store = store()
        store.save(InkTests.drawing(strokes: [60]), canvas: canvas, bringsToLife: true, for: "2026-10")
        store.save(InkTests.drawing(strokes: [60]), canvas: canvas, bringsToLife: true, for: "2026-09")
        let before = store.revision
        store.remove("2026-10")
        #expect(store.drawing(for: "2026-10") == nil)
        #expect(store.revision > before, "a screen showing it draws again")
        #expect(store.drawing(for: "2026-09") != nil)
        let left = Set(store.files.all().map(\.lastPathComponent))
        #expect(!left.contains { $0.hasPrefix("month-2026-10") })
        #expect(left.contains(MonthDrawingStore.recordName("2026-09")))
    }

    @Test("drawn and rubbed out is the original again")
    func emptyIsOriginal() {
        let store = store()
        store.save(InkTests.drawing(strokes: [60]), canvas: canvas, bringsToLife: true, for: "2026-10")
        store.save(PKDrawing(), canvas: canvas, bringsToLife: true, for: "2026-10")
        #expect(store.drawing(for: "2026-10") == nil)
        #expect(store.files.all().isEmpty)
    }

    @Test("a record whose picture is gone is no drawing")
    func missingPicture() throws {
        let store = store()
        store.save(InkTests.drawing(strokes: [60]), canvas: canvas, bringsToLife: true, for: "2026-10")
        let picture = try #require(store.drawing(for: "2026-10")).picture
        store.files.remove(picture)
        #expect(MonthDrawingStore(files: store.files).drawing(for: "2026-10") == nil)
    }

    // MARK: - The replay's clock

    @Test("the strokes play in about 1.8 seconds, in the order they were drawn")
    func totalAndOrder() {
        let timing = InkReplayTiming(lengths: [100, 50, 200, 80, 120, 60])
        #expect(abs(timing.drawDuration - InkReplayTiming.total) < 1e-9)
        #expect(abs(timing.durations.reduce(0, +) - 1.8) < 1e-9)
        // In order, end to end: each starts as the one before it finishes.
        #expect(timing.starts.first == 0)
        for i in 1..<timing.starts.count {
            #expect(abs(timing.starts[i] - (timing.starts[i - 1] + timing.durations[i - 1])) < 1e-9)
        }
        // Shared by length.
        #expect(abs(timing.durations[2] / timing.durations[1] - 4) < 1e-9)
        #expect(abs(timing.playDuration - (1.8 + InkReplayTiming.settle)) < 1e-9)
    }

    @Test("no stroke takes more than its cap, and what it gives up goes to the rest")
    func capPerStroke() {
        // One long line and two short ones: by length alone the line would
        // take 1.66s and hold the rest back.
        let timing = InkReplayTiming(lengths: [1000, 50, 50])
        #expect(timing.durations[0] == InkReplayTiming.perStrokeCap)
        #expect(timing.durations.allSatisfy { $0 <= InkReplayTiming.perStrokeCap + 1e-9 })
        #expect(abs(timing.drawDuration - 1.8) < 1e-9, "the time it gave up is shared, not lost")
        // Two strokes cannot fill 1.8 at 0.6 each: the play is shorter,
        // never longer.
        let two = InkReplayTiming(lengths: [300, 300])
        #expect(abs(two.drawDuration - 1.2) < 1e-9)
        // The injection, so the cap can fail: without it the line is 1.66s.
        let uncapped = InkReplayTiming(lengths: [1000, 50, 50], cap: 10)
        #expect(uncapped.durations[0] > 1.6)
    }

    @Test("a dot still appears, and nothing to draw takes no time")
    func edges() {
        let timing = InkReplayTiming(lengths: [0, 100])
        #expect(timing.durations[0] > 0)
        #expect(timing.progress(of: 0, at: 0) == 0)
        #expect(timing.progress(of: 0, at: timing.durations[0]) == 1)
        #expect(timing.progress(of: 1, at: timing.starts[1]) == 0)
        #expect(timing.progress(of: 1, at: .infinity) == 1, "at rest everything is drawn")
        #expect(InkReplayTiming(lengths: []).drawDuration == 0)
    }

    @Test("the settle sways once and comes to rest; the boil only boils while drawing")
    func settleAndBoil() {
        #expect(InkReplayTiming.sway(at: 0) == 0)
        #expect(InkReplayTiming.sway(at: InkReplayTiming.settle) == 0)
        #expect(InkReplayTiming.sway(at: 10) == 0, "never a loop")
        let peak = stride(from: 0.0, to: InkReplayTiming.settle, by: 0.01).map { abs(InkReplayTiming.sway(at: $0)) }.max() ?? 0
        #expect(peak > 0.5 && peak < 3, "gentle, and there: \(peak) degrees")

        let timing = InkReplayTiming(lengths: [100, 100, 100])
        #expect(timing.boil(at: timing.drawDuration + 0.01) == .zero, "never at rest")
        #expect(timing.boil(at: 0) == .zero)
        let frames = Set(stride(from: 0.01, to: timing.drawDuration, by: 0.01).map {
            let b = timing.boil(at: $0)
            return "\(b.width),\(b.height)"
        })
        #expect(frames.count == 3)
        let biggest = stride(from: 0.01, to: timing.drawDuration, by: 0.01).map {
            let b = timing.boil(at: $0)
            return hypot(b.width, b.height)
        }.max() ?? 0
        #expect(biggest < 0.5, "tiny jitter, a fraction of a point")
    }

    @Test("the replay reads the strokes in the order they were drawn")
    func linesInOrder() {
        let drawing = InkTests.drawing(strokes: [80, 40, 120])
        let lines = InkReplay.lines(of: drawing)
        #expect(lines.count == 3)
        // `InkTests.drawing` lays each stroke on its own row, top to bottom.
        let rows = lines.map { $0.points.first?.y ?? 0 }
        #expect(rows == rows.sorted())
        let lengths = lines.map(InkReplay.length)
        #expect(lengths[2] > lengths[0] && lengths[0] > lengths[1])
        // `InkTests.drawing` records each point at the size given (2.5), so
        // the replay draws the line PencilKit draws for that size.
        #expect(lines.allSatisfy { abs($0.width - InkPen.lineWidth(forPointSize: InkPen.width)) < 0.01 })
    }

    @Test("the tool is set so the line drawn is the house width")
    func penCalibration() {
        // Measured on the simulator: a point records at the tool's width plus
        // 2, and draws about 1.35 times its size less 1.6. The round trip
        // lands the line at 2.5.
        let tool = InkPen.toolWidth(forLine: InkPen.width)
        #expect(abs(InkPen.lineWidth(forPointSize: tool + 2) - InkPen.width) < 0.01)
        #expect(abs(InkPen.lineWidth(forPointSize: InkPen.pointSize(forLine: 4)) - 4) < 0.01)
        // The measured points it was fitted to, within a third of a point.
        #expect(abs(InkPen.lineWidth(forPointSize: 4.5) - 4.2) < 0.33)
        #expect(abs(InkPen.lineWidth(forPointSize: 6.8) - 7) < 0.33)
        #expect(tool < InkPen.width, "a tool at the house width drew a 4.2pt line")
    }

    @Test("a drawing fitted to a bigger canvas replays its lines bigger too")
    func transformScalesTheLine() {
        let drawing = InkTests.drawing(strokes: [80])
        let scaled = drawing.transformed(using: CGAffineTransform(scaleX: 2, y: 2))
        let a = InkReplay.lines(of: drawing)[0], b = InkReplay.lines(of: scaled)[0]
        #expect(abs(b.width - 2 * a.width) < 0.01)
        #expect(abs(InkReplay.length(b) - 2 * InkReplay.length(a)) < 1)
    }
}
