import CoreGraphics
import Foundation

// MARK: - The world the companion is given

/// **Everything the companion is allowed to know about the Wins screen.**
///
/// The companion never reaches into `TowerViewModel`. It is handed this
/// value, once a frame, and that is the whole of its knowledge: a box it may
/// move in, the tops of the four columns, the block being placed, and a block
/// in the air. Two reasons, and the second is the one that matters:
///
/// 1. The simulation stays pure, so it can be tested without a container, a
///    view or a simulator (`TowerCompanionTests`).
/// 2. Reading the tower's model from inside the companion would make the
///    companion a dependency of the tower's own body. CLAUDE.md is explicit
///    about what that costs: `towerScrollOffset` in `AnimatedBlockView.==`
///    ran 884 block bodies a second over one fling, and 0 without it.
///
/// **Coordinates are the arena's**, origin top left, y down, points. The
/// arena is whatever view the companion is laid over; `TowerCompanionLayer`
/// measures it and converts the tower's window geometry into it.
nonisolated struct TowerCompanionWorld: Equatable, Sendable {

    /// One block's place in the tower's grid, in the tower's own numbers.
    ///
    /// Deliberately not `PlacedBlock`. The caller maps into this, lazily, so
    /// that handing the companion a tower costs no allocation: see
    /// `TowerSkyline.build`.
    nonisolated struct Cell: Equatable, Sendable {
        var column: Int
        var row: Int
        var columnSpan: Int
        var rowSpan: Int

        init(_ column: Int, _ row: Int, _ columnSpan: Int, _ rowSpan: Int) {
            self.column = column
            self.row = row
            self.columnSpan = columnSpan
            self.rowSpan = rowSpan
        }
    }

    /// A block that just hit the tower.
    ///
    /// The owner, 2026-09-23: "it will react to things happening, like a
    /// block flying near him or placing a block."
    nonisolated struct Landing: Equatable, Sendable {
        /// The moment of impact. The companion remembers the last one it
        /// answered and compares on this, so handing it the same landing on
        /// every frame of the ripple costs nothing and startles it once.
        /// `LatticeRipple.started` is exactly this value.
        var at: Date
        /// Where the block came to rest, in arena points.
        var rect: CGRect

        init(at: Date, rect: CGRect) {
            self.at = at
            self.rect = rect
        }
    }

    /// Where the head may go. Already clear of the header and the tab bar:
    /// the caller insets it, because the caller is the only one that knows
    /// how tall its own chrome is.
    var bounds: CGRect

    /// **Where the head starts, and nothing else.**
    ///
    /// This was a band near the top that the head was CLAMPED into, which is
    /// what the owner saw: "the head, I notice from the build I'm looking at,
    /// only stays near the top, never bouncing on the blocks below or anything,
    /// remaining on the same plane. I would prefer it to interact with all the
    /// elements." He is right, and a band is a plane by construction. The whole
    /// of `bounds` is the head's world now and the tower is an object in it; all
    /// this does is say where a head that has just appeared should be put.
    var opening: ClosedRange<CGFloat>

    /// The tops of the tower's columns, for hopping along.
    var skyline: TowerSkyline

    /// **The next slot, and the block being drawn into it.**
    ///
    /// The one rectangle on this screen the head may never cover. Logging a
    /// win is the fastest thing in the app (CLAUDE.md, the rule that settles
    /// arguments) and a head sitting on the slot would be a toy getting in
    /// the way of the product.
    var slot: CGRect?

    /// A block in the air, if one is falling. Non nil from the moment the
    /// drop is queued to the moment it lands.
    var falling: CGRect?

    /// The last landing, or nil on a screen where nothing has landed.
    var landing: Landing?

    /// **The drawn objects on the screen, in the companion's coordinates.**
    ///
    /// The tally, the Plan button, the tab bar: things the person can see. The
    /// head bounces off these and off the blocks, and off nothing else. See
    /// `CompanionObstacles`.
    var obstacles: [CGRect] = []

    init(bounds: CGRect,
         opening: ClosedRange<CGFloat>? = nil,
         skyline: TowerSkyline = TowerSkyline(),
         slot: CGRect? = nil,
         falling: CGRect? = nil,
         landing: Landing? = nil,
         obstacles: [CGRect] = []) {
        self.bounds = bounds
        self.skyline = skyline
        self.slot = slot
        self.falling = falling
        self.landing = landing
        self.obstacles = obstacles
        if let opening {
            self.opening = opening
        } else {
            // The top third of the box: somewhere sensible for a head that
            // has just appeared to be, and nothing more than that.
            let depth = min(bounds.height * 0.34, 220)
            let top = bounds.minY
            self.opening = top...(top + max(depth, 1))
        }
    }

}

// MARK: - The tops of the columns

/// **The tower's roofline, as four numbers.**
///
/// Inline storage, not an array, because this is rebuilt on every frame the
/// companion runs and an array would be a heap allocation sixty times a
/// second. `SIMD4<Double>` is four doubles in a register.
///
/// Four because the tower has four columns (`GridConstants.columnCount`).
/// `TowerCompanionTests.theGridIsStillFourColumnsWide` fails loudly if that
/// ever changes, rather than this quietly dropping a column.
nonisolated struct TowerSkyline: Equatable, Sendable {
    static let columns = 4

    /// Left edge of column 0, in arena x.
    var originX: CGFloat = 0
    /// One cell's width. The tower's `colW`.
    var columnWidth: CGFloat = 0
    /// The tower's gutter, which is `GridConstants.spacing`.
    var gutter: CGFloat = 0
    /// The top of each column in arena y. `floorY` where a column is empty.
    var tops: SIMD4<Double> = SIMD4<Double>(repeating: 0)
    /// The ground row's bottom edge: where an empty column's "top" is.
    var floorY: CGFloat = 0
    /// False on an empty tower, which is the one case with nothing to hop on.
    var hasTower: Bool = false
    /// **How far in from a column's edge the block's flat top begins.**
    ///
    /// A block is drawn into its whole cell but it has a corner radius, so its
    /// top edge is flat only between the corners. Colliding on the cell's full
    /// width means a head can meet a surface where the block has curved away,
    /// which is the "invisible boundary" case at a column's edge. The caller
    /// passes `GridConstants.blockCornerRadius(forCell:)`, which is the number
    /// the block is actually drawn with.
    var cornerInset: CGFloat = 0

    /// **Builds the roofline from the tower's own grid numbers.**
    ///
    /// `cells` is any sequence, so the caller can pass
    /// `placedBlocks.lazy.map { ... }` and this walks it without materialising
    /// an array. That is the whole reason it is generic.
    ///
    /// The tower is bottom anchored: row 0 is the ground row and a block
    /// occupies `row ..< row + rowSpan`. A block's top edge inside the grid is
    /// `gridHeight - (row + rowSpan) * (cell + gutter) + gutter`, which is
    /// `GridConstants.blockFrame` put through `MainAppView.flippedY`. Getting
    /// this off by one gutter would stand the head a gutter inside the block
    /// it is meant to be standing on, so it is written out rather than
    /// approximated.
    static func build<C: Sequence>(cells: C,
                                   originX: CGFloat,
                                   cellSize: CGFloat,
                                   gutter: CGFloat,
                                   gridTopY: CGFloat,
                                   gridHeight: CGFloat,
                                   cornerInset: CGFloat = 0) -> TowerSkyline
    where C.Element == TowerCompanionWorld.Cell {
        let pitch = cellSize + gutter
        let floorY = gridTopY + gridHeight
        var reach = SIMD4<Int32>(repeating: 0)
        var any = false
        for cell in cells {
            any = true
            let first = max(0, cell.column)
            let last = min(columns - 1, cell.column + cell.columnSpan - 1)
            guard first <= last else { continue }
            let rows = Int32(max(0, cell.row + cell.rowSpan))
            for c in first...last where reach[c] < rows { reach[c] = rows }
        }
        var tops = SIMD4<Double>(repeating: Double(floorY))
        for c in 0..<columns where reach[c] > 0 {
            tops[c] = Double(floorY - CGFloat(reach[c]) * pitch + gutter)
        }
        // **Nothing non finite gets in.** One NaN here becomes a NaN position,
        // and a NaN position is a hard crash the moment SwiftUI is handed it.
        guard floorY.isFinite, originX.isFinite, cellSize.isFinite, cellSize > 0,
              gutter.isFinite else { return TowerSkyline() }
        let inset = cornerInset.isFinite ? min(max(cornerInset, 0), cellSize / 3) : 0
        return TowerSkyline(originX: originX,
                            columnWidth: cellSize,
                            gutter: gutter,
                            tops: tops,
                            floorY: floorY,
                            hasTower: any,
                            cornerInset: inset)
    }

    var pitch: CGFloat { columnWidth + gutter }

    func columnIndex(atX x: CGFloat) -> Int {
        // **`Int(_:)` traps on a NaN or an infinity**, and geometry arrives from
        // SwiftUI before a layout has happened. One non finite number anywhere
        // upstream turns this from a wrong answer into a crash on launch, which
        // is exactly what it did.
        guard pitch > 0, x.isFinite, originX.isFinite else { return 0 }
        let raw = ((x - originX) / pitch).rounded(.down)
        guard raw.isFinite else { return 0 }
        return min(max(Int(raw), 0), Self.columns - 1)
    }

    func top(ofColumn c: Int) -> CGFloat {
        CGFloat(tops[min(max(c, 0), Self.columns - 1)])
    }

    func centreX(ofColumn c: Int) -> CGFloat {
        let i = min(max(c, 0), Self.columns - 1)
        return originX + pitch * CGFloat(i) + columnWidth / 2
    }

    /// The surface directly under a point. A step function, because the
    /// tower is: the head stands on whichever column it is over.
    func surfaceY(atX x: CGFloat) -> CGFloat {
        top(ofColumn: columnIndex(atX: x))
    }

    /// **The highest roof under a span**, which is what supports a head rather
    /// than a point. Dragging the head along the tower has to rest it on the
    /// tallest column its face covers, or a cheek sinks into the column next
    /// door a moment before the centre reaches it.
    func highestTop(from x0: CGFloat, to x1: CGFloat) -> CGFloat {
        let a = columnIndex(atX: min(x0, x1) + cornerInset)
        let b = columnIndex(atX: max(x0, x1) - cornerInset)
        guard b >= a else { return top(ofColumn: a) }
        var best = top(ofColumn: a)
        if b > a { for c in (a + 1)...b { best = min(best, top(ofColumn: c)) } }
        return best
    }

    /// The highest roof on the tower, which is the thing the drift band has
    /// to stay clear of on a tall tower.
    var highestTop: CGFloat {
        var best = CGFloat(tops[0])
        for c in 1..<Self.columns { best = min(best, CGFloat(tops[c])) }
        return best
    }
}

