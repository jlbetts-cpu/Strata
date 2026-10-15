import SwiftUI

/// **One of the owner's drawings, cut into its parts so each part can move**
/// (the owner, 2026-10-14: "make sure for the animations you are animating as
/// many parts as possible ... the eyes and mouth and stuff").
///
/// Every part is his ink, cut out of his drawing and saved at the drawing's
/// full size, so the parts line up exactly when nothing moves. Nothing is
/// redrawn: where he drew two poses (a calm cat and a scared one, a fist and
/// a thumb), the parts the two poses share are one layer and only the parts
/// that differ swap. The one exception is `InkStroke`, a few short dashes in
/// his pen's weight for a "click", which he asked for by name.
///
/// A figure says, as a pure function of the seconds since its play began,
/// where each part is. Transforms are in the drawing's own pixels (his
/// 2048-wide canvas, cropped), so a part turns about the joint it hangs from
/// whatever size the drawing is shown at.
///
/// It plays once when it comes into view and again on a tap, as
/// `Illustration` does; the one that walks (`JoiningWalk`) loops instead,
/// because while a crew is joining it is the spinner. Under Reduce Motion it
/// is the still drawing.
struct InkPart {
    var asset: String
    var transform: CGAffineTransform = .identity
    var opacity: Double = 1
    /// Where the part shows, in the drawing's pixels: ink drawn in as
    /// something moves (the cat's scratches, behind its claws).
    var reveal: [CGRect]? = nil
}

/// A short dash in his pen's weight, in the drawing's pixels.
struct InkStroke {
    var from: CGPoint
    var to: CGPoint
    var opacity: Double
}

protocol InkScript {
    /// The drawing's size, in his pixels.
    var canvas: CGSize { get }
    /// How long one play is, settle included; nil when it loops.
    var length: Double? { get }
    /// How long a looping figure takes to come to rest once it stops.
    var settle: Double { get }
    /// Every part, in the same order every frame; a part that is not showing
    /// has opacity 0.
    func parts(at t: Double, stoppedAt: Double?) -> [InkPart]
    func strokes(at t: Double) -> [InkStroke]
    /// What Reduce Motion shows.
    var still: [InkPart] { get }
}

extension InkScript {
    var settle: Double { 0 }
    func strokes(at t: Double) -> [InkStroke] { [] }
}

struct InkFigure<Script: InkScript>: View {
    let script: Script
    /// The drawing's height at most; the width follows the drawing.
    var height: CGFloat = 150
    var ink: Color = AppColors.drawingInk
    /// For a looping figure: false brings it to rest.
    var running = true
    /// His pen, in his pixels: what an `InkStroke` is drawn with.
    static var pen: CGFloat { 11 }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt: Date?
    @State private var stoppedAt: Double?
    @State private var playing = false

    var body: some View {
        Group {
            if reduceMotion {
                layers(script.still, strokes: [])
            } else {
                TimelineView(.animation(paused: !playing)) { context in
                    let t = startedAt.map { context.date.timeIntervalSince($0) } ?? 0
                    layers(script.parts(at: t, stoppedAt: stoppedAt), strokes: script.strokes(at: t))
                }
                .contentShape(Rectangle())
                .onTapGesture { if script.length != nil { play() } }
                .onAppear { play() }
                .onDisappear { playing = false; startedAt = nil }
                // Plays when it comes into view, not only when it is built
                // (`Illustration` has why: a page built ahead danced to nobody).
                .onScrollVisibilityChange(threshold: 0.6) { visible in
                    if visible, script.length != nil { play() }
                }
                .onChange(of: running) { _, now in
                    if now { play() } else { rest() }
                }
            }
        }
        .aspectRatio(script.canvas, contentMode: .fit)
        .frame(maxHeight: height)
        .accessibilityHidden(true)
    }

    private func layers(_ parts: [InkPart], strokes: [InkStroke]) -> some View {
        GeometryReader { proxy in
            let k = proxy.size.width / script.canvas.width
            ZStack(alignment: .topLeading) {
                ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                    Image(part.asset)
                        .renderingMode(.template)
                        .resizable()
                        .foregroundStyle(ink)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .mask(alignment: .topLeading) {
                            if let reveal = part.reveal {
                                ZStack(alignment: .topLeading) {
                                    ForEach(Array(reveal.enumerated()), id: \.offset) { _, r in
                                        Rectangle()
                                            .frame(width: max(r.width * k, 0), height: max(r.height * k, 0))
                                            .offset(x: r.minX * k, y: r.minY * k)
                                    }
                                }
                                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                            } else {
                                Rectangle()
                            }
                        }
                        .transformEffect(Self.onScreen(part.transform, k: k))
                        .opacity(part.opacity)
                }
                if !strokes.isEmpty {
                    Canvas { context, _ in
                        for stroke in strokes where stroke.opacity > 0 {
                            var path = Path()
                            path.move(to: CGPoint(x: stroke.from.x * k, y: stroke.from.y * k))
                            path.addLine(to: CGPoint(x: stroke.to.x * k, y: stroke.to.y * k))
                            context.stroke(path, with: .color(ink.opacity(stroke.opacity)),
                                           style: StrokeStyle(lineWidth: Self.pen * k, lineCap: .round))
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
        }
    }

    /// A transform in his pixels, as one on screen.
    private static func onScreen(_ t: CGAffineTransform, k: CGFloat) -> CGAffineTransform {
        guard k > 0, !t.isIdentity else { return t }
        return CGAffineTransform(scaleX: 1 / k, y: 1 / k).concatenating(t).concatenating(CGAffineTransform(scaleX: k, y: k))
    }

    /// From the start, even if a play is under way: what is seen is the whole of it.
    private func play() {
        let started = Date()
        startedAt = started
        stoppedAt = running ? nil : 0
        playing = true
        guard let length = script.length else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(length + 0.05))
            if startedAt == started { playing = false }
        }
    }

    /// A looping figure comes to rest where it is in its stride.
    private func rest() {
        guard let started = startedAt, playing else { return }
        stoppedAt = Date().timeIntervalSince(started)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(script.settle + 0.05))
            if startedAt == started { playing = false }
        }
    }
}

