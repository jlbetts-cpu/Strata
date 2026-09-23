import SwiftUI

/// **What a win looks like as a card, whether or not it has a photograph.**
///
/// One view, because the folder's stack and the grid inside it were drawing
/// the same two cases separately and had already drifted: one kept a white
/// border after the other lost it, and one centred its title while the other
/// did too when it should not have.
///
/// **A win with a photograph is the photograph.** No title on it, per the
/// owner: "the titles shouldn't be on the cards with photos." A photograph of
/// the thing IS the label, and a caption over it is the app talking over the
/// person's own picture.
///
/// **A win without one is a made surface, not a swatch.**
///
/// The owner: "the coloured blocks should use the photo effect we were going
/// to do with Apollo, with the premium glass blur and simple coloured photo
/// behind it adding texture, and less of the playful vibrant colours which
/// don't fit Apollo's premium aesthetic."
///
/// So three layers rather than a fill. A **field**: two soft blooms of the
/// colour, off centre and heavily blurred, which is what gives it somewhere
/// to be lighter and darker instead of being one flat value. **Texture**: a
/// fine speckle, because the thing that separates a premium surface from a
/// rectangle of colour is that it is not perfectly smooth. And **glass** over
/// both, which pulls the whole thing back and is what stops a colour from
/// shouting.
///
/// The colour is muted on the way in rather than a second palette being
/// invented: the category's own hue, taken down in saturation and brightness.
/// The app's categories are deliberately bright where they are small marks on
/// a light page; at this size, on a dark ground, the same value is a poster.
struct WinCardFace: View {
    var win: ScatterWin
    var image: UIImage?
    /// Titles are hidden on the folder's stack, where a card is 40% of a
    /// small folder and a word would be a smudge.
    var showsTitle: Bool = true
    var corner: CGFloat = 16

    /// The category hue, at the saturation and brightness a large surface can
    /// carry. Measured against the palette rather than guessed: the app's own
    /// colours run around 0.7 saturation, which is right for a 20pt mark and
    /// loud across half a screen.
    /// The same colour, moved a little around the wheel. Wrapped rather than
    /// clamped: a hue is a circle, and clamping it would make red and purple
    /// drift one way only.
    static func shifted(_ colour: Color, by amount: Double) -> Color {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        UIColor(colour).getHue(&hue, saturation: &saturation,
                               brightness: &brightness, alpha: &alpha)
        let moved = (hue + CGFloat(amount)).truncatingRemainder(dividingBy: 1)
        return Color(hue: moved < 0 ? moved + 1 : moved,
                     saturation: saturation, brightness: brightness)
    }

