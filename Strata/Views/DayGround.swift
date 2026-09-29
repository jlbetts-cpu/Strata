import SwiftUI

/// **The ground takes its colour from the day you actually had.**
///
/// The owner, 2026-09-29: "I think the design would look a lot stronger with
/// more light refraction, more transparency, glass UI letting more colour seep
/// through rather than just be flat... that slight colour and texture seeping
/// through the background... brings more layers to the design that weren't
/// previously there."
///
/// **It is the fix for a contradiction already written down in this codebase.**
/// `GlassIconButton.swift` says, correctly, that on a plain warm page glass "has
/// nothing to refract, so it renders as a grey box pretending to be a material,
/// which looks cheaper than a clean flat control would" — and concluded that the
/// answer was to use less glass. The answer is the other one: give the glass
/// something to refract. Every glass surface in the app has been floating over a
/// flat fill, which is why none of them have earned their keep away from the
/// camera.
///
/// **It is also already permitted.** `docs/design-system-future.md` §4: "A tint
/// is only ever borrowed from content: a block's category colour, a day's colour,
/// the photograph. Never a brand accent painted onto chrome." That sentence
/// authorises exactly this, and until now nothing in the app used it — the ground
/// borrowed nothing and was the same warm white on every day of your life.
///
/// So there is no brand gradient here and there is not going to be one. Luma
/// needs one because it has no content of its own to light the page with; this
/// app has a wall of the person's own colours and photographs, which is a better
/// light source than any magenta anybody could choose. A green day and a red day
/// do not look the same any more, and nobody picked either colour.
///
/// **The three guards, because §4 also says "no glow, no neon, no colour used to
/// mean futuristic":**
///
/// 1. `ceiling` is the most alpha any one wash may carry. It is deliberately
///    low. The test is that you should not be able to name the colour with the
///    tower covered up — you should only notice when it is gone.
/// 2. The wash is anchored where the blocks are and fades out upward, so the
///    colour is where the light would actually come from rather than an
///    all-over tint somebody chose.
/// 3. At most `maxStops` colours, taken by how much of the tower each covers.
///    A day with six categories in it is not six washes; it is the two that
///    dominate, or the page turns grey from mixing.
struct DayGround: View {

    /// The day's colours, most-covered first, already deduplicated.
    let colours: [Color]

    /// 0 when the tower is empty, 1 when it fills the frame. The wash comes up
    /// with the tower rather than sitting at full strength over one block: on a
    /// day with a single win the page should be almost as quiet as an empty one.
    let fill: Double

    /// **The most alpha a single wash may carry**, before `fill` scales it.
    ///
    /// Measured against the thing it has to beat: the empty lattice is black at
    /// 2% over a 245 ground, which reads as three levels out of 255 and is why
    /// the page looks bare. This is the same order of magnitude deliberately —
    /// it is atmosphere, not a surface. Raise it and read §4's "no glow" line
    /// again before deciding it was too low.
    static let ceiling: Double = 0.14

    /// Two, not six. See the note above.
    static let maxStops = 2

    /// Reduced transparency means somebody has asked the system for less of
    /// exactly this. The wash is the first thing to go.
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            WarmBackground()
            if !reduceTransparency {
                ForEach(Array(stops.enumerated()), id: \.offset) { i, colour in
                    wash(colour, index: i)
                }
            }
        }
        .ignoresSafeArea()
    }

    private var stops: [Color] { Array(colours.prefix(Self.maxStops)) }

    /// One colour, poured from where the tower stands and thinning upward.
    ///
    /// A radial gradient rather than a linear one because a linear wash reads as
    /// a band across the page — the thing `WarmBackground` already records
    /// removing once, for being "too shallow to read as a gradient and deep
    /// enough to read as a seam".
    private func wash(_ colour: Color, index: Int) -> some View {
        // The second colour sits off to the other side, so two washes read as
        // light from two places rather than one muddier colour in the middle.
        // Both sit just inside the bottom edge rather than below it: centred off
        // screen, most of the radius was spent outside the page and the measured
        // shift on the left half was zero.
        let centre: UnitPoint = index == 0 ? .init(x: 0.12, y: 0.88)
                                           : .init(x: 0.92, y: 0.72)
        return RadialGradient(
            colors: [colour.opacity(Self.ceiling * fill), colour.opacity(0)],
            center: centre, startRadius: 0, endRadius: 640
        )
        // **PLAIN SOURCE-OVER, NOT `.plusLighter`.**
        //
        // The first cut used plusLighter, which was measured and was wrong: on a
        // ground at 245 it can only push toward white, so a green wash came out
        // as a paler white rather than a greener page. Largest shift anywhere on
        // the screen was 8 levels, and on the whole left half it was zero.
        // Lighten blends belong on a dark ground; this app's is nearly white.
        .allowsHitTesting(false)
    }
}
