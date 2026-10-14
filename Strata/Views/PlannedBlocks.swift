import SwiftData
import PhotosUI
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
    /// When it is for, if the line said ("Gym @ 2"): beside the box.
    var time: String? = nil
    let cornerRadius: CGFloat
    let side: CGFloat
    @Environment(\.colorScheme) private var scheme

    /// The plan's own bullet, at the size it is in the plan, so the box in
    /// the tower is the box you will see ticked there.
    private var box: CGFloat { min(18, side * 0.22) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: GridConstants.spacing) {
                    RoundedRectangle(cornerRadius: GridConstants.blockCornerRadius(forCell: box), style: .continuous)
                        .strokeBorder(PlanBullet.outlineInk, lineWidth: PlanBullet.outlineWidth(forSide: box))
                        .frame(width: box, height: box)
                    if let time {
                        Text(time)
                            .font(BlockContentOverlay.titleFont)
                            .foregroundStyle(AppColors.inkSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                    }
                }
                Spacer(minLength: 2)
                // A block's own title type and place (`BlockContentOverlay`).
                // **And its own strength** (the owner, 2026-10-11: "the
                // checkmark block font and weight should be the same as the
                // other blocks"). The face was already the block's; the ink
                // was the secondary grey, and the whole outline was drawn at
                // 82%, so the same Medium read a weight lighter than the
                // white on a block beside it. The title ink, at full
                // strength: dark on the light pane, white on the dark one,
                // as a block's title is white on its colour.
                // Two lines, since the words are all an outline has, and
                // never shrunk: three outlines at three sizes is a ransom
                // note (seen 2026-10-10 with one long line among short ones).
                Text(title)
                    .font(BlockContentOverlay.titleFont)
                    .foregroundStyle(AppColors.inkPrimary)
                    .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .padding(.vertical, 12)
        }
        .frame(width: side, height: side)
        // The slot's own edge (`SlotPane`): one pane, whether it holds a
        // `+` or a box.
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(AppColors.slotInk.opacity(SlotPane.edge(scheme)), lineWidth: GridConstants.strokeThin)
        }
        .glassSlot(cornerRadius: cornerRadius)
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
    /// From the photo library, as the add sheet's own block offers.
    var onLibrary: (PlanItem) -> Void = { _ in }
    var onLog: (PlanItem) -> Void
    var onEdit: (PlanItem) -> Void
    var onNotToday: (PlanItem) -> Void

    /// The planned win whose choices are showing.
    @State private var choosing: PlanItem?

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
        // **A press opens the menu** (the owner's pick, 2026-10-11, over
        // press = camera). It is a checkbox, and a press that opened the
        // camera surprised anyone who only meant to tick it, while the
        // library and "without a photo" sat behind a hold nobody could see.
        // The same short menu the add sheet's empty block opens, so one
        // block teaches the other (`docs/flows.md`).
        // (A button that shows the menu, never a system `Menu` round the
        // glass: that never opened on a tap, the pairing `CrewReactions`
        // records as swallowing taps.)
        Button {
            HapticsEngine.lightTap()
            choosing = item
        } label: {
            PlannedOutline(title: PlanTime.title(item.text), time: PlanTime.label(for: item.text),
                           cornerRadius: cornerRadius, side: frame.width)
        }
        .buttonStyle(.pressSurface)
        // The block's own menu (`BlockMenuRow`), the one the add sheet's
        // block opens: a glyph and a word a row, hung off the block.
        .blockMenu(isPresented: shows(item), above: true) { rows(item) }
        // A hold opens the same choices, as on a plan line.
        .contextMenu { menu(item) }
        .frame(width: frame.width, height: frame.height)
        .offset(x: frame.minX, y: gridHeight - frame.minY - frame.height)
        .transition(.scale(scale: 0.86).combined(with: .opacity))
        .accessibilityLabel(["Planned: \(PlanTime.title(item.text))", PlanTime.label(for: item.text)]
            .compactMap { $0 }.joined(separator: ", "))
        .accessibilityHint("Shows the ways to finish it.")
        // The hold's own items, by name (one builder: a chain of four
        // named actions was past what the type checker would solve).
        .accessibilityActions { named(item) }
    }

    private func shows(_ item: PlanItem) -> Binding<Bool> {
        Binding(get: { choosing?.id == item.id },
                set: { if !$0, choosing?.id == item.id { choosing = nil } })
    }

    /// The rows of a planned win's menu: the three ways to fill a block, in
    /// the add sheet's order and words, then what can be done to the plan.
    @ViewBuilder
    private func rows(_ item: PlanItem) -> some View {
        let open = shows(item)
        BlockMenuRow("Take Photo", "camera") { BlockMenuAfter.run(closing: open) { onCamera(item) } }
        BlockMenuRow("Choose from Library", "photo.on.rectangle") { BlockMenuAfter.run(closing: open) { onLibrary(item) } }
        BlockMenuRow("Log Without a Photo", "checkmark") { BlockMenuAfter.run(closing: open) { onLog(item) } }
        BlockMenuRow("Edit", "pencil") { BlockMenuAfter.run(closing: open) { onEdit(item) } }
        BlockMenuRow(item.repeats ? "Skip Today" : "Not Today", "moon.zzz") {
            open.wrappedValue = false
            onNotToday(item)
        }
    }

    @ViewBuilder
    private func named(_ item: PlanItem) -> some View {
        Button("Choose from Library") { onLibrary(item) }
        Button("Log Without a Photo") { onLog(item) }
        Button("Edit") { onEdit(item) }
        Button(item.repeats ? "Skip Today" : "Not Today") { onNotToday(item) }
    }

    @ViewBuilder
    private func menu(_ item: PlanItem) -> some View {
        // The add sheet's own three ways to fill a block, in its order and
        // its words (the owner, 2026-10-11: "you aren't able to add camera
        // roll wins to the check mark ... make sure the plan and check mark
        // experience is both consistent").
        Button("Take Photo", systemImage: "camera") { onCamera(item) }
        Button("Choose from Library", systemImage: "photo.on.rectangle") { onLibrary(item) }
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
    /// From the photo library, as the add sheet's own block offers.
    var onLibrary: (PlanItem) -> Void = { _ in }
    var onLog: (PlanItem) -> Void
    var onEdit: (PlanItem) -> Void
    var onNotToday: (PlanItem) -> Void

    var body: some View {
        let open = PlannedSlots.open(lines)
        let cells = PlannedSlots.cells(count: open.count, grid: grid, slot: slot, slotSize: slotSize)
        PlannedOutlines(items: open, cells: cells, cellSize: cellSize, gridHeight: gridHeight,
                        cornerRadius: cornerRadius, onCamera: onCamera, onLibrary: onLibrary, onLog: onLog, onEdit: onEdit,
                        onNotToday: onNotToday)
            .onChange(of: PlannedSlots.rows(cells), initial: true) { _, rows in
                if rowsNeeded != rows { rowsNeeded = rows }
            }
            .onDisappear { rowsNeeded = 0 }
    }
}