    static func muted(_ colour: Color) -> Color {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        UIColor(colour).getHue(&hue, saturation: &saturation,
                               brightness: &brightness, alpha: &alpha)
        return Color(hue: hue,
                     saturation: min(saturation * 0.52, 0.42),
                     brightness: min(brightness * 0.78, 0.62))
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                colourField
                if showsTitle {
                    Text(win.title)
                        .font(Typography.bodySmall)
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .padding(corner * 0.85)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }

    /// **Every card of a colour was the same card.**
    ///
    /// The owner: "the coloured ones that don't have a photo, they should
    /// have a clean blurry glass effect too, and there should be an actual
    /// like Unsplash image behind it in that colour, so it's kinda just doing
    /// the colours, each coloured block looking semi unique."
    ///
    /// **Not an Unsplash image, and here is the honest reason.** Real stock
    /// photographs mean either a network fetch at the moment somebody logs a
    /// win — which is the one moment this app is offline-first about — or a
    /// pack bundled into the binary, which is a licence to read and a couple
    /// of megabytes for something nobody chose. Both buy less than they
    /// cost, because what he is actually describing is *variation*: two
    /// "Deep work" wins that do not look like the same rectangle twice.
    ///
    /// So the field is generated per win instead. Four blooms rather than
    /// two, their positions, sizes, hue drift and light-or-dark all drawn
    /// from a hash of the win's own id: the same win is the same surface on
    /// every launch and on every device, and no two wins are alike. It ships
    /// as nothing, it is unique forever rather than one of forty, and it is
    /// fills rather than images, so a scroll full of them is fills rather
    /// than decodes. If he wants real photographs behind these later, the
    /// right source is his own camera roll, not a stock library.
    ///
    /// **Hue drift, not hue change.** Each bloom moves at most 0.035 around
    /// the wheel, which is the difference between a surface catching light
    /// from two directions and a card with two colours on it.
    private var colourField: some View {
        let base = Self.muted(win.colour)
        var rng = WinCardSeed(win.id)
        let blooms = (0..<4).map { index in
            Bloom(dx: rng.signed() * 0.34,
                  dy: rng.signed() * 0.34,
                  scale: 0.72 + rng.unit() * 0.62,
                  drift: rng.signed() * 0.035,
                  // Two lighter and two darker whatever the draw, so a card
                  // can never come up flat or blown out. Which two is what
                  // the seed decides.
                  lifts: index % 2 == 0)
        }
        return ZStack {
            base
            GeometryReader { geo in
                let side = max(geo.size.width, geo.size.height)
                ZStack {
                    ForEach(Array(blooms.enumerated()), id: \.offset) { _, bloom in
                        Circle()
                            .fill(bloom.lifts
                                  ? Self.shifted(base, by: bloom.drift).opacity(0.9)
                                  : Color.black.opacity(0.42))
                            .frame(width: side * bloom.scale)
                            .offset(x: side * bloom.dx, y: side * bloom.dy)
                            .blendMode(bloom.lifts ? .screen : .multiply)
                    }
                }
                .blur(radius: side * 0.22)
            }
            // The speckle. Cheap, static, and the reason it reads as a
            // surface rather than as a gradient.
            Rectangle()
                .fill(.white.opacity(0.05))
                .blendMode(.overlay)
                .overlay { WinCardGrain().opacity(0.10).blendMode(.overlay) }
            // And glass over all of it, which is what pulls the colour back.
            Rectangle().fill(.ultraThinMaterial).opacity(0.28)
        }
        .compositingGroup()
    }
}

/// One bloom of the generated field. See `WinCardFace.colourField`.
private struct Bloom {
    var dx: CGFloat
    var dy: CGFloat
    var scale: CGFloat
    var drift: Double
    var lifts: Bool
}

/// **A stable sequence from a win's id.**
///
/// Not `hashValue`, which Swift seeds per process, so the same win would be
/// a different surface after every launch. FNV-1a to start it and xorshift to
/// walk it, which is the same pair `ScatterLayout` uses and for the same
/// reason.
private struct WinCardSeed {
    private var state: UInt64

    init(_ text: String) {
        var h: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            h ^= UInt64(byte)
            h = h &* 0x100000001b3
        }
        // xorshift is a fixed point at zero, and an empty id hashes to a
        // constant, so a guard here is cheaper than a card that comes out
        // identical for every untitled win.
        state = h == 0 ? 0x9E3779B97F4A7C15 : h
    }

    mutating func unit() -> CGFloat {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return CGFloat(state % 10_000) / 10_000
    }

    /// Centred on zero, so an offset is as likely to go left as right.
    mutating func signed() -> CGFloat { unit() * 2 - 1 }
}

/// A fine, still speckle. Drawn once into a `Canvas` rather than generated
/// per frame: this sits behind a scroll and anything per-frame here is the
/// scroll's problem.
private struct WinCardGrain: View {
    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 0x9E3779B97F4A7C15
            func next() -> Double {
                seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
                return Double(seed % 1000) / 1000
            }
            let count = Int(size.width * size.height / 260)
            for _ in 0..<max(count, 40) {
                let x = next() * size.width
                let y = next() * size.height
                let bright = next()
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: 1.4, height: 1.4)),
                    with: .color(.white.opacity(bright > 0.5 ? 0.5 : 0.14)))
            }
        }
        .allowsHitTesting(false)
    }
}
