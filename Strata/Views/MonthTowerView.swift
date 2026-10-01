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
    /// **The same lamp the day tower stands under.**
    ///
    /// A month is a tower too — four columns, row 0 on the ground, the same
    /// blocks — and it was lit flat: every block's glow dead centre and every
    /// rim brightest along its top. Two pages showing the same object under two
    /// different lights is exactly the thing the owner meant by "make the whole
    /// app feel like a cohesive experience". One lamp, hung over this grid the
    /// way `MainAppView` hangs it over the day's. See `BlockLight`.
    let packed: MonthTower.Packed
    /// The width to draw into. Explicit rather than a `GeometryReader`, for the
    /// reason `StaticTowerView` documents: a view that must report its own
    /// height cannot measure itself.
    let width: CGFloat
    var onSelect: (String) -> Void = { _ in }
    /// The namespace the day's album is pushed into, so the block a finger
    /// landed on is the thing that opens rather than a new page arriving over
    /// it. Optional: the month tower is drawn in places that do not push
    /// anything — onboarding, the widget preview — and those pass nothing.
    var transitionNamespace: Namespace.ID?

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
                    .matchedTransitionSource(id: block.dateString, in: transitionNamespace)
                    // Row 0 at the BOTTOM, like every other tower in the app.
                    // A month grows upward through itself.
                    .offset(x: f.minX, y: gridHeight - f.minY - f.height)
            }
        }
        .frame(width: gridWidth, height: gridHeight, alignment: .topLeading)
        .environment(\.blockLight, BlockLight.over(rows: packed.rows))
    }

    // MARK: - One day

    private func dayBlock(_ block: MonthTower.Block, size: CGSize) -> some View {
        MonthDayBlock(block: block, size: size, cell: cell, onSelect: onSelect)
    }

}

/// One day of the month, as a block.
///
/// **A view rather than a method, so it can read the lamp.** `BlockLight` is an
/// environment value — one lamp set on the grid, every block working out its
/// own corner from where it stands — and a `private func` on the parent is
/// evaluated in the parent's environment, so it would have got the same aim for
/// every day of the month. The day tower's `FlippableBlockView` is a view for
/// exactly the same reason.
private struct MonthDayBlock: View {
    let block: MonthTower.Block
    let size: CGSize
    let cell: CGFloat
    var onSelect: (String) -> Void

    @Environment(\.blockLight) private var blockLight

    private var aim: BlockAim {
        blockLight?.aim(column: block.column, row: block.row,
                        columnSpan: block.columnSpan, rowSpan: block.rowSpan)
            ?? .overhead
    }

