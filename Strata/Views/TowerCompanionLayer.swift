import SwiftUI

// =============================================================================
// THE CALL SITE. Two lines, on the tower tab's ScrollView inside
// `MainAppView.towerContent` (on the SCROLL VIEW, not on the content, so the
// head floats over the viewport instead of scrolling away with the blocks):
//
//   .overlay { TowerCompanionLayer(active: selectedTab == .tower, probe: towerProbe, bottomInset: GridConstants.tabBarClearance,
//       landing: { latticeRipple.map { TowerCompanionLanding(at: $0.started, cell: TowerCompanionWorld.Cell($0.column, $0.row, $0.columnSpan, $0.rowSpan)) } }) { towerVM.placedBlocks.lazy.map { TowerCompanionWorld.Cell($0.column, $0.row, $0.columnSpan, $0.rowSpan) } } }
//
// Nothing else. It draws nothing, mounts nothing and asks for no frames until
// the head is switched on, and it is off until then.
//
// The switch it reads, `HeadStore.showsOnTower`, is already in the store and
// already defaults to false; what it does not have yet is a row in Profile.
// That file belongs to another session today, so the row is not written here.
// It is the same shape as the map's, beside it in `ProfileView`:
//
//   Toggle(isOn: Binding(get: { heads.showsOnTower }, set: { heads.setShowsOnTower($0) })) { Text("On the tower") }
//
// Until that row exists the feature is reachable only with
// `-strataHeadOn tower`, which `HeadStore` already understands in DEBUG.
// =============================================================================

/// A block that has just landed, in the tower's own grid numbers.
///
/// `MainAppView` already holds exactly this as `latticeRipple`, so the caller
/// hands over what it has rather than measuring anything new.
nonisolated struct TowerCompanionLanding: Equatable, Sendable {
    /// `LatticeRipple.started`: the moment of impact.
    var at: Date
    var cell: TowerCompanionWorld.Cell

    init(at: Date, cell: TowerCompanionWorld.Cell) {
        self.at = at
        self.cell = cell
    }
}

/// Numbers the companion's look is built from, in one place.
enum TowerCompanion {
    /// **The head's own height, crown to chin.**
    ///
    /// The tap floor, and no more. `HeadMarker` is 52 because a player marker
    /// on a map is the one annotation allowed to be the biggest thing on
    /// screen; this is the opposite case. The tower is the record and the head
    /// is a visitor to it, so this is the smallest size that still reads as a
    /// face and is still something a finger can catch.
    static let side: CGFloat = 44

    /// How much of the head counts as its body when it meets a wall. Under a
    /// half, so the hair can touch the edge before he stops: a circle at the
    /// full half radius stops a visible gap short of the wall and reads as an
    /// invisible fence.
    static let radiusShare: CGFloat = 0.42

    /// Clear air under the drift band and above the tab bar, so he never ends
    /// up tucked against either.
    static let topClearance: CGFloat = 8
    static let bottomClearance: CGFloat = 8

    /// The contact shadow, for the one state that earns one. Matched to
    /// `HeadMarker`, which is the other head in this app that stands on
    /// something.
    static let shadowOpacity: Double = 0.24
}

