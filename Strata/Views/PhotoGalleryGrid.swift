import SwiftUI

/// Every photograph, newest first, under month headings — the camera roll.
///
/// It used to be a grid of little blocks: rounded to the block radius, wearing
/// the block's white rim, spaced on the `gapItem` step, and captioned under
/// each picture with the win's title. Every one of those was defensible on its
/// own and together they made a photo grid that looked designed rather than
/// like photographs. The owner's call, from a phone: make it the camera roll.
///
/// So it is what Photos is. Edge to edge, three across, square, a two-point
/// hairline between them, no corner, no rim, no caption. The picture is the
/// only thing on screen and the grid is the thing you scan. The titles have
/// not been thrown away — they are on the photograph in the viewer, which is
/// where you are when you actually want to read one.
///
/// The month headings stay. Past the most recent few days a person looking for
/// a picture is scanning, and a scan wants an occasional date to orient on.
struct PhotoGalleryGrid: View {
    let sections: [GallerySection]
    var onSelect: (GalleryPhoto) -> Void = { _ in }

    /// Two points, the way a camera roll does it.
    ///
    /// Not the tower's 4pt gutter and not `gapItem`'s 12. A gutter that reads
    /// as spacing turns a wall of pictures into a set of cards; the camera
    /// roll's hairline is there only so two photographs of the same colour do
    /// not merge into one.
    private static let gutter: CGFloat = 2

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Self.gutter), count: 3)
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
            ForEach(sections) { section in
                Section {
                    LazyVGrid(columns: columns, spacing: Self.gutter) {
                        ForEach(section.photos) { photo in
                            cell(photo)
                        }
                    }
                } header: {
                    heading(section.title)
                }
            }
        }
    }

    /// Pinned, like Photos. The month you are inside stays named while you
    /// scroll through it, which is the entire job of the heading — unpinned it
    /// answers the question only at the moment you have already scrolled past
    /// the answer.
    private func heading(_ title: String) -> some View {
        Text(title)
            .font(Typography.sectionLabel)
            .kerning(Typography.sectionKerning)
            .foregroundStyle(.primary.opacity(0.55))
            .padding(.horizontal, GridConstants.horizontalPadding)
            .padding(.top, GridConstants.gapSection)
            .padding(.bottom, GridConstants.gapTight)
            .frame(maxWidth: .infinity, alignment: .leading)
            // A pinned header that is not opaque has the grid scrolling
            // through the type behind it.
            .background { WarmBackground() }
    }

    private func cell(_ photo: GalleryPhoto) -> some View {
        Button {
            HapticsEngine.lightTap()
            onSelect(photo)
        } label: {
            GeometryReader { geo in
                CachedImageView(fileName: photo.fileName, width: geo.size.width,
                                height: geo.size.width, cornerRadius: 0)
                    .frame(width: geo.size.width, height: geo.size.width)
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(photo.title ?? "Photo")
    }
}
