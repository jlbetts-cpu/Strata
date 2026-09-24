import SwiftUI

// MARK: - Where glass belongs
//
// **One rule decides it: Liquid Glass is for a control that floats OVER content
// the person is looking at.** A viewfinder, a map, a photograph, a tower. On a
// plain warm-white page glass has nothing to refract, so it renders as a grey
// box pretending to be a material, which looks cheaper than a clean flat
// control would. Apple's own guidance is the same: glass "is best reserved for
// the navigation layer that floats above the content of your app", and it is not
// for the content itself, nor stacked on more glass
// (`developer.apple.com/videos/play/wwdc2025/356`, "Get to know the new design
// system").
//
// So, before adding a caller, answer one question: **what is underneath it?**
// If the answer is "the page", it does not get glass. The app's own measured
// version of this rule is `docs/research/visual-cohesion.md` section 4.2, which
// adds a budget: at most three glass elements on a screen.
//
// Three call sites today are on a plain page and are the audit's open question
// rather than the precedent to copy: the tower header's Plan button and its
// replay pill (`MainAppView`), and the Memories drawer's Done
// (`MemoriesView`). They need the owner's eye before they change, because the
// Plan button stopping being glass is a change to a screen he approved.
//
// **The tower's empty slot is on the page and is glass on purpose**, because he
// asked for it on 2026-09-23 ("maybe more liquid glass feel"). `SlotGlass.swift`
// is the fourth recipe and argues its own case: `.clear`, no tint, so the
// lattice behind it reads through. It is an exception, not a precedent.

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

/// The pre-26 fallback's rim, in one place.
///
/// It was typed out three times, once in each shape below, which is the drift
/// this file exists to stop. **It is deliberately not the page hairline**
/// (`1 / displayScale` in ink, `docs/design-system-future.md` section 6): this
/// is a light rim on a material floating over a photograph, where a dark
/// hairline would read as a dirty edge, and it has to hold at 2x and 3x alike.
private enum GlassFallback {
    static let rim = Color.white.opacity(0.18)
    static let rimWidth: CGFloat = 0.5
}

extension View {
    /// Liquid Glass in a capsule: the same material as `GlassIconButton`, for a
    /// control whose label is a word rather than a glyph.
    ///
    /// It lives here rather than beside its one caller because there is now more
    /// than one: a glass treatment that is redefined per screen drifts per
    /// screen, which is the same lesson `SectionHeading` records about type.
    /// Layout first, glass after: the effect takes its shape from the final
    /// frame.
    ///
    /// **Read the rule at the top of this file before adding a caller.** Three
    /// of this app's glass capsules are on a plain page rather than over
    /// content, and they are the open question in the audit, not the precedent.
    @ViewBuilder
    func glassCapsule() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            self.background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(GlassFallback.rim,
                                                lineWidth: GlassFallback.rimWidth))
        }
    }

    /// Liquid Glass in a rounded rectangle, for a control whose shape is neither
    /// a circle nor a capsule: the camera's film-look container at the owner's
    /// radius 9.9.
    ///
    /// The third and last shape, beside this file's other two, for the reason it
    /// already records: a glass treatment redefined per screen drifts per
    /// screen.
    ///
    /// `carriesType` is the one place the recipe is chosen by ROLE rather than
    /// by shape, and the table on `GlassRecipe.typePanel` is why: a glyph is
    /// legible against almost anything, four rows of names are not.
    @ViewBuilder
    func glassRoundedRect(cornerRadius r: CGFloat, carriesType: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(carriesType ? GlassRecipe.typePanel : GlassRecipe.photoOverlay,
                             in: .rect(cornerRadius: r, style: .continuous))
        } else {
            let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
            self.background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(GlassFallback.rim,
                                            lineWidth: GlassFallback.rimWidth))
        }
    }

    /// Liquid Glass where it exists, a material where it does not.
    ///
    /// **This doc comment was welded onto `glassRoundedRect` and the circle had
    /// none**, which is how the two shapes' reasoning came to look like one
    /// paragraph about a rounded rectangle. Each shape documents itself.
    ///
    /// Internal rather than private since `ProfileButton` needs the same circle:
    /// a second copy of this is how the two buttons would drift.
    ///
    /// `.interactive()` is included because this is genuinely a button: the
    /// effect reacts to the press, which is the affordance being bought here.
    /// The deployment target is 18.0, so the fallback is not optional.
    @ViewBuilder
    func glassCircle() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: .circle)
        } else {
            self.background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(GlassFallback.rim,
                                               lineWidth: GlassFallback.rimWidth))
        }
    }
}

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

    /// **The tray's glass is stronger than the button's, and that is
    /// deliberate: one carries a glyph, the other carries type.**
    ///
    /// The owner, on the approved button: "the text isn't the most readable in
    /// the section. I was thinking more like not so shiny glass effect, so the
    /// text can still be readable."
    ///
    /// A button can be almost invisible because it holds one chevron, and the
    /// chevron is legible against anything. Four rows of names need a ground.
    /// Measured on the open tray, worst row of the four:
    ///
    /// | | bright sky | trees | dark |
    /// |---|---|---|---|
    /// | on `photoOverlay` (the button's glass) | 1.56:1 | 2.30:1 | — |
    /// | `.regular`, no ink | 4.40:1 | 5.40:1 | — |
    /// | **`.regular` + 30% ink** | **5.44:1** | **6.54:1** | **6.73:1** |
    ///
    /// So the button's own glass put the names at 1.56:1 over a bright sky,
    /// against a 4.5:1 floor. This clears it on every row of every scene.
    ///
    /// `.regular` is the right base here for the same reason it was wrong for
    /// the button: it blurs hard, removing about 82% of the scene's detail
    /// where `.clear` removes 22 to 37, and that blur is what stops the
    /// picture reading through the names. The 30% ink takes out its specular
    /// lift, so the panel is substance rather than shine. It still takes the
    /// scene's colour: blue over sky, olive over grass, warm over a dark room.
    static var typePanel: Glass {
        .regular.tint(.black.opacity(0.30)).interactive()
    }
}
