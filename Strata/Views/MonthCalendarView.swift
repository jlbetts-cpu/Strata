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

    /// **SEVEN, WEEKDAY ALIGNED, AND IT WAS FOUR.** The owner, 2026-10-01,
    /// after being shown both built and rendered: "should we make the calendar
    /// look more like a calendar or is the 4 grid the best way to do that, can
    /// you research how we are building things and if that is the right move."
    /// He picked seven.
    ///
    /// **This file's own argument was always for seven and it shipped four.**
    /// The paragraph at the top says a calendar beats the packed tower because
    /// "a day's POSITION carried no meaning", and gives as its example "the
    /// 14th is in the third row under Thursday because that is where the 14th
    /// is". Four columns delivers half of that: position gives you the ordinal
    /// day and not the weekday. The rationale and the layout disagreed.
    ///
    /// **Two measurements decided it.**
    ///
    /// 1. **The month fits.** At seven the grid is five or six rows of 49.4pt,
    ///    about 310 points, so the whole month and the shelf under it are on
    ///    one screen. At four it is eight rows of 93.5, **748 points**, which
    ///    cannot fit under the header on any iPhone: the screen whose job is
    ///    "see your month" never showed you your month.
    /// 2. **The column carries the pattern.** On the September fixture the
    ///    empty days are 7, 14, 21 and 28, and at seven columns those land in
    ///    ONE column. That column is Sunday. A person reads "I never log on
    ///    Sundays" off the shape without being told. At four columns the same
    ///    four days are scattered and say nothing. This is the whole reason
    ///    GitHub's contribution graph is seven rows rather than a ribbon.
    ///
    /// **What it costs, honestly.** The cell goes 89.5 to 49.4, so a day's
    /// photograph is a third of the area it was, and the month stops being the
    /// same 4-column geometry as the tower. The previous note here called a
    /// 48pt cell "not a block" and said a photograph in it is a stamp. That is
    /// true and it is the right trade: this page is a month, and the tower
    /// page is a day. They are different objects and they do not have to be
    /// the same grid. Every cell is still a block drawn by `BlockSurface` with
    /// the same fill, rim and lamp, and 49.4 still clears the 44pt target by
    /// five points.
    ///
    /// **No weekday header row**, which is the other half of what he asked for
    /// twice: "don't need the day of the week, just need all the days". The
    /// alignment still does its work without labels, because a pattern reads
    /// as a vertical stripe whether or not the column is named.
    static let columns = 7

    /// **How much of an empty day is drawn — AN OPEN OWNER DECISION, 2026-10-01.**
    ///
    /// Check 6 of `docs/screen-audit.md` is "greyscale is earned" and it has
    /// caught this calendar once already. Measured on a built page, an empty
    /// day's well is `slotInk` at `MonthCalendarCell.wellInk(filled:)`, 0.018 on a
    /// full month and 0.045 on an empty one, which over
    /// the light page's rgb(247) composites to rgb(244): **3.3 levels out of
    /// 255**, and the pad past the end of the month is 1.6. Both instruments this
    /// app owns are blind to them — `tools/screen-measure.py` calls a pixel
    /// "drawn" at 6 levels and `tools/page-room.py` a row "drawn" at 14 — which
    /// is the same blind spot `docs/space.md` §0 records for the Wins lattice,
    /// and it has a consequence beyond the instrument: the leftmost thing the
    /// page can see in a calendar row is the day NUMERAL, inset 12% of the cell,
    /// so this screen's measured left margin changes with the data. That is one
    /// of the ten left edges clause 11d fails on.
    ///
    /// So the real question is the owner's, and it is brand-visible: thirty-one
    /// cells for an empty month, or the ground showing through where there is no
    /// win. **Nothing here has been changed on my own judgement.** The three
    /// renderings were photographed and put to him:
    ///
    ///   - `.wells` — what ships: an invisible recess, a lit rim, a grey numeral.
    ///   - `.numbers` — the numerals he asked for by name ("it would be filled
    ///     like the lattice with the number, the number can be a placeholder"),
    ///     with the recess and the rim removed. Subtraction with no measurable
    ///     visual cost, because the recess measures 3.3 levels.
    ///   - `.ground` — nothing at all on a day with no win. This one contradicts
    ///     that instruction, which is why it is his call and not mine.
    ///
    /// The flag itself lives in `DebugHarness.calendarEmptyDay`, with every
    /// other launch argument, because a flag that is read from `ProcessInfo` in
    /// a view is a flag nobody finds.
    enum EmptyDay: String {
        case wells, numbers, ground
    }

    /// A `let`, read once: this is asked by all thirty-one cells on every
    /// render, and scanning the launch arguments per cell per frame is a cost
    /// with no upside. In a release build it is a constant.
    static let emptyDay: EmptyDay = {
        #if DEBUG
        if let choice = DebugHarness.calendarEmptyDay.flatMap(EmptyDay.init(rawValue:)) {
            return choice
        }
        #endif
        return .wells
    }()

    /// How many cells the 1st sits past the start of its row, which is what
    /// makes the column mean a weekday. Monday first, from the calendar the
    /// caller passes, so a locale that starts on Sunday gets its own offset
    /// rather than this view's opinion.
    private var leadingBlanks: Int {
        let comps = calendar.dateComponents([.year, .month], from: month)
        guard let first = calendar.date(from: comps) else { return 0 }
        let weekday = calendar.component(.weekday, from: first)
        return (weekday - calendar.firstWeekday + 7) % 7
    }
    private var spacing: CGFloat { GridConstants.spacing }
    private var cell: CGFloat {
        max((width - spacing * CGFloat(Self.columns - 1)) / CGFloat(Self.columns), 1)
    }
    private var radius: CGFloat { GridConstants.blockCornerRadius(forCell: cell) }

    private var dayCount: Int {
        calendar.range(of: .day, in: .month, for: month)?.count ?? 30
    }

    /// The offset counts toward the rows, or a month that starts on a Sunday
    /// loses its last row off the bottom.
    private var rows: Int {
        Int(ceil(Double(dayCount + leadingBlanks) / Double(Self.columns)))
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

    /// How much of this month's grid has colour in it. See
    /// `MonthCalendarCell.wellInk(filled:)` for why it is the grid's share and
    /// not the person's.
    private var filledShare: Double {
        guard dayCount > 0 else { return 0 }
        return Double(byDay.count) / Double(dayCount)
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
                            // Shifted by the offset, so every cell before
                            // the 1st falls through to the lattice branch
                            // below. A blank at the head of the month is the
                            // same object as a blank after the 30th: the
                            // surface the month is built on, carrying on.
                            let day = row * Self.columns + column + 1 - leadingBlanks
                            if day >= 1, day <= dayCount {
                                MonthCalendarCell(
                                    day: day,
                                    block: days[day],
                                    side: cell,
                                    radius: radius,
                                    isFuture: today.map { day > $0 } ?? false,
                                    filled: filledShare,
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
                                // **THE TAIL OF THE LAST ROW IS LATTICE.**
                                //
                                // The owner: "add some lattice at the end of
                                // the calendar in the empty spots, just so it
                                // doesn't look like empty state completely."
                                //
                                // This drew nothing, on the reasoning that a
                                // pane there would be a day the month does not
                                // have. True, and it produced a row that stops
                                // halfway across the page and reads as the grid
                                // failing rather than the month ending. The
                                // lattice is the SURFACE, not the days: it is
                                // what the calendar is built on, and it carries
                                // on past the 30th exactly as the tower's
                                // carries on past the top block.
                                //
                                // So it is the empty cell without its number
                                // and without its tap. There is no day there to
                                // name and nothing to open.
                                MonthCalendarPad(side: cell, radius: radius)
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
struct MonthCalendarCell: View {
    let day: Int
    let block: MonthTower.Block?
    let side: CGFloat
    let radius: CGFloat
    let isFuture: Bool
    /// How full the month is, as a share of the days that have happened. Only
    /// an empty cell reads it. See `wellInk(filled:)`.
    let filled: Double
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
    /// **7.9pt on a phone, and that is under the owner's locked 15pt floor**
    /// (2026-10-02, design review, measured: a 49.3pt cell, a 17px glyph).
    /// `docs/type-pass.md` names three sites allowed under 15 and this is not
    /// one of them; it mentions "the month block's `cell * 0.16` numeral" only
    /// as the family a block title belongs to. Raising it is a change to how
    /// the calendar looks, so it is the owner's call: `-strataCalendarNumeral
    /// floor` (DEBUG) photographs it at 15 for him to compare.
    private var numberSize: CGFloat {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-strataCalendarNumeral") { return max(15, side * 0.16) }
        #endif
        return side * 0.16
    }

    var body: some View {
        if let block {
            Button {
                HapticsEngine.lightTap()
                onSelect(block.dateString)
            } label: {
                filled(block)
            }
            // **`.pressSurface`, not `.plain`** (2026-10-01,
            // `docs/consistency-audit.md` §1.8). A calendar cell is a block with a
            // photograph on it: a surface, so it gives by `tapScaleY` and does not
            // dim, which is the rule `pressSurface` carries ("dimming a photograph
            // by 28% reads as the picture dulling rather than the card being
            // pressed"). The photo grid two bands down and the replay row above it
            // both take this; this cell was the third thing on the Memories tab
            // with no answer to a finger. The month's slideshow keeps running
            // under it, because the press is a transform and not a redraw.
            .buttonStyle(.pressSurface)
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
    /// A future day steps back from that. It has not failed to be filled, it
    /// has not come round yet, and a month that gets quietly fainter toward its
    /// end is the whole of "fills up as you go". **How far back it steps is
    /// `futureStep(filled:full:)`, not a constant**, and only the surface
    /// carries it: the number says which day it is and nothing else.
    ///
    /// **The rim is the half of this that the light page does not get.**
    /// Measured on the empty month: `BlockRim` is white, so against the night
    /// ground it renders rgb(89) on rgb(30), **59 levels**, and against the
    /// light page rgb(247) on rgb(245.6), **1.5**. The dark calendar is a grid
    /// of outlined cells and the light one is a grid of recesses. Both read, and
    /// the rim is the block language so it stays — but it means the LIGHT page's
    /// cell is carried by its fill alone, which is why the fill's floor is
    /// measured there and not here.
    private var empty: some View {
        // The recess and the rim are the `.wells` rendering; the numeral
        // survives in `.numbers` too, because the owner asked for it by name.
        // See `MonthCalendarView.emptyDay` — this is an open decision of his and
        // the shipping default is unchanged.
        Color.clear
            .frame(width: side, height: side)
            .overlay { if MonthCalendarView.emptyDay == .wells { well } }
            .overlay(alignment: .bottomLeading) {
                if MonthCalendarView.emptyDay != .ground {
                    // **Quieter too.** Thirty grey numerals is thirty pieces of
                    // greyscale, and an empty day's number is a coordinate rather
                    // than a reading — you look for it, you do not read it. The
                    // filled days keep theirs in white, where it has a block to sit
                    // on and something to label.
                    //
                    // **THE NUMBER NO LONGER CARRIES `isFuture`** (2026-10-01,
                    // check 12). It was `isFuture ? 0.45 : 0.75`, and on the
                    // light page that renders the glyph at **rgb(182) on 244,
                    // 1.84:1** against the 3:1 a mark this size is held to — on
                    // thirty of the thirty-one cells, because every day after
                    // today is a future one and a month the owner has not logged
                    // in yet is almost all future. Measured off
                    // `/tmp/s2/light/m1-memories-empty.png`. The past-and-empty
                    // value is 2.97:1, which is the 3:1 this was signed off at.
                    //
                    // **The split is the fix, and it is one sentence: the
                    // SURFACE says whether the day has happened, the NUMBER says
                    // which day it is.** Both were saying the first thing, and
                    // the number was the one that could not afford to. The well
                    // still steps back for a day that has not come round — see
                    // `futureStep(filled:full:)` — so today is still the darkest
                    // cell on a bare month without the numerals paying for it.
                    //
                    // **And 3:1 was the wrong bar** (2026-10-02, design review).
                    // A day's number is a NUMERAL, text by WCAG 1.4.3, and the
                    // 0.75 measured **2.91:1** on the built page (rgb 141 on
                    // a 240 well, `/tmp/r2/light/m3-memories-half.png`) against
                    // the 4.5 text is held to. Full `inkTertiary` is the ink
                    // `CountReadout` reads at on this same page.
                    number(AppColors.inkTertiary, onPhoto: false)
                }
            }
    }

    private var well: some View {
        shape
            .fill(AppColors.slotInk.opacity(
                Self.wellInk(filled: filled)
                * (isFuture ? Self.futureStep(filled: filled, full: 0.45) : 1)))
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
                // The rim rides the same ramp as the fill, at its own full-month
                // value, so the cell stays one object: a recess and its lit edge
                // stepping back together rather than a rim that holds still
                // while the surface under it moves. `0.75 * 0.533` is the 0.4
                // this shipped at, to three places.
                //
                // **AND IT IS A TENTH OF THAT IN DARK MODE, BECAUSE A WHITE RIM
                // IS NOT A SCHEME-NEUTRAL THING** (2026-10-02). See
                // `emptyRimScale(in:)` for the measurement.
                .opacity(Self.emptyRimScale(in: colorScheme)
                         * 0.75 * (isFuture ? Self.futureStep(filled: filled, full: 0.533) : 1))
            }
    }

    /// **The empty cell's rim, which was TEN TIMES as loud on the night ground
    /// as on the light page** (2026-10-02).
    ///
    /// `BlockRim.gradient` is made of WHITE, in both schemes, because that is
    /// what a block's rim is: the thing that says a coloured plane is lit from
    /// above. On an empty cell there is no coloured plane under it, only the
    /// page — and a white line on a near-white page is nearly nothing while a
    /// white line on a near-black one is a drawn edge. The fill does not have
    /// this problem, because `slotInk` inverts.
    ///
    /// **Measured on one calendar row in both schemes**, sampled every 2pt
    /// across it (`/tmp/c2/light/m3-memories-full.png` against the dark capture
    /// of the same screen):
    ///
    ///                 gutter   cell fill   rim      fill step   rim step
    ///     light        237        238      244        1           6
    ///     dark          32         37       54        5          17
    ///
    /// Sampled on one clean row of day cells — the first row holds the
    /// out-of-month pads and the rows with numerals in them read the numeral,
    /// and both of those read as the rim if you let them. **The rim is 6 levels
    /// against 17**, and the FILL is the mirror of it: 1 level in light against
    /// 5 in dark, because `slotInk` inverts and a "well" on the night ground is
    /// a highlight rather than a recess.
    /// `docs/screen-audit.md`'s check 12 puts the line between texture and
    /// structure at 4 levels and says so in scheme-neutral terms — "on the light
    /// page (247) and the night ground (29), four levels is about where a flat
    /// edge stops being resolvable at arm's length" — so in light this rim is
    /// texture, as intended, and in dark it is structure. Thirty-five outlined
    /// boxes is the "grid of boxes" the owner has refused twice on measurement,
    /// and it is the same fault as `TowerLattice`, which measures 2.0 levels of
    /// spread in light and 7.0 in dark on the day album.
    ///
    /// **The rim is not needed in dark, and the reason is in the paragraph that
    /// put it there**: "A fill alone could not do that here, because a white
    /// pane cannot be brighter than a white page — but a faint recess with a lit
    /// rim can." On the night ground a recess CAN be darker than the page, and
    /// the fill is already doing it at 6 levels. So the rim is kept at a tenth,
    /// where it is still the cell's edge and no longer its loudest part, rather
    /// than deleted: it is what keeps an empty day and a filled one the same
    /// object, which is this cell's whole construction.
    ///
    /// **0.35, solved on the build rather than derived.** Two iterations were
    /// photographed and measured on the same row: 0.15 put the rim at 2 levels
    /// and 0.07 at 1, both of them QUIETER than the light page's 6 and both of
    /// them past the point where the cell stops being drawn at all. The
    /// relationship is near enough linear between 1.00 (17 levels) and 0.15 (2),
    /// so 0.35 lands it on the light page's 6. **Parity in levels is the target,
    /// not a smaller number**: in dark the rim is the only thing drawing the
    /// cell, because the fill cannot cut a recess into a near-black ground.
    /// **The light value does not move by a thousandth**, which is deliberate:
    /// the owner looked at and accepted the light calendar, and a dark-mode
    /// correction that moves the daylight is the thing this app has been caught
    /// doing four times in the other direction.
    static func emptyRimScale(in scheme: ColorScheme) -> Double {
        scheme == .dark ? 0.35 : 1
    }

    /// **How dark an empty day is, and it depends on how many of them there
    /// are. Two of the owner's instructions pull opposite ways and they are
    /// both about this number.**
    ///
    /// 2026-09-30, when it went from 0.035 to 0.018: *"make sure we aren't
    /// using any unnecessary greyscale elements, it should be fairly minimal."*
    /// He was looking at a month with wins in it, where thirty grey squares
    /// beside them are not thirty slots, they are a grey field with some colour
    /// in it.
    ///
    /// 2026-10-01: *"the memories looks good but you cant really see anything
    /// half the time ... the empty state has to look just as good."* He was
    /// looking at a month with one win in it, where those same squares are the
    /// only thing on the page and 0.018 over a 247 ground is **3.3 levels**,
    /// which is at the edge of what an eye resolves.
    ///
    /// **Neither instruction is wrong and neither is about greyscale.** They are
    /// both about the same rule: the structure carries the page exactly as much
    /// as the content does not. A month full of wins is a picture of a month and
    /// the grid should get out of its way; a month with one win in it IS the
    /// grid, and a grid you cannot see is a blank page with a dot on it.
    ///
    /// So it is a function rather than a constant. **0.045 empty, 0.018 full**,
    /// which is 8.2 levels and 3.3 levels on the light page — the first reads
    /// as a surface, the second as a whisper, and nothing in between is a value
    /// anybody picked. The crossing point is a quarter full, because by then
    /// there is colour on every row and the colour is doing the work.
    ///
    /// **Measured against the month's LENGTH, and the other version was built
    /// first and rejected by looking at it.** Against the days that have
    /// happened, one win on the 1st of the month is a month 100% full, so the
    /// cells take the whisper — and the screen that produced is the one the
    /// owner was complaining about: a single green square and thirty ghosts.
    /// The elapsed-days ratio is true about the person and false about the
    /// picture, and this number is about the picture. What the eye counts is
    /// how much of the grid has colour in it, so that is what is counted here.
    ///
    /// A perfect first week still reads as nearly empty by this measure (7 of
    /// 31), and that is correct: seven coloured cells out of thirty-five is
    /// still a page the grid has to hold up. Whether the person is doing well
    /// is what the colour says; whether the page has anything on it is what
    /// this decides. `isFuture` carries the other reading, stepping a day that
    /// has not happened back from one that has — see `futureStep(filled:full:)`,
    /// which was a constant 0.45 and is now the same kind of function as this
    /// one, for the same reason.
    static func wellInk(filled: Double) -> Double {
        let t = min(max(filled, 0), fullAt) / fullAt
        return inkEmpty + (inkFull - inkEmpty) * t
    }

    /// **How far a day that has not happened steps back from one that has, and
    /// it depends on how much of the month is there to step back from.**
    ///
    /// `full` is the share this element takes on a full month, which is the
    /// value each of them already shipped: 0.45 for the well's fill and 0.533
    /// for its rim (0.4 of the past day's 0.75). **At `fullAt` and above this
    /// returns exactly that, so the state the owner signed off on 2026-09-30
    /// renders to the pixel.** Below it the step shortens to `stepBare`.
    ///
    /// **The defect it fixes, measured on the light page at 402x874.** The 0.45
    /// was tuned on a month with wins in it, where the future is the tail of the
    /// month and the colour carries the page. On a month with nothing in it
    /// every day after today is a future one: on 1 October that is **30 of 31
    /// cells**, so the dim was not dimming a tail, it was dimming the page. The
    /// wells rendered 3.5 to 4.3 levels below their own gutter, at or under
    /// check 12's 4-level floor, on the exact screen the owner was looking at
    /// when he said "you cant really see anything half the time".
    ///
    /// **It is the same rule as `wellInk(filled:)` and that is why it is the
    /// same shape**: the structure carries the page exactly as much as the
    /// content does not. "A month fills up as it is lived" is a statement about
    /// a month with something in it; on a bare one there is nothing to be the
    /// faint end of.
    ///
    /// **0.72 bare, and not 1.0, because today has to stay marked.** The only
    /// thing distinguishing today on an empty month is that its cell is the one
    /// that is not stepped back. At 0.72 the pair is 8.2 against 5.9 levels,
    /// a ratio of 1.39 — above Kubovy's one-rung 1.33, so it still reads as two
    /// weights — and 5.9 clears the floor by half as much again. At 1.0 the
    /// grid would be uniform and today would vanish into it; at 0.45 it is the
    /// screen he complained about.
    ///
    /// **This only ever applies to the CURRENT month.** `todayIfVisible` is nil
    /// for any other, so `isFuture` is false throughout a past month and this
    /// function is not consulted.
    static func futureStep(filled: Double, full: Double) -> Double {
        let t = min(max(filled, 0), fullAt) / fullAt
        return stepBare + (full - stepBare) * t
    }

    /// What a day that has not happened keeps when the month is bare. See
    /// `futureStep(filled:full:)` for why it is not 1.
    private static let stepBare: Double = 0.72

    /// 8.2 levels on the light page: a surface, which is what a month with
    /// nothing in it has to be.
    private static let inkEmpty: Double = 0.045
    /// 3.3 levels: the whisper the owner asked for when there are wins to look
    /// at instead.
    private static let inkFull: Double = 0.018
    /// **Where the grid hands the page over to the colour: 45% of the days.**
    ///
    /// Counted off the thirty-five cell grid a seven column month draws. At
    /// 0.45 of a 31 day month, 14 cells have colour in them and every one of
    /// the five rows has at least two, so there is no row the grid is holding
    /// up on its own. At a quarter, 8 cells, two rows can still be bare. The
    /// whole range below this is spent on the sparse months, which is where the
    /// owner was looking when he said he could not see anything.
    private static let fullAt: Double = 0.45

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


/// The surface past the end of the month: a lattice cell with no day in it.
///
/// Drawn at half the weight of an empty DAY, which is the distinction that
/// keeps it honest. An empty day is a day you could have filled; this is not a
/// day at all, and if the two looked alike the calendar would be claiming the
/// month had 32 of them.
private struct MonthCalendarPad: View {
    let side: CGFloat
    let radius: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        Color.clear
            .frame(width: side, height: side)
            .overlay {
                // Only in the `.wells` rendering: in the other two there is no
                // empty DAY to be half the weight of, so a pad with nothing to
                // be quieter than is just a mark on the ground.
                if MonthCalendarView.emptyDay == .wells {
                    shape
                        .fill(AppColors.slotInk.opacity(0.009))
                        .overlay {
                            shape.strokeBorder(
                                BlockRim.gradient(in: colorScheme),
                                lineWidth: max(1, GridConstants.blockRimWidth
                                                  * side / GridConstants.blockReferenceCell)
                            )
                            // The same dark-mode correction the empty DAY's rim
                            // takes, for the same reason and in the same
                            // proportion: this rim is the identical white
                            // gradient and a pad sits on the identical ground.
                            // See `MonthCalendarCell.emptyRimScale(in:)`.
                            .opacity(MonthCalendarCell.emptyRimScale(in: colorScheme) * 0.45)
                        }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