// MARK: - The simulation

/// **A head that floats on the Wins screen, as a pure simulation.**
///
/// The owner, 2026-09-23, asked for a companion that floats near the top,
/// bounces off the walls, can be moved with a finger and reacts to a block
/// landing, and then, having seen it: "I would focus on just making it floating
/// for now, bouncing around, and polishing it to the max."
///
/// **So what ships is the float, and only the float.** `drifting`, `startled`,
/// `held`, `thrown`, and `resting` for Reduce Motion. Dropping to the tower,
/// hopping along the blocks and getting out from under a falling one are all
/// built, all tested, and all unreachable behind `visitsTheTower`, which is
/// false. That is the gate; nothing in the app turns it on.
///
/// **No SwiftUI in here, on purpose.** Everything that could be wrong about a
/// companion is arithmetic: does it leave the box, does it stand inside a block,
/// does it ever stop, does the speed have any variety in it. Those are questions
/// a test answers in milliseconds, and this one cannot be photographed at all:
/// it is in motion and `simctl io screenshot` samples at about 3Hz.
///
/// **A fixed step, and a positional resolve.** `update` accumulates real time
/// and runs whole ticks of `Self.tick`, so the motion is the same at 60Hz and at
/// 120Hz and is reproducible from a seed. Every wall and the slot are resolved
/// by MOVING the head, not by reversing its velocity and hoping: at 20,000
/// points a second a velocity only bounce walks straight through a wall between
/// two ticks, and this cannot.
///
/// **It does not stop while it is on screen.** `docs/design-system-future.md`
/// says "Nothing loops. Nothing idles", and the first build obeyed that by
/// damping the drift to nothing and sleeping. Measured on a phone: four pixels
/// of movement in two seconds, and the owner asked whether the feature worked.
/// The doc's rule is about decoration arriving with a screen; a float the person
/// switched on is a sustained motion by definition. What stops the clock is the
/// head being invisible, and that is a gate in `TowerCompanionLayer`.
///
/// The whole API is three calls: `init`, `update`, and `touch` when a finger is
/// on it.
nonisolated struct TowerCompanionSim {

    /// The states the owner named, plus the two that join them up.
    enum State: Equatable, Sendable {
        /// Still, asking for no frames.
        case resting
        /// Floating near the top, bouncing off the walls.
        case drifting
        /// A finger has it.
        case held
        /// Let go with speed behind it.
        case thrown
        /// Something happened nearby and it flinched.
        case startled
        /// On its way down to the tower.
        case descending
        /// On the blocks, jumping along the tops.
        case hopping
        /// Getting out from under a block that is falling.
        case dodging
        /// On its way back up to the drift band.
        case returning
    }

    /// What a finger is doing.
    enum Touch: Equatable, Sendable { case began, moved, ended }

    // MARK: Tunables
    //
    // Local rather than read from `GridConstants`, because this type is
    // `nonisolated` and most of `GridConstants` is not. Where a number has a
    // twin over there it says so and must be kept in step.

    /// 60Hz. The step is fixed so two devices and a test agree.
    static let tick: TimeInterval = 1.0 / 60.0
    /// The most ticks one `update` will run. A stall, a scroll that starved
    /// the main thread, or the first frame after the tab appears hands us a
    /// huge elapsed; without this the head crosses the screen in one frame.
    static let maxTicks = 4

    /// **The same gravity the blocks fall at** (`GridConstants.dropGravity`,
    /// 4200). One screen, one world, one g: a head that fell at half the rate
    /// of the block beside it would read as floating rather than as jumping.
    static let gravity: CGFloat = 4200

    /// Per tick, and only for the GATED behaviours: a dodge and a return are
    /// both going somewhere on purpose, so they bleed off rather than float. The
    /// float itself has real drag instead. See `drag`.
    static let driftDamping: CGFloat = 0.985
    static let airDamping: CGFloat = 0.999
    /// The slot pushes back at this much. Walls have their own, lossier and
    /// scattered: see `bounce(alongX:into:)`. The tower's roof gives least of
    /// all, because a head bouncing off a block reads as rubber.
    static let wallRestitution: CGFloat = 0.62
    static let groundRestitution: CGFloat = 0.30

    /// **The float is a traverse, integrated, not a path and not a wander.**
    ///
    /// Four builds got here and each one was wrong in a way you could only see
    /// on glass. It damped to nothing and slept (four pixels in two seconds). It
    /// held a constant cruise speed on a curving heading, and the owner's note
    /// was "the animations do not feel natural at all". Then it became a body in
    /// a wandering current, which looked like weight and then lived on one side
    /// of the screen: measured over 24 runs of four minutes, up to 35 seconds at
    /// a time against one edge and a quietest three seconds that moved him 0.4
    /// points. That is a stopped head again.
    ///
    /// The owner's own reference is the right one: "it should act kinda like the
    /// DVD logo, like bounce from side to side. I mean a bit more freedom, but
    /// there shouldn't be like some sort of structure to the movement."
    ///
    /// So: a long traverse at a speed it holds, turned slowly and unpredictably
    /// by a force that acts ONLY sideways, and stopped by nothing but the walls.
    /// A sideways force does no work along the path, so it can never stall him
    /// and it can never hold him anywhere. Every other force is gone: no pull to
    /// the middle, no cushion at the edges, no home position, nothing with a
    /// shape for the eye to learn.

    /// The speed a traverse holds, in points a second. 30 crosses a 393 point
    /// screen in thirteen seconds: one long deliberate pass, which is the
    /// reading of "premium tool, not a tacky game" at this scale.
    static let cruise: ClosedRange<Double> = 26...34
    /// How firmly the cruise is restored, per second, coming up from a bounce
    /// and coming down from a throw. Up is gentle so a bounce reads as a bounce
    /// and not a rubber band; down is firmer or a hard flick spends five seconds
    /// crossing the screen.
    static let governorUp: CGFloat = 0.7
    static let governorDown: CGFloat = 2.2

    /// How long the sideways push holds its direction, in seconds, and how hard
    /// it pushes. Six seconds is a turn that takes as long as the traverse it is
    /// bending, so the path is a long curve rather than a scribble; the clamp is
    /// what stops a run of the random walk from spinning him.
    static let gustTau: Double = 6.0
    static let gustStrength: CGFloat = 11
    static let maxLateral: CGFloat = 26

    /// **How far off an axis a heading must stay**, in radians: about twenty
    /// two degrees.
    ///
    /// A lossy bounce takes a bite out of the component ALONG the wall every
    /// time, so without this a traverse converges on a perfectly horizontal or
    /// vertical line, which is the one path a person learns in seconds. Swept
    /// over 40 runs of three minutes against four tower shapes: at nine degrees
    /// the worst run covered 56% of the screen's width, at twenty two the tenth
    /// percentile is 100% on every shape. A heading that always carries real
    /// travel on both axes is also what walks the head out of a gap between two
    /// tall columns instead of ping ponging in it.
    static let axisFloor: Double = 0.38

    /// The ceiling on the float, in points a second. A taste limit, not a
    /// physical one: past this the head stops reading as drifting.
    static let maxDrift: CGFloat = 54

    /// **A wall bounce loses a little energy and scatters.**
    ///
    /// A perfect mirror is the single most artificial thing a bouncing object
    /// can do: equal angles, same speed, for ever. This keeps most of the speed,
    /// because the head has to carry on across the screen afterwards, scrubs the
    /// component along the wall, and knocks the outgoing direction a few degrees
    /// off so no two bounces off the same wall are alike. The governor then
    /// takes it back to the cruise over the next second or so, which is the part
    /// you read as weight.
    static let bounceRestitution: CGFloat = 0.82
    static let bounceFriction: CGFloat = 0.94
    /// Radians. About seven degrees of scatter at most.
    static let bounceScatter: Double = 0.12
    /// Below this approach speed there is no bounce, only contact. See
    /// `bounce(alongX:into:)`.
    static let contactSpeed: CGFloat = 4

    /// Air kept between the head and the top of the tower, whether it is being
    /// dragged or thrown. Enough that the head reads as ABOVE the blocks rather
    /// than resting on them, which is a different claim (CLAUDE.md: a head casts
    /// a contact shadow exactly when it is standing on something, and this one
    /// never is).
    static let towerClearance: CGFloat = 6

    /// Below this much overlap there is no collision. See `towerEscape`.
    static let contactEpsilon: CGFloat = 0.05

    /// **How strongly a head below the tower's tallest roof rises**, in points a
    /// second squared, and over what depth it reaches full strength. Zero above
    /// the tower, so it is not a pull toward the top of the screen.
    ///
    /// Swept over 40 runs of three minutes against five tower shapes, reading
    /// both things it trades between. At 0 the worst run covered 16% of the
    /// screen's width, trapped in a gap between two tall columns for the whole
    /// three minutes. At 26 the worst run covered 59% but the head only ever got
    /// 110 points below the tallest roof, which is hovering over the tower
    /// rather than meeting it. 16 is the knee: worst run 76%, and it still gets
    /// 203 points down among the blocks, with 2.3 seconds a run actually in
    /// contact with them.
    static let wellLift: CGFloat = 16
    static let wellReach: CGFloat = 120


    /// The hardest a flick can throw it. A cap, because the projection from a
    /// finger has no ceiling of its own and a head crossing the screen in one
    /// frame is not a throw, it is a teleport.
    static let maxThrow: CGFloat = 1800

    /// **How long between visits to the tower, unprompted.**
    ///
    /// The owner: "occasionally he can drop down and jump along the tops of the
    /// blocks." The first build only went down on a landing, so on the screen
    /// the Wins tab actually is most of the time, which is a tower with nothing
    /// arriving, it never once happened. Twenty to forty five seconds is rare
    /// enough to be a surprise and often enough to be a feature.
    static let visitEvery: ClosedRange<Double> = 20...45

    // **Everything from here to `noticeRadius` serves the GATED behaviours** and
    // is unreachable while `visitsTheTower` is false. Kept because the code is
    // sound and measured, not because it runs.

    /// A hop clears 68 points at the top of its arc, which is most of a cell.
    /// A hop onto a column more than that above it is not attempted; it
    /// crosses to one it can reach instead.
    static let hopUp: CGFloat = 760
    static let hopSide: CGFloat = 230
    static let hopGap: ClosedRange<Double> = 0.5...1.1
    static let hopsPerVisit: ClosedRange<Double> = 2...5

    /// **How often a landing ALSO sends it down to the tower.** Lower than it
    /// was, because the visit timer above now carries the behaviour on its own
    /// and a head that went down on a third of your wins would be a thing you
    /// have to look past to see your tower.
    static let visitChance: Double = 0.2

    /// A flinch is short. Anything longer reads as a performance.
    static let startleHold: TimeInterval = 0.22
    static let startleSpeed: CGFloat = 130
    /// How near a falling block has to pass before it is noticed.
    static let noticeRadius: CGFloat = 130

    /// The clear air it wants on either side of a falling block, and how hard
    /// it moves to get there.
    static let dodgeMargin: CGFloat = 18
    static let escapeSpeed: CGFloat = 460

    /// **The head leans into its movement, and the lean LAGS it.**
    ///
    /// A tilt computed straight off the velocity arrives on the same frame the
    /// velocity does, which is the thing that makes an object read as a sticker
    /// being slid about: it has no mass of its own. This is a damped spring
    /// toward the lean the current speed wants, under damped a little, so the
    /// head rolls into a turn, overshoots slightly coming out of a bounce and
    /// settles. Bounce is earned here: `apple-design.md` allows it exactly when
    /// momentum caused the motion, and hitting a wall is momentum.
    ///
    /// Seven degrees, not twelve. At twelve a 76 point head is visibly cocked
    /// over and it reads as a character; at seven you read it as weight.
    static let maxTilt: Double = 7
    static let tiltPerPoint: Double = 0.16
    static let tiltStiffness: Double = 26
    static let tiltDamping: Double = 7.6

    // MARK: State

    private(set) var state: State = .drifting
    private(set) var position: CGPoint = .zero
    private(set) var velocity: CGVector = .zero
    /// Degrees. A lean into the direction of travel, for the view.
    private(set) var tilt: Double = 0
    /// **True only under Reduce Motion.**
    ///
    /// It used to mean "the drift has died away", and the layer stopped its
    /// clock on it. That is what shipped a parked head. A floating head is in
    /// motion by definition, so while the Wins tab is on screen the clock runs;
    /// what stops it is the head not being visible at all (another tab, the
    /// app in the background, a sheet over the page) or Reduce Motion, and
    /// those are all gates in the layer rather than facts about the drift.
    private(set) var isAtRest = false

    /// **Half the head's DRAWN width and height, in points.**
    ///
    /// The owner, 2026-09-23, watching it: "when it bounces off the sides it
    /// should actually look like it, like right now it's bouncing but it's not
    /// even touching the side." He was right and the cause was here. The body
    /// was one circle of radius 0.42 of the layout side, and the drawn face is
    /// neither square nor as wide as its frame: measured on glass at side 76,
    /// the ink is 58 by 78 points. A circle of radius 32 inside a 58 wide face
    /// turns the head round three points before its cheek reaches the wall, and
    /// a 10 point safety inset I had added on top of that made it thirteen.
    /// Both are gone. The bounce is now on the ink, so the visible edge of the
    /// head meets the visible edge of the screen.
    var halfWidth: CGFloat
    var halfHeight: CGFloat

    /// For the gated tower behaviours, which stand the head on a surface: the
    /// only extent that matters there is the vertical one.
    var radius: CGFloat { halfHeight }
    /// Reduce Motion holds it still. The owner asked for an option, not for
    /// a disappearance, so this parks the head and stops the clock rather
    /// than removing it.
    var reduceMotion = false
    /// **THE GATE. Dropping to the tower, hopping along the blocks and dodging
    /// a falling block are all off.**
    ///
    /// The owner, 2026-09-23, after seeing it: "I would focus on just making it
    /// floating for now, bouncing around, and polishing it to the max." The code
    /// for all three is sound and measured (`TowerCompanionTests` still walks
    /// every one of them), so it is gated rather than deleted: `.descending`,
    /// `.hopping` and `.dodging` are unreachable while this is false, which is
    /// how it ships. `think` and `countTowardAVisit` are the only two callers
    /// and `advance` skips both.
    ///
    /// The skyline and the landing are NOT gated. The float still stands off the
    /// top of a tall tower and still flinches when a block lands, which is the
    /// one reaction he kept.
    var visitsTheTower = false

    /// **How long between unprompted visits to the tower.** Gated off. A stored property
    /// rather than the constant, so a debug run can force one every few seconds
    /// and the behaviour can actually be watched instead of waited for. The app
    /// never sets it.
    var visitInterval: ClosedRange<Double> = TowerCompanionSim.visitEvery

    /// How many times he has bounced off a wall or the band's edges. Counted
    /// because "bouncing off the walls" is a thing the owner asked for by name,
    /// and a number is the only way a test can say it happened.
    private(set) var wallHits = 0

    /// The landing already answered, compared on its moment.
    private(set) var answeredLanding: Date?
    /// True once a falling block has been seen; cleared when it lands, so the
    /// next fall startles again.
    private var sawFalling = false

    private var accumulator: TimeInterval = 0
    private var time: TimeInterval = 0
    private var stateAge: TimeInterval = 0
    /// Counts down to the next unprompted visit to the tower.
    private var visitIn: TimeInterval = 0
    /// **The sideways push**, in points a second squared, signed: positive is
    /// one way round from the direction of travel. An Ornstein Uhlenbeck
    /// process, so it has a correlation time and no period. This is the whole
    /// source of the float's shape, and being perpendicular is what stops it
    /// ever slowing him down or holding him anywhere.
    private var lateral: CGFloat = 0
    /// The speed this traverse is holding. Re-rolled on every bounce, so no two
    /// crossings of the screen are at quite the same pace.
    private var cruiseSpeed: CGFloat = 30
    /// The lean's own velocity, degrees a second, so the lean can lag and
    /// overshoot rather than tracking the speed exactly.
    private var tiltVel: Double = 0
    private var hopCooldown: TimeInterval = 0
    private var hopsLeft = 0
    /// How long he has been off the roof while meant to be on it.
    private var airborne: TimeInterval = 0
    /// The dodge began with his feet on a block, so it is a jump and gravity
    /// brings him back down. A dodge that began in the air is a sidestep and
    /// must not turn into a fall.
    private var dodgeGrounded = false
    /// The offset from the finger to the head's centre, captured on touch down
    /// so the head is picked up where it is instead of leaping under the finger.
    private var grab: CGPoint = .zero
    private var rng: UInt64

    /// `seed` exists so a test can walk the same race twice. It is never set
    /// from the app; the head is meant to be different every time.
    init(halfWidth: CGFloat, halfHeight: CGFloat, seed: UInt64 = 0x5EED_1EAF) {
        self.halfWidth = halfWidth
        self.halfHeight = halfHeight
        self.rng = seed == 0 ? 0x5EED_1EAF : seed
    }

    // MARK: The one update call

    /// Advances the simulation by real time elapsed since the last call.
    ///
    /// Everything edge triggered (a landing, a block appearing in the air) is
    /// handled once per call; everything continuous runs inside the fixed
    /// ticks. Cheap enough to state plainly: on a quiet frame this is one
    /// tick of about forty floating point operations, no allocation, no
    /// `Date` formatting, no collection built.
    mutating func update(_ world: TowerCompanionWorld, elapsed: TimeInterval) {
        // **A world that is not finite is not stepped at all.** SwiftUI hands
        // out geometry before it has laid anything out, and one NaN reaching
        // `position` is a crash rather than a glitch: `Int(_:)` traps on it and
        // Core Animation rejects a non finite frame outright. Measured on the
        // simulator, this took the app down a few seconds after launch.
        guard world.bounds.origin.x.isFinite, world.bounds.origin.y.isFinite,
              world.bounds.width.isFinite, world.bounds.height.isFinite,
              elapsed.isFinite else { return }
        guard !reduceMotion else { park(in: world); return }

        notice(world)

        accumulator = min(accumulator + max(elapsed, 0),
                          Self.tick * Double(Self.maxTicks))
        while accumulator >= Self.tick {
            accumulator -= Self.tick
            if state == .held {
                // **Nothing moves the head while a finger has it.** Not the
                // integrator, not a clamp, not a spring. `touch` is the only
                // writer of `position` until the finger comes off, and the lean
                // eases back to upright under it.
                time += Self.tick
                stateAge += Self.tick
                tiltStep()
            } else {
                advance(world)
            }
        }
    }

    // MARK: The one touch input

    /// **A finger on the head, and while it is down the finger is the ONLY
    /// thing that decides where the head is.**
    ///
    /// The owner: "dragging the head around with your finger right now it can be
    /// really glitchy... The dragging needs to feel smooth though." Three things
    /// were wrong and all three are fixed here, because a guess that happens to
    /// work is a bug waiting to come back:
    ///
    /// 1. **The head jumped on touch down.** `.began` set `position = point`, so
    ///    the head's centre snapped to wherever on the face you had grabbed it.
    ///    Take it by the chin and it leapt about forty points. `grab` is the
    ///    offset from the finger to the centre, captured once, and held for the
    ///    whole gesture.
    /// 2. **Two things were writing `position` on the same frames.** The finger
    ///    wrote it here and the simulation's `resolve` wrote it again on every
    ///    tick, and at the edges of the box they disagreed and the head sat
    ///    between them shaking. `update` no longer integrates at all while the
    ///    state is `.held`, and the clamp happens once, right here, so there is
    ///    exactly one writer.
    /// 3. **The lean was being driven by a manufactured speed.** `.moved`
    ///    computed a velocity as the finger's step divided by one tick, but
    ///    gesture callbacks do not arrive at 60Hz and a finger can cross half
    ///    the screen between two of them, so this produced thousands of points a
    ///    second and the head's lean snapped about. It was never used for the
    ///    throw, which comes from the gesture's own projection at `.ended`, so
    ///    it is simply gone.
    ///
    /// `apple-design.md`: respond on pointer DOWN, continuously during the
    /// gesture, and project momentum on release rather than snapping from the
    /// release point. All three still hold.
    mutating func touch(_ phase: Touch, at point: CGPoint,
                        velocity v: CGVector = .zero,
                        in world: TowerCompanionWorld) {
        switch phase {
        case .began:
            state = .held
            stateAge = 0
            isAtRest = false
            // The head does not move on touch down. It is picked up where it is.
            grab = CGPoint(x: position.x - point.x, y: position.y - point.y)
            velocity = .zero
        case .moved:
            guard state == .held else { return }
            position = held(CGPoint(x: point.x + grab.x, y: point.y + grab.y), in: world)
        case .ended:
            guard state == .held else { return }
            position = held(CGPoint(x: point.x + grab.x, y: point.y + grab.y), in: world)
            let speed = hypot(v.dx, v.dy)
            let scale = speed > Self.maxThrow ? Self.maxThrow / speed : 1
            velocity = CGVector(dx: v.dx * scale, dy: v.dy * scale)
            enter(.thrown)
        }
    }

    /// **Where a finger is allowed to put the head.**
    ///
    /// The owner: "I don't think you should be able to drag it on top of the
    /// blocks, like over them." Same rule the float already follows, and for the
    /// same reason: the tower is the record and the head is a thing that lives
    /// in the air above it.
    ///
    /// The floor is the tower's own roofline under the whole width of the face,
    /// not under its centre, so the head rests on the tallest thing it is over
    /// rather than sinking a cheek into the column next door. Because it is a
    /// floor and not a wall, dragging down into the tower slides the head along
    /// the top of the blocks instead of stopping it dead.
    func held(_ wanted: CGPoint, in world: TowerCompanionWorld) -> CGPoint {
        var p = wanted
        let loX = world.bounds.minX + halfWidth
        let hiX = world.bounds.maxX - halfWidth
        p.x = hiX > loX ? clamp(p.x, loX, hiX) : world.bounds.midX

        let loY = world.bounds.minY + halfHeight
        var hiY = world.bounds.maxY - halfHeight
        if world.skyline.hasTower {
            let roof = world.skyline.highestTop(from: p.x - halfWidth, to: p.x + halfWidth)
            hiY = min(hiY, roof - halfHeight - Self.towerClearance)
        }
        p.y = hiY > loY ? clamp(p.y, loY, hiY) : loY

        // And not inside anything drawn. One pass is enough: these do not
        // overlap each other on this screen, and the float's own resolve picks
        // up anything a pathological layout leaves behind.
        for r in world.obstacles {
            let left = (p.x + halfWidth) - r.minX
            let right = r.maxX - (p.x - halfWidth)
            let up = (p.y + halfHeight) - r.minY
            let down = r.maxY - (p.y - halfHeight)
            guard left > 0, right > 0, up > 0, down > 0 else { continue }
            let least = min(min(left, right), min(up, down))
            if least == left { p.x = r.minX - halfWidth }
            else if least == right { p.x = r.maxX + halfWidth }
            else if least == up { p.y = r.minY - halfHeight }
            else { p.y = r.maxY + halfHeight }
        }
        return p
    }

    // MARK: Events

    /// Things that happened since the last frame, answered once.
    private mutating func notice(_ world: TowerCompanionWorld) {
        if let landing = world.landing, landing.at != answeredLanding {
            answeredLanding = landing.at
            startle(awayFrom: CGPoint(x: landing.rect.midX, y: landing.rect.midY),
                    world: world)
            // **Occasionally he goes down to look.** Only from the air, and
            // only when there is a tower to stand on: a visit that begins
            // while a finger is on the head would take it out of the hand.
            //
            // **`visitsTheTower` is checked HERE as well**, and leaving it out
            // was a real hole: `advance` gates `think` and `countTowardAVisit`,
            // but `notice` runs on every update, so a gated build still went
            // down to the tower one landing in five. It survived the gate test
            // because that test ran a world with nothing landing in it, which is
            // the one screen where this path cannot fire. The test feeds
            // landings now.
            if visitsTheTower, world.skyline.hasTower,
               state == .drifting || state == .startled || state == .resting,
               random() < Self.visitChance {
                hopsLeft = Int(random(in: Self.hopsPerVisit).rounded())
                enter(.descending)
            }
        }

        if let falling = world.falling {
            if !sawFalling {
                sawFalling = true
                // A block flying near him. Far away it is not his business:
                // the flinch is proportional and it is often nothing at all.
                if distance(from: position, to: falling) < Self.noticeRadius {
                    startle(awayFrom: CGPoint(x: falling.midX, y: falling.maxY), world: world)
                }
            }
        } else {
            sawFalling = false
        }
    }

    /// **The unprompted visit.** Counted in the tick loop rather than answered
    /// off an event, because the thing it has to work on is a Wins tab with
    /// nothing happening on it, which is what the screen looks like almost all
    /// of the time.
    private mutating func countTowardAVisit(_ world: TowerCompanionWorld) {
        guard state == .drifting else { return }
        visitIn -= Self.tick
        guard visitIn <= 0 else { return }
        visitIn = random(in: visitInterval)
        guard world.skyline.hasTower else { return }
        hopsLeft = Int(random(in: Self.hopsPerVisit).rounded())
        enter(.descending)
    }

    /// **The drift: a held speed on a slowly curving heading.**
    ///
    /// Not a damped impulse, which is what parked the first build, and not a
    /// spring to a target, which never bounces off anything. The owner asked
    /// for a float that bounces off the walls, so the velocity is the truth and
    /// the walls reflect it; all this does is keep the speed from dying and bend
    /// the heading so the path is a long curve instead of a straight line
    /// across the screen for ever.
    /// **A flinch: an impulse into the same air, away from what happened.**
    ///
    /// The owner: "it will react to things happening, like a block flying near
    /// him or placing a block." This is the one reaction that survives the cut
    /// to floating only, and it is deliberately not a state with physics of its
    /// own. It adds to the velocity and drag takes it away over a second or so,
    /// so the reaction and the float are the same object moving: a head that
    /// switched to a different kind of motion for a fifth of a second and back
    /// is a large part of why the first version did not feel natural.
    private mutating func startle(awayFrom point: CGPoint, world: TowerCompanionWorld) {
        guard state != .held else { return }
        isAtRest = false
        var away = CGVector(dx: position.x - point.x, dy: position.y - point.y)
        let d = max(hypot(away.dx, away.dy), 1)
        away = CGVector(dx: away.dx / d, dy: away.dy / d)
        // Falls off with distance, so a landing on the far side of the tower is
        // a twitch and one right under him is a shove.
        let near = clamp(Double(1 - d / (Self.noticeRadius * 2.5)), 0.12, 1)
        let push = Self.startleSpeed * CGFloat(near)
        velocity.dx += away.dx * push
        velocity.dy += away.dy * push
        // The head is knocked round as well as sideways, which is what makes it
        // read as having been hit rather than moved.
        tiltVel += Double(away.dx) * Double(push) * 0.25
        if state == .drifting { enter(.startled) }
    }

    private mutating func floatStep(_ world: TowerCompanionWorld) {
        let dt = CGFloat(Self.tick)
        var sp = speed
        if sp < 1 {
            // Handed a zero. Pick a heading rather than sitting there, and never
            // exactly along an axis: a traverse locked to the horizontal is the
            // one path a person learns in seconds.
            let angle = random() * 2 * Double.pi
            velocity = CGVector(dx: CGFloat(cos(angle)) * cruiseSpeed,
                                dy: CGFloat(sin(angle)) * cruiseSpeed)
            unstick()
            sp = speed
        }
        let ux = velocity.dx / sp, uy = velocity.dy / sp

        // **The wander is SIDEWAYS only, and that is the whole design.**
        //
        // The model before this was a current pushing the head in any direction
        // against drag. It looked like weight, and it had two faults the owner
        // saw at once: a gust pointing into a wall held him against it for as
        // long as it blew, and a current passing through zero left him hanging.
        // Measured over 24 runs of four minutes: the quietest three seconds of a
        // run moved him 0.4 points, which is a stopped head, and he spent up to
        // 35 seconds at a time against one edge.
        //
        // A force perpendicular to travel cannot do either. It cannot slow him
        // down, because it does no work along his path, so he never stalls; and
        // it cannot hold him anywhere, because it is never pointing where he is.
        // All it can do is TURN him, which is exactly the freedom asked for:
        // "a bit more freedom, but there shouldn't be like some sort of
        // structure to the movement."
        //
        // It is an Ornstein Uhlenbeck process, so it has a correlation time and
        // no period: the turns are unhurried and they never repeat.
        let pull = CGFloat(Self.tick / Self.gustTau)
        let kick = Self.gustStrength * CGFloat(Self.tick.squareRoot())
        lateral += -lateral * pull + kick * CGFloat(gauss())
        lateral = clamp(lateral, -Self.maxLateral, Self.maxLateral)
        var ax = -uy * lateral
        var ay = ux * lateral

        // **The governor, which is where the weight lives.**
        //
        // Not a speed that is set, which is a tween: a force along the path
        // proportional to how far off the cruise he is. He accelerates out of a
        // bounce over about a second and a half, and a landing's shove or a
        // throw bleeds off the same way. Coming down from a throw is firmer than
        // coming up from a bounce, or a hard flick would spend five seconds
        // crossing the screen like a bullet.
        let gain = sp > cruiseSpeed ? Self.governorDown : Self.governorUp
        let along = (cruiseSpeed - sp) * gain
        ax += ux * along
        ay += uy * along

        // **A floating thing rises out of a hole, and that is the only force in
        // here that is not the wander or the governor.**
        //
        // The owner described the behaviour he wanted exactly: it falls to the
        // tower, lands on it, bounces off, "and goes back up". Without this it
        // does the first three and then, measured over 40 runs of three minutes
        // on a tower with two tall columns, one run in ten was still in the same
        // well after three minutes: 16% of the screen's width, which is living
        // in a region. A well is a geometric trap and no amount of tuning the
        // bounce gets out of one.
        //
        // It is ZERO above the tower's tallest roof, so there is no pull toward
        // the top of the screen and no home position: it only exists down among
        // the blocks, where being able to leave is the whole point. It is also
        // far weaker than a traverse, so it never stops the head descending; it
        // just means a head that went down comes back up.
        if world.skyline.hasTower {
            // **In a well, not merely low.** This used to measure the depth
            // below the tower's TALLEST roof, which is a different thing and it
            // held the head off the whole tower: measured on a phone over two
            // and a half minutes, the closest the chin ever came to a block was
            // 35 points, so it never landed on one at all.
            //
            // A well is somewhere with a higher roof beside it. Comparing the
            // roofline one column either side against the roofline directly
            // under the head says exactly that, and a head coming down onto the
            // tallest column's flat top gets no lift whatever, so it can land.
            let sky = world.skyline
            let reach = sky.pitch
            let around = sky.highestTop(from: position.x - halfWidth - reach,
                                        to: position.x + halfWidth + reach)
            let under = sky.highestTop(from: position.x - halfWidth,
                                       to: position.x + halfWidth)
            let depth = (position.y + halfHeight) - around
            if around < under, depth > 0 {
                ay -= Self.wellLift * min(depth / Self.wellReach, 1)
            }
        }

        velocity.dx += ax * dt
        velocity.dy += ay * dt

        // **Nothing else.** No pull toward the middle of the band, no cushion at
        // the edges, no preferred region of any kind. Those were what kept him
        // living on one side of the screen, and a head with a home position has
        // a structure a person can learn. The walls are the only thing that
        // changes his mind, and they do it by being hit.
        if speed > Self.maxDrift {
            let k = Self.maxDrift / speed
            velocity = CGVector(dx: velocity.dx * k, dy: velocity.dy * k)
        }
    }

    /// **Never let a traverse settle onto an axis.**
    ///
    /// A path exactly along the horizontal or the vertical is the one shape the
    /// eye learns immediately, and a lossy bounce tends toward it: each bounce
    /// takes a bite out of the component along the wall. So a heading inside a
    /// few degrees of an axis is knocked off it. Called on every bounce and on
    /// any restart.
    private mutating func unstick() {
        let sp = speed
        guard sp > 0.01 else { return }
        var angle = atan2(Double(velocity.dy), Double(velocity.dx))
        let quarter = Double.pi / 2
        let nearest = (angle / quarter).rounded() * quarter
        if abs(angle - nearest) < Self.axisFloor {
            let push = Self.axisFloor * (random() < 0.5 ? -1 : 1)
            angle = nearest + push
            velocity = CGVector(dx: CGFloat(cos(angle)) * sp, dy: CGFloat(sin(angle)) * sp)
        }
    }

    /// **The lean, one tick behind the movement.** See `tiltStiffness`.
    private mutating func tiltStep() {
        // A head in a hand sits upright. The lean is a thing its own movement
        // does to it, and while it is held it has no movement of its own.
        let target = state == .held ? 0
            : clamp(Double(velocity.dx) * Self.tiltPerPoint, -Self.maxTilt, Self.maxTilt)
        tiltVel += ((target - tilt) * Self.tiltStiffness - tiltVel * Self.tiltDamping) * Self.tick
        tilt += tiltVel * Self.tick
        // The spring cannot take the head further over than the lean allows,
        // whatever it overshoots by.
        if tilt > Self.maxTilt { tilt = Self.maxTilt; tiltVel = min(tiltVel, 0) }
        if tilt < -Self.maxTilt { tilt = -Self.maxTilt; tiltVel = max(tiltVel, 0) }
    }

    /// A standard normal, from three uniforms. No trigonometry, no allocation:
    /// three draws in [0,1) sum to a standard deviation of 0.5, so doubling the
    /// centred sum gives very close to unit variance, which is all a push needs.
    private mutating func gauss() -> Double {
        (random() + random() + random() - 1.5) * 2
    }

    /// **Where the head overlaps a drawn object, and the shortest way out.**
    ///
    /// The same rule the tower uses, for the same reason: pushing out along the
    /// shortest axis turns landing on top of something into an upward bounce and
    /// running into its side into a sideways one, without anybody having to
    /// decide which happened.
    ///
    /// One object per tick. Two overlapping at once is a corner, and resolving
    /// the deeper one first and the other on the next tick is what makes a
    /// corner read as two bounces rather than as a jump.
    func obstacleEscape(_ world: TowerCompanionWorld) -> CGVector? {
        var best: CGVector?
        var bestDepth = CGFloat.greatestFiniteMagnitude
        for r in world.obstacles {
            let left = (position.x + halfWidth) - r.minX
            let right = r.maxX - (position.x - halfWidth)
            let up = (position.y + halfHeight) - r.minY
            let down = r.maxY - (position.y - halfHeight)
            guard left > Self.contactEpsilon, right > Self.contactEpsilon,
                  up > Self.contactEpsilon, down > Self.contactEpsilon else { continue }
            let least = min(min(left, right), min(up, down))
            guard least < bestDepth else { continue }
            bestDepth = least
            if least == left { best = CGVector(dx: -left, dy: 0) }
            else if least == right { best = CGVector(dx: right, dy: 0) }
            else if least == up { best = CGVector(dx: 0, dy: -up) }
            else { best = CGVector(dx: 0, dy: down) }
        }
        return best
    }

    /// **Where the head overlaps the tower, and the shortest way out.**
    ///
    /// The owner: "I would prefer it to interact with all the elements." So the
    /// tower is not a floor the head is kept above, it is an object in the same
    /// box: the head traverses the whole screen, meets the blocks, and comes off
    /// them the same way it comes off a wall.
    ///
    /// **Least penetration, not a floor.** Clamping y to the roofline under the
    /// head looks right and is not: a tower is a staircase, so the moment the
    /// head's cheek reaches a column one row taller, a y clamp lifts it the
    /// whole row in a single tick. That is a teleport, and it is the difference
    /// between a head that bounced off the side of a block and a head that
    /// jumped onto it. Working out the shortest way out instead gives the right
    /// answer for both cases by construction: landing on a roof escapes upward,
    /// and running into the side of a step escapes sideways by a fraction of a
    /// point, which is a bounce off a wall.
    ///
    /// Returns the escape as a vector, or nil when the head is in clear air.
    /// Only ONE of the two components is ever non zero.
    func towerEscape(_ world: TowerCompanionWorld) -> CGVector? {
        let sky = world.skyline
        guard sky.hasTower, sky.pitch > 0 else { return nil }
        let bottom = position.y + halfHeight + Self.towerClearance
        let left = position.x - halfWidth
        let right = position.x + halfWidth

        var up: CGFloat = 0, pushLeft: CGFloat = 0, pushRight: CGFloat = 0
        for c in 0..<TowerSkyline.columns {
            let top = sky.top(ofColumn: c)
            guard bottom > top else { continue }
            // The block's FLAT top, not its cell: a corner is drawn curving
            // away, and colliding on the cell's full width puts a surface where
            // the person can see there is none.
            let colLeft = sky.originX + sky.pitch * CGFloat(c) + sky.cornerInset
            let colRight = colLeft + sky.columnWidth - sky.cornerInset * 2
            guard right > colLeft, left < colRight else { continue }
            up = max(up, bottom - top)
            pushLeft = max(pushLeft, right - colLeft)
            pushRight = max(pushRight, colRight - left)
        }
        // **An epsilon, and it is not tidiness.** A head sliding along the side
        // of a block overlaps it by about 1e-14 of a point every tick, and
        // without this that counts as a collision: a full bounce, a wall hit and
        // a reversed velocity, sixty times a second. It is the same chatter the
        // side walls had before `contactSpeed`, and it is invisible in code.
        guard up > Self.contactEpsilon else { return nil }

        // Sideways only when it is genuinely the shorter way out. A head sitting
        // squarely on a roof has a huge sideways escape and a small upward one.
        if pushLeft <= up && pushLeft <= pushRight {
            return pushLeft > Self.contactEpsilon ? CGVector(dx: -pushLeft, dy: 0) : nil
        }
        if pushRight <= up {
            return pushRight > Self.contactEpsilon ? CGVector(dx: pushRight, dy: 0) : nil
        }
        return CGVector(dx: 0, dy: -up)
    }

    // MARK: A tick

    private mutating func advance(_ world: TowerCompanionWorld) {
        time += Self.tick
        stateAge += Self.tick

        // A finger owns the head outright. No integration, no gravity: the
        // head is exactly where the hand is, which is what "responds
        // continuously during the gesture" means.
        guard state != .held else {
            resolve(world, landing: false)
            return
        }

        // `.resting` is Reduce Motion only now, and `update` returns before it
        // gets here in that case. Anything else that reaches this state is a
        // bug, so it floats rather than sitting still for ever.
        if state == .resting { enter(.drifting) }

        // **Getting out of the way is NOT gated**, and it is not optional.
        //
        // The head shares the screen with the tower now, so it can be exactly
        // where a block is about to land. The one thing a companion must never
        // do is stand in front of what the person is doing, so the dodge runs
        // whatever else is switched off. Walking and hopping along the blocks
        // still sit behind `visitsTheTower`: they are a different idea, a
        // scripted visit rather than a physical object, and the owner has not
        // asked for them back.
        think(world)
        if visitsTheTower { countTowardAVisit(world) }

        let dt = CGFloat(Self.tick)
        let falls = state == .descending || state == .hopping
            || (state == .dodging && dodgeGrounded)
        if falls {
            velocity.dy += Self.gravity * dt
            velocity.dx *= Self.airDamping
        } else if state == .dodging || state == .returning {
            // Gated behaviours in the air: these bleed off rather than float,
            // because both are going somewhere on purpose.
            velocity.dx *= Self.driftDamping
            velocity.dy *= Self.driftDamping
        } else {
            // **Drifting, flinching and thrown are all the same body in the
            // same air.**
            //
            // A throw used to switch on gravity and a flinch used to damp on
            // its own curve, and both were discontinuities: the head changed
            // what kind of object it was mid motion, which is a large part of
            // "the animations do not feel natural at all". One integrator, and
            // a landing or a flick is an impulse into it. Drag takes the
            // impulse away over about two seconds, which is a glide.
            floatStep(world)
        }

        if state == .returning {
            // A pull toward the middle of the drift band, damped, so he rises
            // and settles rather than shooting through it.
            let target = (world.opening.lowerBound + world.opening.upperBound) / 2
            velocity.dy += (target - position.y) * 5.0 * dt
        }

        if state == .dodging {
            // The one place a velocity is commanded rather than nudged. See
            // `escapeX`: getting out of the way has to be a guarantee, not a
            // tendency, or a block lands on his head.
            if let falling = world.falling {
                let goal = escapeX(from: falling, world: world)
                let dir: CGFloat = goal > position.x ? 1 : -1
                velocity.dx = dir * Self.escapeSpeed
            }
        }

        position.x += velocity.dx * dt
        position.y += velocity.dy * dt

        resolve(world, landing: state == .descending || state == .hopping)
        settle(world)
        // Per tick, not once per update, or the lean's own spring would be
        // integrated at whatever rate the display happens to be running at.
        tiltStep()
    }

    /// State changes that depend on where he is rather than on an event.
    private mutating func think(_ world: TowerCompanionWorld) {
        // **Out of the way of a block that is coming down.** Checked every
        // tick and from every state, because the block is moving and the
        // answer changes under him.
        if let falling = world.falling, state != .held, threatened(by: falling) {
            if state != .dodging {
                dodgeGrounded = onSurface(world)
                // A jump, not a slide: "making sure to jump out of the way of
                // the blocks falling."
                if dodgeGrounded { velocity.dy = -Self.hopUp * 0.7 }
                enter(.dodging)
            }
        } else if state == .dodging, stateAge > 0.12 {
            enter(visitsTheTower && onSurface(world) ? .hopping : .drifting)
        }

        if state == .startled, stateAge >= Self.startleHold { enter(.drifting) }

        guard visitsTheTower else { return }

        if state == .returning, stateAge > 8 {
            // **Insurance, not physics.** The spring toward the band always
            // gets there in practice, and a companion that could be left
            // hanging in the middle of the screen for ever is not worth
            // being right about in theory.
            enter(.drifting)
        }

        if state == .hopping {
            guard onSurface(world) else {
                // **Stranded, so go home.** He can come down somewhere with no
                // roof under him: a tower whose bottom row sits below the tab
                // bar, or a reflow that took the block away while he was in
                // the air. Without this he sits there as `.hopping` for ever
                // with the cooldown never ticking, which is a clock that can
                // never be stopped.
                airborne += Self.tick
                if airborne > 2.5 { enter(.returning) }
                return
            }
            airborne = 0
            hopCooldown -= Self.tick
            guard hopCooldown <= 0 else { return }
            if hopsLeft <= 0 { enter(.returning); return }
            hopsLeft -= 1
            hopCooldown = random(in: Self.hopGap)
            jump(world)
        }
    }

    /// Is this falling block coming down on him.
    private func threatened(by falling: CGRect) -> Bool {
        // Above him, and his x is inside the block's shadow with a margin.
        // The margin is what makes him step clear rather than stand at the
        // very edge of a block's corner.
        let lane = falling.insetBy(dx: -(Self.dodgeMargin + halfWidth), dy: 0)
        guard position.x > lane.minX, position.x < lane.maxX else { return false }
        return falling.maxY <= position.y + radius
    }

    /// **The nearest edge of the falling block's lane that he can actually
    /// reach**, so the escape is provable rather than hopeful.
    ///
    /// Whichever side has room in the arena wins; when neither does (a block
    /// that spanned the whole width, which this grid cannot make but which a
    /// test is entitled to ask about) he goes to the side with more room and
    /// the arena's own clamp keeps him inside.
    private func escapeX(from falling: CGRect, world: TowerCompanionWorld) -> CGFloat {
        let pad = Self.dodgeMargin + halfWidth + 2
        let left = falling.minX - pad
        let right = falling.maxX + pad
        let lo = world.bounds.minX + halfWidth
        let hi = world.bounds.maxX - halfWidth
        let leftOK = left >= lo
        let rightOK = right <= hi
        if leftOK && rightOK {
            return abs(left - position.x) <= abs(right - position.x) ? left : right
        }
        if leftOK { return left }
        if rightOK { return right }
        return (position.x - lo) > (hi - position.x) ? lo : hi
    }

    private mutating func jump(_ world: TowerCompanionWorld) {
        let here = world.skyline.columnIndex(atX: position.x)
        let apex = Double(Self.hopUp * Self.hopUp / (2 * Self.gravity))
        // Neighbours he can actually land on: one he would need more than an
        // apex to reach is not a hop, it is a failed hop, and a failed hop is
        // him walking into the side of a block. Two optionals rather than an
        // array, because this file allocates nothing.
        func reachable(_ c: Int) -> Bool {
            guard c >= 0, c < TowerSkyline.columns else { return false }
            let rise = Double(world.skyline.top(ofColumn: here) - world.skyline.top(ofColumn: c))
            return rise < apex * 0.92
        }
        let left = reachable(here - 1)
        let right = reachable(here + 1)
        let target: Int
        if left && right { target = random() < 0.5 ? here - 1 : here + 1 }
        else if left { target = here - 1 }
        else if right { target = here + 1 }
        else { target = here }
        let goal = world.skyline.centreX(ofColumn: target)
        let dx = goal - position.x
        velocity.dy = -Self.hopUp
        // In place when there is nowhere to go: a small hop on the spot reads
        // as him enjoying himself, and standing frozen reads as a bug.
        velocity.dx = abs(dx) < 1 ? 0 : (dx > 0 ? Self.hopSide : -Self.hopSide)
    }

    // MARK: Resolving, by position

    /// **Walls, the slot and the tower, resolved by moving the head.**
    ///
    /// Nothing here reverses a velocity and leaves the head where it was. At
    /// 20,000 points a second a velocity-only bounce is outside the box for a
    /// whole tick and the next tick pushes it further out; a positional clamp
    /// cannot tunnel however fast the head is going, which is what
    /// `TowerCompanionTests.itNeverTunnelsThroughAWall` pins.
    private mutating func resolve(_ world: TowerCompanionWorld, landing: Bool) {
        let loX = world.bounds.minX + halfWidth
        let hiX = world.bounds.maxX - halfWidth
        let loY = world.bounds.minY + halfHeight
        let hiY = world.bounds.maxY - halfHeight

        if hiX <= loX {
            position.x = world.bounds.midX
            velocity.dx = 0
        } else if position.x < loX {
            position.x = loX
            bounce(alongX: true, into: 1)
        } else if position.x > hiX {
            position.x = hiX
            bounce(alongX: true, into: -1)
        }

        if hiY <= loY {
            position.y = world.bounds.midY
            velocity.dy = 0
        } else if position.y < loY {
            position.y = loY
            bounce(alongX: false, into: 1)
        } else if position.y > hiY {
            position.y = hiY
            velocity.dy = -abs(velocity.dy) * Self.groundRestitution
            if landing { arrive(world) }
        }

        // The drift band is a ceiling and a floor of its own while he is up
        // there, so floating "on the top" means on the top rather than
        // anywhere in the page.
        // Everything that floats meets the tower the same way. A head let go
        // just above the blocks carries on from where it was let go: there is no
        // band to be snapped back into any more.
        if state == .thrown || state == .drifting || state == .startled {
            // **The tower is an object in the box, not the bottom of it.**
            // See `towerEscape`: the head comes off a roof upward and off the
            // side of a step sideways, and both are the same lossy bounce the
            // walls give it.
            if let out = towerEscape(world) ?? obstacleEscape(world) {
                if out.dy != 0 {
                    position.y += out.dy
                    bounce(alongX: false, into: out.dy < 0 ? -1 : 1)
                } else {
                    position.x += out.dx
                    bounce(alongX: true, into: out.dx < 0 ? -1 : 1)
                }
            }
        }

        // The tower's own roofline, for anything that is coming down onto it.
        //
        // **The snap does not ask which way he is going.** It did, and a hop
        // that crossed sideways into a taller column while still RISING was
        // never tested: he passed through the side of a block and came out
        // standing inside it. A head is never inside a block, whatever its
        // velocity, so the position is corrected first and only the bounce
        // asks about direction.
        if landing || state == .hopping || state == .dodging {
            let surface = world.skyline.surfaceY(atX: position.x) - radius
            if world.skyline.hasTower, position.y > surface {
                position.y = surface
                if velocity.dy > 40 {
                    // **The give is capped, not proportional.** A fall from
                    // the drift band arrives at about 1,400 points a second,
                    // and 30% of that is a 22 point bounce: a head made of
                    // rubber. Capped, the give is under ten points, which is
                    // a landing.
                    velocity.dy = -min(velocity.dy * Self.groundRestitution, 260)
                } else if velocity.dy >= 0 {
                    velocity.dy = 0
                    // He plants his feet. Without this a hop's sideways speed
                    // carries on along the roof and he slides instead of
                    // standing, which reads as ice rather than as a landing.
                    velocity.dx *= 0.35
                    arrive(world)
                }
            }
        }

        pushOutOfSlot(world)

        // **The last word, and it only moves him.**
        //
        // The roofline and the slot are both resolved after the walls, and
        // either can put him back outside: a tower tall enough to reach into
        // the drift band snaps him above the top edge, and a slot against an
        // edge pushes him through it. This is the guarantee
        // `itStaysInsideItsBounds` and `itNeverTunnelsThroughAWall` are
        // actually pinning, so it is the thing that runs last and it touches
        // no velocity, because a second bounce here would be a bounce nobody
        // could see the cause of.
        if !position.x.isFinite || !position.y.isFinite {
            // Belt and braces. If anything upstream ever produces one again,
            // the head is put back in the middle rather than taking the app out.
            position = CGPoint(x: world.bounds.midX, y: world.bounds.midY)
            velocity = .zero
        }
        if hiX > loX { position.x = clamp(position.x, loX, hiX) } else { position.x = world.bounds.midX }
        if hiY > loY { position.y = clamp(position.y, loY, hiY) } else { position.y = world.bounds.midY }
    }

    /// He has touched down on the tower.
    private mutating func arrive(_ world: TowerCompanionWorld) {
        guard state != .hopping else { return }
        if world.skyline.hasTower {
            if hopsLeft <= 0 { hopsLeft = Int(random(in: Self.hopsPerVisit).rounded()) }
            hopCooldown = random(in: Self.hopGap)
            enter(.hopping)
        } else {
            enter(.returning)
        }
    }

    /// **A bounce that is not a mirror.**
    ///
    /// The owner: the motion has to feel natural. Equal angles at equal speed is
    /// the single most artificial thing a bouncing object can do, and a head that
    /// keeps arriving back at the same speed it left with reads as a sprite on a
    /// path. So three things happen at once, all of them what contact with a
    /// surface actually does:
    ///
    /// - about half the speed comes back along the normal (`bounceRestitution`),
    /// - the component ALONG the wall is scrubbed (`bounceFriction`), which is
    ///   what turns a glancing hit into a slide rather than a skid,
    /// - and the outgoing direction is knocked a few degrees off
    ///   (`bounceScatter`), so two bounces off the same wall never repeat.
    ///
    /// The gust is left alone: the current that pushed the head into the wall is
    /// still blowing, and having to fight back out of the corner is part of what
    /// makes the float look like it is in something.
    ///
    /// `into` is the direction the head leaves in, 1 or -1.
    private mutating func bounce(alongX: Bool, into sign: CGFloat) {
        // **A slow contact is a contact, not a bounce.**
        //
        // A gust holding the head against an edge put it a hair past the line on
        // every tick, and every tick reflected a near zero velocity: measured,
        // 369 "bounces" in a minute and a head vibrating on the boundary. A body
        // pressed against a wall by a steady force rests on it. So below this
        // speed the normal component is simply stopped, and the cushion is what
        // eventually peels him off.
        let incoming = alongX ? abs(velocity.dx) : abs(velocity.dy)
        guard incoming >= Self.contactSpeed else {
            if alongX { velocity.dx = 0 } else { velocity.dy = 0 }
            return
        }
        wallHits += 1
        if alongX {
            let hit = abs(velocity.dx)
            velocity.dx = sign * hit * Self.bounceRestitution
            velocity.dy *= Self.bounceFriction
            // Knocked round by the impact, and the lean's own spring carries it
            // back. This is the rotation that says the head has mass.
            tiltVel += Double(sign * hit) * 0.16
        } else {
            let hit = abs(velocity.dy)
            velocity.dy = sign * hit * Self.bounceRestitution
            velocity.dx *= Self.bounceFriction
        }
        // A few degrees of scatter, so nothing about a bounce is repeatable.
        let a = (random() - 0.5) * 2 * Self.bounceScatter
        let c = CGFloat(cos(a)), sn = CGFloat(sin(a))
        velocity = CGVector(dx: velocity.dx * c - velocity.dy * sn,
                            dy: velocity.dx * sn + velocity.dy * c)
        unstick()
        // A new pace for the traverse this bounce starts, so two crossings of
        // the same screen are never at the same speed.
        cruiseSpeed = CGFloat(random(in: Self.cruise))
    }

    /// **The block being placed is never covered.**
    ///
    /// Pushed out along the shorter way, because the shorter way is the one
    /// that looks like him getting out of the way rather than teleporting
    /// round the block.
    private mutating func pushOutOfSlot(_ world: TowerCompanionWorld) {
        guard let slot = world.slot else { return }
        let box = slot.insetBy(dx: -halfWidth, dy: -halfHeight)
        guard box.width > 0, box.height > 0,
              position.x > box.minX, position.x < box.maxX,
              position.y > box.minY, position.y < box.maxY else { return }
        let left = position.x - box.minX
        let right = box.maxX - position.x
        let up = position.y - box.minY
        let down = box.maxY - position.y
        // **Put OUTSIDE the edge, not on it.** `CGRect.contains` includes its
        // own minimum edges, so landing him exactly on `box.minX` leaves him
        // inside the rectangle by every test anybody will write, including the
        // one that guards this.
        let out: CGFloat = 0.5
        let least = min(min(left, right), min(up, down))
        if least == left { position.x = box.minX - out; velocity.dx = -abs(velocity.dx) * Self.wallRestitution }
        else if least == right { position.x = box.maxX + out; velocity.dx = abs(velocity.dx) * Self.wallRestitution }
        else if least == up { position.y = box.minY - out; velocity.dy = -abs(velocity.dy) * Self.wallRestitution }
        else { position.y = box.maxY + out; velocity.dy = abs(velocity.dy) * Self.wallRestitution }
    }

    // MARK: Back to the drift

    /// **There is no coming to rest any more**, and that is the fix.
    ///
    /// This used to put the head to sleep once its drift had damped below seven
    /// points a second, so the layer could stop its clock. Measured on a phone
    /// that is exactly what the person sees: a head that moves for a few
    /// seconds after launch and is then a sticker. The clock is stopped by the
    /// head being invisible now, not by the head being still.
    private mutating func settle(_ world: TowerCompanionWorld) {
        if state == .returning, world.opening.contains(position.y),
           abs(velocity.dy) < 60 {
            enter(.drifting)
        }

        // A throw is an impulse into the same air, so there is nothing to arrive
        // at: once it is back in the band at something like a traverse speed, it
        // is simply drifting again. The timeout is insurance, not physics.
        if state == .thrown, speed < cruiseSpeed * 1.8 || stateAge > 6 {
            enter(visitsTheTower && onSurface(world) ? .hopping : .drifting)
        }

        if state == .startled, stateAge >= Self.startleHold { enter(.drifting) }
    }

    /// Reduce Motion: parked, and it stays parked.
    ///
    /// The owner asked for the head as an option; Reduce Motion is a
    /// statement about movement, not about whether he wants a head. So the
    /// head is put somewhere sensible near the top and left there, which is
    /// also `LivingHeadView`'s own behaviour under the same setting.
    private mutating func park(in world: TowerCompanionWorld) {
        state = .resting
        velocity = .zero
        tilt = 0
        isAtRest = true
        let x = clamp(world.bounds.maxX - halfWidth - 12,
                      world.bounds.minX + halfWidth, world.bounds.maxX - halfWidth)
        let y = clamp(world.opening.lowerBound + halfHeight + 6,
                      world.bounds.minY + halfHeight, world.bounds.maxY - halfHeight)
        position = CGPoint(x: x, y: y)
        if let slot = world.slot {
            let box = slot.insetBy(dx: -halfWidth, dy: -halfHeight)
            if box.contains(position) { position.y = box.maxY }
        }
    }

    // MARK: Small helpers

    var speed: CGFloat { hypot(velocity.dx, velocity.dy) }

    /// Standing on the tower right now.
    func onSurface(_ world: TowerCompanionWorld) -> Bool {
        guard world.skyline.hasTower else { return false }
        return abs(position.y - (world.skyline.surfaceY(atX: position.x) - radius)) < 2.5
    }

    /// Puts the head somewhere sensible the first time the layer has a size,
    /// and gives it the speed it will hold.
    mutating func place(in world: TowerCompanionWorld) {
        position = CGPoint(x: world.bounds.midX + world.bounds.width * 0.22,
                           y: (world.opening.lowerBound + world.opening.upperBound) / 2)
        // **Starts at a third of the cruise, not at rest and not at speed.** The
        // governor takes it the rest of the way over the first second or so, so
        // the first thing anybody sees is a head gathering itself rather than a
        // head launched by something.
        cruiseSpeed = CGFloat(random(in: Self.cruise))
        let angle = random() * 2 * Double.pi
        velocity = CGVector(dx: CGFloat(cos(angle)) * cruiseSpeed / 3,
                            dy: CGFloat(sin(angle)) * cruiseSpeed / 3)
        unstick()
        // Put where it is allowed to be. Without this the very first frame has
        // the head wherever the opening said, unclamped, which is how a
        // measurement of "the closest it came to the top edge" came back as 36
        // points OUTSIDE the screen.
        position = held(position, in: world)
        lateral = CGFloat((random() - 0.5) * 2) * Self.maxLateral * 0.4
        tilt = 0
        tiltVel = 0
        visitIn = random(in: visitInterval)
        state = .drifting
        isAtRest = false
    }

    /// **Puts the head at a point.** For tests and the debug lab, which need it
    /// somewhere specific; the app only ever calls `place(in:)`.
    ///
    /// It exists because `touch` stopped being a way to teleport: a finger picks
    /// the head up where it is now, so `.began` no longer moves it anywhere.
    mutating func place(in world: TowerCompanionWorld, at point: CGPoint,
                        velocity v: CGVector = .zero) {
        place(in: world)
        position = held(point, in: world)
        velocity = v
        tilt = 0
        tiltVel = 0
    }

    private mutating func enter(_ next: State) {
        guard state != next else { return }
        state = next
        stateAge = 0
        if next != .resting { isAtRest = false }
    }

    private func distance(from p: CGPoint, to r: CGRect) -> CGFloat {
        let dx = max(r.minX - p.x, 0, p.x - r.maxX)
        let dy = max(r.minY - p.y, 0, p.y - r.maxY)
        return hypot(dx, dy)
    }

    // A xorshift, stored in the struct, so a test can walk the same head
    // twice and the app never does.
    private mutating func random() -> Double {
        rng ^= rng << 13
        rng ^= rng >> 7
        rng ^= rng << 17
        return Double(rng >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }

    private mutating func random(in r: ClosedRange<Double>) -> Double {
        r.lowerBound + (r.upperBound - r.lowerBound) * random()
    }
}

private func clamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T {
    min(max(v, lo), hi)
}
