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
/// **No progress indicator at all.** It was six cells in the corner, then one
/// measured rule across the top where the wordmark used to be, and the owner's
/// verdict on the rule is the end of the line: "the progress bar is lowkey
/// clutter ngl." Six screens is not far enough to need a gauge, and the page
/// already has a back button saying which way is behind you. The reading
/// survives as the top band's accessibility label, for the one audience that
/// cannot see how much copy is left.
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
    @Environment(\.colorScheme) private var colorScheme
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
    /// **A row of its own, which outlived the rule it was separated from.** The
    /// button and the progress rule used to share one row, and on page 0 that
    /// put the first thing on the first screen — a gauge — a thumb-width in from
    /// the margin, pushed aside by an invisible object. Stacking them fixed it.
    /// The rule is gone now and the stack stays: the button sits where iOS puts
    /// a back button, in a navigation row above the content, and on page 0 that
    /// row is empty air, which is what an app with nowhere to go back to looks
    /// like.
    ///
    /// **NO PROGRESS RULE.** The owner, 2026-09-30: "the progress bar is lowkey
    /// clutter ngl."
    ///
    /// It was softened one commit ago — `inkPrimary` to `inkSecondary`, 38 on a
    /// 247 page to 97 — and softening was answering the wrong question. The
    /// thing wrong with a full-width bar across the top of six white pages is
    /// not how dark it is; it is that it is a second piece of chrome on a page
    /// that already has a back button, and six screens is not far enough to
    /// need a gauge. Premium is subtraction.
    ///
    /// **The reading survives where it is actually used.** It is on the band as
    /// an accessibility label, so VoiceOver still says "step 3 of 6" — which is
    /// the one audience the rule was genuinely load-bearing for, because they
    /// cannot see how much copy is left.
    private var topBand: some View {
        VStack(alignment: .leading, spacing: GridConstants.gapItem) {
            back
            mark
        }
        .padding(.top, GridConstants.gapItem)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Step \(step + 1) of \(Self.lastStep + 1)")
    }

    /// **The illustration's room, held open before there is an illustration.**
    ///
    /// The owner, 2026-09-30: "the onboarding still doesn't feel really clean. I
    /// want to leave room for illustrations and more white space."
    ///
    /// Both halves of that are the same slot. It is `markSide` square on the
    /// leading margin of every page, between the rule and the title, and until
    /// he draws into it it is simply air — which is the other thing he asked
    /// for. Holding the height whether or not the asset exists is the whole
    /// point: the day the drawings land, nothing below them moves.
    ///
    /// **Same place, same size, on all six**, so the set reads as a set. That is
    /// the one thing a corner mark has to do that a big centred illustration
    /// cannot: `docs/illustrations.md` asks for six of these and they only work
    /// if they are clearly the same object six times.
    ///
    /// `UIImage(named:)` rather than `Image(_:)` because `Image` of a missing
    /// asset draws a warning placeholder; this has to draw nothing.
    @ViewBuilder
    private var mark: some View {
        Color.clear
            .frame(width: Self.markSide, height: Self.markSide)
            .overlay {
                if let art = UIImage(named: "OnboardingMark\(step)") {
                    Image(uiImage: art)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(AppColors.inkPrimary)
                }
            }
            .accessibilityHidden(true)
    }

    /// Big enough to read as a drawing rather than an icon, small enough that
    /// six of them are a set of marks rather than six illustrations.
    private static let markSide: CGFloat = 56

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
                            onPage: true,
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
    /// **56, not 40.** The band below the copy is where the page breathes, and
    /// the owner asked for more of it. It is still one of the four numbers this
    /// file allows itself — see the note on `body` — because 56 is 40 plus the
    /// grid's own 16, not a fifth value invented for the occasion.
    private static let airArt: CGFloat = 56

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
            // **THE BOARD NEEDS A GROUND, OR THE LESSON IS INVISIBLE.**
            //
            // Measured on this page: cells 248, gutters 244, which is 1.03:1.
            // The lattice draws its cells as WHITE PANES, and a white pane
            // over a 245 ground has four values of room to be seen in. The
            // component's own note says exactly this and says what fixed it on
            // the Wins tab: "a white pane cannot be brighter than a ground
            // that is already at 240, so the answer was never to outline the
            // pane, it was to stop the ground being that bright. `DayGround`
            // sits lower now."
            //
            // The Wins tab gets that lower ground from `GroundField`, which is
            // made of the blurred photographs you have taken. On the walkthrough
            // there are none, so the ground is flat `WarmBackground.top` and
            // the panes have nowhere to go. Raising `TowerLattice.strength`
            // cannot fix it: white on 245 tops out at 255, which is 1.07:1 at
            // full opacity.
            //
            // This page is the one where the board is the LESSON. You are
            // being taught that a Quick takes one cell and a Deep takes four,
            // and you cannot be taught it by cells you cannot see. So the
            // board gets the seat the Wins ground has, at a little over twice
            // the strength because it has to work on a flat page rather than
            // on a field: the ground under the board falls to about 232 and
            // the panes read at about 240 on it, with the board itself a
            // visible 13 under the page. That is a board on a page, which is
            // what it is.
            ZStack(alignment: .bottomLeading) {
                Rectangle()
                    .fill(AppColors.slotInk.opacity(Self.boardSeat))
                    .frame(width: width, height: height)
                TowerLattice(cellSize: cell, contentHeight: height, ripple: ripple)
                    .frame(width: width, height: height, alignment: .bottom)
                    .clipped()
            }
            .clipShape(RoundedRectangle(cornerRadius: GridConstants.blockCornerRadius(forCell: cell),
                                        style: .continuous))
        }
    }

    /// The ground under the tutorial board. `GroundField.seat` is 0.030 and
    /// sits under a field of blurred photographs; this is a flat page with
    /// none, so it carries the whole difference itself.
    private static let boardSeat: Double = 0.07

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
    /// **The disc is lit, because the real one is.** `ProfileView` fills a head's
    /// disc with `EtherealFill.fill(baseColor)` and this filled it with the flat
    /// `baseColor`, so the page that introduces your head showed it on a
    /// different surface from the page it lives on. Measured on the 2026-10-01
    /// shot: a flat 174,152,250 across the whole 200pt circle, where every other
    /// coloured object in the app carries the core-to-rim lift. One recipe, and
    /// it is already written.
    private var headPage: some View {
        ZStack {
            Circle()
                .fill(EtherealFill.fill(HabitCategory.creativity.style.baseColor))
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
                .elevation(.floating)
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

            // **`GridConstants.spacing`, and it was a hand-typed 2.** Four is
            // the grid's own gutter and it is what `RestoreBackupView` already
            // puts between a count and the word under it, which is the same
            // pairing: a name and the line that says what it is. A raw 2 is the
            // only number on these six pages that came from neither ladder, and
            // the audit's check 7 catches exactly that. The pair moves 2pt.
            VStack(spacing: GridConstants.spacing) {
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

    /// The one offer on the last page.
    ///
    /// **It was wearing a second black and a ring nobody could see.** Measured
    /// on the 2026-10-01 shot of page 6: the label sampled 64,61,57 (`slotInk`,
    /// the tower's warm black) while the title 450pt above it sampled 36,36,36
    /// (`inkPrimary`) — two blacks on one page, which is the thing
    /// `AppColors` exists to stop. And the ring, `slotInk` at 35%, sampled 180
    /// on a 243 ground: **1.89:1**, against the 3:1 the guideline asks of a
    /// shape. The only thing saying "this is a button" was a line you cannot
    /// see.
    ///
    /// So: the page's own ink for the word, and `inkQuiet` for the ring, which
    /// is a token rather than a hand-typed 35% of a different black. Computed
    /// over the sampled ground: the label clears 14.3:1, which is what the title
    /// on this page already measures, and the ring 3.3:1 against the 3.0 floor.
    ///
    /// The height is `pillHeight`, shared with the primary below it, so the two
    /// capsules on this page are provably the same object and not two 50s that
    /// happen to agree.
    private var connectButton: some View {
        Button {
            if let url = URL(string: Self.linkedIn) { openURL(url) }
        } label: {
            Text("Connect on LinkedIn")
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.inkPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: Self.pillHeight)
                .background(Capsule().strokeBorder(AppColors.inkQuiet,
                                                   lineWidth: GridConstants.strokeThin))
                .contentShape(Capsule())
        }
        // `PressResponse.swift`: "Use this rather than `.plain` on anything that
        // is not already Liquid Glass." Every button on these six pages was
        // `.plain`, which draws the label and nothing else, so the one shared
        // component written to answer "every button with a clean animation" had
        // no call sites in the app at all.
        .buttonStyle(.pressWord)
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
            if offersHead { decline }

            action
        }
        // On the whole band, not on the button, because the two states of the
        // action are now two different views and the cross-fade between them is
        // the thing being animated.
        .animation(GridConstants.gentleReveal, value: canAdvance)
    }

    /// **"Not now", with a target you can actually hit.**
    ///
    /// The label is `bodySmall` and carried no frame, so the Button's hit area
    /// was the text's own line box: **18pt tall**, against the 44 the HIG asks
    /// for and against the 44 the back disc on the same page already is. It was
    /// also set in `inkQuiet`, which `AppColors` documents as held to 3:1
    /// "deliberately, these are UI elements and decorative glyphs rather than
    /// text somebody has to read". This is text somebody has to read: it is the
    /// only way to decline the head. Computed over the sampled page ground
    /// (243,243,243), `inkQuiet` lands at 3.3:1 and `inkSecondary` at 6.0:1,
    /// against the 4.5 a word is held to. A decline you can barely read is a
    /// dark pattern rather than a quiet one.
    ///
    /// **And it answers the owner's note that it "sits tight above the primary
    /// button".** He is right and the cause is the target, not the gap: the
    /// VStack's 12 was 12 from the pill to a line box with no padding in it, so
    /// the word sat 12pt off a 50pt capsule. A 44pt box around the same word
    /// puts 13pt of its own air under the text, so the optical gap goes
    /// **12 to 25** without the pill moving a point and without a fifth
    /// vertical number: the stack spacing is still `gapItem`.
    ///
    /// The frame and the `contentShape` are on the LABEL, not on the Button. A
    /// `.frame` outside a Button grows the view and not the hit test, which is
    /// how a 44pt target gets declared and not measured.
    private var decline: some View {
        Button {
            HapticsEngine.lightTap()
            withAnimation(GridConstants.naturalSettle) { step += 1 }
        } label: {
            Text("Not now")
                .font(Typography.bodySmall)
                .foregroundStyle(AppColors.inkSecondary)
                .frame(height: Self.tapFloor)
                .padding(.horizontal, GridConstants.gapLabel)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressWord)
    }

    /// The primary action, in one of its two states.
    ///
    /// **A native button.** It was a `BlockSurface`, the app's own object,
    /// which sounded right and looked like a slab. The owner: "simplify the
    /// button, it shouldnt have the block styling, just make it simple like an
    /// apple native button." A block is a win. A button is not a win.
    ///
    /// **THE WAITING STATE IS NOT A DISABLED `Button`, AND THAT IS A
    /// MEASUREMENT.** (2026-10-01)
    ///
    /// It was one Button with `.buttonStyle(.plain)` and `.disabled(!canAdvance)`,
    /// switching its own background. The comment above it said the label was
    /// `inkTertiary` "at 4.8:1" and the ring `inkQuiet` "at 3.1:1", which is what
    /// those two inks measure when they are drawn. They were not being drawn.
    /// Sampled off page 2 of the 2026-10-01 screenshots, where "What else" waits
    /// for you to draw a block:
    ///
    ///     ring, declared inkQuiet 0.45     rendered 188 on 243   1.71:1
    ///     label, declared inkTertiary 0.55 rendered 176 on 243   1.96:1
    ///
    /// Both are exactly HALF the alpha they ask for, to three decimal places,
    /// and the stems are flat runs rather than antialiased edges, so this is not
    /// coverage. **A disabled plain button is dimmed by the environment**, which
    /// `HeadMakerView` already found and wrote down the other way round: its
    /// shutter "came out at 128 of 255 during capture instead of white", and it
    /// routed around the dim by not disabling the button.
    ///
    /// So the state the owner has complained about twice ("the button is lowkey
    /// invisible during the onboarding flow, same colour as the background, when
    /// its grey") was still invisible, and the fix that was written for it was
    /// being halved before it reached the glass. An outline was the right idea:
    /// it is a different object rather than a paler pill, which is what section
    /// 10 rule 6 asks for. It just has the least ink of anything on the page to
    /// carry a ratio with, so it is the first thing a 0.5 multiplier kills.
    ///
    /// The waiting pill is therefore plain views with no `Button` and no
    /// `.disabled` anywhere near them, so nothing can halve it. Computed over
    /// the same sampled ground: ring `inkTertiary` 4.6:1 and label
    /// `inkSecondary` 6.0:1, against floors of 3 and 4.5. **Re-shoot page 2 and
    /// sample `row 791` and the ring at `col 201` y 766 to prove it**: the only
    /// way this fix is wrong is if something else is also dimming, and the
    /// numbers above say what the pixels have to be.
    ///
    /// **What VoiceOver loses, and what it gets instead.** `.disabled` is what
    /// makes VoiceOver say "dimmed", and there is no way to keep that and keep
    /// the contrast. So the waiting pill is one accessibility element whose
    /// VALUE says why it is waiting, which is more than "dimmed" ever said, and
    /// it offers no activate action, so nothing lies about being pressable.
    @ViewBuilder
    private var action: some View {
        if canAdvance {
            Button {
                HapticsEngine.lightTap()
                advance()
            } label: {
                Text(actionTitle)
                    .font(Typography.headerMedium)
                    .foregroundStyle(pillLabel)
                    .frame(maxWidth: .infinity)
                    .frame(height: Self.pillHeight)
                    .background { litPill }
                    .contentShape(Capsule())
            }
            // `PressResponse.swift` asks for this rather than `.plain`, and
            // `pressWord` is its own variant for a control whose label is a word:
            // "a word at 6% reads as a wobble, so it moves less and dims more".
            .buttonStyle(.pressWord)
        } else {
            waitingPill
        }
    }

    /// **LIT FROM INSIDE.** (2026-09-30)
    ///
    /// The owner, with the reference: "can we make the main buttons like this, I
    /// think this looks super clean." It was a flat capsule of `inkPrimary`.
    ///
    /// Same recipe the blocks now use, so the button and the thing it makes are
    /// visibly the same material: an inside-out radial, most saturated at a core
    /// above centre, thinning toward the rim. Plus the reference's light rim,
    /// brightest at the top.
    ///
    /// **NO BLOOM.** There was a blurred capsule of the button's own colour
    /// behind it, on the reasoning that a lit object lights the page instead of
    /// shading it. The owner: "why is there light coming off of it, please fix
    /// that." He is right and the reasoning was borrowed from the wrong place:
    /// that argument came off the reference image, which is a button floating in
    /// a render with nothing around it to light. This button stands on a page
    /// that is already clean white, so a blue halo on it is not light, it is a
    /// stain the same colour as the button.
    ///
    /// **THE BLOCK'S OWN RIM**, not a second opinion about what a lit edge looks
    /// like. The owner: "make sure it has the same rim design we made in the box,
    /// like that outline fade on the bottom." It was a hand-written white 0.30 to
    /// 0.08, which is the same IDEA and a different curve. `BlockRim` is the
    /// curve, it is already on every block-shaped thing in the app, and it eases
    /// itself off in dark mode. One definition.
    ///
    /// **The fill is flat now, and the rim stays.** `EtherealFill` lightens a
    /// colour toward its rim, which is right on a block, where the thing being
    /// lit is a surface and nothing is written across it. On a button it means
    /// the contrast of the label depends on how long the label is: measured,
    /// 4.69:1 under a short word and 4.24 at the far end of a long one. The rim
    /// is the part of the treatment that reads as light and it costs the label
    /// nothing, because no word reaches it.
    private var litPill: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(pillFill)
            Capsule(style: .continuous)
                .strokeBorder(BlockRim.gradient(in: colorScheme),
                              lineWidth: GridConstants.blockRimWidth)
        }
    }

    /// The same capsule, waiting. See `action` for why this is not a Button.
    private var waitingPill: some View {
        Text(actionTitle)
            .font(Typography.headerMedium)
            .foregroundStyle(disabledInk)
            .frame(maxWidth: .infinity)
            .frame(height: Self.pillHeight)
            .background {
                Capsule().strokeBorder(disabledRing,
                                       lineWidth: GridConstants.strokeThin)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(actionTitle)
            .accessibilityValue("Not yet. Draw a block to go on.")
    }

    /// The height of a primary action, shared with the LinkedIn capsule above it
    /// so the two are provably one object rather than two 50s that agree today.
    private static let pillHeight: CGFloat = 50

    /// The HIG's minimum target, and `GlassIconButton`'s own `defaultSide`. Named
    /// here so the one control on these pages that was under it is measured
    /// against the same number the back disc is.
    private static let tapFloor: CGFloat = GlassIconButton.defaultSide

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
    /// **ONE BLUE, FLAT, AND THE WORD ON IT CLEARS 4.5.** (2026-10-01)
    ///
    /// This pill was the only control in the app still filled with
    /// `AppColors.accent`, the bright blue read off the owner's reference
    /// image. Everything else that carries the primary action moved to
    /// `accentPrimary` when he said "changing the primary to the blue because
    /// I notice in the settings it is still green", so the app had two blues
    /// doing one job, which check 5 of the audit fails on its own terms: one
    /// accent, for the primary action.
    ///
    /// And the word on it could not be read. Sampled off the shipped build
    /// rather than reasoned about: glyphs a flat 255,255,255 on a fill of a
    /// flat 67,195,252, which is **2.03:1** where a 17pt word is held to 4.5.
    /// It is the only control on every page of the walkthrough, so it was the
    /// app's most repeated piece of type and its least readable.
    ///
    /// Nothing about choosing that blue was a decision about the label's
    /// legibility, because nobody had measured the one relationship that
    /// matters here. `accentPrimary`'s own doc has the blue measured three
    /// ways, as ink on the light page, on the dark page, and against a
    /// switch's white thumb, and not once as a white word ON it. That was a
    /// hole in the palette rather than a judgement made badly.
    ///
    /// **Flat, not lit**, and that is the second half of the fix. The
    /// ethereal treatment lightens a fill toward its rim, so a lit
    /// `accentPrimary` measures 4.69:1 at the core and **4.24 at the far end
    /// of a long word**: the number would pass on "Go on" and fail on
    /// "Make your head". A flat fill measures (0, 123, 178) at every point across the pill and
    /// holds **4.69:1** on all of it,
    /// whatever is written in it, and a button is the one object in this app
    /// that has to be the same everywhere a word lands on it.
    ///
    /// The two alternatives, both measured and both rejected:
    ///
    ///     keep `accent`, label warmBlack       5.37:1 core, 5.87 at the rim.
    ///                                          Highest number of the three and
    ///                                          it leaves the app with two
    ///                                          blues, which is the fault under
    ///                                          the fault.
    ///     `accent` at brightness 0.644, white  4.50:1 exactly. A pill deeper
    ///                                          than the reference AND a third
    ///                                          blue to maintain.
    ///
    /// The ink stays a FIXED white rather than an adaptive one: `accentPrimary`
    /// does not flip with the scheme, so an ink that did would pass in light
    /// and fail in dark.
    private var pillFill: Color { AppColors.accentPrimary }

    private var pillLabel: Color { .white }

    /// What the action says while it is waiting for you, and the ring around it.
    ///
    /// **Each moved up one rung on 2026-10-01**, because the previous pair was
    /// being halved before it was drawn: see `action`. Computed over the sampled
    /// page 2 ground (243): `inkSecondary` 6.0:1 for the word, against 4.5 for
    /// text; `inkTertiary` 4.6:1 for the ring, against 3.0 for a shape. The ring stays
    /// quieter than the word, so the waiting pill still reads as an outline with
    /// something written in it rather than as a second filled button.
    private var disabledInk: Color { AppColors.inkSecondary }

    private var disabledRing: Color { AppColors.inkTertiary }

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
