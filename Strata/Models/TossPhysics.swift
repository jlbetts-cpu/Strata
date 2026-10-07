import CoreGraphics
import Foundation

// MARK: - A drawing that falls onto a crew tower

/// **A tossed drawing, as a pure simulation** (the owner, 2026-10-07: "if you
/// draw something it should drop into the app with physics ... like it
/// physically drops on the tower like it's an actual object").
///
/// No SwiftUI in here, for the reason `TowerCompanionSim` gives: whether a
/// drawing ends up INSIDE a block is arithmetic, and arithmetic is a test, not
/// a film (`TossTests.aDrawingRestsOnTheBlockNotInIt`).
///
/// **What it is.** A flat thing with a size, falling at the tower's own `g`
/// (`GridConstants.dropGravity`, handed in), turning a little in the air,
/// meeting the tops of the blocks, the slot and the floor, bouncing with most
/// of its speed lost, and coming to rest at a slight tilt of its own. Each
/// phone runs its own landing: seeded by the drawing's id and the phone, so
/// a relaunch lands it in the same place and a friend's phone somewhere else.
///
/// **A fixed step**, so the same seed lands in the same place at 60Hz, at
/// 120Hz and in a test that runs it to rest in one call (`settle`).
///
/// **Collisions are resolved by moving the drawing**, never by trusting a
/// velocity: at the speed a 600pt fall reaches, a velocity-only bounce walks
/// through a block's top between two ticks.
nonisolated struct TossBody: Equatable, Sendable {
    let id: UUID
    /// Half the drawing's frame, unrotated.
    var half: CGSize
    /// The frame's centre, in the layer's points.
    var position: CGPoint
    var velocity: CGVector = .zero
    /// Radians, clockwise on screen.
    var angle: Double = 0
    /// Radians a second.
    var spin: Double = 0
    /// The tilt it settles at: a dropped thing never lands square.
    var restAngle: Double = 0
    /// The clear air the export leaves round the ink (`InkExport.inkBounds`),
    /// in points at the drawn size: the INK rests on the block, not the frame.
    var sink: CGFloat = 0
    /// Still, on something. A resting body asks for no frames.
    var resting = false
    /// Ticks spent on a support without moving, toward `resting`.
    var stillTicks = 0
    /// Times it has hit something on the way down. The first is the one the
    /// phone answers with a tap (`CrewTossLayer`).
    var impacts = 0
    /// Under a finger: placed by it, not by the world, and nothing stands
    /// on it (`grab`).
    var held = false
}

/// Everything a drawing may land on, in the layer's coordinates (origin top
/// left, y down).
nonisolated struct TossWorld: Equatable, Sendable {
    /// The tops of the four columns, as the heads have them.
    var skyline: TowerSkyline
    /// The ground under the tower.
    var floorY: CGFloat
    /// The walls either side.
    var left: CGFloat
    var right: CGFloat
    /// **The slot is a solid** (the brief: drawings "never cover the add
    /// slot"). A drawing lands on it as on a block, and one already resting
    /// where the slot moves to is lifted onto it.
    var solids: [CGRect] = []
    /// Points a second squared. The blocks' own `g`.
    var gravity: CGFloat
    /// **The highest a drawing may lie**: the header's foot. A pile of
    /// drawings stops being something to land on before it reaches the
    /// crew's name and bubble, and the next one lies over the pile instead
    /// (ink on clear ground overlaps without hiding anything).
    var ceiling: CGFloat = -.greatestFiniteMagnitude
}

