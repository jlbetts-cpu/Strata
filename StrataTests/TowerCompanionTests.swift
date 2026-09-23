import Testing
import CoreGraphics
import Foundation
@testable import Strata

/// **The companion head, measured rather than looked at.**
///
/// Everything that can be wrong about a floating head is arithmetic: does it
/// leave the box, does it stand inside a block, does it get out of the way
/// before the block arrives, and does it ever stop. CLAUDE.md is full of
/// features that were green in a screenshot and broken in the app, and this one
/// cannot be photographed at all: it is in motion, and
/// `simctl io screenshot` samples at about 3Hz.
///
/// So the simulation is pure and these walk it step by step. A failure here
/// names the frame it went wrong on.
@Suite("The tower companion")
struct TowerCompanionTests {

    // MARK: Fixtures

    /// A 14 inch phone's worth of arena, and a tower four columns wide.
    private let cell: CGFloat = 86
    private let arenaWidth: CGFloat = 393
    private let arenaHeight: CGFloat = 700

    private var gutter: CGFloat { GridConstants.spacing }
    private var gridWidth: CGFloat { 4 * cell + 3 * gutter }
    private var originX: CGFloat { (arenaWidth - gridWidth) / 2 }

    private var bounds: CGRect {
        CGRect(x: 0, y: 8, width: arenaWidth, height: arenaHeight - 8 - 118)
    }

    /// A tower with a different height in every column, so the roofline is a
    /// real staircase rather than a flat line that would hide a bug.
    private func skyline(_ heights: [Int]) -> TowerSkyline {
        var cells: [TowerCompanionWorld.Cell] = []
        for (column, rows) in heights.enumerated() {
            for row in 0..<rows {
                cells.append(TowerCompanionWorld.Cell(column, row, 1, 1))
            }
        }
        let rows = heights.max() ?? 0
        let gridHeight = rows > 0
            ? CGFloat(rows) * cell + CGFloat(rows - 1) * gutter
            : 0
        // The grid sits on the bottom of the arena, as it does in the app.
        let gridTopY = bounds.maxY - gridHeight
        return TowerSkyline.build(cells: cells, originX: originX, cellSize: cell,
                                  gutter: gutter, gridTopY: gridTopY,
                                  gridHeight: gridHeight)
    }

    private func world(_ heights: [Int] = [2, 1, 3, 1],
                       slot: CGRect? = nil,
                       falling: CGRect? = nil,
                       landing: TowerCompanionWorld.Landing? = nil) -> TowerCompanionWorld {
        TowerCompanionWorld(bounds: bounds, skyline: skyline(heights),
                            slot: slot, falling: falling, landing: landing)
    }

    private func sim(seed: UInt64 = 0xC0FFEE) -> TowerCompanionSim {
        var s = TowerCompanionSim(radius: TowerCompanion.side * TowerCompanion.radiusShare,
                                  seed: seed)
        s.place(in: world())
        return s
    }

    /// One second of simulated time, as whole ticks.
    private func run(_ s: inout TowerCompanionSim, _ w: TowerCompanionWorld,
                     seconds: Double) {
        let ticks = Int((seconds / TowerCompanionSim.tick).rounded())
        for _ in 0..<ticks { s.update(w, elapsed: TowerCompanionSim.tick) }
    }

    // MARK: The grid this is all built on

    /// The skyline is four numbers in a register. If the tower ever grows a
    /// fifth column this fails, rather than the head quietly forgetting it.
    @Test func theGridIsStillFourColumnsWide() {
        #expect(TowerSkyline.columns == GridConstants.columnCount)
    }

