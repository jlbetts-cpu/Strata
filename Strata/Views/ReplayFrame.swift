import SwiftUI
import UIKit

/// One moment of a replay. No timers, no state: everything comes from
/// `script` at `t`. `ReplayView` draws it live and `ReplayVideoExporter`
/// draws it to frames.
struct ReplayFrame: View {
    let script: ReplayScript
    let images: ReplayImages
    let t: Double
    /// The one `now` the date is worded against. Required: a
    /// default `Date()` per frame could reword the range mid-play at
    /// midnight, and the still and the video would each pick their own.
    let now: Date
    /// "Sample" after the date once it arrives. The Settings
    /// preview's live replay and its saved video, so a made-up week cannot
    /// be posted as a real one.
    var showsSampleBadge = false
    /// Replay, Save Video and Share, supplied live; the exporter passes
    /// nothing.
    var controls: AnyView? = nil
    /// Live only: how far a photograph that arrived after playback started
    /// has faded in. The exporter waits for every photograph and passes
    /// nothing, so every frame of the video draws each picture whole.
    var photoOpacity: ((ReplayPhoto) -> Double)? = nil
    /// Live only: whether a block's photograph is in or still on its way, so
    /// the block is drawn as a photograph (veil, vignette, title shadow) from
    /// its first frame and only the picture fades in. Without it a block is
    /// drawn as a photograph exactly when its picture is in, which is always
    /// for the exporter and the posters.
    var expectsPhoto: ((ReplayPhoto) -> Bool)? = nil
    /// The frame's top safe-area inset: the status bar and the Dynamic Island
    /// live, or a story-safe margin in the saved video. The header is set
    /// from it. The tower's lines and the controls' row come from the
    /// script's metrics, which were laid out from the same insets.
    var topInset: CGFloat = 0
    /// A tap on a block, by index into `replay.blocks`. Live only, and only
    /// once the close has arrived; the card and the exporter pass nothing,
    /// and then nothing extra is drawn or hit-tested.
    var onTapBlock: ((Int) -> Void)? = nil
    /// VoiceOver's double tap on the header or the close words. Live only.
    /// An action rather than the player's tap gesture: see `ReplayView`.
    var onAccessibilityActivate: (() -> Void)? = nil
    /// The shelf's poster: the tower alone, at a scale and on a base the
    /// caller chose, so a row of posters shares one scale and compares by
    /// height. Nil everywhere else, which draws the replay as it plays.
    var poster: Poster? = nil

    struct Poster: Equatable {
        /// World points to frame points, the same for every card in a row.
        var scale: CGFloat
        /// Where the tower's base stands, in frame points.
        var baseY: CGFloat
    }

    private var m: ReplayScript.Metrics { script.metrics }
    private var replay: Replay { script.replay }

    /// The type size around the frame, capped below as the frame caps its own
    /// content: this view's environment is read outside its own
    /// `.dynamicTypeSize(...xxLarge)`.
    @Environment(\.dynamicTypeSize) private var outerTypeSize

    /// The count's size as the type is actually set, for the digit roll's
    /// window. Scaled from the CAPPED size: a `@ScaledMetric` here read the
    /// uncapped one, so above xxLarge the window was sized for a bigger
    /// digit than the one drawn and shaved the rolling digits.
    private var tallySize: CGFloat {
        let category = UIContentSizeCategory(min(outerTypeSize, .xxLarge))
        return UIFontMetrics(forTextStyle: .largeTitle)
            .scaledValue(for: Typography.screenTitleSize,
                         compatibleWith: UITraitCollection(preferredContentSizeCategory: category))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            WarmBackground()
            // **The surface, between the ground and the type, and that layer is
            // a measurement rather than tidiness.**
            //
            // It was first hung as the tower's own `.background`, which is where
            // the Wins tab hangs it and is the arrangement that keeps the two in
            // step for free. But the tower is drawn ABOVE `topCopy` here on
            // purpose (the note below), so the lattice came up with it and a
            // field of panes was laid over the count and the date. That is the
            // exact failure the empty Wins page was marked down for: the copy
            // printed across the ghost cells read as debris on the surface
            // rather than as a caption of it. Three layers instead of two, and
            // the depth reads better for it: the surface is behind everything
            // because it IS the ground, the type is printed on the page, and the
            // blocks are objects in the scene in front of both.
            surface
            // Type BENEATH the tower: a block falling past the count passes
            // in front of it, as a thing in the scene passes in front of a
            // caption, rather than the number printing across the block.
            if poster == nil { topCopy }
            tower
            if let onTapBlock { blockTaps(onTapBlock) }
            if poster == nil { close }
        }
        .frame(width: m.frame.width, height: m.frame.height)
        // **Capped.** The frame's lines (`followY`, `baseY`) are fractions of
        // the frame and cannot grow with the type, so past xxLarge the label
        // ran across the follow line and the close ran off the bottom. The
        // exporter pins `.large`, so the video is the default setting.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }

