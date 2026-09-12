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

    private var store: ProfileStore { .shared }

    var body: some View {
        if let head = HeadStore.shared.headForPicture {
            ZStack {
                Circle().fill(store.backgroundStyle)
                // Expressive: on Profile the head is the subject of the page.
                LivingHeadView(rig: head, side: side * Self.headShare, liveliness: .expressive)
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
                    Circle().strokeBorder(Color.primary.opacity(0.08),
                                          lineWidth: GridConstants.headerDividerHeight)
                }
                .accessibilityHidden(true)
        } else {
            ZStack {
                Circle().fill(store.backgroundStyle)
                if store.initials.isEmpty {
                    Image(systemName: "person.fill")
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

    private var store: ProfileStore { .shared }
    private let side = GlassIconButton.defaultSide

    var body: some View {
        Button {
            HapticsEngine.lightTap()
            action()
        } label: {
            label
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profile")
    }

    @ViewBuilder
    private var label: some View {
        let head = HeadStore.shared.headForPicture
        let glyph = Image(systemName: "person.fill")
            .font(Typography.bodyLarge.weight(.medium))
            .foregroundStyle(head == nil && store.photo == nil && store.initials.isEmpty ? Color.primary : .clear)
            .frame(width: side, height: side)

        if let head {
            // Calm: in a header the head blinks and glances and nothing more
            // (plan §5.3), because a face pulling expressions in a corner
            // pulls the eye from the page it sits on.
            let face = glyph
                .overlay {
                    LivingHeadView(rig: head, side: side * ProfileAvatar.headShare, liveliness: .calm)
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
                            Circle().strokeBorder(Color.primary.opacity(0.08),
                                                  lineWidth: GridConstants.headerDividerHeight)
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
