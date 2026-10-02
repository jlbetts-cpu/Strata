import SwiftUI
import SwiftData

/// The plan: what you mean to do, written as blocks-to-be.
///
/// Deliberately the smallest thing that helps. It is a page of bullet points,
/// the way Notes is a page of bullet points — type a line, press return, type
/// another, backspace an empty one away. Everything this app has removed was
/// removed for claiming more structure than anyone wanted to give it, so there
/// is no due date, no priority, no folder and no list-of-lists. There is a
/// repeat, because "the days I do this" is the one thing a plan genuinely
/// needs and the one thing you cannot write in the text.
///
/// **The bullet is a block.** Empty it is an outline, which is the tower's own
/// word for "nothing here yet". Checked it is the real thing, in colour, with
/// a tick. A plan is a picture of the tower you are about to build.
///
/// **A finished line stays until the day turns.** Clearing it the moment you
/// tick it throws away the other half of what this page is for — seeing what
/// you got through. `PlanItem.sweep` does the clearing at the next launch on a
/// new day.
struct PlanSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Called with the line when its block is pressed. The caller opens the
    /// add sheet; the line is ticked at once, and the tick is kept only once
    /// a win is actually saved, so backing out of that sheet does not spend it.
    var onComplete: (PlanItem) -> Void

    @Query(sort: \PlanItem.order) private var allItems: [PlanItem]
    @Query private var habits: [Habit]
    @State private var focused: UUID?
    @State private var detail: PlanItem?

    /// A hairline is `1 / displayScale` (`docs/design-system-future.md` section
    /// 6), which is one device pixel however dense the screen is.
    @Environment(\.displayScale) private var displayScale

    private let calendar = Calendar.current

    // MARK: - The row's geometry
    //
    // **One arithmetic, not two.** The row's leading margin, the empty state's
    // and the separator's inset were three hand-written sums of the same
    // numbers (`horizontalPadding - 11`, `horizontalPadding + 24 + 14`), which
    // is how the separator ended up starting one point off where the text does.
    // Derived from the bullet and its target, so they cannot drift apart.

    /// `PlanBullet`'s own side, which is its default.
    private static let bulletSide: CGFloat = 24
    /// The HIG's minimum target, measured not declared. Every control on this
    /// sheet is this box, whatever its glyph measures.
    private static let tapTarget: CGFloat = 44
    /// What the target adds around the bullet, which the row's margin gives back
    /// so the glyph still lands on the page margin.
    ///
    /// **Derived, and it moves the page one point.** It was written as a literal
    /// 11, which is right for a 22pt bullet and the bullet is 24, so the glyph
    /// sat at 15 while every other page margin in the app is 16. The comment on
    /// the row already claimed it "stays exactly where it was on the page"; now
    /// it does.
    private static let bulletInset: CGFloat = (tapTarget - bulletSide) / 2
    /// Where a line's text starts, and therefore where a separator does. Comes
    /// out at 54, which is what the separator's hand-written sum said.
    private static let textLeading: CGFloat =
        GridConstants.horizontalPadding - bulletInset + tapTarget + GridConstants.spacing
    /// The tap-to-write space under the last line, when the list is long
    /// enough that there is no spare page to give it. On a short list it takes
    /// everything that is left instead. See `content`.
    ///
    /// Not `private`: `SheetRoomTests` checks that the floor the empty page's
    /// split leaves under the invitation is still at least this deep.
    static let tailHeight: CGFloat = 160

    /// **How an EMPTY page divides its spare room: eight shares above the
    /// invitation, five below.**
    ///
    /// Read by `content`, which writes `pageSpace` this many times on each
    /// side; flexible children of a `VStack` split the slack equally, so the
    /// ratio is exact and survives a change of type size, which a fraction of
    /// the viewport would not.
    ///
    /// **8 : 5 is the Fibonacci pair nearest φ, so the invitation stands on
    /// the field's golden section** — the classical answer to where one object
    /// sits in an empty field, and the same canon `docs/space.md` P5 reasons
    /// from about margins. It was CHOSEN BY LOOKING, against two others
    /// photographed at 402x874 and compared side by side, because counting is
    /// not looking:
    ///
    /// - **1 : 1**, the invitation centred at y455. It looks right and it
    ///   fails the clause it was moved for: the break above measures 346 and
    ///   the floor 347, so which of the two is the page's biggest white is a
    ///   coin toss.
    /// - **2 : 1**, at y574. It passes 11c with room to spare and it reads as
    ///   the invitation having FALLEN to the bottom of the sheet rather than
    ///   standing in a field. This one shipped for exactly one build.
    /// - **8 : 5**, the one that ships. Measured on the built sheet: the
    ///   invitation's ink runs y547 to 585, with a 438.0pt break above it and
    ///   254.7 under it, 1.72x. (It is not exactly 1.6 because the shares
    ///   divide the slack left by the invitation's 52pt LAYOUT box while
    ///   `page-room.py` measures its 38.3pt of ink.) The break is
    ///   unambiguously the page's own breath, and on screen it still reads as
    ///   centred, because the eye puts the centre of a field slightly above
    ///   its middle anyway.
    ///
    /// `SheetRoomTests` pins the ratio and pins that the floor it leaves is
    /// still deeper than `tailHeight`.
    static let emptyFieldShares: (above: Int, below: Int) = (8, 5)

    /// Today's list: everything one-off, plus the repeats due today.
    private var items: [PlanItem] {
        allItems.filter { $0.belongs(on: Date(), calendar: calendar) }
    }

    var body: some View {
        NavigationStack {
            content
                .sheetTitle("Plan", drawn: true)
                .toolbar { planToolbar }
                .sheet(item: $detail) { item in
                    PlanItemDetailSheet(item: item)
                }
        }
        // **Full height, and stated.** It was unstated, which happens to give
        // the same thing, and unstated is how two sheets end up differing
        // without anybody choosing.
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        // The page's own ground, as the sheet's material rather than as a layer
        // inside it. `AddWinSheet` records why: through the default frosted
        // glass the tower's colours bleed up behind the controls, and a frosted
        // surface is the block's material, not a sheet's. This was a
        // `WarmBackground` in a `ZStack`, which covers the content area and
        // leaves the sheet's own material to the system.
        .presentationBackground { WarmBackground().ignoresSafeArea() }
    }

    /// **The same bare glyphs every other screen has.**
    ///
    /// These two were plain `ToolbarItem`s, so on iOS 26 they kept the glass
    /// capsule the system puts behind every toolbar item — which the rest of
    /// the app strips deliberately (see the Toolbars note in `MainAppView`). Two
    /// consequences, and the owner hit both: the plan did not look like the
    /// screens either side of it, and the capsule rendered BLACK against this
    /// sheet's warm ground when it was jostled mid-gesture — "i bumped into
    /// the screen tweaking and the apple glass plan button turned black."
    ///
    /// Typed `ToolbarContent` rather than an inline `.toolbar`, because that
    /// is where the availability gate can live:
    /// `ToolbarContentBuilder` supports `if #available` through
    /// `buildLimitedAvailability`, and an inline one does not.
    @ToolbarContentBuilder
    private var planToolbar: some ToolbarContent {
        // **Done on the right, like every other sheet.** It was on the left,
        // with the plus on the right; Profile, Settings and the win sheet all
        // confirm top-right, so the plan was the one screen where a thumb
        // reaching for Done found a plus. The owner's call (2026-09-13).
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarLeading) { addButton }
                .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .topBarTrailing) { doneButton }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarLeading) { addButton }
            ToolbarItem(placement: .topBarTrailing) { doneButton }
        }
    }

    private var doneButton: some View {
        Button {
            HapticsEngine.lightTap()
            tidy()
            dismiss()
        } label: {
            // **44pt of target, whatever the glyph measures.** Audited from
            // the accessibility tree: Done came out 68x36 and the plus 35x36,
            // both under Apple's minimum — and this is the screen the owner
            // had already called "really easy to miss click". A toolbar button
            // is sized by its label unless it is told otherwise.
            Text("Done")
                .font(Typography.headerSmall)
                .frame(minWidth: Self.tapTarget, minHeight: Self.tapTarget)
                .contentShape(Rectangle())
        }
        .foregroundStyle(AppColors.accentWarm)
    }

    private var addButton: some View {
        Button { addLine() } label: {
            Image(systemName: "plus")
                .iconSize(GridConstants.iconToolbar, relativeTo: .body, weight: .medium)
                .foregroundStyle(AppColors.accentWarm)
                .frame(width: Self.tapTarget, height: Self.tapTarget)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Add a line")
    }

    @ViewBuilder
    private var content: some View {
        // **The whole empty page answers a tap, not the first 160pt of it.**
        //
        // Measured off the built sheet at 402x874 with five lines on it: the
        // last line ended at 403pt, so 471pt of the page was empty and only
        // 160 of them did anything. Pressing the middle of a blank page and
        // getting nothing is the opposite of what a page of bullets promises,
        // and it is invisible from the source: the tail was a number, and a
        // number cannot be wrong against a screen it has never been compared
        // to.
        //
        // The `GeometryReader` is what makes the fix arithmetic rather than a
        // guess: the stack is held to at least the viewport's own height and
        // the tail is the flexible thing in it, so it takes exactly whatever
        // the lines left over. On a list taller than the screen the
        // `minHeight` stops binding and the tail falls back to its 160, which
        // is still deep enough to be aimed at rather than found by accident.
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                // Read once. `items` filters `allItems` on every access, and
                // the separator below has to ask how many there are.
                let lines = items
                VStack(alignment: .leading, spacing: 0) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(lines) { item in
                            row(item)
                            // **Between two lines, never after the last one.**
                            //
                            // The hairline was drawn in the `ForEach` body with
                            // the row, so five lines got five separators where
                            // five lines have four boundaries. Measured at
                            // 402x874: a rule at y=403.0 with the page's last
                            // ink at 389 and 471pt of nothing under it, which
                            // is a line separating a list from the empty half
                            // of a sheet. A separator is a statement about two
                            // things; drawn against one it is a rule across the
                            // page.
                            //
                            // Compared by id rather than by an enumerated
                            // index, so the `ForEach` stays keyed on identity:
                            // keyed on position instead, the focused line's
                            // `UITextField` would be re-identified every time a
                            // line above it was added or backspaced away, which
                            // is how a caret ends up jumping rows.
                            if item.id != lines.last?.id { separator }
                        }
                    }

                    // **THE INVITATION SITS IN THE FIELD, NOT AT THE TOP OF
                    // IT** (2026-10-01, check 11c of `docs/screen-audit.md`).
                    //
                    // Measured before: 90.2% of the page empty, one 653.3pt
                    // break, and it was the run UNDER the last band — 93% of
                    // the page's emptiness in one dead tail, against a biggest
                    // interior gap of 39.7. That is the worst ratio in the app
                    // and it is what 11c is for: a page should END, not stop.
                    //
                    // **Eight shares above, five below**, which puts the
                    // invitation on the field's golden section. The ratio, the
                    // two positions it was photographed against, and why a
                    // centred one is not good enough are all on
                    // `emptyFieldShares`. Measured at 402x874: 438.0pt of
                    // break above, 254.7 of floor below, and that floor is
                    // still deeper than `tailHeight` (160), so the
                    // tap-to-write space under the invitation is the one the
                    // audit measured and not a scrap left over.
                    //
                    // **The price, stated: the first line does not appear
                    // where the ghost stood.** The note on `hint` is the
                    // record of why it used to — a 20pt jump between the thing
                    // you pressed and the thing it was pretending to be — and
                    // that distance is about 420pt now. It is paid rather than
                    // hidden: the tap animates on `motionSmooth`, so the page
                    // visibly GATHERS to the top as it becomes a list, which
                    // is a page changing state and not a control teleporting.
                    // The trade is one animated transition, once, against the
                    // worst composition in the app on every visit before the
                    // first line is written.
                    if lines.isEmpty {
                        ForEach(0..<Self.emptyFieldShares.above, id: \.self) { _ in pageSpace }
                        hint
                        ForEach(0..<Self.emptyFieldShares.below, id: \.self) { _ in pageSpace }
                    } else {
                        // Pressing the empty space below the list starts a new
                        // line, which is what a page of bullets does. Without
                        // it the only way to add is the button in the corner,
                        // and the corner is not where anyone looks when they
                        // are writing.
                        //
                        // A written page keeps its lines at the TOP: lines flow
                        // downward, and a list that floats in the middle of a
                        // sheet moves every time one is added. So this branch
                        // is the tail it always was.
                        Color.clear
                            .frame(minHeight: Self.tailHeight, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture { addLine() }
                            .accessibilityLabel("Add a line")
                            .accessibilityAddTraits(.isButton)
                    }
                }
                .padding(.top, GridConstants.gapTight)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    /// One share of the empty page's spare room.
    ///
    /// Flexible children of a `VStack` divide the slack equally, so N of these
    /// take N shares and the ratio is written as how many times it appears
    /// rather than as a fraction that has to be kept in step with the
    /// invitation's own height. It answers a tap like every other blank part of
    /// this page.
    ///
    /// Hidden from VoiceOver on purpose: `hint` is already an "Add a line"
    /// button and the tail below is another, and three identical buttons on an
    /// empty page is a swipe through the same control three times.
    private var pageSpace: some View {
        Color.clear
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(GridConstants.motionSmooth) { addLine() } }
            .accessibilityHidden(true)
    }

    /// **A hairline in ink, not a `Divider`.**
    ///
    /// Section 6: chrome separates with a hairline and with translucency, and a
    /// hairline is `1 / displayScale` in ink at low alpha, never a grey line.
    /// `Divider` draws the platform's separator colour at the platform's
    /// weight, which is the one grey this page had.
    ///
    /// Inset to `textLeading`, so it runs under the words and not under the
    /// bullets: the bullets are a column of objects and a rule through them
    /// would cut the column rather than divide the lines.
    private var separator: some View {
        Rectangle()
            .fill(AppColors.quietFill)
            .frame(height: 1 / displayScale)
            .padding(.leading, Self.textLeading)
            .padding(.trailing, GridConstants.horizontalPadding)
    }

    /// What the page looks like before anything is written on it.
    ///
    /// **Show the line, not a notice.** It was two pieces of grey type in the
    /// corner, which tells you the page is empty — something you can already
    /// see — and gives your hand nothing to aim at. A page of bullets that is
    /// waiting can show one waiting bullet: the same row the real lines use,
    /// ghosted, with the invitation beside it. Tapping anywhere here starts
    /// writing, which is what the empty space below already did and what
    /// nobody could tell.
    ///
    /// **ONE waiting line, not three things in a corner.**
    ///
    /// It was a ghost bullet, a grey bar standing in for text, and a sentence
    /// underneath, and measured at 402x874 the three started at three
    /// different places: the bullet on the page margin at 16.0pt, the grey bar
    /// at 54, and the sentence at **18.3**, which is a margin the app does not
    /// have. The sentence was `gapItem` indented from a stack that was itself
    /// pulled back by the bullet's target inset, so 12 - 10 came out at 2
    /// points of nothing. An empty screen is the one somebody meets before
    /// they know what the feature is for, and this one asked them to read
    /// three objects to learn one thing.
    ///
    /// So the grey bar goes. It said "text goes here" while real text sat
    /// twelve points under it saying the same thing in words, and at 1.20:1
    /// against the page it was the faintest ink on the sheet, which is the
    /// skeleton a screen shows while it is still loading rather than one that
    /// is finished and waiting. The sentence takes its place, at `textLeading`
    /// (54.0pt), which is the column a line's own words sit in. What is left is
    /// a single waiting row: the bullet's silhouette, with the invitation
    /// written where the line will be.
    ///
    /// **It used to sit where the first real line sits, and as of 2026-10-01
    /// it does not.** The original fault is kept here because the arithmetic
    /// still is: the old one carried `gapWide` of top padding against a row's
    /// 4, so the ghost's block started at 174.0pt where a first line's bullet
    /// starts at 154.3, and tapping it made the page jump twenty points as the
    /// thing you pressed was replaced by the thing it was pretending to be. It
    /// still carries the row's own vertical padding, so the ROW it draws is
    /// still exactly a row.
    ///
    /// What changed is where that row stands: `content` now puts it two thirds
    /// down the empty field, for check 11c, and the full argument and the
    /// price are written out there. The short version is that the 20pt
    /// discrepancy this paragraph was written to kill is a ~420pt move now and
    /// it is paid for on purpose, with an animation, because a page whose
    /// biggest white is a 653pt dead tail is the worse of the two faults.
    private var hint: some View {
        // **Centred, not baseline-aligned, and that is what lands it.**
        //
        // The row's `.firstTextBaseline` cannot be borrowed here. Its `-27`
        // guide is calibrated against a `UITextField`, whose baseline SwiftUI
        // derives from the view's own box; a `Text` reports the font's real
        // one, which sits elsewhere, and reusing the number put the ghost
        // eleven points off the line it was meant to stand on.
        //
        // Centring needs no number and is exact where it matters. The ghost's
        // 44pt box is taller than a two-line invitation (40.6pt at the default
        // size), so the `HStack` is 44 and the box sits flush at its top,
        // which is where a real row's bullet box sits too, because the bullet
        // is the tallest thing in that row as well. Measured on the built
        // sheet: line one's bullet glyph starts at 154.3pt, and so does this.
        HStack(spacing: GridConstants.spacing) {
            // **A block, not a circle.** This is a ghost of the bullet
            // beside a real line, and that bullet is a BLOCK — the whole
            // point of the plan is that a line becomes one. A dotted
            // circle is a ghost of something the app does not have: "why
            // is there a circle dotted when it should be a square."
            //
            // Same corner rule as the real one, off the same cell size, so
            // the outline is the exact silhouette of what will land in it.
            // **`bulletSide`, not 22.** The comment above is the test and
            // the outline failed it: the bullet that lands here is 24, so a
            // 22pt ghost was the silhouette of nothing, two points off the
            // real one and a point off the page margin with it.
            //
            // It failed the same test on ink and weight, which is what
            // `PlanBullet.outlineInk` and `outlineWidth(forSide:)` are for:
            // 0.40 at 1.5 measured 2.13:1 against this page where the real
            // bullet measures 3.31:1, so the ghost missed the 3:1 a UI shape
            // is held to while claiming to be the same shape.
            RoundedRectangle(
                cornerRadius: GridConstants.blockCornerRadius(forCell: Self.bulletSide),
                style: .continuous)
                .strokeBorder(PlanBullet.outlineInk,
                              style: StrokeStyle(
                                lineWidth: PlanBullet.outlineWidth(forSide: Self.bulletSide),
                                dash: [GridConstants.ghostBlockDashLength]))
                .frame(width: Self.bulletSide, height: Self.bulletSide)
                .frame(width: Self.tapTarget, height: Self.tapTarget)

            // A line's own size and a line's own column, one step quieter.
            // `bodySmall` put the invitation a tier below everything it is
            // standing in for, which is how it ended up reading as a notice
            // ABOUT the page rather than as the first thing written on it.
            // **One line, and the second clause is cut** (2026-10-01). It read
            // "Write what you mean to do, then press its block when you have."
            // and wrapped to two lines at 15pt Medium, which on a page whose
            // whole composition is one small figure in a big field made the
            // figure a paragraph.
            //
            // What went is a forward reference: "press its block" describes
            // something that happens on the WINS tab, to a block this page has
            // not drawn yet, at a moment that has not arrived. The owner, the
            // same day: "the areas are very self explanitory and I think over
            // explaining components loses the charm." The behaviour is learned
            // the first time a line exists, where the block is in front of you.
            //
            // **The accessibility label was already the short version**, which
            // is the tell: whoever wrote it had decided what the sentence was
            // for and only said it to VoiceOver.
            Text("Write what you mean to do")
                .font(Typography.bodyLarge)
                .foregroundStyle(AppColors.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, GridConstants.horizontalPadding - Self.bulletInset)
        .padding(.trailing, GridConstants.horizontalPadding)
        .padding(.vertical, GridConstants.spacing)
        .contentShape(Rectangle())
        // **Animated, because the page moves now.** The invitation stands two
        // thirds down an empty field (see `content`) and the first real line
        // lands at the top, so the tap is a page gathering itself into a list
        // rather than a swap in place. `motionSmooth` is the ladder's own
        // rung for a layout answering a press.
        .onTapGesture { withAnimation(GridConstants.motionSmooth) { addLine() } }
        .accessibilityElement()
        .accessibilityLabel("Write what you mean to do")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - A line

    private func row(_ item: PlanItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: GridConstants.spacing) {
            Button {
                complete(item)
            } label: {
                PlanBullet(category: item.category, isDone: item.isDone)
                    // **A real 44pt frame, not padding cancelled by negative
                    // padding.**
                    //
                    // It used to be `.padding(11)` for the target and
                    // `.padding(-11)` to take the space back — which shrinks
                    // the LAYOUT and leaves the hit area where it was, eleven
                    // points out on every side. So the left edge of the text
                    // was standing on the bullet's target, and tapping there
                    // to edit a line COMPLETED it instead. The owner: "the
                    // plan screen is really easy to miss click or something
                    // not work."
                    //
                    // Same family as the month tower's `.offset` and the photo
                    // well's unbounded image: in SwiftUI what a view occupies
                    // and what it can be touched through are two different
                    // rectangles, and only the second one catches fingers.
                    .frame(width: Self.tapTarget, height: Self.tapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // The bullet has no text in it, so it has no baseline of its own to
            // align on. This puts one where the glyph's own middle is: measured
            // from the box's bottom, not derived, because where a 17pt line's
            // baseline sits inside its line box is the font's business.
            .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 27 }
            .accessibilityLabel(item.isDone
                                ? "\(item.text), done"
                                : "Log \(item.text.isEmpty ? "this line" : item.text) as a win")

            VStack(alignment: .leading, spacing: 2) {
                PlanTextField(
                    text: Binding(get: { item.text }, set: { item.text = $0 }),
                    placeholder: "",
                    focused: $focused,
                    id: item.id,
                    isDone: item.isDone,
                    onReturn: { addLine(after: item) },
                    onBackspaceWhenEmpty: { backspace(item) }
                )
                if let summary = item.repeatSummary(calendar: calendar) {
                    // **`screenSubtitle`, 15 Medium, and it was 13 Regular**
                    // (2026-10-01, the type pass). A repeat summary is the
                    // quiet line under a line you wrote, and the quiet is `inkQuiet`
                    // rather than two points of size.
                    //
                    // Still costs nothing in layout, which is the number that
                    // had to be rechecked: a row's height is set by the
                    // bullet's 44pt box, and a 17pt line (20.3pt of line box)
                    // plus the 2 plus a 15pt subheadline (20.0) comes to 42.3,
                    // so the row is still 44 either way.
                    Text(summary)
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(AppColors.inkQuiet)
                }
            }

            // The way in, the way Reminders does it — and, like Reminders,
            // only on the line you are actually on.
            //
            // Drawn on every row it was six identical glyphs down the right
            // edge of a page whose whole job is to look like somewhere you
            // write. On the focused row it is one control, next to the thing
            // it acts on, and the rest of the list is text.
            //
            // It stays in the accessibility tree either way: hiding a control
            // from VoiceOver because it is visually quiet would make the
            // repeat settings unreachable without sighted aim.
            if focused == item.id {
                Button { HapticsEngine.lightTap(); detail = item } label: {
                    Image(systemName: "info.circle")
                        // The same icon token the plus and the trash beside it
                        // use, so the three controls on this sheet are one size
                        // rather than two.
                        .iconSize(GridConstants.iconToolbar, relativeTo: .body, weight: .medium)
                        .foregroundStyle(AppColors.inkQuiet)
                        // 44pt, the HIG minimum. The glyph plus 8pt of padding
                        // came to 33, which is a control you have to aim at.
                        .frame(width: Self.tapTarget, height: Self.tapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Options for \(item.text)")
                .transition(.opacity)
            }
        }
        // The bullet's 44pt box already carries its own air, so the row's
        // leading margin gives back what the box added — the glyph stays
        // exactly where it was on the page.
        .padding(.leading, GridConstants.horizontalPadding - Self.bulletInset)
        .padding(.trailing, GridConstants.horizontalPadding)
        // 4pt, the grid's gutter. The bullet's 44pt box already carries 10pt of
        // air above and below a 24pt glyph, so the 6 this was added a fifth
        // number to a row whose every other measure comes from the ladder.
        .padding(.vertical, GridConstants.spacing)
        .contentShape(Rectangle())
        .animation(GridConstants.motionSnappy, value: focused)
        // A context menu, not `.swipeActions`.
        //
        // Swipe actions only exist inside a `List`, and this is a
        // `LazyVStack` — so the swipe-to-delete that was here did nothing at
        // all. A long press works in any container, and it is also what keeps
        // both actions reachable on the rows whose info button is not drawn:
        // VoiceOver surfaces a context menu as custom actions, so nothing is
        // hidden behind having to focus the line first.
        .contextMenu {
            Button { detail = item } label: {
                Label("Options", systemImage: "info.circle")
            }
            Button(role: .destructive) { delete(item) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Editing

    private func complete(_ item: PlanItem) {
        guard !item.isDone else {
            // Pressing a finished line puts it back. Nothing here is
            // irreversible, and a tick you cannot undo is a trap.
            item.completedAt = nil
            try? modelContext.save()
            HapticsEngine.lightTap()
            return
        }
        // Checked NOW, not when the win saves: making the tick wait would
        // leave the commonest gesture in the sheet with no visible result
        // until two screens later. It is optimistic, though. Closing the add
        // sheet without saving takes it back (`MainAppView.tickAwaitingWin`),
        // so the plan never claims a block the tower does not have.
        item.completedAt = Date()
        try? modelContext.save()
        HapticsEngine.success()
        tidy()
        onComplete(item)
    }

    /// A new line wears the colour the tower currently has least of, which is
    /// how a win with no category picks one — so a plan reads like the tower
    /// it will become rather than like a list of one colour.
    private func addLine(after item: PlanItem? = nil) {
        // In the function, not at the three call sites that reach it — the
        // plus button, the empty state and the tap below the last line all
        // make the same thing happen and should all feel the same.
        HapticsEngine.tick()
        let colour = QuickWinService.spontaneousCategory(existing: habits)
        let position = (item?.order ?? allItems.last?.order ?? -1) + 1
        for existing in allItems where existing.order >= position {
            existing.order += 1
        }
        let line = PlanItem(text: "", order: position, category: colour)
        modelContext.insert(line)
        try? modelContext.save()
        focused = line.id
    }

    /// Backspace on an empty line removes it and puts the caret on the end of
    /// the line above — the behaviour every bullet list has, and the reason
    /// this uses a `UITextField` at all.
    private func backspace(_ item: PlanItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let previous = index > 0 ? items[index - 1] : nil
        // Lighter than a deliberate delete: this fires while you are typing,
        // and a full tick on every backspace would be noise.
        HapticsEngine.lightTap()
        modelContext.delete(item)
        StoreReset.commitDelete("backspacing a plan line away", context: modelContext)
        focused = previous?.id
    }

    private func delete(_ item: PlanItem) {
        HapticsEngine.tick()
        if focused == item.id { focused = nil }
        modelContext.delete(item)
        StoreReset.commitDelete("deleting a plan line", context: modelContext)
    }

    /// Drops blank lines. An empty bullet you walked away from was never an
    /// item — the one you are still typing in is left alone.
    private func tidy() {
        for item in allItems
        where item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && item.id != focused {
            modelContext.delete(item)
        }
        StoreReset.commitDelete("dropping blank plan lines", context: modelContext)
    }
}
