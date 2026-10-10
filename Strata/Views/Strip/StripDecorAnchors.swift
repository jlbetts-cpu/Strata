import PencilKit
import UIKit

/// **Where a strip's doodles and stickers belong** (the owner, 2026-10-09:
/// "fix the doodle shifting and sticker like where you draw or paste is where
/// it should go").
///
/// The strip's decoration was one picture laid over the paper from the top.
/// The paper under it is not fixed: a photo logged later joins the day, a
/// second Quick pairs with a lone one and turns a 2:1 row into two squares,
/// a frame is taken off in the editor. Every one of those moves the photos,
/// and the doodle stayed where it was, over a different picture.
///
/// So each stroke and each sticker belongs to what it was drawn on:
/// - **a photo**: it moves and scales with that photo, by its centre;
/// - **the foot** (the wordmark and signature): it moves with the foot;
/// - **the paper above or beside**: it stays.
/// A photo taken off the strip takes its doodles with it, and they come back
/// with it. Where each photo was is kept with the drawing (`StripAnchors`),
/// so this works on strips doodled before it existed only from their next
/// save: an old drawing has no record of what was under it.
struct StripAnchors: Codable, Equatable {
    /// Each frame's rectangle at `StripDecor.canvasWidth`: x, y, w, h.
    var frames: [String: [Double]]
    /// Where the foot begins, under the last row.
    var footTop: Double

    func rect(_ id: String) -> CGRect? {
        guard let r = frames[id], r.count == 4 else { return nil }
        return CGRect(x: r[0], y: r[1], width: r[2], height: r[3])
    }

    /// The strip's frames as `StripView` lays them out, at `width`.
    static func of(_ frames: [PhotoStrip.Frame], width: CGFloat = StripDecor.canvasWidth,
                   style: StripStyle = .current) -> StripAnchors {
        of(frames.map { ($0.id, $0.size) }, width: width, style: style)
    }

    static func of(_ frames: [(id: UUID, size: BlockSize)], width: CGFloat = StripDecor.canvasWidth,
                   style: StripStyle = .current) -> StripAnchors {
        let margin = width * style.edge, gap = width * style.gap
        let inner = width - 2 * margin
        var y = margin
        var rects: [String: [Double]] = [:]
        func put(_ index: Int, _ rect: CGRect) {
            rects[frames[index].id.uuidString] = [rect.minX, rect.minY, rect.width, rect.height].map(Double.init)
        }
        if frames.isEmpty { y += inner * 0.75 + gap }
        for row in StripLayout.rows(frames.map(\.size)) {
            switch row {
            case .pair(let a, let b):
                let side = (inner - gap) / 2
                put(a, CGRect(x: margin, y: y, width: side, height: side))
                put(b, CGRect(x: margin + side + gap, y: y, width: side, height: side))
                y += side + gap
            case .full(let i, let aspect):
                let h = inner / aspect
                put(i, CGRect(x: margin, y: y, width: inner, height: h))
                y += h + gap
            }
        }
        return StripAnchors(frames: rects, footTop: Double(y))
    }

    /// The layout as one line, for a cache's key.
    var signature: String {
        frames.keys.sorted().map { "\($0):\((frames[$0] ?? []).map { String(Int($0.rounded())) }.joined(separator: ","))" }
            .joined(separator: ";") + "|\(Int(footTop.rounded()))"
    }

    /// The same layout to within a hair, so a strip that has not changed
    /// draws the picture already saved rather than drawing it again.
    func matches(_ other: StripAnchors) -> Bool {
        guard abs(footTop - other.footTop) < 0.5, frames.keys == other.frames.keys else { return false }
        return frames.allSatisfy { key, r in
            guard let o = other.frames[key] else { return false }
            return zip(r, o).allSatisfy { abs($0 - $1) < 0.5 }
        }
    }
}

/// Moving a strip's decoration from one layout to another.
enum StripDecorPlacement {
    enum Anchor: Equatable {
        case frame(String)
        case foot
        case paper
    }

    /// What a mark at `point` was drawn on. A mark in the hairline gutter
    /// between two photos belongs to the nearer one.
    static func anchor(of point: CGPoint, in layout: StripAnchors) -> Anchor {
        let slack = 3.0
        var best: (id: String, distance: CGFloat)?
        for id in layout.frames.keys.sorted() {
            guard let rect = layout.rect(id) else { continue }
            if rect.contains(point) { return .frame(id) }
            let grown = rect.insetBy(dx: -slack, dy: -slack)
            guard grown.contains(point) else { continue }
            let d = hypot(point.x - rect.midX, point.y - rect.midY)
            if best == nil || d < best!.distance { best = (id, d) }
        }
        if let best { return .frame(best.id) }
        return point.y >= layout.footTop ? .foot : .paper
    }

