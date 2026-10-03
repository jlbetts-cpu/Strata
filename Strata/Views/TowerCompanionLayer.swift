import SwiftUI
#if DEBUG
import os

/// **The lab for the companion.** DEBUG only, off unless a flag is passed.
///
/// None of this head's behaviour can be photographed by asking for a picture at
/// the right moment: `simctl io screenshot` takes longer to come back than a
/// dodge lasts, and an unprompted visit to the tower is twenty to forty five
/// seconds away. So the flags make the right moment come round on demand, which
/// is the same reason `-strataLatticeLab` exists in `TowerLattice`.
///
/// `ProcessInfo` is read here rather than through `DebugHarness` because that
/// file belongs to another session today.
@MainActor
enum CompanionProbe {
    private static let args = ProcessInfo.processInfo.arguments

    private static func value(_ flag: String) -> Double? {
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return Double(args[i + 1])
    }

    /// `-strataCompanionVisits`: turn the gated tower behaviours on at all.
    /// Off in the app: see `TowerCompanionSim.visitsTheTower`.
    static let visitsTheTower = args.contains("-strataCompanionVisits")
    /// `-strataCompanionVisit <s>`: with the above, go down to the tower every s
    /// seconds instead of every twenty to forty five.
    static let visitEvery: Double? = value("-strataCompanionVisit")
    /// `-strataCompanionFall <s>`: drop a block down the head's own column
    /// every s seconds, so the dodge can be watched. The app does not wire
    /// `falling:` yet, so without this the dodge is dormant in the app.
    static let fallEvery: Double? = value("-strataCompanionFall")
    /// `-strataCompanionProbe`: the state, the position and the speed, four
    /// times a second, into `Documents/companion.log`.
    static let logs = args.contains("-strataCompanionProbe")
    /// `-strataCompanionPlain`: draw a plain disc instead of the head, with the
    /// simulation running exactly as it does. The one way to tell the cost of
    /// the 60Hz loop apart from the cost of `LivingHeadView` playing its own
    /// idle beats, which it does whether or not this feature exists.
    static let plain = args.contains("-strataCompanionPlain")
    /// `-strataCompanionStill`: hold him where he is placed, so a test can tap
    /// him; he moves faster than a screenshot-then-tap loop can follow.
    static let still = args.contains("-strataCompanionStill")

    private static let log = Logger(subsystem: "Strata", category: "companion")
    private static var lastNote: CFTimeInterval = 0
    private static var frames = 0
    private static var handle: FileHandle?
    private static var column: Int?

    // **The closest the DRAWN head ever came to each surface, in points.**
    //
    // The owner can see it turning before it touches, and this is the fourth
    // time the answer has been to measure on the glass rather than reason in the
    // code. A screenshot cannot catch the instant of a bounce, so the app keeps
    // the minimum itself, every frame, and reports it in the same units the
    // screenshot can be measured in.
    private static var nearestLeft = CGFloat.greatestFiniteMagnitude
    private static var nearestRight = CGFloat.greatestFiniteMagnitude
    private static var nearestTop = CGFloat.greatestFiniteMagnitude
    private static var nearestRoof = CGFloat.greatestFiniteMagnitude

    private static var lastBox = CGRect.null

