import SwiftUI

/// The Memories tab, composed rather than screenshotted, for the onboarding's
/// device frame.
///
/// The owner, 2026-09-23, with a photograph of the real screen on his phone:
/// the map page "should look like the real Memories screen". It was showing
/// `DemoMap` on its own, which is a picture of a MAP: his photographs are on it,
/// but none of the app is, so the one page that is meant to say "this is where
/// your wins live" looked like Apple Maps with pictures dropped on it.
///
/// **Composed, not live, for the same reason the camera page is a picture**
/// (his note, of the map page: "make sure the map loads faster... no need to
/// load in an entire map, just need a photo of the map"). A real
/// `MemoriesMapView` here spins up MapKit and fetches tiles over a network that
/// might not be there, during the ninety seconds when somebody is deciding
/// whether they like this app. Nothing on this page is interactive, so there is
/// nothing to buy with a live map.
///
/// **The ground is the app's own render**, blocks and all: `DemoMap` was
/// produced by this app, with the real clusterer, on his own photographs. What
/// is added here is only the chrome that capture did not include, drawn from the
/// same components the real screen draws it with: `GlassIconLabel` for the back
/// and recentre discs, and the tab bar's glyphs from `StrataTab.icon(selected:)`,
/// which is the one place in the app that decides filled against hollow.
///
/// **Everything is composed at `reference` points wide and scaled once.** The
/// device on the onboarding page is about half a phone wide, so every number
/// here is a real screen's number multiplied by `s`. That is what keeps it a
/// picture of the app rather than a small approximation of it: the title is the
/// title's cap height, the buttons are 44pt buttons, the margins are the page
/// margin.
struct MemoriesStill: View {

    /// The screen this is being drawn into. **Both dimensions, because the
    /// composition has to be clipped to them**: a `scaledToFill` image reports
    /// the size it scaled to, not the size it was offered, so in a stack it
    /// makes the stack bigger than the screen and every piece of chrome laid out
    /// against that stack lands off the edge. Photographed once: the title read
    /// "es" and the tab bar ran out of both sides of the phone.
    let width: CGFloat
    let height: CGFloat

    /// The width the chrome is composed at: a real phone.
    static let reference: CGFloat = 402

    private var s: CGFloat { width / Self.reference }

    /// A real phone's top inset, so the chrome sits where it sits on the device
    /// rather than against the glass.
    ///
    /// **`safeBottom` (34) was here and is gone.** It was the home indicator's
    /// inset and the tab bar was the only thing that read it, as the gap under
    /// the capsule — which was a derivation, not a measurement, and it was
    /// wrong: the real bar's bottom edge sits **21pt** above the screen, not 34.
    /// That number is `barBottom` now, beside the rest of the bar's measured
    /// geometry, where the capture it came from is named.
    private static let safeTop: CGFloat = 59

