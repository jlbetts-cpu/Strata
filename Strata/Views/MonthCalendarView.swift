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
    /// The calendar to lay out in. Monday-first, matching the view model's.
    let calendar: Calendar
    let width: CGFloat
    var onSelect: (String) -> Void = { _ in }
    var transitionNamespace: Namespace.ID?

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Geometry

    static let columns = 7
    private var spacing: CGFloat { GridConstants.spacing }
    private var cell: CGFloat {
        max((width - spacing * CGFloat(Self.columns - 1)) / CGFloat(Self.columns), 1)
    }
    private var radius: CGFloat { GridConstants.blockCornerRadius(forCell: cell) }

    /// How many empty cells before the 1st.
    ///
    /// `weekday` is 1-based from the calendar's own `firstWeekday`, so this is
    /// the offset from it rather than from Sunday — which is the whole reason
    /// the calendar is handed in rather than taken from `.current`. The view
    /// model lays its months out Monday-first and a header row that disagreed
    /// with the grid by one column would be worse than no header at all.
    private var leadingBlanks: Int {
        guard let first = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return 0 }
        let weekday = calendar.component(.weekday, from: first)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var dayCount: Int {
        calendar.range(of: .day, in: .month, for: month)?.count ?? 30
    }

    private var rows: Int {
        Int(ceil(Double(leadingBlanks + dayCount) / Double(Self.columns)))
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
            weekdays
            VStack(spacing: spacing) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<Self.columns, id: \.self) { column in
                            let day = row * Self.columns + column - leadingBlanks + 1
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

    /// The weekday initials, in the grid's own columns.
    ///
    /// Taken from the calendar rather than written out, so a Monday-first
    /// layout and a Sunday-first one both get the right letters, and a phone
    /// set to another language gets its own.
    private var weekdays: some View {
        HStack(spacing: spacing) {
            ForEach(0..<Self.columns, id: \.self) { column in
                Text(Self.initial(for: column, calendar: calendar))
                    .font(Typography.caption2)
                    .foregroundStyle(AppColors.inkTertiary)
                    .frame(width: cell)
            }
        }
        .accessibilityHidden(true)
    }

    private static func initial(for column: Int, calendar: Calendar) -> String {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let index = (calendar.firstWeekday - 1 + column) % symbols.count
        return symbols[index]
    }
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

    /// The day number's size, solved off the cell so it holds at any width.
    /// A calendar's number is a label on a cell, not a tally — a quarter of the
    /// side is where it stops being readable and starts being decoration.
    private var numberSize: CGFloat { side * 0.30 }

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
