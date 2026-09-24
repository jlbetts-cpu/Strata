import SwiftUI

/// The first two minutes.
///
/// **Every page is full-bleed and stands in the register of what it
/// introduces.** The tower pages on `WarmBackground`, the camera page inside a
/// real viewfinder, the map page on a real `MemoriesMapView`. Nothing is a
/// picture of the app drawn on a card — the owner's note after seeing the map
/// page was "I love how the maps screen takes up the whole screen, more of the
/// screens should be like that", and he is right: an app that opens by filling
/// the display reads as confident, and one that opens with a small illustration
/// in the middle of a lot of nothing does not.
///
/// **Read it, don't skim it.** Each page gets one line of title and at most two
/// of body. The earlier version ran to four and nobody would have read them.
///
/// **The premium pass, 2026-09-23.** The owner: "I just want our app to be the
/// cleanest and most minimal feel while maintaining the future aesthetic, and
/// premium is number one. It has to feel premium to touch and to look at in
/// every state, every setting... every single state should look like a
/// screenshot moment."
///
/// He named an app he admires for its onboarding. **Nothing of its interface is
/// here, deliberately**: this app was rejected under App Store guideline 4.1(a)
/// for copycat metadata, on an account under extended review, and that guideline
/// names copying another app's interface. What was taken is the set of
/// principles nobody owns, applied through this app's own language:
///
/// - **One idea per page.** Page 0 says what the app is, page 1 teaches the one
///   gesture, page 2 the camera, page 3 the map, page 4 the head, page 5 who
///   made it.
/// - **Type does the work.** The title is the app's own screen-title rung (34,
///   `Typography.screenTitle`) over body at 17, left-aligned to the page margin
///   like every other screen. It was 17 Medium over 17 Regular, centred, which
///   is a caption above a caption with no hierarchy between them.
/// - **The same four bands on every page**, so paging through reads as one
///   object with different contents rather than as six screens. See `body`.
/// - **The value shown, not described.** The real packer, the real block sizes
///   and colours, the real slot, the real lattice, his real photographs, and
///   the camera inside a phone we draw (`DeviceFrame`).
/// - **One thumb move.** One full-width pill on the bottom margin, and the pill
///   never moves between pages; the copy grows upward off it.
///
/// **A rule, not a row of marks.** It was six cells in the corner and the owner
/// said so ("the progress bar doesn't look good tbh"); it is one measured rule
/// across the top of the page now, where the wordmark used to be and where his
/// own reference puts it. `OnboardingProgress` carries the argument.
///
/// **Kept from his earlier calls**, so a later session does not undo them: the
/// pages are full-bleed; the camera page is his photograph with nothing added;
/// the map page is a picture of the map rather than a live one; some, not all,
/// of the opening blocks carry photographs; the tutorial is the real first-fit
/// packer and stops at three rows; the sizes are called Quick, Regular and Deep;
/// the primary action is a plain capsule and not block styling, and disabled is
/// an outline pill rather than a faded one; the head is offered and never
/// required; the thank-you page makes one offer and asks for nothing; the
/// wordmark is 32 on the camera's own line; and the only permission asked for is
/// location, on the page that has just explained it.
struct OnboardingView: View {

    var onFinish: () -> Void

    @State private var step = 0
    @State private var landed = 0
    /// What the tutorial has actually watched the finger do.
    @State private var hasDrawn = false
    /// The tutorial's own tower, and the grid it is packed into — the same
    /// two things `TowerViewModel` keeps.
    @State private var built: [(c: Int, r: Int, w: Int, h: Int, category: HabitCategory)] = []
    @State private var grid: [[Bool]] = []
    /// The size the finger is drawing right now. The slot grows with it,
    /// exactly as the tower's does.
    @State private var drawingSize: BlockSize = .small
    /// The landing the tutorial's lattice is answering, if it is answering one.
    @State private var ripple: LatticeRipple?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    /// Whatever the thing presenting onboarding says about heads, so the value
    /// this view publishes narrows it rather than overriding it.
    @Environment(\.headsAwake) private var coveringHeadsAwake
    @State private var location = LocationService.shared
    @State private var heads = HeadStore.shared
    @State private var showsHeadMaker = false

    #if DEBUG
    private static let debugStep = DebugHarness.onboardingStep
    #endif

    private static let headStep = 4
    private static let lastStep = 5
    /// The cell size that takes the tower margin to margin.
    ///
    /// The owner, 2026-09-23: "why is the tower in the onboarding not margin to
    /// margin". It was a fixed 74, which on a 393pt phone drew a 308pt tower in
    /// a 361pt column: 26pt of air down each side, so the first screen of the app
    /// showed a picture of a tower rather than the tower. The real tower derives
    /// its cell from the width it is handed and so does this, off the same page
    /// margin as every other screen. `cellSize(forGridWidth:)` floors, so the
    /// grid lands within a couple of points of the margin and never over it.
    private static func cell(forWidth width: CGFloat) -> CGFloat {
        GridConstants.cellSize(forGridWidth: width)
    }

