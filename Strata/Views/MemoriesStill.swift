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
/// same components the real screen draws it with: `MemoriesTitle`,
/// `GlassIconLabel`, and the tab bar's glyphs from `StrataTab.icon(selected:)`,
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

    /// A real phone's top and bottom insets, so the chrome sits where it sits on
    /// the device rather than against the glass.
    private static let safeTop: CGFloat = 59
    private static let safeBottom: CGFloat = 34

    var body: some View {
        ZStack {
            // The map, and his photographs on it, exactly as the app drew them.
            Image("DemoMap")
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .clipped()

            VStack(spacing: 0) {
                titleRow
                Spacer(minLength: 0)
                bottomRow
                tabBar
            }
            .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }

    /// The name of the screen, and the two controls that live opposite it.
    ///
    /// Top-aligned with the buttons offset onto the title's cap, which is what
    /// `MemoriesView.titleRow` does and for the reason CLAUDE.md records: a
    /// drawn title is only as tall as its cap, so a centre rule would hang the
    /// row off the 44pt buttons and drop the word below the line.
    private var titleRow: some View {
        HStack(alignment: .top, spacing: GridConstants.gapTight * s) {
            MemoriesTitle(size: Typography.screenTitleCap * s,
                          color: AppColors.inkPrimary)
            Spacer(minLength: 0)
            GlassIconLabel(systemName: "photo.on.rectangle.angled",
                           size: GlassIconButton.defaultSide * s,
                           glyphSize: 17 * s)
                .offset(y: capOffset)
            profile.offset(y: capOffset)
        }
        .padding(.horizontal, GridConstants.horizontalPadding * s)
        .padding(.top, (Self.safeTop + GridConstants.headerArtworkTopPadding) * s)
    }

    /// Centred on the title's cap by hand. See `titleRow`.
    private var capOffset: CGFloat {
        (Typography.screenTitleCap - GlassIconButton.defaultSide) / 2 * s
    }

    /// You, where the gear used to be. The real screen draws the head if one has
    /// been made and the photograph otherwise; onboarding has neither yet, so it
    /// is his own portrait, which is the picture this app ships with.
    private var profile: some View {
        Image("CreatorPortrait")
            .resizable()
            .scaledToFill()
            .frame(width: GlassIconButton.defaultSide * s,
                   height: GlassIconButton.defaultSide * s)
            .clipShape(Circle())
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
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(StrataTab.allCases, id: \.self) { tab in
                let on = tab == .memories
                VStack(spacing: 3 * s) {
                    Image(systemName: tab.icon(selected: on))
                        .font(.system(size: 20 * s, weight: .regular))
                    Text(tab.rawValue)
                        .font(.system(size: 11 * s, weight: .medium))
                }
                .foregroundStyle(on ? AppColors.inkPrimary : AppColors.inkTertiary)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, GridConstants.gapItem * s)
        .padding(.horizontal, GridConstants.gapWide * s)
        .background {
            Capsule(style: .continuous)
                .fill(.regularMaterial)
                .environment(\.colorScheme, .light)
        }
        .padding(.horizontal, (GridConstants.horizontalPadding + GridConstants.gapWide) * s)
        .padding(.bottom, Self.safeBottom * s)
    }
}
