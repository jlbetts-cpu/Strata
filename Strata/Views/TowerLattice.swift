import SwiftUI
#if DEBUG
import os
/// `-strataLatticeLog`: one line per landing, for checking WHICH colour the
/// surface answered a photographed win in. Off unless the flag is passed, and
/// the message is an autoclosure so a run without it builds no strings.
/// Never on the per-frame draw path: a probe that formatted a string for
/// every band of every frame was, itself, work on the frame the block lands
/// on.
enum LatticeProbe {
    static let isOn = ProcessInfo.processInfo.arguments.contains("-strataLatticeLog")
    static let log = Logger(subsystem: "Strata", category: "lattice")
    static func note(_ message: @autoclosure () -> String) {
        guard isOn else { return }
        // Evaluated into a local first: the log's own interpolation escapes
        // what it is handed, and a non-escaping autoclosure cannot be.
        let text = message()
        log.notice("[PERF-LAT] \(text, privacy: .public)")
    }
}
#endif

/// **The surface the tower is built on.**
///
/// The owner, 2026-09-23: "the blocks right now, they don't feel like they
/// fit when there is a bunch of images, like they just don't fit well inside
/// of there when they are mixed, it looks a bit odd. I think the easy fix
/// would be to add structure to the background, like a grid of some sort that
/// helps structure the screen. But I don't want it to look cheap, it has to
/// be like if Apple designed it: minimal, clean. And really help the user
/// understand."
///
/// **What the problem actually is.** A tower of flat colours is a composition
/// somebody chose; the same tower with photographs in half the slots is two
/// kinds of object on one page, and the photographs bring their own colour,
/// their own contrast and their own edges. Nothing on the page says the two
/// belong to the same system, so the mixed tower reads as a collage.
///
/// **So this is not wallpaper, it is the grid the blocks land in.** Same cell
/// size, same 4pt gutter, same corner radius, anchored to the same bottom row.
/// A block does not sit ON the pattern, it FILLS one of these cells, and the
/// empty ones carry on above it. That is the part that teaches: you can see
/// the slots, so you can see that a small win takes one and a big one takes
/// four, and a photograph is just a slot with a picture in it.
///
/// **Why cells and not lines.** A ruled lattice of hairlines is graph paper:
/// it is a second geometry laid over the first, its lines land in the
/// gutters, and at this contrast hairlines alias into a grey haze on a
/// scrolling view. Filled cells are the app's own shape at the app's own
/// radius, they have no sub-pixel edge to shimmer, and the 4pt gutter stays
/// the gutter rather than becoming a drawn line.
///
/// **It fades upward** so the screen is grounded rather than caged. Strongest
/// under the tower, gone well before the top of the viewport, which is also
/// what keeps it from reading as an empty state waiting to be filled in.
struct TowerLattice: View {
    /// The tower's cell, which is `colW` at the call site: the same number
    /// every block is measured with.
    var cellSize: CGFloat
    /// How tall the tower's own grid is, so the lattice knows where the
    /// content ends and its own overhang begins.
    var contentHeight: CGFloat
    var spacing: CGFloat = GridConstants.spacing
    var columns: Int = GridConstants.columnCount

    /// **The touches the page is currently answering**, so the surface can
    /// answer them too.
    ///
    /// The owner, 2026-09-30: "make sure it also interacts with the lattice,
    /// like it looks like the lattice is also participating in the moving."
    ///
    /// The ring itself is drawn in the page's BACKGROUND, underneath the
    /// lattice — which already does half the job for free, because a pane is
    /// translucent and a gap is not, so the ring arrives at the eye already cut
    /// into the grid. What that cannot do is move. This is the other half: the
    /// panes the ring is passing brighten, on the ring's own curve, so the
    /// sheet reads as taking the disturbance rather than as something the
    /// disturbance happens behind.
    ///
    /// Empty almost always, and everything below is gated on that.
    var touches: [TouchRipple] = []

    /// **How far above the tower the lattice carries on, in rows.**
    ///
    /// It was a whole viewport, and photographed that was the failure he
    /// warned about: a checkerboard from the tab bar to the status bar, at
    /// one strength, with the fade finishing off screen above. The lattice
    /// is a surface the tower stands on, not a backdrop the app lives in, so
    /// it reaches a few rows past the top block and is gone.
    static let rowsAbove = 3

