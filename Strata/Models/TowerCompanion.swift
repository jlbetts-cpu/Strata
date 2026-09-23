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

    /// The band near the top the head drifts in when nothing is happening.
    /// The owner: "it kinda just floats on the top, around, bouncing off the
    /// walls."
    var driftBand: ClosedRange<CGFloat>

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

    init(bounds: CGRect,
         driftBand: ClosedRange<CGFloat>? = nil,
         skyline: TowerSkyline = TowerSkyline(),
         slot: CGRect? = nil,
         falling: CGRect? = nil,
         landing: Landing? = nil) {
        self.bounds = bounds
        self.skyline = skyline
        self.slot = slot
        self.falling = falling
        self.landing = landing
        if let driftBand {
            self.driftBand = driftBand
        } else {
            // **A third of the box, capped.** On a tall phone a band that is
            // a flat share of the height puts the head halfway down the
            // screen, which is not "on the top" any more. On a short one a
            // fixed 220 would be most of the page.
            let depth = min(bounds.height * 0.34, 220)
            let top = bounds.minY
            self.driftBand = top...(top + max(depth, 1))
        }
    }

    /// Nothing is happening: no block in the air, and the last landing has
    /// already been answered. The layer pauses its clock on this.
    ///
    /// A nil `landing` is quiet whatever was answered. It used to compare
    /// `landing?.at == answered`, which is true while the ripple is up and
    /// false the moment the caller clears it, so the clock woke on the clear
    /// and then never paused again.
    func isQuiet(answered: Date?) -> Bool {
        guard falling == nil else { return false }
        guard let landing else { return true }
        return landing.at == answered
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
                                   gridHeight: CGFloat) -> TowerSkyline
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
        return TowerSkyline(originX: originX,
                            columnWidth: cellSize,
                            gutter: gutter,
                            tops: tops,
                            floorY: floorY,
                            hasTower: any)
    }

    var pitch: CGFloat { columnWidth + gutter }

    func columnIndex(atX x: CGFloat) -> Int {
        guard pitch > 0 else { return 0 }
        let raw = Int(((x - originX) / pitch).rounded(.down))
        return min(max(raw, 0), Self.columns - 1)
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

    /// The highest roof on the tower, which is the thing the drift band has
    /// to stay clear of on a tall tower.
    var highestTop: CGFloat {
        var best = CGFloat(tops[0])
        for c in 1..<Self.columns { best = min(best, CGFloat(tops[c])) }
        return best
    }
}

// MARK: - The simulation

