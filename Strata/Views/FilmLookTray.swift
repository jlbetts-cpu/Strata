import SwiftUI
import UIKit

/// Where the tray's swatches get their picture.
///
/// **This is the seam for the live path, and it is why it is a type rather
/// than a parameter.** Today a swatch cannot show the scene in front of the
/// lens: the viewfinder is an `AVCaptureVideoPreviewLayer`, and Apple states
/// plainly that its frames go straight from the capture session with no
/// opportunity for an app to touch them. When the preview becomes an `MTKView`
/// fed by `AVCaptureVideoDataOutput`, the frame it is already rendering
/// becomes the source and `.live` is the only case that has to arrive.
/// Nothing about this control's layout changes.
enum FilmLookSwatchSource: Equatable {
    case reference
    /// Not reachable until the Metal preview lands.
    case live(UIImage)

    /// **A bundled reference, and the alternatives were weighed.**
    ///
    /// - *The last capture* has nothing to show on a first run, and the last
    ///   thing somebody photographed is as likely to be a dark blur as a
    ///   scene that tells you what a look does.
    /// - *A neutral gradient* shows the curve and nothing else. These looks
    ///   act on skin, foliage and sky.
    /// - *One bundled photograph* shows all four looks on the SAME subject,
    ///   which is what makes them comparable, and it is what a film box does.
    func image() -> UIImage? {
        switch self {
        case .live(let frame): return frame
        case .reference: return UIImage(named: "DemoPhoto1")
        }
    }
}

/// The film looks, growing out of the camera's glass button.
///
/// **The button and the tray are ONE piece of glass.** The owner: "I think it
/// would look clean with a nice dropdown animation and even merging with the
/// glass pill above it, kind of like how the same colour blocks merge, but
/// with the glass dropdown container."
///
/// So this control owns the button rather than sitting under it. There is one
/// shape, one stroke, one fill and one blur; opening changes its size and
/// nothing else. It is never two glass objects with a gap, which is what a
/// tray placed below a button would have been, and it is why the button could
/// not stay in the header and be merged with from outside.
///
/// The rows fade in **behind** the growth rather than with it, so the
/// container reads as extending and then filling rather than as a menu
/// arriving whole.
///
/// **The swatches are the live scene.** `FilmLookSwatchSource.live` is handed
/// one camera frame when the tray opens, so each row shows what that look does
/// to what the lens is pointing at rather than to a bundled photograph. It
/// falls back to the reference image when there is no frame, which is the
/// simulator and the first moment after launch.
struct FilmLookTray: View {
    @Binding var selection: FilmLook.Kind
    @Binding var isOpen: Bool
    var source: FilmLookSwatchSource = .reference

    // MARK: - The numbers, all on the app's own scale

    /// The button, from his node 14190:9740 — and therefore the closed size of
    /// the whole control.
    static let buttonSide: CGFloat = 40
    /// His radius, kept for both states so the shape never changes character
    /// as it grows.
    static let radius: CGFloat = 9.9

    /// His own panel width, from version A of the mock.
    private static let openWidth: CGFloat = 147
    /// `gapItem`. The container's inside padding, on all four edges.
    private static let pad: CGFloat = GridConstants.gapItem        // 12
    /// A swatch. 44 is the app's tap floor and it leaves the name a column.
    private static let swatch: CGFloat = 44
    /// The pixel size a swatch is rendered at, so a caller handing in a live
    /// camera frame can scale it once rather than hand over a full frame.
    static var swatchPixels: CGFloat { swatch * 3 }
    /// `gapItem` between a swatch and its name.
    private static let nameGap: CGFloat = GridConstants.gapItem    // 12
    /// `gapTight` between rows.
    private static let rowGap: CGFloat = GridConstants.gapTight    // 8

    /// The chevron keeps the button's whole 40pt square at the top, so the
    /// thing you press to close is exactly the thing you pressed to open.
    private static var openHeight: CGFloat {
        buttonSide + pad
            + CGFloat(FilmLook.all.count) * swatch
            + CGFloat(FilmLook.all.count - 1) * rowGap
            + pad
    }

    /// His `#E6E6E6`, white, exactly as node 14190:9740 draws it.
    ///
    /// The owner: "the chevron should still be white just like mine, like a
    /// premium blur more than a distinct object." It was dark for one build
    /// and that was wrong of me — see the note on the light appearance below,
    /// which records the one case where this costs contrast.
    private static let chevronInk = Grey.g100