    static func note(_ sim: TowerCompanionSim, world: TowerCompanionWorld) {
        guard logs else { return }
        frames += 1
        // **Start again whenever the room changes.** A minimum measured against
        // a box that has since moved is not a measurement of anything, and the
        // first few frames after launch run against an unsettled geometry: they
        // reported the head 215 points outside a wall it had never been near.
        if world.bounds != lastBox {
            lastBox = world.bounds
            nearestLeft = .greatestFiniteMagnitude
            nearestRight = .greatestFiniteMagnitude
            nearestTop = .greatestFiniteMagnitude
            nearestRoof = .greatestFiniteMagnitude
        }
        nearestLeft = min(nearestLeft, (sim.position.x - sim.halfWidth) - world.bounds.minX)
        nearestRight = min(nearestRight, world.bounds.maxX - (sim.position.x + sim.halfWidth))
        nearestTop = min(nearestTop, (sim.position.y - sim.halfHeight) - world.bounds.minY)
        if world.skyline.hasTower {
            let roof = world.skyline.highestTop(from: sim.position.x - sim.halfWidth,
                                                to: sim.position.x + sim.halfWidth)
            nearestRoof = min(nearestRoof, roof - (sim.position.y + sim.halfHeight))
        }
        let now = CACurrentMediaTime()
        guard now - lastNote > 0.25 else { return }
        lastNote = now
        let line = String(format: "[COMPANION] t=%.2f state=%@ x=%.1f y=%.1f speed=%.1f walls=%d frames=%d box=%.0f,%.0f,%.0f,%.0f roof=%.0f half=%.1fx%.1f near L%.1f R%.1f T%.1f roof%.1f tower=%@",
                          now, "\(sim.state)", sim.position.x, sim.position.y,
                          sim.speed, sim.wallHits, frames,
                          world.bounds.minX, world.bounds.minY, world.bounds.maxX, world.bounds.maxY,
                          world.skyline.hasTower ? world.skyline.highestTop : -1,
                          sim.halfWidth, sim.halfHeight,
                          nearestLeft, nearestRight, nearestTop,
                          nearestRoof == .greatestFiniteMagnitude ? -999 : nearestRoof,
                          world.skyline.hasTower ? "yes" : "no")
        log.notice("\(line, privacy: .public)")
        // The unified log store persists lines tens of seconds late under load
        // and a `log show` straight after a run comes back short. CLAUDE.md
        // records that, and `PerfProbe` writes a file for the same reason.
        if handle == nil,
           let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let url = dir.appendingPathComponent("companion.log")
            FileManager.default.createFile(atPath: url.path, contents: nil)
            handle = try? FileHandle(forWritingTo: url)
        }
        handle?.write(Data((line + "\n").utf8))
    }

    /// The synthetic fall, as a rect in the arena, or nil between drops.
    ///
    /// The app's own gravity, from above the band, down the column the head was
    /// over when the drop began, so the dodge it provokes is the real one.
    static func syntheticFall(at now: CFTimeInterval,
                              head: CGPoint,
                              world: TowerCompanionWorld) -> CGRect? {
        guard let every = fallEvery, every > 0 else { return nil }
        let cell = max(world.skyline.columnWidth, 60)
        let phase = now.truncatingRemainder(dividingBy: every)
        guard phase < 1.2 else { column = nil; return nil }
        if column == nil { column = world.skyline.columnIndex(atX: head.x) }
        let c = column ?? 0
        let x = world.skyline.originX + world.skyline.pitch * CGFloat(c)
        let y = world.bounds.minY - 300 + 0.5 * TowerCompanionSim.gravity * CGFloat(phase * phase)
        return CGRect(x: x, y: y, width: cell, height: cell)
    }
}
#endif

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

// MARK: - The things on the screen the head can actually hit

/// **The real, drawn objects the companion bounces off.**
///
/// The owner, 2026-09-23: "I notice the head bounces off the header but there's
/// like nothing it's actually bouncing off of. It should only bounce off actual
/// objects, like the Plan button, the wins, the Apple pill, like actual things
/// on the screen, not invisible objects."
///
/// So the head's world is the screen, and the obstacles in it are elements that
/// are really drawn. An element opts in with one line, `.companionObstacle(_:)`,
/// and its frame follows it: change a margin, move a button, and the thing the
/// head hits moves with it. Nothing here is a number anybody has to keep in
/// step, which is the whole reason it is not a table of rectangles.
///
/// **Not a `PreferenceKey`**, which was the obvious choice and does not work
/// here: preferences travel UP the view tree, and the companion is an overlay on
/// the tower's scroll view while the tally, the Plan button and the tab bar are
/// its siblings or its ancestors. A plain unobserved registry reaches all of
/// them, costs one write per layout pass, and invalidates nothing. It is the
/// same pattern and the same reason as `TowerGeometryProbe`.
@MainActor
final class CompanionObstacles {
    static let shared = CompanionObstacles()

    private var frames: [String: CGRect] = [:]
    /// Bumped by any change. The companion rebuilds its list only when this
    /// moves, so a frame of drifting costs no allocation at all.
    private(set) var revision = 0

    func set(_ id: String, _ rect: CGRect) {
        guard frames[id] != rect else { return }
        frames[id] = rect
        revision &+= 1
    }