    var body: some View {
        ZStack {
            stage
            // **Four bands, the same four on every page** (the owner, via the
            // brief of 2026-09-23: "the use of white space isn't good, the
            // onboarding still feels cramped and a bit unfinished... I would
            // appreciate more of a balanced onboarding experience").
            //
            //   1. The progress rule, under the safe area.
            //   2. The title, 24 under it, with one grey line 12 under that.
            //   3. The composition, centred in whatever is left.
            //   4. The action, 24 clear of the home indicator.
            //
            // **The title is at the TOP** (the owner, 2026-09-23: "the type I
            // feel like it's too thin and it should be on the top"). It was at
            // the bottom, sitting on the button, which put the first thing you
            // read last on the page and left the composition to open it.
            //
            // **Only four vertical numbers are allowed here: 12, 24, 40, 48.**
            // A fifth is how a page starts reading as unfinished, because the
            // eye sees the rhythm break without being able to name it. The only
            // thing that changes between pages is the composition's height, and
            // band 3 absorbs it.
            VStack(spacing: 0) {
                topBand
                words
                art
                actions
            }
            .padding(.horizontal, GridConstants.horizontalPadding)
            .padding(.bottom, GridConstants.gapWide)
        }
        .task {
            #if DEBUG
            if let start = Self.debugStep { step = start }
            #endif
            await runFall()
        }
        // **The head on the page underneath sleeps while the maker is up.**
        //
        // A cover does not make the page under it disappear, so the head page's
        // own head went on blinking and glancing behind the maker, which is work
        // nobody can see (CLAUDE.md: a head sleeps when it cannot be seen).
        // BEFORE the cover modifier, or the maker's own head would sleep too,
        // and ANDed with what this view inherits, because onboarding is itself
        // presented as a cover from Settings. Same shape as `ProfileView`.
        .environment(\.headsAwake, coveringHeadsAwake && !showsHeadMaker)
        // A made head moves you on. Closing the maker without one leaves you
        // here, where "Not now" is one press away.
        .fullScreenCover(isPresented: $showsHeadMaker, onDismiss: {
            guard heads.head != nil, step == Self.headStep else { return }
            withAnimation(GridConstants.naturalSettle) { step += 1 }
        }) {
            HeadMakerView()
        }
    }

    // MARK: - The bands

    /// Band 1: the way back, and how far through you are. Nothing else.
    ///
    /// The owner, 2026-09-23, with a picture: "I would prefer if there was a
    /// back button in the onboarding like this so I can go back to previous
    /// pages with ease."
    ///
    /// **Two rows, not one, because of what one row did to page 0** (the owner,
    /// 2026-09-23: "the screen progress bar looks weird on the first page since
    /// there is no back button"). The button and the rule shared a row, so the
    /// rule began a thumb-width in from the leading margin with nothing in that
    /// space: on page 0 the first thing on the first screen was a gauge that had
    /// been pushed aside by an invisible object. `OnboardingProgress`'s own
    /// opening line is "one rule, margin to margin", and in one row that was
    /// never true on any page.
    ///
    /// Stacked, the rule spans the page margin on every page and the button sits
    /// where iOS puts a back button: in the navigation row above the content. On
    /// page 0 that row is empty air, which is what an app with nowhere to go back
    /// to looks like, and the rule under it does not move by a point when the
    /// button arrives.
    ///
    /// The alternative was letting the rule fill the vacated slot on page 0 and
    /// shrink when the button appears. Rejected: the rule's track and its fill
    /// would both change width in the same transaction, and a gauge whose scale
    /// moves while its reading moves cannot be read as either.
    private var topBand: some View {
        VStack(alignment: .leading, spacing: GridConstants.gapItem) {
            back
            OnboardingProgress(step: step, count: Self.lastStep + 1)
        }
        .padding(.top, GridConstants.gapItem)
    }

    /// **Its room is held on page 0, where there is nothing to go back to**, so
    /// the rule below it never moves between pages. Held with `.opacity`, not by
    /// leaving the button out: the glass then cross-fades in on the 0 to 1 press,
    /// inside the caller's own transaction, rather than appearing.
    ///
    /// **It is the system's Liquid Glass disc**, which is what the owner asked
    /// for (2026-09-23: "the back needs to be liquid glass native iOS"). It was a
    /// bare chevron at `inkSecondary` with no disc and no fill, which read as a
    /// mark on the page rather than as something to press, and which is the same
    /// note he made about the share and settings glyphs that became
    /// `GlassIconButton` in the first place.
    ///
    /// **Note what `GlassIconButton.swift` says at the top**: glass is for a
    /// control floating over content, and on a plain warm page it has nothing to
    /// refract. Two of these six pages are a live viewfinder and a live map,
    /// where that is satisfied exactly; four stand on `WarmBackground`, where it
    /// is the concession. The owner has already settled the direction it trades
    /// against ("see if there are other areas of the app that should get the
    /// glass treatment... I think it's confidence and we need to add it to every
    /// page"), and one disc is inside the three-element glass budget on every one
    /// of these pages.
    ///
    /// The glyph takes `inkPrimary`, the same ink the rule beneath it fills with
    /// and the title under that is set in, so the band reads as one object.
    private var back: some View {
        HStack(spacing: 0) {
            // `GlassIconButton` taps the haptic itself.
            GlassIconButton(systemName: "chevron.left",
                            tint: AppColors.inkPrimary,
                            accessibilityLabel: "Back") {
                // **Going back replays nothing.** The opening cascade is in a
                // `.task`, which does not run again; the tutorial's blocks and
                // its grid are state that is simply still there; the lattice's
                // ripple rests at a phase that draws no cells. There is nothing
                // here that re-arms.
                withAnimation(GridConstants.naturalSettle) { step -= 1 }
            }
            Spacer(minLength: 0)
        }
        .frame(height: Self.backSlot)
        .opacity(step > 0 ? 1 : 0)
        .allowsHitTesting(step > 0)
        .accessibilityHidden(step == 0)
    }

