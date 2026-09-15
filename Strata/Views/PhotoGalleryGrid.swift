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
    /// Where the viewer should appear to come FROM.
    ///
    /// Given one, each cell becomes a zoom source and the viewer grows out of
    /// the thumbnail you tapped instead of sliding up over the page. That is
    /// the difference between a photo app and a screen that presents a sheet:
    /// the picture you touched is the picture that opens, and nothing else
    /// moves.
    var transitionNamespace: Namespace.ID?
    var onSelect: (GalleryPhoto) -> Void = { _ in }
    /// The screen's own title. When the grid is ONE section whose heading
    /// says the same thing ("August" over "AUGUST"), the heading is dropped:
    /// the same fact twice is the mistake the tower header already made once.
    var screenTitle: String?

    /// Whether the only section's heading repeats the screen's title.
    static func headingRepeatsTitle(_ sections: [GallerySection], title: String?) -> Bool {
        guard sections.count == 1, let title, !title.isEmpty else { return false }
        return sections[0].title.localizedCaseInsensitiveCompare(title) == .orderedSame
    }

    /// Two points, the way a camera roll does it.
    ///
    /// Not the tower's 4pt gutter and not `gapItem`'s 12. A gutter that reads
    /// as spacing turns a wall of pictures into a set of cards; the camera
    /// roll's hairline is there only so two photographs of the same colour do
    /// not merge into one.
    private static let gutter: CGFloat = 2

    /// The grid's own width, measured once rather than by a `GeometryReader`
    /// in every cell. See `cell`.
    @State private var gridWidth: CGFloat = 0

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Self.gutter), count: 3)
    }

    var body: some View {
        // **Not pinned.**
        //
        // These headings used to stick to the top and float over the
        // photographs as they passed under, which the owner saw on a place
        // screen and put plainly: "why is it scrolling, doesnt look good and
        // no point". Both halves are right. It looks bad because a heading
        // hovering over photographs needs a ground to stay legible, and any
        // ground you give it is a bar drawn across somebody's pictures. And it
        // is pointless because a pinned heading answers "which month am I in",
        // a question this grid does not raise: you are not navigating a
        // calendar, you are looking through a roll of pictures.
        //
        // Unpinned they do what a heading does — they mark where one run ends
        // and the next begins, then scroll away with it.
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(sections) { section in
                Section {
                    LazyVGrid(columns: columns, spacing: Self.gutter) {
                        ForEach(section.photos) { photo in
                            cell(photo)
                        }
                    }
                } header: {
                    if !Self.headingRepeatsTitle(sections, title: screenTitle) {
                        heading(section.title)
                    }
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { gridWidth = $0 }
    }

    /// Pinned, like Photos. The month you are inside stays named while you
    /// scroll through it, which is the entire job of the heading — unpinned it
    /// answers the question only at the moment you have already scrolled past
    /// the answer.
    private func heading(_ title: String) -> some View {
        SectionHeading(text: title)
    }

    private func cell(_ photo: GalleryPhoto) -> some View {
        Button {
            HapticsEngine.lightTap()
            onSelect(photo)
        } label: {
            // **A square from the grid's width, not a `GeometryReader` per
            // cell.** Three flexible columns with two gutters are each a third
            // of what is left, which is the width the reader used to report —
            // and the width still has to be handed over, because it is what
            // the photograph is decoded at.
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if gridWidth > 0 {
                        let side = (gridWidth - Self.gutter * 2) / 3
                        CachedImageView(fileName: photo.fileName, width: side,
                                        height: side, cornerRadius: 0)
                            .frame(width: side, height: side)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(photo.title ?? "Photo")
        .matchedTransitionSource(id: photo.id, in: transitionNamespace)
    }
}

