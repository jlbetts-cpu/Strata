import CoreGraphics
import Foundation
import PencilKit

/// **The pen's quiet help, as arithmetic** (the owner approved this pass on
/// 2026-10-06: hold to snap, light smoothing, pinch to zoom, two-finger tap to
/// undo). Everything here is pure: points in, points out, so the thresholds
/// can be tested without a finger. `InkCanvas` is the only caller.
///
/// Two things it does to a stroke you just drew, and never both:
///
/// - **Hold to snap**, Procreate's QuickShape in its smallest form. Finish a
///   stroke and keep the finger still, and a stroke that is nearly a line
///   becomes the line, and one that closes on itself and is nearly an ellipse
///   becomes the ellipse (a circle, when the two radii are within 12%).
///   Anything else is left exactly as drawn: a guess that turns a scribble
///   into a shape is worse than no help. No menu, no handles, no second
///   gesture to pick a variant, because "scarcity" is the owner's pick for
///   this pass: no new chrome.
/// - **Smoothing**, on every stroke that did not snap: one gentle weighted
///   average that takes out a finger's wobble, with every point held to
///   within `maxShift` of where it was drawn, so the drawing keeps its hand.
///   The last few points narrow a little, so an end reads as ink lifting
///   ("one hand, one weight": the same line, with tapered ends).
nonisolated enum InkAssist {

    // MARK: - Tolerances

    /// How close is close enough. Every number is relative to the stroke's
    /// own size except the floors, so a small circle and a big one are
    /// judged alike.
    struct Tolerance: Sendable, Equatable {
        /// A line: the root-mean-square distance from the chord, over its length.
        var lineRMS: CGFloat = 0.035
        /// A line: the furthest point from the chord, over its length.
        var lineMax: CGFloat = 0.08
        /// A line: the path's length over the chord's, at most. Out and back
        /// along one line is not a line.
        var lineDetour: CGFloat = 1.25
        /// Nothing shorter than this snaps, in points.
        var minLength: CGFloat = 16
        /// An ellipse: the gap between the ends, over its larger diameter.
        var ellipseGap: CGFloat = 0.3
        /// An ellipse: how much of one turn the stroke goes round, at least.
        var ellipseSweep: CGFloat = 0.85
        /// An ellipse: the average radial miss, as a fraction of the radius.
        var ellipseMean: CGFloat = 0.08
        /// An ellipse: the worst radial miss.
        var ellipseMax: CGFloat = 0.25
        /// The smaller radius, at least, in points.
        var minRadius: CGFloat = 4
        /// Radii this close are one circle.
        var circleWithin: CGFloat = 0.12

        static let standard = Tolerance()
    }

    /// The still finger that asks for a shape: 0.45s inside 3pt.
    static let holdDuration: TimeInterval = 0.45
    static let holdSlop: CGFloat = 3

    /// The furthest smoothing may move any point, in canvas points.
    static let maxShift: CGFloat = 1.25

    // MARK: - Shapes

    enum Shape: Equatable {
        case line(from: CGPoint, to: CGPoint)
        /// `radii` along the rotated axes; `rotation` in radians.
        case ellipse(center: CGPoint, radii: CGSize, rotation: CGFloat)
    }

    struct LineFit: Equatable {
        var from: CGPoint
        var to: CGPoint
        var length: CGFloat
        /// RMS and worst distance from the chord, each over `length`.
        var rms: CGFloat
        var worst: CGFloat
        /// Distance travelled along the chord over its length: 1 for a
        /// stroke that never turns back.
        var detour: CGFloat
    }

    struct EllipseFit: Equatable {
        var center: CGPoint
        var a: CGFloat
        var b: CGFloat
        var rotation: CGFloat
        /// Radial misses as a fraction of the radius: average and worst.
        var mean: CGFloat
        var worst: CGFloat
        /// Turns swept round the centre, signed (positive is the direction of
        /// increasing angle in the canvas's own axes).
        var sweep: CGFloat
        /// The gap between the stroke's ends over the larger diameter.
        var gap: CGFloat
    }

    /// The chord from the first point to the last, and how far the stroke
    /// strays from it. Nil for a stroke too short to have a direction.
    static func fitLine(_ points: [CGPoint]) -> LineFit? {
        guard points.count >= 2, let first = points.first, let last = points.last else { return nil }
        let d = last - first
        let length = d.length
        guard length > 0.001 else { return nil }
        var sum: CGFloat = 0, worst: CGFloat = 0
        for p in points {
            let off = abs(d.cross(p - first)) / length
            sum += off * off
            worst = max(worst, off)
        }
        let rms = (sum / CGFloat(points.count)).squareRoot()
        // Travel ALONG the chord, so a hand's sideways tremor (which the rms
        // already judges) does not count as going back on itself.
        let unit = d / length
        let along = zip(points, points.dropFirst()).reduce(CGFloat(0)) {
            $0 + abs(($1.1 - $1.0).dot(unit))
        }
        return LineFit(from: first, to: last, length: length,
                       rms: rms / length, worst: worst / length,
                       detour: along / length)
    }

    /// The ellipse that fits the stroke best, by least squares in the frame
    /// of its own principal axes (`A u² + B v² + C u + D v = 1`), and how
    /// well it fits. Nil when the points do not describe an ellipse at all.
    static func fitEllipse(_ raw: [CGPoint]) -> EllipseFit? {
        let total = pathLength(raw)
        guard raw.count >= 5, total > 1 else { return nil }
        // Even spacing, so a slow stretch of the stroke does not outvote a
        // fast one.
        let points = resample(raw, spacing: max(total / 96, 0.5))
        guard points.count >= 5 else { return nil }

        let n = CGFloat(points.count)
        let mean = points.reduce(CGPoint.zero) { $0 + $1 } / n
        var sxx: CGFloat = 0, syy: CGFloat = 0, sxy: CGFloat = 0
        for p in points {
            let q = p - mean
            sxx += q.x * q.x; syy += q.y * q.y; sxy += q.x * q.y
        }
        let rotation = 0.5 * atan2(2 * sxy, sxx - syy)
        let c = cos(rotation), s = sin(rotation)
        let scale = max(((sxx + syy) / n).squareRoot(), 0.001)
        let uv = points.map { p -> CGPoint in
            let q = p - mean
            return CGPoint(x: (q.x * c + q.y * s) / scale, y: (-q.x * s + q.y * c) / scale)
        }

        // Normal equations for [A, B, C, D].
        var m = [[Double]](repeating: [Double](repeating: 0, count: 5), count: 4)
        for p in uv {
            let row = [Double(p.x * p.x), Double(p.y * p.y), Double(p.x), Double(p.y)]
            for i in 0..<4 {
                for j in 0..<4 { m[i][j] += row[i] * row[j] }
                m[i][4] += row[i]
            }
        }
        guard let k = solve(m) else { return nil }
        let A = CGFloat(k[0]), B = CGFloat(k[1]), C = CGFloat(k[2]), D = CGFloat(k[3])
        guard A > 0, B > 0 else { return nil }
        let u0 = -C / (2 * A), v0 = -D / (2 * B)
        let g = 1 + A * u0 * u0 + B * v0 * v0
        guard g > 0 else { return nil }
        let a = (g / A).squareRoot(), b = (g / B).squareRoot()

        var errSum: CGFloat = 0, worst: CGFloat = 0, sweep: CGFloat = 0
        var previous: CGFloat?
        for p in uv {
            let x = (p.x - u0) / a, y = (p.y - v0) / b
            let miss = abs((x * x + y * y).squareRoot() - 1)
            errSum += miss
            worst = max(worst, miss)
            let angle = atan2(y, x)
            if let previous {
                var step = angle - previous
                if step > .pi { step -= 2 * .pi }
                if step < -.pi { step += 2 * .pi }
                sweep += step
            }
            previous = angle
        }
        let center = mean + CGPoint(x: (u0 * c - v0 * s) * scale, y: (u0 * s + v0 * c) * scale)
        let ra = a * scale, rb = b * scale
        let gap = ((raw.last ?? .zero) - (raw.first ?? .zero)).length / (2 * max(ra, rb))
        // The rotation of the ellipse's frame is the principal frame's, and
        // the sweep is measured in it; its sign survives because the frame is
        // a rotation, not a reflection.
        return EllipseFit(center: center, a: ra, b: rb, rotation: rotation,
                          mean: errSum / n, worst: worst,
                          sweep: sweep / (2 * .pi), gap: gap)
    }

    /// The shape a held stroke becomes, or nil to leave it as drawn. A line
    /// is tried first: a long thin loop that also passes as an ellipse is
    /// read as the line it nearly is only if it does not come back on itself
    /// (`lineDetour`).
    static func shape(for points: [CGPoint], tolerance t: Tolerance = .standard) -> Shape? {
        if let line = fitLine(points),
           line.length >= t.minLength,
           line.rms <= t.lineRMS, line.worst <= t.lineMax, line.detour <= t.lineDetour {
            return .line(from: line.from, to: line.to)
        }
        if let e = fitEllipse(points),
           2 * max(e.a, e.b) >= t.minLength, min(e.a, e.b) >= t.minRadius,
           e.gap <= t.ellipseGap || abs(e.sweep) >= 1,
           abs(e.sweep) >= t.ellipseSweep,
           e.mean <= t.ellipseMean, e.worst <= t.ellipseMax {
            var a = e.a, b = e.b
            if max(a, b) / min(a, b) <= 1 + t.circleWithin { a = (a + b) / 2; b = a }
            return .ellipse(center: e.center, radii: CGSize(width: a, height: b), rotation: e.rotation)
        }
        return nil
    }

    /// The shape as points to draw through, about `spacing` apart. An
    /// ellipse starts where the stroke started (`start`) and goes round the
    /// way it went (`clockwise` in the canvas's own axes, y down), and closes.
    static func outline(of shape: Shape, start: CGPoint, sweepPositive: Bool = true,
                        spacing: CGFloat = 3) -> [CGPoint] {
        switch shape {
        case let .line(from, to):
            let steps = max(Int((to - from).length / spacing), 1)
            return (0...steps).map { from + (to - from) * (CGFloat($0) / CGFloat(steps)) }
        case let .ellipse(center, radii, rotation):
            let c = cos(rotation), s = sin(rotation)
            let q = start - center
            let u = q.x * c + q.y * s, v = -q.x * s + q.y * c
            let t0 = atan2(v / max(radii.height, 0.001), u / max(radii.width, 0.001))
            let a = radii.width, b = radii.height
            // Ramanujan's perimeter, for the spacing.
            let h = pow(a - b, 2) / max(pow(a + b, 2), 0.001)
            let perimeter = CGFloat.pi * (a + b) * (1 + 3 * h / (10 + (4 - 3 * h).squareRoot()))
            let steps = max(Int(perimeter / spacing), 24)
            let direction: CGFloat = sweepPositive ? 1 : -1
            return (0...steps).map { i in
                let t = t0 + direction * 2 * .pi * CGFloat(i) / CGFloat(steps)
                let x = a * cos(t), y = b * sin(t)
                return center + CGPoint(x: x * c - y * s, y: x * s + y * c)
            }
        }
    }

    // MARK: - Smoothing and the ink's end

    /// A finger's wobble taken out, its character kept: a 1-4-6-4-1 average
    /// (1-2-1 next to the ends), the two ends where they were drawn, and no
    /// point moved more than `maxShift`. Expects points about 2pt apart,
    /// which is what `PKStrokePath.interpolatedPoints(by: .distance(2))` gives.
    static func smooth(_ points: [CGPoint], maxShift: CGFloat = InkAssist.maxShift) -> [CGPoint] {
        let n = points.count
        guard n >= 3 else { return points }
        var out = points
        for i in 1..<(n - 1) {
            let averaged: CGPoint
            if i >= 2, i <= n - 3 {
                averaged = (points[i - 2] + points[i - 1] * 4 + points[i] * 6
                            + points[i + 1] * 4 + points[i + 2]) / 16
            } else {
                averaged = (points[i - 1] + points[i] * 2 + points[i + 1]) / 4
            }
            let shift = averaged - points[i]
            let distance = shift.length
            out[i] = distance <= maxShift ? averaged : points[i] + shift * (maxShift / distance)
        }
        return out
    }

    /// How much of the line each point keeps, as a factor of its width: 1
    /// along the stroke, narrowing over its last `over` points of length to
    /// `to` at the very end. A stroke shorter than three times `over` keeps
    /// its width: a dot or a tick has no end to taper.
    static func taper(_ points: [CGPoint], over: CGFloat = 8, to: CGFloat = 0.6) -> [CGFloat] {
        var factors = [CGFloat](repeating: 1, count: points.count)
        guard points.count >= 3, pathLength(points) >= over * 3 else { return factors }
        var fromEnd: CGFloat = 0
        for i in stride(from: points.count - 1, through: 0, by: -1) {
            if i < points.count - 1 { fromEnd += (points[i + 1] - points[i]).length }
            guard fromEnd < over else { break }
            let t = fromEnd / over                   // 0 at the end, 1 where it starts
            let eased = t * t * (3 - 2 * t)
            factors[i] = to + (1 - to) * eased
        }
        return factors
    }

    /// Whether the stroke ended on a still finger: its last points stay
    /// within `slop` of where it lifted for at least `hold`. The after-lift
    /// reading, from the recorded times; the canvas also watches the finger
    /// live and does not depend on this alone.
    static func heldAtEnd(_ points: [CGPoint], times: [TimeInterval],
                          hold: TimeInterval = holdDuration, slop: CGFloat = holdSlop) -> Bool {
        guard points.count == times.count, points.count >= 2,
              let last = points.last, let end = times.last else { return false }
        var i = points.count - 1
        while i > 0, (points[i - 1] - last).length <= slop { i -= 1 }
        // The finger arrived at the still cluster at its first point; a
        // stroke that never left the cluster is a dot, not a hold.
        return i > 0 && end - times[i] >= hold
    }

    // MARK: - Strokes

    /// The stroke after the pen's help: snapped to its shape when `held` and
    /// one fits, otherwise smoothed and tapered. `snapped` says which.
    static func assisted(_ stroke: PKStroke, held: Bool,
                         tolerance: Tolerance = .standard) -> (stroke: PKStroke, snapped: Bool) {
        let control = Array(stroke.path)
        guard control.count >= 2 else { return (stroke, false) }
        let sampled = Array(stroke.path.interpolatedPoints(by: .distance(2)))
        let locations = sampled.map(\.location)
        let heldNow = held || heldAtEnd(control.map(\.location), times: control.map(\.timeOffset))
        if heldNow, let shape = shape(for: locations, tolerance: tolerance) {
            return (snapped(stroke, to: shape, sampled: sampled), true)
        }
        guard sampled.count >= 3 else { return (stroke, false) }
        let smoothed = smooth(locations)
        let factors = taper(smoothed)
        let points = sampled.indices.map { i -> PKStrokePoint in
            let p = sampled[i]
            let line = InkPen.lineWidth(forPointSize: p.size.width) * factors[i]
            let size = factors[i] < 1 ? InkPen.pointSize(forLine: line) : p.size.width
            return PKStrokePoint(location: smoothed[i], timeOffset: p.timeOffset,
                                 size: CGSize(width: size, height: size), opacity: p.opacity,
                                 force: p.force, azimuth: p.azimuth, altitude: p.altitude)
        }
        return (rebuilt(stroke, points: points), false)
    }

    /// The shape as a stroke in the same ink at the same width (the median
    /// of what was drawn, untapered: a shape has no hand to lift), its times
    /// spread over the time the original took, so a replay draws it at the
    /// pace it was drawn.
    static func snapped(_ stroke: PKStroke, to shape: Shape, sampled: [PKStrokePoint]) -> PKStroke {
        let sizes = sampled.map(\.size.width).sorted()
        let size = sizes.isEmpty ? InkPen.pointSize(forLine: InkPen.width) : sizes[sizes.count / 2]
        let first = sampled.first, start = first?.location ?? .zero
        let duration = max((sampled.last?.timeOffset ?? 0) - (first?.timeOffset ?? 0), 0.1)
        var positive = true
        if case .ellipse = shape, let fit = fitEllipse(sampled.map(\.location)) { positive = fit.sweep >= 0 }
        let outline = outline(of: shape, start: start, sweepPositive: positive)
        let last = max(outline.count - 1, 1)
        let points = outline.enumerated().map { i, location in
            PKStrokePoint(location: location,
                          timeOffset: (first?.timeOffset ?? 0) + duration * Double(i) / Double(last),
                          size: CGSize(width: size, height: size), opacity: first?.opacity ?? 1,
                          force: first?.force ?? 1, azimuth: first?.azimuth ?? 0,
                          altitude: first?.altitude ?? .pi / 2)
        }
        return rebuilt(stroke, points: points)
    }

    private static func rebuilt(_ stroke: PKStroke, points: [PKStrokePoint]) -> PKStroke {
        PKStroke(ink: stroke.ink,
                 path: PKStrokePath(controlPoints: points, creationDate: stroke.path.creationDate),
                 transform: stroke.transform, mask: stroke.mask)
    }

    // MARK: - Geometry

    static func pathLength(_ points: [CGPoint]) -> CGFloat {
        guard points.count >= 2 else { return 0 }
        return zip(points, points.dropFirst()).reduce(0) { $0 + ($1.1 - $1.0).length }
    }

    /// The polyline again, a point every `spacing` along it.
    static func resample(_ points: [CGPoint], spacing: CGFloat) -> [CGPoint] {
        guard points.count >= 2, spacing > 0, let first = points.first else { return points }
        var out = [first]
        var carried: CGFloat = 0
        for (a, b) in zip(points, points.dropFirst()) {
            let segment = (b - a).length
            guard segment > 0 else { continue }
            var at = spacing - carried
            while at <= segment {
                out.append(a + (b - a) * (at / segment))
                at += spacing
            }
            carried = segment - (at - spacing)
        }
        if let last = points.last, (out.last.map { ($0 - last).length } ?? 0) > spacing * 0.25 { out.append(last) }
        return out
    }

    /// Gaussian elimination with partial pivoting on an augmented 4x5.
    private static func solve(_ input: [[Double]]) -> [Double]? {
        var m = input
        let n = m.count
        for col in 0..<n {
            guard let pivot = (col..<n).max(by: { abs(m[$0][col]) < abs(m[$1][col]) }),
                  abs(m[pivot][col]) > 1e-12 else { return nil }
            m.swapAt(col, pivot)
            for row in 0..<n where row != col {
                let f = m[row][col] / m[col][col]
                for k in col...n { m[row][k] -= f * m[col][k] }
            }
        }
        return (0..<n).map { m[$0][n] / m[$0][$0] }
    }
}

// MARK: - Point arithmetic, private to the pen

nonisolated fileprivate extension CGPoint {
    static func + (l: CGPoint, r: CGPoint) -> CGPoint { CGPoint(x: l.x + r.x, y: l.y + r.y) }
    static func - (l: CGPoint, r: CGPoint) -> CGPoint { CGPoint(x: l.x - r.x, y: l.y - r.y) }
    static func * (l: CGPoint, r: CGFloat) -> CGPoint { CGPoint(x: l.x * r, y: l.y * r) }
    static func / (l: CGPoint, r: CGFloat) -> CGPoint { CGPoint(x: l.x / r, y: l.y / r) }
    var length: CGFloat { (x * x + y * y).squareRoot() }
    func cross(_ o: CGPoint) -> CGFloat { x * o.y - y * o.x }
    func dot(_ o: CGPoint) -> CGFloat { x * o.x + y * o.y }
}
