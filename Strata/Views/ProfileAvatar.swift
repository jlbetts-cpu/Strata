import SwiftUI

/// The profile picture at the top of Profile: your head, a photo, initials,
/// or a glyph — in that order of preference, the head only when switched on.
///
/// No rim and no shadow. A hairline only on the photograph, so a pale picture
/// does not dissolve into a pale page; initials sit on a fill that adapts
/// with the scheme, with ink that adapts with it, so their contrast holds in
/// both (see CLAUDE.md, *An ink is not a surface*).
struct ProfileAvatar: View {
    let side: CGFloat

    /// Crown to chin as a share of the circle. The head sits whole in the
    /// middle, hair clear of the edge.
    static let headShare: CGFloat = 0.76

    /// **The app has one hairline and this file was drawing a second one.**
    /// `docs/design-system-future.md` section 6: a hairline is `1 / displayScale`
    /// in ink at low alpha. `PlanSheet`, `FilmLookTray` and the map's panels all
    /// do exactly that; these two circles were the only places in the app using
    /// `GridConstants.headerDividerHeight` (a flat 0.5) as a stroke width, which
    /// is a hairline on a 2x phone and 50% too heavy on a 3x one. A line that is
    /// only a hairline on some phones is the hedge, not the number.
    @Environment(\.displayScale) private var displayScale

    private var store: ProfileStore { .shared }

    /// What the circle is made of when no photograph fills it.
    ///
    /// A chosen colour is `ProfileStore.backgroundStyle`'s own lit fill, and
    /// with no colour that property is `AppColors.quietFill`. It used to fall
    /// back to `.quaternary`, measured (203, 203, 202) on a 247 page, which is
    /// a system hierarchical grey and 1.51:1; this view carried a shim around
    /// it for a few hours and the default itself is right now, so the shim is
    /// gone. See `ProfileStore.backgroundStyle`.
    private var ground: AnyShapeStyle { store.backgroundStyle }

    /// **No rim.** It had `BlockRim`, so an avatar would be the same kind of
    /// object as a block — and the owner's call on this screen is the platform's
    /// look, not ours. A lit edge is a block's claim to be a thing you built;
    /// a profile picture is not one.
    ///
    var body: some View {
        if let head = HeadStore.shared.headForPicture {
            ZStack {
                // The same ground as the empty circle below, for the same
                // reason: a head's crown-to-chin is 0.76 of the circle, so what
                // shows around it is this ring, and it was `.quaternary` here
                // too.
                Circle().fill(ground)
                // Expressive: on Profile the head is the subject of the page.
                LivingHeadView(rig: head, side: side * Self.headShare, liveliness: .expressive, traceID: "profile")
            }
            .frame(width: side, height: side)
            .clipShape(Circle())
            .accessibilityHidden(true)
        } else if let photo = store.photo {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: side, height: side)
                .clipShape(Circle())
                .overlay {
                    // One hairline, one token. See `displayScale` above.
                    Circle().strokeBorder(GridConstants.fillHairline,
                                          lineWidth: 1 / displayScale)
                }
                .accessibilityHidden(true)
        } else {
            ZStack {
                // **An empty slot, in the app's own word for one.**
                //
                // With no colour chosen this drew `ProfileStore.backgroundStyle`,
                // which falls back to `.quaternary`. Measured off the built
                // sheet, that renders (203, 203, 202) on a (247, 247, 247) page:
                // a mid-grey blob 88pt across, 1.51:1 against the ground, and a
                // system hierarchical grey rather than a colour from the palette.
                // `ProfileView`'s own "no colour" swatch, ten points below this
                // on the same screen, refuses `.quaternary` by name and says why:
                // section 8 of `docs/design-system-future.md` will not take a
                // colour that is neither in `AppColors` nor read off content.
                //
                // The app already has a word for a slot with nothing in it yet,
                // and the swatch below cites it: `quietFill` with a faint
                // `slotInk` outline, the weight `AddWinSheet`'s empty photo well
                // uses. Borrowed rather than invented. `quietFill` composites to
                // (232, 232, 232) here and the glyph inside it still measures
                // 5.05:1, so what identifies the control is the figure, which is
                // the thing a person is actually looking for.
                //
                // It matters because this circle is reserved: `docs/illustrations.md`
                // has a shoulders-up drawing landing in it, flat ink, and flat
                // ink wants a ground to sit on rather than a grey disc already
                // doing the drawing's job.
                //
                // A chosen colour keeps its own fill and takes no outline. A
                // colour is a surface; it does not need an edge drawn round it.
                Circle().fill(ground)
                if store.background == nil {
                    Circle().strokeBorder(AppColors.slotInk.opacity(0.26),
                                          lineWidth: GridConstants.strokeThin)
                }
                if store.initials.isEmpty {
                    Image(systemName: "person.fill")
                        // A fixed size on purpose, and one of the exceptions
                        // `Typography` names: this glyph is a fraction of a
                        // circle the caller solved for, so it scales with the
                        // circle rather than with Dynamic Type. The circle is
                        // twice the header button, which is where the 88 on
                        // Profile comes from.
                        .font(.system(size: side * 0.42, weight: .medium))
                        .foregroundStyle(store.background == nil ? AppColors.inkSecondary : store.initialsInk)
                } else {
                    Text(store.initials)
                        .font(Typography.screenTitle)
                        .foregroundStyle(store.initialsInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(GridConstants.gapTight)
                }
            }
            .frame(width: side, height: side)
            .accessibilityHidden(true)
        }
    }
}

