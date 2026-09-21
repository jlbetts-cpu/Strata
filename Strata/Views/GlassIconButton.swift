import SwiftUI

/// A round icon button on iOS 26's Liquid Glass.
///
/// The share and settings buttons were bare glyphs at 45% opacity in the
/// corner of a header — legible, but they read as decoration rather than as
/// something to press, and they were the only controls on those screens.
/// Glass is what iOS 26 uses for exactly this: a floating control over
/// content, which is what both of them are.
///
/// **Why this does not contradict CLAUDE.md's "chrome is not a block".** That
/// rule forbids giving cards, sheets and wells a white rim or a frosted edge,
/// because those are a block's claim to be an object you built. A 44pt circle
/// is not in any danger of being mistaken for a block — it is round, it is a
/// control, and the shape is the whole distinction.
///
/// It is also NOT the same as the toolbar rule. `sharedBackgroundVisibility(.hidden)`
/// strips the glass capsule iOS puts behind *toolbar* items automatically,
/// where it was unasked for and grouped unrelated buttons together. This is
/// glass applied deliberately, one control at a time.
struct GlassIconButton: View {
    let systemName: String
    /// The glyph's colour. `.white` over a viewfinder, `.primary` on a page.
    var tint: Color = .primary
    /// The HIG's minimum target, and the one every one of these is.
    static let defaultSide: CGFloat = 44
    var size: CGFloat = GlassIconButton.defaultSide
    var glyphSize: CGFloat = 17
    var accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button {
            HapticsEngine.lightTap()
            action()
        } label: {
            GlassIconLabel(systemName: systemName, tint: tint,
                           size: size, glyphSize: glyphSize)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// `GlassIconButton`'s face without its `Button`: for a `Menu` label, which
/// supplies its own press handling and cannot hold a button inside it.
///
/// **One face, two wrappers.** The photo viewer and the add sheet's photo
/// review each rebuilt this privately (a 36pt disc in a 44pt frame, a
/// semibold glyph), so their close was visibly smaller and heavier than the
/// replay's. The styling lives here once and both wrappers draw it.
struct GlassIconLabel: View {
    let systemName: String
    var tint: Color = .primary
    var size: CGFloat = GlassIconButton.defaultSide
    var glyphSize: CGFloat = 17

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: glyphSize, weight: .medium))
            .foregroundStyle(tint)
            // Layout first, glass after: the effect takes its shape from
            // the final frame, so applying it before the frame gives it
            // the wrong bounds.
            .frame(width: size, height: size)
            .glassCircle()
            .contentShape(Circle())
    }
}

extension View {
    /// Liquid Glass in a capsule — the same material as `GlassIconButton`, for
    /// a control whose label is a word rather than a glyph.
    ///
    /// It lives here rather than beside its one caller because there is now
    /// more than one: a glass treatment that is redefined per screen drifts
    /// per screen, which is the same lesson `SectionHeading` records about
    /// type. Layout first, glass after — the effect takes its shape from the
    /// final frame.
    @ViewBuilder
    func glassCapsule() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            self.background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
        }
    }
}

extension View {
    /// Liquid Glass where it exists, a material where it does not.
    ///
    /// Internal rather than private since `ProfileButton` needs the same
    /// circle: a second copy of this is how the two buttons would drift.
    ///
    /// `.interactive()` is included because this is genuinely a button — the
    /// effect reacts to the press, which is the affordance being bought here.
    /// The deployment target is 18.0, so the fallback is not optional.
    /// Liquid Glass in a rounded rectangle, for a control whose shape is
    /// neither a circle nor a capsule — the camera's film-look container at
    /// the owner's radius 9.9.
    ///
    /// The third and last shape, beside this file's other two, for the reason
    /// it already records: a glass treatment redefined per screen drifts per
    /// screen.
    @ViewBuilder
    func glassRoundedRect(cornerRadius r: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(GlassRecipe.photoOverlay,
                             in: .rect(cornerRadius: r, style: .continuous))
        } else {
            let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
            self.background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
        }
    }

    @ViewBuilder
    func glassCircle() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: .circle)
        } else {
            self.background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
        }
    }
}

extension View {
    /// **Legible over a photograph, without a panel, a box or a scrim.**
    ///
    /// The owner, once the simulator started showing a real scene: "the white
    /// UI has some trouble being visible against the bright image... I want it
    /// to be semi invisible."
    ///
    /// Measured on the valley scene now behind the viewfinder: the sky is
    /// **L 0.4681**, so white sits on it at **2.03:1** — under the 4.5:1 floor
    /// for text and under even the 3:1 one for a glyph. The thirds lines
    /// scored worse: over the same sky the line region reads as a smooth
    /// 189 to 216 gradient with no distinguishable line in it at all.
    ///
    /// **A soft dark halo, and it is self-adapting, which is why it is the
    /// smallest thing that works.** Over a bright scene the dark carries the
    /// contrast the white cannot. Over a dark scene the halo is dark on dark
    /// and effectively absent, so the controls that were already fine do not
    /// go muddy. Nothing samples the scene, nothing switches mode, and there
    /// is no threshold to flicker across.
    ///
    /// **No offset**, so it is a halo rather than a drop shadow: an offset
    /// shadow reads as an object floating above the picture, which is the
    /// thing the app's shadow rule exists to forbid.
    ///
    /// **On that rule.** "The companion heads cast contact shadows, nothing
    /// else" is about CHROME ON A FLAT GROUND, where a shadow is a false claim
    /// that a flat interface has depth. This is white ink on a photograph,
    /// where the only alternative to a halo is a panel or a scrim — both of
    /// which put a new opaque object on the picture, and both of which the
    /// owner has asked not to have. The exception is the viewfinder and
    /// nothing else.
    func legibleOverPhoto() -> some View {
        // **0.22 at radius 2, which is half what it was.** The owner: "the
        // drop shadow has to be more subtle if it's there at all, right now it
        // looks too stark." At 0.45 and radius 3 it read as a dark glow around
        // the wordmark — a visible effect rather than a reason the white
        // stayed legible, which is the opposite of "semi invisible".
        //
        // It does NOT go on the glass. The button and the tray get their
        // separation from the blur and their own refractive edge, and a shadow
        // there turns them into an object sitting on the picture rather than
        // part of it. This is for white ink with nothing behind it: the five
        // controls, the shutter's ring and the wordmark.
        //
        // The thirds lines do not take it either — they are scene tinted, and
        // a shadow under a tinted line is the "pure white with a shadow" he
        // called the opposite of what he wanted.
        shadow(color: .black.opacity(0.22), radius: 2, x: 0, y: 0)
    }
}