    /// **How much ink an empty cell gets, as a share of `quietFill`.**
    ///
    /// `AppColors.quietFill` is the app's "empty cell" token at 6% ink, which
    /// is right for ONE well on a page and too strong for a field of them:
    /// at 6% the lattice reads as a checkerboard and competes with the
    /// blocks. Rendered and looked at rather than reasoned about.
    /// **Photographed at 0.55 and it was a checkerboard**, which is exactly
    /// the cheap he asked this not to be. The cells have to be findable and
    /// then forgotten: enough that the tower reads as built into something,
    /// not enough to count them without looking for them.
    /// **0.34, after 0.62 was too much.** The owner, 2026-09-30: "I think the
    /// lattice looks better more subtle, right now it's too visible." It went to
    /// 0.62 while the fade bug was still eating most of it; once that was fixed
    /// the same number was suddenly doing twice the work it had been. A value
    /// chosen against a broken renderer is not a value.
    ///
    /// **How opaque the pane is.** It was a fraction of black ink until the
    /// cells stopped being paint; as a white pane over a scene it is the
    /// difference between a cell and the gap beside it, which is the whole of
    /// the translucency. The two failure modes it sits between — too thin to
    /// find, too thick to see through — are pinned in `TowerLatticeTests`.
    static let strength: Double = 0.34


    /// **What the surface is worth at the peak of a landing**, over the
    /// resting cells, in the block's own colour.
    ///
    /// The owner, 2026-09-23: "it's not actually using the lattice, it's like
    /// a separate ripple that shouldn't be there... they should react to a
    /// block dropping, ripple with the colour or something, depending on how
    /// big the block is."
    ///
    /// The first version was a band that swept the whole lattice whenever you
    /// arrived on the screen, and he is right that it reads as an overlay
    /// rather than as the surface: a soft wash crossing everything, in grey,
    /// for no reason anybody asked for. Nothing animates on arrival now.
    /// **A landing is the only thing that moves the lattice**, and it moves
    /// it from where the block actually hit.
    ///
    /// **In ink, not in the block's colour.** It carried the block's colour,
    /// and the photograph's colour where there was one, for exactly one
    /// build. The owner: "I feel like the colour of the pulses is what makes
    /// it not look premium. I feel like it should just be a more visible
    /// grey." He is right, and it is the design doc's own rule turned on me:
    /// the blocks and the photographs carry every saturated colour in this
    /// app, and the chrome is ink. A coloured flash under the tower is the
    /// chrome borrowing the content's voice, which is the definition of
    /// tacky here. Grey, and stronger, so it reads as the surface taking the
    /// hit rather than as a light coming on.
    ///
    /// These are a share of `inkPrimary`, so a 2x2 lands at about a tenth of
    /// full ink against a resting cell's two percent: four or five times the
    /// cell you can already see, which is the "more visible" he asked for,
    /// and still quiet enough to be a material rather than an effect.
    static func peak(for span: Int) -> Double {
        switch span {
        case 4: return 0.12     // a 2x2
        case 2: return 0.09     // a 2x1
        default: return 0.07    // a 1x1
        }
    }

    /// How far the ring travels, in cells, and how long it takes.
    ///
    /// **Speed is the motto**, so even the heaviest block is done in two
    /// thirds of a second: long enough to read as the surface answering,
    /// short enough that it is over before you have looked for it.
    static func reach(for span: Int) -> CGFloat {
        switch span {
        case 4: return 5.0
        case 2: return 3.6
        default: return 2.6
        }
    }

    static func duration(for span: Int) -> Double {
        switch span {
        case 4: return 0.66
        case 2: return 0.52
        default: return 0.42
        }
    }

    /// The landing the surface is answering, if it is answering one.
    var ripple: LatticeRipple? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var pitch: CGFloat { cellSize + spacing }
    private var overhang: CGFloat { CGFloat(Self.rowsAbove) * pitch }
    private var height: CGFloat { max(contentHeight, 1) + overhang }

