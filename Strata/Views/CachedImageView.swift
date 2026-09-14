import SwiftUI

struct CachedImageView: View {
    let fileName: String?
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    var fullResolution: Bool = false
    /// **Which part of the photograph to show**, as a fraction of the
    /// photograph away from its middle, chosen by dragging the crop on the
    /// camera's review. Zero is centred, which is every picture nobody moved.
    ///
    /// The picture fills the frame and the frame cuts it, so only the
    /// overflowing axis can move at all. Sliding the window right means
    /// sliding the picture left, which is the minus below.
    var crop: CGPoint = .zero

    /// The full-resolution picture, for the viewer. Thumbnails come from
    /// `ThumbnailStore` instead — see `body`.
    @State private var fullImage: UIImage?
    @State private var fullFailed = false
    @Environment(\.displayScale) private var displayScale
    /// Whether to draw a grey box while the photograph decodes.
    ///
    /// **Off inside a block.** A block already has something to show while it
    /// waits — its colour, which is what a block IS. Filling it with grey
    /// first put the rim, the blurred band, the caption veil and the title on
    /// top of a placeholder instead of on top of the block, and the whole
    /// stack read as broken: "it shows the blur and all the elements before
    /// the picture so it looks like they are all layering over a grey box."
    ///
    /// On in the gallery and the album covers, where the cell has nothing of
    /// its own and an empty square reads as a missing photograph rather than
    /// an arriving one.
    var showsPlaceholder = true
    /// The width to decode at, when it is not the width drawn. For a view whose
    /// size changes while it is on screen: one decode at the largest size
    /// serves every smaller one. See `PlaceBlock.decodeWidth`.
    var decodeWidth: CGFloat? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// **Asked for while drawing, not when appearing.**
    ///
    /// `.task` never ran for a photograph inside a tower block, so the load
    /// was never even requested and every block kept its colour. Reading the
    /// store here both returns what is in memory and schedules what is not,
    /// and the store's `version` brings the view back when it lands. See
    /// `ThumbnailStore`.
    private var shown: (image: UIImage?, missing: Bool) {
        guard let fileName else { return (nil, false) }
        if fullResolution { return (fullImage, fullFailed) }
        return ThumbnailStore.shared.state(for: fileName, width: (decodeWidth ?? width) * displayScale)
    }

    var body: some View {
        let state = shown
        let image = state.image
        let loadFailed = state.missing
        return Group {
            if let image {
                let drawn = filled(image.size)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .offset(x: -crop.x * drawn.width, y: -crop.y * drawn.height)
                    .frame(width: width, height: height)
                    .clipped()
                    .transition(reduceMotion ? .identity : .opacity.animation(GridConstants.imageFadeIn))
            } else if loadFailed {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppColors.quietFill)
                    .frame(width: width, height: height)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: min(width, height) * 0.25, weight: .regular))
                            .foregroundStyle(AppColors.inkQuiet)
                    )
                    .accessibilityLabel("Photo missing")
            } else if fileName != nil, showsPlaceholder {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppColors.quietFill)
                    .frame(width: width, height: height)
                    .modifier(ShimmerModifier())
                    // **Leaves at once, not on a fade.** It faded out over
                    // 0.15s while the image faded in over 0.25s, so both were
                    // partly transparent at the same moment and what is under
                    // the view showed through the middle of the handover
                    // (CLAUDE.md: a crossfade must never reveal what is under
                    // it). Now there is one fading layer, the picture.
                    .transition(.identity)
            }
        }
        .animation(reduceMotion ? nil : GridConstants.imageFadeIn, value: image != nil)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        // Only the viewer's full-resolution read needs a lifecycle: it is one
        // picture, on a screen that has certainly appeared.
        .task(id: fullResolution ? fileName : nil) {
            await loadFullImage()
        }
    }

    /// How big the picture is drawn once it has filled the frame.
    private func filled(_ size: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else { return CGSize(width: width, height: height) }
        let scale = max(width / size.width, height / size.height)
        return CGSize(width: size.width * scale, height: size.height * scale)
    }

    private func loadFullImage() async {
        guard fullResolution, let fileName else { return }
        fullFailed = false
        fullImage = await ImageManager.shared.loadFullImage(fileName: fileName)
        fullFailed = fullImage == nil
    }
}
