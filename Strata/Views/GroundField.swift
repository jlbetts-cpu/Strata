import SwiftUI

/// **A sheet with light behind it, and no colour in it.**
///
/// The owner wanted "a subtle grassy field on a sunny day behind it... like it's
/// a sheet put up to the sky", and then asked for the research rather than more
/// guessing. The research is what produced the version this is:
///
/// **A backdrop blur has nothing to do to a smooth gradient.** `.ultraThinMaterial`
/// on the lattice is the correct primitive by Apple's own description — the
/// material "adapts to the content underneath" — and it was built, photographed,
/// and made the cells nearly vanish. Blur a smooth mesh and you get the same
/// smooth mesh. Every translucent surface in this app was failing to look like
/// glass for one reason: **there was no detail behind it to bend.**
///
/// So the backdrop has detail now, and the only honest detail this app owns is
/// **the person's own photographs.** They go behind the tower at a size where
/// nothing is recognisable — just their colour and their variation — which is
/// both the texture glass needs and, for an app whose whole claim is "a camera
/// for the things that went right", the correct thing to be standing on.
///
/// ```
///   sky mesh              ← the room, when there are no photographs yet
///   photographs           ← the day, at 40px, blown up: colour and variation
///   veil                  ← the sheet
/// ```
///
/// **The blur is free and that is not a trick, it is the trick.** A photograph
/// decoded at 40 pixels wide and drawn across a third of the screen IS a blur:
/// the detail is gone before it is ever rasterised. No blur pass, no filter, no
/// frame cost — and a 40px decode is smaller than the icons in the tab bar.
/// `.blur()` over three full photographs would have been the expensive way to
/// arrive at a worse picture.
struct GroundField: View {


    /// **Three.** One photograph is a wash and reads as a mistake; six average
    /// into mud, which is the same lesson the two-hue version learned. Three
    /// across the page is a day, and the eye cannot count them at this size.
    static let maxPhotos = 3

    /// **The width the photographs are decoded at, in pixels.** This is the blur
    /// radius in disguise, and it is the number that decides whether this is
    /// texture or just a colour cast.
    ///
    /// It was 40 and that was measured as too few: three 40px pictures stretched
    /// across a third of the screen each are three smooth blobs, and the page
    /// came out with 6 to 9 levels of spread across its whole width. Colour, no
    /// structure — which is the one thing they were added for, since a material
    /// or a lens has nothing to bend without it.
    ///
    /// **120 was then tried, with the blur raised to match, and measured NO
    /// BETTER: 9/5/4 levels against 9/6.** More pixels and more blur cancel, and
    /// that is the finding rather than a number to keep tuning.
    ///
    /// **Any blur strong enough to make a photograph unrecognisable is strong
    /// enough to remove its structure.** So blurred photographs cannot be both
    /// anonymous and textured, and the original hope for them -- give a material
    /// or a lens something real to bend -- is not reachable this way. What they
    /// DO give, and what they are kept for, is honest colour: a page tinted by
    /// the actual pictures of your day rather than by a palette someone chose.
    /// 40 is back because it measured the same as 120 and decodes less.
    static let photoPixels: CGFloat = 40

    /// **How much cloth is between you and all of it — and it sets the page's
    /// brightness, which is what makes the lattice readable.**
    ///
    /// At 0.82 the whole page sat at 240 and the cells vanished into it: a white
    /// pane has nothing left to give on a ground that bright, and the fix I
    /// reached for first was to outline them, which the owner rejected on sight
    /// and was right to. A drawn line is not light.
    ///
    /// So this carries it instead. The ground sits lower, the panes are the
    /// brightest thing on the page, and the lattice is readable with nothing
    /// drawn around it — which is what a sheet lit from behind looks like.
    static let veil: Double = 0.70

