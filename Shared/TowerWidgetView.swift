import SwiftUI
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
    /// Forced size, for the renderer that photographs this view.
    ///
    /// `widgetFamily` is read-only in the environment, so there is no way to
    /// ask SwiftUI to lay this out as a medium widget from outside WidgetKit —
    /// and nothing on the build machine can place a widget on a home screen to
    /// see it for real. One optional override is the cheapest honest way to
    /// look at all three sizes.
    var forcedFamily: WidgetFamily?
    @Environment(\.widgetFamily) private var environmentFamily

    private var family: WidgetFamily { forcedFamily ?? environmentFamily }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            lockScreen
        default:
            homeScreen
        }
    }

    // MARK: - Home screen

    private var homeScreen: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            if snapshot.blocks.isEmpty {
                empty
            } else {
                // **"today" said once, on the thing it describes.** The
                // headline counts everything ever; these are the blocks that
                // landed since midnight, and without a word saying so the two
                // numbers look like they disagree.
                Text("today")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                TowerMark(blocks: snapshot.blocks, columns: family == .systemSmall ? 4 : 7)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
    }

    /// The count as the fact, the word as its caption.
    ///
    /// The same rank the tower's own header uses: the number is what you came
    /// to read and the word only says what it counts, so the word is quieter
    /// and smaller rather than half of a two-word title.
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(snapshot.total)")
                .font(.system(size: family == .systemSmall ? 28 : 32,
                              weight: .semibold, design: .rounded))
                .contentTransition(.numericText())
            Text(snapshot.total == 1 ? "win" : "wins")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    /// **Not "no wins yet".** An empty tower is the state every single person
    /// is in on their first day, and the widget's job then is to be an
    /// invitation rather than a score of zero.
    private var empty: some View {
        VStack(alignment: .leading, spacing: 3) {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                .foregroundStyle(.tertiary)
                .frame(width: 26, height: 26)
            Text("Your first block goes here")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Lock screen

    private var lockScreen: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(snapshot.total) wins")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Text(secondLine)
                .font(.system(size: 12, weight: .medium, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        return "\(snapshot.today) today"
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
        return RoundedRectangle(cornerRadius: max(w * 0.147, 1.5), style: .continuous)
            .fill(Color(hex6: block.hex))
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

    // MARK: - Packing

    struct Placed {
        let block: WidgetSnapshot.Block
        let column: Int
        let row: Int
    }

    /// First fit, the same rule the tower uses.
    ///
    /// **Not monotonic, and that is the app's behaviour rather than a bug
    /// here**: a 2x2 leaves a hole beside it that a later block drops into. It
    /// has to match, or the widget would show a different arrangement from the
    /// one you are looking at in the app.
    static func pack(_ blocks: [WidgetSnapshot.Block], columns: Int) -> [Placed] {
        var occupied = Set<[Int]>()
        var out: [Placed] = []
        for block in blocks {
            let span = min(block.columns, columns)
            var row = 0
            var placed = false
            while !placed && row < 64 {
                for column in 0...(max(columns - span, 0)) {
                    let cells = (0..<span).flatMap { dx in
                        (0..<block.rows).map { dy in [column + dx, row + dy] }
                    }
                    if cells.allSatisfy({ !occupied.contains($0) }) {
                        cells.forEach { occupied.insert($0) }
                        out.append(Placed(block: block, column: column, row: row))
                        placed = true
                        break
                    }
                }
                row += 1
            }
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