/// **A head that lives on the Wins screen, as a pure simulation.**
///
/// The owner, 2026-09-23: "for the head I want it to be added to the Wins
/// screen as an option, where it kinda just floats on the top, around,
/// bouncing off the walls, and you can kinda move around, and it will react to
/// things happening, like a block flying near him or placing a block.
/// Occasionally he can drop down and jump along the tops of the blocks, making
/// sure to jump out of the way of the blocks falling."
///
/// **No SwiftUI in here, on purpose.** Everything that could be wrong about a
/// companion is arithmetic: does it leave the box, does it stand inside a
/// block, does it get out of the way in time, does it ever stop. Those are
/// questions a test can answer in milliseconds, and CLAUDE.md is full of
/// features that looked right in a screenshot and were not.
///
/// **A fixed step, and a positional resolve.** `update` accumulates real time
/// and runs whole ticks of `Self.tick`, so the motion is the same at 60Hz and
/// at 120Hz and is reproducible in a test. Every wall, every surface and the
/// slot are resolved by MOVING the head, not by reversing its velocity and
/// hoping: at 20,000 points a second a velocity-only bounce walks straight
/// through a wall between two ticks, and this cannot.
///
/// **It stops.** `docs/design-system-future.md`: "Nothing loops. Nothing
/// idles." A drifting head is damped, so it bounces a few times and comes to
/// rest, and `isAtRest` is what tells the layer to ask the system for no more
/// frames. It is woken by something happening, which is the same rule the
/// lattice follows.
///
/// The whole API is three calls: `init`, `update`, and `touch` when a finger
/// is on it.
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

    /// Per tick. 0.985^60 is 0.40, so a drift halves about every second and a
    /// half and is under the rest floor within a few seconds.
    static let driftDamping: CGFloat = 0.985
    static let airDamping: CGFloat = 0.999
    /// A wall gives most of the speed back; the tower's roof does not, because
    /// a head bouncing off a block reads as rubber.
    static let wallRestitution: CGFloat = 0.62
    static let groundRestitution: CGFloat = 0.30

    /// Under this, for `restHold`, and it is asleep.
    static let restSpeed: CGFloat = 7
    static let restHold: TimeInterval = 0.7

    /// How hard a wake pushes it, and how hard it can be thrown.
    static let wakeSpeed: ClosedRange<Double> = 70...130
    static let maxThrow: CGFloat = 1800

    /// A hop clears 68 points at the top of its arc, which is most of a cell.
    /// A hop onto a column more than that above it is not attempted; it
    /// crosses to one it can reach instead.
    static let hopUp: CGFloat = 760
    static let hopSide: CGFloat = 230
    static let hopGap: ClosedRange<Double> = 0.5...1.1
    static let hopsPerVisit: ClosedRange<Double> = 2...5

    /// **How often a landing sends it down to the tower.** The owner said
    /// "occasionally", and occasionally is the whole charm of it: a head that
    /// went down on every win would be a thing you have to look past to see
    /// your tower.
    static let visitChance: Double = 0.34

    /// A flinch is short. Anything longer reads as a performance.
    static let startleHold: TimeInterval = 0.22
    static let startleSpeed: CGFloat = 260
    /// How near a falling block has to pass before it is noticed.
    static let noticeRadius: CGFloat = 130

    /// The clear air it wants on either side of a falling block, and how hard
    /// it moves to get there.
    static let dodgeMargin: CGFloat = 18
    static let escapeSpeed: CGFloat = 460

    /// The head leans into its own movement, and no further. Degrees.
    static let maxTilt: Double = 12
    static let tiltPerPoint: Double = 1.0 / 34.0

    // MARK: State

    private(set) var state: State = .drifting
    private(set) var position: CGPoint = .zero
    private(set) var velocity: CGVector = .zero
    /// Degrees. A lean into the direction of travel, for the view.
    private(set) var tilt: Double = 0
    /// True when nothing will move again until something happens.
    private(set) var isAtRest = false

    /// The head's own radius, in points. Everything is resolved as a circle:
    /// a head is round enough and a circle has no corner to catch on a wall.
    var radius: CGFloat
    /// Reduce Motion holds it still. The owner asked for an option, not for
    /// a disappearance, so this parks the head and stops the clock rather
    /// than removing it.
    var reduceMotion = false

    /// The landing already answered, compared on its moment.
    private(set) var answeredLanding: Date?
    /// True once a falling block has been seen; cleared when it lands, so the
    /// next fall startles again.
    private var sawFalling = false

    private var accumulator: TimeInterval = 0
    private var time: TimeInterval = 0
    private var stateAge: TimeInterval = 0
    private var slowFor: TimeInterval = 0
    private var hopCooldown: TimeInterval = 0
    private var hopsLeft = 0
    /// How long he has been off the roof while meant to be on it.
    private var airborne: TimeInterval = 0
    /// The dodge began with his feet on a block, so it is a jump and gravity
    /// brings him back down. A dodge that began in the air is a sidestep and
    /// must not turn into a fall.
    private var dodgeGrounded = false
    private var grip: CGPoint = .zero
    private var rng: UInt64

    /// `seed` exists so a test can walk the same race twice. It is never set
    /// from the app; the head is meant to be different every time.
    init(radius: CGFloat, seed: UInt64 = 0x5EED_1EAF) {
        self.radius = radius
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
        guard !reduceMotion else { park(in: world); return }

        notice(world)

        accumulator = min(accumulator + max(elapsed, 0),
                          Self.tick * Double(Self.maxTicks))
        while accumulator >= Self.tick {
            accumulator -= Self.tick
            advance(world)
        }
        tilt = clamp(Double(velocity.dx) * Self.tiltPerPoint,
                     -Self.maxTilt, Self.maxTilt)
    }

    // MARK: The one touch input

    /// A finger on the head. `velocity` is only read on `.ended`, and it is
    /// the throw.
    ///
    /// `apple-design.md`: respond on pointer DOWN and continuously during the
    /// gesture, and project momentum on release rather than snapping from the
    /// release point. So `.began` takes it out of whatever it was doing on the
    /// same frame, `.moved` puts it exactly under the finger, and `.ended`
    /// hands its own speed to the simulation instead of dropping it.
    mutating func touch(_ phase: Touch, at point: CGPoint, velocity v: CGVector = .zero) {
        switch phase {
        case .began:
            state = .held
            stateAge = 0
            isAtRest = false
            slowFor = 0
            grip = point
            position = point
            velocity = .zero
        case .moved:
            guard state == .held else { return }
            // The finger's own movement, so a flick that ends in one frame
            // still has a speed to give away.
            velocity = CGVector(dx: (point.x - grip.x) / CGFloat(Self.tick),
                                dy: (point.y - grip.y) / CGFloat(Self.tick))
            grip = point
            position = point
        case .ended:
            guard state == .held else { return }
            let speed = hypot(v.dx, v.dy)
            let scale = speed > Self.maxThrow ? Self.maxThrow / speed : 1
            velocity = CGVector(dx: v.dx * scale, dy: v.dy * scale)
            enter(.thrown)
        }
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
            if world.skyline.hasTower,
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

    /// A recoil away from a point, scaled by how close it was, and a wake.
    private mutating func startle(awayFrom point: CGPoint, world: TowerCompanionWorld) {
        guard state != .held else { return }
        isAtRest = false
        slowFor = 0
        var away = CGVector(dx: position.x - point.x, dy: position.y - point.y)
        let d = max(hypot(away.dx, away.dy), 1)
        away = CGVector(dx: away.dx / d, dy: away.dy / d)
        // Falls off with distance, so a landing on the far side of the tower
        // is a twitch and one under his feet is a jump.
        let near = clamp(Double(1 - d / (Self.noticeRadius * 2.5)), 0.18, 1)
        let push = Self.startleSpeed * CGFloat(near)
        velocity.dx += away.dx * push
        velocity.dy += away.dy * push
        if state == .resting || state == .drifting { enter(.startled) }
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

        if state == .resting {
            // Nothing to do, and nothing will happen until `notice` or `touch`
            // wakes him. The one exception: a block coming down on a sleeping
            // head. He does not get to sleep through that.
            guard let f = world.falling, threatened(by: f) else { return }
            enter(.drifting)
        }

        think(world)

        let dt = CGFloat(Self.tick)
        let falls = state == .thrown || state == .descending || state == .hopping
            || (state == .dodging && dodgeGrounded)
        if falls {
            velocity.dy += Self.gravity * dt
            velocity.dx *= Self.airDamping
        } else if state != .held && state != .resting {
            // No gravity in the air band. He is floating, not falling, and
            // gravity up here would make every reaction end on the floor.
            velocity.dx *= Self.driftDamping
            velocity.dy *= Self.driftDamping
        }

        if state == .returning {
            // A pull toward the middle of the drift band, damped, so he rises
            // and settles rather than shooting through it.
            let target = (world.driftBand.lowerBound + world.driftBand.upperBound) / 2
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

        resolve(world, landing: state == .thrown || state == .descending || state == .hopping)
        settle(world)
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
            enter(world.skyline.hasTower && onSurface(world) ? .hopping : .returning)
        }

        if state == .startled, stateAge >= Self.startleHold { enter(.drifting) }

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
        let lane = falling.insetBy(dx: -(Self.dodgeMargin + radius), dy: 0)
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
        let pad = Self.dodgeMargin + radius + 2
        let left = falling.minX - pad
        let right = falling.maxX + pad
        let lo = world.bounds.minX + radius
        let hi = world.bounds.maxX - radius
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
        let loX = world.bounds.minX + radius
        let hiX = world.bounds.maxX - radius
        let loY = world.bounds.minY + radius
        let hiY = world.bounds.maxY - radius

        if hiX <= loX {
            position.x = world.bounds.midX
            velocity.dx = 0
        } else if position.x < loX {
            position.x = loX
            velocity.dx = abs(velocity.dx) * Self.wallRestitution
        } else if position.x > hiX {
            position.x = hiX
            velocity.dx = -abs(velocity.dx) * Self.wallRestitution
        }

        if hiY <= loY {
            position.y = world.bounds.midY
            velocity.dy = 0
        } else if position.y < loY {
            position.y = loY
            velocity.dy = abs(velocity.dy) * Self.wallRestitution
        } else if position.y > hiY {
            position.y = hiY
            velocity.dy = -abs(velocity.dy) * Self.groundRestitution
            if landing { arrive(world) }
        }

        // The drift band is a ceiling and a floor of its own while he is up
        // there, so floating "on the top" means on the top rather than
        // anywhere in the page.
        if state == .drifting || state == .startled {
            let floor = min(world.driftBand.upperBound,
                            world.skyline.hasTower
                            ? world.skyline.highestTop - radius - 8
                            : world.bounds.maxY)
            let ceiling = max(world.driftBand.lowerBound, loY)
            if position.y < ceiling {
                position.y = ceiling
                velocity.dy = abs(velocity.dy) * Self.wallRestitution
            } else if position.y > max(floor, ceiling) {
                position.y = max(floor, ceiling)
                velocity.dy = -abs(velocity.dy) * Self.wallRestitution
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

    /// **The block being placed is never covered.**
    ///
    /// Pushed out along the shorter way, because the shorter way is the one
    /// that looks like him getting out of the way rather than teleporting
    /// round the block.
    private mutating func pushOutOfSlot(_ world: TowerCompanionWorld) {
        guard let slot = world.slot else { return }
        let box = slot.insetBy(dx: -radius, dy: -radius)
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

    // MARK: Coming to rest

    private mutating func settle(_ world: TowerCompanionWorld) {
        if state == .returning, world.driftBand.contains(position.y),
           abs(velocity.dy) < 60 {
            enter(.drifting)
        }

        if state == .thrown, speed < 90 {
            enter(onSurface(world) ? .hopping : .returning)
        }

        // **Only a drifting head is allowed to fall asleep.** A head on the
        // tower has somewhere to be, and it goes back up before it stops.
        guard state == .drifting else { slowFor = 0; return }
        if speed < Self.restSpeed {
            slowFor += Self.tick
            if slowFor >= Self.restHold {
                velocity = .zero
                isAtRest = true
                state = .resting
            }
        } else {
            slowFor = 0
        }
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
        let x = clamp(world.bounds.maxX - radius - 12,
                      world.bounds.minX + radius, world.bounds.maxX - radius)
        let y = clamp(world.driftBand.lowerBound + radius + 6,
                      world.bounds.minY + radius, world.bounds.maxY - radius)
        position = CGPoint(x: x, y: y)
        if let slot = world.slot {
            let box = slot.insetBy(dx: -radius, dy: -radius)
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

    /// Puts the head somewhere sensible the first time the layer has a size.
    mutating func place(in world: TowerCompanionWorld) {
        position = CGPoint(x: world.bounds.midX + world.bounds.width * 0.22,
                           y: (world.driftBand.lowerBound + world.driftBand.upperBound) / 2)
        let sideways = CGFloat(random(in: Self.wakeSpeed))
        velocity = CGVector(dx: random() < 0.5 ? -sideways : sideways,
                            dy: CGFloat(random(in: -40...40)))
        state = .drifting
        isAtRest = false
        slowFor = 0
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