/// What a planned win's box can be asked to do, for a screen that is not
/// the Wins page and has none of its sheets: the crew's tower.
enum PlannedAction: Sendable {
    case camera, library, log, edit, notToday
}

/// **A crew's plans you are in, as boxes on the crew's own tower** (the
/// owner, 2026-10-13: "when you plan something in the crew chat they should
/// show up as a checkbox block in the crew tower ... if the other person
/// accepts it it also goes as a checkbox on their crew tower. This allows
/// separate crews with different goals to live on the app").
///
/// **The same box, drawn by the same view** (`PlannedOutlines`): clear
/// glass, the line's words, the plan's empty box, after the slot, one cell
/// each, never counted. Only this crew's lines stand here
/// (`GroupPlanBook.planItems`), so two crews with two goals are two towers
/// with two sets of boxes. It is still a line of your own plan, so it is on
/// your own tower too, and finishing it in either place is one win, sent to
/// this crew.
///
/// **Only yours.** A friend who is in sees their own box on their own
/// phone. Nothing here shows who is in and who is not.
struct CrewPlannedLayer: View {
    @Query(sort: \PlanItem.order) private var lines: [PlanItem]

    let crewID: CrewID
    let grid: [[Bool]]
    let slot: (column: Int, row: Int)?
    let slotSize: BlockSize
    let cellSize: CGFloat
    let gridHeight: CGFloat
    let cornerRadius: CGFloat
    /// Bumped when the book or a skip changed: neither is in the query.
    let nudge: Int
    @Binding var rowsNeeded: Int
    var act: (PlanItem, PlannedAction) -> Void

