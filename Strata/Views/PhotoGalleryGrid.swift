import SwiftUI

/// Every photograph, newest first, under month headings.
///
/// The shape Snapchat's Memories and Apple's Photos both settle on, for the
/// same reason: past the most recent few days, a person looking for a picture
/// is scanning, and a scan wants a dense grid and an occasional date to orient
/// on. A list of day cards is the wrong instrument for that — it was what this
/// screen had, and it said nothing the month tower above it did not already
/// say better.
///
/// **A photograph carries its title.** Every picture in this app is a picture
/// OF something you did, and the word for it is already stored on the win.
/// Showing it costs a line and turns a wall of images into a record. A win
/// logged in one tap has no name, and those stay uncaptioned rather than
/// being labelled "Win".
struct PhotoGalleryGrid: View {
    let sections: [GallerySection]
    var onSelect: (GalleryPhoto) -> Void = { _ in }

    /// Three across, at the tower's own gutter, so the gallery sits on the
    /// same grid as everything else on the page.
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: GridConstants.spacing),
              count: 3)
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(sections) { section in
                Text(section.title)
                    .font(Typography.sectionLabel)
                    .kerning(Typography.sectionKerning)
                    .foregroundStyle(.primary.opacity(0.35))
                    .padding(.horizontal, GridConstants.horizontalPadding)
                    .padding(.top, 30)
                    .padding(.bottom, 12)

                LazyVGrid(columns: columns, spacing: GridConstants.spacing) {
                    ForEach(section.photos) { photo in
                        cell(photo)
                    }
                }
                .padding(.horizontal, GridConstants.horizontalPadding)
            }
        }
    }

    private func cell(_ photo: GalleryPhoto) -> some View {
        Button {
            HapticsEngine.lightTap()
            onSelect(photo)
        } label: {
            GeometryReader { geo in
                let side = geo.size.width
                CachedImageView(
                    fileName: photo.fileName,
                    width: side,
                    height: side,
                    cornerRadius: GridConstants.blockCornerRadius(forCell: side)
                )
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(
                    cornerRadius: GridConstants.blockCornerRadius(forCell: side),
                    style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    if let title = photo.title {
                        Text(title)
                            .font(Typography.photoCaption)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 7)
                            .padding(.bottom, 6)
                            // A scrim only where the text is. A full overlay
                            // dims every photograph to caption one line of it.
                            .background(alignment: .bottom) {
                                LinearGradient(
                                    colors: [.clear, .black.opacity(0.45)],
                                    startPoint: .top, endPoint: .bottom
                                )
                                .frame(height: side * 0.42)
                                .allowsHitTesting(false)
                            }
                    }
                }
                .clipShape(RoundedRectangle(
                    cornerRadius: GridConstants.blockCornerRadius(forCell: side),
                    style: .continuous))
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(photo.title ?? "Photo")
    }
}