// MARK: - Moves, in his pixels

enum Ink {
    static func rotate(_ degrees: Double, about p: CGPoint) -> CGAffineTransform {
        CGAffineTransform(translationX: -p.x, y: -p.y)
            .concatenating(CGAffineTransform(rotationAngle: degrees * .pi / 180))
            .concatenating(CGAffineTransform(translationX: p.x, y: p.y))
    }

    static func scale(_ sx: Double, _ sy: Double, about p: CGPoint) -> CGAffineTransform {
        CGAffineTransform(translationX: -p.x, y: -p.y)
            .concatenating(CGAffineTransform(scaleX: sx, y: sy))
            .concatenating(CGAffineTransform(translationX: p.x, y: p.y))
    }

    static func move(_ dx: Double, _ dy: Double) -> CGAffineTransform {
        CGAffineTransform(translationX: dx, y: dy)
    }

    /// Leans everything below (or above) `y` sideways by `k` points a
    /// point, and nothing at `y` itself: a leg swinging from a joint cut
    /// level, which stays joined at the cut.
    static func shearX(_ k: Double, aboutY y: Double) -> CGAffineTransform {
        CGAffineTransform(a: 1, b: 0, c: k, d: 1, tx: -k * y, ty: 0)
    }

    /// A piece between two level cuts, its ends moved: the cut at `y0` goes
    /// to `to0` and `dx0` along, the one at `y1` to `to1` and `dx1` along,
    /// and everything between follows. A thigh and a shin that share the
    /// knee's cut stay joined however the knee moves.
    static func segment(_ y0: Double, to to0: Double, dx0: Double, _ y1: Double, to to1: Double, dx1: Double) -> CGAffineTransform {
        let s = (to1 - to0) / (y1 - y0), k = (dx1 - dx0) / (y1 - y0)
        return CGAffineTransform(a: 1, b: 0, c: k, d: s, tx: dx0 - k * y0, ty: to0 - s * y0)
    }

    /// A flap folding on its hinge, seen face on: squashed across the hinge
    /// line from `a` to `b`, which does not move.
    static func fold(_ amount: Double, hinge a: CGPoint, _ b: CGPoint) -> CGAffineTransform {
        let angle = atan2(b.y - a.y, b.x - a.x)
        return CGAffineTransform(translationX: -a.x, y: -a.y)
            .concatenating(CGAffineTransform(rotationAngle: -angle))
            .concatenating(CGAffineTransform(scaleX: 1, y: amount))
            .concatenating(CGAffineTransform(rotationAngle: angle))
            .concatenating(CGAffineTransform(translationX: a.x, y: a.y))
    }

    // MARK: Curves

    static func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }
    static func smooth(_ x: Double) -> Double { let u = clamp(x); return u * u * (3 - 2 * u) }
    static func easeIn(_ x: Double) -> Double { let u = clamp(x); return u * u }
    static func backOut(_ x: Double) -> Double {
        let c1 = 1.70158, c3 = c1 + 1, u = clamp(x) - 1
        return 1 + c3 * u * u * u + c1 * u * u
    }
    /// 0 before `rise`, up to 1 at `peak`, back to 0 by `fall`.
    static func bump(_ t: Double, _ rise: Double, _ peak: Double, _ fall: Double) -> Double {
        if t <= rise || t >= fall { return 0 }
        return t < peak ? smooth((t - rise) / (peak - rise)) : 1 - smooth((t - peak) / (fall - peak))
    }
    /// A damped spring let go from 1 at `t` = 0, settling to 0; 1 before.
    static func spring(_ t: Double, frequency: Double, damping: Double) -> Double {
        t <= 0 ? 1 : IllustrationMotion.spring(t, frequency: frequency, damping: damping)
    }
    /// The same spring pushed from rest: 0, out, back, settling to 0.
    static func springOut(_ t: Double, frequency: Double, damping: Double) -> Double {
        t <= 0 ? 0 : IllustrationMotion.springOut(t, frequency: frequency, damping: damping)
    }
    /// Eases between held values: `keys` are (seconds, value), in order.
    static func keys(_ t: Double, _ keys: [(Double, Double)]) -> Double {
        guard let first = keys.first else { return 0 }
        if t <= first.0 { return first.1 }
        for (a, b) in zip(keys, keys.dropFirst()) where t < b.0 {
            return a.1 + (b.1 - a.1) * smooth((t - a.0) / (b.0 - a.0))
        }
        return keys.last!.1
    }
}

extension CGAffineTransform {
    /// This, then `next`.
    func then(_ next: CGAffineTransform) -> CGAffineTransform { concatenating(next) }
}
