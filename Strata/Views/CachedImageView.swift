import SwiftUI

struct CachedImageView: View {
    let fileName: String?
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    var fullResolution: Bool = false

    @State private var image: UIImage?
    @State private var loadFailed = false
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

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
                    .transition(reduceMotion ? .identity : .opacity.animation(.easeIn(duration: 0.25)))
            } else if loadFailed {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: width, height: height)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: min(width, height) * 0.25, weight: .regular))
                            .foregroundStyle(.secondary.opacity(0.5))
                    )
                    .onTapGesture {
                        loadFailed = false
                        Task { await loadImage() }
                    }
                    .accessibilityLabel("Photo failed to load, tap to retry")
            } else if fileName != nil, showsPlaceholder {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: width, height: height)
                    .modifier(ShimmerModifier())
                    .transition(reduceMotion ? .identity : .opacity.animation(.easeOut(duration: 0.15)))
            }
        }
        .animation(reduceMotion ? nil : .easeIn(duration: 0.25), value: image != nil)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: fileName) {
            await loadImage()
        }
        .onDisappear {
            image = nil
        }
    }

    private func loadImage() async {
        guard let fileName else { return }
        loadFailed = false

        if fullResolution {
            image = await ImageManager.shared.loadFullImage(fileName: fileName)
        } else {
            let targetWidth = width * displayScale
            image = await ImageManager.shared.loadThumbnail(
                fileName: fileName,
                maxWidth: targetWidth
            )
        }

        if image == nil {
            loadFailed = true
        }
    }
}
