import SwiftUI

struct CachedImageView: View {
    let fileName: String?
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    var fullResolution: Bool = false

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
        return ThumbnailStore.shared.state(for: fileName, width: width * displayScale)
    }

    var body: some View {
        let state = shown
        let image = state.image
        let loadFailed = state.missing
        return Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
                    .transition(reduceMotion ? .identity : .opacity.animation(.easeIn(duration: 0.25)))
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
                    .transition(reduceMotion ? .identity : .opacity.animation(.easeOut(duration: 0.15)))
            }
        }
        .animation(reduceMotion ? nil : .easeIn(duration: 0.25), value: image != nil)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        // Only the viewer's full-resolution read needs a lifecycle: it is one
        // picture, on a screen that has certainly appeared.
        .task(id: fullResolution ? fileName : nil) {
            await loadFullImage()
        }
    }

    private func loadFullImage() async {
        guard fullResolution, let fileName else { return }
        fullFailed = false
        fullImage = await ImageManager.shared.loadFullImage(fileName: fileName)
        fullFailed = fullImage == nil
    }
}
