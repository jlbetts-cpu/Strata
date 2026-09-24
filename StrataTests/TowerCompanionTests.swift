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
        var s = TowerCompanionSim(halfWidth: TowerCompanion.side * TowerCompanion.inkHalfWidth,
                                  halfHeight: TowerCompanion.side * TowerCompanion.inkHalfHeight,
                                  seed: seed)
        s.place(in: world())
        return s
    }

    /// **The same head with the gated behaviours turned on.**
    ///
    /// Dropping to the tower, hopping and dodging are off in the app (owner,
    /// 2026-09-23: "I would focus on just making it floating for now, bouncing
    /// around, and polishing it to the max"). They are gated, not deleted, so
    /// these still walk them: a gate with no test behind it is how code rots
    /// while looking present.
    private func towerSim(seed: UInt64 = 0xC0FFEE,
                          every: ClosedRange<Double> = 6...6) -> TowerCompanionSim {
        var s = TowerCompanionSim(halfWidth: TowerCompanion.side * TowerCompanion.inkHalfWidth,
                                  halfHeight: TowerCompanion.side * TowerCompanion.inkHalfHeight,
                                  seed: seed)
        s.visitsTheTower = true
        s.visitInterval = every
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
            s.touch(.began, at: s.position, in: w)
            s.touch(.ended, at: s.position, velocity: v, in: w)
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
                s.touch(.began, at: CGPoint(x: w.bounds.midX, y: w.bounds.minY + 60), in: w)
                s.touch(.ended, at: CGPoint(x: w.bounds.midX, y: w.bounds.minY + 60),
                        velocity: CGVector(dx: d.dx * speed, dy: d.dy * speed), in: w)
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
        s.touch(.began, at: CGPoint(x: 100, y: 100), in: w)
        s.touch(.ended, at: CGPoint(x: 100, y: 100),
                velocity: CGVector(dx: 50_000, dy: -50_000), in: w)
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
        let halfW = s.halfWidth
        let halfH = s.halfHeight
        for burst in 0..<90 {
            let angle = Double(burst) * 0.91
            // Thrown straight at the slot, over and over.
            s.touch(.began, at: s.position, in: w)
            s.touch(.ended, at: s.position,
                    velocity: CGVector(dx: CGFloat(cos(angle)) * 1_200,
                                       dy: CGFloat(sin(angle)) * 1_200), in: w)
            for _ in 0..<40 {
                s.update(w, elapsed: TowerCompanionSim.tick)
                let box = slot.insetBy(dx: -halfW, dy: -halfH)
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
        // The gated sim: dodging is off in the app, so this is the test that
        // keeps it honest for when it comes back.
        var s = towerSim()
        let w = world(heights)
        // Put him directly over column 1, which is where the block will fall.
        let lane = CGRect(x: originX + (cell + gutter), y: 0, width: cell, height: cell)
        let sky = skyline(heights)
        let startY = fromTheRoof
            ? sky.top(ofColumn: 1) - s.halfHeight
            : bounds.minY + 40
        s.place(in: w, at: CGPoint(x: lane.midX, y: startY))

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
            if blockY + cell >= s.position.y - s.halfHeight {
                let clear = s.position.x < falling.minX - s.halfWidth
                    || s.position.x > falling.maxX + s.halfWidth
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
        let far = CGPoint(x: bounds.maxX - s.halfWidth - 4, y: bounds.minY + 40)
        s.place(in: w, at: far)
        let w = world(falling: lane)
        for _ in 0..<120 { s.update(w, elapsed: TowerCompanionSim.tick) }
        #expect(s.position.x > lane.maxX + s.halfWidth)
    }

    // MARK: It stops

    /// **It never stops while it is on screen, and that is the first fix.**
    ///
    /// The first build damped the drift to nothing and slept, so the layer could
    /// stop its clock. Measured on a phone that is a head which moves for a few
    /// seconds after launch and is then a sticker: four pixels in two seconds.
    @Test func itKeepsDriftingForEver() {
        var s = sim()
        let w = world()
        run(&s, w, seconds: 120)
        #expect(!s.isAtRest)

        var travelled: CGFloat = 0
        var last = s.position
        for _ in 0..<Int(60 / TowerCompanionSim.tick) {
            s.update(w, elapsed: TowerCompanionSim.tick)
            travelled += hypot(s.position.x - last.x, s.position.y - last.y)
            last = s.position
        }
        // Measured over eight two minute runs: 760 to 1,060 points a minute.
        #expect(travelled > 700, "a minute of drift covered only \(travelled) points")
    }

    /// **The motion is a body in air, and these are the numbers that say so.**
    ///
    /// The owner's note on the second build was "the animations do not feel
    /// natural at all", and a held constant speed was why. So:
    ///
    /// - the speed is never even (a standard deviation, not just a mean),
    /// - it never goes fast enough to read as a game,
    /// - it uses the whole width of the screen rather than a corner of it,
    /// - and the head rotates, so it has mass rather than sliding like a sticker.
    @Test func theFloatMovesLikeSomethingWithWeight() {
        for seed in [UInt64(1), 2, 3] {
            var s = TowerCompanionSim(halfWidth: TowerCompanion.side * TowerCompanion.inkHalfWidth,
                                      halfHeight: TowerCompanion.side * TowerCompanion.inkHalfHeight,
                                      seed: seed)
            let w = world()
            s.place(in: w)
            var speeds: [CGFloat] = []
            var xs: [CGFloat] = []
            var tilts: [Double] = []
            // **Two minutes, not one, and that is measured rather than
            // generous.** The float is a random process, so a one minute
            // sample's horizontal sweep ranges from 43% to 100% of the screen
            // over 24 seeds: a real head looks fine in every one of those and a
            // test on it fails about one run in eight. At two minutes the mean
            // is 100% and the worst of 24 seeds is 95%.
            for _ in 0..<Int(120 / TowerCompanionSim.tick) {
                s.update(w, elapsed: TowerCompanionSim.tick)
                speeds.append(s.speed)
                xs.append(s.position.x)
                tilts.append(s.tilt)
                #expect(s.state == .drifting || s.state == .startled,
                        "an ungated head reached \(s.state)")
            }
            let mean = speeds.reduce(0, +) / CGFloat(speeds.count)
            let sd = (speeds.map { ($0 - mean) * ($0 - mean) }.reduce(0, +)
                      / CGFloat(speeds.count)).squareRoot()
            #expect(mean > 10 && mean < 30, "seed \(seed) mean speed \(mean)")
            #expect(sd > 4, "seed \(seed) speed deviation \(sd): too even to be natural")
            #expect(speeds.max()! <= TowerCompanionSim.maxDrift + 0.5,
                    "seed \(seed) peaked at \(speeds.max()!)")
            // The centre has 329 points of usable range on this fixture.
            #expect(xs.max()! - xs.min()! > 260,
                    "seed \(seed) only covered \(xs.max()! - xs.min()!) points of 329 sideways")
            #expect(tilts.max()! - tilts.min()! > 3,
                    "seed \(seed) barely rotates: \(tilts.min()!) to \(tilts.max()!)")
        }
    }

    /// **Bouncing off the walls, which he asked for by name, and not a pinball.**
    ///
    /// The count is the whole assertion. Without the edge cushion it measured 369
    /// a minute, which is a head grinding along the side of the page rather than
    /// bouncing off it; with the cushion too strong it measured 0 to 2 and one
    /// run never crossed the screen. Four a minute is a real bounce about every
    /// fourteen seconds.
    @Test func itBouncesOffTheWallsWithoutChattering() {
        var s = sim()
        let w = world()
        run(&s, w, seconds: 120)
        #expect(s.wallHits >= 2, "only \(s.wallHits) wall bounces in two minutes")
        #expect(s.wallHits < 60, "\(s.wallHits) bounces in two minutes is chatter")
    }

    /// **The visible edge of the head reaches the visible edge of the screen.**
    ///
    /// The owner: "when it bounces off the sides it should actually look like
    /// it, like right now it's bouncing but it's not even touching the side."
    /// Two things were stopping it and both were mine: the body was a circle of
    /// 0.42 of the layout side inside a face 0.382 wide, and I had added ten
    /// points of clear air on top. Measured on glass the ink turned around
    /// thirteen points early. This is the assertion that keeps it honest.
    @Test func itsVisibleEdgeReachesTheWall() {
        var closestLeft = CGFloat.greatestFiniteMagnitude
        var closestRight = CGFloat.greatestFiniteMagnitude
        for seed in [UInt64(1), 2, 3, 4] {
            var s = TowerCompanionSim(halfWidth: TowerCompanion.side * TowerCompanion.inkHalfWidth,
                                      halfHeight: TowerCompanion.side * TowerCompanion.inkHalfHeight,
                                      seed: seed)
            let w = world()
            s.place(in: w)
            for _ in 0..<Int(180 / TowerCompanionSim.tick) {
                s.update(w, elapsed: TowerCompanionSim.tick)
                closestLeft = min(closestLeft, (s.position.x - s.halfWidth) - w.bounds.minX)
                closestRight = min(closestRight, w.bounds.maxX - (s.position.x + s.halfWidth))
            }
        }
        #expect(closestLeft < 0.5, "the ink never reached the left wall: \(closestLeft)pt short")
        #expect(closestRight < 0.5, "the ink never reached the right wall: \(closestRight)pt short")
    }

    /// **It crosses the whole screen and never looks stopped.**
    ///
    /// The owner: "make sure the head doesn't just stay to one side, like it
    /// should act kinda like the DVD logo." The model before this was a body in
    /// a wandering current, and measured over 24 runs of four minutes it spent
    /// up to 35 seconds at a time against one edge and had a quietest three
    /// seconds that moved it 0.4 points.
    ///
    /// Travel, not displacement: a head that bounces off a wall and comes
    /// straight back has moved the whole time and shows almost no displacement,
    /// so displacement reports a moving head as a stopped one.
    @Test func itCrossesTheWholeScreenAndNeverStalls() {
        let usable = (bounds.maxX - TowerCompanion.side * TowerCompanion.inkHalfWidth)
            - (bounds.minX + TowerCompanion.side * TowerCompanion.inkHalfWidth)
        var crossed = 0
        for seed in [UInt64(1), 2, 3, 4, 5, 6, 7, 8] {
            var s = TowerCompanionSim(halfWidth: TowerCompanion.side * TowerCompanion.inkHalfWidth,
                                      halfHeight: TowerCompanion.side * TowerCompanion.inkHalfHeight,
                                      seed: seed)
            let w = world()
            s.place(in: w)
            var track: [CGPoint] = []
            var slowest = CGFloat.greatestFiniteMagnitude
            for _ in 0..<Int(180 / TowerCompanionSim.tick) {
                s.update(w, elapsed: TowerCompanionSim.tick)
                track.append(s.position)
                slowest = min(slowest, s.speed)
            }
            let xs = track.map(\.x)
            let sweep = xs.max()! - xs.min()!
            if sweep > usable * 0.9 { crossed += 1 }
            // **A floor on every run and a distribution across them.** The tower
            // is an object in the same box now, so a run can spend a while in a
            // gap between two tall columns; measured over 40 runs against five
            // tower shapes, nine in ten still cover the whole width and the
            // worst covers 76% of it.
            #expect(sweep > usable * 0.6,
                    "seed \(seed) swept only \(sweep) of \(usable)")
            #expect(slowest > 3, "seed \(seed) stalled to \(slowest) points a second")

            var cum: [CGFloat] = [0]
            for i in 1..<track.count {
                cum.append(cum[i - 1] + hypot(track[i].x - track[i - 1].x,
                                              track[i].y - track[i - 1].y))
            }
            let k = Int(3.0 / TowerCompanionSim.tick)
            var quietest = CGFloat.greatestFiniteMagnitude
            var i = k * 3
            while i < track.count { quietest = min(quietest, cum[i] - cum[i - k]); i += 6 }
            // 35pt measured across 24 runs of three minutes. The build the
            // owner called parked managed 0.4pt over the same window.
            #expect(quietest > 25,
                    "seed \(seed): its quietest three seconds travelled \(quietest)pt")
        }
        #expect(crossed >= 6, "only \(crossed) of 8 runs crossed the whole screen")
    }

    /// **The tower is an object in the head's world, not the bottom of it.**
    ///
    /// The owner: "the head, I notice from the build I'm looking at, only stays
    /// near the top, never bouncing on the blocks below or anything, remaining
    /// on the same plane. I would prefer it to interact with all the elements."
    ///
    /// Three things have to be true at once and the middle one is the trap: it
    /// has to reach the blocks, it must never be left inside one, and it must
    /// never be moved a visible distance in a single frame. A y clamp to the
    /// roofline passes the first two and fails the third, because a tower is a
    /// staircase and a clamp lifts the head a whole row the moment its cheek
    /// reaches a taller column. See `towerEscape`.
    @Test func itMeetsTheTowerAndIsNeverInsideIt() {
        let heights = [3, 1, 4, 2]
        var met = 0
        var worstOverlap: CGFloat = 0
        var biggestStep: CGFloat = 0
        for seed in [UInt64(1), 2, 3, 4, 5, 6] {
            var s = TowerCompanionSim(halfWidth: TowerCompanion.side * TowerCompanion.inkHalfWidth,
                                      halfHeight: TowerCompanion.side * TowerCompanion.inkHalfHeight,
                                      seed: seed)
            let w = world(heights)
            s.place(in: w)
            var touched = false
            var last = s.position
            for i in 0..<Int(180 / TowerCompanionSim.tick) {
                s.update(w, elapsed: TowerCompanionSim.tick)
                if i > 60 {
                    biggestStep = max(biggestStep, hypot(s.position.x - last.x,
                                                         s.position.y - last.y))
                }
                last = s.position
                if let out = s.towerEscape(w) {
                    worstOverlap = max(worstOverlap, hypot(out.dx, out.dy))
                }
                let roof = w.skyline.highestTop(from: s.position.x - s.halfWidth,
                                                to: s.position.x + s.halfWidth)
                if s.position.y + s.halfHeight > roof - 4 { touched = true }
            }
            if touched { met += 1 }
        }
        #expect(met >= 5, "only \(met) of 6 runs ever reached the blocks")
        #expect(worstOverlap < 1, "it was left \(worstOverlap)pt inside a block after a tick")
        #expect(biggestStep < 6,
                "a single frame moved it \(biggestStep)pt: that is a teleport, not a bounce")
    }

    /// **A finger moves it and nothing else does, and it cannot be put on the
    /// blocks.**
    ///
    /// The owner: "dragging the head around with your finger right now it can be
    /// really glitchy, and I don't think you should be able to drag it on top of
    /// the blocks, like over them." Three separate faults, each asserted here:
    /// the head jumping under the finger on touch down, the simulation writing
    /// the position on the same frames as the finger, and the tower being open
    /// to the drag.
    @Test func aFingerMovesItSmoothlyAndCannotPutItOnTheBlocks() {
        var s = sim()
        let w = world([2, 1, 3, 1])

        let before = s.position
        let chin = CGPoint(x: before.x, y: before.y + s.halfHeight - 4)
        s.touch(.began, at: chin, in: w)
        #expect(hypot(s.position.x - before.x, s.position.y - before.y) < 0.01,
                "the head jumped on touch down")

        var worstDrift: CGFloat = 0
        var deepest = -CGFloat.greatestFiniteMagnitude
        var y = chin.y
        while y < bounds.maxY + 200 {
            y += 7
            s.touch(.moved, at: CGPoint(x: chin.x + 40 * sin(Double(y) / 40), y: y), in: w)
            // A whole handful of frames must not shift it by a hair.
            let placed = s.position
            run(&s, w, seconds: 1.0 / 30.0)
            worstDrift = max(worstDrift, hypot(s.position.x - placed.x, s.position.y - placed.y))
            let roof = w.skyline.highestTop(from: s.position.x - s.halfWidth,
                                            to: s.position.x + s.halfWidth)
            deepest = max(deepest, (s.position.y + s.halfHeight) - roof)
        }
        #expect(worstDrift < 0.001,
                "the simulation moved the head \(worstDrift)pt while a finger held it")
        #expect(deepest < 0, "the head was dragged \(deepest)pt onto the blocks")

        s.touch(.ended, at: CGPoint(x: chin.x, y: y), velocity: .zero, in: w)
        run(&s, w, seconds: 12)
        #expect(s.state == .drifting, "after a release it ended in \(s.state)")
        // There is no band to come home to. What must be true is that it is
        // floating again and is not left standing inside the tower.
        #expect(s.towerEscape(w) == nil,
                "after a release it was left inside the tower at \(s.position)")
    }

    /// **A bounce loses energy and is never a mirror.** Equal angles at equal
    /// speed is the single most artificial thing a bouncing object can do.
    @Test func aBounceLosesEnergy() {
        var s = sim(seed: 9)
        let w = world()
        var ratios: [CGFloat] = []
        var seen = 0
        for _ in 0..<Int(300 / TowerCompanionSim.tick) {
            let before = s.speed
            s.update(w, elapsed: TowerCompanionSim.tick)
            if s.wallHits > seen { seen = s.wallHits; ratios.append(s.speed / max(before, 0.01)) }
        }
        #expect(ratios.count > 3, "only \(ratios.count) bounces to judge")
        let median = ratios.sorted()[ratios.count / 2]
        #expect(median < 0.9, "bounces come back at the speed they arrived: \(median)")
    }

    /// **The tower behaviours are unreachable as it ships**, and they still work
    /// when the gate is opened. Both halves matter: the first is what the owner
    /// asked for, and the second is what keeps gated code from rotting.
    @Test func theTowerBehavioursAreGatedOff() {
        var off = sim(seed: 4)
        let w = world()
        // **With landings in it.** The first version of this ran a quiet world,
        // and that is the one screen where the leak it was meant to catch cannot
        // fire: `advance` gated the visit timer but `notice` did not, so a gated
        // build still went down to the tower on about one landing in five. A
        // test that cannot fail is worse than no test.
        for i in 0..<Int(300 / TowerCompanionSim.tick) {
            let w = i % 120 == 0
                ? world(landing: TowerCompanionWorld.Landing(
                    at: Date().addingTimeInterval(Double(i)),
                    rect: CGRect(x: originX, y: bounds.maxY - 90, width: cell, height: cell)))
                : w
            off.update(w, elapsed: TowerCompanionSim.tick)
            // Dodging is deliberately NOT gated: the head shares the screen
            // with the tower now, so getting out of the way of a block being
            // placed is not optional. Walking and hopping still are.
            #expect(off.state != .descending && off.state != .hopping
                    && off.state != .returning,
                    "a gated state was reached: \(off.state)")
        }

        var on = towerSim(seed: 4)
        var hopped = false
        for _ in 0..<Int(120 / TowerCompanionSim.tick) {
            on.update(w, elapsed: TowerCompanionSim.tick)
            if on.state == .hopping { hopped = true }
        }
        #expect(hopped, "the gated behaviour no longer works when it is turned on")
    }

    /// A landing moves him. He is already drifting, so this is a flinch rather
    /// than a wake: the recoil is away from where the block hit and it is
    /// proportional to how close it was.
    @Test func aLandingFlinchesHim() {
        var s = sim()
        let quiet = world()
        run(&s, quiet, seconds: 20)
        let before = s.position
        let near = CGRect(x: before.x - cell / 2, y: before.y + 30, width: cell, height: cell)
        let loud = world(landing: TowerCompanionWorld.Landing(at: Date(), rect: near))
        let speedBefore = s.speed
        s.update(loud, elapsed: TowerCompanionSim.tick)
        #expect(s.speed > speedBefore, "the landing did not push him")
        #expect(s.state == .startled, "state after a landing was \(s.state)")
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
        s.touch(.began, at: CGPoint(x: 10, y: 10), in: w)
        s.touch(.ended, at: CGPoint(x: 10, y: 10), velocity: CGVector(dx: 1_500, dy: 1_500), in: w)
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
        var s = towerSim()
        // Drop him onto the roof and then let him get on with it.
        let start = CGPoint(x: skyline(heights).centreX(ofColumn: 2), y: bounds.minY + 30)
        let w = world(heights)
        s.place(in: w, at: start, velocity: CGVector(dx: 40, dy: 900))
        s.touch(.began, at: start, in: w)
        s.touch(.ended, at: start, velocity: CGVector(dx: 40, dy: 900), in: w)
        var everStood = false
        for tick in 0..<1_800 {
            s.update(w, elapsed: TowerCompanionSim.tick)
            let surface = w.skyline.surfaceY(atX: s.position.x) - s.halfHeight
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
        s.touch(.began, at: CGPoint(x: w.bounds.midX, y: w.bounds.minY + 40), in: w)
        s.touch(.ended, at: CGPoint(x: w.bounds.midX, y: w.bounds.minY + 40),
                velocity: CGVector(dx: 1_200, dy: 0), in: w)
        let before = s.position
        s.update(w, elapsed: 8.0)
        let travelled = hypot(s.position.x - before.x, s.position.y - before.y)
        // Four ticks at most, so at 1200 points a second that is 80 points.
        #expect(travelled < 120, "one stalled frame moved him \(travelled)")
        #expect(inside(s, w))
    }

    // MARK: Helpers

    private func inside(_ s: TowerCompanionSim, _ w: TowerCompanionWorld) -> Bool {
        s.position.x >= w.bounds.minX + s.halfWidth - 0.01
            && s.position.x <= w.bounds.maxX - s.halfWidth + 0.01
            && s.position.y >= w.bounds.minY + s.halfHeight - 0.01
            && s.position.y <= w.bounds.maxY - s.halfHeight + 0.01
    }
}