/// **Your head, living on the Wins screen.**
///
/// The owner, 2026-09-23: "for the head I want it to be added to the Wins
/// screen as an option, where it kinda just floats on the top, around,
/// bouncing off the walls, and you can kinda move around, and it will react to
/// things happening, like a block flying near him or placing a block.
/// Occasionally he can drop down and jump along the tops of the blocks, making
/// sure to jump out of the way of the blocks falling. I think that would add
/// another layer to the app. Making sure the app looks and feels good though,
/// but I think that would be a playful addition."
///
/// **It is an option and it is off.** `HeadStore.showsOnTower` already exists
/// and its `UserDefaults` key (`headOnTower`) defaults to false, so a phone
/// that has never been told otherwise gets nothing. The whole cost of the
/// feature when it is off is this view's own `body`, which resolves to
/// `EmptyView`: no simulation, no `TimelineView`, no clock, no head, and no
/// `@State` (which is why the runner below is a separate type: a `@State` is
/// created with the view it is declared on, whatever that view's body returns).
///
/// **The one thing he was most worried about is latency.** Same day: "make
/// sure there is no latency, I feel like that's something I definitely don't
/// want to see in the app, like when placing blocks or anything." So:
///
/// - The simulation lives in a plain reference box, not in `@State` and not in
///   an `@Observable`. Stepping it invalidates nothing. Same pattern and same
///   reason as `TowerGeometryProbe`: "Publishing it would re-render the whole
///   tower at 60Hz to deliver a number that nothing on screen depends on."
/// - It reads the tower through closures the caller supplies, called from
///   inside this view's own clock. A read on a frame this view owns registers
///   no observation dependency in the tower's body, so the tower does not
///   re-evaluate because the head moved.
/// - The clock is `TimelineView(.animation(paused:))` and it pauses the moment
///   the head is at rest. `TowerLattice` measured what a timeline costs when
///   it wakes: a 50ms frame gap, and the gap landed on the frame the block
///   hits. This one wakes when the block STARTS falling, which is 340 to 720ms
///   earlier (`GridConstants.dropDurationRange`), so it is already running by
///   the impact frame. That is why `falling` is worth passing even though the
///   dodge would work without it.
///
/// **Reduce Motion stops the movement, not the head.** He asked for the head
/// as an option; Reduce Motion is a statement about motion. The head parks near
/// the top and the clock stops for good.
///
/// **No shadow except when he is standing on a block.** CLAUDE.md, the
/// absolute rule: a head casts a contact shadow exactly when it is standing on
/// something. Drifting and in the air he has nothing under him, so he has no
/// shadow. `HeadMarker` is the other side of the same rule.
///
/// Nothing cute: no speech, no sparkle, no sound, no emoji. He is a head in a
/// bright room, which is all `docs/design-system-future.md` will allow.
struct TowerCompanionLayer<Cells: Sequence>: View where Cells.Element == TowerCompanionWorld.Cell {
    /// The Wins tab is the selected one. A `TabView` keeps its other tabs
    /// alive, so without this the head would go on drifting behind the camera.
    var active: Bool = true
    /// Where the tower's grid really is. Read on the companion's own frames
    /// and never published, which is what it is for.
    var probe: TowerGeometryProbe
    /// The header's height inside this overlay, if the overlay reaches under
    /// it. The tower's own header is fixed above the scroll view, so 0 is
    /// right there.
    var topInset: CGFloat = 0
    /// The tab bar's clearance. `GridConstants.tabBarClearance` is the app's
    /// number, passed in rather than read so the simulation's file stays free
    /// of the main actor.
    var bottomInset: CGFloat = 110
    /// The next slot, in this overlay's coordinates, if the caller can supply
    /// it. Without it he simply has one fewer thing to keep off.
    var slot: () -> CGRect? = { nil }
    /// A block in the air, in this overlay's coordinates.
    var falling: () -> CGRect? = { nil }
    /// The last landing. `MainAppView.latticeRipple` is this value already.
    var landing: () -> TowerCompanionLanding? = { nil }
    /// The tower's blocks. Pass a lazy map, not an array: this is walked on
    /// every frame the head is moving, and materialising an array would be a
    /// heap allocation sixty times a second.
    var cells: () -> Cells

    var body: some View {
        // **The switch is read HERE, in the companion's own body.** Reading
        // `HeadStore` from the tower's body would make the tower observe the
        // head, so toggling one would re-evaluate the tower. This body is the
        // only thing that re-runs.
        if let rig = HeadStore.shared.headForTower {
            TowerCompanionRunner(rig: rig, active: active, probe: probe,
                                 topInset: topInset, bottomInset: bottomInset,
                                 slot: slot, falling: falling,
                                 landing: landing, cells: cells)
        }
    }
}

// MARK: - What the frame loop holds on to

/// **A plain box, deliberately not observed.** See `TowerGeometryProbe` for the
/// same decision and the measurement behind it. Writing to this invalidates
/// nothing, which is the whole reason the companion can run a clock without
/// touching the tower.
///
/// At file scope rather than nested in the generic runner: a type nested in a
/// generic picks the generic up (`Runner<Cells>.Life`), and CLAUDE.md records
/// what that costs in `DrawerDetent`.
@MainActor
private final class TowerCompanionLife {
    var sim = TowerCompanionSim(radius: TowerCompanion.side * TowerCompanion.radiusShare)
    var placed = false
    var lastFrame: Date?
    /// The overlay's own origin in the window, so a global drag location can
    /// become an arena coordinate without a second geometry reader inside the
    /// gesture.
    var arenaOrigin: CGPoint = .zero
    // What the view draws, copied out of the simulation once a frame.
    var position: CGPoint = .zero
    var tilt: Double = 0
    /// Read by the shadow. Held here rather than in state so changing it costs
    /// no invalidation.
    var grounded = false
}

// MARK: - The one that actually runs

private struct TowerCompanionRunner<Cells: Sequence>: View where Cells.Element == TowerCompanionWorld.Cell {
    let rig: HeadRig
    let active: Bool
    let probe: TowerGeometryProbe
    let topInset: CGFloat
    let bottomInset: CGFloat
    let slot: () -> CGRect?
    let falling: () -> CGRect?
    let landing: () -> TowerCompanionLanding?
    let cells: () -> Cells

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    /// The same sleep every other head in the app uses: false under a sheet, a
    /// full screen cover, or a page nobody can see.
    @Environment(\.headsAwake) private var headsAwake

