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

    private var colourField: some View {
        let base = Self.muted(win.colour)
        return ZStack {
            base
            // Two blooms, off centre, so the surface has a light side.
            GeometryReader { geo in
                let side = max(geo.size.width, geo.size.height)
                ZStack {
                    Circle()
                        .fill(base.opacity(0.9))
                        .frame(width: side * 1.1)
                        .offset(x: -side * 0.22, y: -side * 0.28)
                        .blendMode(.screen)
                    Circle()
                        .fill(Color.black.opacity(0.45))
                        .frame(width: side * 0.9)
                        .offset(x: side * 0.3, y: side * 0.34)
                        .blendMode(.multiply)
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