    // MARK: The count and the date

    /// The count over the date, top left.
    ///
    /// **During the build only the count** (the owner, 2026-09-15: "before
    /// that it should just say the win numbers and be counting up as the
    /// blocks place"). It is set as the Wins tab's header, the owner's
    /// digits with the word a quieter caption beside it, and it counts one
    /// landing at a time. **The date arrives with the reveal**, under the
    /// count, which stays the lead. Its line is laid out from the first
    /// frame at opacity 0, so nothing moves when it arrives.
    private var topCopy: some View {
        VStack(alignment: .leading, spacing: GridConstants.gapTight) {
            countLine
            rangeLine
        }
        .padding(.leading, GridConstants.horizontalPadding)
        // The cap line the Wins tab's count sits on, measured from the bottom
        // of the frame's safe area.
        .padding(.top, topInset + GridConstants.headerTopPadding(forTitleSize: GridConstants.tallyNumeral))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(topCopyLabel)
        .replayActivation(onAccessibilityActivate)
    }

    /// How tall the count and date stand under the top inset at a text
    /// size: the header's top padding, the count's line, the gap and the
    /// date's line. The script keeps the finished tower's top under it
    /// (`Metrics.standard`). From the system's own line heights for the
    /// styles the lines are set relative to, since the script is made before
    /// anything is laid out.
    static func topCopyHeight(_ size: DynamicTypeSize) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(min(size, .xxLarge)))
        let count = UIFont.preferredFont(forTextStyle: .largeTitle, compatibleWith: traits).lineHeight
        // The date line is `Typography.screenSubtitle`, a subheadline.
        let title = UIFont.preferredFont(forTextStyle: .subheadline, compatibleWith: traits).lineHeight
        return GridConstants.headerTopPadding(forTitleSize: GridConstants.tallyNumeral)
            + count + GridConstants.gapTight + title
    }

    /// "31 wins, Your week, 7 to 13 September": the numbers spoken, since
    /// the digits are drawn a position at a time and the range as figures.
    private var topCopyLabel: String {
        let n = script.count(at: t)
        return ["\(n) \(n == 1 ? "win" : "wins")", showsSampleBadge ? "Sample" : nil,
                replay.period.title, replay.period.spokenRange(relativeTo: now)]
            .compactMap { $0 }.joined(separator: ", ")
    }

    /// The range, or a month's name: "9/7-9/13", "September".
    private var rangeText: String { replay.period.range(relativeTo: now) }

    private var countLine: some View {
        let roll = script.countRoll(at: t)
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            digits(roll)
                // Optical, as on the Wins tab: a digit's ink starts inside its
                // box, so the box sits a little left of the margin.
                .padding(.leading, -GridConstants.tallyOpticalInset)
            Text(roll.count == 1 ? "win" : "wins")
                .font(Typography.screenSubtitle)
                .foregroundStyle(AppColors.inkQuiet)
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .opacity(script.countOpacity(at: t))
    }

    /// The count, one digit position at a time.
    ///
    /// **An odometer.** Only a position that changes moves: its old digit
    /// rises out of a window the height of the digits' own ink as the new
    /// one rises in from below it, both at full strength. The window is the
    /// cap band (`roundedCapInset` below the line's top, a cap high, with a
    /// little room for round overshoot), not the line box: the owner's face
    /// sets its digits in a line about 1.2 em tall with the ink in the
    /// middle, and clipped to that box, a roll a whole line long showed the
    /// two numbers stacked with a gap between them, "19" over "20". The
    /// digits travel the window's height and a small gap more, so they never
    /// overlap and nothing fades or dims: a frame mid-roll shows the bottom
    /// of the old digit leaving the top of the window and the top of the new
    /// one entering at the bottom, the way a counter wheel looks.
    ///
    /// The owner's digits are tabular, so neighbours never shift; a new
    /// leading digit (9 to 10) opens its width in the first half of the roll,
    /// so "wins" slides over rather than jumping. Under Reduce Motion nothing
    /// travels: the digit changes at the middle of the roll.
    private func digits(_ roll: ReplayScript.CountRoll) -> some View {
        let slots = ReplayScript.digitSlots(roll)
        let e = CGFloat(script.rollEase(roll.progress))
        let still = script.reduceMotion
        let size = tallySize
        let pad = size * Self.rollWindowPad
        let windowTop = GridConstants.roundedCapInset * size - pad
        let windowHeight = Typography.screenTitleCap / Typography.screenTitleSize * size + 2 * pad
        let travel = windowHeight + size * Self.rollGap
        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            ForEach(slots.indices, id: \.self) { i in
                let slot = slots[i]
                WidthReveal(fraction: slot.old == nil && slot.changes && !still ? CGFloat(ReplayScript.rollOpening(Double(e))) : 1) {
                    if slot.changes, !still {
                        ZStack {
                            if let old = slot.old { digit(old).offset(y: -travel * e) }
                            if let new = slot.new { digit(new).offset(y: travel * (1 - e)) }
                        }
                        .mask(alignment: .top) {
                            Rectangle()
                                .frame(height: windowHeight)
                                .padding(.top, windowTop)
                        }
                    } else if slot.changes {
                        // Both laid out, one shown: a leading digit's width
                        // is there from the roll's start, so "wins" does not
                        // step sideways.
                        ZStack {
                            if let old = slot.old { digit(old).opacity(e < 0.5 ? 1 : 0) }
                            if let new = slot.new { digit(new).opacity(e < 0.5 ? 0 : 1) }
                        }
                    } else if let new = slot.new {
                        digit(new)
                    }
                }
                // The part of a still-opening position that is not open yet
                // is not drawn.
                .clipped()
            }
        }
    }

    /// Room above and below the digits' cap band inside the roll's window,
    /// for the round digits' overshoot, as a fraction of the type's size.
    private static let rollWindowPad: CGFloat = 0.06
    /// The space between a leaving digit and an arriving one, as a fraction
    /// of the type's size.
    private static let rollGap: CGFloat = 0.1

    private func digit(_ c: Character) -> some View {
        Text(String(c))
            .font(Typography.tally)
            .foregroundStyle(AppColors.inkPrimary)
    }

    /// The line under the count: the range, or a month's name, in the quiet
    /// ink at the caption size.
    ///
    /// **No "Your week" over it** (the owner, 2026-09-15: the title block
    /// "looks a bit too much"). Four were drawn and looked at: this one; the
    /// range after "wins" on the count's line; the count alone; and "Your
    /// week" with the range in the darker medium weight, which is what
    /// shipped first. This one keeps the count's line exactly as the Wins
    /// tab sets it, and leaves the date as what it is: context under the
    /// fact. The words "Your week" are the app talking about itself, which
    /// the person the video is sent to does not need.
    ///
    /// It arrives up 8pt with opacity in the hold after the last block lands,
    /// settling exactly as the camera starts to pull out, and a Settings
    /// preview's "Sample" follows it 80ms later. It used to start WITH the
    /// reveal and was lost under it: see `ReplayScript.titleStart`.
    private var rangeLine: some View {
        let range = script.titleArrival(0, at: t)
        let badge = script.titleArrival(1, at: t)
        // `gapTight`, not the 6 on the line above. That 6 is the Wins tab's
        // own number (`MainAppView.headerCount`), and it is an optical gap
        // between a 34pt numeral and a 15pt caption; it was copied down here
        // where the pair is two words at the same size, which is the ladder's
        // "things that belong to each other" and therefore 8.
        return HStack(alignment: .firstTextBaseline, spacing: GridConstants.gapTight) {
            Text(rangeText)
                .font(Typography.screenSubtitle)
                .foregroundStyle(AppColors.inkQuiet)
                .opacity(range.opacity)
                .offset(y: range.offset)
            if showsSampleBadge {
                Text("Sample")
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkQuiet)
                    .opacity(badge.opacity)
                    .offset(y: badge.offset)
            }
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: The surface

    /// **The grid of empty cells the replay's blocks land in, for as long as
    /// there are blocks still landing.**
    ///
    /// The owner, 2026-10-01: "shouldn't the lattice be in the replay as well."
    /// It should. On the Wins tab a tower stands ON something and that surface
    /// is the whole of why it reads as built rather than floating; the replay
    /// drew the same tower, and the same blocks, on bare ground.
    ///
    /// The owner, the same day, looking at the first build of it: "i dont think
    /// i like the lattice when it zooms out." He is right, and the reason is
    /// worth writing down, because it is not about strength or sharpness.
    ///
    /// **At rest the only lattice you can see is the overhang, and the overhang
    /// is a promise a replay cannot keep.** `TowerLattice.rowsAbove` is 3
    /// because on the Wins tab the tower is still growing and those rows are
    /// where the NEXT win goes. Everything below the crown is covered by the
    /// tower standing in it, so once the camera has pulled back what actually
    /// reaches the eye is one rectangle of empty cells hanging in open air above
    /// a finished tower. On the sample week at 402x874 it draws 160pt tall,
    /// 18.3% of the frame, and the header prints straight across it: "9/28-10/4"
    /// and "Sample" sit inside the ghost cells. That is the exact failure the
    /// empty Wins page was marked down for, and the one the three-layer order
    /// above exists to avoid — type reading as debris ON the surface instead of
    /// as a caption OF it. A replay's tower is finished. There is no next win in
    /// this picture, so a grid holding room for one is scaffolding left standing
    /// after the building is done.
    ///
    /// **So the surface belongs to the build, and it strikes with the set.**
    /// `surfaceOpacity` takes it out across the first 60% of the reveal, which
    /// is the camera's own pull-back: 0.6s of a week's 1.0s reveal, 0.84s of a
    /// month's 1.4s. The ground dissolves as the camera lifts off it, and the
    /// finished tower is left alone on the page, which is what the dance and the
    /// close are for. Through the build — most of the replay, and every frame in
    /// which a block is falling — nothing changes at all.
    ///
    /// **A tower that never zooms out never loses it** (`fitScale` 1). That is
    /// the Wins tab's own case arriving inside the replay: the camera stays at
    /// scale 1, the overhang is still where blocks are landing right up to the
    /// last one, and the surface is simply the ground, as it is on the tab.
    ///
    /// **All-or-nothing, rather than a band in the scale, is deliberate.** The
    /// obvious alternative is to fade by the live scale, the way `titleOpacity`
    /// does. It has a failure this does not: any band catches some tower at its
    /// resting scale, and a lattice frozen at 40% for good is the "ghost grey"
    /// rendering-fault look that `titleOpacity` needed a `fitScale` guard to
    /// escape. Keyed to the reveal instead, every tower ends at exactly 0 or
    /// exactly 1, and no tower can come to rest part way.
    ///
    /// **It rides the camera's own transform, not a copy of it** (`stage`). The
    /// replay's scale is not one number: the build runs at 1, a week comes to
    /// rest at `fitScale` 0.574 and a month at 0.128, and the reveal moves
    /// geometrically between them. At 402x874 the world cell is 89pt. A lattice
    /// with its own idea of the cell would be a surface the tower slides across
    /// during the reveal, which is worse than no surface. One transform applied
    /// twice cannot drift — and it is still one transform now that the fade is
    /// an opacity on top of it rather than a second geometry.
    ///
    /// **The strength is the shared pair, and that is a measurement rather than
    /// an inheritance.**
    ///
    /// `TowerLattice.strength` is 0.34 and `strengthDark` is 0.04 because a white
    /// pane means two completely different amounts over a 247 page and a 29 one.
    /// The reason the replay takes both numbers unchanged is that it is standing
    /// on the SAME ground they were measured on: `WarmBackground`, which is
    /// `top` plus `GroundField`'s mesh, the `seat` and the grain, exactly as the
    /// Wins tab draws it. Computed over that ground, the pane against the gutter
    /// beside it comes to **1.024:1 light (2.7 levels of 255) and 1.114:1 dark
    /// (9.0 levels)**, which is the audit's own 1.03 and 1.11 to the level. Over
    /// the night field's whole range, brightness 0.098 to 0.128, the dark figure
    /// moves between 1.106 and 1.119. There is no third ground here to measure
    /// against, so a third number would be a number with nothing behind it.
    ///
    /// **The fade is the answer to feature size too, and that is the cheaper
    /// half of why it is right.** The camera changes how big the grid is drawn,
    /// not its contrast: the 4pt gutter draws 2.30pt at a week's rest and
    /// **0.51pt at a month's, which is 1.54 device pixels at 3x.** A half-pixel
    /// gutter under a continuous zoom is exactly the geometry that aliases, and
    /// the old note here could only promise the shimmer was small (bounded by
    /// the same 2.7 and 9.0 levels above) rather than absent. It is now absent:
    /// the lattice is at full opacity only while the camera is at scale 1, and
    /// every scale small enough to alias is a scale it has already left.
    ///
    /// It also carries no information about the finished shape: four columns of
    /// identical cells say where a block CAN land, never where one will, so a
    /// lattice present from the first frame gives nothing away.
    ///
    /// **And it does not fade in.** `TowerLattice` animates nothing on arrival
    /// and nothing was added here. Check 10 of the rubric fails anything that
    /// animates because it appeared; the surface is simply already there, which
    /// is also what the empty Wins page does.
    ///
    /// **It costs nothing per frame, which is the one thing worth checking on a
    /// view whose body runs sixty times a second.** Every stored property handed
    /// to `TowerLattice` here is constant for the whole replay: the cell, the
    /// finished height, no touches, no ripple. So its body is the same value
    /// every frame, and `TowerLatticeShape.path(in:)` is asked for its 170-odd
    /// rounded rectangles once, because `scaleEffect` is a transform on the
    /// drawn layer and never changes the bounds the path was built in. The
    /// camera's zoom moves a cached layer, not a rebuilt path.
    private var surface: some View {
        TowerLattice(cellSize: m.cell, contentHeight: worldHeight)
            .frame(width: script.gridWidth)
            .modifier(stage)
            .opacity(surfaceOpacity)
    }

    /// How strongly the ground draws right now. See `surface` for why.
    ///
    /// A poster is a still of a finished tower at shelf scale: the resting case
    /// with nothing left to animate, so no ground. Reduce Motion reaches the
    /// same picture without a reveal — `camera(at:)` returns `fitScale` from the
    /// first frame — so there is no window to fade across and it takes the same
    /// answer rather than a fade that would run against a camera that never
    /// moved.
    private var surfaceOpacity: Double {
        if poster != nil { return 0 }
        if script.reduceMotion { return script.fitScale < 1 ? 0 : 1 }
        return Self.surfaceOpacity(fitScale: script.fitScale, revealStart: script.revealStart,
                                   revealDuration: script.revealDuration, t: t)
    }

    /// The whole rule, as a function of the script and the moment. Split out
    /// from the property so it can be measured rather than described.
    static func surfaceOpacity(fitScale: CGFloat, revealStart: Double,
                               revealDuration: Double, t: Double) -> Double {
        guard fitScale < 1 else { return 1 }
        let window = revealDuration * surfaceStrike
        guard window > 0 else { return t < revealStart ? 1 : 0 }
        return 1 - min(max((t - revealStart) / window, 0), 1)
    }

    /// The fraction of the reveal over which the ground goes. Short enough that
    /// the tower is alone well before the camera settles, long enough that it is
    /// a dissolve and not a cut in a saved video.
    static let surfaceStrike: Double = 0.6

    // **NO RIPPLE, AND THE NUMBERS ARE WHY.**
    //
    // `TowerLattice` answers a landing with a ring of lit cells, and a replay is
    // a sequence of landings, so the ripple looks like the obvious thing to pass
    // through. Solved against the real pacing at 402x874 it is not. A ring lasts
    // 0.42s for a 1x1 and 0.66s for a 2x2, against the gap the build actually
    // leaves between landings:
    //
    //   week, 22 wins     359ms apart   1.2 to 1.9 rings alive at once
    //   month, 108 wins   140ms apart   3.0 to 4.7
    //   month, 150 wins   122ms apart   3.4 to 5.4
    //
    // Three to five rings on the surface at every instant, for twenty-two
    // seconds, is not a surface answering a landing. It is a boiling lattice,
    // and it is the end of the one sentence the component is built on: "enough
    // that the tower reads as built into something, not enough to count them
    // without looking for them."
    //
    // Check 10 of the rubric does NOT settle this either way, and it is worth
    // being straight about that rather than borrowing it. A replay is one answer
    // to one press, and the blocks, the count, the camera and the dance all
    // already move on that press, so a ripple would be allowed. It is left out
    // on the density, and on the export.
    //
    // **What was rejected, in the order it was tried.**
    //
    // 1. Passing the latest landing straight through as `ripple`. The landing
    //    track is keyed off `LatticeRipple.started`, a `Date`, so every landing
    //    cancels the one before it. At a month's 140ms against a 0.42s track a
    //    ring never gets past 33% of its reach: seven restarts a second, each a
    //    bright stub beside the newest block. A strobe, not a surface.
    // 2. Deriving the ripple from `t` instead, which the script could do
    //    honestly, since it holds every landing's time, column and row. That is
    //    the only version that keeps the replay's one real claim -- no animation
    //    state anywhere in it, one function for the live view and for every
    //    frame of the video -- and the only one that could survive
    //    `ImageRenderer`, where a keyframe track renders its initial value and a
    //    ripple driven by a `Date` draws nothing at all. The alternative is a
    //    live replay whose saved video is a different replay. Rejected anyway on
    //    the density above, and because it needs `TowerLattice` to take N
    //    ripples where it takes one: a shared-file change to answer a
    //    measurement that says do not.
    // 3. Rippling only for 2x2 landings, to cut the density to the heavy
    //    minority. The arithmetic works and the idea does not: a surface that
    //    answers some wins and not others is chrome with an opinion about which
    //    wins matter, and a replay is a record, not a ranking.
    // 4. Rippling during the build and not the dance. The build IS the dense
    //    part, so that drops the quiet two seconds and keeps the loud twenty.
    //
    // `touches` is left empty for a simpler reason: the page's touch ring is a
    // Wins tab thing (`TouchRippleModifier`), and the replay's own taps are a
    // skip and a photograph, not a disturbance of the ground.

    // MARK: Tower

    private var tower: some View {
        let camera = self.camera
        let radius = GridConstants.blockCornerRadius(forCell: m.cell)
        let height = worldHeight
        // A poster is a picture of a tower at a glance: at shelf size a
        // title is a speck, and a row of them reads as dust.
        let titleOpacity = poster == nil ? titleOpacity(at: camera.scale) : 0
        return ZStack(alignment: .bottomLeading) {
            Color.clear.frame(width: script.gridWidth, height: height)
            ForEach(replay.blocks.indices, id: \.self) { index in
                let block = replay.blocks[index]
                let pose = script.pose(index, at: t)
                if pose.visible {
                    let f = script.blockFrame(index)
                    let image = images[block.win.photo]
                    BlockFace(title: block.win.title, category: block.win.category,
                              rowSpan: block.rowSpan,
                              width: f.width, height: f.height, cornerRadius: radius,
                              hasPhoto: image != nil || block.win.photo.map { expectsPhoto?($0) ?? false } == true,
                              showOverlay: titleOpacity > 0,
                              overlayOpacity: titleOpacity) {
                        if let image, let source = block.win.photo {
                            photo(image, crop: block.win.crop, width: f.width, height: f.height)
                                .opacity(photoOpacity?(source) ?? 1)
                        }
                    }
                    .scaleEffect(x: pose.scaleX, y: pose.scaleY, anchor: .bottom)
                    .rotationEffect(.degrees(pose.tilt), anchor: .bottom)
                    .opacity(pose.opacity)
                    .offset(x: f.minX, y: -f.minY + pose.fallOffset + pose.lift)
                }
            }
        }
        .modifier(stage)
        .accessibilityHidden(true)
    }

    /// The camera at `t`, or the poster's fixed one.
    ///
    /// Read twice a frame now, by the tower and by the surface under it. That is
    /// safe for exactly the reason this whole file exists: it is a pure function
    /// of `t`, so two evaluations are the same number, and the alternative, one
    /// value threaded through two properties, is a thing that can be forgotten.
    private var camera: ReplayScript.Camera {
        poster.map { ReplayScript.Camera(rise: 0, scale: $0.scale) } ?? script.camera(at: t)
    }

    /// The finished tower's height in world points: what the tower and the
    /// surface under it are both laid out against, so the two share a base.
    private var worldHeight: CGFloat { max(script.towerHeight, 1) }

    private var stage: CameraStage {
        CameraStage(camera: camera, width: script.gridWidth, height: worldHeight,
                    frameWidth: m.frame.width, baseY: poster?.baseY ?? m.baseY)
    }

    /// One tap layer over the whole tower, hit-tested against where the
    /// script draws each block, rather than a recogniser per block.
    ///
    /// **Why one layer.** A finished month rests at a scale near 0.11, where a
    /// block is 9pt across; the script's `block(at:)` gives every block at
    /// least a finger's target. It is a sibling in the ZStack, not an
    /// overlay: over the close it would take Share's taps, and an optional
    /// sibling leaves the tower's identity alone when it arrives.
    ///
    /// **Why it cannot fight the player's gestures.** A child's tap gesture
    /// wins over an ancestor's, so after the close a tap here is not also the
    /// player's skip; that skip is a no-op there anyway, since it only moves
    /// forward to the close. The player's hold is simultaneous and still runs.
    private func blockTaps(_ onTap: @escaping (Int) -> Void) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { point in
                if let index = script.block(at: point, t: t) { onTap(index) }
            }
            .accessibilityHidden(true)
    }

    /// How strongly block titles draw at a camera scale.
    ///
    /// Photographed at a month's fitted scale (0.11) every title rendered as a
    /// 2pt grey speck, so a finished month read as a ribbon covered in dust.
    /// At 0.45 `Typography.headerMedium` draws at about 8pt, which is where it
    /// stops being words.
    ///
    /// **Faded, not cut:** across scale 0.55 to 0.45, so the saved video has
    /// no one-frame cut. **And decided by where the tower comes to REST:** a
    /// tower whose fitted scale is at or above the floor keeps full titles
    /// throughout. Fading by the live scale alone left the sample week, which
    /// rests at 0.50, with every title at 47% for good, and a finished tower
    /// with ghost-grey titles reads as a rendering fault. Any band would catch
    /// some tower at rest; this way none is.
    private func titleOpacity(at scale: CGFloat) -> Double {
        if script.fitScale >= Self.titleScaleFloor { return 1 }
        return Double(min(max((scale - Self.titleScaleFloor) / Self.titleFade, 0), 1))
    }

    private static let titleScaleFloor: CGFloat = 0.45
    private static let titleFade: CGFloat = 0.10

    /// The crop exactly as `CachedImageView` applies it: offset the FILLED
    /// picture by a fraction of its drawn size, then frame, then clip. Offset
    /// after the frame moves the picture off its own clip and leaves a strip
    /// of the block's colour showing.
    private func photo(_ image: UIImage, crop: CGPoint, width: CGFloat, height: CGFloat) -> some View {
        let size = image.size
        let scale = size.width > 0 && size.height > 0 ? max(width / size.width, height / size.height) : 1
        return Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .offset(x: -crop.x * size.width * scale, y: -crop.y * size.height * scale)
            .frame(width: width, height: height)
            .clipped()
    }

    // MARK: Close

    /// Under the tower once it has danced: the controls, and nothing else.
    ///
    /// **No sentence** (the owner, 2026-09-15): a replay is shared with
    /// friends, and "Thursday was your biggest day" means nothing to them.
    /// The count and the title at the top already say what the tower is. The
    /// video passes no controls, so its close is the tower alone.
    @ViewBuilder
    private var close: some View {
        if let controls {
            let arrival = script.closeArrival(at: t)
            controls
                .opacity(arrival.opacity)
                .offset(y: arrival.offset)
                .allowsHitTesting(t >= script.closeStart)
                .padding(.horizontal, GridConstants.horizontalPadding)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .contain)
                // On the bottom margin the script laid out (`closeTop`), so
                // the row is seated just above the home indicator on every
                // phone and the tower fills the space above it.
                .alignmentGuide(VerticalAlignment.top) { _ in -m.closeTop }
                .frame(width: m.frame.width, height: m.frame.height, alignment: .top)
        }
    }
}

