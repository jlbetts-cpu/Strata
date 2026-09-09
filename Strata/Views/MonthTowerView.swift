import SwiftUI

/// A month, drawn as a tower that grows through it.
///
/// One block per day you logged anything, sized by how much (`MonthTower.size`)
/// and coloured by what kind of day it was. It replaces the fourteen-day bar
/// chart, which drew a reading of the record without being part of it.
///
/// **Fixed cell, variable height.** The chart solved its cell size for a height
/// budget; doing that here would draw a busy month shorter than a quiet one,
/// which is a lie, and comparing months is the entire point of having a picker.
/// So the cell comes from the grid — four columns at the page width, exactly as
/// on the Wins tab — and a busy month is simply taller.
struct MonthTowerView: View {
    let packed: MonthTower.Packed
    /// The width to draw into. Explicit rather than a `GeometryReader`, for the
    /// reason `StaticTowerView` documents: a view that must report its own
    /// height cannot measure itself.
    let width: CGFloat
    var onSelect: (String) -> Void = { _ in }

    private var cell: CGFloat { GridConstants.cellSize(forGridWidth: width) }
    private var gridWidth: CGFloat { GridConstants.gridWidth(cellSize: cell) }
    private var gridHeight: CGFloat { GridConstants.gridHeight(rows: packed.rows, cellSize: cell) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear.frame(width: gridWidth, height: gridHeight)

            ForEach(packed.blocks) { block in
                let f = GridConstants.blockFrame(
                    column: block.column, row: block.row,
                    columnSpan: block.columnSpan, rowSpan: block.rowSpan,
                    cellSize: cell
                )
                dayBlock(block, size: CGSize(width: f.width, height: f.height))
                    // Row 0 at the BOTTOM, like every other tower in the app.
                    // A month grows upward through itself.
                    .offset(x: f.minX, y: gridHeight - f.minY - f.height)
            }
        }
        .frame(width: gridWidth, height: gridHeight, alignment: .topLeading)
    }

    // MARK: - One day

    private func dayBlock(_ block: MonthTower.Block, size: CGSize) -> some View {
        Button {
            HapticsEngine.lightTap()
            onSelect(block.dateString)
        } label: {
            BlockSurface(
                cornerRadius: GridConstants.blockCornerRadius(forCell: cell),
                scale: cell / GridConstants.blockReferenceCell
            ) {
                block.category.style.baseColor
            }
            .frame(width: size.width, height: size.height)
            .overlay(alignment: .bottomLeading) {
                // The day number, quietly.
                //
                // CLAUDE.md says a block with no name shows no text, and that
                // rule is about an unnamed win claiming a name. A day number is
                // not a name, it is the block's coordinate — and it is needed,
                // because first-fit packing is not monotonic: a 2x2 leaves a
                // hole beside it that a LATER day drops into, so position alone
                // does not say which day a block is. Every block here is a
                // destination, and tapping without the number is a lottery.
                //
                // It sits inside `BlockSurface`'s frosted band, which is
                // already the lighter region, so it does not fight the colour.
                Text("\(block.dayOfMonth)")
                    .font(.system(size: cell * 0.16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(cell * 0.11)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Day \(block.dayOfMonth), \(block.winCount) \(block.winCount == 1 ? "win" : "wins")")
    }
}

/// `‹ SEPTEMBER ›`, where the month itself is a menu.
///
/// The chevrons step one month at a time, which is what you want most of the
/// time. Tapping the name opens a native menu of every month there is, which
/// is what you want when the thing you are looking for is last summer —
/// eleven presses away by chevron.
///
/// A `Menu` rather than a wheel or a sheet: it is the platform's own control
/// for "choose one of these", it renders as UIKit's menu with no styling of
/// ours on it, and it needs no room on the page when it is closed.
///
/// The chevrons are **disabled and dimmed at the edges, never hidden**: a
/// control that vanishes reads as a bug, and a disabled button is what
/// VoiceOver can describe. No wraparound — a year is not a carousel.
struct MonthPicker: View {
    let title: String
    let canGoBack: Bool
    let canGoForward: Bool
    /// Every month there is, newest first, with what to call each one.
    var months: [Date] = []
    var titleFor: (Date) -> String = { _ in "" }
    var onSelect: (Date) -> Void = { _ in }
    let onBack: () -> Void
    let onForward: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            chevron("chevron.left", enabled: canGoBack, label: "Previous month", action: onBack)
            Spacer(minLength: 0)

            Menu {
                ForEach(months, id: \.self) { month in
                    Button {
                        onSelect(month)
                    } label: {
                        Text(titleFor(month).capitalized)
                        if titleFor(month) == title { Image(systemName: "checkmark") }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(title)
                        .font(Typography.sectionLabel)
                        .kerning(Typography.sectionKerning)
                        .foregroundStyle(.primary.opacity(0.55))
                        .contentTransition(.opacity)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.35))
                }
                .padding(.horizontal, 10)
                .frame(height: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Month, \(title). Choose another")

            Spacer(minLength: 0)
            chevron("chevron.right", enabled: canGoForward, label: "Next month", action: onForward)
        }
        // The Figma puts the chevrons at x 23.5, which cannot centre a 44pt
        // target — it would start at 1.5. Shifted to the 8pt grid so the tap
        // target clears the HIG minimum.
        .padding(.horizontal, 2)
        .frame(height: 44)
    }

    private func chevron(_ name: String, enabled: Bool,
                         label: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticsEngine.lightTap()
            action()
        } label: {
            Image(systemName: name)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.primary.opacity(enabled ? 0.55 : 0.25))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}