    var body: some View {
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
                    ? GridConstants.blockScrimOpacity : 0.06,
                aim: aim
            ) {
                ZStack {
                    // The colour is still under the picture, not replaced by
                    // it: it is what the block IS while the photograph
                    // decodes, and it is what shows through the rim.
                    Rectangle().fill(EtherealFill.fill(block.category.style.baseColor,
                                                       aim: aim))
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
                    // 0.9 on colour and on a photograph alike. At 0.55 a
                    // day with no picture measured 1.67:1 on Work blue and
                    // 1.8:1 on Health green, which is not a number you can
                    // tap by, and the page showed two numeral weights.
                    .foregroundStyle(.white.opacity(0.9))
                    // Only on a photograph, and only as much as it takes.
                    // On flat colour the numeral sits in the frosted band and
                    // needs nothing; on a picture it can land on anything.
                    .shadow(color: .black.opacity(block.photoFileNames.isEmpty
                                                  ? 0 : Legibility.ink),
                            radius: Legibility.radius, y: Legibility.y)
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
struct DayPhotoSlideshow: View {
    let fileNames: [String]
    let size: CGSize
    /// What makes this block's clock its own. The day of the month, so two
    /// blocks side by side are never in step.
    let phase: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// False while the Memories drawer holding this month is lowered. The
    /// slideshow holds its picture and stops its clock then: nobody can see
    /// it, and it kept the tab busy under the map. Raised again, it carries on
    /// from the picture it was showing.
    @Environment(\.memoriesDrawerVisible) private var isVisible
    /// The picture underneath, always fully opaque, and the one fading in on
    /// top of it. Two slots rather than one index, because the substrate must
    /// never be visible — see below.
    @State private var base: String?
    @State private var top: String?
    @State private var topOpacity: Double = 0
    /// The photographs the clock last ran over. See `run`.
    @State private var clockFiles: [String] = []

    /// How long one photograph holds.
    ///
    /// Long. This is a page you scroll past, not a screensaver, and anything
    /// quick enough to catch the eye while you are reading below it is a
    /// distraction rather than a detail.
    private static let dwell: Duration = .seconds(5)
    /// And how long the handover takes. Slow enough to read as a dissolve
    /// rather than a cut.
    private static let fade: Double = GridConstants.monthPhotoFadeDuration

    var body: some View {
        ZStack {
            if let base { picture(base) }
            if let top { picture(top).opacity(topOpacity) }
        }
        .task(id: Clock(fileNames: fileNames, running: isVisible)) { await run() }
    }

    /// What the slideshow's task restarts on.
    private struct Clock: Equatable {
        let fileNames: [String]
        let running: Bool
    }

    private func picture(_ name: String) -> some View {
        CachedImageView(fileName: name, width: size.width,
                        height: size.height, cornerRadius: 0,
                        showsPlaceholder: false)
            .scaleEffect(1.03)
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
        // Paused: leave whatever is on the block exactly as it is. The drawer
        // may still be sliding away, and a handover cut short here would be
        // seen.
        if !isVisible, base != nil { return }
        // Resuming after a pause carries on from the picture showing (a
        // handover cut short left the incoming one on top, at full strength
        // by now). A day whose photographs changed starts at its newest, as
        // it always did.
        let resuming = clockFiles == fileNames
        clockFiles = fileNames
        let showing = top ?? base
        let kept = resuming ? showing.flatMap { fileNames.firstIndex(of: $0) } : nil
        base = kept.map { fileNames[$0] } ?? fileNames.first
        top = nil
        topOpacity = 0
        guard fileNames.count > 1, !reduceMotion, isVisible else { return }

        // Offset the first tick so the month does not turn over at once.
        try? await Task.sleep(for: .seconds(Double(phase % 7) * 0.7))
        var next = (kept ?? 0) + 1
        while !Task.isCancelled {
            try? await Task.sleep(for: Self.dwell)
            guard !Task.isCancelled else { return }
            let name = fileNames[next % fileNames.count]
            #if DEBUG
            PerfProbe.count("SlideshowTick")
            #endif
            top = name
            withAnimation(GridConstants.monthPhotoFade) { topOpacity = 1 }
            try? await Task.sleep(for: .seconds(Self.fade))
            guard !Task.isCancelled else { return }
            base = name
            top = nil
            topOpacity = 0
            next += 1
        }
    }
}

/// Which month the tower is showing, and how to change it.
///
/// **Three paragraphs about a pair of chevrons used to sit above this**, headed
/// `‹ SEPTEMBER ›`, describing how they stepped one month at a time and how they
/// were dimmed rather than hidden at the ends of the range. The chevrons were
/// removed on the owner's call (below) and their documentation outlived them,
/// which is exactly the trap CLAUDE.md names about the water: a doc comment for
/// a deleted control reads precisely like a control you cannot find. Deleted.
///
/// A `Menu` rather than a wheel or a sheet: it is the platform's own control for
/// "choose one of these", it renders as UIKit's menu with no styling of ours on
/// it, and it needs no room on the page when it is closed.
///
/// **A menu, and nothing else.** It carried a `‹` and a `›` on either side of
/// the title as well, which the owner's call removed: "why does there have to
/// be arrows on the sides if its a drop down menu, that works better through
/// that". They are right, and the reason is not only that it is two controls
/// for one job — it is that they are two DIFFERENT jobs wearing one hat. The
/// arrows walk one month at a time; the menu jumps anywhere. Anybody wanting
/// last March had to either press `‹` six times or discover that the title in
/// the middle was also a button, and the arrows made it look less like one by
/// flanking it.
///
/// It is leading-aligned now rather than centred, because it is a control at
/// the top of a page rather than a title. Centred, with the arrows gone, it
/// read as a heading that happened to be tappable.
struct MonthPicker: View {
    let title: String
    /// Every month there is, newest first, with what to call each one.
    var months: [Date] = []
    var titleFor: (Date) -> String = { _ in "" }
    var onSelect: (Date) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 0) {
            Menu {
                ForEach(months, id: \.self) { month in
                    Button {
                        // Every control in this app answers the finger — the
                        // month menu was the one that did not.
                        HapticsEngine.lightTap()
                        onSelect(month)
                    } label: {
                        Text(titleFor(month).capitalized)
                        if titleFor(month) == title { Image(systemName: "checkmark") }
                    }
                }
            } label: {
                // **A CONTROL, NOT A LABEL WITH A CHEVRON GLUED ON.**
                //
                // The owner, 2026-09-30: "why does the September dropdown look
                // like that, it doesn't look good at all."
                //
                // It was set as a `SectionHeading` — small caps, kerned, in
                // `inkSecondary` — on the argument that the page can show
                // SEPTEMBER twice and two weights of ink would read as two
                // different kinds of thing. That argument is sound and it
                // produced the wrong object: this is the only control on the
                // page that changes what the whole page is about, and it was
                // rendered as the quietest mark on it. A heading that happens
                // to be tappable is the thing it was already warned against
                // three comments up.
                //
                // So it takes the shape every other control in the app takes —
                // the header's own month pill on the Wins tab, which this is
                // the sibling of — and it is set in ink rather than in grey,
                // because the month IS the subject here. The gallery's own
                // month heading below stays a heading; one of them is a
                // control and one is a label, and now they look like it.
                HStack(spacing: GridConstants.gapTight) {
                    Text(title.capitalized)
                        .font(Typography.headerMedium)
                        .foregroundStyle(AppColors.inkPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.opacity)
                    Image(systemName: "chevron.down")
                        .iconSize(GridConstants.iconChevron, relativeTo: .footnote, weight: .semibold)
                        .foregroundStyle(AppColors.inkSecondary)
                }
                // Layout first, glass after.
                .padding(.horizontal, GridConstants.gapLabel)
                .frame(height: GlassIconButton.defaultSide)
                .glassCapsule(onPage: true)
                .contentShape(Capsule())
            }
            .accessibilityLabel("Month, \(title). Choose another")
            .accessibilityIdentifier("MonthPicker")

            Spacer(minLength: 0)
        }
        .frame(height: 44)
    }

}

extension EnvironmentValues {
    /// Whether the Memories drawer is raised. True everywhere else a month
    /// tower is drawn (onboarding, the widget preview), where nothing hides it.
    @Entry var memoriesDrawerVisible: Bool = true
}
