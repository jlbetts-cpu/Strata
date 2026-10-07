import SwiftUI

// MARK: - Drawings on a crew's tower

/// **Where the heads and the drawings meet** (the owner, 2026-10-07: "make
/// sure the doodle works with the heads floating around and have actual
/// physics"). The heads float in a layer over the whole screen and the
/// drawings lie in the tower's scroll, so each tells the other where it is
/// through this: the drawings' frames (the heads bounce off them as off
/// anything drawn), and knocks (a head that runs into one, fast or carried,
/// sends it flying).
///
/// Unobserved but for `kicks`, which wakes the drawings' clock: they stop it
/// when everything lies still, and a knock has to start it again.
@MainActor
@Observable
final class CrewPlayfield {
    /// Each drawing's frame in the drawings' own layer, and that layer's top
    /// left in the window. Two parts, so a scroll moves every frame without
    /// anyone stepping a clock.
    @ObservationIgnored var drawings: [UUID: CGRect] = [:]
    @ObservationIgnored var origin: CGPoint = .zero
    /// Pushes waiting for the drawings' next frame, in points a second.
    @ObservationIgnored var pending: [UUID: CGVector] = [:]
    /// When each drawing was last knocked, so a head resting against one does
    /// not knock it every frame.
    @ObservationIgnored private var lastKnock: [UUID: Date] = [:]
    private(set) var kicks = 0

    /// Every drawing's frame, in the window.
    var drawingsInWindow: [(id: UUID, rect: CGRect)] {
        drawings.map { ($0.key, $0.value.offsetBy(dx: origin.x, dy: origin.y)) }
    }

    /// A head ran into a drawing. Called from a head's frame, so the clock
    /// is woken on the next turn of the run loop, never during the update.
    func knock(_ id: UUID, by impulse: CGVector, now: Date = Date()) {
        if let last = lastKnock[id], now.timeIntervalSince(last) < 0.35 { return }
        lastKnock[id] = now
        let was = pending[id] ?? .zero
        pending[id] = CGVector(dx: was.dx + impulse.dx, dy: was.dy + impulse.dy)
        Task { @MainActor in self.kicks &+= 1 }
    }
}

/// What the drawings on one crew tower share between frames. Not observed,
/// like `CrewArenaBox`: stepping the world sixty times a second must not
/// invalidate the tower around it.
@MainActor
final class CrewTossBox {
    var bodies: [TossBody] = []
    var world: TossWorld?
    var lastFrame: Date?
    var carry: Double = 0
    /// When the next live arrival may start (`GridConstants.tossStagger`).
    var nextLive = Date.distantPast
    /// Drawings that arrived while this screen watched: they answer their
    /// first landing with a tap, and under Reduce Motion fade in.
    var live: Set<UUID> = []
    /// The layer's top left, in the window, for a tuck's flight.
    var origin: CGPoint = .zero

    /// Something was taken away: everything left looks again at what it
    /// stands on, so a drawing that lay on a tucked one falls. A resting
    /// body only asks about its ground while the clock runs, and with every
    /// body at rest the clock is stopped.
    func wake() {
        for i in bodies.indices where bodies[i].resting {
            bodies[i].resting = false
            bodies[i].stillTicks = 0
        }
    }
}

