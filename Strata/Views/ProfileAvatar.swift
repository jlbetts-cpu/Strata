import SwiftUI

/// The picture at the top of Profile: you, as `PersonHead` draws you.
///
/// **Your head, or the blank head where yours will be** (the owner,
/// 2026-10-14: "remove the option for a pfp and make the head making a
/// must"). It used to choose between your head, a photograph, your initials
/// on a colour and a glyph, by a switch; there is one answer now, and it is
/// the one every crew shows of you.
///
/// No rim and no shadow. The disc is your Background Colour, or the quiet
/// well when none is chosen.
struct ProfileAvatar: View {
    let side: CGFloat

    var body: some View {
        // Expressive: on Profile the head is the subject of the page.
        PersonHead(person: .me, side: side, life: .expressive,
                   setting: .disc(.chosen), traceID: "profile")
    }
}

/// The profile picture as a header button, beside the other glass buttons.
///
/// **Built on `GlassIconButton`'s own skeleton**: a 17pt SF Symbol in a 44pt
/// frame, so it lands exactly where the Photographs button beside it does,
/// whichever way a header aligns its row. The glyph is drawn clear: it is
/// there to be measured, and there is always a head or the blank head over it.
struct ProfileButton: View {
    let action: () -> Void

    private var store: ProfileStore { .shared }
    private let side = GlassIconButton.defaultSide

    /// Whether the label is drawn on Liquid Glass, mirroring `label` below:
    /// glass unless a Background Colour is chosen, which is the picture's own
    /// ground, as in Profile.
    private var isGlass: Bool { store.background == nil }

    var body: some View {
        Button {
            HapticsEngine.lightTap()
            action()
        } label: {
            label
        }
        // **Glass answers a press on its own; a colour does not** (2026-10-02,
        // the motion pass). Under `.plain` a chosen colour did nothing at all
        // under a finger while every other button in the header gave. It
        // takes the app's surface press; glass keeps a press that does
        // nothing, so the press is not answered twice.
        .buttonStyle(isGlass ? PressResponse(scale: 1, dim: 1) : .pressSurface)
        .accessibilityLabel("Profile")
    }

    @ViewBuilder
    private var label: some View {
        // Hollow, beside the hollow `play` and `map` in the Memories header
        // (the cohesion pass, 2026-10-05, visual-cohesion §4.3), and clear:
        // the frame it gives is what is measured.
        let glyph = Image(systemName: "person")
            .font(Typography.bodyLarge.weight(.medium))
            .foregroundStyle(.clear)
            .frame(width: side, height: side)
        // Calm: in a header the head blinks and glances and nothing more
        // (plan §5.3), because a face pulling expressions in a corner pulls
        // the eye from the page it sits on.
        let face = glyph
            .overlay {
                PersonHead(person: .me, side: side, life: .calm,
                           setting: .disc(.clear), traceID: "header")
            }
            .contentShape(Circle())
        if isGlass {
            face.glassCircle()
        } else {
            face.background(Circle().fill(store.backgroundStyle))
        }
    }
}
