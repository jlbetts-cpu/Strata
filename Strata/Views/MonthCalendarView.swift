import SwiftUI

/// **The month, as a calendar that fills in.**
///
/// The owner, 2026-09-30: "it would look a lot better if the top part with the
/// blocks actually looked like a calendar and acted like one, and it would be
/// filled like the lattice with the number — the number can be a placeholder,
/// and the calendar can kind of fill up as you go. Make the calendar look a lot
/// more premium and fit the tower design."
///
/// **What it replaces, and why that was the problem.** `MonthTowerView` packed
/// the month's days with the same first-fit algorithm the day tower uses: a day
/// with seven wins became a 2×2, a quiet one a 1×1, and they settled into
/// whatever holes were left. It is a beautiful object and it is not a month. A
/// day's POSITION carried no meaning — the 30th could sit above the 3rd — so
/// every block had to print its own number to say which day it was, and the
/// grid was, in his word, floating blocks.
///
/// A calendar fixes that by giving position back its meaning. The 14th is in
/// the third row under Thursday because that is where the 14th is. Nothing has
/// to be explained.
///
/// **Three things keep it in the app's vocabulary rather than making it a
/// widget somebody dropped in:**
///
/// 1. **Every cell is a lattice pane.** The same translucent white the Wins
///    tab's tower stands on, at the same strength, so an empty day is the same
///    object as an empty slot. That is what "filled like the lattice" means —
///    the month is a surface that has cells, and the wins fill them.
/// 2. **A filled day is a BLOCK**, drawn by `BlockSurface` with
///    `EtherealFill` and `BlockRim`, which is the same object the tower is
///    built from. The calendar fills with the thing the app is made of.
/// 3. **One lamp over the whole grid**, from `BlockLight`, so a day in the
///    left column catches the light on its right shoulder exactly as a block
///    in the tower does.
///
/// **The number is always there**, in every cell, filled or not — his
/// "placeholder". On an empty day it is the date, quietly; on a filled one it
/// sits on the block's own frosted band. Which means the grid reads as a month
/// before anything is in it, and a month that is half full looks half full
/// rather than sparse.
struct MonthCalendarView: View {
    /// The packed month. Only `dayOfMonth`, the colour, the photographs and the
    /// count are read — the packing's columns and rows are exactly what a
    /// calendar throws away.
    let packed: MonthTower.Packed
    /// The month being shown, for its length and its first weekday.
    let month: Date
    /// The calendar, for the month's length and for where today falls. It no
    /// longer decides a column, since the columns are not weekdays.
    let calendar: Calendar
    let width: CGFloat
    var onSelect: (String) -> Void = { _ in }
    var transitionNamespace: Namespace.ID?

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Geometry

    /// **FOUR, AND NO WEEKDAYS.** The owner, having seen the seven-column
    /// version: "I think I liked the 4 per row or whatever it was — don't need
    /// the day of the week, just need all the days, because I want each day to
    /// be tappable, and we can keep the quick block size for each day."
    ///
    /// Which keeps the half of the calendar he asked for and drops the half he
    /// did not. What he wanted was that every day is THERE and every day can be
    /// pressed — a month you can see the shape of and reach into. What a
    /// seven-column layout adds on top of that is weekday alignment, and that
    /// costs the thing this page is actually for: at seven columns the cell is
    /// 48pt, which is not a block, and a day's photograph in it is a stamp.
    ///
    /// At four, the cell is the tower's own — `GridConstants.cellSize` on this
    /// width, the size a Quick win is — so a day on this page and a win on the
    /// Wins page are the same object at the same size. The days simply run in
    /// order, which is all a month has to do to be read as one when every cell
    /// carries its own number.
    static let columns = 4
    private var spacing: CGFloat { GridConstants.spacing }
    private var cell: CGFloat {
        max((width - spacing * CGFloat(Self.columns - 1)) / CGFloat(Self.columns), 1)
    }
    private var radius: CGFloat { GridConstants.blockCornerRadius(forCell: cell) }

    // **No leading blanks.** The seven-column version offset the 1st to its
    // real weekday, which is what makes a calendar a calendar and is exactly
    // what four columns gives up. The days run from the first cell.

    private var dayCount: Int {
        calendar.range(of: .day, in: .month, for: month)?.count ?? 30
    }

