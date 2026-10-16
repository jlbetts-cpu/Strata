import SwiftUI

/// One picture in a profile's banner: one of your own wins, or a friend's
/// shared one.
enum BannerPicture: Hashable {
    case mine(String)
    case theirs(URL)
}

/// **The banner at the top of a profile** (the owner, 2026-10-16: "a little
/// banner on the top of Memories, with previous wins, automatic but you are
/// able to edit it ... for other people's profiles too, to add that
/// personable element and make the app feel more alive").
///
/// **On the tower's own grid** ("make sure the banner fits like the blocks,
/// and if they don't have photos in the slots, make sure it is the lattice
/// for those empty spots"): four columns at the tower's cell and gap, two
/// rows, four slots placed as blocks are, a tall one, two small stacked and
/// a large square. The newest photograph takes the large one. A slot with
/// no photograph is the lattice's own panes, so a new account's banner is
/// the empty tower waiting, not a hole. No shadow; the hairline the owner
/// likes round each photograph.
struct ProfileBanner: View {
    let pictures: [BannerPicture]
    static let most = 4
    private let gap = GridConstants.spacing

    /// The four slots, in the order photographs fill them: the large square
    /// first, then the tall one, then the two small.
    private static let slots: [(column: Int, row: Int, columns: Int, rows: Int)] = [
        (2, 0, 2, 2), (0, 0, 1, 2), (1, 0, 1, 1), (1, 1, 1, 1),
    ]

    /// The tower's cell for this width, as `TowerLattice` and every block
    /// are measured.
    static func cell(for width: CGFloat) -> CGFloat {
        let columns = CGFloat(GridConstants.columnCount)
        return (width - (columns - 1) * GridConstants.spacing) / columns
    }

    static func height(for width: CGFloat) -> CGFloat { cell(for: width) * 2 + GridConstants.spacing }

    @State private var width: CGFloat = 0

    var body: some View {
        // Exactly two rows of the tower for whatever width it is given.
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: max(Self.height(for: width), 1))
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .overlay(alignment: .topLeading) { grid }
            .accessibilityHidden(true)
    }

    private var grid: some View {
        GeometryReader { geo in
            let cell = Self.cell(for: geo.size.width)
            ZStack(alignment: .topLeading) {
                ForEach(Array(Self.slots.enumerated()), id: \.offset) { index, slot in
                    let f = GridConstants.blockFrame(column: slot.column, row: slot.row,
                                                     columnSpan: slot.columns, rowSpan: slot.rows, cellSize: cell)
                    Group {
                        if index < pictures.count {
                            tile(pictures[index], f.width, f.height)
                        } else {
                            panes(columns: slot.columns, rows: slot.rows, cell: cell)
                        }
                    }
                    .frame(width: f.width, height: f.height)
                    .offset(x: f.minX, y: f.minY)
                }
            }
        }
    }

    /// The lattice's empty cells, one pane a cell, as the tower draws them.
    private func panes(columns: Int, rows: Int, cell: CGFloat) -> some View {
        let radius = GridConstants.blockCornerRadius(forCell: cell)
        return VStack(spacing: gap) {
            ForEach(0..<rows, id: \.self) { _ in
                HStack(spacing: gap) {
                    ForEach(0..<columns, id: \.self) { _ in
                        // The lattice's shape in the quiet grey: on the
                        // profile card, the lattice's white panes were white
                        // on white.
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(AppColors.quietFill)
                            .frame(width: cell, height: cell)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tile(_ picture: BannerPicture, _ w: CGFloat, _ h: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous)
        Group {
            switch picture {
            case let .mine(file):
                CachedImageView(fileName: file, width: w, height: h, cornerRadius: GridConstants.cornerRadius)
            case let .theirs(url):
                CrewPhotoView(url: url, width: w, height: h)
                    .clipShape(shape)
            }
        }
        .frame(width: w, height: h)
        .overlay(shape.strokeBorder(AppColors.inkPrimary.opacity(0.08), lineWidth: GridConstants.strokeThin))
    }
}