    /// **How present the photographs are, and 0.75 was measured and was far too
    /// much.** At that strength three pictures took the whole page mint green and
    /// the sky vanished: they stopped being texture behind a scene and became the
    /// scene. They are here to give the surface VARIATION for glass to bend, not
    /// to colour it.
    static let photoStrength: Double = 0.0

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var scheme

    /// Loaded once, off the main actor, and held. Never reloaded on scroll.
    @State private var loaded: [UIImage] = []

    var body: some View {
        ZStack {
            scene
            Color.black.opacity(Self.seat)
            grain
        }
        .ignoresSafeArea()
    }

    // **THE PHOTOGRAPH BACKDROP IS GONE FROM HERE**, and the reasoning it
    // carried is in `docs/reference-board.md` and in the commit that removed it:
    // any blur strong enough to make a photograph anonymous is strong enough to
    // remove its structure, so it gave colour and never texture. It was already
    // switched off; leaving a dead loader running on every screen in the app is
    // a worse thing than losing the note.

    /// **Grain, which is where the texture actually comes from.**
    ///
    /// The owner asked for "more texture" in the same breath as "more subtle",
    /// and those only sound contradictory. Colour cannot supply texture here —
    /// anything strong enough to have visible structure is strong enough to
    /// compete with the blocks, and the photograph experiment proved the same
    /// thing from the other side: any blur that makes a picture anonymous also
    /// makes it smooth.
    ///
    /// Grain has no such problem. It is texture with no colour and no shape, so
    /// it reads as the surface being MADE of something — paper, cloth, film —
    /// without adding a single thing for a block to argue with. It is also what
    /// separates a printed page from a computed gradient, which is most of the
    /// difference between "expensive" and "flat" on a near-white screen.
    ///
    /// One 128px image, generated once, tiled. No shader, no filter, no per
    /// frame cost.
    private var grain: some View {
        Image(uiImage: Self.noise)
            .resizable(resizingMode: .tile)
            .opacity(Self.grainStrength)
            .blendMode(.overlay)
            .allowsHitTesting(false)
            .ignoresSafeArea()
    }

    /// **Low enough to deny on sight.** You should not be able to point at it;
    /// you should only notice the page looks flat when it is gone.
    static let grainStrength: Double = 0.055

    /// **How far below white the page sits.** The one number that decides
    /// whether anything on this page reads as translucent. Too little and the
    /// panes vanish into the ground; too much and the "light" direction he likes
    /// turns into a grey app.
    /// **0.030, because the page is clean white now.** This was 0.055, chosen
    /// when the ground was a lower, warmer thing and the lattice needed
    /// headroom to be a brighter pane than it. On a clean white page that much
    /// ink is what turns "white" back into "grey" — the exact word the owner
    /// used about the version before the warm one. The lattice keeps enough:
    /// measured, a pane still reads above the ground it sits on, and he has
    /// already asked twice for it to be the quieter of the two.
    static let seat: Double = 0.030

    /// A 128px tile of monochrome noise, built once and shared.
    ///
    /// Deterministic rather than random: a tile that changed between launches
    /// would be a different surface every time the app opened, and nothing else
    /// in this app redecorates itself behind the owner's back.
    private static let noise: UIImage = {
        let side = 128
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        var seed: UInt64 = 0x5EED_1234_ABCD_0001
        for i in 0..<(side * side) {
            // xorshift: cheap, deterministic, and good enough for grain.
            seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
            let v = UInt8(truncatingIfNeeded: seed >> 24)
            let j = i * 4
            bytes[j] = v; bytes[j + 1] = v; bytes[j + 2] = v; bytes[j + 3] = 255
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        let cg = CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 32,
                         bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                         bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                         provider: provider, decode: nil, shouldInterpolate: false,
                         intent: .defaultIntent)!
        return UIImage(cgImage: cg)
    }()

    /// The room, and what shows when there are no photographs: sky, sun, light.
    private var scene: some View {
        MeshGradient(width: 3, height: 3,
                     points: Self.points,
                     colors: scheme == .dark ? Self.night : Self.day,
                     smoothsColors: true)
    }

