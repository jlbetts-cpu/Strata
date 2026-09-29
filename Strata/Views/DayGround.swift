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

    /// **A lift of plain light under everything**, so the page has somewhere
    /// bright for the colour to sit on.
    ///
    /// Airiness is not a colour, it is a luminance gradient: without this the two
    /// hues sit on a uniform ground and read as two stains. With it the bottom of
    /// the page is lit and the top falls away, which is what a room with a lamp
    /// in it does, and the colour becomes the tint of that light rather than the
    /// whole of it.
    /// **The cool fall-off above**, which is what actually makes it read as air.
    ///
    /// Composited six candidates over a real screenshot and looked at them
    /// together rather than rebuilding blind. The warm-wash-alone versions all
    /// read as a stain on a page. The one that read as a LIT ROOM had the day's
    /// warmth low down and a cool neutral falling away above it, because that is
    /// what light in a room does and a single tint is not.
    ///
    /// It is a hue rather than white for the reason white failed: on a ground
    /// already at 245 there is no headroom to add brightness, so "more light"
    /// has to be carried by colour temperature instead of by luminance. Blue,
    /// unsaturated, no content behind it -- this one is not borrowed from
    /// anything, and it is the single exception to §4 in the app. It is allowed
    /// because it is not a brand accent and carries no meaning: it is the colour
    /// of the sky end of a room, and at 10% of a 16%-saturation blue it cannot
    /// be named on sight.
    static let coolLift: Double = 0.10

    /// The cool end's hue and saturation. Deliberately barely a colour.
    static let coolHue: Double = 0.58
    static let coolSaturation: Double = 0.16

    /// **The most alpha a single wash may carry**, before `fill` scales it.
    ///
    /// Measured against the thing it has to beat: the empty lattice is black at
    /// 2% over a 245 ground, which reads as three levels out of 255 and is why
    /// the page looks bare. This is the same order of magnitude deliberately —
    /// it is atmosphere, not a surface.
    ///
    /// **It was 0.14 while the wash was raw pigment and is 0.55 now that it is
    /// light.** That is not a loosening: `asLight` takes the colour to about 20%
    /// saturation before this is applied, so the ink actually reaching the page
    /// is far less than it was at 0.14 with a full-strength hue. Read §4's "no
    /// glow" line before moving it again, and judge it by the measured level
    /// shift rather than by this number.
    static let ceiling: Double = 0.12

    /// **ONE, and two was measured and was wrong.**
    ///
    /// Two stops looked reasonable on a day of reds and purples and fell apart on
    /// a day of red and green: near-complementary hues average, so the page went
    /// grey-green and murky -- the owner's word for the result was that it wasn't
    /// airy, and he was right. Light in a room comes from one direction. A second
    /// hue is not more atmosphere, it is a mixture, and a mixture of two colours
    /// on a near-white page is grey every time.
    static let maxStops = 1

    /// Reduced transparency means somebody has asked the system for less of
    /// exactly this. The wash is the first thing to go.
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            WarmBackground()
            if !reduceTransparency {
                // The day's own colour, low, where the tower stands.
                ForEach(Array(stops.enumerated()), id: \.offset) { i, colour in
                    wash(colour, index: i)
                }
                // And the cool end above it. Not scaled by `fill`: the room is
                // the room whether or not anything has happened in it yet, and
                // an empty tower should still sit on a page with air in it.
                RadialGradient(
                    colors: [Color(hue: Self.coolHue, saturation: Self.coolSaturation,
                                   brightness: 0.99).opacity(Self.coolLift),
                             .clear],
                    center: .init(x: 0.5, y: 0.04), startRadius: 0, endRadius: 900)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }

    private var stops: [Color] { Array(colours.prefix(Self.maxStops)).map(Self.asLight) }

    /// **The block's colour as LIGHT, not as paint.**
    ///
    /// The owner, 2026-09-29: "I want the light to not just be like red, it
    /// should have some nice lightness and airiness to it."
    ///
    /// He is describing a real error. The first version laid the category colour
    /// straight onto the page, and source-over of a mid-saturation colour on a
    /// ground at 245 can only ever DARKEN it -- so a red day came out as a page
    /// someone had painted red, which is the opposite of light falling on it.
    ///
    /// What is actually happening physically is a bounce: light off a coloured
    /// surface onto a near-white one. That is bright and barely saturated, and it
    /// keeps only the HUE of what it came from. So the colour is pulled most of
    /// the way to white and its saturation cut to a fifth, which leaves the hue
    /// and takes away the pigment. A green day and a red day still do not look
    /// alike; neither of them looks painted.
    private static func asLight(_ c: Color) -> Color {
        var h: CGFloat = 0, sat: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(c).getHue(&h, saturation: &sat, brightness: &b, alpha: &a)
        return Color(hue: h, saturation: min(sat * 0.2, 0.22),
                     brightness: min(1, max(b, 0.97)))
    }

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
        // One source, centred under the tower, because that is where the
        // colour in the room actually is.
        let centre: UnitPoint = index == 0 ? .init(x: 0.5, y: 0.92)
                                           : .init(x: 0.92, y: 0.72)
        return RadialGradient(
            colors: [colour.opacity(Self.ceiling * fill), colour.opacity(0)],
            center: centre, startRadius: 0, endRadius: 900
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
