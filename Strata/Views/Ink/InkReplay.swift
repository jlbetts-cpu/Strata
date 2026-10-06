import PencilKit
import SwiftUI

/// **Your month drawing, brought to life** (spec section 4, "The animation").
///
/// The saved strokes draw themselves on in the order you drew them, each
/// revealed along its own interpolated path (`PKStrokePath.interpolatedPoints`),
/// time-compressed to about 1.8s with a cap per stroke (`InkReplayTiming`),
/// and then it is still. No sway and no boil: the owner, 2026-10-06, "the
/// drawing animation with the shake it doesnt give off premium to me".
///
/// **When**, as the scarecrow: once on appear and again on a tap, never a
/// loop (nothing in this app loops; `SkeletonBlockView` has why), and only
/// with "Bring It to Life" on. Under Reduce Motion it is a short fade and
/// nothing moves. The timeline runs only while a play is under way.
///
/// Drawn in a `Canvas` in the page's ink, so it follows dark mode the way the
/// owner's drawings do; the PNG beside it is the still copy for everywhere
/// else (`MonthDrawingStore.pictureURL`).
struct InkReplay: View {
    let drawing: MonthDrawing
    /// The drawing's height at most, as `Illustration`'s.
    var height: CGFloat = 290
    /// Called when a play has finished, and once at once when nothing plays.
    var onRest: (@MainActor () -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lines: [Line] = []
    @State private var timing = InkReplayTiming(lengths: [])
    /// When the current play began; nil at rest.
    @State private var playedAt: Date?
    /// Before the first play, the drawing waits at its first frame (empty)
    /// rather than flashing whole and then starting over.
    @State private var waiting = true
    @State private var shown = true

    /// One stroke, as the points it passes through, in canvas points.
    struct Line: Equatable {
        var points: [CGPoint]
        /// The body's width.
        var width: CGFloat
        /// The width at each point: the body's, narrowing at the tips
        /// (`InkAssist.taper`), so a replay draws the line the canvas drew.
        var widths: [CGFloat] = []
    }

    private var animates: Bool { drawing.bringsToLife && !reduceMotion }

    var body: some View {
        Group {
            if animates {
                TimelineView(.animation(paused: playedAt == nil)) { context in
                    let t = waiting ? 0 : playedAt.map { context.date.timeIntervalSince($0) } ?? .infinity
                    ink(at: t)
                }
            } else {
                ink(at: .infinity).opacity(shown ? 1 : 0)
            }
        }
        .aspectRatio(drawing.canvasWidth / max(drawing.canvasHeight, 1), contentMode: .fit)
        .frame(minHeight: height * 0.5, maxHeight: height)
        .layoutPriority(1)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { play() }
        .task(id: drawing.picture) {
            load()
            play()
            #if DEBUG
            // `-strataMonthReplayEvery <s>`: plays again every s seconds, so
            // a play can be caught mid-stroke by a screenshot. Never shipped:
            // the drawing does not loop.
            if let every = DebugHarness.argument("-strataMonthReplayEvery").flatMap(Double.init) {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(every))
                    play()
                }
            }
            #endif
        }
        .onDisappear { playedAt = nil }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your drawing for the month")
        .accessibilityAddTraits(.isImage)
    }

    private func ink(at t: Double) -> some View {
        Canvas { context, size in
            let scale = size.width / max(drawing.canvasWidth, 1)
            for (index, line) in lines.enumerated() {
                let progress = timing.progress(of: index, at: t)
                guard progress > 0, !line.points.isEmpty else { continue }
                let count = max(1, Int((Double(line.points.count) * progress).rounded(.up)))
                let points = line.points.prefix(count).map { CGPoint(x: $0.x * scale, y: $0.y * scale) }
                let width = line.width * scale
                if points.count == 1 {
                    let p = points[0]
                    context.fill(Path(ellipseIn: CGRect(x: p.x - width / 2, y: p.y - width / 2,
                                                        width: width, height: width)),
                                 with: .color(AppColors.drawingInk))
                    continue
                }
                // **The line's own widths, not one for the stroke.** It took
                // the first point's, the thinnest once the start tapered,
                // so every replayed line drew at its tip's weight. Runs of
                // one width are one path; the tips step down a segment at a
                // time. The ink is opaque, so the round caps where segments
                // meet do not darken.
                let widths = line.widths.count == line.points.count
                    ? line.widths.prefix(count).map { $0 * scale }
                    : Array(repeating: width, count: points.count)
                var i = 0
                while i < points.count - 1 {
                    var j = i + 1
                    while j < points.count - 1, abs(widths[j] - widths[i]) < 0.05 { j += 1 }
                    var path = Path()
                    path.addLines(Array(points[i...j]))
                    context.stroke(path, with: .color(AppColors.drawingInk),
                                   style: StrokeStyle(lineWidth: (widths[i] + widths[j]) / 2,
                                                      lineCap: .round, lineJoin: .round))
                    i = j
                }
            }
        }
    }

    /// The strokes, as points along each, and the clock they play on.
    private func load() {
        guard let pk = try? PKDrawing(data: drawing.strokes) else { lines = []; return }
        lines = Self.lines(of: pk)
        timing = InkReplayTiming(lengths: lines.map(Self.length))
    }

    static func lines(of drawing: PKDrawing) -> [Line] {
        drawing.strokes.map { stroke in
            let sampled = Array(stroke.path.interpolatedPoints(by: .distance(1.5)))
            let points = sampled.map { $0.location.applying(stroke.transform) }
            // The line PencilKit draws for each recorded size, scaled with
            // the stroke when a drawing was fitted to another canvas.
            let t = stroke.transform
            let scale = sqrt(abs(t.a * t.d - t.b * t.c))
            let widths = sampled.map { InkPen.lineWidth(forPointSize: $0.size.width) * scale }
            let body = widths.max() ?? InkPen.width * scale
            return Line(points: points, width: body, widths: widths)
        }
    }

    static func length(_ line: Line) -> Double {
        zip(line.points, line.points.dropFirst()).reduce(0) { sum, pair in
            sum + hypot(pair.1.x - pair.0.x, pair.1.y - pair.0.y)
        }
    }

    private func play() {
        guard animates else {
            // Reduce Motion: a short fade, and nothing moves.
            if drawing.bringsToLife {
                shown = false
                withAnimation(GridConstants.crossFade) { shown = true }
            }
            onRest?()
            return
        }
        guard playedAt == nil else { return }
        let started = Date()
        waiting = false
        playedAt = started
        let duration = timing.playDuration
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration + 0.05))
            guard playedAt == started else { return }
            playedAt = nil
            onRest?()
        }
    }
}
