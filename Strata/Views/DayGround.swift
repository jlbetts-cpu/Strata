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
struct DayGround: View {

    /// Kept from when the field borrowed the day's hue. Unused; both go once
    /// this settles.
    let colours: [Color]
    let fill: Double

    /// Up to `maxPhotos` file names from today's blocks, biggest block first.
    /// Empty is the normal case early in a day and draws the sky alone.
    var photos: [String] = []

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
            if reduceTransparency {
                WarmBackground()
            } else {
                scene
                photographs
                WarmBackground.top.opacity(Self.veil)
                // **THE GROUND IS SEATED BELOW WHITE, AND THAT IS WHAT MAKES
                // THE TRANSPARENCY VISIBLE.**
                //
                // The owner, 2026-09-30: "I like our light direction though. I
                // just want the transparency and cleanness to be more clear."
                //
                // You can only SEE that something is transparent if there is a
                // difference between where the sheet is and where it is not. The
                // page had drifted to 236-241 everywhere, so a white pane at 62%
                // landed 2 to 4 levels above the gap beside it and nothing read
                // as see-through -- which is also the headroom wall that had me
                // drawing a hairline round every cell.
                //
                // His own reference board is built on this: pin after pin sits
                // on a light neutral grey and lets white elements float above
                // it. A few levels of ground is what buys every translucent
                // thing on the page its legibility, and it costs the light
                // nothing -- the sky, the sun and the grain are all still there,
                // simply seated rather than blown out.
                Color.black.opacity(Self.seat)
                grain
            }
        }
        .ignoresSafeArea()
        .task(id: photos.prefix(Self.maxPhotos).joined()) { await load() }
    }

    /// The day, at forty pixels.
    ///
    /// Each picture takes a third of the width and the full height, so the page
    /// reads left to right as the day did. `.interpolation(.high)` on a 40px
    /// source blown up this far is what makes it a smooth field rather than
    /// visible squares — the one place in the app where the expensive
    /// interpolation is the cheap answer.
    @ViewBuilder
    private var photographs: some View {
        if !loaded.isEmpty {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(Array(loaded.enumerated()), id: \.offset) { _, image in
                        Image(uiImage: image)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width / CGFloat(loaded.count),
                                   height: geo.size.height)
                            .clipped()
                    }
                }
                // The seams between three rectangles would be three vertical
                // lines down the page. A single soft blur over the whole strip
                // is one pass on an image that is already tiny, and it is the
                // only blur here.
                // **18 over a 40px decode.** At 60 the sum of the two was a flat
                // colour;
                // stacking a 60pt pass on top averaged all three pictures into a
                // single flat colour, which is the exact opposite of the reason
                // they are here. Measured, the page had 7 to 14 levels of spread
                // across its whole width -- less texture than the mesh it was
                // supposed to be adding texture to. This is only enough to hide
                // the two seams where the three pictures meet.
                .blur(radius: 18)
                .opacity(Self.photoStrength)
            }
        }
    }

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
    static let seat: Double = 0.055

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

    private func load() async {
        let wanted = Array(photos.prefix(Self.maxPhotos))
        guard !wanted.isEmpty else { loaded = []; return }
        var out: [UIImage] = []
        for name in wanted {
            // `.prefetch` lane, not `.visible`: this is scenery, and must
            // never take a decode slot from a block somebody is looking at.
            if let image = await ImageManager.shared.loadThumbnail(
                fileName: name, maxWidth: Self.photoPixels, lane: .prefetch,
                countsAsForeground: false) {
                out.append(image)
            }
        }
        loaded = out
    }

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
        white(0.968, 0.58), white(0.972, 0.58), white(0.964, 0.58),
        white(0.976, 0.58), white(0.992, 0.12), white(0.970, 0.58),
        white(0.958, 0.08), white(0.966, 0.08), white(0.954, 0.08),
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
    private static func white(_ brightness: Double, _ hue: Double) -> Color {
        Color(hue: hue, saturation: 0.03, brightness: brightness)
    }

}
