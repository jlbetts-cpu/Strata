import SwiftUI
import UIKit

/// The ground every page stands on.
///
/// **It is no longer warm, and the name is kept anyway** — renaming a type
/// used on twelve screens to say the same thing in a different word is churn,
/// and this comment is where the truth lives.
///
/// It was a warm off-white (250,249,246 → 249,247,244). Rendered against the
/// full block palette on six candidate grounds and looked at side by side, the
/// warmth was the problem: it is a yellow cast, and half the blocks are cool —
/// blue, purple, green — so the ground and the object on it pulled in opposite
/// directions and the pastels read as printed rather than lit.
///
/// Measured first, and the measurement said it did not matter: CIELAB
/// separation from the six block colours varied by barely two units across all
/// six candidates (53.3 to 55.0). Contrast was never the question. What
/// changes is the cast, and that is a thing to look at rather than compute.
///
/// This is the faintest possible cool lift — a blue-grey a couple of units off
/// neutral, nowhere near enough to read as "blue", but enough that the colours
/// on top of it look like they are catching light. The blocks are the app;
/// the ground's only job is to make them look clean and then disappear.
struct WarmBackground: View {

    /// The ground's colour at the top of the screen.
    ///
    /// Named because more than one thing needs it now: anything that fades
    /// INTO the page — a header's wash, a scroll edge — has to start from
    /// exactly this and not from a second copy of it typed nearby. A wash that
    /// is one shade off the ground it sits on draws a band you cannot quite
    /// see and cannot stop seeing.
    /// **Dynamic**, so every consumer adapts without knowing it did.
    ///
    /// Making these two adaptive is what gives the whole app dark mode: the
    /// page, the drawer, the pinned headings, the badge on a map block and
    /// every scroll-edge wash all fade into one of these, so they follow the
    /// system together or not at all.
    ///
    /// The dark values are a warm charcoal, not black. `AppColors.warmBlack`
    /// is 0x403D39 — the app's black has always had brown in it — and the
    /// ground goes a little under it so a block still reads as lit FROM
    /// somewhere. Pure black would be the ethereal thing this app is going
    /// for turning into a void: there would be no ground for a block to stand
    /// on, only an absence behind it.
    static let top = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.129, green: 0.125, blue: 0.118, alpha: 1)
            : UIColor(red: 0.965, green: 0.970, blue: 0.978, alpha: 1)
    })
    /// And at the bottom. The gradient runs the same direction in both: the
    /// light ground gets very slightly cooler and darker downwards, the dark
    /// ground very slightly deeper, so "lit from above" survives the flip.
    static let bottom = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.094, green: 0.090, blue: 0.086, alpha: 1)
            : UIColor(red: 0.947, green: 0.955, blue: 0.965, alpha: 1)
    })

    /// Stage light: a soft pool of light behind the tower and a falloff to
    /// the edges. Only the page grounds pass `true` (Wins, the Memories
    /// drawer, Profile). Sheets and forms stay flat, because a vignette
    /// behind form rows makes the rows at the edges look greyer than the rows
    /// in the middle.
    ///
    /// **Static.** Three gradients sized off the page, no timeline, no
    /// `Canvas`. The page's size does not change on scroll or on a drop, so
    /// nothing here redraws after the first frame.
    ///
    /// **The top 12% is exactly `top`.** Header washes and scroll edges fade
    /// into `top`; a darker corner under one would draw a band. The base holds
    /// `top` to 12% and both lit layers are masked off it, ramping in over
    /// the next 24% (a 14% ramp left a visible shoulder at the side edges).
    ///
    /// Tokens and geometry are the research mock's (`ground-shots/scripts/
    /// final.py` renders exactly this), with the light pool and vignette made
    /// about twice as strong: at the mock's strength light mode was almost
    /// invisible. Measured over the real screenshots: light L* 84 to 100,
    /// dark 2.7 to 21.6, and chroma at most 2.6, so it adds light, not colour.
    var lit: Bool = false

    /// Written out: the private environment reads below would make the
    /// synthesised memberwise initialiser private.
    init(lit: Bool = false) {
        self.lit = lit
    }

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        if lit && contrast != .increased {
            litGround
        } else {
            flat
        }
    }

    private var flat: some View {
        LinearGradient(
            stops: [
                .init(color: Self.top, location: 0.0),
                .init(color: Self.bottom, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .accessibilityHidden(true)
    }

    // MARK: - Stage light

    private static let topHold: CGFloat = 0.12
    private static let ramp: CGFloat = 0.24

    private static let poolColor = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 56 / 255, green: 54 / 255, blue: 51 / 255, alpha: 1)
            : UIColor(red: 1, green: 1, blue: 1, alpha: 1)
    })
    private static let edgeColor = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 8 / 255, green: 8 / 255, blue: 7 / 255, alpha: 1)
            : UIColor(red: 203 / 255, green: 205 / 255, blue: 210 / 255, alpha: 1)
    })

    @Environment(\.colorScheme) private var scheme

    private var litGround: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let dark = scheme == .dark
            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: Self.top, location: 0.0),
                        .init(color: Self.top, location: Self.topHold),
                        .init(color: Self.bottom, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                // The pool: 1 - smoothstep(d) over an ellipse 0.912W by
                // 0.553H, centred 44% down.
                Self.ellipse(
                    stops: Self.poolStops(alpha: dark ? 0.90 : 1.0),
                    rx: 0.912 * w, ry: 0.553 * h,
                    center: CGPoint(x: w / 2, y: 0.44 * h)
                )
                .mask { Self.topMask }
                // The vignette: smoothstep from d 0.55 to 1.25 over an
                // ellipse 0.62W by 0.60H, centred 48% down.
                Self.ellipse(
                    stops: Self.vignetteStops,
                    rx: 1.25 * 0.62 * w, ry: 1.25 * 0.60 * h,
                    center: CGPoint(x: w / 2, y: 0.48 * h)
                )
                .mask { Self.topMask }
            }
            .frame(width: w, height: h)
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Clear over the top 12%, then a smoothstep to opaque over 24%.
    private static var topMask: some View {
        LinearGradient(
            stops: (0...8).map { i in
                let t = CGFloat(i) / 8
                return .init(color: .black.opacity(smooth(t)), location: topHold + ramp * t)
            },
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// A radial gradient in a circle of radius `rx`, squashed to `ry`. Exact,
    /// where `EllipticalGradient`'s radius fraction would be a guess.
    private static func ellipse(stops: [Gradient.Stop], rx: CGFloat, ry: CGFloat,
                                center: CGPoint) -> some View {
        Rectangle()
            .fill(RadialGradient(stops: stops, center: .center, startRadius: 0, endRadius: rx))
            .frame(width: 2 * rx, height: 2 * rx)
            .scaleEffect(x: 1, y: ry / rx)
            .position(center)
    }

    private static func poolStops(alpha: Double) -> [Gradient.Stop] {
        stops(color: poolColor, alpha: alpha, span: 1) { d in 1 - smooth(d) }
    }

    private static let vignetteStops: [Gradient.Stop] =
        stops(color: edgeColor, alpha: 0.90, span: 1.25) { d in smooth((d - 0.55) / 0.70) }

    /// Samples an alpha curve `f(d)` for d in 0...span as gradient stops.
    /// Sixteen stops keep the piecewise-linear curve within 1% of smoothstep.
    private static func stops(color: Color, alpha: Double, span: CGFloat,
                              _ f: (CGFloat) -> CGFloat) -> [Gradient.Stop] {
        (0...16).map { i in
            let d = span * CGFloat(i) / 16
            return .init(color: color.opacity(alpha * Double(f(d))), location: CGFloat(i) / 16)
        }
    }

    private static func smooth(_ x: CGFloat) -> CGFloat {
        let v = min(max(x, 0), 1)
        return v * v * (3 - 2 * v)
    }
}
