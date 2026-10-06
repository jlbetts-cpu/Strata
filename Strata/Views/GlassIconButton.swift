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
    /// `GridConstants.iconToolbar`, which is the same 17 this was typed as a
    /// literal — here and again on `GlassIconLabel`, which is two copies of one
    /// number on one ladder (`docs/consistency-audit.md` §1.15).
    var glyphSize: CGFloat = GridConstants.iconToolbar
    /// True when this stands on the app's own page rather than over a
    /// photograph or a viewfinder. See `GlassRecipe.onPage`.
    var onPage: Bool = false
    var accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button {
            HapticsEngine.lightTap()
            action()
        } label: {
            GlassIconLabel(systemName: systemName, tint: tint,
                           size: size, glyphSize: glyphSize, onPage: onPage)
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
    var glyphSize: CGFloat = GridConstants.iconToolbar
    var onPage: Bool = false

    var body: some View {
        Image(systemName: systemName)
            // **`iconSize`, not `.font(.system(size:))`** (2026-10-01,
            // `docs/consistency-audit.md` §1.15, which named this the worst of
            // the five fixed sizes left in the app because it is the SHARED
            // component: every `GlassIconButton` and `GlassIconLabel` in the app
            // had an icon that did not grow with the user's text size, while the
            // label beside it did. `IconStyle`'s own first line is the argument.
            // The glass disc behind it keeps its own 44pt frame, so a larger
            // glyph grows inside a fixed control rather than moving the layout.
            .iconSize(glyphSize, relativeTo: .body, weight: .medium)
            .foregroundStyle(tint)
            // Layout first, glass after: the effect takes its shape from
            // the final frame, so applying it before the frame gives it
            // the wrong bounds.
            .frame(width: size, height: size)
            .glassCircle(onPage: onPage)
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
    ///
    /// **`carriesType`**, as `glassRoundedRect` already has. A capsule holding
    /// WORDS over a photograph is a different problem from one holding a
    /// chevron, and until this flag existed the capsule shape had no way to
    /// reach `GlassRecipe.typePanel`, which is the recipe measured for exactly
    /// that. The camera's size picker found it: its unselected word came out
    /// at 2.91:1 on a capsule of rgb(108, 102, 130), against a 4.5 floor for
    /// text, and the selected one passed at 5.07, which is how it survived a
    /// reading. With the panel recipe the same word measures 5.83.
    @ViewBuilder
    func glassCapsule(onPage: Bool = false, carriesType: Bool = false, interactive: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            // `interactive: false` for a capsule that HOLDS buttons rather than
            // being one (the reaction bar): interactive glass tracks the finger
            // itself, and around buttons of its own it took their taps on a real
            // phone (the owner, 2026-10-05: "the reaction picker... never shows
            // up").
            self.glassEffect(carriesType ? GlassRecipe.typePanel
                                         : (onPage ? GlassRecipe.onPage
                                            : (interactive ? Glass.regular.interactive() : Glass.regular)),
                             in: .capsule)

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
    /// The bubble's glass: the page recipe, with no system press response.
    @ViewBuilder
    func stillGlassCircle() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(GlassRecipe.onPageStill, in: .circle)
        } else {
            self.background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(GlassFallback.rim,
                                               lineWidth: GlassFallback.rimWidth))
        }
    }

    @ViewBuilder
    func glassCircle(onPage: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(onPage ? GlassRecipe.onPage : .regular.interactive(),
                             in: .circle)

        } else {
            self.background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(GlassFallback.rim,
                                               lineWidth: GlassFallback.rimWidth))
        }
    }
}

@available(iOS 26.0, *)
enum GlassRecipe {
    /// **CHROME THAT STANDS ON THE PAGE, NOT OVER A PHOTOGRAPH.**
    ///
    /// The owner, 2026-09-30, twice: "I don't like how much the buttons stick
    /// out like a sore thumb, there's no continuity" and then, after the ground
    /// was warmed to meet them, "those glass buttons are still sticking out like
    /// a sore thumb, I need it to be clean and cohesive."
    ///
    /// The note at the top of this file already called this the open question:
    /// three of this app's glass controls sit on a plain page rather than over
    /// content, and they are not what the material is for. Measured on the
    /// built header, that is exactly how it fails — `.regular` over a smooth
    /// near-white field has NOTHING TO REFRACT, so it collapses to a flat
    /// opaque capsule at (251, 250, 246) on a (240, 238, 232) page. It is the
    /// one opaque white object on a page where every other surface is
    /// translucent and lit, and that is what "sore thumb" means. It is the same
    /// finding the lattice produced when `.ultraThinMaterial` was tried on it:
    /// blur a smooth gradient and you get the same smooth gradient.
    ///
    /// Still native glass — he is emphatic about that and he is right, a
    /// hand-rolled one looked cheap. So this is `.regular` with its LIFT taken
    /// off rather than a different material.
    ///
    /// **`.clear` was the obvious answer and is wrong, which this file already
    /// knew.** `photoInk` right below says it in one line: "0.16 cancels
    /// `.clear`'s lift". `.clear` does not mean less bright, it means less
    /// blurred — over a near-white page it keeps its specular rise and loses the
    /// frost, so the measured result of trying it here was a pill at (255, 255,
    /// 255), FOUR LEVELS WORSE than the `.regular` it replaced. Adding the
    /// app's white rim to that made it brighter again.
    ///
    /// A small black tint on `.regular` moves the one number that matters. The
    /// target is not "invisible" — it is `PageSurface`, which lands at 245 on a
    /// 240 page and is the surface the rest of the app's chrome is already made
    /// of. Five levels, which is enough to find and not enough to shout.
    static let pageInk: Double = 0.035
    static var onPage: Glass { .regular.tint(.black.opacity(pageInk)).interactive() }
    /// The same glass without the system's press response, for a control that
    /// answers the press itself and holds something that must stay visible
    /// through it: the tower head's bubble, where the interactive glow washed
    /// the parked head out for the length of the press (filmed, 2026-10-02).
    static var onPageStill: Glass { .regular.tint(.black.opacity(pageInk)) }

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


/// **Two glass buttons that belong together, as one group** (the Wins
/// header's Journal and Plan, 2026-10-05: "one glass pair, reading as mine").
///
/// One `GlassEffectContainer`, so the two discs are rendered as one piece of
/// glass sampling one backdrop rather than as two materials side by side,
/// and so a change to either morphs inside the group. **Its blend distance is
/// under the gap between them**, which is what stops them fusing: on
/// 2026-10-02 a group at the default distance welded the Plan and the head's
/// bubble into one peanut-shaped capsule. Two discs, `gap` apart, never
/// touching. Before iOS 26 there is no container and the two stand as they
/// always did.
struct HeaderGlassPair<Content: View>: View {
    /// The space between the two discs, the header's own `gapTight`.
    static var gap: CGFloat { GridConstants.gapTight }
    /// How close two shapes come before the glass starts to join them. Under
    /// `gap`, so at rest they never do.
    static var blend: CGFloat { 0 }

    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: Self.blend) {
                HStack(spacing: Self.gap) { content }
            }
        } else {
            HStack(spacing: Self.gap) { content }
        }
    }
}