    private static let backSlot: CGFloat = GlassIconButton.defaultSide

    /// **The wordmark is gone from every page** (the owner, 2026-09-23: "the
    /// logo is really not necessary"). He is right twice over: the app's name is
    /// on the icon they just tapped and on the screen they are about to land in,
    /// so a walkthrough repeating it says nothing, and it was the thing crowding
    /// the top of every page and competing with the title for the same job. The
    /// progress rule has that band now and the title carries the identity.
    ///
    /// The air around the composition, above and below it. Band 3 is greedy, so
    /// this is the minimum rather than the measurement: the slack becomes air.
    private static let airArt: CGFloat = 40

    // MARK: - The stage

    /// What the page stands on: the app's own ground, on every page.
    ///
    /// **Nothing is full-bleed any more, and that is a real trade.** The map
    /// page WAS the whole screen and he liked it that way ("I love how the maps
    /// screen takes up the whole screen"). Under the layout he asked for on
    /// 2026-09-23 it stopped working: with the title at the top of the page the
    /// copy lands on the brightest part of a pale map, and holding it up takes a
    /// dark wash across the top third. CLAUDE.md is explicit that a wash over
    /// type is the one thing that makes a map feel cheap, and photographed it
    /// was: the subtitle sat exactly where the wash ran out.
    ///
    /// So both app screens are shown the same way now, in `DeviceFrame`, which
    /// is section 10 rule 8 as well: one answer per problem, not two. The full
    /// bleed version is one revert away if he prefers it.
    private var stage: some View {
        WarmBackground().ignoresSafeArea()
    }

    // MARK: - The art

    /// The page's subject, in the space the header and the copy leave it.
    ///
    /// **A `GeometryReader` is greedy**, so in this stack it is exactly the
    /// leftover: the header, the words and the actions take their own heights
    /// first and this gets the rest. That is what lets the tower size itself to
    /// the page rather than to a constant, and it is why a long title on a small
    /// phone now squeezes the picture instead of landing on top of it.
    @ViewBuilder
    private var art: some View {
        GeometryReader { geo in
            let box = geo.size
            ZStack {
                switch step {
                case 0: tower(in: box)
                case 1: workshop(in: box)
                case 2: screenshot("DemoViewfinder", in: box)
                case 3: memories(in: box)
                case Self.headStep: headPage
                case Self.lastStep: thanks
                default: EmptyView()
                }
            }
            .frame(width: box.width, height: box.height)
        }
        .padding(.bottom, Self.airArt)
    }

    // MARK: - The camera

    /// The camera, in a phone we draw.
    ///
    /// The owner, 2026-09-23: "I like how they put the photo of the app into an
    /// actual like Apple device. I feel like it makes it look a lot cleaner.
    /// Especially we can use that for the camera as like an intro."
    ///
    /// **The photograph is still whole and still untouched**, which was his
    /// earlier instruction about this page and it still holds: "the photo I sent
    /// of the camera is stunning, just show that, dont need to show everything
    /// else." Two versions before that one drew our own ring on it or cropped
    /// its chrome away, and both were the same mistake. A frame around a picture
    /// is not a change to the picture.
    ///
    /// **As large as the slot allows, and whole.** The shell is capped by the
    /// page margin on one axis and by the slot on the other, so it is the biggest
    /// complete phone that fits. It is not run off the bottom of the page to
    /// reach the margin: a device with no bottom is a crop, and a crop is the
    /// broken-looking state he asked never to see.
    /// The Memories tab, composed inside the same phone the camera is in.
    ///
    /// The owner sent a photograph of the real screen: it is a map with his
    /// pictures on it AND the app's own chrome, and what was here was the map
    /// alone. `MemoriesStill` carries the argument and the composition.
    private func memories(in box: CGSize) -> some View {
        let width = min(box.width, box.height * DeviceFrame<EmptyView>.aspect)
        let height = width / DeviceFrame<EmptyView>.aspect
        let band = DeviceFrame<EmptyView>.defaultBezel * 2
        return DeviceFrame(width: width) {
            MemoriesStill(width: width - band, height: height - band)
        }
    }

    private func screenshot(_ asset: String, in box: CGSize) -> some View {
        let width = min(box.width, box.height * DeviceFrame<EmptyView>.aspect)
        return DeviceFrame(width: width) {
            Image(asset)
                .resizable()
                .scaledToFill()
        }
    }

    // MARK: - The tower