    /// A mark carried from one rectangle of a photo to another: by the
    /// centre, at the scale that keeps it inside the new one. A Quick that
    /// goes from a full row to half a pair keeps its doodle on the same part
    /// of the picture, smaller.
    static func carry(from o: CGRect, to n: CGRect) -> CGAffineTransform? {
        guard o.width > 0, o.height > 0 else { return nil }
        let s = min(n.width / o.width, n.height / o.height)
        return CGAffineTransform(translationX: -o.midX, y: -o.midY)
            .concatenating(CGAffineTransform(scaleX: s, y: s))
            .concatenating(CGAffineTransform(translationX: n.midX, y: n.midY))
    }

    /// The marks of one photo that is off the strip, where they were, and
    /// where the photo was. **Kept by the photo's own id** (found 2026-10-10
    /// by review): they were kept in one pile and matched back to a photo by
    /// position, and a photo taken off leaves its old rectangle lying over
    /// whichever photo moved up into its place, so a neighbour's doodle
    /// could be taken for the removed photo's and vanish with it.
    struct Parked {
        var drawing = PKDrawing()
        var stickers: [InkSticker] = []
        var rect: CGRect
    }

    struct Moved {
        var drawing: PKDrawing
        var stickers: [InkSticker]
        /// Marks on photos that are not on the new strip, by photo.
        var parked: [String: Parked]
    }

    /// Everything from `old` to `new`, in `StripDecor.canvasWidth` points.
    static func move(_ drawing: PKDrawing, stickers: [InkSticker],
                     from old: StripAnchors, to new: StripAnchors) -> Moved {
        var kept: [PKStroke] = [], keptStickers: [InkSticker] = []
        var parked: [String: Parked] = [:]
        /// The transform for a mark at `point`, or the photo it is parked with.
        func place(_ point: CGPoint) -> (CGAffineTransform?, String?) {
            switch anchor(of: point, in: old) {
            case .paper: return (.identity, nil)
            case .foot: return (CGAffineTransform(translationX: 0, y: new.footTop - old.footTop), nil)
            case .frame(let id):
                guard let o = old.rect(id) else { return (.identity, nil) }
                if let n = new.rect(id), let t = carry(from: o, to: n) { return (t, nil) }
                if parked[id] == nil { parked[id] = Parked(rect: o) }
                return (nil, id)
            }
        }
        for stroke in drawing.strokes {
            let b = stroke.renderBounds
            let (t, id) = place(CGPoint(x: b.midX, y: b.midY))
            if let t {
                kept.append(moved(stroke, by: t))
            } else if let id {
                parked[id]?.drawing.append(PKDrawing(strokes: [stroke]))
            }
        }
        for sticker in stickers {
            let (t, id) = place(sticker.center)
            if let t {
                keptStickers.append(moved(sticker, by: t))
            } else if let id {
                parked[id]?.stickers.append(sticker)
            }
        }
        return Moved(drawing: PKDrawing(strokes: kept), stickers: keptStickers, parked: parked)
    }

    /// The parked marks whose photo is on `new`, put back on it; the rest
    /// stay parked.
    static func restore(_ parked: [String: Parked], to new: StripAnchors) -> Moved {
        var strokes: [PKStroke] = [], stickers: [InkSticker] = []
        var still: [String: Parked] = [:]
        for (id, group) in parked {
            guard let n = new.rect(id), let t = carry(from: group.rect, to: n) else {
                still[id] = group
                continue
            }
            strokes += group.drawing.strokes.map { moved($0, by: t) }
            stickers += group.stickers.map { moved($0, by: t) }
        }
        return Moved(drawing: PKDrawing(strokes: strokes), stickers: stickers, parked: still)
    }

    private static func moved(_ stroke: PKStroke, by t: CGAffineTransform) -> PKStroke {
        var out = stroke
        out.transform = stroke.transform.concatenating(t)
        return out
    }

    private static func moved(_ sticker: InkSticker, by t: CGAffineTransform) -> InkSticker {
        var out = sticker
        let c = sticker.center.applying(t)
        out.x = c.x
        out.y = c.y
        out.size = sticker.size * Double(hypot(t.a, t.b))
        return out
    }
}
