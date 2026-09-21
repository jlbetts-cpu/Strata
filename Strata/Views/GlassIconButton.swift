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
            self.glassEffect(.regular.interactive(),
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