    @State private var swatches: [FilmLook.Kind: UIImage] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            chevron
            if isOpen {
                rows
                    .padding(.horizontal, Self.pad)
                    .padding(.bottom, Self.pad)
                    // **Behind the growth, not with it.** The container
                    // reaches its size first and the rows arrive into it,
                    // which is what makes it read as one thing extending
                    // rather than a menu appearing.
                    .transition(.opacity.animation(
                        reduceMotion ? nil
                        // `crossFade` is 0.2; the delay is a shade over half
                        // of `slotSnap`'s 0.30 response, so the rows start
                        // arriving once the shape is most of the way open.
                        : .easeOut(duration: 0.20).delay(0.18)))
            }
        }
        .frame(width: isOpen ? Self.openWidth : Self.buttonSide,
               height: isOpen ? Self.openHeight : Self.buttonSide,
               alignment: .top)
        // **The platform's Liquid Glass, not a material and a drawn stroke.**
        //
        // The owner, on the first version: "the edge looks a bit off and the
        // clean blur, I don't see it there in the glass." Both halves of that
        // were real and both came from the same mistake — hand building a
        // glass that iOS 26 already ships.
        //
        // `.ultraThinMaterial` is a BLUR. Liquid Glass is a blur plus a
        // refractive edge that bends what is behind it, which is the "clean
        // edge" his render has and a material cannot produce. And drawing a
        // `#CECECE` hairline on top of a material gives TWO edges: the
        // material's own boundary and the stroke over it, which is the
        // doubling that reads as "a bit off".
        //
        // `glassEffect` supplies one edge, its own, and it is the same call
        // `glassCircle` and `glassCapsule` already make — so this control is
        // the same glass as the rest of the app's chrome rather than a
        // fourth interpretation of it.
        .glassRoundedRect(cornerRadius: Self.radius, carriesType: isOpen)
        // **Neutral glass, not light glass, and that is the whole of the
        // fix.** This control forced the light appearance on itself for a
        // while, to escape the camera's dark one. It worked and it was wrong:
        // the owner, on the result, "yours is way brighter and too obvious,
        // not clean."
        //
        // It was aiming at the wrong target. The glass is not supposed to be
        // light OR dark, it is supposed to be the scene. Measured against a
        // frame of the same screen with `Glass.identity` (which draws nothing,
        // so it is the scene behind this button pixel for pixel), the light
        // appearance put the interior at 116% of the scene over sky, 152% over
        // trees and 178% over a dark scene — lightest exactly where the
        // picture was darkest.
        //
        // `GlassRecipe.photoOverlay` measures 95 / 102 / 102 on the same three
        // scenes, and it is scheme independent, so there is nothing left for
        // this view to override. The recipe and its table live in
        // `GlassIconButton.swift`.
        .animation(reduceMotion ? nil : GridConstants.slotSnap, value: isOpen)
        .task(id: source) { await makeSwatches() }
    }

    /// His own chevron path, at his coordinates, rotating as the shape grows.
    private var chevron: some View {
        Path { p in
            p.move(to: CGPoint(x: 14, y: 17))
            p.addLine(to: CGPoint(x: 20, y: 23))
            p.addLine(to: CGPoint(x: 26, y: 17))
        }
        .stroke(Self.chevronInk,
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        .frame(width: Self.buttonSide, height: Self.buttonSide)
        .rotationEffect(.degrees(isOpen ? 180 : 0))
        .contentShape(Rectangle())
        .onTapGesture {
            HapticsEngine.lightTap()
            isOpen.toggle()
        }
        .accessibilityElement()
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Film look")
        .accessibilityValue(isOpen ? "Open" : "Closed")
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: Self.rowGap) {
            ForEach(FilmLook.all, id: \.kind) { look in
                row(look.kind)
            }
        }
        .frame(width: Self.openWidth - Self.pad * 2, alignment: .leading)
    }

    private func row(_ kind: FilmLook.Kind) -> some View {
        let chosen = kind == selection
        return Button {
            HapticsEngine.tick()
            withAnimation(GridConstants.slotSnap) { selection = kind }
        } label: {
            HStack(spacing: Self.nameGap) {
                ZStack {
                    if let image = swatches[kind] {
                        Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color.white.opacity(0.08)
                    }
                }
                .frame(width: Self.swatch, height: Self.swatch)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.white.opacity(chosen ? 0.9 : 0.20),
                                      lineWidth: chosen ? 2 : 1 / displayScale)
                }

                Text(kind.name)
                    .font(Typography.bodySmall)
                    // White ink, and it needs no halo: the glass it sits on
                    // is its own ground, and it is neutral rather than light,
                    // so white reads on it over any scene.
                    .foregroundStyle(chosen ? .white : .white.opacity(0.65))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(kind.describedAs)
        .accessibilityAddTraits(chosen ? [.isSelected] : [])
    }

    /// One grade per look, off the main thread, at the swatch's own size —
    /// the same call `FilmLookStrip` makes on the review screen, so a look
    /// looks the same in both places by construction.
    private func makeSwatches() async {
        guard let source = source.image() else { return }
        let made = await Task.detached(priority: .userInitiated) { () -> [FilmLook.Kind: UIImage] in
            let small = source.scaledDown(to: FilmLookTray.swatch * 3)
            var out: [FilmLook.Kind: UIImage] = [:]
            for look in FilmLook.all {
                out[look.kind] = look.kind == .none
                    ? small
                    : FilmLookRenderer.shared.render(small, look: look)
            }
            return out
        }.value
        withAnimation(reduceMotion ? nil : GridConstants.crossFade) { swatches = made }
    }
}