    @State private var life = TowerCompanionLife()
    /// **The one published bit of state, and it flips at most twice a visit**:
    /// once when he settles and once when something wakes him. It exists
    /// because an unobserved box cannot invalidate a body, and the body is
    /// where the clock's `paused` is decided.
    @State private var settled = false

    var body: some View {
        GeometryReader { geo in
            let arena = geo.frame(in: .global)
            // Cheap, and it is the wake signal. Both closures read values the
            // caller already holds, so this costs a nil check and a `Date`
            // comparison per evaluation of THIS body.
            // A nil landing is quiet whatever was answered: see
            // `TowerCompanionWorld.isQuiet`, which is the same test and
            // carries the bug it is written the way it is to avoid.
            let pending = landing()
            let quiet = falling() == nil
                && (pending == nil || pending?.at == life.sim.answeredLanding)
            let paused = reduceMotion || !active || !headsAwake
                || scenePhase != .active
                || (settled && quiet)

            // **Built once per evaluation of this body, never inside the frame
            // loop.** `LivingHeadView` is a big view. The loop below applies a
            // rotation and an offset to this same value, so what SwiftUI
            // compares each frame is identical and the head's own body has no
            // reason to run again: only the transform changes.
            //
            // `.calm`, not `.expressive`, and that is as much a performance
            // decision as a design one. `HeadLife.expressive` has
            // `floats: true`, which is `GridConstants.headFloatX`, a
            // `repeatForever` animation. A permanent animation is a permanent
            // frame request, which is the exact thing this file exists to
            // avoid, and its float would be fighting the simulation's over the
            // same few points anyway.
            let head = LivingHeadView(rig: rig, side: TowerCompanion.side, liveliness: .calm)
                .frame(width: TowerCompanion.side, height: TowerCompanion.side)
                .contentShape(Circle())

            TimelineView(.animation(paused: paused)) { context in
                // One step, then draw. Everything in `step` is arithmetic on a
                // struct the box already holds: no allocation, no formatting,
                // and nothing handed back to SwiftUI outside this closure.
                let _ = step(to: context.date, arena: arena, paused: paused)
                ZStack(alignment: .topLeading) {
                    contactShadow
                    head
                        .rotationEffect(.degrees(life.tilt))
                        .offset(x: life.position.x - TowerCompanion.side / 2,
                                y: life.position.y - TowerCompanion.side / 2)
                        .gesture(drag)
                }
                .frame(width: geo.size.width, height: geo.size.height,
                       alignment: .topLeading)
            }
        }
        // The head is a companion, not information. There is nothing in him
        // for VoiceOver to read, and a floating element in the tower's tree
        // would be one more thing to swipe past on the way to a win.
        .accessibilityHidden(true)
    }

    /// **Only while he is standing on a block.** CLAUDE.md: the heads cast a
    /// contact shadow, and they cast one exactly when they are standing on
    /// something. In the air there is nothing under him, so there is nothing
    /// to cast onto. A soft ellipse under the chin, light rather than heavy,
    /// the same shape `HeadMarker` uses on the ground.
    private var contactShadow: some View {
        Ellipse()
            .fill(Color.black.opacity(TowerCompanion.shadowOpacity))
            .frame(width: TowerCompanion.side * 0.66, height: TowerCompanion.side * 0.15)
            .blur(radius: 2.5)
            .opacity(life.grounded ? 1 : 0)
            .offset(x: life.position.x - TowerCompanion.side * 0.33,
                    y: life.position.y + TowerCompanion.side * 0.42)
            .allowsHitTesting(false)
    }

