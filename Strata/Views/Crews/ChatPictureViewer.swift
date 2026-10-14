import SwiftUI

/// **A strip, picture or sticker in the chat, full screen** (M4,
/// `docs/qol-research-2026-10-13.md`; the owner, 2026-10-13). It was a 120
/// point strip nobody could open.
///
/// The photo viewer's own page (`PhotoPage`): the print on the black, pinch
/// or double tap to zoom, drag to pan while zoomed. Close on the left and ⋯
/// on the right, as `docs/ten.md` sets for the photo viewer, and at the foot
/// who sent it and when: "Sam, 4:12 PM". A drag down closes it.
///
/// **⋯ holds Share and Save to Photos only when it is yours.** A friend's
/// picture is theirs to keep: theirs offers Heart and Report. A strip sent
/// into a crew is always the sender's own (`StripStory.share` offers crews
/// only for your own strip), so nobody's photos leave in someone else's
/// hands.
struct ChatPictureViewer: View {
    let message: CrewMessage
    /// "You" or the friend's short name.
    let sender: String
    let mine: Bool
    let hearted: Bool
    let onClose: () -> Void
    var onHeart: () -> Void = {}
    var onReport: () -> Void = {}

    @State private var image: UIImage?
    @State private var zoomed = false
    @State private var drop: CGFloat = 0
    @State private var saving = false
    @State private var saved = false
    @State private var saveFailed = false

    /// How far a drag down goes before it closes.
    private static let closeAfter: CGFloat = 120
    private static let topInset: CGFloat = 58
    private static let footHeight: CGFloat = 56

    private var photo: GalleryPhoto {
        GalleryPhoto(fileName: message.sketch?.lastPathComponent ?? message.messageID.uuidString,
                     title: nil, date: message.createdAt, dateString: message.crewDay)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                PhotoPage(photo: photo, image: image, isCurrent: true,
                          inset: GridConstants.horizontalPadding,
                          onZoomChanged: { zoomed = $0 })
                    .padding(.top, Self.topInset + GlassIconButton.defaultSide)
                    .offset(y: drop)
                    .opacity(1 - min(Double(drop / (Self.closeAfter * 3)), 0.5))
                Text("\(sender), \(ChatTimes.words(message.createdAt))")
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.onDarkQuiet)
                    .lineLimit(1)
                    .padding(.horizontal, GridConstants.horizontalPadding)
                    .frame(height: Self.footHeight, alignment: .top)
                    .padding(.bottom, GridConstants.gapSection)
            }
            VStack {
                HStack {
                    GlassIconButton(systemName: "xmark", tint: .white,
                                    accessibilityLabel: "Close photo", action: onClose)
                    Spacer(minLength: 0)
                    menu
                }
                .buttonStyle(.plain)
                .padding(.horizontal, GridConstants.horizontalPadding)
                .padding(.top, Self.topInset)
                Spacer(minLength: 0)
            }
            // The viewer is dark in both appearances, as the photo viewer
            // is, so its glass and inks answer to the black under them.
            .environment(\.colorScheme, .dark)
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .gesture(DragGesture(minimumDistance: 20)
            .onChanged { value in drop = max(0, value.translation.height) }
            .onEnded { value in
                if value.translation.height > Self.closeAfter {
                    onClose()
                } else {
                    withAnimation(GridConstants.motionSnappy) { drop = 0 }
                }
            }, isEnabled: !zoomed)
        .accessibilityAction(.escape) { onClose() }
        .photoSaveFailed($saveFailed)
        .task(id: message.messageID) {
            guard let url = message.sketch else { return }
            image = await Task.detached(priority: .userInitiated) { UIImage(contentsOfFile: url.path) }.value
        }
    }

    private var menu: some View {
        Menu {
            if mine {
                if let image {
                    ShareLink(item: Image(uiImage: image),
                              preview: SharePreview(message.isStrip ? "Photo Strip" : "Photo", image: Image(uiImage: image))) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
                Button { save() } label: {
                    Label(saved ? "Saved to Photos" : "Save to Photos",
                          systemImage: saved ? "checkmark" : "square.and.arrow.down")
                }
                .disabled(image == nil || saving || saved)
            } else {
                Button { onHeart() } label: {
                    Label(hearted ? "Remove Heart" : "Heart", systemImage: hearted ? "heart.slash" : "heart")
                }
                Button(role: .destructive) { onReport() } label: {
                    Label("Report", systemImage: "exclamationmark.bubble")
                }
            }
        } label: {
            GlassIconLabel(systemName: "ellipsis", tint: .white)
        }
        .accessibilityLabel("Photo actions")
    }

    private func save() {
        guard let image, !saving, !saved else { return }
        saving = true
        Task {
            let ok = await PhotoLibrarySaver.save(image, respectingPreference: false)
            saving = false
            if ok {
                saved = true
                HapticsEngine.success()
            } else {
                HapticsEngine.warning()
                saveFailed = true
            }
        }
    }
}
