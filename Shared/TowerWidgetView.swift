import SwiftUI
import UIKit
import WidgetKit

/// The warm ground the app stands on, repeated here.
///
/// Written out rather than shared from `WarmBackground`: that view lives in
/// the app target, and reaching across for it would mean compiling a growing
/// slice of the app into a process that has a few hundred milliseconds to
/// draw. Two numbers is the right amount of duplication; the whole view is
/// not. If the ground is ever retuned, it is retuned in two places, which is
/// why both carry this note.
struct WidgetGround: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        LinearGradient(
            colors: scheme == .dark
                ? [Color(red: 0.129, green: 0.125, blue: 0.118),
                   Color(red: 0.094, green: 0.090, blue: 0.086)]
                : [Color(red: 0.965, green: 0.970, blue: 0.978),
                   Color(red: 0.947, green: 0.955, blue: 0.965)],
            startPoint: .top, endPoint: .bottom)
    }
}

struct TowerWidgetView: View {
    let snapshot: WidgetSnapshot
    /// Which of today's photographs to show — see `TowerProvider.getTimeline`.
    var photoIndex: Int = 0
    /// Forced size, for the renderer that photographs this view.
    ///
    /// `widgetFamily` is read-only in the environment, so there is no way to
    /// ask SwiftUI to lay this out as a lock screen accessory from outside
    /// WidgetKit — and nothing on the build machine can place a widget on a
    /// home screen to see it for real.
    var forcedFamily: WidgetFamily?
    @Environment(\.widgetFamily) private var environmentFamily

    private var family: WidgetFamily { forcedFamily ?? environmentFamily }

