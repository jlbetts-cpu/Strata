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

    /// Three across.
    ///
    /// At the tower's 4pt gutter this read as cramped, and it was the wrong
    /// borrowing: blocks touch because touching is what makes them one object,
    /// and a set of photographs is not one object. `gapItem` is the step for
    /// things that merely sit beside each other.
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: GridConstants.gapItem),
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
                    .padding(.top, GridConstants.gapSection)
                    .padding(.bottom, GridConstants.gapLabel)

                LazyVGrid(columns: columns, spacing: GridConstants.gapItem) {
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
            VStack(alignment: .leading, spacing: 6) {
                thumbnail(photo)
                // The title sits UNDER the photograph, not on it.
                //
                // It was white text over a dark gradient, which is what every
                // photo grid does and exactly what this app does not: a block
                // is a flat colour under a white rim, and a smear of black up
                // the bottom of a picture is the one gesture in the app that
                // looks like it came from somewhere else. Underneath, the
                // caption reads better, the photograph is not dimmed to make
                // room for it, and the grid gains a rhythm the blocks already
                // have.
                Text(photo.title ?? " ")
                    .font(Typography.photoCaption)
                    .foregroundStyle(.primary.opacity(photo.title == nil ? 0 : 0.55))
                    .lineLimit(1)
                    .padding(.horizontal, 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(photo.title ?? "Photo")
    }

    private func thumbnail(_ photo: GalleryPhoto) -> some View {
        GeometryReader { geo in
            let side = geo.size.width
            let radius = GridConstants.blockCornerRadius(forCell: side)
            CachedImageView(fileName: photo.fileName, width: side,
                            height: side, cornerRadius: radius)
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay {
                    // A photograph in this app is a photograph on a BLOCK, and
                    // a block's edge is a white rim. The same one the tower's
                    // photo blocks wear.
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(.white.opacity(0.55),
                                      lineWidth: GridConstants.blockRimWidth
                                          * (side / GridConstants.blockReferenceCell))
                }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