    /// **The roofline has to be the tower's own arithmetic**, or the head
    /// stands a gutter inside the block it is meant to be standing on. Four
    /// points does not show in a screenshot and it does here.
    @Test func theRooflineIsTheTowersOwnGrid() {
        let heights = [2, 1, 3, 1]
        let s = skyline(heights)
        let rows = 3
        let gridHeight = CGFloat(rows) * cell + CGFloat(rows - 1) * gutter
        let gridTopY = bounds.maxY - gridHeight

        for (column, filled) in heights.enumerated() {
            // The same expression `MainAppView.flippedY` puts a block at:
            // `gridHeight - frame.minY - frame.height`, plus the grid's own top.
            let frame = GridConstants.blockFrame(column: column, row: filled - 1,
                                                 columnSpan: 1, rowSpan: 1,
                                                 cellSize: cell)
            let expected = gridTopY + gridHeight - frame.minY - frame.height
            #expect(abs(s.top(ofColumn: column) - expected) < 0.01,
                    "column \(column) roofline")
        }
        #expect(s.hasTower)
    }

    /// An empty tower has no roof, and the head must not try to stand on one.
    @Test func anEmptyTowerHasNoRoofline() {
        let s = skyline([0, 0, 0, 0])
        #expect(!s.hasTower)
    }

    // MARK: It stays inside its box

    @Test func itStaysInsideItsBounds() {
        var s = sim()
        let w = world()
        // Poked in a new direction every third of a second for a minute, which
        // is far more than anybody will do to it, and it never leaves.
        for burst in 0..<180 {
            let angle = Double(burst) * 0.37
            let v = CGVector(dx: CGFloat(cos(angle)) * 900, dy: CGFloat(sin(angle)) * 900)
            s.touch(.began, at: s.position)
            s.touch(.ended, at: s.position, velocity: v)
            run(&s, w, seconds: 1.0 / 3.0)
            #expect(inside(s, w), "burst \(burst) left the box at \(s.position)")
        }
    }

    /// **The one that a velocity only bounce fails.** At twenty thousand points
    /// a second a head travels 333 points between two ticks, which is most of
    /// the screen: reversing the velocity leaves it outside the box, and the
    /// next tick takes it further out. Every wall here is resolved by moving
    /// the head, so no speed can get through one.
    @Test func itNeverTunnelsThroughAWall() {
        let w = world()
        let speeds: [CGFloat] = [2_000, 20_000, 200_000]
        let directions: [CGVector] = [
            CGVector(dx: 1, dy: 0), CGVector(dx: -1, dy: 0),
            CGVector(dx: 0, dy: 1), CGVector(dx: 0, dy: -1),
            CGVector(dx: 0.7, dy: 0.7), CGVector(dx: -0.7, dy: -0.7)
        ]
        for speed in speeds {
            for d in directions {
                var s = sim()
                s.touch(.began, at: CGPoint(x: w.bounds.midX, y: w.bounds.minY + 60))
                s.touch(.ended, at: CGPoint(x: w.bounds.midX, y: w.bounds.minY + 60),
                        velocity: CGVector(dx: d.dx * speed, dy: d.dy * speed))
                for tick in 0..<240 {
                    s.update(w, elapsed: TowerCompanionSim.tick)
                    #expect(inside(s, w),
                            "speed \(speed) direction (\(d.dx), \(d.dy)) tick \(tick): \(s.position)")
                }
            }
        }
    }

    /// A throw is capped, so a flick cannot hand the simulation a number it
    /// then has to survive.
    @Test func aThrowIsCapped() {
        var s = sim()
        s.touch(.began, at: CGPoint(x: 100, y: 100))
        s.touch(.ended, at: CGPoint(x: 100, y: 100),
                velocity: CGVector(dx: 50_000, dy: -50_000))
        #expect(s.speed <= TowerCompanionSim.maxThrow + 0.01)
    }

    // MARK: It keeps off what you are doing

    /// **The slot is the one rectangle he may never cover.** Logging a win is
    /// the fastest thing in the app; a head sitting on the button is a toy in
    /// front of the product.
    @Test func itKeepsClearOfTheBlockBeingPlaced() {
        // A slot right in the middle of the drift band, which is the worst
        // case and not a case the app often has.
        let slot = CGRect(x: originX + cell, y: bounds.minY + 40, width: cell * 2, height: cell)
        let w = world(slot: slot)
        var s = sim()
        let radius = s.radius
        for burst in 0..<90 {
            let angle = Double(burst) * 0.91
            // Thrown straight at the slot, over and over.
            s.touch(.began, at: s.position)
            s.touch(.ended, at: s.position,
                    velocity: CGVector(dx: CGFloat(cos(angle)) * 1_200,
                                       dy: CGFloat(sin(angle)) * 1_200))
            for _ in 0..<40 {
                s.update(w, elapsed: TowerCompanionSim.tick)
                let box = slot.insetBy(dx: -radius, dy: -radius)
                #expect(!box.contains(s.position),
                        "burst \(burst): he was on the slot at \(s.position)")
            }
        }
    }

    // MARK: Out of the way

    /// **He always leaves a falling block's path.**
    ///
    /// The block starts above him and comes down his column. This asserts the
    /// thing that actually matters: by the time the block reaches him, he is
    /// not under it. Run at both of the two cases, standing on the tower and
    /// drifting, because the dodge is a jump in one and a sidestep in the
    /// other.
    @Test(arguments: [true, false])
    func itLeavesAFallingBlocksPath(fromTheRoof: Bool) {
        let heights = [2, 1, 3, 1]
        var s = sim()
        // Put him directly over column 1, which is where the block will fall.
        let lane = CGRect(x: originX + (cell + gutter), y: 0, width: cell, height: cell)
        let sky = skyline(heights)
        let startY = fromTheRoof
            ? sky.top(ofColumn: 1) - s.radius
            : bounds.minY + 40
        s.touch(.began, at: CGPoint(x: lane.midX, y: startY))
        s.touch(.ended, at: CGPoint(x: lane.midX, y: startY), velocity: .zero)

        // The block falls at the app's own g from above the screen, which is
        // how a real drop arrives (CLAUDE.md: the fall starts off screen).
        var blockY = startY - 520
        var blockV: CGFloat = 0
        var cleared = false
        for tick in 0..<600 {
            let falling = CGRect(x: lane.minX, y: blockY, width: cell, height: cell)
            let w = world(heights, falling: falling)
            s.update(w, elapsed: TowerCompanionSim.tick)

            blockV += TowerCompanionSim.gravity * CGFloat(TowerCompanionSim.tick)
            blockY += blockV * CGFloat(TowerCompanionSim.tick)

            // The moment the block's bottom edge reaches his top edge is the
            // moment the answer has to already be yes.
            if blockY + cell >= s.position.y - s.radius {
                let clear = s.position.x < falling.minX - s.radius
                    || s.position.x > falling.maxX + s.radius
                #expect(clear,
                        "tick \(tick): the block reached him at x \(s.position.x), lane \(falling.minX) to \(falling.maxX)")
                cleared = true
                break
            }
        }
        #expect(cleared, "the block never got down to him, so nothing was tested")
    }

    /// A block falling nowhere near him is not his business. The flinch is
    /// proportional, and at the far side of the screen it is nothing.
    @Test func aBlockFallingElsewhereDoesNotMoveHimIntoIt() {
        var s = sim()
        let lane = CGRect(x: originX, y: bounds.minY, width: cell, height: cell)
        // Park him on the far right.
        let far = CGPoint(x: bounds.maxX - s.radius - 4, y: bounds.minY + 40)
        s.touch(.began, at: far)
        s.touch(.ended, at: far, velocity: .zero)
        let w = world(falling: lane)
        for _ in 0..<120 { s.update(w, elapsed: TowerCompanionSim.tick) }
        #expect(s.position.x > lane.maxX + s.radius)
    }

    // MARK: It stops

    /// **It comes to rest rather than jittering for ever.**
    ///
    /// `docs/design-system-future.md`: "Nothing loops. Nothing idles." This is
    /// the assertion that lets the layer pause its clock, so a Wins screen
    /// nobody is touching asks the system for no frames at all. Without it the
    /// feature is a permanent 60Hz tax on the one screen that must never
    /// stutter.
    @Test func itComesToRest() {
        var s = sim()
        let w = world()
        s.touch(.began, at: CGPoint(x: w.bounds.midX, y: w.bounds.minY + 50))
        s.touch(.ended, at: CGPoint(x: w.bounds.midX, y: w.bounds.minY + 50),
                velocity: CGVector(dx: 900, dy: 260))
        run(&s, w, seconds: 60)
        #expect(s.isAtRest, "still moving after a minute, state \(s.state), speed \(s.speed)")

        // And it stays put: a head that rests and then creeps is a head the
        // clock can never be stopped for.
        let where1 = s.position
        run(&s, w, seconds: 10)
        #expect(abs(s.position.x - where1.x) < 0.001)
        #expect(abs(s.position.y - where1.y) < 0.001)
    }

    /// A landing wakes him, which is the other half of the contract: a clock
    /// that stops has to be startable by something the person did.
    @Test func aLandingWakesHim() {
        var s = sim()
        let quiet = world()
        run(&s, quiet, seconds: 60)
        #expect(s.isAtRest)
        let asleep = s.position

        let landed = TowerCompanionWorld.Landing(
            at: Date(),
            rect: CGRect(x: originX, y: asleep.y + 30, width: cell, height: cell))
        let loud = world(landing: landed)
        run(&s, loud, seconds: 0.5)
        #expect(!s.isAtRest)
        #expect(hypot(s.position.x - asleep.x, s.position.y - asleep.y) > 1,
                "the landing did not move him")
    }

    /// **The same landing, handed over on every frame of its ripple, is
    /// answered once.** `MainAppView` holds `latticeRipple` for the whole life
    /// of the ring, which is up to 0.66s, so forty frames carry the same
    /// landing. Answering it on each of them would be a shove, not a flinch.
    ///
    /// Proved by comparison rather than by a threshold: a head given the
    /// landing for forty frames must end up exactly where a head given it for
    /// one frame does.
    @Test func oneLandingIsAnsweredOnce() {
        var held = sim(seed: 777)
        var once = sim(seed: 777)
        let quiet = world()
        run(&held, quiet, seconds: 30)
        run(&once, quiet, seconds: 30)

        let landed = TowerCompanionWorld.Landing(
            at: Date(),
            rect: CGRect(x: originX, y: held.position.y + 30, width: cell, height: cell))
        let loud = world(landing: landed)

        held.update(loud, elapsed: TowerCompanionSim.tick)
        once.update(loud, elapsed: TowerCompanionSim.tick)
        for _ in 0..<40 {
            held.update(loud, elapsed: TowerCompanionSim.tick)
            once.update(quiet, elapsed: TowerCompanionSim.tick)
        }
        #expect(held.position == once.position,
                "the landing was answered more than once")
        #expect(held.state == once.state)
    }

    /// The world is quiet once the landing has been answered, and quiet again
    /// once the caller clears it. The second half is the bug this test exists
    /// for: comparing `landing?.at` to the answered date made a cleared ripple
    /// look like news for ever, and the clock could never pause again.
    @Test func aClearedLandingIsQuiet() {
        let at = Date()
        let landed = TowerCompanionWorld.Landing(at: at, rect: .zero)
        #expect(!world(landing: landed).isQuiet(answered: nil))
        #expect(world(landing: landed).isQuiet(answered: at))
        #expect(world().isQuiet(answered: at))
        #expect(!world(falling: CGRect(x: 0, y: 0, width: 10, height: 10)).isQuiet(answered: at))
    }

    // MARK: Reduce Motion

    /// **Reduce Motion turns the movement off and leaves the head there.** The
    /// owner asked for the head as an option; Reduce Motion is a statement
    /// about motion, so taking the head away would be answering a question
    /// nobody asked.
    @Test func reduceMotionHoldsHimStill() {
        var s = sim()
        s.reduceMotion = true
        let w = world()
        s.update(w, elapsed: TowerCompanionSim.tick)
        let parked = s.position
        #expect(s.isAtRest)

        // A landing, a falling block and a throw all change nothing.
        let landed = TowerCompanionWorld.Landing(at: Date(), rect: CGRect(x: originX, y: parked.y, width: cell, height: cell))
        let loud = world(falling: CGRect(x: parked.x - 10, y: parked.y - 200, width: cell, height: cell),
                         landing: landed)
        s.touch(.began, at: CGPoint(x: 10, y: 10))
        s.touch(.ended, at: CGPoint(x: 10, y: 10), velocity: CGVector(dx: 1_500, dy: 1_500))
        run(&s, loud, seconds: 10)
        #expect(s.isAtRest)
        #expect(abs(s.position.x - parked.x) < 0.001)
        #expect(abs(s.position.y - parked.y) < 0.001)
        #expect(s.tilt == 0)
        #expect(inside(s, w))
    }

    // MARK: On the tower

    /// He never sinks into a block. Standing inside the thing you are standing
    /// on is the one way a companion can look broken while every number about
    /// it looks fine.
    @Test func heStandsOnTheBlocksAndNotInThem() {
        let heights = [2, 1, 3, 1]
        var s = sim()
        // Drop him onto the roof and then let him get on with it.
        let start = CGPoint(x: skyline(heights).centreX(ofColumn: 2), y: bounds.minY + 30)
        s.touch(.began, at: start)
        s.touch(.ended, at: start, velocity: CGVector(dx: 40, dy: 900))
        let w = world(heights)
        var everStood = false
        for tick in 0..<1_800 {
            s.update(w, elapsed: TowerCompanionSim.tick)
            let surface = w.skyline.surfaceY(atX: s.position.x) - s.radius
            // A tolerance of one tick of fall at this g, because the resolve
            // happens after the integration and the last frame of a fall is
            // allowed to have gone slightly past.
            #expect(s.position.y <= surface + 1.0,
                    "tick \(tick): sank to \(s.position.y), roof at \(surface)")
            if s.onSurface(w) { everStood = true }
        }
        #expect(everStood, "he never actually reached the tower, so nothing was tested")
    }

    // MARK: Determinism

    /// Same seed, same head. This is what makes every test above repeatable
    /// and a failure worth reading.
    @Test func theSimulationIsDeterministic() {
        var a = sim(seed: 12_345)
        var b = sim(seed: 12_345)
        let w = world()
        let landed = TowerCompanionWorld.Landing(at: Date(), rect: CGRect(x: originX, y: bounds.minY + 100, width: cell, height: cell))
        let loud = world(landing: landed)
        run(&a, loud, seconds: 3)
        run(&b, loud, seconds: 3)
        run(&a, w, seconds: 3)
        run(&b, w, seconds: 3)
        #expect(a.position == b.position)
        #expect(a.state == b.state)
    }

    /// A long stall does not teleport him across the screen. The first frame
    /// after a tab appears, and any frame the main thread was late for, hands
    /// the simulation a huge elapsed.
    @Test func aStalledFrameIsCapped() {
        var s = sim()
        let w = world()
        s.touch(.began, at: CGPoint(x: w.bounds.midX, y: w.bounds.minY + 40))
        s.touch(.ended, at: CGPoint(x: w.bounds.midX, y: w.bounds.minY + 40),
                velocity: CGVector(dx: 1_200, dy: 0))
        let before = s.position
        s.update(w, elapsed: 8.0)
        let travelled = hypot(s.position.x - before.x, s.position.y - before.y)
        // Four ticks at most, so at 1200 points a second that is 80 points.
        #expect(travelled < 120, "one stalled frame moved him \(travelled)")
        #expect(inside(s, w))
    }

    // MARK: Helpers

    private func inside(_ s: TowerCompanionSim, _ w: TowerCompanionWorld) -> Bool {
        s.position.x >= w.bounds.minX + s.radius - 0.01
            && s.position.x <= w.bounds.maxX - s.radius + 0.01
            && s.position.y >= w.bounds.minY + s.radius - 0.01
            && s.position.y <= w.bounds.maxY - s.radius + 0.01
    }
}
