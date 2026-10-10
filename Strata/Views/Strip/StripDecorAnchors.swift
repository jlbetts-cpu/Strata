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

    /// The same layout to within a hair, so a strip that has not changed
    /// draws the picture already saved rather than drawing it again.
    func matches(_ other: StripAnchors) -> Bool {
        guard abs(footTop - other.footTop) < 0.5, frames.keys == other.frames.keys else { return false }
        return frames.allSatisfy { key, r in
            guard let o = other.frames[key] else { return false }
            return zip(r, o).allSatisfy { abs($0 - $1) < 0.5 }
        }
    }

    /// `other`'s frames added to these, where these have none of their own.
    func merging(_ other: StripAnchors) -> StripAnchors {
        StripAnchors(frames: frames.merging(other.frames) { mine, _ in mine }, footTop: footTop)
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

    /// How a mark on `anchor` moves from `old` to `new`, or nil when its photo
    /// is not on the new strip.
    static func transform(for anchor: Anchor, from old: StripAnchors, to new: StripAnchors) -> CGAffineTransform? {
        switch anchor {
        case .paper:
            return .identity
        case .foot:
            return CGAffineTransform(translationX: 0, y: new.footTop - old.footTop)
        case .frame(let id):
            guard let o = old.rect(id), let n = new.rect(id), o.width > 0, o.height > 0 else { return nil }
            // By the centre, at the scale that keeps it inside the new frame:
            // a Quick that goes from a full row to half a pair keeps its
            // doodle on the same part of the picture, smaller.
            let s = min(n.width / o.width, n.height / o.height)
            return CGAffineTransform(translationX: -o.midX, y: -o.midY)
                .concatenating(CGAffineTransform(scaleX: s, y: s))
                .concatenating(CGAffineTransform(translationX: n.midX, y: n.midY))
        }
    }

    struct Moved {
        var drawing: PKDrawing
        var stickers: [InkSticker]
        /// Marks on photos no longer on the strip, where they were, so they
        /// come back with their photo.
        var parkedDrawing: PKDrawing
        var parkedStickers: [InkSticker]
    }

    /// Everything from `old` to `new`, in `StripDecor.canvasWidth` points.
    static func move(_ drawing: PKDrawing, stickers: [InkSticker],
                     from old: StripAnchors, to new: StripAnchors) -> Moved {
        var kept: [PKStroke] = [], parked: [PKStroke] = []
        for stroke in drawing.strokes {
            let b = stroke.renderBounds
            let anchor = anchor(of: CGPoint(x: b.midX, y: b.midY), in: old)
            if let t = transform(for: anchor, from: old, to: new) {
                var moved = stroke
                moved.transform = stroke.transform.concatenating(t)
                kept.append(moved)
            } else {
                parked.append(stroke)
            }
        }
        var keptStickers: [InkSticker] = [], parkedStickers: [InkSticker] = []
        for sticker in stickers {
            let anchor = anchor(of: sticker.center, in: old)
            if let t = transform(for: anchor, from: old, to: new) {
                var moved = sticker
                let c = sticker.center.applying(t)
                moved.x = c.x
                moved.y = c.y
                moved.size = sticker.size * Double(hypot(t.a, t.b))
                keptStickers.append(moved)
            } else {
                parkedStickers.append(sticker)
            }
        }
        return Moved(drawing: PKDrawing(strokes: kept), stickers: keptStickers,
                     parkedDrawing: PKDrawing(strokes: parked), parkedStickers: parkedStickers)
    }
}
