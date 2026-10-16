import SwiftUI

/// **A month, opened** (the owner, 2026-10-16: "the way you can click into
/// the profile, you should be able to click into the month, and that's where
/// all the photos should be, the deep, medium and small ... I want the Hinge
/// treatment, full sized, in a container"). The month's photographed wins
/// as cards, each a container with the win's name inside at its top and the
/// photograph full width under it; Deep, Regular and Quick a tap apart at
/// the top, all of them by default. A tap opens the viewer.
struct MonthPhotosPage: View {
    let title: String
    let month: GallerySection?
    var onSelect: (GalleryPhoto) -> Void

    enum Size: String, CaseIterable, Identifiable {
        case all, hard, medium, small
        var id: String { rawValue }
        var name: String {
            switch self {
            case .all: "All"
            case .hard: BlockSize.hard.effortLabel
            case .medium: BlockSize.medium.effortLabel
            case .small: BlockSize.small.effortLabel
            }
        }
        var block: BlockSize? {
            switch self {
            case .all: nil
            case .hard: .hard
            case .medium: .medium
            case .small: .small
            }
        }
    }

    @State private var size: Size = .all
    private let hPad = GridConstants.horizontalPadding

    private var photos: [GalleryPhoto] {
        let all = (month?.photos ?? []).filter { $0.block == nil }
        // Deep first, as the tower's own order is, when all are shown.
        guard let block = size.block else {
            return Album.sizeOrder.flatMap { s in all.filter { $0.size == s } }
        }
        return all.filter { $0.size == block }
    }

    /// Only the sizes this month has, so no choice leads to nothing.
    private var sizes: [Size] {
        let has = Set((month?.photos ?? []).map(\.size))
        return [.all] + Size.allCases.dropFirst().filter { $0.block.map(has.contains) ?? false }
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width - hPad * 2
            ScrollView {
                LazyVStack(spacing: GridConstants.gapSection) {
                    if sizes.count > 2 {
                        GlassChoiceBar(items: sizes, chosen: size, title: { $0.name }, spoken: { $0.name },
                                       choose: { picked in
                                           HapticsEngine.tick()
                                           withAnimation(GridConstants.motionSnappy) { size = picked }
                                       }, fills: true)
                    }
                    ForEach(photos) { photo in
                        card(photo, width: width)
                    }
                }
                .padding(.horizontal, hPad)
                .padding(.top, GridConstants.gapItem)
                .padding(.bottom, GridConstants.tabBarClearance)
            }
        }
        .background { WarmBackground().ignoresSafeArea() }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .glassBackButton()
    }

    /// The win's name inside the card's top, the day and size quiet beside
    /// it; then the photograph, full width, at the portrait 4:5 a feed uses.
    private func card(_ photo: GalleryPhoto, width: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous)
        return Button {
            HapticsEngine.lightTap()
            onSelect(photo)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: GridConstants.gapItem) {
                    Text(photo.title ?? "A win")
                        .font(Typography.headerMedium)
                        .foregroundStyle(AppColors.inkPrimary)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    Text(photo.date.formatted(.dateTime.month(.abbreviated).day()) + " \u{00B7} " + photo.size.effortLabel)
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(AppColors.inkSecondary)
                        .fixedSize()
                }
                .padding(GridConstants.horizontalPadding)
                CachedImageView(fileName: photo.fileName, width: width, height: width * 1.25, cornerRadius: 0)
                    .frame(width: width, height: width * 1.25)
            }
            .pageCard()
            .clipShape(shape)
            .contentShape(shape)
        }
        .buttonStyle(.pressSurface)
        .accessibilityLabel(photo.spokenName)
        .accessibilityHint("Opens it full screen.")
    }
}