    private static let points: [SIMD2<Float>] = [
        .init(0.0, 0.0),  .init(0.5, 0.0),   .init(1.0, 0.0),
        .init(0.0, 0.30), .init(0.68, 0.22), .init(1.0, 0.27),
        .init(0.0, 1.0),  .init(0.5, 0.94),  .init(1.0, 1.0),
    ]

    private static let day: [Color] = [
        // **Halved, because the blocks have to sit ON this.** The owner:
        // "it looks way too strong, it should be more subtle, more light, more
        // texture, being able to fit the coloured blocks and photos on top of
        // it." A backdrop that a 2x2 red block has to compete with is not a
        // backdrop.
        // **NO COLOUR.** The owner, 2026-09-30: "I like the white light
        // ethereal vibe right now, I don't think I like all the colour."
        //
        // So the scene keeps its STRUCTURE and loses its hue. These are nine
        // near-whites a few levels apart, with the barest temperature to them --
        // a touch cool along the top, a touch warm at the foot -- which is what
        // stops a field of one colour reading as a flat fill. The light and the
        // depth survive; the sky and the sun do not.
        // **NO TEMPERATURE AT ALL, AND THAT IS THE THIRD AND LAST ANSWER.**
        //
        // This was cool at the top and warm at the foot, on the reasoning that
        // a sheet held up to the sky is. Measured, that put the coolest part of
        // the page exactly where the header's buttons sit and the owner saw it
        // ("the background is greyish"). It was then taken all-warm, and his
        // verdict on that is the one that settles it: "I don't like this warm
        // style, I liked it more when it was premium clean. The clean white
        // fits the brand so much more."
        //
        // He is right, and the reason is in the design doc rather than in
        // taste. The blocks and the photographs carry every colour in this app
        // (§4). A ground with a hue of its own is a ground the content has to
        // argue with — and the illustrations coming next are the case that
        // breaks it, because an illustration on a beige page is an illustration
        // with a beige background.
        //
        // **The structure survives; only the hue goes.** These are still nine
        // near-whites a few levels apart, so the field still has its light and
        // its depth and does not read as a flat fill. They are simply neutral,
        // and they sit high: clean white, a touch of shading toward the foot.
        white(0.998, 0), white(1.000, 0), white(0.996, 0),
        white(0.994, 0), white(0.999, 0), white(0.991, 0),
        white(0.974, 0), white(0.980, 0), white(0.970, 0),
    ]

    private static let night: [Color] = [
        Color(hue: 0.60, saturation: 0.45, brightness: 0.30),
        Color(hue: 0.60, saturation: 0.40, brightness: 0.34),
        Color(hue: 0.60, saturation: 0.48, brightness: 0.28),
        Color(hue: 0.60, saturation: 0.38, brightness: 0.26),
        Color(hue: 0.11, saturation: 0.30, brightness: 0.34),
        Color(hue: 0.60, saturation: 0.42, brightness: 0.24),
        Color(hue: 0.60, saturation: 0.35, brightness: 0.18),
        Color(hue: 0.60, saturation: 0.30, brightness: 0.20),
        Color(hue: 0.60, saturation: 0.38, brightness: 0.16),
    ]

    /// A near-white at a given brightness, carrying only enough hue to have a
    /// temperature. 3% saturation is under the threshold at which anybody can
    /// name a colour; it is the difference between "white" and "dead white".
    /// A neutral near-white at a given brightness.
    ///
    /// **`hue` is kept and `saturation` is now zero**, deliberately rather than
    /// by deleting the parameter: the hue was the thing that went wrong twice,
    /// and a signature that still asks for one is a reminder that it was tried
    /// in both directions and the answer was neither. Night keeps its own
    /// colours; it is a night sky, not a page.
    private static func white(_ brightness: Double, _ hue: Double) -> Color {
        Color(hue: hue, saturation: 0, brightness: brightness)
    }

}