    var body: some View {
        resting
            .overlay { landing }
            .overlay { touchSwell }
            .mask {
                // **The fade is spent on the overhang, not on the whole
                // height.** As a share of the lattice it finished above the
                // top of the screen and every visible cell came out at full
                // strength. In points it always lands where the tower ends:
                // clear at the top, full by the time it reaches the block.
                // **THE FADE IS ONE ROW, AND IT WAS EATING THE WHOLE LATTICE.**
                //
                // It ran from clear at the top to full at `overhang / height`,
                // with a note saying the fade was "spent on the overhang, not on
                // the whole height". The intent was right; the arithmetic was
                // not. `overhang` is three rows and `height` is however tall the
                // lattice happens to be, so on a SHORT tower -- which is most
                // days, and every new user -- that fraction covers most of what
                // is on screen, and the cells you can see are the ones being
                // faded away.
                //
                // Measured, and this is the whole reason the lattice "was not
                // visible" through every round of this: with the mask replaced
                // by solid black, a pane at full strength reads 255 against a
                // 224 ground. With the mask in place it read 225. The opacity
                // was never the problem and no amount of tuning it could have
                // been the fix -- including the hairline I drew round every cell
                // to rescue it.
                //
                // One row, in points, from the top of the lattice. Enough that
                // the grid does not end in a hard line above the tower, short
                // enough that every cell below the first row is at full
                // strength.
                LinearGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: min(pitch / max(height, 1), 1)),
                    .init(color: .black, location: 1)
                ], startPoint: .top, endPoint: .bottom)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// The lattice as it sits: every cell at `strength`.
    private var shape: TowerLatticeShape {
        TowerLatticeShape(cellSize: cellSize, spacing: spacing, columns: columns)
    }

    /// **The cells are the sheet, and the gaps are where you see past it.**
    ///
    /// The owner, 2026-09-29, for the third time and this time unmistakably:
    /// "you keep doing colours but not doing the translucent backing like I
    /// asked."
    ///
    /// He was right and I had been answering a different question every time.
    /// The cells were `quietFill` — black at 6%, multiplied by 0.34, so 2% ink
    /// painted ON TOP of whatever was behind them. That is opaque thinking: a
    /// surface that ADDS darkness can never let anything through, so no matter
    /// what went in the background, the lattice sat in front of it as paint.
    /// Measured earlier in the session, it came to three levels out of 255,
    /// which is why the page read as empty however much was put behind it.
    ///
    /// Inverted: a cell is now a white translucent pane. The scene behind shows
    /// through it, dimmed and cooled the way something does through cloth, and
    /// the GAPS between cells are where you see the scene at full strength. So
    /// the lattice reads as panes held up against a sky rather than as a grid
    /// drawn on a page, the light varies down the tower because the scene does,
    /// and the whole thing finally has the depth the flat version could not.
    ///
    /// **A MATERIAL, NOT A FILL, AND THAT IS THE DIFFERENCE BETWEEN GLASS AND
    /// PAINT.**
    ///
    /// The first go at this used white at 55%, on the reasoning that forty-odd
    /// `.ultraThinMaterial` cells would be forty blur passes in a scrolling
    /// grid. The reasoning was wrong twice.
    ///
    /// Wrong on the look, which is the part that matters: Apple's description
    /// of the material is that it "dynamically bends, shapes, and concentrates
    /// light" and "adapts to the content underneath". A flat white fill is
    /// translucency with no refraction — it lets a colour through and does
    /// nothing to it. That is the difference the owner kept seeing and I kept
    /// answering with a different opacity.
    ///
    /// Wrong on the cost too: `shape` is ONE `Shape` that already contains every
    /// cell rectangle, so filling it with a material is a single backdrop pass
    /// for the whole lattice, not one per cell. The thing that would have been
    /// expensive is forty separate views, which was never how this was drawn.
    ///
    /// **AND THEN THE MATERIAL WAS TRIED, AND WAS WORSE, AND THE REASON IS THE
    /// USEFUL PART.**
    ///
    /// `.ultraThinMaterial` is the correct primitive on paper and it was built
    /// and photographed: the cells nearly vanished. A backdrop blur blurs what
    /// is behind it, and what is behind this is a smooth `MeshGradient`. Blur a
    /// smooth gradient and you get the same smooth gradient. The material's
    /// entire defining behaviour had nothing to act on, so all that survived was
    /// a faint lightening — which is the one thing a plain white fill already
    /// does, more cheaply and with a number you can steer.
    ///
    /// So a material is right when there is DETAIL behind it, and this backdrop
    /// is deliberately smooth. If the scene ever gains texture, come back to
    /// this: one material fill on `shape` is a single backdrop pass, because
    /// `shape` already contains every cell rectangle, and the "forty blur
    /// passes" worry that first ruled it out was never true.
    ///
    /// Either way it is not `.glassEffect`. Apple's layering model puts Liquid
    /// Glass in the functional layer floating ABOVE content, and the lattice is
    /// the surface the tower is built on. The glass in this app stays where it
    /// belongs — the tab bar, the slot, the buttons.
    private var resting: some View {
        // **A PANE, AND NOTHING DRAWN AROUND IT.**
        //
        // A hairline was added here and the owner rejected it on sight, and he
        // was right: a drawn line is the one thing this whole pass is trying not
        // to do. Every cue in this design has to be made of light.
        //
        // The line was there because the cells had gone to ONE level of contrast
        // against the gap beside them. The mistake was fixing the wrong end. A
        // white pane cannot be brighter than a ground that is already at 240, so
        // the answer was never to outline the pane — it was to stop the ground
        // being that bright. `DayGround` sits lower now, and the panes are the
        // brightest thing on the page again, which is what a sheet lit from
        // behind actually looks like.
        shape.fill(Color.white.opacity(Self.strength))        .frame(height: height)
    }

    /// **The sheet answering a touch, drawn as the panes the ring is on.**
    ///
    /// White, because a pane IS white here and this is the pane getting
    /// brighter — the same move the landing makes in ink, and for the same
    /// reason the landing is not coloured: the chrome does not borrow the
    /// content's voice.
    ///
    /// Three things make this honest rather than a second effect laid on top:
    ///
    /// 1. **It is masked to `shape`.** Only the cells light. The gaps between
    ///    them stay exactly as they were, so the ring is quantised into the
    ///    grid instead of sweeping across it.
    /// 2. **It reads the ring's own position**, through `TouchRipple.front`,
    ///    rather than running a curve of its own. Two curves would be two
    ///    speeds, and the whole point is that it is one disturbance.
    /// 3. **The `TimelineView` is only here while something is moving.** An
    ///    always-mounted one is what kept the landing animation off a timeline
    ///    in the first place: measured at a 50ms frame gap on the frame the
    ///    block hits. `TouchRippleModifier` clears its array on a timer so this
    ///    goes away on its own.
    @ViewBuilder
    private var touchSwell: some View {
        if !reduceMotion, !touches.isEmpty {
            GeometryReader { geo in
                // Where this lattice is on the page, so a point taken from a
                // finger somewhere in the header or over the tab bar lands on
                // the right cell of a grid that is scrolled some way up.
                let origin = geo.frame(in: .named(TouchRipple.space)).origin
                TimelineView(.animation) { timeline in
                    Canvas { context, _ in
                        let now = timeline.date
                        for touch in touches {
                            for ring in 0..<TouchRipple.rings {
                                guard let front = touch.front(ring, at: now) else { continue }
                                let centre = CGPoint(x: touch.at.x - origin.x,
                                                     y: touch.at.y - origin.y)
                                let r = front.radius
                                let circle = Path(ellipseIn: CGRect(
                                    x: centre.x - r, y: centre.y - r,
                                    width: r * 2, height: r * 2))
                                // **THE PANES TAKE THE SAME DENT, NOT A
                                // DIFFERENT EFFECT.**
                                //
                                // This drew the ring in WHITE, on the reasoning
                                // that a pane is white and a pane reacting gets
                                // brighter. That was true on the lower, warmer
                                // ground; on a clean white page a white band
                                // over a 248 pane is nothing at all, and the
                                // lattice stopped taking part at exactly the
                                // moment the page was cleaned up.
                                //
                                // So it is `TouchRipple`'s own two colours,
                                // offset its own way: the panes carry the same
                                // embossed dip the page does, a little stronger,
                                // and because this is masked to the cells the
                                // grid reads as the thing being disturbed rather
                                // than as something the disturbance happens
                                // behind. One light source, one dent, two
                                // surfaces.
                                context.drawLayer { layer in
                                    layer.addFilter(.blur(radius: TouchRipple.shadowBlur))
                                    layer.translateBy(x: -TouchRipple.offset,
                                                      y: -TouchRipple.offset)
                                    layer.stroke(
                                        circle,
                                        with: .color(TouchRipple.light.opacity(Self.swell * front.fade)),
                                        lineWidth: TouchRipple.bandWidth)
                                }
                                context.drawLayer { layer in
                                    layer.addFilter(.blur(radius: TouchRipple.shadowBlur))
                                    layer.translateBy(x: TouchRipple.offset,
                                                      y: TouchRipple.offset)
                                    layer.stroke(
                                        circle,
                                        with: .color(TouchRipple.shade.opacity(Self.swell * front.fade)),
                                        lineWidth: TouchRipple.bandWidth)
                                }
                            }
                        }
                    }
                }
                .mask { shape.frame(height: height) }
            }
        }
    }

    /// **How much brighter a pane gets as the ring crosses it**, on top of
    /// `strength`.
    ///
    /// A share of the ring's own strength, so the surface and the page are one
    /// disturbance at two depths rather than two effects on one curve. Under
    /// about 0.3 the lattice does not visibly take part, which was the
    /// complaint; over about 0.7 the cells flash and the grid becomes the
    /// subject, which is the other one.
    static let swell: Double = 0.45

    /// **The landing, drawn as the cells it reaches.**
    ///
    /// A ring travels out from the cells the block just filled, and every
    /// cell it passes takes the block's colour for a moment. The owner:
    /// "it's not actually using the lattice, it's like a separate ripple
    /// that shouldn't be there... they should react to a block dropping."
    ///
    /// **One animated number drives all of it**, through a keyframe track:
    /// how far through the landing we are, 0 to 1. The cells the ring is
    /// passing are the only ones drawn, and the colour fades as it travels,
    /// so the envelope comes out of the same number rather than out of a
    /// second animation that could drift against it.
    ///
    /// **No `TimelineView` and no `Canvas`, and that is a measurement rather
    /// than a preference.** Both of those were built first, and mounting a
    /// paused timeline that woke for each landing cost a 50ms frame gap
    /// every time: sixteen of them in 38 seconds with the lab dropping a
    /// block every 1.5s, against zero in the same run with no landings. The
    /// gap landed on exactly the frame the block hits, which is the one
    /// moment the screen has to be smooth.
    private var landing: some View {
        // **Mounted always, played by a change of trigger.**
        //
        // It was wrapped in `if let ripple`, which looks tidier and cannot
        // work: every landing is a different value, so the whole subtree was
        // re-created and a keyframe animator that has just appeared has no
        // trigger CHANGE to play. One mounted view, and the trigger is the
        // moment of impact.
        Color.clear
            .frame(height: height)
            .keyframeAnimator(initialValue: 0.0, trigger: ripple?.started ?? .distantPast) { view, phase in
                view.overlay { rings(phase: phase) }
            } keyframes: { _ in
                KeyframeTrack(\.self) {
                    // **One ease-out keyframe, and NOT a spring.**
                    //
                    // A `SpringKeyframe` inherits the velocity of the
                    // keyframe before it, and this track used to open with a
                    // 1ms hop from a resting sentinel of -2 up to 0. Two
                    // cells in a millisecond is 2000 cells a second, the
                    // spring launched at that, and the ring left the screen
                    // instead of crossing it. Measured with the lab running
                    // and every frame logged: of 3023 frames of ripple,
                    // 459 sat on the sentinel, exactly ONE had the front
                    // inside the reach, and the rest were 4.1 to 78.6 cells
                    // out against a reach of at most 5. Past the reach the
                    // envelope is zero, so every landing drew nothing. That
                    // is the whole of the "eighteen screenshots caught no
                    // ripple" bug. A linear keyframe on an ease-out curve
                    // has no velocity to inherit and cannot overshoot.
                    LinearKeyframe(1.0,
                                   duration: Self.duration(for: ripple?.span ?? 1),
                                   timingCurve: .easeOut)
                }
            }
            .allowsHitTesting(false)
    }

    /// The two rings: the cells the front is on, and the ones just behind it.
    ///
    /// Two bands rather than a gradient, because a cell is either reacting or
    /// it is not — the quantising is what makes this read as the surface
    /// rather than as a glow laid over it.
    @ViewBuilder
    private func rings(phase: Double) -> some View {
        // **`phase` runs 0 to 1, and it is deliberately not the front in
        // cells.** Both ends of it draw nothing, which is what lets one
        // mounted animator rest between landings: 0 before the first one and
        // 1 after each. A track that rested on "the reach" would rest on a
        // different number for every block size, so a landing of a different
        // size to the one before it would draw a stale ring for the frame
        // before its own track started.
        if let ripple, !reduceMotion, phase > 0, phase < 1 {
            ringLayers(ripple, phase: phase)
        }
    }

    /// Where the ring's front is, in cells, at a given point in the landing.
    ///
    /// The one place `phase` becomes a distance, so a test can walk a whole
    /// landing and ask what was visible during it rather than trusting the
    /// animation to have taken the values it was asked for. It did not: see
    /// the keyframe track above.
    static func front(atPhase phase: Double, span: Int) -> CGFloat {
        CGFloat(phase) * reach(for: span)
    }

    @ViewBuilder
    private func ringLayers(_ ripple: LatticeRipple, phase: Double) -> some View {
        let front = Self.front(atPhase: phase, span: ripple.span)
        let peak = Self.peak(for: ripple.span)
        let envelope = Self.envelope(front: front, ripple: ripple)
        RippleCells(front: front, band: 0...Self.frontBand, ripple: ripple,
                    cellSize: cellSize, spacing: spacing, columns: columns)
            .fill(AppColors.inkPrimary.opacity(peak * envelope))
        RippleCells(front: front, band: Self.frontBand...Self.backBand, ripple: ripple,
                    cellSize: cellSize, spacing: spacing, columns: columns)
            .fill(AppColors.inkPrimary.opacity(peak * envelope * 0.45))
    }

    /// How thick the ring is, in cells: the band at full strength, and the
    /// one trailing it at under half. A cell inside the first band is lit for
    /// `frontBand` cells of travel, which at these reaches is five or six
    /// frames — long enough to read as that cell answering rather than as a
    /// flicker passing over it.
    static let frontBand: CGFloat = 0.70
    static let backBand: CGFloat = 1.70

    /// **The energy is spent over the cells somebody can actually SEE.**
    ///
    /// The decay used to run from the ring's centre, which is underneath the
    /// block: the nearest cell the block is not already covering is a whole
    /// cell out from a 1x1's centre, so the ring reached the first visible
    /// cell with a third of `peak` already gone and `peak` never meant what
    /// its own doc comment says. It runs from the block's own edge now, so a
    /// cell beside the block gets the full number and the last cell within
    /// reach gets none.
    static func envelope(front: CGFloat, ripple: LatticeRipple) -> Double {
        let reach = reach(for: ripple.span)
        let edge = CGFloat(max(ripple.columnSpan, ripple.rowSpan)) / 2
        guard front > 0 else { return 0 }
        let travelled = max(0, front - edge)
        return max(0, min(1, 1 - Double(travelled / max(reach - edge, 0.01))))
    }

}