    private var rows: Int {
        Int(ceil(Double(dayCount) / Double(Self.columns)))
    }

    /// The day's block, by day of month, so a cell can ask for its own.
    private var byDay: [Int: MonthTower.Block] {
        Dictionary(packed.blocks.map { ($0.dayOfMonth, $0) }, uniquingKeysWith: { a, _ in a })
    }

    /// Today, when today is in this month. Everything after it is drawn fainter:
    /// a month fills up as it is lived, and a future Thursday is not an empty
    /// one, it is one that has not happened.
    private var todayIfVisible: Int? {
        guard calendar.isDate(month, equalTo: Date(), toGranularity: .month) else { return nil }
        return calendar.component(.day, from: Date())
    }

    // MARK: - Body

    var body: some View {
        let days = byDay
        let today = todayIfVisible
        VStack(alignment: .leading, spacing: GridConstants.gapTight) {
            VStack(spacing: spacing) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<Self.columns, id: \.self) { column in
                            let day = row * Self.columns + column + 1
                            if day >= 1, day <= dayCount {
                                MonthCalendarCell(
                                    day: day,
                                    block: days[day],
                                    side: cell,
                                    radius: radius,
                                    isFuture: today.map { day > $0 } ?? false,
                                    column: column,
                                    // `BlockLight` counts rows from the ground
                                    // up and a calendar is laid out top down,
                                    // so the row is flipped here. Without it
                                    // the lamp hangs underneath the month.
                                    rowFromBottom: rows - 1 - row,
                                    onSelect: onSelect,
                                    transitionNamespace: transitionNamespace
                                )
                            } else {
                                // Before the 1st or after the last: nothing at
                                // all, not an empty pane. A pane there would be
                                // a day this month does not have.
                                Color.clear.frame(width: cell, height: cell)
                            }
                        }
                    }
                }
            }
            // **One lamp over the grid**, the same way `MainAppView` hangs one
            // over the tower. A calendar is a grid of blocks, so it is lit like
            // one: see `BlockLight`. Row 0 is the GROUND row there and the top
            // row here, so the count is the row count and the arithmetic works
            // out the same either way — the lamp hangs above the whole thing.
            .environment(\.blockLight, BlockLight.over(rows: rows, columns: Self.columns))
        }
        .frame(width: width, alignment: .leading)
    }

    // **`weekdays` and `initial(for:calendar:)` are gone** with the seven-column
    // layout. A row of letters over columns that do not mean weekdays would be
    // a label that lies.
}

