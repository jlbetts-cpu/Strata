import SwiftUI

/// One cell of the tower grid.
struct GridCell: Hashable {
    let column: Int
    let row: Int
}

/// The outline of a set of grid cells, as a single rounded shape.
///
/// This exists because a merged run of blocks has to be drawn ONCE — one
/// outline, one frosted band, one shadow. Drawing those per block and hiding
/// the parts that fall on a seam gets close but never clean: every suppressed
/// edge leaves something behind, and stacking four such suppressions produced
/// exactly the stray pixels and half-lines that made a merged run still read as
/// separate blocks.
///
/// The path is built from the cells, not from the blocks: a 2x2 block
/// contributes four cells, so a group of mixed sizes has one honest outline.
///
/// Each cell is grown by half the grid gap on every side that faces another
/// cell in the set, so neighbours meet exactly and the seams close. Outer edges
/// keep the true block bounds, so a merged run is exactly as wide as the blocks
/// it replaces.
struct MergedShape: Shape {
    let cells: Set<GridCell>
    let cellSize: CGFloat
    let spacing: CGFloat
    /// Height of the grid, needed to flip row 0 to the bottom.
    let gridHeight: CGFloat
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for loop in boundaryLoops() {
            appendRounded(loop, to: &path)
        }
        return path
    }

    // MARK: - Geometry

    private var pitch: CGFloat { cellSize + spacing }

    /// A cell's rect at FULL pitch, centred on the block it represents.
    ///
    /// Growing each cell only toward its own occupied neighbours seems right
    /// and is not: at a concave corner the two boundaries end up offset by half
    /// the gap in BOTH axes, leaving a notch the edges cannot chain across.
    /// That is what produced a torn path.
    ///
    /// Pitch rects tile perfectly, so every edge meets its neighbour exactly
    /// and the boundary always closes. The whole polygon is then inset by half
    /// the gap, which lands the outer edges precisely on the real block bounds.
    private func rect(for cell: GridCell) -> CGRect {
        let half = spacing / 2
        let x = CGFloat(cell.column) * pitch - half
        let yBottom = gridHeight - CGFloat(cell.row) * pitch + half
        return CGRect(x: x, y: yBottom - pitch, width: pitch, height: pitch)
    }

    // MARK: - Boundary

    private struct Segment { let from: CGPoint; let to: CGPoint }

    /// Every cell edge with no cell on the other side, wound clockwise on
    /// screen (right along the top, down the right, left along the bottom, up
    /// the left).
    private func boundarySegments() -> [Segment] {
        var out: [Segment] = []
        for cell in cells {
            let r = rect(for: cell)
            let hasAbove = cells.contains(GridCell(column: cell.column, row: cell.row + 1))
            let hasBelow = cells.contains(GridCell(column: cell.column, row: cell.row - 1))
            let hasLeft  = cells.contains(GridCell(column: cell.column - 1, row: cell.row))
            let hasRight = cells.contains(GridCell(column: cell.column + 1, row: cell.row))

            if !hasAbove { out.append(Segment(from: CGPoint(x: r.minX, y: r.minY), to: CGPoint(x: r.maxX, y: r.minY))) }
            if !hasRight { out.append(Segment(from: CGPoint(x: r.maxX, y: r.minY), to: CGPoint(x: r.maxX, y: r.maxY))) }
            if !hasBelow { out.append(Segment(from: CGPoint(x: r.maxX, y: r.maxY), to: CGPoint(x: r.minX, y: r.maxY))) }
            if !hasLeft  { out.append(Segment(from: CGPoint(x: r.minX, y: r.maxY), to: CGPoint(x: r.minX, y: r.minY))) }
        }
        return out
    }

    /// Pulls the polygon in by half the grid gap, so its outer edges land on
    /// the real block bounds rather than on the pitch grid.
    ///
    /// Clockwise on screen means the interior lies at +90 degrees from the
    /// direction of travel, so each edge moves along `(-dy, dx)`. Every vertex
    /// of a rectilinear polygon joins one vertical and one horizontal edge, so
    /// its new x comes from the vertical one and its new y from the horizontal
    /// one — no line intersection needed.
    private func inset(_ points: [CGPoint]) -> [CGPoint] {
        let n = points.count
        guard n >= 4 else { return points }
        let d = spacing / 2
        return (0..<n).map { i in
            let prev = points[(i - 1 + n) % n]
            let cur = points[i]
            let next = points[(i + 1) % n]

            var x = cur.x, y = cur.y
            for (a, b) in [(prev, cur), (cur, next)] {
                let dx = b.x - a.x, dy = b.y - a.y
                if abs(dx) < 0.01 {              // vertical edge
                    x += (dy > 0 ? -d : d)
                } else if abs(dy) < 0.01 {       // horizontal edge
                    y += (dx > 0 ? d : -d)
                }
            }
            return CGPoint(x: x, y: y)
        }
    }

    private func key(_ p: CGPoint) -> String {
        // Rounded, so endpoints that are equal by construction also compare
        // equal after floating-point arithmetic.
        String(format: "%.2f,%.2f", p.x, p.y)
    }

    private func boundaryLoops() -> [[CGPoint]] {
        var byStart: [String: [Segment]] = [:]
        for s in boundarySegments() { byStart[key(s.from), default: []].append(s) }

        var loops: [[CGPoint]] = []
        var usedFrom: [String: Int] = [:]

        for seed in byStart.keys.sorted() {
            while (usedFrom[seed] ?? 0) < (byStart[seed]?.count ?? 0) {
                var loop: [CGPoint] = []
                var cursor = seed
                var guardCount = 0
                while guardCount < 4096 {
                    guardCount += 1
                    let taken = usedFrom[cursor] ?? 0
                    guard let options = byStart[cursor], taken < options.count else { break }
                    usedFrom[cursor] = taken + 1
                    let seg = options[taken]
                    loop.append(seg.from)
                    cursor = key(seg.to)
                    if cursor == seed { break }
                }
                if loop.count >= 4 { loops.append(inset(simplify(loop))) }
            }
        }
        return loops
    }

    /// Drops points that sit in the middle of a straight run, so the corner
    /// rounding below only ever sees real corners.
    private func simplify(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count > 2 else { return points }
        var out: [CGPoint] = []
        for i in 0..<points.count {
            let prev = points[(i - 1 + points.count) % points.count]
            let cur = points[i]
            let next = points[(i + 1) % points.count]
            let collinear = (abs(prev.x - cur.x) < 0.01 && abs(cur.x - next.x) < 0.01)
                         || (abs(prev.y - cur.y) < 0.01 && abs(cur.y - next.y) < 0.01)
            if !collinear { out.append(cur) }
        }
        return out.isEmpty ? points : out
    }

    /// Rounds every corner, convex and concave alike.
    ///
    /// `addArc(tangent1End:tangent2End:radius:)` handles both without the path
    /// needing to know which it is — it fillets whatever angle the two
    /// segments make. The radius is capped at half the shorter adjoining run so
    /// a small cell cannot produce an arc larger than the edge it sits on.
    private func appendRounded(_ points: [CGPoint], to path: inout Path) {
        guard points.count >= 3 else { return }
        let n = points.count

        func start() -> CGPoint {
            let a = points[0], b = points[1]
            return CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }

        path.move(to: start())
        for i in 1...n {
            let corner = points[i % n]
            let next = points[(i + 1) % n]
            let prev = points[(i - 1 + n) % n]
            let inLen = hypot(corner.x - prev.x, corner.y - prev.y)
            let outLen = hypot(next.x - corner.x, next.y - corner.y)
            let r = min(cornerRadius, min(inLen, outLen) / 2)
            path.addArc(tangent1End: corner, tangent2End: next, radius: max(r, 0.01))
        }
        path.closeSubpath()
    }
}