    var body: some View {
        ZStack {
            // The map, and his photographs on it, exactly as the app drew them.
            Image("DemoMap")
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .clipped()

            VStack(spacing: 0) {
                backRow
                Spacer(minLength: 0)
                bottomRow
                tabBar
            }
            .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
        // **The picture is of a LIGHT screen, in both schemes** (2026-10-02,
        // design review). `DemoMap` is a baked capture of the pale map, so the
        // chrome drawn over it has to be the light chrome too. Following the
        // phone, dark mode set the title in white on that pale map: **1.25:1**
        // (rgb 220 on 197, onboarding page 4), against 8.95 in light. The tab
        // bar's capsule was already pinned light for the same reason; its
        // glyphs and the title were not. Pinned: 8.95:1 in both schemes.
        .environment(\.colorScheme, .light)
        .accessibilityHidden(true)
    }

    /// **The way back, and nothing else, because that is the map now**
    /// (the owner's call, 2026-10-02: "Redraw it").
    ///
    /// This drew the "Memories" title with the album and profile buttons
    /// opposite it, which was the map AS the Memories tab. Since 2026-09-30
    /// Memories is a page and the map is pushed from it full screen: a back
    /// disc top-leading, no title, no profile, the recentre button over the
    /// tab bar (`MemoriesMapView`, captured as `11-map`). The picture promised
    /// a screen the app no longer had; it now draws the one it has. Same
    /// geometry as the real control: `GlassIconButton.defaultSide`, on the page
    /// margin, `headerArtworkTopPadding` under the status bar.
    private var backRow: some View {
        HStack {
            GlassIconLabel(systemName: "chevron.left",
                           size: GlassIconButton.defaultSide * s,
                           glyphSize: 17 * s)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, GridConstants.horizontalPadding * s)
        .padding(.top, (Self.safeTop + GridConstants.headerArtworkTopPadding) * s)
    }

    /// The recentre control, which on the real screen floats above the tab bar
    /// on the right.
    private var bottomRow: some View {
        HStack {
            Spacer(minLength: 0)
            GlassIconLabel(systemName: "location",
                           size: GlassIconButton.defaultSide * s,
                           glyphSize: 17 * s)
        }
        .padding(.horizontal, GridConstants.horizontalPadding * s)
        .padding(.bottom, GridConstants.gapItem * s)
    }

    /// The floating bar, with Memories on.
    ///
    /// Drawn rather than borrowed because the real one is the system's
    /// `TabView`, which cannot be put in a picture. The glyphs come from
    /// `StrataTab` so the filled-means-selected rule stays in one place.
    ///
    /// **ICON ONLY, and every number below is now MEASURED off the real bar**
    /// (`docs/copy-audit.md` cut 8, 2026-10-01).
    ///
    /// It drew an 11pt medium word under each glyph, and the entry that stood
    /// here defended them as "UIKit's tab-bar metrics, not this app's type
    /// scale". That defence died the same day: **the real tab bar has no words
    /// on it.** `MainAppView` builds each `Tab` from a bare
    /// `Image(systemName:)` and the three names exist only as
    /// `accessibilityLabel`. So this was teaching a chrome the app does not
    /// have, and doing it in the smallest type in the app: measured off
    /// `/tmp/room/20-onboarding-4.png`, each word's ink was **3.4pt tall** on
    /// screen, which is the owner's "no tiny text under or anythign like that"
    /// twice over.
    ///
    /// **The labels coming off exposed that none of the rest of it matched
    /// either**, so the shape was re-derived from the shipping bar rather than
    /// from UIKit's old constants. Measured off `/tmp/room/new-wins.png`, a
    /// 402x874 @3x capture of the Wins tab, against what this view drew before
    /// (its own capture, converted back to reference points at `s` = 0.356):
    ///
    /// | | real | this view, before |
    /// |---|---|---|
    /// | capsule height | **62.0** (y 791.0 to 853.0) | 68.4 |
    /// | capsule width | **274.0** (x 64.0 to 337.7) | 322.0 |
    /// | bottom edge above the screen | **21.0** | 34.0 |
    /// | glyph pitch | **86.0** (centres 114.7 / 200.7 / 286.7) | 92.5 |
    /// | glyph ink height | **26.3 / 21.7 / 25.0** | 21.6 / 17.8 / 21.6 |
    ///
    /// The glyph ink ratio across the three is 1.22 / 1.22 / 1.16, mean 1.20,
    /// so the size that was 20 is **24**. The inner horizontal padding is
    /// `(274 - 3 x 86) / 2 = 8`, which puts the drawn centres at 115 / 201 /
    /// 287 against the measured 114.7 / 200.7 / 286.7 — inside half a point.
    ///
    /// **The selection pill is deliberately NOT drawn.** The real bar has one:
    /// sampled across the capsule's middle row, the selected third reads
    /// rgb(233) against the bar's own rgb(252), x 68 to 162. That is **1.17:1
    /// over 94 reference points**, which at this view's 0.356 is a 33pt shape
    /// carrying nineteen levels of grey — invisible in the drawing, and the
    /// mock already says which tab is on twice, by the glyph filling
    /// (`StrataTab.icon(selected:)`) and by the tint stepping from
    /// `inkTertiary` to `inkPrimary`. Drawing it would be adding chrome in a
    /// pass whose whole job was taking some off.
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(StrataTab.allCases, id: \.self) { tab in
                let on = tab == .memories
                // **The bar's own picture of each tab** (`StrataTab.picture`):
                // his drawing with its word under it, the idle two grey, as
                // the real bar draws them since 2026-10-06. A drawing of the
                // app's own chrome has to be the chrome, or onboarding teaches
                // a bar the app does not have.
                let picture = tab.picture(selected: on, scheme: .light)
                Image(uiImage: picture)
                    .resizable()
                    .scaledToFit()
                    .frame(height: picture.size.height * s)
                    .foregroundStyle(AppColors.inkPrimary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, Self.barInnerPad * s)
        .frame(height: Self.barHeight * s)
        .background {
            Capsule(style: .continuous)
                .fill(.regularMaterial)
                .environment(\.colorScheme, .light)
        }
        .padding(.horizontal, Self.barInset * s)
        .padding(.bottom, Self.barBottom * s)
    }

    /// The real tab bar's own geometry, in a real phone's points. **Every one of
    /// these is a measurement off `/tmp/room/new-wins.png`, not a token**, and
    /// that is on purpose: this is a picture of chrome iOS lays out, so the
    /// app's spacing ladder has no claim on it and a rung that happened to be
    /// close would be a coincidence dressed as a decision. The table on
    /// `tabBar` carries the measurements and what each one replaced.
    private static let barHeight: CGFloat = 62
    private static let barInset: CGFloat = (reference - 274) / 2
    private static let barBottom: CGFloat = 21
    private static let barInnerPad: CGFloat = (274 - 86 * 3) / 2
    private static let barGlyph: CGFloat = 24
}