    /// This crew's lines among today's open ones, in the plan's order.
    static func lines(_ open: [PlanItem], held: Set<UUID>) -> [PlanItem] {
        open.filter { held.contains($0.id) }
    }

    /// This crew's lines, read from the book when it may have changed (a
    /// line added or gone, or the host's nudge) and not on every draw: the
    /// crew's screen is redrawn every few seconds while it is live.
    @State private var held: Set<UUID>?

    var body: some View {
        let open = Self.lines(PlannedSlots.open(lines), held: held ?? GroupPlanBook.planItems(in: crewID))
        let cells = PlannedSlots.cells(count: open.count, grid: grid, slot: slot, slotSize: slotSize)
        PlannedOutlines(items: open, cells: cells, cellSize: cellSize, gridHeight: gridHeight,
                        cornerRadius: cornerRadius,
                        onCamera: { act($0, .camera) }, onLibrary: { act($0, .library) },
                        onLog: { act($0, .log) }, onEdit: { act($0, .edit) },
                        onNotToday: { act($0, .notToday) })
            .onChange(of: PlannedSlots.rows(cells), initial: true) { _, rows in
                if rowsNeeded != rows { rowsNeeded = rows }
            }
            .onChange(of: "\(nudge)|\(lines.count)", initial: true) { _, _ in
                held = GroupPlanBook.planItems(in: crewID)
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
    /// The planned win a photo is being chosen for, from the library.
    var picking: Binding<PlanItem?> = .constant(nil)
    var onCaptured: (PlanItem, UIImage, BlockSize, WinPlace?, CGPoint, CGFloat) -> Void

    @State private var picked: PhotosPickerItem?

    /// What the shutter took, held until the camera has gone.
    @State private var taken: (item: PlanItem, photo: UIImage, size: BlockSize, place: WinPlace?, crop: CGPoint, zoom: CGFloat)?

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
                onCaptured(shot.item, shot.photo, shot.size, shot.place, shot.crop, shot.zoom)
            }) { item in
                CameraView(
                    onCaptured: { image, drawn, place, crop, zoom in
                        taken = (item, image, drawn, place, crop, zoom)
                        capturing = nil
                    },
                    onClose: { capturing = nil },
                    fillsScreen: true
                )
            }
            // **A photo from the library finishes it too.** The picker, then
            // the add sheet holding the photo once the picker has left, as
            // the camera's does.
            .photosPicker(isPresented: Binding(get: { picking.wrappedValue != nil },
                                               set: { if !$0, picked == nil, picking.wrappedValue != nil { picking.wrappedValue = nil } }),
                          selection: $picked, matching: .images)
            .onChange(of: picked) { _, chosen in
                guard let chosen, let item = picking.wrappedValue else { return }
                Task { @MainActor in
                    let data = try? await chosen.loadTransferable(type: Data.self)
                    picked = nil
                    picking.wrappedValue = nil
                    guard let data, let image = UIImage(data: data) else { return }
                    try? await Task.sleep(for: .milliseconds(500))
                    onCaptured(item, image, item.size, nil, .zero, 1)
                }
            }
            .sheet(item: $editing) { item in
                PlanItemDetailSheet(item: item)
            }
    }
}
