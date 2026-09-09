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
                scale: cell / GridConstants.blockReferenceCell,
                // A white wash floors a photograph's luminance at its own
                // alpha. The tower's photo blocks drop to 0.06 for exactly
                // this reason and these are the same object.
                washOpacity: block.photoFileNames.isEmpty
                    ? GridConstants.blockScrimOpacity : 0.06
            ) {
                ZStack {
                    // The colour is still under the picture, not replaced by
                    // it: it is what the block IS while the photograph
                    // decodes, and it is what shows through the rim.
                    block.category.style.baseColor
                    DayPhotoSlideshow(fileNames: block.photoFileNames,
                                      size: size,
                                      phase: block.dayOfMonth)
                }
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
                    // The owner's digits, like every other number in the
                    // app. Solved off the cell rather than the type scale:
                    // this numeral is the block's coordinate, so it has to
                    // stay in proportion to the block.
                    .font(Typography.numeral(cell * 0.16))
                    .foregroundStyle(.white.opacity(block.photoFileNames.isEmpty ? 0.55 : 0.9))
                    // Only on a photograph, and only as much as it takes.
                    // On flat colour the numeral sits in the frosted band and
                    // needs nothing; on a picture it can land on anything.
                    .shadow(color: .black.opacity(block.photoFileNames.isEmpty ? 0 : 0.45),
                            radius: 3, y: 1)
                    .padding(cell * 0.11)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Day \(block.dayOfMonth), \(block.winCount) \(block.winCount == 1 ? "win" : "wins")")
    }
}

// MARK: - The photographs on a day

/// A day's photographs, cycling on its block.
///
/// The month used to be thirty blocks of flat colour, which said how much you
/// did and nothing about what it was. A day you photographed has the answer
/// sitting in the store; showing it turns the month from a chart into the
/// thing the page is for.
///
/// **A stagger, not a slideshow.** Thirty blocks crossfading on one clock is a
/// wall that blinks, and the eye reads a blink as an alert. Each block's phase
/// comes from its own day number, so at any moment one or two are changing and
/// the month reads as alive rather than as animated. Reduce Motion turns it off
/// entirely and leaves the newest photograph, which is the right still frame.
///
/// A block with one photograph does not cycle, and a block with none draws
/// nothing at all — no placeholder, no shimmer. A day is allowed to just be a
/// colour.
private struct DayPhotoSlideshow: View {
    let fileNames: [String]
    let size: CGSize
    /// What makes this block's clock its own. The day of the month, so two
    /// blocks side by side are never in step.
    let phase: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The picture underneath, always fully opaque, and the one fading in on
    /// top of it. Two slots rather than one index, because the substrate must
    /// never be visible — see below.
    @State private var base: String?
    @State private var top: String?
    @State private var topOpacity: Double = 0

    /// How long one photograph holds.
    ///
    /// Long. This is a page you scroll past, not a screensaver, and anything
    /// quick enough to catch the eye while you are reading below it is a
    /// distraction rather than a detail.
    private static let dwell: Duration = .seconds(5)
    /// And how long the handover takes. Slow enough to read as a dissolve
    /// rather than a cut.
    private static let fade: Double = 0.7

    var body: some View {
        ZStack {
            if let base { picture(base) }
            if let top { picture(top).opacity(topOpacity) }
        }
        .task(id: fileNames) { await run() }
    }

    private func picture(_ name: String) -> some View {
        CachedImageView(fileName: name, width: size.width,
                        height: size.height, cornerRadius: 0)
            .frame(width: size.width, height: size.height)
    }

    /// **The outgoing picture stays fully opaque underneath the incoming one.**
    ///
    /// A `.transition(.opacity)` on a single slot crossfades symmetrically —
    /// both copies pass through partial alpha at once, which composites to
    /// less than opaque and lets the block's colour show through the middle of
    /// every handover. That is the same mistake `BlockSurface` documents about
    /// its two masked copies, in a different place. One layer holds at 1 while
    /// the other comes up, and the swap happens after it has arrived.
    private func run() async {
        base = fileNames.first
        top = nil
        topOpacity = 0
        guard fileNames.count > 1, !reduceMotion else { return }

        // Offset the first tick so the month does not turn over at once.
        try? await Task.sleep(for: .seconds(Double(phase % 7) * 0.7))
        var next = 1
        while !Task.isCancelled {
            try? await Task.sleep(for: Self.dwell)
            guard !Task.isCancelled else { return }
            let name = fileNames[next % fileNames.count]
            top = name
            withAnimation(.easeInOut(duration: Self.fade)) { topOpacity = 1 }
            try? await Task.sleep(for: .seconds(Self.fade))
            guard !Task.isCancelled else { return }
            base = name
            top = nil
            topOpacity = 0
            next += 1
        }
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
                        .font(.system(size: 10, weight: .medium))
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