    /// Dragging and throwing him.
    ///
    /// `apple-design.md`: respond on pointer down, continuously during the
    /// gesture, and project momentum on release rather than snapping from the
    /// release point. `minimumDistance: 0` is the pointer down half;
    /// `predictedEndTranslation` is the throw.
    ///
    /// The recogniser is on the head's own 44pt circle and nothing else. Every
    /// other point of this overlay is transparent to touch, so the tower's
    /// scroll view keeps the rest of the screen. CLAUDE.md is emphatic that a
    /// recogniser on a BLOCK starves that scroll view; this is neither on a
    /// block nor inside the scrolling content, but a finger that lands on the
    /// head does move the head rather than the tower, which is the point.
    private var drag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                let p = arenaPoint(value.location)
                if life.sim.state == .held {
                    life.sim.touch(.moved, at: p)
                } else {
                    life.sim.touch(.began, at: p)
                }
                if settled { settled = false }
            }
            .onEnded { value in
                let p = arenaPoint(value.location)
                // UIKit's own projection, over roughly a quarter of a second
                // of deceleration, turned into points a second.
                let v = CGVector(
                    dx: (value.predictedEndTranslation.width - value.translation.width) / 0.25,
                    dy: (value.predictedEndTranslation.height - value.translation.height) / 0.25)
                life.sim.touch(.moved, at: p)
                life.sim.touch(.ended, at: p, velocity: v)
                if settled { settled = false }
            }
    }

    private func arenaPoint(_ global: CGPoint) -> CGPoint {
        CGPoint(x: global.x - life.arenaOrigin.x, y: global.y - life.arenaOrigin.y)
    }

    // MARK: The frame

    /// Builds the world, steps the simulation, and copies out what the view
    /// draws. The return value is unused: it is there so the call can sit in a
    /// `let _ =` inside a `ViewBuilder`, which is how `TowerLattice` does the
    /// same thing.
    @discardableResult
    private func step(to now: Date, arena: CGRect, paused: Bool) -> Bool {
        life.arenaOrigin = CGPoint(x: arena.minX, y: arena.minY)
        let world = makeWorld(arena: arena)

        if !life.placed, arena.width > 1, arena.height > 1 {
            life.placed = true
            life.sim.place(in: world)
            life.lastFrame = now
        }
        life.sim.reduceMotion = reduceMotion

        let elapsed = life.lastFrame.map { now.timeIntervalSince($0) } ?? TowerCompanionSim.tick
        life.lastFrame = now
        // Reduce Motion still needs one call: that is what parks him.
        if !paused || reduceMotion {
            life.sim.update(world, elapsed: elapsed)
        }
        life.position = life.sim.position
        life.tilt = life.sim.tilt
        life.grounded = (life.sim.state == .hopping || life.sim.state == .dodging)
            && life.sim.onSurface(world)

        // **The only place published state changes, and it changes at most
        // twice a visit.** On the next turn of the run loop rather than here,
        // because a `@State` write inside a body evaluation is the one thing
        // SwiftUI will complain about, and this is the transition, not a per
        // frame path. The `Task` inherits this view's main actor context.
        let wantsSettled = life.sim.isAtRest
        if wantsSettled != settled {
            Task { settled = wantsSettled }
        }
        return true
    }

    /// **The tower, turned into the companion's world.**
    ///
    /// Everything here is arithmetic over numbers the caller already has.
    /// `cells()` is walked lazily, the skyline is inline storage, and the whole
    /// function allocates nothing.
    private func makeWorld(arena: CGRect) -> TowerCompanionWorld {
        let cell = probe.cellSize
        let gutter = GridConstants.spacing
        let gridWidth = CGFloat(TowerSkyline.columns) * cell
            + CGFloat(TowerSkyline.columns - 1) * gutter
        // The tower is centred in the page's horizontal padding, so its left
        // edge follows from the two widths and cannot get out of step with a
        // second measurement.
        let originX = max((arena.width - gridWidth) / 2, 0)
        // `probe.gridTopOnScreen` is in the window and so is this overlay, so
        // the difference is the grid's top in the arena. It goes negative
        // whenever the tower is scrolled up past the top of the viewport,
        // which is correct: the roofline is off screen and he stays in his
        // band.
        let gridTopY = probe.gridTopOnScreen - arena.minY

        let box = CGRect(x: 0,
                         y: topInset + TowerCompanion.topClearance,
                         width: arena.width,
                         height: max(arena.height - topInset - bottomInset
                                     - TowerCompanion.topClearance
                                     - TowerCompanion.bottomClearance, 1))

        let skyline: TowerSkyline = probe.hasMeasured
            ? TowerSkyline.build(cells: cells(), originX: originX, cellSize: cell,
                                 gutter: gutter, gridTopY: gridTopY,
                                 gridHeight: probe.gridHeight)
            : TowerSkyline()

        var landed: TowerCompanionWorld.Landing?
        if let l = landing(), probe.hasMeasured {
            let pitch = cell + gutter
            let floorY = gridTopY + probe.gridHeight
            let w = CGFloat(l.cell.columnSpan) * cell + CGFloat(l.cell.columnSpan - 1) * gutter
            let h = CGFloat(l.cell.rowSpan) * cell + CGFloat(l.cell.rowSpan - 1) * gutter
            let top = floorY - CGFloat(l.cell.row + l.cell.rowSpan) * pitch + gutter
            landed = TowerCompanionWorld.Landing(
                at: l.at,
                rect: CGRect(x: originX + CGFloat(l.cell.column) * pitch, y: top,
                             width: w, height: h))
        }

        return TowerCompanionWorld(bounds: box,
                                   skyline: skyline,
                                   slot: slot(),
                                   falling: falling(),
                                   landing: landed)
    }
}