    /// Which of the opening blocks carry a photograph.
    ///
    /// **Not all of them.** The owner asked for "some photos in some of the
    /// blocks on the first page, just to put in that human element" — some,
    /// and he is right that it is some. A tower of nothing but pictures is a
    /// photo grid; the point of this screen is that a block is a block whether
    /// or not it has a picture on it, and the mix says that in one look.
    private static let openingPhotos: [Int: String] = [
        0: "DemoPhoto5", 2: "DemoPhoto9", 4: "DemoPhoto2", 6: "DemoPhoto11"
    ]

    /// **Seven blocks, and it was eight.** The eighth started a fourth row on
    /// its own, and a fourth row is what stopped this page going margin to
    /// margin: at four rows the tower is taller than the slot on a small phone,
    /// so the cell would have had to come off the height instead of the width
    /// and the air down the sides would have come back. Seven fills three rows
    /// exactly, with no gap anywhere in the grid, which is also the better
    /// picture of what the app does.
    private static let demo: [(size: BlockSize, category: HabitCategory)] = [
        (.medium, .health), (.small, .work), (.hard, .mindfulness),
        (.small, .social), (.medium, .creativity), (.small, .focus),
        (.small, .health)
    ]

    private static let packed: [(c: Int, r: Int, w: Int, h: Int, category: HabitCategory)] = {
        var grid: [[Bool]] = []
        var out: [(c: Int, r: Int, w: Int, h: Int, category: HabitCategory)] = []
        for item in demo {
            let w = item.size.columnSpan
            let h = item.size.rowSpan
            guard let spot = GridPacker.firstFit(columnSpan: w, rowSpan: h,
                                            columns: GridConstants.columnCount, grid: &grid) else { continue }
            out.append((spot.column, spot.row, w, h, item.category))
        }
        return out
    }()

    /// Real sizes, real colours, placed by the real packer — the same
    /// first-fit scan the tower runs, so this is the app's arrangement rather
    /// than one that resembles it.
    private func tower(in box: CGSize) -> some View {
        let gutter = GridConstants.spacing
        let cell = Self.cell(forWidth: box.width)
        let rows = Self.packed.map { $0.r + $0.h }.max() ?? 1
        let height = CGFloat(rows) * cell + CGFloat(rows - 1) * gutter
        let width = GridConstants.gridWidth(cellSize: cell)

        return ZStack(alignment: .bottomLeading) {
            ForEach(Array(Self.packed.enumerated()), id: \.offset) { index, item in
                block(item.category, columns: item.w, rows: item.h, cell: cell,
                      photo: Self.openingPhotos[index])
                    .offset(x: CGFloat(item.c) * (cell + gutter),
                            y: -CGFloat(item.r) * (cell + gutter)
                                + (landed > index ? 0 : -640))
                    .opacity(landed > index ? 1 : 0)
            }
        }
        .frame(width: width, height: height, alignment: .bottomLeading)
        // **The tower stands on the same surface it will stand on tomorrow.**
        //
        // `TowerLattice` is what the Wins tab draws behind the real tower, and
        // without it the first screen of the app showed a tower on nothing and
        // then handed you a tower on a grid. It is also the page that has to
        // teach what a block IS: you can see the cells, so you can see that a
        // Quick takes one of them and a Deep takes four, and that a photograph
        // is a cell with a picture in it.
        //
        // **Applied after the frame, not before it.** The blocks are placed
        // with `.offset`, which moves the drawing and not the layout, so the
        // ZStack's own size is one block: the grid's bounds only exist once
        // `.frame` has set them, and a background asked for before that would
        // be one cell wide. Same family of trap as CLAUDE.md's note that a
        // block's hit area is bigger than what it draws.
        // **Clipped to the tower's own rows.** `TowerLattice` carries three
        // rows of overhang above whatever it is given, which on the Wins tab is
        // right: the tower is still growing and the surface fades out above it.
        // Here it would put a fading checkerboard into band 1, which is the one
        // band that has to stay empty. Cut to the grid, the surface is a board
        // with a top edge, and this demo fills every cell of it, so at rest it
        // is invisible and during the fall you can see the slots the blocks are
        // dropping into.
        .background(alignment: .bottomLeading) {
            TowerLattice(cellSize: cell, contentHeight: height)
                .frame(width: width, height: height, alignment: .bottom)
                .clipped()
        }
    }