/// The Liquid Glass recipe for a control that sits on a photograph.
///
/// **The target is neutral: the interior should measure about 100% of the
/// scene behind it.** The owner: "yours is way brighter and too obvious, not
/// clean... the interior should measure about 100 percent of the scene behind
/// it, neither darkened nor lifted. What makes it visible is that the picture
/// inside it is soft while the picture outside is sharp, plus the single light
/// edge. Nothing else."
///
/// **Measured, not chosen.** `Glass.identity` draws nothing at all, which
/// gives an exact reference: shoot the same screen twice and the identity
/// frame is the scene that is behind the button, pixel for pixel. Interior
/// means over three scenes, each against its own identity frame:
///
/// | recipe | bright sky | trees | dark scene |
/// |---|---|---|---|
/// | `.regular`, light appearance | 116% | 152% | 178% |
/// | `.regular`, dark appearance | 56% | — | — |
/// | `.clear` | 110% | 118% | 117% |
/// | **`.clear` + 16% ink** | **95%** | **102%** | **102%** |
///
/// **Three things that decided it.**
///
/// `.regular` is the milky slab he rejected. It does not tint the scene, it
/// washes toward white, and it washes hardest where the scene is darkest —
/// +33 levels over sky, +86 over a dark scene. There is no appearance that
/// fixes it: the dark variant crushes the same scene to 56%, which is the
/// "muddy dark colour" he rejected before this.
///
/// `.clear` is scheme independent. Measured identical in both appearances to
/// the decimal, so this control can no longer go dark because the camera
/// declares the dark appearance for its tab bar. That removes the whole class
/// of fault rather than compensating for it, and it is why the forced light
/// appearance this control used to carry is gone.
///
/// **The 16% ink is not a fill, it is a cancellation.** `.clear` still lifts
/// by a roughly constant +20 levels, so it reads lighter than the picture on
/// every scene. The ink removes that lift and nothing more: net of it, the
/// interior sits within about 2% of the scene on trees and on a dark scene,
/// which is his "near zero fill" measured rather than declared. The one place
/// it is not within a few percent is blue over a bright sky, where the scene's
/// blue channel is already at 245 and cannot lift to meet it: that channel
/// lands at 91%, and the interior reads a shade cooler than the sky.
///
/// **What this still does not match, measured: the blur.** His node asks for
/// `backdrop-filter: blur(8px)` at a Figma background-blur radius of 16, which
/// is a sigma of 8pt. Applying exactly that recipe to the same three identity
/// frames (blur, then his `#080808` at 1%, then his `#CECECE` hairline) gives:
///
/// | | his recipe | ours | `.regular` |
/// |---|---|---|---|
/// | interior, sky | 98% | 95% | 116% |
/// | interior, trees | 97% | 102% | 152% |
/// | interior, dark | 102% | 102% | 178% |
/// | **detail removed, sky** | **82%** | **-1%** | 76% |
/// | **detail removed, trees** | **94%** | **37%** | 82% |
/// | **detail removed, dark** | **92%** | **22%** | 74% |
///
/// So the neutrality is matched and the blur is not. Inside his button the
/// picture is gone and the shape is a flat field; inside ours the scene is
/// softened but still readable. `.clear` buys its neutrality by barely
/// blurring, and the only stronger blur the platform exposes is `.regular`,
/// which is the milky slab. There is no public way to blur what is behind a
/// view on iOS, so closing this gap means blurring a copy of the camera frame
/// ourselves and drawing it clipped to this shape.
///
/// **That is the live-frame work, not a separate job.** `CameraService`
/// already has the seam for it (`attachFrames`) and `FilmLookTray` already has
/// the seam for a live frame (`FilmLookSwatchSource.live`), both unused. It is
/// deliberately not built here: it is the same pipeline the graded viewfinder
/// needs, the owner deferred that to his own device, and its frame rate and
/// thermal cost cannot be judged in a simulator.
@available(iOS 26.0, *)
enum GlassRecipe {
    /// 0.16 cancels `.clear`'s lift. See the table above before changing it —
    /// the number is the output of a measurement, and moving it moves the
    /// interior off the scene in a direction the owner has already rejected
    /// once in each direction.
    static let photoInk: Double = 0.16

    static var photoOverlay: Glass {
        .clear.tint(.black.opacity(photoInk)).interactive()
    }
}