    private var photo: UIImage? {
        let photos = snapshot.photos
        guard !photos.isEmpty else { return nil }
        return Self.image(named: photos[photoIndex % photos.count])
    }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            lockScreen
        default:
            homeScreen
        }
    }

    // MARK: - Home screen

    /// **The photograph IS the widget.**
    ///
    /// It was a small tower with a header over it, which is the app's own
    /// screen shrunk until the blocks were 20pt squares — legible only if you
    /// already knew what they were. The owner, after living with it: "i feel
    /// like the widget should just show the picture and it cycle through and
    /// the number of wins for that day just so its clean."
    ///
    /// That is the better idea and it is not only simpler. A home screen is
    /// read at a glance from arm's length, and a photograph survives that
    /// where a grid of small coloured rectangles does not — and the
    /// photographs are the part of this app nobody else has.
    private var homeScreen: some View {
        ZStack(alignment: .bottomLeading) {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                // The count sits ON the picture, so it needs a floor under it
                // or a bright sky eats it. Bottom only, and gone by a third of
                // the way up: a veil over the whole photograph would be the
                // thing the tower's own caption veil was dialled back for.
                LinearGradient(
                    colors: [.black.opacity(0.55), .black.opacity(0)],
                    startPoint: .bottom, endPoint: .center)
            } else {
                empty
            }
            if photo != nil { count.padding(12) }
        }
        .clipped()
    }

    /// Today's number, in the owner's own digits.
    private var count: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(StrataNumerals.digits(snapshot.today))
                .font(StrataNumerals.size(30))
                .foregroundStyle(.white)
            Text(snapshot.today == 1 ? "win" : "wins")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
        .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
        .accessibilityLabel("\(snapshot.today) wins today")
    }

    /// **Not "no wins yet".** An empty day is the state everybody is in every
    /// morning, and the widget's job then is to be an invitation rather than a
    /// score of zero.
    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1.4, dash: [3, 3]))
                .foregroundStyle(.tertiary)
                .frame(width: 30, height: 30)
            Text(snapshot.total == 0 ? "Your first win goes here" : "Nothing yet today")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(14)
    }

    // MARK: - Lock screen

    /// No photograph here: the lock screen renders accessories as a flat
    /// tinted stencil, so a picture arrives as a grey smear.
    private var lockScreen: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(StrataNumerals.digits(snapshot.today))
                    .font(StrataNumerals.size(16))
                Text("today")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            Text(secondLine)
                .font(.system(size: 12, weight: .medium, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Thumbnails out of the group container. A widget draws once and is torn
    /// down, so there is nothing to cache.
    static func image(named file: String) -> UIImage? {
        guard let directory = WidgetSnapshot.photoDirectory else { return nil }
        return UIImage(contentsOfFile: directory.appendingPathComponent(file).path)
    }
}

extension TowerWidgetView {
    /// The one extra fact worth a second line, and never a repeat of the
    /// first.
    ///
    /// On day one every win IS today's, so "11 wins / 11 today" says the same
    /// thing twice — the failure the tower's own header was redesigned to
    /// avoid. Day one gets to be day one instead.
    fileprivate var secondLine: String {
        if snapshot.streak > 1 { return "\(snapshot.streak) day streak" }
        if snapshot.today == 0 { return "Add one" }
        if snapshot.today == snapshot.total { return "Day one" }
        return "\(snapshot.total) altogether"
    }
}

/// The top of the tower, packed the way the app packs it.
///
/// **Deliberately not `BlockSurface`.** The real block draws its surface twice
/// and masks one copy through a blur to reproduce the Figma rim — worth every
/// cycle at full size in the app, and wrong here: the blur is 1.78% of the
/// block's width, which at widget scale is well under a pixel, so it would
/// cost an offscreen pass to render nothing. What carries a block's identity
/// at this size is the flat colour and the rim brightest along the top edge,
/// and that is what this draws.
struct TowerMark: View {
    let blocks: [WidgetSnapshot.Block]
    let columns: Int

    var body: some View {
        GeometryReader { geo in
            let placed = Self.pack(blocks, columns: columns)
            let rows = max((placed.map { $0.row + $0.block.rows }.max() ?? 0), 1)
            // **Fill the box, don't sit in the corner of it.** Sizing the cell
            // off the width alone left a two-block tower as two small squares
            // in the bottom-left of a mostly empty medium widget. Take
            // whichever of width and height is the binding constraint, and cap
            // it so a single block does not become a slab.
            let byWidth = geo.size.width / CGFloat(columns)
            let byHeight = geo.size.height / CGFloat(rows)
            let cell = max(min(byWidth, byHeight, geo.size.height / 2), 1)
            let height = CGFloat(rows) * cell

            ZStack(alignment: .topLeading) {
                ForEach(placed.indices, id: \.self) { i in
                    let item = placed[i]
                    brick(item.block, cell: cell)
                        // **Row 0 at the BOTTOM.** First-fit packs downward,
                        // so drawing rows in packing order stands the tower on
                        // its head: the partial row — the newest blocks —
                        // ended up along the floor, with the full rows above
                        // it. A tower stands on its complete rows.
                        .offset(x: CGFloat(item.column) * cell,
                                y: CGFloat(rows - item.row - item.block.rows) * cell)
                }
            }
            .frame(width: geo.size.width, height: height, alignment: .topLeading)
            // Bottom-aligned: a tower stands on the ground, and the newest
            // blocks are the ones worth seeing when there is not room for all.
            .offset(y: max(geo.size.height - height, 0))
        }
    }

    private func brick(_ block: WidgetSnapshot.Block, cell: CGFloat) -> some View {
        let gutter: CGFloat = 1.5
        let w = CGFloat(block.columns) * cell - gutter
        let h = CGFloat(block.rows) * cell - gutter
        let shape = RoundedRectangle(cornerRadius: max(w * 0.147, 1.5), style: .continuous)
        return shape
            .fill(Color(hex6: block.hex))
            // **The photograph, over its colour.** A tower of flat squares is
            // not what the app shows, and the owner said so: "it doesnt show
            // the pictures on the blocks." The colour stays underneath rather
            // than being replaced, which is what the tower does too — it is
            // what the block IS while the picture loads, and what shows
            // through a photograph that does not fill the frame.
            .overlay {
                if let photo = block.photo, let image = Self.image(named: photo) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipShape(shape)
                }
            }
            .overlay {
                // Lit from above by the rim, exactly as in the app: full white
                // along the top edge, falling away elsewhere. No vertical
                // gradient on the fill — the block is one flat colour.
                RoundedRectangle(cornerRadius: max(w * 0.147, 1.5), style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.85), .white.opacity(0.18)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 0.8)
            }
            .frame(width: max(w, 1), height: max(h, 1))
    }

    /// Thumbnails out of the group container, cached for the life of the
    /// render. A widget draws once and is torn down, so a process-wide cache
    /// would be memory the system never gets back.
    private static func image(named file: String) -> UIImage? {
        guard let directory = WidgetSnapshot.photoDirectory else { return nil }
        return UIImage(contentsOfFile:
            directory.appendingPathComponent(file).path)
    }

    // MARK: - Packing

    struct Placed {
        let block: WidgetSnapshot.Block
        let column: Int
        let row: Int
    }

    /// **The app's own packer, not a copy of it.**
    ///
    /// This used to be a re-implementation of first fit living here, which is
    /// the arrangement drifting from the tower's the moment either is
    /// touched — and the tower is what the widget is a picture of: "make sure
    /// the tower works the same way it does in the app." `GridPacker` moved to
    /// Shared/ so both compile the same function.
    ///
    /// It is deliberately not monotonic, and that is inherited rather than
    /// introduced: a 2x2 leaves a 1x1 hole beside it that a later, smaller
    /// block drops into. The widget wants exactly that, because the app does
    /// it.
    static func pack(_ blocks: [WidgetSnapshot.Block], columns: Int) -> [Placed] {
        var grid: [[Bool]] = []
        var out: [Placed] = []
        for block in blocks {
            guard let spot = GridPacker.firstFit(
                columnSpan: min(block.columns, columns),
                rowSpan: block.rows,
                columns: columns,
                grid: &grid) else { continue }
            out.append(Placed(block: block, column: spot.column, row: spot.row))
        }
        return out
    }

}

extension Color {
    /// `RRGGBB`, as written in the snapshot.
    init(hex6: String) {
        let value = UInt64(hex6, radix: 16) ?? 0
        self.init(red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}

extension WidgetSnapshot {
    /// What the gallery and the placeholder show — a tower that looks like
    /// someone's, not an empty box.
    static let preview = WidgetSnapshot(
        total: 34, today: 2, streak: 5,
        blocks: [
            .init(columns: 1, rows: 1, hex: "0EAD74"),
            .init(columns: 2, rows: 1, hex: "40A9FF"),
            .init(columns: 1, rows: 1, hex: "AF9CFA"),
            .init(columns: 2, rows: 2, hex: "0EAD74"),
            .init(columns: 1, rows: 1, hex: "40A9FF"),
            .init(columns: 1, rows: 2, hex: "AF9CFA"),
            .init(columns: 2, rows: 1, hex: "0EAD74"),
            .init(columns: 1, rows: 1, hex: "40A9FF")
        ],
        updated: Date())
}
