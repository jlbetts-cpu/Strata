import SwiftUI
import UIKit

/// Choosing a look, on the photograph you just took.
///
/// **Your own picture, four times.** A row of named swatches would be a guess;
/// these are the actual shot with each look on it, which is the only way to
/// choose one. They are rendered small and off the main actor, so opening the
/// review is never slower for having them.
///
/// The row sits above Retake and Use Photo, on the camera's dark ground, and
/// says nothing until there is a photograph to show.
struct FilmLookStrip: View {
    let photo: UIImage
    @Binding var selection: FilmLook.Kind

    @State private var previews: [FilmLook.Kind: UIImage] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Big enough to judge a look on, small enough that four of them fit a
    /// phone with room either side.
    private static let side: CGFloat = 58
    /// What the previews are rendered at: the swatch at 3x, and no more.
    private static let renderSide: CGFloat = 180

    var body: some View {
        HStack(spacing: GridConstants.gapTight) {
            ForEach(FilmLook.all) { look in
                swatch(look)
            }
        }
        .frame(maxWidth: .infinity)
        .task(id: photo) { await makePreviews() }
    }

    private func swatch(_ look: FilmLook) -> some View {
        let isChosen = selection == look.kind
        return Button {
            guard selection != look.kind else { return }
            HapticsEngine.tick()
            withAnimation(reduceMotion ? nil : GridConstants.motionSnappy) {
                selection = look.kind
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    if let preview = previews[look.kind] {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFill()
                    } else {
                        // The picture is the placeholder: a grey box under a
                        // photograph is the thing `CachedImageView` records
                        // looking broken.
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .opacity(0.5)
                    }
                }
                .frame(width: Self.side, height: Self.side)
                .clipShape(RoundedRectangle(cornerRadius: GridConstants.blockCornerRadius(forCell: Self.side),
                                            style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: GridConstants.blockCornerRadius(forCell: Self.side),
                                     style: .continuous)
                        .strokeBorder(isChosen ? AppColors.onDarkStrong : AppColors.onDarkFaint,
                                      lineWidth: isChosen ? 2 : 1)
                }
                .scaleEffect(isChosen ? 1 : 0.94)

                Text(look.kind.name)
                    .font(Typography.caption)
                    .foregroundStyle(isChosen ? AppColors.onDarkStrong : AppColors.onDarkQuiet)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(look.kind.describedAs)
        .accessibilityAddTraits(isChosen ? [.isSelected] : [])
    }

    /// Renders the four swatches once per photograph, off the main actor.
    private func makePreviews() async {
        let source = photo
        let made = await Task.detached(priority: .userInitiated) { () -> [FilmLook.Kind: UIImage] in
            let small = source.scaledDown(to: FilmLookStrip.renderSide)
            var out: [FilmLook.Kind: UIImage] = [:]
            for look in FilmLook.all {
                out[look.kind] = look.kind == .none
                    ? small : FilmLookRenderer.shared.render(small, look: look)
            }
            return out
        }.value
        previews = made
    }
}

extension UIImage {
    /// A copy no bigger than `side` on its longest edge, for a preview.
    func scaledDown(to side: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > side else { return uprighted() }
        let factor = side / longest
        let target = CGSize(width: size.width * factor, height: size.height * factor)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