    func remove(_ id: String) {
        if frames.removeValue(forKey: id) != nil { revision &+= 1 }
    }

    /// Fills `out` with the obstacles in the companion's own coordinates.
    /// `removeAll(keepingCapacity:)` so the array's storage is reused.
    func fill(_ out: inout [CGRect], origin: CGPoint) {
        out.removeAll(keepingCapacity: true)
        for r in frames.values where r.width > 1 && r.height > 1 {
            out.append(r.offsetBy(dx: -origin.x, dy: -origin.y))
        }
    }
}

extension View {
    /// **One line: this element is something the companion head can hit.**
    ///
    /// `id` has to be stable and unique on the screen. The frame is taken in
    /// window coordinates and the companion converts it into its own, so this
    /// works wherever in the tree the element lives.
    ///
    /// It costs one closure on each layout pass that actually moves the element,
    /// and nothing at all on a frame where it does not move.
    func companionObstacle(_ id: String) -> some View {
        onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }
        action: { CompanionObstacles.shared.set(id, $0) }
    }
}

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
    /// **The head's own height, crown to chin, and it is sized off the tower's
    /// own cell.**
    ///
    /// It was 44, the tap floor and no more, on the reasoning that the tower is
    /// the record and the head is a visitor to it. Mounted, the owner's verdict
    /// was immediate: "the mini head should be bigger, like right now it's way
    /// too small, looks unintentional." He is right, and "unintentional" is the
    /// exact fault: 44 is the size of a tab bar glyph, so a photograph of a face
    /// at 44 reads as a smudge somebody left on the screen.
    ///
    /// **0.88 of a cell** is the answer rather than a round number, because the
    /// cell is this app's unit of one object. A head just under the size of one
    /// block belongs to the same system as the thing it is floating over: you
    /// read it against the lattice and it measures out as deliberate. A head
    /// LARGER than a cell would be the biggest object on the Wins screen, which
    /// is the tower's job.
    ///
    /// At the reference cell (86.5) that is 76 points against 44, and at 76 the
    /// eyes and the mouth are all legible at arm's length. Clamped either side
    /// so a very narrow or very wide device cannot take it somewhere silly.
    static func side(forCell cell: CGFloat) -> CGFloat {
        guard cell > 1 else { return 76 }
        return min(max(cell * 0.88, 68), 92)
    }

    /// What it draws at before the tower has been measured, and what the tests
    /// size the simulation with.
    static let side: CGFloat = 76

    /// **Half the head's DRAWN width and height, as a share of `side`.**
    ///
    /// The owner, watching it: "when it bounces off the sides it should actually
    /// look like it, like right now it's bouncing but it's not even touching the
    /// side." Two things were making that true and both were here. The body was
    /// a circle of 0.42 of `side`, and a drawn face is neither square nor as
    /// wide as the frame it is laid out in; and I had added ten points of
    /// "clear air" on top, which is the kind of number that looks tidy in code
    /// and reads as an invisible fence on glass.
    ///
    /// **These are measured, not reasoned.** At `side` 76 on the simulator, the
    /// head's ink runs 58 points wide and 78 tall: 0.382 and 0.513 of the side.
    /// To re-measure after a change to the rig or to `HeadFraming`, take a
    /// screenshot and find the extent of everything under about 150 luminance in
    /// the top third of the page, which is the head and nothing else up there.
    static let inkHalfWidth: CGFloat = 0.382
    static let inkHalfHeight: CGFloat = 0.513

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
/// - The clock is `TimelineView(.animation(paused:))`, and what pauses it is the
///   head not being visible: another tab, the app in the background, a sheet
///   over the page, or Reduce Motion. It used to pause when the drift had
///   damped to nothing as well, and that shipped a parked head. Nothing about
///   the tower can wake or stop it any more, so there is no wake cost on the
///   frame a block lands, which is the 50ms gap `TowerLattice` measured.
///
/// **Reduce Motion stops the movement, not the head.** He asked for the head
/// as an option; Reduce Motion is a statement about motion. The head parks near
/// the top and the clock stops for good.
///
/// **No shadow, because he is never standing on anything.** CLAUDE.md, the
/// absolute rule: a head casts a contact shadow exactly when it is standing on
/// something, and a floating head is not. The shadow is written and it is drawn
/// only for the gated states that put him on the blocks, so in the shipped path
/// it never appears. `HeadMarker` is the other side of the same rule.
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
    /// A block in the air, in this overlay's coordinates. Only the gated dodge
    /// reads it, so the app passes nothing.
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
/// generic picks the generic up (`Runner<Cells>.Life`), and what that costs is
/// written up in CLAUDE.md under the Memories drawer, where `DrawerDetent` paid
/// for it. It cited `DrawerMetrics` until that file was deleted too, on
/// 2026-10-01.
@MainActor
private final class TowerCompanionLife {
    var sim = TowerCompanionSim(halfWidth: TowerCompanion.side * TowerCompanion.inkHalfWidth,
                                halfHeight: TowerCompanion.side * TowerCompanion.inkHalfHeight)
    var placed = false
    var lastFrame: Date?
    /// The overlay's own origin in the window, so a global drag location can
    /// become an arena coordinate without a second geometry reader inside the
    /// gesture.
    var arenaOrigin: CGPoint = .zero
    /// The obstacle list, rebuilt only when the registry's revision moves, so a
    /// frame of drifting allocates nothing.
    var obstacles: [CGRect] = []
    var obstacleRevision = -1
    /// The window's size, and the arena size it was read for. See
    /// `windowSize(for:)`: reading it per frame was measurable.
    var windowSize: CGSize = .zero
    var windowFor: CGSize = .zero
    /// The status bar's height, read with the window's size.
    var statusBar: CGFloat = 0
    // What the view draws, copied out of the simulation once a frame.
    var position: CGPoint = .zero
    var tilt: Double = 0
    /// The head's drawn height for this frame, from the tower's measured cell.
    var side: CGFloat = TowerCompanion.side
    /// Read by the shadow. Held here rather than in state so changing it costs
    /// no invalidation.
    var grounded = false
    /// The last world built for a frame. The gesture arrives between frames and
    /// has to clamp the finger against the same box and the same roofline the
    /// simulation is using, so it reads this rather than building its own.
    var world = TowerCompanionWorld(bounds: .zero)
    /// Out of a popped bubble: how far he was drawn from where the simulation
    /// put him, and when he started closing it. Read off the frame clock, not
    /// a SwiftUI animation: inside this timeline an animated offset held still
    /// and then jumped (filmed, 2026-10-02).
    var emergeFrom: CGSize = .zero
    var emergeStart: Date?
    /// Set at the pop; the clock starts on the first frame actually drawn, so
    /// a frame the timeline took to wake up is not counted as travel.
    var emergePending = false
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
    /// **Tap him and he pulls a face, the same twelve as on a photograph**
    /// (the owner, 2026-10-02: "when you click on it it will change faces just
    /// like the camera"). The same `HeadTakeDeck` as `HeadSticker`, so it
    /// never repeats the face it just made; unlike the sticker he does not
    /// keep it, because nothing is being saved: the take plays, holds, and he
    /// eases back to calm.
    @State private var take: HeadTake.Played?
    @State private var deck = HeadTakeDeck()
    /// The bubble beside the Plan button. See `CompanionDock`.
    @State private var parking = CompanionParking.shared