/// **Today's drawings on a crew's tower, as things that fell onto it** (the
/// owner, 2026-10-07: "like it physically drops on the tower like it's an
/// actual object").
///
/// Laid over the tower's scroll content, so a drawing scrolls with the block
/// it stands on and the header's bubble is never under one. Each falls from
/// above the visible top through `TossPhysics`, turns a little, meets the
/// blocks' tops, the slot and the ground, bounces once or twice and lies
/// still. A drawing that landed before this screen opened is placed where its
/// fall put it (`CrewTossShelf.landed`), so it is in the same place every
/// time on this phone; one that arrives while you watch falls, with a light
/// tap as it lands. Reduce Motion: it appears where it would have landed.
///
/// **It takes a finger only on itself.** Nothing behind a drawing is a
/// target, so the blocks, the slot and the reactions still answer everywhere
/// else. Hold one to tuck it into the bubble (`onTuck`).
///
/// **Pick it up and throw it** (the owner, 2026-10-07: "actual physics like
/// you can pick them up and move them and stuff"). Drawn across, it follows
/// the finger; let go, it leaves at the finger's speed, turns with the throw
/// and falls back onto the tower, onto the blocks or the other drawings.
/// Carried onto the bubble it tucks in, as a head parks. The floating heads
/// bounce off it, and one that runs into it fast, or is carried into it,
/// knocks it flying (`CrewPlayfield`).
struct CrewTossLayer: View {
    let crewID: CrewID
    /// Today's drawings to show: `SocialStore.tosses(in:)` less the tucked.
    let tosses: [CrewMessage]
    /// The crew day they belong to.
    let day: String
    let names: [UUID: String]
    let me: UUID
    let model: CrewTowerModel
    let colW: CGFloat
    let gridH: CGFloat
    /// The tower's side margin and its foot, as the scroll content pads it.
    let hPad: CGFloat
    let foot: CGFloat
    /// The scroll's visible height: a live drawing starts above it.
    let viewport: CGFloat
    /// The slot, in the grid's own coordinates (y down from the grid's top),
    /// or nil when it is not showing.
    let slot: CGRect?
    /// A sheet or the viewer is up: live drops wait for it to go.
    let isBusy: Bool
    /// The header's foot, in the window: nothing piles up past it.
    var ceiling: CGFloat? = nil
    /// A held drawing, where it is in the window and how it lies.
    let onTuck: (CrewMessage, CGPoint, CGSize, Double) -> Void
    /// DEBUG films: bumped to tuck the oldest drawing at rest, as a hold would.
    var tuckOldest = 0
    /// Shared with the heads: where the drawings are, and the knocks.
    var playfield: CrewPlayfield? = nil
    /// The bubble, for a drawing carried onto it.
    var parking: CrewParking? = nil

    @State private var box = CrewTossBox()
    /// Each drawing's picture, width over height, and the air round its ink
    /// as a share of its height (`InkExport.inkBounds`).
    @State private var shapes: [UUID: (aspect: CGFloat, air: CGFloat)] = [:]
    @State private var lifted: UUID?
    /// The drawing under a finger, and where the finger took it.
    @State private var carried: UUID?
    @State private var grabOffset = CGSize.zero
    private static let space = "crewTossLayer"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var shelf: CrewTossShelf { CrewTossShelf(crewID: crewID) }