/// **A landing, as the lattice needs to know it.**
///
/// Where the block came to rest, how big it is, and what colour it is. The
/// surface needs nothing else, and taking only this keeps the lattice out of
/// the tower's model: it cannot accidentally start depending on a habit, a
/// log or a view model.
struct LatticeRipple: Equatable {
    var column: Int
    var row: Int
    var columnSpan: Int
    var rowSpan: Int
    /// When it hit. The ring is driven by a keyframe track off this value, so
    /// a new landing is a new trigger rather than a counter somebody has to
    /// remember to reset.
    var started: Date = Date()

    /// How many cells the block covers, which is what the ripple is scaled
    /// by: a Quick taps the surface, a Deep hits it.
    var span: Int { columnSpan * rowSpan }
}


/// Every cell of the tower's grid, from the bottom row upward.
///
/// **Bottom anchored, because the tower is.** A block's frame comes from
/// `GridConstants.blockFrame(column:row:...)` and is then flipped so row 0
/// sits on the ground; the lattice is built the same way round, from
/// `rect.maxY` up, so the ground row of cells is exactly the ground row of
/// blocks whatever the height happens to be. Measuring down from the top
/// would put the two half a gutter out of step at any height that is not a
/// whole number of rows.
struct TowerLatticeShape: Shape {
    var cellSize: CGFloat
    var spacing: CGFloat
    var columns: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = GridConstants.blockCornerRadius(forCell: cellSize)
        for cell in cellRects(in: rect) {
            path.addRoundedRect(in: cell,
                                cornerSize: CGSize(width: radius, height: radius),
                                style: .continuous)
        }
        return path
    }

    /// **Where every cell is, as numbers rather than as a drawn path.**
    ///
    /// Separate from `path(in:)` so a test can hold it against
    /// `GridConstants.blockFrame`, which is the only thing that makes this
    /// safe: a lattice a few points out of step with the blocks is worse
    /// than no lattice, and it is the kind of wrong nobody notices in a
    /// screenshot until the day a cell size changes. The ripple walks the
    /// same list, so the cells that light up are the cells that are drawn.
    func cellRects(in rect: CGRect) -> [CGRect] {
        guard cellSize > 0, columns > 0 else { return [] }
        let pitch = cellSize + spacing
        var rects: [CGRect] = []
        var top = rect.maxY - cellSize
        // One row past the top edge, so a cell that is only half on screen is
        // still drawn rather than stopping in a straight line of its own.
        while top > rect.minY - pitch {
            for column in 0..<columns {
                let x = rect.minX + CGFloat(column) * pitch
                rects.append(CGRect(x: x, y: top, width: cellSize, height: cellSize))
            }
            top -= pitch
        }
        return rects
    }
}


