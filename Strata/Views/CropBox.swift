import SwiftUI

/// **The box a photo is framed in** (the owner, 2026-10-13: "on the apollo
/// landing page it kinda shows a resize box in the right photo of the hero
/// and I think that looks a lot cleaner maybe make the rule of third lines
/// less visible and the corner etches can be in the doodle style").
///
/// Three things, over a photo that runs on past the box: the photo outside
/// is faded toward the page, the thirds are drawn faintly inside, and the
/// four corners are marked in his pen's line. Nothing here takes a touch;
/// the photo under it does.
struct CropBox: View {
    /// The box, centred in whatever this is laid over.
    let box: CGSize
    let radius: CGFloat
    /// What the photo outside the box fades toward, and the pen's colour:
    /// the page and its ink on a sheet, black and the block's white ink on
    /// the camera's review, which is a dark room whatever the phone is set to.
    var ground: Color = WarmBackground.top
    var ink: Color = AppColors.drawingInk

    /// How much of the photo outside the box is taken away (his pick,
    /// "Dimmed outside": about 45%).
    static let dim: CGFloat = 0.45
    /// The thirds (his pick: about 25%).
    static let grid: CGFloat = 0.25
    /// The corner marks stand this far off the box, so the pen never covers
    /// the edge it is marking.
    static let gap: CGFloat = 5

    /// The box's corners: a block's own, for a box this size, and never
    /// rounder than a two-row block's. The editor took the box's short side
    /// for one cell, which is right for a one-row block and twice too round
    /// for a square one: at 47pt the box read as an app icon and the corner
    /// marks as four brackets (seen 2026-10-13).
    static func radius(for box: CGSize) -> CGFloat {
        min(24, GridConstants.blockCornerRadius(forCell: min(box.width, box.height)))
    }

    var body: some View {
        ZStack {
            CropOutside(box: box, radius: radius)
                .fill(ground.opacity(Self.dim), style: FillStyle(eoFill: true))
            CropThirds()
                .stroke(Color.white.opacity(Self.grid), lineWidth: 1)
                .frame(width: box.width, height: box.height)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            SketchCorners(radius: radius + Self.gap)
                .stroke(ink,
                        style: StrokeStyle(lineWidth: InkPen.width, lineCap: .round, lineJoin: .round))
                .frame(width: box.width + Self.gap * 2, height: box.height + Self.gap * 2)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Everything but the box: the whole rectangle with the box cut out of it.
private struct CropOutside: Shape {
    let box: CGSize
    let radius: CGFloat
    static let bleed: CGFloat = 2400

    func path(in rect: CGRect) -> Path {
        // Well past its own frame, up and down: the photo runs on under the
        // bars above and below, and it is faded there too.
        var path = Path(rect.insetBy(dx: 0, dy: -Self.bleed))
        path.addRoundedRect(in: CGRect(x: rect.midX - box.width / 2, y: rect.midY - box.height / 2,
                                       width: box.width, height: box.height),
                            cornerSize: CGSize(width: radius, height: radius), style: .continuous)
        return path
    }
}

/// The rule of thirds: two lines each way.
struct CropThirds: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for i in 1...2 {
            let x = rect.minX + rect.width * CGFloat(i) / 3
            let y = rect.minY + rect.height * CGFloat(i) / 3
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return path
    }
}

/// **Four corners, drawn by hand**: each a short line, round the corner,
/// and a short line on. Walked in small steps with `SketchBox`'s own wobble,
/// each corner on its own stretch of it, so no two are the same mark turned
/// round.
struct SketchCorners: Shape {
    /// The corner's own radius, where the pen turns.
    var radius: CGFloat = 12
    var seed: Int = 5

    /// How far the pen runs along each side from the corner's turn.
    static func arm(in rect: CGRect, radius: CGFloat) -> CGFloat {
        max(6, min(20, min(rect.width, rect.height) / 2 - radius - 6))
    }

    func path(in rect: CGRect) -> Path {
        let r = max(0, min(radius, min(rect.width, rect.height) / 2))
        let arm = Self.arm(in: rect, radius: r)
        var path = Path()
        // Each corner: where its turn is centred, and the angle it starts at.
        let corners: [(CGPoint, CGFloat)] = [
            (CGPoint(x: rect.minX + r, y: rect.minY + r), .pi),
            (CGPoint(x: rect.maxX - r, y: rect.minY + r), 1.5 * .pi),
            (CGPoint(x: rect.maxX - r, y: rect.maxY - r), 0),
            (CGPoint(x: rect.minX + r, y: rect.maxY - r), 0.5 * .pi)
        ]
        for (index, corner) in corners.enumerated() {
            let (centre, from) = corner
            var points: [CGPoint] = []
            let a = CGPoint(x: centre.x + cos(from) * r, y: centre.y + sin(from) * r)
            let to = from + .pi / 2
            let b = CGPoint(x: centre.x + cos(to) * r, y: centre.y + sin(to) * r)
            // In along the side before the turn, round it, out along the next.
            let before = CGPoint(x: a.x + sin(from) * arm, y: a.y - cos(from) * arm)
            let after = CGPoint(x: b.x - sin(to) * arm, y: b.y + cos(to) * arm)
            let steps = max(2, Int(arm / 4))
            for i in 0..<steps {
                let t = CGFloat(i) / CGFloat(steps)
                points.append(CGPoint(x: before.x + (a.x - before.x) * t, y: before.y + (a.y - before.y) * t))
            }
            let turn = max(3, Int(r / 2))
            for i in 0...turn {
                let angle = from + (to - from) * CGFloat(i) / CGFloat(turn)
                points.append(CGPoint(x: centre.x + cos(angle) * r, y: centre.y + sin(angle) * r))
            }
            for i in 1...steps {
                let t = CGFloat(i) / CGFloat(steps)
                points.append(CGPoint(x: b.x + (after.x - b.x) * t, y: b.y + (after.y - b.y) * t))
            }
            let s = CGFloat(seed + index * 7)
            for (i, p) in points.enumerated() {
                let t = CGFloat(i)
                let nudge = sin(t * 0.61 + s) * 0.5 + sin(t * 0.17 + s * 1.7) * 0.7
                let q = CGPoint(x: p.x + nudge * 0.6, y: p.y + nudge * 0.8)
                if i == 0 { path.move(to: q) } else { path.addLine(to: q) }
            }
        }
        return path
    }
}
