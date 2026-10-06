#if DEBUG
import PencilKit
import UIKit

/// **Drawings for screenshots.** A simulator driven by `simctl` cannot draw
/// with a finger, so the ink screens are photographed with one of these: a
/// small sun over a hill, drawn in the order a hand would (the circle, its
/// rays one by one, then the ground), in `InkPen`'s ink.
enum InkSamples {

    /// The sun over a hill, fitted to `size` (canvas points).
    static func sunOverHill(in size: CGSize, width: CGFloat = InkPen.width) -> PKDrawing {
        let w = size.width, h = size.height
        let centre = CGPoint(x: w * 0.62, y: h * 0.34)
        let r = min(w, h) * 0.13
        var strokes: [[CGPoint]] = []
        // The sun, round once and a little past, as a hand closes a circle.
        strokes.append((0...40).map { i in
            let a = Double(i) / 40 * 2.1 * .pi - .pi / 2
            return CGPoint(x: centre.x + r * cos(a), y: centre.y + r * sin(a))
        })
        // Eight rays.
        for k in 0..<8 {
            let a = Double(k) / 8 * 2 * .pi
            let inner = r * 1.35, outer = r * 1.85
            strokes.append([CGPoint(x: centre.x + inner * cos(a), y: centre.y + inner * sin(a)),
                            CGPoint(x: centre.x + outer * cos(a), y: centre.y + outer * sin(a))])
        }
        // The hill, a long slow line across.
        strokes.append((0...48).map { i in
            let u = Double(i) / 48
            return CGPoint(x: w * (0.06 + 0.88 * u), y: h * (0.82 - 0.22 * sin(u * .pi)))
        })
        // A bird.
        strokes.append([CGPoint(x: w * 0.2, y: h * 0.3), CGPoint(x: w * 0.25, y: h * 0.26),
                        CGPoint(x: w * 0.3, y: h * 0.3), CGPoint(x: w * 0.35, y: h * 0.26),
                        CGPoint(x: w * 0.4, y: h * 0.3)])
        return drawing(strokes, width: width)
    }

    /// Strokes through the given points, each a hand's pace apart.
    static func drawing(_ strokes: [[CGPoint]], width: CGFloat) -> PKDrawing {
        let ink = PKInk(.monoline, color: .black)
        return PKDrawing(strokes: strokes.map { points in
            let path = PKStrokePath(controlPoints: points.enumerated().map { i, p in
                PKStrokePoint(location: p, timeOffset: Double(i) * 0.012,
                              size: CGSize(width: width, height: width), opacity: 1,
                              force: 1, azimuth: 0, altitude: .pi / 2)
            }, creationDate: Date())
            return PKStroke(ink: ink, path: path)
        })
    }
}
#endif
