import SwiftData
import SwiftUI

// MARK: - Planned wins, on the tower

/// **What you mean to do today, standing in the tower as an empty outline**
/// (the owner, 2026-10-10: "planned wins appear in the tower as empty
/// lattice blocks: no color, clear, a liquid-glass checkbox-style
/// placeholder that reads as the outline of a block waiting to be filled,
/// NOT a full colored block with character").
///
/// **This reverses a removal, on purpose.** The tower once drew the day's
/// unfinished habits as faded coloured ghosts and stopped: "they made the
/// tower busy. The tower is the record; the planning lives elsewhere." What
/// stands here is a different object and keeps that rule's point. A planned
/// win takes no colour, no rim, no band and no shadow, because colour is
/// what the app spends on things that happened (`PlanBullet`). It is the
/// slot's own glass, quieter than the slot, with the line's words and the
/// plan's empty box in it: a place, not a block.
///
/// - **Always Quick.** One cell each, whatever the win turns out to weigh:
///   its size is chosen when it is done, at the shutter or in the sheet.
/// - **After the slot, never before it.** The slot sits where the next block
///   lands, and a block drawn out of the slot has to land in it. So the
///   outlines queue behind it, in the plan's order, and step along as the
///   tower grows.
/// - **Not counted.** The goal and the goal's dance count wins. An outline
///   is not one.
/// - **Press, and the camera opens** to finish it with a photo. **Hold** for
///   the rest: log it without a photo, change it, take it off today.
enum PlannedSlots {
    /// The most outlines the tower draws: two rows. A plan longer than that
    /// is all there in the plan; the tower shows what comes next, and the
    /// queue moves up as each one is done. An outline is a cue, and a wall
    /// of them is a debt (`docs/planning.md`).
    static let most = 8

    /// Today's open lines, in the plan's order.
    static func open(_ lines: [PlanItem], on date: Date = Date(), calendar: Calendar = .current) -> [PlanItem] {
        lines.filter {
            !$0.text.trimmingCharacters(in: .whitespaces).isEmpty
                && $0.isOpen(on: date, calendar: calendar, today: date)
                && !PlanSkips.isSkipped($0, on: date)
        }
            .sorted { ($0.order, $0.createdAt) < ($1.order, $1.createdAt) }
    }

    /// The cells the first `count` outlines stand in: the tower's own
    /// packing (`GridPacker`), one cell each, after the blocks that are
    /// there and after the slot at the size it is being drawn.
    static func cells(count: Int, grid: [[Bool]], slot: (column: Int, row: Int)?, slotSize: BlockSize,
                      columns: Int = GridConstants.columnCount) -> [(column: Int, row: Int)] {
        guard count > 0 else { return [] }
        var taken = grid
        if let slot {
            while taken.count < slot.row + slotSize.rowSpan { taken.append(Array(repeating: false, count: columns)) }
            for r in slot.row..<(slot.row + slotSize.rowSpan) {
                for c in slot.column..<min(columns, slot.column + slotSize.columnSpan) { taken[r][c] = true }
            }
        }
        var out: [(column: Int, row: Int)] = []
        for _ in 0..<min(count, most) {
            guard let cell = GridPacker.firstFit(columnSpan: 1, rowSpan: 1, columns: columns, grid: &taken) else { break }
            out.append((cell.column, cell.row))
        }
        return out
    }

    /// The rows the tower must be tall enough for.
    static func rows(_ cells: [(column: Int, row: Int)]) -> Int { (cells.map(\.row).max() ?? -1) + 1 }
}

/// One planned win: the slot's glass with nothing on it but the line's own
/// words and the plan's empty box.
struct PlannedOutline: View {
    let title: String
    let cornerRadius: CGFloat
    let side: CGFloat