/// **The cells a ring is passing through, right now.**
///
/// A `Shape` rather than a canvas so SwiftUI's own animation drives it: the
/// keyframe track hands `front` a new value each frame and this draws the
/// cells at that distance from the landing. Only the ring's cells are built,
/// so the work per frame is a dozen rounded rectangles rather than the whole
/// lattice.
struct RippleCells: Shape {
    /// How far out the ring has travelled, in cells.
    var front: CGFloat
    /// Which slice behind the front this layer draws, in cells.
    var band: ClosedRange<CGFloat>
    var ripple: LatticeRipple
    var cellSize: CGFloat
    var spacing: CGFloat
    var columns: Int

    private var pitch: CGFloat { cellSize + spacing }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = GridConstants.blockCornerRadius(forCell: cellSize)
        for cell in litCells(in: rect) {
            path.addRoundedRect(in: cell,
                                cornerSize: CGSize(width: radius, height: radius),
                                style: .continuous)
        }
        return path
    }

    /// **Which cells the ring is on right now, as numbers rather than as a
    /// drawn path.**
    ///
    /// Separate from `path(in:)` for the same reason
    /// `TowerLatticeShape.cellRects` is: a test can hold it against
    /// `GridConstants.blockFrame` and against the landing's own column and
    /// row. A ring a row out of step with the block that caused it is the
    /// kind of wrong nobody sees in a screenshot, and the ring being invisible
    /// for its whole life was not caught by looking either.
    func litCells(in rect: CGRect) -> [CGRect] {
        guard cellSize > 0, columns > 0, front > 0 else { return [] }
        var cells: [CGRect] = []
        let origin = origin(in: rect)
        // A row whose vertical distance alone already exceeds the front
        // cannot hold a cell the ring has reached, so it is skipped before
        // its cells are ever considered.
        let outer = front + 1
        var row = 0
        var top = rect.maxY - cellSize
        while top > rect.minY - pitch {
            let dy = (top + cellSize / 2 - origin.y) / pitch
            if abs(dy) <= outer {
                for column in 0..<columns {
                    // **A cell the block is standing in is not an empty cell
                    // any more, so it does not react.** Photographed without
                    // this the ring read as a filled patch rather than as the
                    // surface answering around the landing: the four cells at
                    // the centre light first and brightest, and the ring only
                    // becomes a ring once it has left them. On the tower a
                    // block covers them and nobody sees it, which is exactly
                    // the kind of thing that looks fine until the day
                    // something is drawn where a block is not.
                    if column >= ripple.column, column < ripple.column + ripple.columnSpan,
                       row >= ripple.row, row < ripple.row + ripple.rowSpan { continue }
                    let x = rect.minX + CGFloat(column) * pitch
                    let dx = (x + cellSize / 2 - origin.x) / pitch
                    let behind = front - sqrt(dx * dx + dy * dy)
                    guard band.contains(behind) else { continue }
                    cells.append(CGRect(x: x, y: top, width: cellSize, height: cellSize))
                }
            }
            top -= pitch
            row += 1
        }
        return cells
    }

    /// **Bottom anchored, like everything else here.** The tower's row 0 is
    /// on the ground and the lattice's bottom row is the same row, so a
    /// block's centre is measured up from `maxY` rather than down from the
    /// top: the lattice is taller than the grid by its overhang, and
    /// measuring from the top would put the ring a few rows out.
    func origin(in rect: CGRect) -> CGPoint {
        let x = rect.minX
            + CGFloat(ripple.column) * pitch
            + (CGFloat(ripple.columnSpan) * cellSize
               + CGFloat(ripple.columnSpan - 1) * spacing) / 2
        let y = rect.maxY
            - CGFloat(ripple.row) * pitch
            - (CGFloat(ripple.rowSpan) * cellSize
               + CGFloat(ripple.rowSpan - 1) * spacing) / 2
        return CGPoint(x: x, y: y)
    }
}