    var body: some View {
        GeometryReader { geo in
            let world = makeWorld(size: geo.size)
            let ready = tosses.filter { shapes[$0.messageID] != nil }
            let wanted = Set(ready.map(\.messageID))
            let have = Set(box.bodies.map(\.id))
            let built = model.tower.hasBuiltOnce
            // The clock runs only while something moves or is due: a body
            // in the air, the ground changed under one, one to place, or a
            // live one free to fall. A live one held back for a sheet waits
            // with the clock stopped.
            let landed = Set(shelf.landed(on: day))
            let missing = wanted.subtracting(have)
            let held = isBusy && !missing.contains(where: landed.contains)
            // `kicks` is read so a head's knock restarts a stopped clock.
            let _ = playfield?.kicks
            let knocked = !(playfield?.pending.isEmpty ?? true)
            let still = box.bodies.allSatisfy(\.resting) && box.world == world
                && have.isSubset(of: wanted) && (missing.isEmpty || held)
                && carried == nil && !knocked
            let paused = still || !built || scenePhase != .active
            TimelineView(.animation(paused: paused)) { context in
                let _ = frame(context.date, ready: ready, world: world, height: geo.size.height, built: built)
                ZStack(alignment: .topLeading) {
                    ForEach(box.bodies, id: \.id) { body in
                        if let toss = ready.first(where: { $0.messageID == body.id }), let sketch = toss.sketch {
                            drawing(toss, sketch: sketch, body: body)
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                .coordinateSpace(.named(Self.space))
            }
            .onGeometryChange(for: CGPoint.self) { $0.frame(in: .global).origin } action: {
                box.origin = $0
                playfield?.origin = $0
            }
        }
        .task(id: tosses.map(\.messageID)) { await loadShapes() }
        .onChange(of: tuckOldest) {
            Task { @MainActor in
                // Waits, for a film, until one has come to rest.
                for _ in 0..<60 {
                    if let body = box.bodies.first(where: \.resting),
                       let toss = tosses.first(where: { $0.messageID == body.id }) {
                        lifted = body.id
                        try? await Task.sleep(for: .milliseconds(350))
                        tuck(toss, body: body)
                        return
                    }
                    try? await Task.sleep(for: .seconds(1))
                }
            }
        }
    }

    // MARK: A drawing

    private func drawing(_ toss: CrewMessage, sketch: URL, body: TossBody) -> some View {
        let size = CGSize(width: body.half.width * 2, height: body.half.height * 2)
        let held = lifted == body.id
        return TossDrawing(url: sketch, fadesIn: reduceMotion && box.live.contains(body.id))
            .frame(width: size.width, height: size.height)
            .scaleEffect(held ? 1.08 : 1)
            .animation(GridConstants.tossLift, value: held)
            .rotationEffect(.radians(body.angle))
            .offset(x: body.position.x - body.half.width, y: body.position.y - body.half.height)
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.35, maximumDistance: 12) {
                // A hold that became a carry is a carry.
                guard carried != body.id else { return }
                tuck(toss, body: body)
            } onPressingChanged: { pressing in
                if pressing { HapticsEngine.tick() }
                lifted = pressing ? body.id : (lifted == body.id ? nil : lifted)
            }
            .simultaneousGesture(carry(toss))
            .accessibilityElement()
            .accessibilityLabel(label(for: toss))
            .accessibilityAddTraits(.isImage)
            .accessibilityAction(named: "Tuck into the bubble") { tuck(toss, body: body) }
    }

    /// The finger takes it, carries it, and throws it.
    private func carry(_ toss: CrewMessage) -> some Gesture {
        let id = toss.messageID
        return DragGesture(minimumDistance: 6, coordinateSpace: .named(Self.space))
            .onChanged { value in
                if carried != id {
                    guard let i = box.bodies.firstIndex(where: { $0.id == id }) else { return }
                    let p = box.bodies[i].position
                    grabOffset = CGSize(width: value.startLocation.x - p.x, height: value.startLocation.y - p.y)
                    TossPhysics.grab(&box.bodies, id: id)
                    carried = id
                    lifted = id
                    HapticsEngine.tick()
                }
                if let i = box.bodies.firstIndex(where: { $0.id == id }) {
                    box.bodies[i].position = CGPoint(x: value.location.x - grabOffset.width,
                                                     y: value.location.y - grabOffset.height)
                }
                if let parking {
                    let over = parking.isOver(window(value.location))
                    if over != parking.over {
                        parking.over = over
                        if over { HapticsEngine.tick() }
                    }
                }
            }
            .onEnded { value in
                guard carried == id else { return }
                carried = nil
                lifted = nil
                let parks = parking?.isOver(window(value.location)) ?? false
                parking?.over = false
                if parks, let body = box.bodies.first(where: { $0.id == id }) {
                    tuck(toss, body: body)
                    return
                }
                TossPhysics.release(&box.bodies, id: id,
                                    velocity: CGVector(dx: value.velocity.width, dy: value.velocity.height))
                box.lastFrame = nil
            }
    }

    private func window(_ local: CGPoint) -> CGPoint {
        CGPoint(x: box.origin.x + local.x, y: box.origin.y + local.y)
    }

    private func label(for toss: CrewMessage) -> String {
        if toss.senderProfileID == me { return "Your drawing" }
        let name = names[toss.senderProfileID] ?? ""
        return name.isEmpty ? "A friend's drawing" : "\(name)'s drawing"
    }

    private func tuck(_ toss: CrewMessage, body: TossBody) {
        lifted = nil
        let centre = CGPoint(x: box.origin.x + body.position.x, y: box.origin.y + body.position.y)
        box.bodies.removeAll { $0.id == body.id }
        playfield?.drawings[body.id] = nil
        box.wake()
        onTuck(toss, centre, CGSize(width: body.half.width * 2, height: body.half.height * 2), body.angle)
    }

    // MARK: The world

    /// The tower as `TossPhysics` sees it, in this layer's points: the grid
    /// sits at the foot, `hPad` in, its top `gridH` above the foot. Blocks
    /// still falling are left out until they land, or a drawing would stand
    /// on a block that is not there yet.
    private func makeWorld(size: CGSize) -> TossWorld {
        let floorY = size.height - foot
        let gridTop = floorY - gridH
        let falling = model.animation.activelyAnimatingIDs
        let cells = model.tower.placedBlocks.lazy
            .filter { !falling.contains($0.id) }
            .map { TowerCompanionWorld.Cell($0.column, $0.row, $0.columnSpan, $0.rowSpan) }
        let skyline = colW > 0
            ? TowerSkyline.build(cells: cells, originX: hPad, cellSize: colW, gutter: GridConstants.spacing,
                                 gridTopY: gridTop, gridHeight: gridH,
                                 cornerInset: GridConstants.blockCornerRadius(forCell: colW))
            : TowerSkyline()
        let solids = slot.map { [$0.offsetBy(dx: hPad, dy: gridTop)] } ?? []
        var world = TossWorld(skyline: skyline, floorY: floorY, left: 2, right: max(size.width - 2, 4),
                              solids: solids, gravity: GridConstants.dropGravity)
        if let ceiling { world.ceiling = ceiling - box.origin.y + GridConstants.gapTight }
        return world
    }

    // MARK: The frame

    /// Brings the bodies in line with the drawings to show, then steps them.
    private func frame(_ now: Date, ready: [CrewMessage], world: TossWorld, height: CGFloat, built: Bool) {
        guard built, world.floorY.isFinite, world.right > world.left else { return }
        box.world = world
        let wanted = Set(ready.map(\.messageID))
        if box.bodies.contains(where: { !wanted.contains($0.id) }) {
            box.bodies.removeAll { !wanted.contains($0.id) }
            box.wake()
        }
        let landed = Set(shelf.landed(on: day))
        for toss in ready where !box.bodies.contains(where: { $0.id == toss.messageID }) {
            let id = toss.messageID
            guard let shape = shapes[id] else { continue }
            let seen = landed.contains(id)
            if !seen && (isBusy || now < box.nextLive) { continue }
            // From above what you can see, and above whatever it will land
            // on, so it always enters from off the top.
            let visibleTop = height - viewport
            let above = min(visibleTop, world.skyline.highestTop - 240) - 4
            var body = TossPhysics.spawn(id: id, seed: TossPhysics.seed(for: id, salt: me), aspect: shape.aspect,
                                         longest: GridConstants.tossSide, sinkFraction: shape.air,
                                         above: above, in: world, among: box.bodies)
            if seen || reduceMotion {
                box.bodies.append(body)
                TossPhysics.settle(&box.bodies, only: box.bodies.count - 1, in: world)
                if !seen { box.live.insert(id) }
            } else {
                body.velocity.dy = 0
                box.bodies.append(body)
                box.live.insert(id)
                box.nextLive = now.addingTimeInterval(GridConstants.tossStagger)
            }
            shelf.markLanded(id, on: day)
        }
        // Whole ticks of real time; a long gap (the screen was paused) is
        // one tick, not a lurch.
        let elapsed = box.lastFrame.map { now.timeIntervalSince($0) } ?? TossPhysics.tick
        box.lastFrame = now
        box.carry = elapsed > 0.25 ? TossPhysics.tick : box.carry + elapsed
        let ticks = min(Int(box.carry / TossPhysics.tick), TossPhysics.maxTicks)
        box.carry -= Double(ticks) * TossPhysics.tick
        if box.carry > TossPhysics.tick * Double(TossPhysics.maxTicks) { box.carry = 0 }
        // A head's knocks, since the last frame.
        if let playfield, !playfield.pending.isEmpty {
            for (id, push) in playfield.pending { TossPhysics.knock(&box.bodies, id: id, by: push) }
            playfield.pending = [:]
            HapticsEngine.tick()
        }
        let hits = TossPhysics.step(&box.bodies, in: world, ticks: ticks)
        if hits.contains(where: box.live.contains) { HapticsEngine.lightTap() }
        // Where each lies now, for the heads: the ink's share of the frame,
        // and not the one in the hand.
        if let playfield {
            var rects: [UUID: CGRect] = [:]
            for b in box.bodies where !b.held {
                let e = TossPhysics.extent(b)
                rects[b.id] = CGRect(x: b.position.x - e.width * 0.8, y: b.position.y - e.height * 0.8,
                                     width: e.width * 1.6, height: e.height * 1.6)
            }
            playfield.drawings = rects
        }
    }

    /// Each drawing's shape, read off the main thread once.
    private func loadShapes() async {
        for toss in tosses where shapes[toss.messageID] == nil {
            guard let url = toss.sketch else { continue }
            let size = await Task.detached(priority: .userInitiated) {
                InkImageCache.size(at: url, scale: 3)
            }.value
            guard let size, size.width > 0, size.height > 0 else { continue }
            // The export keeps two pens' width of air round the ink, at the
            // scale it was written (3 for any canvas this app has).
            let air = (2 * InkPen.width) / size.height
            shapes[toss.messageID] = (size.width / size.height, air)
        }
    }
}

/// One drawing: the sender's ink on clear ground, in the page's drawing ink
/// so it follows dark mode. No card, no rim, no shadow: it is a drawing on
/// the tower, not chrome over it.
private struct TossDrawing: View {
    let url: URL
    var fadesIn = false
    @State private var shown = false

    var body: some View {
        InkImage(url: url, tint: AppColors.drawingInk)
            .opacity(!fadesIn || shown ? 1 : 0)
            .onAppear {
                guard fadesIn else { return }
                withAnimation(GridConstants.tossAppear) { shown = true }
            }
    }
}

// MARK: - Into the bubble

/// A drawing on its way into the bubble: from where it lay, turning square,
/// shrinking to a head's size as it goes in. In the window's coordinates, over
/// everything, as a head's flight is.
struct TossTuckFlight: View, Identifiable {
    let id: UUID
    let url: URL
    let from: CGPoint
    let to: CGPoint
    let size: CGSize
    let angle: Double
    let onArrive: () -> Void

    @State private var gone = false

    var body: some View {
        GeometryReader { geo in
            let origin = geo.frame(in: .global).origin
            let at = gone ? to : from
            // The picture the tower was drawing, already decoded: through
            // `InkImage` it loaded a beat into the flight and most of the
            // flight was nothing (filmed 2026-10-07).
            Group {
                if let ink = InkImageCache.image(at: url, scale: 3) {
                    Image(uiImage: ink)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(AppColors.drawingInk)
                } else {
                    InkImage(url: url, tint: AppColors.drawingInk)
                }
            }
            .frame(width: size.width, height: size.height)
            .scaleEffect(gone ? 0.16 : 1.08)
            .rotationEffect(.radians(gone ? 0 : angle))
            .opacity(gone ? 0.4 : 1)
            .position(x: at.x - origin.x, y: at.y - origin.y)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(GridConstants.tossTuck) { gone = true } completion: { onArrive() }
        }
    }
}

// MARK: - The count on the bubble

/// **How many of today's drawings are tucked in the bubble**: a small glass
/// capsule in the crest caption's own type, monotone like everything in the
/// middle. Nothing at zero.
struct TossCountBadge: View {
    let count: Int

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "scribble")
                .font(Typography.headerSmall)
                .imageScale(.small)
                .foregroundStyle(AppColors.inkTertiary)
            Text(StrataFont.digits(count))
                .font(Typography.headerSmall)
                .monospacedDigit()
                .foregroundStyle(AppColors.inkPrimary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .glassCapsule(onPage: true)
        .animation(GridConstants.tossCount, value: count)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(count == 1 ? "1 drawing tucked away" : "\(count) drawings tucked away")
    }
}

// MARK: - What is tucked, on this phone

/// Today's tucked drawings in one crew, observed, so the bubble's count and
/// the Draw tab's list move together. Stored by `CrewTossShelf`.
@MainActor
@Observable
final class CrewTossTucks {
    let crewID: CrewID
    private(set) var day: String
    private(set) var ids: [UUID]
    /// Bumped as a tucked drawing reaches the bubble, so the bubble swells
    /// on arrival rather than at the hold.
    private(set) var arrivals = 0
    @ObservationIgnored private let shelf: CrewTossShelf

    init(crewID: CrewID, day: String, defaults: UserDefaults = .standard) {
        self.crewID = crewID
        self.day = day
        shelf = CrewTossShelf(crewID: crewID, defaults: defaults)
        ids = shelf.tucked(on: day)
    }

    /// A new crew day: yesterday's list reads as empty.
    func show(_ day: String) {
        guard day != self.day else { return }
        self.day = day
        ids = shelf.tucked(on: day)
    }

    func isTucked(_ id: UUID) -> Bool { ids.contains(id) }

    func tuck(_ id: UUID) {
        shelf.tuck(id, on: day)
        ids = shelf.tucked(on: day)
    }

    func arrived() {
        arrivals += 1
        HapticsEngine.lightTap()
    }

    /// Back onto the tower: it falls in again from the top.
    func putBack(_ id: UUID) {
        shelf.putBack(id, on: day)
        ids = shelf.tucked(on: day)
    }
}
