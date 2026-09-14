import Foundation

/// A smooth curve through points that never overshoots them.
///
/// Fritsch-Carlson monotone cubic interpolation. The replay's camera needs a
/// curve that is smooth through a run of targets arriving a fraction of a
/// second apart (a spring retargeted thirty times shudders) and that never
/// dips or overshoots, because a camera that sinks back while a tower is
/// growing reads as a mistake.
struct MonotoneCurve {
    private let xs: [Double]
    private let ys: [Double]
    private let ms: [Double]

    init(points: [(x: Double, y: Double)]) {
        var merged: [(x: Double, y: Double)] = []
        for p in points.sorted(by: { $0.x < $1.x }) {
            if let last = merged.last, abs(last.x - p.x) < 1e-6 {
                merged[merged.count - 1].y = max(last.y, p.y)
            } else {
                merged.append(p)
            }
        }
        // Never down.
        for i in merged.indices.dropFirst() { merged[i].y = max(merged[i].y, merged[i - 1].y) }

        xs = merged.map(\.x)
        ys = merged.map(\.y)
        let n = merged.count
        guard n > 1 else { ms = Array(repeating: 0, count: n); return }

        var d: [Double] = []
        d.reserveCapacity(n - 1)
        for i in 0..<(n - 1) {
            let dy: Double = ys[i + 1] - ys[i]
            let dx: Double = xs[i + 1] - xs[i]
            d.append(dy / dx)
        }
        var m = Array(repeating: 0.0, count: n)
        m[0] = d[0]
        m[n - 1] = d[n - 2]
        for k in 1..<(n - 1) {
            let left: Double = d[k - 1]
            let right: Double = d[k]
            m[k] = (left * right <= 0) ? 0.0 : (left + right) / 2.0
        }
        for k in 0..<(n - 1) {
            if d[k] == 0 { m[k] = 0; m[k + 1] = 0; continue }
            let a = m[k] / d[k], b = m[k + 1] / d[k]
            let s = a * a + b * b
            if s > 9 {
                let tau: Double = 3.0 / s.squareRoot()
                m[k] = tau * a * d[k]
                m[k + 1] = tau * b * d[k]
            }
        }
        ms = m
    }

    func value(at x: Double) -> Double {
        guard let first = xs.first, let last = xs.last else { return 0 }
        if x <= first { return ys[0] }
        if x >= last { return ys[ys.count - 1] }
        var lo = 0, hi = xs.count - 1
        while hi - lo > 1 { let mid = (lo + hi) / 2; if xs[mid] <= x { lo = mid } else { hi = mid } }
        let h = xs[hi] - xs[lo]
        let t = (x - xs[lo]) / h
        let t2 = t * t, t3 = t2 * t
        return (2 * t3 - 3 * t2 + 1) * ys[lo]
            + (t3 - 2 * t2 + t) * h * ms[lo]
            + (-2 * t3 + 3 * t2) * ys[hi]
            + (t3 - t2) * h * ms[hi]
    }
}