    var body: some View {
        GeometryReader { geo in
            let arena = geo.frame(in: .global)
            // **What stops the clock is the head not being visible, not the
            // head being still.**
            //
            // It used to include "and the drift has damped to nothing", with a
            // piece of `@State` latching that fact. Mounted on a phone, that is
            // exactly what the person sees: measured over four screenshots
            // about 0.7s apart, the head moved FOUR PIXELS in two seconds. On a
            // Wins tab with nothing landing, nothing ever woke it again. A head
            // the owner asked to float has to be in motion while it is on
            // screen, so the only gates left are the ones that mean nobody can
            // see it.
            // Parked, or flying into the bubble, nothing simulates him.
            // Under Reduce Motion the clock still runs while a finger carries
            // him, so he follows it; it is the only motion he makes there.
            let paused = (reduceMotion && !parking.dragging) || !active || !headsAwake
                || scenePhase != .active || (Self.heldStill && !parking.dragging)
                || parking.parked || parking.arriving

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
            // Sized off the tower's own cell: see `TowerCompanion.side(forCell:)`.
            // Read here rather than inside the frame loop, so the head's view
            // value is identical from one frame to the next and only the
            // transform changes.
            let side = TowerCompanion.side(forCell: probe.cellSize)
            let head = companionHead(rig: rig, side: side)

            TimelineView(.animation(paused: paused)) { context in
                // One step, then draw. Everything in `step` is arithmetic on a
                // struct the box already holds: no allocation, no formatting,
                // and nothing handed back to SwiftUI outside this closure.
                let _ = step(to: context.date, arena: arena, paused: paused)
                ZStack(alignment: .topLeading) {
                    // Only drawn when there is something under him. With the
                    // tower behaviours gated off that is never, and an ellipse
                    // blurred at zero opacity on every frame is a cost for
                    // something that cannot appear.
                    if life.grounded && !hidden { contactShadow }
                    // In the bubble, on his way in or bursting out of it, the
                    // bubble draws him.
                    if !hidden {
                        freeHead(head, side: side, now: context.date)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height,
                       alignment: .topLeading)
            }
            // The bubble grows him to this size as it pops, so it has to know
            // it, including after a relaunch that finds him parked.
            .onChange(of: side, initial: true) { _, now in parking.headSide = now }
        }
        // The bubble popped: he comes out where it was, at its size, and grows.
        .onChange(of: parking.popped) { leaveTheBubble() }
        #if DEBUG
        // `-strataDockCycle <s>`: into the bubble, then popped, every s
        // seconds, so the pop can be filmed.
        .task {
            guard let every = DebugHarness.argument("-strataDockCycle").flatMap(Double.init) else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(every))
                if !parking.parked { parkWithoutCarrying() }
                try? await Task.sleep(for: .seconds(every))
                parking.debugPop += 1
            }
        }
        #endif
        // **One element, and only because he does things now** (2026-10-02).
        // He was hidden as decoration: nothing to read, one more stop on the
        // way to a win. Once a tap gives him a face and he can be parked, he
        // is a control, and a control VoiceOver cannot reach is a feature
        // half the people who want it cannot use. One stop: his name, a
        // double-tap for a face, and the bubble as a named action.
    }

    /// `-strataCompanionStill` (DEBUG): held where he is placed.
    private static var heldStill: Bool {
        #if DEBUG
        CompanionProbe.still
        #else
        false
        #endif
    }

    /// **Him, loose on the tower**: where the simulation put him, the drag, the
    /// tap for a face, and the one VoiceOver element. Its own function because
    /// inline it took the body past what the type-checker will solve, the same
    /// ceiling and the same fix `block(for:)` records on the map.
    private func freeHead(_ head: some View, side: CGFloat, now: Date) -> some View {
        let emerge = emergence(at: now)
        return head
            .rotationEffect(.degrees(life.tilt))
            .offset(x: life.position.x - side / 2 + emerge.width,
                    y: life.position.y - side / 2 + emerge.height)
            .gesture(drag)
            // The system's own tap, beside the drag rather than worked out
            // from it: it has the platform's slop and timing, and a drag that
            // moves cancels it.
            .simultaneousGesture(TapGesture().onEnded { changeFace() })
            .accessibilityElement()
            .accessibilityLabel("Your head")
            .accessibilityHint("Double-tap for a new face.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { changeFace() }
            .accessibilityAction(named: "Park in the bubble") { parkWithoutCarrying() }
            // Taken back from the bubble in one frame. SwiftUI's default
            // insertion faded him in over 150ms after the pop (filmed).
            .transition(.identity)
    }

    /// The bubble without the drag, for VoiceOver: he goes straight in.
    private func parkWithoutCarrying() {
        withAnimation(GridConstants.motionSnappy) { parking.parked = true }
        parking.landed += 1
        HapticsEngine.success()
    }

    /// The head itself, or a plain disc under `-strataCompanionPlain`.
    @ViewBuilder
    private func companionHead(rig: HeadRig, side: CGFloat) -> some View {
        #if DEBUG
        if CompanionProbe.plain {
            Circle().fill(AppColors.inkPrimary.opacity(0.85))
                .frame(width: side, height: side)
                .contentShape(Circle())
        } else {
            LivingHeadView(rig: rig, side: side, liveliness: .calm, take: take)
                .frame(width: side, height: side)
                .contentShape(Circle())
        }
        #else
        LivingHeadView(rig: rig, side: side, liveliness: .calm, take: take)
            .frame(width: side, height: side)
            .contentShape(Circle())
        #endif
    }

    /// **Only while he is standing on a block.** CLAUDE.md: the heads cast a
    /// contact shadow, and they cast one exactly when they are standing on
    /// something. In the air there is nothing under him, so there is nothing
    /// to cast onto. A soft ellipse under the chin, light rather than heavy,
    /// the same shape `HeadMarker` uses on the ground.
    private var contactShadow: some View {
        Ellipse()
            .fill(Color.black.opacity(TowerCompanion.shadowOpacity))
            .frame(width: life.side * 0.66, height: life.side * 0.15)
            .blur(radius: 2.5)
            .offset(x: life.position.x - life.side * 0.33,
                    y: life.position.y + life.side * 0.42)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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
                // Carrying him brings the bubble; over it, it swells.
                if !parking.dragging {
                    withAnimation(GridConstants.motionSnappy) { parking.dragging = true }
                }
                let over = parking.isOver(value.location)
                if over != parking.over {
                    parking.over = over
                    if over { HapticsEngine.tick() }
                }
                // **The world is handed in, so the clamp and the finger are the
                // same write.** It used to be clamped afterwards by the
                // simulation's own resolve on the next tick, which meant two
                // things were deciding where the head was on the same frames and
                // at the edges they disagreed. That was the jitter.
                if life.sim.state == .held {
                    life.sim.touch(.moved, at: p, in: life.world)
                } else {
                    life.sim.touch(.began, at: p, in: life.world)
                }
            }
            .onEnded { value in
                let p = arenaPoint(value.location)
                // UIKit's own projection, over roughly a quarter of a second of
                // deceleration, turned into points a second. This is the only
                // velocity the throw uses; nothing is measured during the drag.
                let v = CGVector(
                    dx: (value.predictedEndTranslation.width - value.translation.width) / 0.25,
                    dy: (value.predictedEndTranslation.height - value.translation.height) / 0.25)
                let parks = parking.over
                parking.over = false
                // Let go over the bubble: he stops where he is and flies in.
                life.sim.touch(.ended, at: p, velocity: parks ? .zero : v, in: life.world)
                if parks {
                    // From where he is drawn, not from the finger: the grab
                    // keeps him off the finger by wherever it took hold of
                    // him, and starting from the finger jumped him (filmed).
                    let drawn = CGPoint(x: life.arenaOrigin.x + life.position.x,
                                        y: life.arenaOrigin.y + life.position.y)
                    parking.beginArrival(from: drawn, side: life.side)
                } else {
                    withAnimation(GridConstants.motionSnappy) { parking.dragging = false }
                }
            }
    }

    /// The bubble is drawing him, so the tower does not.
    private var hidden: Bool {
        parking.parked || parking.arriving || parking.releasing
    }

    /// The bubble's centre in this overlay's coordinates.
    private var dockCentre: CGPoint {
        CGPoint(x: parking.dockFrame.midX - life.arenaOrigin.x,
                y: parking.dockFrame.midY - life.arenaOrigin.y)
    }

    /// **Out of the popped bubble**: taken from the bubble at its centre and at
    /// his own size, then clear of it as he starts to float again.
    ///
    /// The bubble is an obstacle he keeps off, so the simulation puts him just
    /// clear of it rather than inside it. He is drawn from the bubble's centre
    /// anyway, offset back to it, and the offset runs out as he grows: filmed
    /// without it, his first frame was already beside the bubble, which read
    /// as a jump rather than a pop.
    private func leaveTheBubble() {
        let centre = dockCentre
        life.sim.place(in: life.world, at: centre,
                       velocity: CGVector(dx: CGFloat.random(in: -60...60), dy: 90))
        // The bubble has already grown him to his own size on its spot (see
        // `CompanionDock.burst`); he only has to move clear of it.
        life.emergeFrom = CGSize(width: centre.x - life.sim.position.x,
                                 height: centre.y - life.sim.position.y)
        life.emergeStart = nil
        life.emergePending = !reduceMotion
    }

    /// How far from the simulation's spot to draw him this frame: all of
    /// `emergeFrom` at the pop, none of it `emergeTime` later, eased out.
    private func emergence(at now: Date) -> CGSize {
        if life.emergePending {
            life.emergePending = false
            life.emergeStart = now
        }
        guard let start = life.emergeStart else { return .zero }
        let p = min(max(now.timeIntervalSince(start) / Self.emergeTime, 0), 1)
        if p >= 1 { life.emergeStart = nil; return .zero }
        let left = pow(1 - p, 3)
        return CGSize(width: life.emergeFrom.width * left,
                      height: life.emergeFrom.height * left)
    }

    private static var emergeTime: Double { 0.32 }

    /// Exactly `HeadSticker.changeFace`: the next of the faces this head has,
    /// never the one it just made, played in a random direction.
    private func changeFace() {
        let available = HeadTake.available(faces: rig.takeFaces, hasShut: rig.shut != nil,
                                           reduceMotion: reduceMotion)
        guard let next = deck.next(from: available) else { return }
        HapticsEngine.tick()
        #if DEBUG
        NSLog("[strata-head] tower take \(next.id.rawValue)")
        #endif
        take = HeadTake.Played(id: next.id, direction: Bool.random() ? 1 : -1,
                               nonce: (take?.nonce ?? 0) + 1)
    }

    /// **The window's own size**, which is the only way an overlay on the scroll
    /// view can know where the screen's edges are.
    ///
    /// **Cached, and that is a measurement.** It was read from
    /// `UIApplication.shared.connectedScenes` on every frame, walking the
    /// scenes and their windows and asking each one whether it is the key
    /// window, sixty times a second. With `-strataPerfProbe` over 30 seconds of
    /// the Wins tab that cost 6 frame gaps over 50ms against 2 for the same run
    /// with the head switched off, and a worst gap of 250ms against 99. The
    /// window's size changes on a rotation and on nothing else, so it is read
    /// when the arena's own geometry changes and not again.
    private func windowSize(for arena: CGRect) -> CGSize {
        if life.windowFor == arena.size, life.windowSize != .zero { return life.windowSize }
        life.windowFor = arena.size
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            if let w = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
                life.windowSize = w.bounds.size
                life.statusBar = w.safeAreaInsets.top
                return life.windowSize
            }
        }
        return life.windowSize
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
        guard arena.origin.x.isFinite, arena.origin.y.isFinite,
              arena.width.isFinite, arena.height.isFinite else { return false }
        life.arenaOrigin = CGPoint(x: arena.minX, y: arena.minY)
        let world = makeWorld(arena: arena)
        life.world = world

        // The drawn size and the simulation's radius are one number, followed
        // live: the cell arrives a layout pass after the first frame, and a head
        // whose body stayed 44 wide while it drew at 76 would clip a quarter of
        // itself through every wall.
        life.side = TowerCompanion.side(forCell: probe.cellSize)
        life.sim.halfWidth = life.side * TowerCompanion.inkHalfWidth
        life.sim.halfHeight = life.side * TowerCompanion.inkHalfHeight

        if !life.placed, arena.width > 1, arena.height > 1 {
            life.placed = true
            #if DEBUG
            if let every = CompanionProbe.visitEvery { life.sim.visitInterval = every...every }
            // **The gate.** Dropping to the tower, hopping and dodging are off
            // in the app (owner, 2026-09-23: "I would focus on just making it
            // floating for now"). `-strataCompanionVisits` is the only thing
            // that turns them on, and it is DEBUG only.
            life.sim.visitsTheTower = CompanionProbe.visitsTheTower
            #endif
            life.sim.place(in: world)
            #if DEBUG
            // Held mid-screen, clear of the status bar, where a test can tap.
            if CompanionProbe.still {
                life.sim.place(in: world, at: CGPoint(x: arena.width / 2, y: arena.height * 0.4))
            }
            #endif
            life.lastFrame = now
        }
        life.sim.reduceMotion = reduceMotion

        let elapsed = life.lastFrame.map { now.timeIntervalSince($0) } ?? TowerCompanionSim.tick
        life.lastFrame = now
        // Reduce Motion still needs one call: that is what parks him.
        if !paused || reduceMotion {
            life.sim.update(world, elapsed: elapsed)
        }
        guard life.sim.position.x.isFinite, life.sim.position.y.isFinite,
              life.sim.tilt.isFinite else { return false }
        life.position = life.sim.position
        life.tilt = life.sim.tilt
        // Resting counts: under Reduce Motion he stands on the tower, and a
        // head standing on something casts its contact shadow.
        life.grounded = (life.sim.state == .hopping || life.sim.state == .dodging
                         || life.sim.state == .resting)
            && life.sim.onSurface(world)

        // **Nothing published, ever.** There used to be a piece of `@State`
        // here latching "he has settled", which is what stopped the clock and
        // shipped a parked head. The clock's gates are all environment and
        // caller values now, read in the body above, so this whole path writes
        // to the unobserved box and to nothing else.
        #if DEBUG
        // Only on frames the simulation actually ran. A paused frame still
        // draws, and noting one recorded the head at the position it was placed
        // at under the PREVIOUS geometry, which read as 36 points outside the
        // top of the screen on a head that had never been there.
        if !paused { CompanionProbe.note(life.sim, world: world) }
        #endif
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

        // **The arena is the WHOLE SCREEN, and nothing invisible bounds it.**
        //
        // The owner: "I notice the head bounces off the header but there's like
        // nothing it's actually bouncing off of... not invisible objects." This
        // view is an overlay on the tower's scroll view, so its own frame stops
        // where the header ends and where the tab bar begins, and a head bounded
        // by it turns around on two lines a person cannot see. So the box is the
        // window, expressed in this view's coordinates, and the header and the
        // tab bar earn their collisions by being registered as obstacles like
        // everything else.
        // Top: the window's own top edge, so the head passes BETWEEN the tally
        // and the Plan button and up into the empty part of the header, rather
        // than turning round on the header's baseline where there is nothing.
        // Bottom: the scroll view's own bottom edge, which is where the tab bar
        // starts. That is a real object's visible top edge; the bar itself is
        // system chrome with no view to hang `.companionObstacle` on, and it is
        // the one surface here not registered as an obstacle.
        //
        // **Top: the bottom of the status bar** (2026-10-02). It was the
        // window's own top, so he floated up behind the clock and the Dynamic
        // Island, which is exactly the strip where iOS takes a tap for itself:
        // filmed, taps on him there reached nothing. The status bar is a
        // visible object, so turning on its edge keeps the owner's rule (no
        // invisible walls), and every tap on him now lands.
        let win = windowSize(for: arena)
        let ceiling = life.statusBar
        let box = CGRect(x: -arena.minX, y: -arena.minY + ceiling,
                         width: max(win.width, arena.width),
                         height: arena.minY + arena.height - ceiling)

        let skyline: TowerSkyline = probe.hasMeasured
            ? TowerSkyline.build(cells: cells(), originX: originX, cellSize: cell,
                                 gutter: gutter, gridTopY: gridTopY,
                                 gridHeight: probe.gridHeight,
                                 // The radius a block is really drawn with, so
                                 // the head meets the flat part of its top and
                                 // not the air beside a rounded corner.
                                 cornerInset: GridConstants.blockCornerRadius(forCell: cell))
            : TowerSkyline()

        if life.obstacleRevision != CompanionObstacles.shared.revision {
            life.obstacleRevision = CompanionObstacles.shared.revision
            CompanionObstacles.shared.fill(&life.obstacles,
                                           origin: CGPoint(x: arena.minX, y: arena.minY))
        }

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

        var inFlight = falling()
        #if DEBUG
        // `-strataCompanionFall <s>`. The app does not pass `falling:` yet, so
        // this is the only way to see the dodge; it is also how the dodge was
        // verified on a phone rather than only in a test.
        if inFlight == nil {
            var world = TowerCompanionWorld(bounds: box, skyline: skyline)
            world.slot = slot()
            inFlight = CompanionProbe.syntheticFall(at: CACurrentMediaTime(),
                                                    head: life.sim.position,
                                                    world: world)
        }
        #endif

        return TowerCompanionWorld(bounds: box,
                                   skyline: skyline,
                                   slot: slot(),
                                   falling: inFlight,
                                   landing: landed,
                                   obstacles: life.obstacles)
    }
}
