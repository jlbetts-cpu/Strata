import SwiftUI

/// **A month, opened** (the owner, 2026-10-16: "you should be able to click
/// into the month, and that's where all the photos should be, the deep,
/// medium and small"; then, "we should still stick to the Apple Photos look
/// for easy showing", the Hinge cards being for featured wins alone). The
/// month's photographs as the camera roll shows them, edge to edge, grouped
/// Deep, Regular and Quick. A tap opens the viewer.
struct MonthPhotosPage: View {
    let title: String
    let month: GallerySection?
    var onSelect: (GalleryPhoto) -> Void

    private var sections: [GallerySection] {
        guard let month else { return [] }
        let split = Album.sizeSections(month)
        return split.isEmpty ? [month] : split
    }

    var body: some View {
        ScrollView {
            PhotoGalleryGrid(sections: sections, onSelect: onSelect, screenTitle: title,
                             headingAir: GridConstants.gapSection)
                .padding(.bottom, GridConstants.tabBarClearance)
        }
        .background { WarmBackground().ignoresSafeArea() }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .glassBackButton()
    }
}
