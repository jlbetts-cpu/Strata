import SwiftData
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
    private let gap = GridConstants.spacing

    typealias Slot = (column: Int, row: Int, columns: Int, rows: Int)

    /// **The banner's arrangements, as the tower's blocks combine** (the
    /// owner, 2026-10-16: "different combinations just how a tower can, two
    /// big blocks, medium across, two small ones"). Each fills the two rows
    /// of four exactly; slots in the order photographs fill them, the large
    /// first.
    static let layouts: [[Slot]] = [
        [(2, 0, 2, 2), (0, 0, 1, 2), (1, 0, 1, 1), (1, 1, 1, 1)],        // big, tall, two small
        [(0, 0, 2, 2), (2, 0, 2, 2)],                                    // two big
        [(0, 0, 2, 2), (2, 0, 1, 1), (3, 0, 1, 1), (2, 1, 1, 1), (3, 1, 1, 1)], // big and four small
        [(0, 0, 2, 2), (2, 0, 2, 1), (2, 1, 2, 1)],                      // big and two wide
        [(2, 0, 2, 2), (0, 0, 1, 2), (1, 0, 1, 2)],                      // two tall and big
        [(0, 0, 2, 1), (2, 0, 2, 1), (0, 1, 2, 1), (2, 1, 2, 1)],        // four wide
    ]
    static let most = 5

    var layout: Int = 0
    /// The slot being chosen for, in Edit Profile: outlined in ink.
    var selected: Int? = nil
    /// A tap on a slot (Edit Profile); nil, and the banner is a picture.
    var onTapSlot: ((Int) -> Void)? = nil

    private var slots: [Slot] { Self.layouts[min(max(layout, 0), Self.layouts.count - 1)] }

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
            .overlay(alignment: .topLeading) { if width > 0 { grid } }
            .accessibilityHidden(true)
    }

    private var grid: some View {
        GeometryReader { geo in
            let cell = Self.cell(for: geo.size.width)
            ZStack(alignment: .topLeading) {
                // **The empty slots, fading upward as the tower's lattice
                // does** (the owner, 2026-10-16: "the empty lattice has to
                // fade on the top like it does on the tower ... it should blend
                // in better with the back"). One layer for all of them, under
                // one fade, so the fade runs across the banner and not slot by
                // slot.
                ZStack(alignment: .topLeading) {
                    ForEach(Array(slots.enumerated()), id: \.offset) { index, slot in
                        if index >= pictures.count {
                            let f = frame(slot, cell)
                            panes(columns: slot.columns, rows: slot.rows, cell: cell)
                                .frame(width: f.width, height: f.height)
                                .offset(x: f.minX, y: f.minY)
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                .mask {
                    LinearGradient(stops: [.init(color: .clear, location: 0),
                                           .init(color: .black.opacity(0.55), location: 0.5),
                                           .init(color: .black, location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                }
                ForEach(Array(slots.enumerated()), id: \.offset) { index, slot in
                    let f = frame(slot, cell)
                    Group {
                        if index < pictures.count {
                            tile(pictures[index], f.width, f.height)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(width: f.width, height: f.height)
                    .overlay {
                        if selected == index {
                            RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous)
                                .strokeBorder(AppColors.inkPrimary, lineWidth: 2.5)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { onTapSlot?(index) }
                    .allowsHitTesting(onTapSlot != nil)
                    .offset(x: f.minX, y: f.minY)
                }
            }
        }
    }

    private func frame(_ slot: (column: Int, row: Int, columns: Int, rows: Int), _ cell: CGFloat) -> CGRect {
        GridConstants.blockFrame(column: slot.column, row: slot.row,
                                 columnSpan: slot.columns, rowSpan: slot.rows, cellSize: cell)
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

/// **Editing a month's banner, by its pictures** (the owner, 2026-10-16:
/// "the banner should be in the profile and you should edit it by picture,
/// make it easy and visible"; "different combinations ... and make it easy
/// to edit"). In Edit Profile itself, nothing over it: the banner large,
/// a tap on a slot to choose for it, the six arrangements under it to pick
/// from, and the month's photographs big enough to see, a tap putting one
/// in the chosen slot. Automatic goes back to the latest, the first layout.
struct BannerEditor: View {
    let month: Date
    @Query(filter: #Predicate<HabitLog> { $0.completed && $0.imageFileName != nil },
           sort: \HabitLog.createdAt, order: .reverse) private var photographed: [HabitLog]
    @State private var slot: Int? = 0
    private var store: ProfileStore { .shared }
    private var key: String { String(DateUtils.dateString(from: month).prefix(7)) }

    var body: some View {
        let _ = store.bannerChanged
        let key = key
        let files = photographed.filter { $0.dateString.hasPrefix(key) }.compactMap(\.imageFileName)
        let layout = store.bannerLayout(for: key)
        let count = ProfileBanner.layouts[layout].count
        let chosen = store.bannerFiles(for: key)
        let shown = chosen.isEmpty ? Array(files.prefix(count)) : chosen
        VStack(alignment: .leading, spacing: GridConstants.gapItem) {
            ProfileBanner(pictures: shown.prefix(count).map(BannerPicture.mine), layout: layout,
                          selected: files.isEmpty ? nil : slot, onTapSlot: { slot = $0; HapticsEngine.tick() })
            layouts(current: layout, files: files, shown: shown)
            if files.isEmpty {
                Text("Photographed wins this month fill it.")
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkSecondary)
            } else {
                photos(files, shown: Array(shown.prefix(count)), count: count)
                if !chosen.isEmpty || layout != 0 {
                    Button {
                        HapticsEngine.lightTap()
                        store.setBanner([], for: key)
                        store.setBannerLayout(0, for: key)
                        slot = 0
                    } label: {
                        Text("Automatic")
                            .font(Typography.bodyLarge)
                            .foregroundStyle(AppColors.inkPrimary)
                    }
                    .buttonStyle(.pressWord)
                }
            }
        }
    }

    /// The six arrangements, each drawn as its blocks, the one in use inked.
    private func layouts(current: Int, files: [String], shown: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: GridConstants.gapItem) {
                ForEach(ProfileBanner.layouts.indices, id: \.self) { index in
                    Button {
                        HapticsEngine.tick()
                        // The pictures already chosen carry over, as many as fit.
                        if store.bannerFiles(for: key).isEmpty { store.setBanner(Array(shown), for: key) }
                        store.setBannerLayout(index, for: key)
                        slot = 0
                    } label: {
                        LayoutGlyph(slots: ProfileBanner.layouts[index], on: index == current)
                    }
                    .buttonStyle(.press)
                    .accessibilityLabel("Layout \(index + 1)")
                    .accessibilityAddTraits(index == current ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
        .edgeFade()
    }

    /// The month's photographs, three across, big enough to tell apart.
    private func photos(_ files: [String], shown: [String], count: Int) -> some View {
        let gap = GridConstants.spacing
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: gap), count: 3), spacing: gap) {
            ForEach(files, id: \.self) { file in
                let at = shown.firstIndex(of: file)
                Button { place(file, shown: shown, count: count) } label: {
                    GeometryReader { geo in
                        CachedImageView(fileName: file, width: geo.size.width, height: geo.size.width,
                                        cornerRadius: GridConstants.cornerRadius)
                            .overlay(alignment: .topTrailing) {
                                if let at {
                                    Text(verbatim: "\(at + 1)")
                                        .font(Typography.headerSmall)
                                        .foregroundStyle(WarmBackground.top)
                                        .frame(width: 24, height: 24)
                                        .background(Circle().fill(AppColors.inkPrimary))
                                        .padding(6)
                                }
                            }
                    }
                    .aspectRatio(1, contentMode: .fit)
                }
                .buttonStyle(.press)
                .accessibilityLabel(at.map { "Photo, in slot \($0 + 1)" } ?? "Photo")
            }
        }
    }

    /// Into the chosen slot (a picture there already moves to where this one
    /// was); then on to the next slot.
    private func place(_ file: String, shown: [String], count: Int) {
        HapticsEngine.tick()
        var next = Array(shown.prefix(count))
        let target = min(slot ?? 0, count - 1)
        if let was = next.firstIndex(of: file) {
            if was == target { return }
            next.swapAt(was, min(target, next.count - 1))
        } else if target < next.count {
            next[target] = file
        } else {
            next.append(file)
        }
        store.setBanner(next, for: key)
        slot = (target + 1) % count
    }
}

/// An arrangement, drawn as its blocks: small, in ink when it is the one.
private struct LayoutGlyph: View {
    let slots: [ProfileBanner.Slot]
    let on: Bool

    var body: some View {
        let cell: CGFloat = 12, gap: CGFloat = 2
        ZStack(alignment: .topLeading) {
            ForEach(Array(slots.enumerated()), id: \.offset) { _, s in
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(on ? AppColors.inkPrimary : AppColors.inkTertiary.opacity(0.45))
                    .frame(width: CGFloat(s.columns) * cell + CGFloat(s.columns - 1) * gap,
                           height: CGFloat(s.rows) * cell + CGFloat(s.rows - 1) * gap)
                    .offset(x: CGFloat(s.column) * (cell + gap), y: CGFloat(s.row) * (cell + gap))
            }
        }
        .frame(width: cell * 4 + gap * 3, height: cell * 2 + gap, alignment: .topLeading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: GridConstants.radiusControl + 4, style: .continuous)
            .fill(on ? AppColors.chosenFill : AppColors.quietFill))
        .frame(minHeight: 44)
    }
}