    /// The plan's own bullet, at the size it is in the plan, so the box in
    /// the tower is the box you will see ticked there.
    private var box: CGFloat { min(18, side * 0.22) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            VStack(alignment: .leading, spacing: 0) {
                RoundedRectangle(cornerRadius: GridConstants.blockCornerRadius(forCell: box), style: .continuous)
                    .strokeBorder(PlanBullet.outlineInk, lineWidth: PlanBullet.outlineWidth(forSide: box))
                    .frame(width: box, height: box)
                Spacer(minLength: 2)
                // A block's own title type and place (`BlockContentOverlay`),
                // in ink where a block's is white: the same family, quieter.
                // Two lines, since the words are all an outline has, and
                // never shrunk: three outlines at three sizes is a ransom
                // note (seen 2026-10-10 with one long line among short ones).
                Text(title)
                    .font(BlockContentOverlay.titleFont)
                    .foregroundStyle(AppColors.inkSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .padding(.vertical, 12)
        }
        .frame(width: side, height: side)
        .glassSlot(cornerRadius: cornerRadius)
        // Quieter than the slot it follows: the slot is where to press to
        // add anything; these wait.
        .opacity(0.82)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// The queue of them, laid in the tower's grid.
struct PlannedOutlines: View {
    let items: [PlanItem]
    let cells: [(column: Int, row: Int)]
    let cellSize: CGFloat
    let gridHeight: CGFloat
    let cornerRadius: CGFloat
    var onCamera: (PlanItem) -> Void
    var onLog: (PlanItem) -> Void
    var onEdit: (PlanItem) -> Void
    var onNotToday: (PlanItem) -> Void

    private struct Placed: Identifiable {
        let item: PlanItem
        let frame: CGRect
        var id: UUID { item.id }
    }

    private var placed: [Placed] {
        zip(items, cells).map { item, cell in
            Placed(item: item, frame: GridConstants.blockFrame(column: cell.column, row: cell.row, columnSpan: 1,
                                                                rowSpan: 1, cellSize: cellSize))
        }
    }

    var body: some View {
        ForEach(placed) { one in
            outline(one.item, frame: one.frame)
        }
    }

    private func outline(_ item: PlanItem, frame: CGRect) -> some View {
        Button {
            HapticsEngine.lightTap()
            onCamera(item)
        } label: {
            PlannedOutline(title: item.text, cornerRadius: cornerRadius, side: frame.width)
        }
        .buttonStyle(.pressSurface)
        // **Hold is the menu**, as on a plan line: a recogniser of its own
        // on something in the tower starves the tower's scroll (CLAUDE.md),
        // and the system's does not.
        .contextMenu { menu(item) }
        .frame(width: frame.width, height: frame.height)
        .offset(x: frame.minX, y: gridHeight - frame.minY - frame.height)
        .transition(.scale(scale: 0.86).combined(with: .opacity))
        .accessibilityLabel("Planned: \(item.text)")
        .accessibilityHint("Opens the camera to finish it.")
        .accessibilityAction(named: "Log Without a Photo") { onLog(item) }
        .accessibilityAction(named: "Edit") { onEdit(item) }
        .accessibilityAction(named: item.repeats ? "Skip Today" : "Not Today") { onNotToday(item) }
    }

    @ViewBuilder
    private func menu(_ item: PlanItem) -> some View {
        Button("Take Photo", systemImage: "camera") { onCamera(item) }
        Button("Log Without a Photo", systemImage: "checkmark") { onLog(item) }
        Button("Edit", systemImage: "pencil") { onEdit(item) }
        Button(item.repeats ? "Skip Today" : "Not Today", systemImage: "moon.zzz") { onNotToday(item) }
    }
}

/// **The outlines, with the plan they are read from.** The query lives
/// here, not on `MainAppView`: there, every letter typed into a plan line
/// re-evaluated the whole main screen under the sheet (found by review).
/// The main screen is told one number, how many rows the outlines need, and
/// only when it changes.
struct PlannedLayer: View {
    @Query(sort: \PlanItem.order) private var lines: [PlanItem]

    let grid: [[Bool]]
    let slot: (column: Int, row: Int)?
    let slotSize: BlockSize
    let cellSize: CGFloat
    let gridHeight: CGFloat
    let cornerRadius: CGFloat
    /// Bumped when a line is skipped for today or the day turns: neither is
    /// something the query notices.
    let nudge: Int
    @Binding var rowsNeeded: Int
    var onCamera: (PlanItem) -> Void
    var onLog: (PlanItem) -> Void
    var onEdit: (PlanItem) -> Void
    var onNotToday: (PlanItem) -> Void

    var body: some View {
        let open = PlannedSlots.open(lines)
        let cells = PlannedSlots.cells(count: open.count, grid: grid, slot: slot, slotSize: slotSize)
        PlannedOutlines(items: open, cells: cells, cellSize: cellSize, gridHeight: gridHeight,
                        cornerRadius: cornerRadius, onCamera: onCamera, onLog: onLog, onEdit: onEdit,
                        onNotToday: onNotToday)
            .onChange(of: PlannedSlots.rows(cells), initial: true) { _, rows in
                if rowsNeeded != rows { rowsNeeded = rows }
            }
            .onDisappear { rowsNeeded = 0 }
    }
}

// MARK: - Finishing one from the tower

/// The camera a planned win opens, and the sheet that changes one: kept out
/// of `MainAppView`'s body, which is at the type checker's ceiling, and on
/// the screen's root, so neither goes away with the tower's layers.
struct PlannedCapture: ViewModifier {
    @Binding var capturing: PlanItem?
    @Binding var editing: PlanItem?
    var onCaptured: (PlanItem, UIImage, BlockSize, WinPlace?, CGPoint) -> Void

    /// What the shutter took, held until the camera has gone.
    @State private var taken: (item: PlanItem, photo: UIImage, size: BlockSize, place: WinPlace?, crop: CGPoint)?

    func body(content: Content) -> some View {
        content
            // **The add sheet opens once the camera has left** (found by
            // review): asked for in the same moment, a sheet presented over
            // one still going away is dropped without a word, and the
            // photograph with it. The plan's own tick does the same
            // (`pendingDraft`).
            .fullScreenCover(item: $capturing, onDismiss: {
                guard let shot = taken else { return }
                taken = nil
                onCaptured(shot.item, shot.photo, shot.size, shot.place, shot.crop)
            }) { item in
                CameraView(
                    onCaptured: { image, drawn, place, crop in
                        taken = (item, image, drawn, place, crop)
                        capturing = nil
                    },
                    onClose: { capturing = nil },
                    fillsScreen: true
                )
            }
            .sheet(item: $editing) { item in
                PlanItemDetailSheet(item: item)
            }
    }
}