/// One day. A pane when nothing happened, a block when something did.
private struct MonthCalendarCell: View {
    let day: Int
    let block: MonthTower.Block?
    let side: CGFloat
    let radius: CGFloat
    let isFuture: Bool
    let column: Int
    let rowFromBottom: Int
    var onSelect: (String) -> Void
    var transitionNamespace: Namespace.ID?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.blockLight) private var blockLight

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    /// **0.16 of the cell, which is the month tower's own number.**
    ///
    /// It was 0.30, and the owner: "why are the dates huge when they should be
    /// the same size as the tower?" He is right and the number has a source —
    /// `MonthTowerView` set its day at `cell * 0.16` and solved it off the CELL
    /// rather than off the type scale, precisely because the numeral is the
    /// block's coordinate and has to stay in proportion to the block. At an
    /// 87pt cell that is 14pt against the 26pt I had put there.
    ///
    /// Which is the difference between a label on a block and a tally. This
    /// page already has one number that is allowed to be large — the win count
    /// under a replay card — and a calendar of 30 big numerals competes with
    /// every photograph in it.
    private var numberSize: CGFloat { side * 0.16 }

    var body: some View {
        if let block {
            Button {
                HapticsEngine.lightTap()
                onSelect(block.dateString)
            } label: {
                filled(block)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(day), \(block.winCount) \(block.winCount == 1 ? "win" : "wins")")
        } else {
            empty
                .accessibilityLabel(isFuture ? "\(day), to come" : "\(day), nothing")
        }
    }

    /// A day with wins: the app's own block, at calendar size.
    private func filled(_ block: MonthTower.Block) -> some View {
        BlockSurface(
            cornerRadius: radius,
            scale: side / GridConstants.blockReferenceCell,
            // A white overlay floors a photograph's luminance at its own alpha,
            // so a photographed cell takes less of the frosted band. The tower's
            // photo blocks drop to 0.06 for the same reason and these are the
            // same object.
            washOpacity: block.photoFileNames.isEmpty
                ? GridConstants.blockScrimOpacity : 0.06,
            aim: aim
        ) {
            ZStack {
                Rectangle().fill(EtherealFill.fill(block.category.style.baseColor, aim: aim))
                if !block.photoFileNames.isEmpty {
                    DayPhotoSlideshow(fileNames: block.photoFileNames,
                                      size: CGSize(width: side, height: side),
                                      phase: block.dayOfMonth)
                }
            }
        }
        .frame(width: side, height: side)
        .overlay(alignment: .bottomLeading) { number(.white.opacity(0.92), onPhoto: !block.photoFileNames.isEmpty) }
        .modifier(DayTransitionSource(id: block.dateString, namespace: transitionNamespace))
    }

    /// A day with nothing on it: a well.
    ///
    /// **A WELL, NOT A PANE, AND THE REASON IS THE PAGE.** The first version
    /// filled it with `TowerLattice`'s own white at its own strength, on the
    /// reasoning that an empty day here and an empty slot on the Wins page
    /// should be the same object. Right idea, wrong half of it: a lattice pane
    /// is white BECAUSE it is a translucent sheet with a lit field behind it,
    /// and this page has no field — it is flat clean white. Measured, the pane
    /// came out three levels from the page, which is to say the calendar had no
    /// cells and the filled days were floating again, which is the complaint
    /// this whole redesign started from.
    ///
    /// So it is `slotInk`, which is the token the tower's empty SLOT and the
    /// add sheet's photo well are already made of — an ink that inverts with the
    /// appearance, at the weight those two use. The cohesion survives; it is
    /// just with the other empty thing in the app.
    ///
    /// A future day is half of that. It has not failed to be filled, it has not
    /// come round yet, and a month that gets quietly fainter toward its end is
    /// the whole of "fills up as you go".
    private var empty: some View {
        shape
            .fill(AppColors.slotInk.opacity(Self.wellInk * (isFuture ? 0.45 : 1)))
            // **AND IT WEARS THE LIT EDGE.** The owner: "make sure the empty
            // days are nice lattice."
            //
            // A flat tint is a grey square; what makes the lattice read as a
            // SURFACE with cells in it is that each pane has an edge made of
            // light. A fill alone could not do that here, because a white pane
            // cannot be brighter than a white page — but a faint recess with a
            // lit rim can, and that is what every empty thing in this app
            // already is: the tower's slot, the photo well. Same `BlockRim`,
            // scaled off the cell the way `ColourSwatch` scales its own, so an
            // empty day and a filled one are the same object with and without
            // a win in it.
            .overlay {
                shape.strokeBorder(
                    BlockRim.gradient(in: colorScheme),
                    lineWidth: max(1, GridConstants.blockRimWidth
                                      * side / GridConstants.blockReferenceCell)
                )
                .opacity(isFuture ? 0.45 : 1)
            }
            .frame(width: side, height: side)
            .overlay(alignment: .bottomLeading) {
                number(isFuture ? AppColors.inkTertiary.opacity(0.5) : AppColors.inkQuiet,
                       onPhoto: false)
            }
    }

    /// The same 0.035 the tower's slot and the photo well use.
    private static let wellInk: Double = 0.035

    private func number(_ ink: Color, onPhoto: Bool) -> some View {
        Text(verbatim: StrataFont.digits(day))
            .font(Typography.numeral(numberSize))
            .foregroundStyle(ink)
            // Only over a photograph, which can be any colour under it. Over a
            // flat block the number sits in the frosted band and needs nothing.
            .shadow(color: .black.opacity(onPhoto ? Legibility.ink : 0),
                    radius: Legibility.radius, y: Legibility.y)
            .padding(side * 0.12)
    }

    private var aim: BlockAim {
        blockLight?.aim(column: column, row: rowFromBottom,
                        columnSpan: 1, rowSpan: 1) ?? .overhead
    }
}

/// The zoom source, only where there is a namespace to zoom into.
///
/// A MODIFIER rather than a conditional call, because
/// `matchedTransitionSource` on a nil namespace is not expressible and an
/// `if` around the whole block would duplicate it.
private struct DayTransitionSource: ViewModifier {
    let id: String
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let namespace {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}