/// **The camera, as one modifier, applied to the tower and to the surface it
/// stands on.**
///
/// World points to frame points: a world height `h` is drawn at
/// `baseY - scale * (h - rise)`, which is the mapping `ReplayScript`'s own
/// header states. It used to be four modifiers typed inline at the end of
/// `tower`, which was fine while the tower was the only thing in the scene.
/// It is not any more, and the replay's scale is not one number: 1 through the
/// build, 0.574 where a week comes to rest, 0.128 where a month does, moving
/// geometrically between them through the reveal. Two copies of that chain is
/// two chances for a surface and the thing standing on it to come apart
/// mid-zoom, and they would come apart in the one second nobody screenshots.
///
/// **`frame` does not clip, and that is load-bearing.** The lattice is taller
/// than `height` by its overhang and is placed bottom-aligned, so it overflows
/// upward and is scaled and positioned by the tower's own base. The same trick
/// the Wins tab's `.background(alignment: .bottom)` relies on.
private struct CameraStage: ViewModifier {
    var camera: ReplayScript.Camera
    var width: CGFloat
    var height: CGFloat
    var frameWidth: CGFloat
    var baseY: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(width: width, height: height, alignment: .bottomLeading)
            .scaleEffect(camera.scale, anchor: .bottom)
            .offset(y: camera.rise * camera.scale)
            .position(x: frameWidth / 2, y: baseY - height / 2)
    }
}

/// Lays its content out at a fraction of its width, trailing-aligned: a
/// digit position opening as the count gains a digit. Its baselines are the
/// content's, so the count's line still sits on "wins".
private struct WidthReveal: Layout {
    var fraction: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let size = subviews.first?.sizeThatFits(.unspecified) ?? .zero
        return CGSize(width: size.width * min(max(fraction, 0), 1), height: size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: CGPoint(x: bounds.maxX, y: bounds.minY), anchor: .topTrailing, proposal: .unspecified)
    }

    func explicitAlignment(of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize,
                           subviews: Subviews, cache: inout ()) -> CGFloat? {
        guard let first = subviews.first else { return nil }
        return bounds.minY + first.dimensions(in: .unspecified)[guide]
    }
}

private extension View {
    /// The frame's accessibility default action, when the caller gave one.
    @ViewBuilder
    func replayActivation(_ action: (() -> Void)?) -> some View {
        if let action { accessibilityAction(.default, action) } else { self }
    }
}