    private func runFall() async {
        guard step == 0, landed == 0 else { return }
        try? await Task.sleep(for: .milliseconds(300))
        for index in Self.packed.indices {
            let fall = GridConstants.dropFallCurve.speed(1 / fallSeconds)
            withAnimation(reduceMotion ? GridConstants.gentleReveal : fall) {
                landed = index + 1
            }
            HapticsEngine.tick()
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 90 : 160))
        }
    }

    /// `t = sqrt(2d/g)`, clamped the way the tower clamps it. Constant
    /// acceleration, no ease out — a falling object does not decelerate into
    /// the ground.
    private var fallSeconds: Double {
        let t = (2 * 640 / GridConstants.dropGravity).squareRoot()
        return min(max(Double(t), GridConstants.dropDurationRange.lowerBound),
                   GridConstants.dropDurationRange.upperBound)
    }

    // MARK: - The camera

    // MARK: - The map

    // MARK: - The tutorial

    /// **The slot grows under the finger, exactly as the tower's does.**
    ///
    /// This was the owner's complaint twice over: "the resize hold block is
    /// still not resizing like it should, it should actually just act like the
    /// tower in the main app." It was pinned inside a fixed square frame, so
    /// `onSizeChanged` had nowhere to go and the ghost never grew — you were
    /// drawing a size you could not see. The tower drives its slot's frame
    /// from `drawingSize` and so does this, with no animation modifier on it,
    /// because `onSizeChanged` already arrives inside a `slotSnap`
    /// transaction and a second one would fight it.
    ///
    /// Accurate in the other direction too: in the tower a tap opens the add
    /// form and only a DRAW logs directly, so the lesson here is the draw.
    private func workshop(in box: CGSize) -> some View {
        let gutter = GridConstants.spacing
        let cell = Self.cell(forWidth: box.width)
        let width = GridConstants.gridWidth(cellSize: cell)
        let spot = ghostSpot
        // A FIXED height, not one that grows with the tower: a box that
        // changes size shoves the title and the button around every time a
        // block lands.
        let rows = Self.maxRows
        let height = CGFloat(rows) * cell + CGFloat(rows - 1) * gutter

        return ZStack(alignment: .bottomLeading) {
            ForEach(Array(built.enumerated()), id: \.offset) { _, item in
                block(item.category, columns: item.w, rows: item.h, cell: cell)
                    .offset(x: CGFloat(item.c) * (cell + gutter),
                            y: -CGFloat(item.r) * (cell + gutter))
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            }

            if let spot {
                NextSlotButton(
                    reduceMotion: reduceMotion,
                    cornerRadius: GridConstants.blockCornerRadius(forCell: cell),
                    previewCategory: Self.tutorialColours[built.count % Self.tutorialColours.count],
                    onSizeChanged: { drawingSize = $0 },
                    action: { size in place(size) },
                    onOpenMenu: { HapticsEngine.lightTap() }
                )
                .frame(width: cell * CGFloat(drawingSize.columnSpan)
                            + gutter * CGFloat(drawingSize.columnSpan - 1),
                       height: cell * CGFloat(drawingSize.rowSpan)
                            + gutter * CGFloat(drawingSize.rowSpan - 1))
                .offset(x: CGFloat(spot.c) * (cell + gutter),
                        y: -CGFloat(spot.r) * (cell + gutter))
            }
        }
        .frame(width: width, height: height, alignment: .bottomLeading)
        // The same surface as page 0 and as the Wins tab, and here it is doing
        // the teaching: the slot is one empty cell among the empty cells, which
        // is what a slot is. The pane of glass the slot is drawn as
        // (`NextSlotButton`) shows these cells through it.
        //
        // **And it answers the landing.** `LatticeRipple` is what the real
        // tower's surface does when a block arrives, in the block's own place
        // and scaled by its size, so the block you place with your finger gets
        // the same reply here as the ones you place tomorrow. Nothing animates
        // because this page appeared; this moves because a finger let go.
        // Cut to the three rows the tutorial can use, for the reason the
        // opening tower's is: the overhang would fill the top of the page with
        // a fading checkerboard. Cut, it is a board with four columns and three
        // rows, which is exactly what this page is teaching.
        .background(alignment: .bottomLeading) {
            TowerLattice(cellSize: cell, contentHeight: height, ripple: ripple)
                .frame(width: width, height: height, alignment: .bottom)
                .clipped()
        }
    }

    private static let tutorialColours: [HabitCategory] = [
        .mindfulness, .health, .creativity, .work, .social
    ]

    /// How tall the tutorial's tower is allowed to get.
    ///
    /// **Three rows and it stops.** The owner: "it goes on forever, it should
    /// break down after a while so it doesnt overlap with things." He is
    /// right — nothing capped it, so a determined finger grew a tower up
    /// through the title and out of the screen. Three rows is enough to hold
    /// one of each size with room to see them, and once there is no room the
    /// slot goes rather than drawing a ghost that cannot land.
    private static let maxRows = 3

    /// Where the slot is standing right now.
    ///
    /// **The same first-fit scan the tower runs**, against the blocks already
    /// placed and at the size the finger is currently drawing — so the ghost
    /// sits exactly where the block will land and MOVES as you change the
    /// size, which is what `TowerViewModel.computeGhostPosition` does in the
    /// app. The owner's note: "it doesn't actually show the tower being built,
    /// it's all centered, it doesn't build the same as it would in the app."
    /// It was one block centred over one slot; it is a tower now.
    private var ghostSpot: (c: Int, r: Int)? {
        var copy = grid
        guard let spot = GridPacker.firstFit(columnSpan: drawingSize.columnSpan,
                                             rowSpan: drawingSize.rowSpan,
                                             columns: GridConstants.columnCount,
                                             grid: &copy) else { return nil }
        guard spot.row + drawingSize.rowSpan <= Self.maxRows else { return nil }
        return (spot.column, spot.row)
    }

    private func place(_ size: BlockSize) {
        var next = grid
        guard let spot = GridPacker.firstFit(columnSpan: size.columnSpan,
                                             rowSpan: size.rowSpan,
                                             columns: GridConstants.columnCount,
                                             grid: &next),
              spot.row + size.rowSpan <= Self.maxRows else { return }
        let category = Self.tutorialColours[built.count % Self.tutorialColours.count]
        withAnimation(GridConstants.dropSettleSpring) {
            grid = next
            built.append((spot.column, spot.row, size.columnSpan, size.rowSpan, category))
        }
        // The surface answers, from the cell the block just filled. Outside the
        // spring on purpose: the ring is a keyframe track of its own, triggered
        // by this value's `started`, and it is not cleared afterwards because a
        // finished track rests at a phase that draws no cells at all (see
        // `TowerLattice.rings`).
        ripple = LatticeRipple(column: spot.column, row: spot.row,
                               columnSpan: size.columnSpan, rowSpan: size.rowSpan)
        drawingSize = .small
        if size != .small { hasDrawn = true }
        HapticsEngine.success()
    }

    // MARK: - Your head

    /// **Offered, never required** (owner: make it "visible to the user instead
    /// of just hidden in the settings", and the head is 100% optional). One
    /// page, one head, shown the way it would be your picture: in a circle
    /// on a colour, blinking and glancing. Yours once you have made one; until
    /// then the creator's, the same head the next page leans over his photo.
    private var headPage: some View {
        ZStack {
            Circle()
                .fill(HabitCategory.creativity.style.baseColor)
            if let rig = heads.head ?? HeadRig.creatorRig {
                TappableHead(rig: rig, side: Self.headCircle * ProfileAvatar.headShare, greets: true)
            }
        }
        .frame(width: Self.headCircle, height: Self.headCircle)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private static let headCircle: CGFloat = 200

    // MARK: - The thank you

    /// **A person, not a brand.** The owner's first app, so it is first person
    /// and it makes one offer rather than three. No rating prompt and no share
    /// sheet: asking for something on the screen where you are thanking
    /// somebody turns the thank you into a transaction.
    private var thanks: some View {
        // **Centred, like every other page's composition.**
        //
        // The owner, 2026-09-23: "the thank you genuinely screen looks broken,
        // like it's not in the middle." It was on the left margin, which is
        // right for the TEXT band and wrong here: the other five pages centre a
        // tower, a board, a phone and a head in this slot, and a portrait hard
        // against the left with the whole band empty beside it reads as
        // something that failed to lay out rather than as a composition. The
        // title and the line under it still hang off the margin; this is the
        // composition, and compositions are centred.
        VStack(spacing: GridConstants.gapItem) {
            Image("CreatorPortrait")
                .resizable()
                .scaledToFill()
                .frame(width: 190, height: 190)
                .clipShape(Circle())
                .overlay { Circle().strokeBorder(AppColors.inkQuiet.opacity(0.22), lineWidth: 1) }
                .shadow(color: .black.opacity(GridConstants.shadowOpacity), radius: 14, y: 6)
                .accessibilityLabel("Jayden, who made Strata")
                // **The head sticker is off this page.**
                //
                // The owner, 2026-09-23: the page "looks broken", and the
                // sticker is the part that reads that way. It hung off the
                // portrait's bottom right over empty page, clipped by nothing,
                // so the overlap looked like a mistake rather than like a head
                // leaning in. CLAUDE.md records the pairing as deliberate ("the
                // same person twice"), and this supersedes it for one reason
                // that did not exist when it was decided: the page BEFORE this
                // one is now a full page of that same head, alive, as its
                // subject. Twice in two pages is a repeat, not a motif.
                // Restoring it is one overlay.

            VStack(spacing: 2) {
                Text("Jayden")
                    .font(Typography.headerMedium)
                    .foregroundStyle(AppColors.inkPrimary)
                Text("Founder, developer and product designer")
                    .font(Typography.bodySmall)
                    .foregroundStyle(AppColors.inkSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        // **And the hand offset is gone, which is what "not in the middle"
        // actually was.** Measured on the screenshot he was looking at: the
        // band ran 259 to 664 and the block sat at 302 to 541, which is 43
        // above and 123 below. Every other page's composition is centred by the
        // layout; this one was centred and then shoved up 40 by a number left
        // over from the old bottom-aligned design, and 40 is exactly the gap
        // between those two numbers. Nothing on these pages is positioned by
        // hand now.
    }

    private static let linkedIn = "https://www.linkedin.com/in/jaydenbetts"

    private var connectButton: some View {
        Button {
            if let url = URL(string: Self.linkedIn) { openURL(url) }
        } label: {
            Text("Connect on LinkedIn")
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.slotInk)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Capsule().strokeBorder(AppColors.slotInk.opacity(0.35), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Words

    /// The page's one idea, in two sizes.
    ///
    /// **Type does the work here, and it was not doing any.** The title was
    /// `headerMedium` and the body `bodyLarge`: 17 Medium over 17 Regular, which
    /// is a caption above a caption, with the weight as the only thing telling
    /// you which is which. The title is the app's one screen-title rung now
    /// (`Typography.screenTitle`, 34 at the default setting, the same size
    /// Memories and a day are set at), so the page has a hierarchy you can read
    /// without looking for it, and the body carries the sentence.
    ///
    /// **Left, to the page margin, and not centred.** Every other screen in the
    /// app names itself on the left at `GridConstants.horizontalPadding`, so
    /// centred copy was the one place the walkthrough stopped looking like the
    /// app it introduces. Left-aligning also gives a 34pt title somewhere to
    /// wrap: centred, a three-line title is three different measures.
    ///
    /// **The inks are the app's own** rather than `Color.white` and a hand-typed
    /// 0.82, which is what they were when two of these pages stood on a
    /// photograph. Every page stands on `WarmBackground` now, so there is one
    /// pair: `inkPrimary` for the title and `inkSecondary` for the line under it.
    private var words: some View {
        VStack(alignment: .leading, spacing: GridConstants.gapItem) {
            Text(title)
                // **SF Pro, bold, and that is the owner's final call.**
                //
                // A third face was tried for exactly one build. He looked at
                // the same headline set in SF Pro, Jaro, Geist and Instrument
                // Sans and landed on "maybe let's just keep it at SF Pro
                // tbh". Which is the right answer for the reason the design
                // doc gives: two faces, and a third one is a decision nobody
                // has to keep defending. Bold rather than medium is his other
                // note here, that the type was too thin.
                .font(Typography.screenTitle)
                .fontWeight(.bold)
                .foregroundStyle(AppColors.inkPrimary)
                // It never shrinks to fit. If a title does not fit, the copy is
                // too long: section 10 rule 3.
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(Typography.bodyLarge)
                .foregroundStyle(AppColors.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        // 24 under the rule above it, 40 down to the composition.
        .padding(.top, GridConstants.gapWide)
        .padding(.bottom, Self.airArt)
    }

    /// **The sizes are called what the rest of the app calls them.** These
    /// said small, medium and large, and nothing after onboarding does: the
    /// camera review, the win sheet and the photo caption all say Quick,
    /// Regular and Deep. A new person was taught one set of words and then
    /// met another. The shape still teaches the gesture; the words are the
    /// ones they will see again.
    ///
    /// **And nothing here watches you.** Page four said "It remembers where
    /// you were", which puts the app in the role of something keeping track
    /// of a person. The photograph keeps its place instead, which is what the
    /// location permission and the empty map already say.
    private var title: String {
        switch step {
        case 0: return "Everything you did, stacked up"
        case 1: return hasDrawn ? "That's how every win is made" : "Quick, regular or deep"
        case 2: return "A win can be a photograph"
        case 3: return "Every photo keeps its place"
        case Self.headStep: return heads.head == nil ? "Make your own head" : "That's your head"
        default: return "Thank you, genuinely"
        }
    }

    private var subtitle: String {
        switch step {
        // **One idea, and the sizes belong to the next page.** This read
        // "Finish something and it becomes a block: quick, regular or deep,
        // depending on what it took", which taught the three sizes one page
        // before the page whose whole job is to teach the three sizes, and it
        // was the longest line in the walkthrough. The first screen has one
        // thing to say and somebody has to believe it.
        case 0: return "Finish something and it becomes a block."
        case 1: return hasDrawn
            ? "Pull nothing and it's a quick one. The size is how much it took."
            : "Hold the slot and pull. Sideways for a regular win, up for a deep one. Let go to drop it in."
        case 2: return "Take it here and the picture becomes the block."
        case 3: return "Your wins land on the map where you took them."
        case Self.headStep: return heads.head == nil
            ? "Fifteen seconds with the front camera. Use it as your picture or add it to your photos, if you like."
            : "Find it in Profile, and on your photos. It stays on this phone."
        default: return "You're one of the first people to open my first app. If you find a bug or want something added, I'd love to hear from you."
        }
    }

    // MARK: - Actions

    /// **One rule for this band: the primary is last, and it never moves.**
    ///
    /// Its bottom edge is 24 above the safe area on all six pages, its height
    /// is fixed, so it lands in exactly the same place every time. Anything
    /// secondary stacks ABOVE it and the composition gives up the room, which
    /// is how the thank-you page's LinkedIn button has always worked.
    ///
    /// **Which is why the head page's decline is above the button and not
    /// under it.** The brief asked for both "the Skip sits 12 under the button"
    /// and "do not let the button move between pages", and with a control
    /// below it those two cannot both be true: a decline under the pill pushes
    /// the pill up by its own height plus the gap on that one page, and paging
    /// onto it would shift the primary action 30pt. Reserving the space on the
    /// other five was ruled out in the same message, and it is the thing that
    /// reads as unfinished anyway. So the gap moves to the other side of the
    /// button, where it costs nothing and the pill is provably identical.
    private var actions: some View {
        VStack(spacing: GridConstants.gapItem) {
            if step == Self.lastStep { connectButton }

            // **Only where something is genuinely optional, which is the head**
            // (the owner, 2026-09-23: "there shouldn't be a skip button other
            // than when doing the face, not every page of the onboarding, and
            // the spacing looks off for that as well").
            //
            // On the other five pages it was an escape hatch out of a
            // six-page walkthrough offered six times, under a button that
            // already says what happens next. It declines the head here, not
            // the tour: the thank you is still to come.
            if offersHead {
                Button("Not now") {
                    HapticsEngine.lightTap()
                    withAnimation(GridConstants.naturalSettle) { step += 1 }
                }
                .font(Typography.bodySmall)
                .foregroundStyle(AppColors.inkQuiet)
            }

            // **A native button.** It was a `BlockSurface` — the app's own
            // object, which sounded right and looked like a slab. The owner:
            // "simplify the button, it shouldnt have the block styling, just
            // make it simple like an apple native button." A block is a win.
            // A button is not a win.
            // **A filled capsule we control, not `.borderedProminent`.**
            //
            // The native prominent style greys itself out when disabled, and
            // grey on this page's ground is grey on grey — the owner: "the
            // button is lowkey invisible during the onboarding flow, same
            // colour as the background, when its grey." A primary action that
            // vanishes when it is waiting for you is the worst moment to
            // vanish, because that is exactly when somebody is looking for it.
            //
            // Same shape and weight as the system's, so it still reads as an
            // ordinary iOS button; the only difference is that WE decide what
            // disabled looks like, and it is the same pill at 55% rather than
            // a different, paler control.
            Button {
                HapticsEngine.lightTap()
                advance()
            } label: {
                Text(actionTitle)
                    .font(Typography.headerMedium)
                    // **Disabled is a different control, not a faded one.**
                    //
                    // It was a 12% ink pill with a 55% ink label, which is a
                    // pale copy of the filled one: photographed, "What else"
                    // was grey type on grey, which is the exact thing he
                    // complained about once already ("the button is lowkey
                    // invisible during the onboarding flow, same colour as the
                    // background, when its grey").
                    //
                    // An outline is not a paler pill, it is a different object,
                    // and that is what section 10 rule 6 asks for: clearly
                    // there or clearly not. The label is `inkTertiary`, which
                    // measures 4.8:1 on this ground, so what it says is still
                    // readable while it waits; the ring is `inkQuiet` at 3.1:1,
                    // the floor for something that is a shape rather than text.
                    .foregroundStyle(canAdvance ? pillLabel : disabledInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background {
                        if canAdvance {
                            Capsule().fill(pillFill)
                        } else {
                            Capsule().strokeBorder(disabledRing,
                                                   lineWidth: GridConstants.strokeThin)
                        }
                    }
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canAdvance)
            .animation(GridConstants.gentleReveal, value: canAdvance)

        }
    }

    private var canAdvance: Bool { step != 1 || hasDrawn }

    /// The primary pill's fill.
    ///
    /// **It is `inkPrimary`, and it was `slotInk`** (the owner,
    /// 2026-09-23: "the button isn't like black... the buttons being like a
    /// darker color"). `slotInk` is the app's warm black, 64,61,57, and against
    /// this page it composites to a soft brown-grey rather than to a black.
    /// `inkPrimary` is the strongest ink the app writes with and it is already
    /// what the title above it is set in, so the page's two loudest things are
    /// now the same ink: measured over the ground, the pill is 37,37,38 and its
    /// label clears 13.9:1. No new colour was invented to get there.
    private var pillFill: Color { AppColors.inkPrimary }

    /// The pill's words: the page's own ground, on a pill of the page's own ink.
    private var pillLabel: Color { WarmBackground.top }

    /// What the action says while it is waiting for you, and the ring around it.
    private var disabledInk: Color { AppColors.inkTertiary }

    private var disabledRing: Color { AppColors.inkQuiet }

    /// The head page, with no head made yet.
    private var offersHead: Bool { step == Self.headStep && heads.head == nil }

    private var actionTitle: String {
        switch step {
        case 0: return "Let me try"
        case 1: return "What else"
        case 2: return "Go on"
        case 3: return location.canAsk ? "Turn on places" : "One more thing"
        case Self.headStep: return heads.head == nil ? "Make my head" : "One more thing"
        default: return "Start"
        }
    }

    private func advance() {
        // **The map page is where the asking belongs.**
        //
        // It is the one screen that has just explained what the permission is
        // for, which is the whole of Apple's guidance on priming: ask where
        // the answer is obvious, never at launch. Leaving the page is the
        // moment — the button says what it will do.
        if step == 3, location.canAsk {
            location.requestAccess()
        }
        if offersHead {
            showsHeadMaker = true
            return
        }
        guard step < Self.lastStep else { onFinish(); return }
        withAnimation(GridConstants.naturalSettle) { step += 1 }
    }

    // MARK: - Drawing

    private func block(_ category: HabitCategory, columns: Int, rows: Int,
                       cell: CGFloat, photo: String? = nil) -> some View {
        let gutter = GridConstants.spacing
        let width = cell * CGFloat(columns) + gutter * CGFloat(columns - 1)
        let height = cell * CGFloat(rows) + gutter * CGFloat(rows - 1)
        return BlockSurface(
            cornerRadius: GridConstants.blockCornerRadius(forCell: cell),
            scale: cell / GridConstants.blockReferenceCell,
            // The photo blocks' own wash. A white veil at the block's usual
            // strength floors a photograph's luminance; the tower drops to
            // 0.06 for exactly this and so does the map.
            washOpacity: photo == nil ? GridConstants.blockScrimOpacity : 0.06
        ) {
            ZStack {
                category.style.baseColor
                if let photo {
                    Image(photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: width, height: height)
                        .clipped()
                }
            }
        }
        .frame(width: width, height: height)
    }
}