nonisolated enum TossPhysics {
    /// 120Hz: a bounce at the speed a fall reaches needs the finer step.
    static let tick: Double = 1.0 / 120.0
    /// The most ticks one frame runs, so a stall does not throw a drawing
    /// across the screen in one frame.
    static let maxTicks = 8

    /// **How much of its speed a bounce keeps.** Paper on wood, not a ball:
    /// about a third, so a fall from the top of the screen bounces once you
    /// can see and once you can only feel.
    static let restitution: CGFloat = 0.3
    /// Sideways speed kept across a bounce.
    static let bounceFriction: CGFloat = 0.6
    /// Below this a contact stops bouncing and slides to rest.
    static let restSpeed: CGFloat = 60
    /// Sideways speed kept per tick while it slides on a top.
    static let slideFriction: CGFloat = 0.9
    /// How firmly a landed drawing turns onto its rest tilt, per second.
    static let settleRate: Double = 10
    /// The share of the frame's width that carries it. The ink is rarely
    /// square to its frame and a rotated frame's corners are mostly air, so
    /// the whole width would stand it on nothing at a column's edge.
    static let footprint: CGFloat = 0.7
    /// The hop a resting drawing makes when the ground rises under it (a
    /// block landing, the slot moving up).
    static let nudge: CGFloat = 260

    // MARK: Spawning

    /// **Where a drawing starts**: seeded, so the same drawing on the same
    /// phone starts (and so lands) in the same place every time.
    ///
    /// `longest` is the drawn size's longest side; `aspect` the picture's
    /// width over its height. `above` is the y it falls from (its bottom edge
    /// starts there, so it enters from off the visible top).
    static func spawn(id: UUID, seed: UInt64, aspect: CGFloat, longest: ClosedRange<CGFloat>,
                      sinkFraction: CGFloat = 0, above: CGFloat, in world: TossWorld,
                      among others: [TossBody] = []) -> TossBody {
        var rng = HeadRandom(seed: seed)
        let side = CGFloat.random(in: longest, using: &rng)
        let a = aspect.isFinite && aspect > 0 ? min(max(aspect, 0.25), 4) : 1
        let size = a >= 1 ? CGSize(width: side, height: side / a) : CGSize(width: side * a, height: side)
        let half = CGSize(width: size.width / 2, height: size.height / 2)
        // Across the tower, clear of the walls, and on open ground when
        // there is any: six seeded places, and the one that falls on the
        // least of the slot and the drawings already down (the first on a
        // tie, so a lone drawing lands where its seed says). Without this
        // three drawings in a row built a pile toward the header.
        let lo = world.left + half.width * footprint + 6
        let hi = max(lo, world.right - half.width * footprint - 6)
        func crowding(_ x: CGFloat) -> CGFloat {
            let s = (x - half.width * footprint)...(x + half.width * footprint)
            func overlap(_ a: CGFloat, _ b: CGFloat) -> CGFloat { max(0, min(s.upperBound, b) - max(s.lowerBound, a)) }
            return world.solids.reduce(0) { $0 + overlap($1.minX, $1.maxX) * 3 }
                + others.reduce(0) { total, other in
                    let o = span(other)
                    return total + overlap(o.lowerBound, o.upperBound)
                }
        }
        var x = CGFloat.random(in: lo...hi, using: &rng)
        var best = crowding(x)
        for _ in 0..<5 {
            let next = CGFloat.random(in: lo...hi, using: &rng)
            let c = crowding(next)
            if c < best - 0.5 { x = next; best = c }
        }
        var body = TossBody(id: id, half: half, position: CGPoint(x: x, y: above - half.height))
        body.angle = Double.random(in: -0.28...0.28, using: &rng)
        body.spin = Double.random(in: -1.4...1.4, using: &rng)
        body.restAngle = Double.random(in: -0.12...0.12, using: &rng)
        body.velocity = CGVector(dx: CGFloat.random(in: -40...40, using: &rng), dy: 0)
        body.sink = min(max(sinkFraction, 0), 0.3) * size.height
        return body
    }

    /// The seed for a drawing on this phone: its id, salted with something
    /// that differs between phones, so two phones land it differently.
    static func seed(for id: UUID, salt: UUID) -> UInt64 {
        func fold(_ u: UUID) -> UInt64 {
            let b = u.uuid
            let hi = [b.0, b.1, b.2, b.3, b.4, b.5, b.6, b.7].reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
            let lo = [b.8, b.9, b.10, b.11, b.12, b.13, b.14, b.15].reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
            return hi ^ (lo &* 0x9E3779B97F4A7C15)
        }
        return fold(id) ^ (fold(salt) &* 0xBF58476D1CE4E5B9) | 1
    }

    // MARK: Geometry

    /// The rotated frame's half extents.
    static func extent(_ body: TossBody) -> CGSize {
        let c = CGFloat(abs(cos(body.angle))), s = CGFloat(abs(sin(body.angle)))
        return CGSize(width: body.half.width * c + body.half.height * s,
                      height: body.half.width * s + body.half.height * c)
    }

    /// Where its ink meets what it stands on.
    static func bottom(_ body: TossBody) -> CGFloat {
        body.position.y + extent(body).height - body.sink
    }

    /// The span it stands on.
    static func span(_ body: TossBody) -> ClosedRange<CGFloat> {
        let w = extent(body).width * footprint
        return (body.position.x - w)...(body.position.x + w)
    }

    /// What it may stand on, in that span: the columns, the solids, and the
    /// tops of drawings already down. `from` filters to tops at or below a
    /// line, for a falling drawing that may only land on what is under it;
    /// nil takes every top under the span, for one at rest that the ground
    /// may have risen under. Returns the highest such top (the smallest y)
    /// and the columns or solids that rose above `from` beside it, as walls.
    private static func support(for index: Int, in bodies: [TossBody], world: TossWorld,
                                from: CGFloat?) -> (top: CGFloat, walls: [ClosedRange<CGFloat>]) {
        let body = bodies[index]
        let s = span(body)
        var top = world.floorY
        var walls: [ClosedRange<CGFloat>] = []
        let slack: CGFloat = 0.5
        let sky = world.skyline
        if sky.columnWidth > 0 {
            for c in 0..<TowerSkyline.columns {
                let x0 = sky.originX + sky.pitch * CGFloat(c) + sky.cornerInset
                let x1 = sky.originX + sky.pitch * CGFloat(c) + sky.columnWidth - sky.cornerInset
                guard x0 < s.upperBound, x1 > s.lowerBound else { continue }
                let t = sky.top(ofColumn: c)
                if let from, t < from - slack { walls.append(x0...x1) } else { top = min(top, t) }
            }
        }
        for solid in world.solids where solid.minX < s.upperBound && solid.maxX > s.lowerBound {
            if let from, solid.minY < from - slack {
                // Beside it, not under it: a wall only where they overlap in height.
                if solid.maxY > body.position.y - extent(body).height { walls.append(solid.minX...solid.maxX) }
            } else {
                top = min(top, solid.minY)
            }
        }
        // **On each other**: a drawing down already is something to land
        // on. Only ones that arrived first, so a pile is built in order and
        // never resolves into itself.
        for j in 0..<index where !bodies[j].held && (bodies[j].resting || (from != nil && bodies[j].impacts > 0)) {
            let other = bodies[j]
            let o = span(other)
            guard o.lowerBound < s.upperBound, o.upperBound > s.lowerBound else { continue }
            let t = other.position.y - extent(other).height * 0.8
            if let from, t < from - slack { continue }
            if t - extent(body).height * 2 + body.sink < world.ceiling { continue }
            top = min(top, t)
        }
        return (top, walls)
    }

    // MARK: Stepping

    /// Runs `elapsed` seconds of whole ticks over every body, in the order
    /// they arrived. Returns the ids that hit something for the first time.
    @discardableResult
    static func step(_ bodies: inout [TossBody], in world: TossWorld, ticks: Int) -> [UUID] {
        var firstHits: [UUID] = []
        for _ in 0..<max(ticks, 0) {
            for i in bodies.indices where !bodies[i].held {
                if advance(&bodies, i, in: world) { firstHits.append(bodies[i].id) }
            }
        }
        return firstHits
    }

    /// Every body to rest, or `seconds` of simulated time, whichever is
    /// first: a drawing that landed before the screen opened is placed where
    /// its fall would have put it.
    ///
    /// `only` settles one body and leaves the rest where they are: a drawing
    /// placed while another is still in the air must not fast-forward it.
    static func settle(_ bodies: inout [TossBody], only: Int? = nil, in world: TossWorld, seconds: Double = 8) {
        let limit = Int(seconds / tick)
        var n = 0
        if let only {
            guard bodies.indices.contains(only) else { return }
            while n < limit, !bodies[only].resting {
                advance(&bodies, only, in: world)
                n += 1
            }
            return
        }
        // **At least one tick, even with everything at rest**: a resting
        // drawing only finds out the ground rose under it (a block landed,
        // the slot moved) when it is stepped. Skipping a world where all
        // were at rest left one on the floor inside a new block
        // (`TossTests.theyStackAndRiseWithTheTower`, 2026-10-07).
        repeat {
            step(&bodies, in: world, ticks: 1)
            n += 1
        } while n < limit && bodies.contains(where: { !$0.resting })
    }

    // MARK: In the hand

    /// **Picked up** (the owner, 2026-10-07: "actual physics like you can
    /// pick them up and move them and stuff"). Moved to the end of the list,
    /// so wherever it is dropped it lands on what is there, as the newest
    /// arrival; whatever lay on it falls. Returns its new index.
    @discardableResult
    static func grab(_ bodies: inout [TossBody], id: UUID) -> Int? {
        guard let i = bodies.firstIndex(where: { $0.id == id }) else { return nil }
        var b = bodies.remove(at: i)
        b.held = true
        b.resting = false
        b.stillTicks = 0
        b.velocity = .zero
        bodies.append(b)
        // What stood on it looks again at its ground.
        for j in bodies.indices where bodies[j].resting {
            bodies[j].resting = false
            bodies[j].stillTicks = 0
        }
        return bodies.count - 1
    }

    /// The fastest a throw leaves the hand, points a second.
    static let throwSpeed: CGFloat = 1800

    /// **Let go**, at the finger's speed: it flies, turns with the throw,
    /// and falls back onto the tower.
    static func release(_ bodies: inout [TossBody], id: UUID, velocity: CGVector) {
        guard let i = bodies.firstIndex(where: { $0.id == id }) else { return }
        bodies[i].held = false
        bodies[i].velocity = clamp(velocity, to: throwSpeed)
        bodies[i].spin = Double(max(-8, min(8, velocity.dx / 260)))
        bodies[i].impacts = max(bodies[i].impacts, 1)
    }

    /// **Knocked** by a head: a push and a hop, and a turn with it.
    static func knock(_ bodies: inout [TossBody], id: UUID, by impulse: CGVector) {
        guard let i = bodies.firstIndex(where: { $0.id == id }), !bodies[i].held else { return }
        let v = CGVector(dx: bodies[i].velocity.dx + impulse.dx, dy: bodies[i].velocity.dy + impulse.dy)
        bodies[i].velocity = clamp(v, to: throwSpeed * 0.6)
        bodies[i].spin += Double(max(-5, min(5, impulse.dx / 240)))
        bodies[i].resting = false
        bodies[i].stillTicks = 0
    }

    private static func clamp(_ v: CGVector, to most: CGFloat) -> CGVector {
        guard v.dx.isFinite, v.dy.isFinite else { return .zero }
        let speed = hypot(v.dx, v.dy)
        guard speed > most else { return v }
        return CGVector(dx: v.dx / speed * most, dy: v.dy / speed * most)
    }

    /// One tick for one body. True on its first impact.
    @discardableResult
    private static func advance(_ bodies: inout [TossBody], _ i: Int, in world: TossWorld) -> Bool {
        var b = bodies[i]
        guard b.half.width.isFinite, b.half.height.isFinite, b.position.x.isFinite, b.position.y.isFinite else {
            return false
        }
        let dt = CGFloat(tick)

        if b.resting {
            // Still, unless the ground under it moved: a block landed, the
            // slot rose, or what it stood on was taken away.
            let under = support(for: i, in: bodies, world: world, from: nil).top
            let bottom = bottom(b)
            if under < bottom - 0.5 {
                b.position.y -= bottom - under
                b.velocity = CGVector(dx: 0, dy: -nudge)
                b.resting = false
                b.stillTicks = 0
            } else if under > bottom + 0.5 {
                b.resting = false
                b.stillTicks = 0
            } else {
                return false
            }
            bodies[i] = b
            return false
        }

        let wasBottom = bottom(b)
        b.velocity.dy += world.gravity * dt
        b.position.x += b.velocity.dx * dt
        b.position.y += b.velocity.dy * dt
        b.angle += b.spin * Double(dt)
        b.spin *= 0.995

        bodies[i] = b
        let found = support(for: i, in: bodies, world: world, from: wasBottom)
        var firstHit = false

        // A taller column or the slot beside it: pushed back out of the
        // side it came in on, never lifted onto it.
        for wall in found.walls {
            let s = span(b)
            guard wall.lowerBound < s.upperBound, wall.upperBound > s.lowerBound else { continue }
            let w = extent(b).width * footprint
            if b.position.x < (wall.lowerBound + wall.upperBound) / 2 {
                b.position.x = wall.lowerBound - w
                b.velocity.dx = -abs(b.velocity.dx) * 0.4
            } else {
                b.position.x = wall.upperBound + w
                b.velocity.dx = abs(b.velocity.dx) * 0.4
            }
        }

        // The walls of the room.
        let ext = extent(b)
        if b.position.x - ext.width < world.left {
            b.position.x = world.left + ext.width
            b.velocity.dx = abs(b.velocity.dx) * 0.4
        } else if b.position.x + ext.width > world.right {
            b.position.x = world.right - ext.width
            b.velocity.dx = -abs(b.velocity.dx) * 0.4
        }

        let bottom = bottom(b)
        if bottom >= found.top {
            b.position.y -= bottom - found.top
            if b.velocity.dy > restSpeed {
                // A bounce: most of the speed gone, a little turn from the
                // knock, toward where it will lie.
                b.velocity.dy = -b.velocity.dy * restitution
                b.velocity.dx *= bounceFriction
                b.spin = -b.spin * 0.4 + (b.restAngle - b.angle) * 3
                firstHit = b.impacts == 0
                b.impacts += 1
            } else {
                if b.impacts == 0 { firstHit = true; b.impacts = 1 }
                b.velocity.dy = 0
                b.velocity.dx *= slideFriction
                // Turned onto its rest tilt, critically: no wobble past it.
                let pull = (b.restAngle - b.angle) * settleRate
                b.spin = pull
                b.angle += pull * Double(dt)
                if abs(b.velocity.dx) < 2, abs(b.restAngle - b.angle) < 0.003 {
                    b.stillTicks += 1
                } else {
                    b.stillTicks = 0
                }
                if b.stillTicks > 12 {
                    b.angle = b.restAngle
                    b.spin = 0
                    b.velocity = .zero
                    // Settled at the tilt: put its ink back on the top.
                    b.position.y -= Self.bottom(b) - found.top
                    b.resting = true
                }
            }
        }
        bodies[i] = b
        return firstHit
    }
}
