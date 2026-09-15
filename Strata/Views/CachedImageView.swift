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
    /// The file whose picture has finished fading in, so its placeholder
    /// underneath can go. See `body`.
    @State private var settledFileName: String?
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
    /// and this photograph's slot in the store brings the view back when it
    /// lands — this view is invalidated by its own photograph and no other.
    /// See `ThumbnailStore`.
    private var shown: (image: UIImage?, missing: Bool) {
        guard let fileName else { return (nil, false) }
        if fullResolution { return (fullImage, fullFailed) }
        return ThumbnailStore.shared.state(for: fileName, width: (decodeWidth ?? width) * displayScale)
    }

    var body: some View {
        #if DEBUG
        let _ = PerfProbe.count("CachedImageView")
        #endif
        let state = shown
        let image = state.image
        let loadFailed = state.missing
        // **Stacked, not either/or.** The placeholder stays UNDER the
        // photograph, at full strength, until the photograph has finished
        // fading in, and only then leaves. As exclusive branches one of them
        // had to go first: fading both crossed two half-transparent layers,
        // and removing the placeholder at once left the picture fading in
        // over nothing for 250ms, which in the edge-to-edge gallery is the
        // page ground flashing through a cold thumbnail (CLAUDE.md: a
        // crossfade must never reveal what is under it). Callers with
        // `showsPlaceholder` off are unchanged: a block's own colour is what
        // the picture fades in over.
        let holdsPlaceholder = fileName != nil && showsPlaceholder && !loadFailed
            && (image == nil || settledFileName != fileName)
        return ZStack {
            if holdsPlaceholder {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppColors.quietFill)
                    .frame(width: width, height: height)
                    .modifier(ShimmerModifier())
                    // It leaves only once the picture on top is opaque, so
                    // leaving at once is invisible.
                    .transition(.identity)
            }
            if let image {
                let shift = Self.shift(crop: crop, photo: image.size, frame: CGSize(width: width, height: height))
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .offset(x: shift.width, y: shift.height)
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
            }
        }
        .animation(reduceMotion ? nil : GridConstants.imageFadeIn, value: image != nil)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        // Only the viewer's full-resolution read needs a lifecycle: it is one
        // picture, on a screen that has certainly appeared.
        .task(id: fullResolution ? fileName : nil) {
            await loadFullImage()
        }
        // Retire the placeholder once the picture has faded in over it. Keyed
        // on the file that arrived, so a reused cell showing a different
        // photograph gets its placeholder back. If this task never runs, the
        // placeholder simply stays hidden under an opaque picture.
        .task(id: (showsPlaceholder && image != nil) ? fileName : nil) {
            guard showsPlaceholder, image != nil, let fileName, settledFileName != fileName else { return }
            if !reduceMotion {
                try? await Task.sleep(for: .seconds(GridConstants.imageFadeInDuration))
                guard !Task.isCancelled else { return }
            }
            settledFileName = fileName
        }
    }

    /// How big the picture is drawn once it has filled the frame.
    nonisolated static func filled(_ photo: CGSize, in frame: CGSize) -> CGSize {
        guard photo.width > 0, photo.height > 0 else { return frame }
        let scale = max(frame.width / photo.width, frame.height / photo.height)
        return CGSize(width: photo.width * scale, height: photo.height * scale)
    }

    /// **How far the picture moves inside the frame** for a window moved by
    /// `crop`. Sliding the window right means sliding the picture left, which
    /// is the minus. `ReplayFrame` and `FlippableBlockView` do the same.
    nonisolated static func shift(crop: CGPoint, photo: CGSize, frame: CGSize) -> CGSize {
        let drawn = filled(photo, in: frame)
        return CGSize(width: -crop.x * drawn.width, height: -crop.y * drawn.height)
    }

    /// **What the block ends up showing**, in fractions of the photograph: the
    /// picture filled into the frame, moved by `shift`, and cut by the frame.
    /// The camera's review draws its hairline over the same rectangle
    /// (`BlockCropOutline`), so the two must agree.
    nonisolated static func visibleRect(crop: CGPoint, photo: CGSize, frame: CGSize) -> CGRect {
        let drawn = filled(photo, in: frame)
        guard drawn.width > 0, drawn.height > 0 else { return CGRect(x: 0, y: 0, width: 1, height: 1) }
        let shift = shift(crop: crop, photo: photo, frame: frame)
        return CGRect(x: ((drawn.width - frame.width) / 2 - shift.width) / drawn.width,
                      y: ((drawn.height - frame.height) / 2 - shift.height) / drawn.height,
                      width: frame.width / drawn.width, height: frame.height / drawn.height)
    }

    private func loadFullImage() async {
        guard fullResolution, let fileName else { return }
        fullFailed = false
        fullImage = await ImageManager.shared.loadFullImage(fileName: fileName)
        fullFailed = fullImage == nil
    }
}
