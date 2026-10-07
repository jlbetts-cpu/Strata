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

    /// **The walkthrough ends on your first win** (owner-approved,
    /// 2026-10-05): after the thank you, the last page is the tower's real
    /// slot. One tap and your first block lands, with five examples of what
    /// counts, and that win is logged through the normal path
    /// (`OnboardingFirstWin`) as the app opens on Wins. False when Settings
    /// replays the tour, which must not log a win.
    var endsOnFirstWin = true
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
    // `colorScheme` was read here by exactly one thing, the primary pill's
    // `BlockRim.gradient(in:)`, which moved to `PrimaryCapsule` with the pill.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    /// Whatever the thing presenting onboarding says about heads, so the value
    /// this view publishes narrows it rather than overriding it.
    @Environment(\.headsAwake) private var coveringHeadsAwake
    @State private var location = LocationService.shared
    @State private var heads = HeadStore.shared
    @State private var showsHeadMaker = false
    /// The walkthrough has handed over; a second finish is ignored.
    @State private var finished = false

    #if DEBUG
    private static let debugStep = DebugHarness.onboardingStep
    #endif

    private static let headStep = 4
    private static let thanksStep = 5
    /// **The day's goal, set before the first win** (2026-10-06: the owner,
    /// "we need to make sure people understand the product from the gecko",
    /// and the goal crest is the first thing on the home screen now). The
    /// crest itself, empty, with the number to choose under it.
    private static let goalStep = 6
    /// **Your three, asked after the goal and skippable** (the owner's pick,
    /// 2026-10-06: "Yes, ask in onboarding after the goal, skippable"). Wins
    /// you could do on your worst day (`YourThree`), chosen on a first day,
    /// which is a good one: the one time a person is asked to plan for a bad
    /// day while having a good one.
    private static let threeStep = 7
    private static let firstWinStep = 8
    @AppStorage(DailyGoal.defaultsKey) private var dailyGoal = DailyGoal.standard
    @AppStorage(YourThree.defaultsKey) private var threeRaw = ""
    /// The three being chosen, kept only once the button is pressed: Skip
    /// leaves nothing behind.
    @State private var threePicked: [YourThree.Item] = []
    private var lastStep: Int { endsOnFirstWin ? Self.firstWinStep : Self.thanksStep }

    // The first-win page's own state.
    /// The title the win will carry: typed, or filled in by a chip.
    @State private var firstTitle = ""
    /// The size the finger is drawing on the first-win slot.
    @State private var firstSize: BlockSize = .small
    /// The block that landed, once it has: its size.
    @State private var firstLanded: BlockSize?
    /// Its fall, 0 above the page and 1 in the slot.
    @State private var firstFell = false
    @FocusState private var firstTyping: Bool
    /// The colour the first block wears: the slot shows it before the tap.
    private static let firstColour: HabitCategory = .mindfulness
    /// Two rows: room for a Deep, and the board stays a strip under the copy.
    private static let firstRows = 2
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
            //   1. The nav row, and the illustration's slot under it.
            //   2. The title, 24 under that, with one grey line 8 under it.
            //   3. The composition, centred in a field it may not fill
            //      (`compositionCeiling`).
            //   4. The action, 24 clear of the home indicator.
            //
            // **The title is at the TOP** (the owner, 2026-09-23: "the type I
            // feel like it's too thin and it should be on the top"). It was at
            // the bottom, sitting on the button, which put the first thing you
            // read last on the page and left the composition to open it.
            //
            // **Four vertical numbers between the bands, and every one of them
            // is a rung of the app's own ladder: 8, 12, 24, 64.** (Inside a
            // composition is the composition's business: the thank-you page
            // sets a name over its caption on `GridConstants.spacing`, which is
            // the grid's gutter and is argued where it is written.) The rule
            // here is unchanged and
            // it is the right rule — a fifth value is how a page starts reading
            // as unfinished, because the eye sees the rhythm break without
            // being able to name it. What changed on 2026-10-01 is which four.
            // It said "12, 24, 40, 48", and by then the 40 had become a
            // hand-written 56 (argued on `airArt` as "40 plus the grid's own
            // 16") and the 48 was used by nothing. Two of the four numbers were
            // therefore not on the spacing ladder at all, which is the fault
            // `GridConstants` names: "a rung that exists in practice and not in
            // the ladder is how a ladder rots". The set is now `gapTight`,
            // `gapItem`, `gapWide` and `gapPage`, and the ratios are what do the
            // work — 64 against 8 is 8x, so the break around the composition
            // cannot be mistaken for the gap inside the copy
            // (`docs/space.md` P1: proximity groups by the RATIO between
            // competing distances, not their difference).
            VStack(spacing: 0) {
                topBand
                words
                art
                actions
            }
            .padding(.horizontal, GridConstants.horizontalPadding)
            .padding(.bottom, GridConstants.gapWide)
            // The first-win page's title field raises the keyboard; the
            // bands stay where they are under it rather than squeezing the
            // board, and Done puts it away.
            .ignoresSafeArea(.keyboard, edges: .bottom)
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
            withAnimation(GridConstants.motionSnappy) { step += 1 }
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
        .accessibilityLabel("Step \(step + 1) of \(lastStep + 1)")
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
    ///
    /// # It drew nothing and it still took the room, and that was the bug
    ///
    /// The owner, looking at page 1 (2026-10-02): "fix like the text being so
    /// far down for no reason like the titles it dont make sense the white space
    /// is an aid but make it make sense."
    ///
    /// Measured on a capture at 402x874: the usable band starts at y59 and the
    /// title's ink starts at **y217**, and `page-room.py` reports the biggest
    /// break on the whole page as **158.0pt, at the very top, above
    /// everything** — on a page that is 48.9% empty, the largest single run of
    /// emptiness was the band before anything began. `docs/space.md` P7 is "a
    /// page ends; it does not stop"; this was its mirror, a page that did not
    /// START.
    ///
    /// **`ls Strata/Assets.xcassets | grep OnboardingMark` returns nothing.**
    /// None of the six drawings exist. So the slot was holding 56pt, plus the
    /// band's own `gapItem` above and below it, for art nobody has drawn, and
    /// on page 1 there is no back button either, which makes that band pure
    /// reservation. The paragraph above says holding the height whether or not
    /// the asset exists "is the whole point: the day the drawings land, nothing
    /// below them moves" — and the price of that promise is a hole at the top
    /// of every page until the day it is kept.
    ///
    /// **So the room is held only when there is something to put in it**, which
    /// keeps the promise where it can be kept and stops charging for it where it
    /// cannot. Today none of the six exist, so all six pages are uniform without
    /// it; when all six exist they are uniform with it. The one wobbly state is
    /// the few days while he is drawing them, when some pages reserve and some
    /// do not — and that is a better problem than six pages shipping with a hole
    /// at the top.
    ///
    /// **The `back` row is deliberately NOT collapsed the same way.** Its room
    /// is held on page 0 so the rule under it does not move between pages, and
    /// that one is holding space for a control that genuinely exists on five of
    /// the six. A reservation for a thing that exists is spacing; a reservation
    /// for a thing that does not is a hole.
    @ViewBuilder
    private var mark: some View {
        if let art = UIImage(named: "OnboardingMark\(step)") {
            Image(uiImage: art)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(AppColors.inkPrimary)
                .frame(width: Self.markSide, height: Self.markSide)
                .accessibilityHidden(true)
        }
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
                withAnimation(GridConstants.motionSnappy) { step -= 1 }
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
    /// this is the MINIMUM rather than the measurement: wherever the composition
    /// is shorter than the slot the slack becomes air on both sides, and the
    /// measured gap is bigger than this number.
    ///
    /// **`gapPage` (64), and it was a hand-written 56.** The 56 was argued as
    /// "40 plus the grid's own 16", which is a derivation and not a rung, and
    /// the ladder has had a top rung since the same day this changed
    /// (`GridConstants.gapPage`, added with check 11). This is the one gap on
    /// these pages whose job is to be a BREAK rather than a gap, so it is the
    /// one that should be reading the top rung.
    ///
    /// **Measured, the number barely matters, and that is the point.** On
    /// 402x874 the composition is shorter than the slot on every one of the six
    /// pages once `compositionCeiling` holds, so this minimum does not bind and
    /// the real gaps come out at 82 to 103. It binds on a short phone, where it
    /// is the floor under the page's one break: at 64 the break still clears
    /// `gapWide` by 2.67x, where 32 would have been one ladder step and would
    /// not have read as a break at all.
    private static let airArt: CGFloat = GridConstants.gapPage

    /// **The tallest a composition on these pages is allowed to be.**
    ///
    /// The owner, 2026-10-01: "more empty space more room for premium hey tea
    /// illustrations later", and `docs/illustrations.md` rule 5 is the form of
    /// it — "Enormous negative space. The figure sits small in a big empty
    /// field." A `GeometryReader` is greedy, so without a ceiling the figure IS
    /// the field: there is no air to be small in.
    ///
    /// **Measured, this was the whole of why two pages were the least roomy
    /// screens in the app.** `docs/space.md` §6 reports onboarding 4 at 37.9%
    /// ground and onboarding 3 at 38.6% against check 11a's 35% floor, the two
    /// lowest non-exempt screens there are. The cause is on the capture: pages 1
    /// and 2 draw a composition 275 and 285pt tall in the same slot, and pages 3
    /// and 4 draw one **330pt** tall, which is not a size anybody chose — it is
    /// `min(box.width, box.height * aspect)` resolving to the leftover height.
    /// So the two pages whose subject is a photograph of a screen were dense
    /// because of an arithmetic accident, and the two whose subject is the app's
    /// own grid were roomy because that grid has a size of its own.
    ///
    /// **So the ceiling is that size: `maxRows` rows of the page's own cell**,
    /// which is exactly the tutorial board on page 2 and the opening tower on
    /// page 1. Nothing is invented. It is derived from the same
    /// `cell(forGridWidth:)` the tower uses, so it moves with the device, and it
    /// makes all six compositions one band of the same height — which is the
    /// cross-page agreement `docs/screen-audit.md`'s onboarding table was built
    /// to look for. **It only bites on pages 3 and 4**: the head disc is 200 and
    /// the portrait block about 247, both already under it.
    ///
    /// **The device mock is still "as large as the slot allows, and whole"**,
    /// which is the rule written on `screenshot(_:in:)` and is unchanged. What
    /// changed is the slot. The phone goes from 152 to 128pt wide, 16% off one
    /// dimension, and `docs/illustrations.md` is explicit that the device frames
    /// "are the strongest argument the app has and should stay" — a smaller
    /// whole phone keeps that argument and a cropped one would not.
    private static func compositionCeiling(forWidth width: CGFloat) -> CGFloat {
        let cell = cell(forWidth: width)
        return CGFloat(maxRows) * cell + CGFloat(maxRows - 1) * GridConstants.spacing
    }

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
                // **The tab bar in this picture is today's** (2026-10-02). The
                // capture still carried the Wins / Camera / Memories labels the
                // app dropped on 2026-10-01. A new device shot was the ask; the
                // simulator has no viewfinder, but its chrome IS the shipping
                // chrome, so the icon-only bar was lifted out of the
                // simulator's camera capture and set into the photograph at
                // the identical rectangle (x192 to 1013, y2373 to 2558 at 3x,
                // the same in both), masked to the capsule. The sunset and
                // every other control are the original capture.
                case 2: screenshot("DemoViewfinder", in: box)
                case 3: memories(in: box)
                case Self.headStep: headPage
                case Self.thanksStep: thanks
                case Self.goalStep: goalPage
                case Self.threeStep: threePage
                case Self.firstWinStep: firstWinPage(in: box)
                default: EmptyView()
                }
            }
            .frame(width: box.width, height: box.height)
        }
        .padding(.bottom, Self.airArt)
    }

    // MARK: - The goal

    /// The crest as Wins will show it, empty, and the number under it: what
    /// is being chosen is visible as it is chosen (each step adds a segment).
    private var goalPage: some View {
        VStack(spacing: GridConstants.gapSection) {
            // No caption: the number under the ring says it once, and the
            // ring's segments say it again without words.
            ZStack {
                GoalRingStroke(wins: 0, goal: dailyGoal, line: 6)
                    .padding(5)
                CrestFace(side: 92)
            }
            .frame(width: 128, height: 128)
            .stillGlassCircle()
            HStack(spacing: GridConstants.gapWide) {
                GlassIconButton(systemName: "minus", onPage: true, accessibilityLabel: "Fewer") {
                    dailyGoal = DailyGoal.clamped(dailyGoal - 1)
                }
                .disabled(dailyGoal <= DailyGoal.range.lowerBound)
                Text("\(dailyGoal)")
                    .font(Typography.tally)
                    .monospacedDigit()
                    .foregroundStyle(AppColors.inkPrimary)
                    .contentTransition(.numericText(value: Double(dailyGoal)))
                    .frame(minWidth: 44)
                GlassIconButton(systemName: "plus", onPage: true, accessibilityLabel: "More") {
                    dailyGoal = DailyGoal.clamped(dailyGoal + 1)
                }
                .disabled(dailyGoal >= DailyGoal.range.upperBound)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Wins a day, \(dailyGoal)")
        }
        .animation(GridConstants.cueIn, value: dailyGoal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Your three

    /// The picks as words, as the first win's examples are (`firstChip`):
    /// told apart by air, each with a full 44pt target. A chosen one is set
    /// in ink with a tick; once three are chosen the rest go quiet.
    private var threePage: some View {
        let full = threePicked.count >= YourThree.size
        return ChipFlow(spacing: GridConstants.gapItem) {
            ForEach(YourThree.picks) { item in
                let on = threePicked.contains(item)
                Button {
                    HapticsEngine.lightTap()
                    if on { threePicked.removeAll { $0 == item } } else if !full { threePicked.append(item) }
                } label: {
                    HStack(spacing: GridConstants.spacing) {
                        if on {
                            Image(systemName: "checkmark")
                                .font(Typography.headerSmall)
                                .imageScale(.small)
                                .transition(.opacity)
                        }
                        Text(item.title)
                            .font(Typography.screenSubtitle)
                            .lineLimit(1)
                    }
                    .foregroundStyle(on ? AppColors.inkPrimary : AppColors.inkTertiary)
                    .frame(minHeight: Self.tapFloor)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressWord)
                .disabled(!on && full)
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
        }
        .animation(GridConstants.crossFade, value: threePicked)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        #if DEBUG
        // `-strataOnboardingThree n`: ticks the first n, a beat after the
        // page opens, so the chosen state can be photographed without a tap.
        .task {
            guard let n = DebugHarness.argument("-strataOnboardingThree").flatMap(Int.init) else { return }
            try? await Task.sleep(for: .seconds(1.5))
            threePicked = Array(YourThree.picks.prefix(n))
        }
        #endif
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
    ///
    /// **And the SLOT is now capped too** (`compositionCeiling`, 2026-10-01).
    /// The rule above is unchanged; what it is measured against is smaller, so
    /// that the phone sits in a field rather than being the field. The ceiling
    /// is the height of page 1's own tower, and the measurement that says why is
    /// on the function.
    /// The Memories tab, composed inside the same phone the camera is in.
    ///
    /// The owner sent a photograph of the real screen: it is a map with his
    /// pictures on it AND the app's own chrome, and what was here was the map
    /// alone. `MemoriesStill` carries the argument and the composition.
    private func memories(in box: CGSize) -> some View {
        let width = Self.mockWidth(in: box)
        let height = width / DeviceFrame<EmptyView>.aspect
        let band = DeviceFrame<EmptyView>.defaultBezel * 2
        return DeviceFrame(width: width) {
            MemoriesStill(width: width - band, height: height - band)
        }
    }

    private func screenshot(_ asset: String, in box: CGSize) -> some View {
        DeviceFrame(width: Self.mockWidth(in: box)) {
            Image(asset)
                .resizable()
                .scaledToFill()
        }
    }

    /// The widest whole phone that fits the slot, with the slot capped.
    ///
    /// Written once because the camera page and the map page are the same
    /// composition with different contents, and they were the same two lines
    /// twice. The cap is the third term: `min(width, slotHeight, ceiling)`
    /// rather than `min(width, slotHeight)`.
    private static func mockWidth(in box: CGSize) -> CGFloat {
        let height = min(box.height, compositionCeiling(forWidth: box.width))
        return min(box.width, height * DeviceFrame<EmptyView>.aspect)
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
            withAnimation(reduceMotion ? GridConstants.motionSnappy : fall) {
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
        withAnimation(GridConstants.motionSnappy) {
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
                .accessibilityLabel("Jayden, who made Some Wins")
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
                    .font(Typography.screenSubtitle)
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
    /// The height is `PrimaryCapsule.height`, shared with the primary below it,
    /// so the two capsules on this page are provably the same object and not two
    /// 50s that happen to agree. It read a private `pillHeight` until the
    /// primary became `PrimaryCapsule`; that constant was the duplicate it was
    /// written to prevent.
    /// **`PrimaryCapsule(outlined:)`, and this was the second copy of the
    /// outlined capsule on the same page as the type that owns it** (2026-10-01,
    /// `docs/consistency-audit.md` §1.7). Four lines differed and the corner was
    /// already written down as a bug on the fix: `PrimaryCapsule.waiting`'s own
    /// comment reads "`Capsule(style: .continuous)`, where the walkthrough's
    /// waiting pill was a plain `Capsule()`. Its own filled state was already
    /// `.continuous`, so the two states had different corner profiles on the one
    /// page that shows both, which is this file's whole subject in miniature." The
    /// fix went into the extracted type; this button kept the plain `Capsule()`,
    /// forty lines above the call to the type that fixed it.
    ///
    /// **It is a THIRD state, not `waiting` with the reason left off**, because
    /// this is a real action: the type's waiting state deliberately builds no
    /// `Button`, and borrowing it would have made the one offer on this page
    /// unpressable. See `init(outlined:action:)`.
    ///
    /// The ring goes from `inkQuiet` to `inkTertiary` with the move, which is the
    /// one visible change: `inkQuiet` at 35% of a different black sampled 180 on
    /// a 243 ground, **1.89:1**, the ring nobody could see that this button's
    /// previous pass was written to fix; the token swap took it to **3.3:1**
    /// against a 3.0 floor; and `inkTertiary`, which is what the type's other
    /// outlined state draws, measures **4.66:1** — sampled off this build at
    /// `/tmp/c2/light/o6-onboarding-6.png`, where the ring renders rgb(109) on
    /// the page's rgb(243) and the label rgb(36).
    private var connectButton: some View {
        PrimaryCapsule(outlined: "Connect on LinkedIn") {
            if let url = URL(string: Self.linkedIn) { openURL(url) }
        }
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
    ///
    /// **`gapTight` between them, and it was `gapItem`** (2026-10-01, check 11b).
    /// This is the page's tight end, and until now the page did not have one by
    /// design — it had one by accident.
    ///
    /// Measured on the four captures `docs/space.md` had: a declared 12 renders
    /// as **17.7 to 18.0** band to band, because the gap carries the title's
    /// descender and the body's ascender air, and 11b asks for a gap of 17pt or
    /// less. Page 2 is the one the audit recorded as failing, and the reason the
    /// other three passed is the finding: their gap of record is **the title's
    /// own LEADING** (10.7 on pages 1 and 4, 16.7 on page 3, between two lines of
    /// one wrapped title), and page 2's title happens to fit on one line. So
    /// three pages passed a spacing clause on letterform, and would fail it the
    /// day a word got shorter. A declared 8 renders at about 14, which is a gap
    /// somebody chose, on all six.
    ///
    /// It is also the right answer by P1 rather than only by the clause: 8
    /// against the 64 around the composition is 8x, so a title and the line
    /// under it read as one object and the air around the figure reads as the
    /// break. At 12 against 56 it was 4.7x and the page measured as three
    /// roughly equal breaks of 99.7, 93.7 and 83.0 — "spacious and flat", which
    /// is `docs/space.md` §8's own words for this page.
    private var words: some View {
        VStack(alignment: .leading, spacing: GridConstants.gapTight) {
            Text(title)
                // **SF Pro, and that is the owner's final call on the face.**
                //
                // A third face was tried for exactly one build. He looked at
                // the same headline set in SF Pro, Jaro, Geist and Instrument
                // Sans and landed on "maybe let's just keep it at SF Pro
                // tbh". Which is the right answer for the reason the design
                // doc gives: two faces, and a third one is a decision nobody
                // has to keep defending.
                //
                // **The `.fontWeight(.bold)` that was here is gone**
                // (2026-10-01): "can you make sure there is one font and not so
                // many font weights." It was his note too, that the type looked
                // too thin, but it was ONE screen's answer to it. Nothing else
                // in the app set Bold, so onboarding's title was heavier than the
                // title of every page it hands you to, and a first run that does
                // not look like the app is the wrong thing for a first run to do.
                //
                // `screenTitle` already carries the weight, so there is no
                // override here at all now. What it cost, measured off SF's own
                // `wght` axis at `opsz` 33.55: a capital's stem goes 4.95pt Bold
                // to 3.68pt Medium, 1.27pt and 25.6% lighter, the largest single
                // change in this pass, and the one to look at first on a device.
                // If it reads thin, the lever is `Typography.titleWeight`, which
                // moves this title and the Memories title together; putting a
                // private weight back on this line is the thing that was wrong.
                .font(Typography.screenTitle)
                .foregroundStyle(AppColors.inkPrimary)
                // It never shrinks to fit. If a title does not fit, the copy is
                // too long: section 10 rule 3.
                .fixedSize(horizontal: false, vertical: true)
            // **Optional, and `nil` draws nothing at all** rather than an empty
            // string. A `Text("")` still takes a line box and still takes the
            // stack's spacing, so a page with no second line would have kept a
            // 14pt gap and a 22pt band of air inside the copy — the exact shape
            // of a label that fell off. See `subtitle` for which page has none.
            if let subtitle {
                Text(subtitle)
                    .font(Typography.bodyLarge)
                    .foregroundStyle(AppColors.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        // 24 under the nav row above it, 64 down to the composition.
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
    ///
    /// **The title does not change when you draw a block** (`docs/copy-audit.md`
    /// cut 21, decided 2026-10-01). Page 2's title used to swap to "That's how
    /// every win is made" the moment `hasDrawn` went true, replacing "Quick,
    /// regular or deep". Three reasons it is gone, in the order they matter:
    ///
    /// 1. **It is the app congratulating itself at the one moment it has nothing
    ///    to add.** The person has just pulled a block out of the slot and let it
    ///    go; they have proved they know how every win is made. The audit's class
    ///    for this is G, the page saying a thing the page already showed.
    /// 2. **It is the only title in the walkthrough that moves, and it moves
    ///    under the finger.** "Quick, regular or deep" sets on one line at 34pt
    ///    and "That's how every win is made" on two, so letting go of a block
    ///    grew the copy band by a whole `screenTitle` line and the greedy art
    ///    band gave the height back — the board you had just built shifted down
    ///    while you were still looking at it. The subtitle swap stays and is a
    ///    deliberate confirmation; it is one line either way, and the subtitle is
    ///    where this page is allowed to talk.
    /// 3. The title is now stable across the page's two states, which is what the
    ///    other five pages do.
    private var title: String {
        switch step {
        case 0: return "Everything you did, stacked up"
        case 1: return "Quick, regular or deep"
        case 2: return "A win can be a photograph"
        case 3: return "Every photo keeps its place"
        case Self.headStep: return heads.head == nil ? "Make your own head" : "That's your head"
        case Self.goalStep: return "A goal for each day"
        case Self.threeStep: return YourThree.Copy.onboardingTitle
        case Self.firstWinStep: return "Your first win"
        default: return "Thank you, genuinely"
        }
    }

    /// The line under the title, where there is one.
    ///
    /// **Page 3 has none** (`docs/copy-audit.md` cut 21, decided 2026-10-01). It
    /// read "Take it here and the picture becomes the block." under the title "A
    /// win can be a photograph", over a `DeviceFrame` holding a picture of
    /// Strata's own viewfinder. The audit classed it E, Explanation, and flagged
    /// it as the owner's call because "the page is a live demo with nothing else
    /// to read". It is not a live demo — it is `screenshot("DemoViewfinder")`, a
    /// still — and of its two halves the second ("the picture becomes the block")
    /// is the title said again, and the third time the walkthrough has said that
    /// something becomes a block (page 1's subtitle and page 2's whole lesson are
    /// the other two). The only new word is "here", meaning in Strata rather than
    /// out of your library, and what is on screen is a phone with Strata's camera
    /// in it, which is that word as a picture. The owner, the same day: "the areas
    /// are very self explanitory and I think over explaining components loses the
    /// charm."
    ///
    /// **Page 4 keeps its line, and this is the page the cut would have cost
    /// something.** The same entry flags "Your wins land on the map where you took
    /// them." on the same grounds, and the grounds do not hold here: page 4's
    /// button says "Turn on places" and `advance()` calls
    /// `location.requestAccess()`, so this is the walkthrough's permission prime
    /// and the only one in it. The file's own note on `advance()` cites Apple's
    /// guidance — ask where the answer is obvious — and this sentence is what
    /// makes it obvious, because it is the only place that names what you GET.
    /// "Every photo keeps its place" says what happens; the map behind it says
    /// where; neither says that your wins appear on it. Cutting the one sentence
    /// that earns a system permission to save 9 words is the wrong trade, and a
    /// refused permission cannot be asked for again.
    private var subtitle: String? {
        switch step {
        // **One idea, and the sizes belong to the next page.** This read
        // "Finish something and it becomes a block: quick, regular or deep,
        // depending on what it took", which taught the three sizes one page
        // before the page whose whole job is to teach the three sizes, and it
        // was the longest line in the walkthrough. The first screen has one
        // thing to say and somebody has to believe it.
        case 0: return "Finish something and it becomes a block."
        // The gesture is the one thing on these six pages a picture cannot
        // teach, so this line stays and it is an instruction, not a caption. It
        // swaps to the confirmation once the finger has done it; the TITLE does
        // not, which is the entry above.
        case 1: return hasDrawn
            ? "Pull nothing and it's a quick one. The size is how much it took."
            : "Hold the slot and pull. Sideways for a regular win, up for a deep one. Let go to drop it in."
        case 2: return nil
        case 3: return "Your wins land on the map where you took them."
        case Self.headStep: return heads.head == nil
            ? "Fifteen seconds with the front camera. Use it as your picture or add it to your photos, if you like."
            : "Find it in Profile, and on your photos. It stays on this phone."
        // What counts, said once; the chips say the rest by example.
        case Self.goalStep: return "Reach it and your tower dances and prints the day's strip."
        case Self.threeStep: return YourThree.Copy.onboardingLine
        case Self.firstWinStep: return "Anything you already did today counts."
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
            if step == Self.thanksStep { connectButton }

            // **Only where something is genuinely optional, which is the head**
            // (the owner, 2026-09-23: "there shouldn't be a skip button other
            // than when doing the face, not every page of the onboarding, and
            // the spacing looks off for that as well").
            //
            // On the other five pages it was an escape hatch out of a
            // six-page walkthrough offered six times, under a button that
            // already says what happens next. It declines the head here, not
            // the tour: the thank you is still to come.
            if offersHead { decline("Not now") }
            // Your three are asked for, never required (the owner's pick:
            // "skippable"), so this page has the head's way out too.
            if step == Self.threeStep { decline(YourThree.Copy.onboardingSkip) }

            action
        }
        // On the whole band, not on the button, because the two states of the
        // action are now two different views and the cross-fade between them is
        // the thing being animated.
        .animation(GridConstants.motionSnappy, value: canAdvance)
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
    private func decline(_ word: String) -> some View {
        Button {
            HapticsEngine.lightTap()
            withAnimation(GridConstants.motionSnappy) { step += 1 }
        } label: {
            Text(word)
                .font(Typography.headerSmall)
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
    /// **Both states are `PrimaryCapsule` now, and this page was the last
    /// holdout.** (2026-10-01)
    ///
    /// It kept a private `litPill` and `waitingPill` after that type existed,
    /// and they were not a drift: the fill, the flatness, the rim and the
    /// outline were all settled HERE and `PrimaryCapsule` was extracted out of
    /// them for the restore confirm and the store retry. Being the original is
    /// not a reason to stay a second copy, though, and the two were already
    /// diverging in three places by the time they were read side by side.
    /// What the move actually found, which is the argument for doing it:
    ///
    ///     the haptic     `PrimaryCapsule` was extracted with `tick()`, a
    ///                    selection feedback, where this page and
    ///                    `GlassIconButton` both use `lightTap()`. The shared
    ///                    type is `lightTap()` now, so the restore confirm and
    ///                    the store retry get their press back as well.
    ///     the capsule    this page's waiting ring was a plain `Capsule()`
    ///                    while its own filled pill was `.continuous`, so the
    ///                    two states had different corner profiles on the one
    ///                    page in the app that shows both.
    ///     the height     50 was typed here and again there. It is
    ///                    `PrimaryCapsule.height` in both places now, and the
    ///                    LinkedIn capsule above reads the same constant.
    ///
    /// Nothing was lost: the colour argument, the flat-not-lit argument, the
    /// measured waiting ratios and the reason the waiting state must never be a
    /// `Button` or a `.disabled` all moved into `PrimaryCapsule`'s own doc,
    /// which is where the next sweep will be standing. **Read that before
    /// touching the waiting state.** The trap is that a disabled plain button
    /// is dimmed by the environment, which halved this page's outline for
    /// weeks, and the shared type is shaped so there is no `Button` inside the
    /// waiting state for a `.disabled` to be put on.
    @ViewBuilder
    private var action: some View {
        if canAdvance {
            // No haptic here: `PrimaryCapsule` makes it, and this used to make
            // its own `lightTap()` beside a `Button` it owned.
            PrimaryCapsule(title: actionTitle) { advance() }
        } else {
            PrimaryCapsule(waiting: actionTitle,
                           because: step == Self.firstWinStep
                               ? "Not yet. Tap the slot to drop your first win in."
                               : step == Self.threeStep
                                   ? YourThree.Copy.onboardingWaiting
                                   : "Not yet. Draw a block to go on.")
        }
    }

    /// The height of a primary action, shared with the LinkedIn capsule above
    /// it so the two are provably one object rather than two 50s that agree
    /// today. **It is `PrimaryCapsule.height` rather than a 50 typed here**,
    /// because that was the second 50 and the primary pill on this page is now
    /// that type: two constants that agree is the same fault one rung down.

    /// The HIG's minimum target, and `GlassIconButton`'s own `defaultSide`. Named
    /// here so the one control on these pages that was under it is measured
    /// against the same number the back disc is.
    private static let tapFloor: CGFloat = GlassIconButton.defaultSide

    private var canAdvance: Bool {
        if step == 1 { return hasDrawn }
        if step == Self.firstWinStep { return firstLanded != nil }
        if step == Self.threeStep { return !threePicked.isEmpty }
        return true
    }

    /// The head page, with no head made yet.
    private var offersHead: Bool { step == Self.headStep && heads.head == nil }

    private var actionTitle: String {
        switch step {
        case 0: return "Let me try"
        case 1: return "What else"
        case 2: return "Go on"
        case 3: return location.canAsk ? "Turn on places" : "One more thing"
        case Self.headStep: return heads.head == nil ? "Make my head" : "One more thing"
        case Self.goalStep: return "Set my goal"
        case Self.threeStep: return YourThree.Copy.onboardingKeep
        case Self.firstWinStep: return "Go to my tower"
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
        if step == Self.threeStep { threeRaw = YourThree.encode(threePicked) }
        guard step < lastStep else { finish(); return }
        withAnimation(GridConstants.motionSnappy) { step += 1 }
    }

    /// The end of the walkthrough. On the first-win page the win is queued
    /// first, so `MainAppView` logs it on the active tower and opens on Wins.
    private func finish() {
        guard !finished else { return }
        finished = true
        if step == Self.firstWinStep, let size = firstLanded {
            OnboardingFirstWin.queue(title: firstTitle, size: size, colour: Self.firstColour)
        }
        onFinish()
    }

    // MARK: - The first win

    /// **The last page is the tower's own slot** (2026-10-05). The title
    /// field, five chips that say by example what counts, and under them a
    /// strip of the tower's board with the real slot in it: tap once and the
    /// block falls into it, draw it out for a bigger one, exactly as on Wins.
    /// A chip fills the title in; nothing has to be typed.
    private func firstWinPage(in box: CGSize) -> some View {
        let gutter = GridConstants.spacing
        let cell = Self.cell(forWidth: box.width)
        let width = GridConstants.gridWidth(cellSize: cell)
        let rows = Self.firstRows
        let height = CGFloat(rows) * cell + CGFloat(rows - 1) * gutter
        let shown = firstLanded ?? firstSize
        let blockW = cell * CGFloat(shown.columnSpan) + gutter * CGFloat(shown.columnSpan - 1)
        let blockH = cell * CGFloat(shown.rowSpan) + gutter * CGFloat(shown.rowSpan - 1)

        return VStack(alignment: .leading, spacing: GridConstants.gapItem) {
            TextField("What did you do?", text: $firstTitle,
                      prompt: Text("What did you do?").foregroundStyle(AppColors.inkTertiary))
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.inkPrimary)
                .focused($firstTyping)
                .submitLabel(.done)
                .disabled(firstLanded != nil)
                .frame(minHeight: Self.tapFloor)

            ChipFlow(spacing: GridConstants.gapItem) {
                ForEach(OnboardingFirstWin.examples, id: \.self) { example in
                    firstChip(example)
                }
            }

            Spacer(minLength: GridConstants.gapItem)

            ZStack(alignment: .bottomLeading) {
                if let landed = firstLanded {
                    block(Self.firstColour, columns: landed.columnSpan, rows: landed.rowSpan, cell: cell)
                        .overlay(alignment: .bottomLeading) {
                            // A named block says its name, in the white every
                            // block label is set in; an unnamed one shows none.
                            if !firstTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                                Text(firstTitle)
                                    .font(Typography.screenSubtitle)
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .padding(cell * 0.12)
                            }
                        }
                        .offset(y: firstFell ? 0 : -640)
                        .opacity(firstFell ? 1 : 0)
                } else {
                    NextSlotButton(
                        reduceMotion: reduceMotion,
                        cornerRadius: GridConstants.blockCornerRadius(forCell: cell),
                        previewCategory: Self.firstColour,
                        onSizeChanged: { firstSize = $0 },
                        action: { size in placeFirst(size) },
                        // A tap is a Quick win here. On the tower a tap opens
                        // the add sheet; this page has no sheet, so a tap only
                        // buzzed, and a new user tapping the "+" got nothing
                        // (found 2026-10-07 by the first-run UI test, which
                        // had been failing on it since the page was added).
                        onOpenMenu: { placeFirst(.small) }
                    )
                    .frame(width: blockW, height: blockH)
                }
            }
            .frame(width: width, height: height, alignment: .bottomLeading)
            // The tutorial's board, its seat and all, for the reason written
            // on `workshop`: on a flat page the cells need a ground to read.
            .background(alignment: .bottomLeading) {
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
            .frame(maxWidth: .infinity)
        }
        .frame(width: box.width, height: box.height, alignment: .top)
        #if DEBUG
        // `-strataOnboardingFirstWin chip|tap`: picks the first chip, and with
        // `tap` drops the block too, a beat after the page opens. A simulator
        // here cannot tap.
        .task {
            guard let auto = DebugHarness.argument("-strataOnboardingFirstWin") else { return }
            try? await Task.sleep(for: .seconds(1.5))
            firstTitle = OnboardingFirstWin.examples[0]
            if auto == "tap" {
                try? await Task.sleep(for: .seconds(1))
                placeFirst(.small, finishes: DebugHarness.argument("-strataOnboardingFinish") == "1")
            }
        }
        #endif
    }

    /// One example. Pressed, its words become the title; pressed again, the
    /// title clears. The chosen one is drawn in ink, the rest in the quieter
    /// ink.
    ///
    /// **Words, not glass capsules.** Five glass chips on one page is five
    /// glass controls where `GlassIconButton.swift` allows three, and the
    /// slot under them is glass already. The examples are told apart by air,
    /// and each word still has its full 44pt target.
    private func firstChip(_ example: String) -> some View {
        let on = firstTitle == example
        return Button {
            HapticsEngine.lightTap()
            firstTyping = false
            firstTitle = on ? "" : example
        } label: {
            Text(example)
                .font(Typography.screenSubtitle)
                .foregroundStyle(on ? AppColors.inkPrimary : AppColors.inkTertiary)
                .lineLimit(1)
                .frame(minHeight: Self.tapFloor)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressWord)
        .disabled(firstLanded != nil)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    /// The tap: the block falls into the slot, the board answers, and a
    /// beat later the walkthrough hands you to the tower with it standing.
    private func placeFirst(_ size: BlockSize, finishes: Bool = true) {
        guard firstLanded == nil else { return }
        firstTyping = false
        firstLanded = size
        firstFell = false
        let fall = GridConstants.dropFallCurve.speed(1 / fallSeconds)
        withAnimation(reduceMotion ? GridConstants.motionSnappy : fall) { firstFell = true }
        ripple = LatticeRipple(column: 0, row: 0, columnSpan: size.columnSpan, rowSpan: size.rowSpan)
        HapticsEngine.success()
        guard finishes else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(1600))
            finish()
        }
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
                // **`EtherealFill.fill`, not the flat `baseColor`** (2026-10-01,
                // `docs/consistency-audit.md` §1.16). Eight of the ten
                // `BlockSurface` call sites in the app hand it
                // `EtherealFill.fill(...)`; two handed it a flat colour, and this
                // one is the FIRST block anybody ever sees.
                //
                // The owner asked for the inside light by name: "I want the blocks
                // to have this kinda glass transparency as well in them, for the
                // inner colour instead of just flat." `EtherealFill` is `coreBoost`
                // 0.035 over `rimSaturation` 0.94 with `rimLift` 0.03, so on a
                // 34pt swatch the difference is small and on this page's cell,
                // which is the biggest block drawn anywhere outside the tower, it
                // is not.
                //
                // **Only under a colour, never under a photograph.** The branch
                // below draws a picture over this fill at `scaledToFill`, so on a
                // photo block the fill is not seen at all and the lift would be
                // paid for nothing; on a colour block it is the whole of what you
                // see. `BlockFace` makes the same split for the same reason.
                EtherealFill.fill(category.style.baseColor)
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

/// The first-win chips, wrapped to the page's width: as many to a line as
/// fit, `spacing` between them and between lines, leading-aligned.
private struct ChipFlow: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.items {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                                      proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var items: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].items.isEmpty ? size.width
                : rows[rows.count - 1].width + spacing + size.width
            if needed > width, !rows[rows.count - 1].items.isEmpty {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width = row.items.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.items.append(index)
            rows[rows.count - 1] = row
        }
        return rows.filter { !$0.items.isEmpty }
    }
}
