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

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
                    .transition(.opacity.animation(.easeIn(duration: 0.25)))
            } else if loadFailed {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: width, height: height)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: min(width, height) * 0.25, weight: .light))
                            .foregroundStyle(.secondary.opacity(0.5))
                    )
            } else if fileName != nil {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: width, height: height)
                    .modifier(ShimmerModifier())
                    .transition(.opacity.animation(.easeOut(duration: 0.15)))
            }
        }
        .animation(.easeIn(duration: 0.25), value: image != nil)
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