/// The profile picture as a header button, beside the other glass buttons.
///
/// **Built on `GlassIconButton`'s own skeleton** — a 17pt SF Symbol in a 44pt
/// frame — so it lands exactly where the Photographs button beside it does,
/// whichever way a header aligns its row. The glyph is drawn clear whenever
/// there is a picture: it is there to be measured.
struct ProfileButton: View {
    let action: () -> Void

    /// The same one hairline as `ProfileAvatar`, for the same reason.
    @Environment(\.displayScale) private var displayScale

    private var store: ProfileStore { .shared }
    private let side = GlassIconButton.defaultSide

    /// Whether the label is drawn on Liquid Glass, mirroring `label` below.
    private var isGlass: Bool {
        if HeadStore.shared.headForPicture != nil { return store.background == nil }
        if store.photo != nil { return false }
        return store.background == nil || store.initials.isEmpty
    }

    var body: some View {
        Button {
            HapticsEngine.lightTap()
            action()
        } label: {
            label
        }
        // **Glass answers a press on its own; a photograph and a colour do
        // not** (2026-10-02, the motion pass). Under `.plain` the two
        // variants with no glass behind them, your photograph and a chosen
        // colour, did nothing at all under a finger while every other button
        // in the header gave. They take the app's surface press; the glass
        // variants keep `.plain` so the press is not answered twice.
        .buttonStyle(isGlass ? PressResponse(scale: 1, dim: 1) : .pressSurface)
        .accessibilityLabel("Profile")
    }

    @ViewBuilder
    private var label: some View {
        let head = HeadStore.shared.headForPicture
        // Hollow, beside the hollow `play` and `map` in the Memories header
        // (the cohesion pass, 2026-10-05, visual-cohesion §4.3: fill means
        // selected). The large placeholder on Profile itself stays filled:
        // it is a picture of a person, not a button.
        let glyph = Image(systemName: "person")
            .font(Typography.bodyLarge.weight(.medium))
            .foregroundStyle(head == nil && store.photo == nil && store.initials.isEmpty ? Color.primary : .clear)
            .frame(width: side, height: side)

        if let head {
            // Calm: in a header the head blinks and glances and nothing more
            // (plan §5.3), because a face pulling expressions in a corner
            // pulls the eye from the page it sits on.
            let face = glyph
                .overlay {
                    LivingHeadView(rig: head, side: side * ProfileAvatar.headShare, liveliness: .calm, traceID: "header")
                        .frame(width: side, height: side)
                        .clipShape(Circle())
                }
                .contentShape(Circle())
            if store.background == nil {
                face.glassCircle()
            } else {
                // A chosen colour is the picture's own background, as in
                // Profile; glass would wash it out.
                face.background(Circle().fill(store.backgroundStyle))
            }
        } else if let photo = store.photo {
            // A photograph is its own surface. Glass behind it would only show
            // at the anti-aliased edge, as a grey fringe.
            glyph
                .overlay {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: side, height: side)
                        .clipShape(Circle())
                        .overlay {
                            Circle().strokeBorder(GridConstants.fillHairline,
                                                  lineWidth: 1 / displayScale)
                        }
                }
                .contentShape(Circle())
        } else {
            let mark = glyph
                .overlay {
                    if !store.initials.isEmpty {
                        Text(store.initials)
                            .font(Typography.headerSmall)
                            .foregroundStyle(store.background == nil ? Color.primary : store.initialsInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
                .contentShape(Circle())
            if store.background == nil || store.initials.isEmpty {
                mark.glassCircle()
            } else {
                mark.background(Circle().fill(store.backgroundStyle))
            }
        }
    }
}
