import Observation
import SwiftUI
import UIKit

// MARK: - Who is in the bubble

/// A crew tower's bubble: which heads are in it, which one is being carried,
/// and which is flying in or popping out.
///
/// **Yours alone.** Parking is how the tower looks on your phone, not on
/// anyone else's, so it is kept in `UserDefaults` per crew and never sent.
@MainActor
@Observable
final class CrewParking {
    let crewID: CrewID
    /// In the order they went in, so the bubble's arrangement is stable.
    private(set) var parked: [UUID]
    /// The member under a finger.
    var dragging: UUID?
    /// The finger is over the bubble.
    var over = false
    /// A head on its way in, from where it was drawn (global coordinates).
    private(set) var arriving: [UUID: CGPoint] = [:]
    /// Bumped on every landing, so the bubble swells and its heads jostle.
    private(set) var landed = 0
    /// Bumped on every pop, with who popped and, from the fan, where they
    /// were (global coordinates).
    private(set) var popped: (member: UUID, count: Int, from: CGPoint?)?
    /// The heads in the bubble, spread out at a size a finger can choose
    /// between (the owner, 2026-10-02: tap fans them out). Eight crammed
    /// heads are 34pt each, under the 44pt a target needs.
    var fanned = false
    /// The bubble, in global coordinates.
    var bubbleFrame: CGRect = .zero
    /// The capsule and the two buttons, for the heads to keep off.
    var controls: [String: CGRect] = [:]

    private var key: String { "crews.parked.\(crewID.rawValue)" }

    init(crewID: CrewID, defaults: UserDefaults = .standard) {
        self.crewID = crewID
        let stored = defaults.stringArray(forKey: "crews.parked.\(crewID.rawValue)")
        parked = (stored ?? []).compactMap(UUID.init(uuidString:))
        firstOpen = stored == nil
        self.defaults = defaults
    }

    /// Never opened on this phone: everyone starts in the bubble.
    @ObservationIgnored private var firstOpen: Bool

    @ObservationIgnored private let defaults: UserDefaults

    func isParked(_ member: UUID) -> Bool { parked.contains(member) }
    func isHidden(_ member: UUID) -> Bool { parked.contains(member) || arriving[member] != nil }

    /// Within reach of the bubble, with a little slop: a target you have to
    /// hit exactly is a target you miss.
    func isOver(_ point: CGPoint) -> Bool {
        !bubbleFrame.isEmpty && bubbleFrame.insetBy(dx: -18, dy: -18).contains(point)
    }

    func beginArrival(_ member: UUID, from point: CGPoint) {
        arriving[member] = point
    }

    /// The flight is over: he is in.
    func land(_ member: UUID) {
        arriving[member] = nil
        guard !parked.contains(member) else { return }
        withAnimation(GridConstants.elasticPop) {
            parked.append(member)
            landed += 1
        }
        persist()
        HapticsEngine.success()
    }

    /// Straight in, for VoiceOver and Reduce Motion.
    func parkNow(_ member: UUID) {
        land(member)
    }

    func pop(_ member: UUID, from point: CGPoint? = nil) {
        guard parked.contains(member), !leaving.contains(member) else { return }
        HapticsEngine.lightTap()
        leaving.insert(member)
        // **Placed first, let go a beat later**, the Wins bubble's own fix:
        // in one update the arena drew the head for a frame at its old spot
        // before it was moved onto the bubble.
        popped = (member, (popped?.count ?? 0) + 1, point)
        Task { @MainActor in
            await Task.yield()
            withAnimation(GridConstants.popBurst) {
                parked.removeAll { $0 == member }
                if parked.isEmpty { fanned = false }
            }
            leaving.remove(member)
            persist()
        }
    }

    /// Heads on their way out, so a second tap cannot pop one twice.
    @ObservationIgnored private var leaving: Set<UUID> = []

    /// Everyone out, one at a time rather than all at once (the owner:
    /// "pop them out one by one so its not like overwhelming"). Only ever
    /// from the bubble's press-and-hold menu, never from a tap.
    func releaseAll() {
        fanned = false
        let order = Array(parked.reversed())
        Task { @MainActor in
            for member in order {
                pop(member)
                try? await Task.sleep(for: .milliseconds(180))
            }
        }
    }

    /// Members who left the crew leave the bubble.
    func keepOnly(_ members: [UUID]) {
        // **Contained on first open** (the owner and a friend of his,
        // 2026-10-02): heads already loose on a tower you have never seen
        // read as a glitch, and nothing says the bubble is theirs. In it,
        // a tap lets them out, and you learn where they go back to.
        if firstOpen, !members.isEmpty {
            firstOpen = false
            parked = members
            persist()
            return
        }
        let kept = parked.filter(members.contains)
        if kept != parked { parked = kept; persist() }
    }

    private func persist() {
        firstOpen = false
        defaults.set(parked.map(\.uuidString), forKey: key)
    }
}

// MARK: - The bubble, crowded

/// The top of a crew tower: the crew's faces, or, once heads are dropped into
/// it, those heads crammed into one glass circle.
///
/// **Crammed on purpose** (the owner: "it should actually look like they are
/// cramped in there"). The circle grows only a little with each head while
/// the heads shrink less than it would take to fit, so they overlap and press
/// out past the rim; each is squashed toward the middle and tipped a few
/// degrees; and every arrival makes the circle swell and everyone inside
/// shuffle up. Tap a head to pop it back out.
struct CrewBubble: View {
    let crew: Crew
    let me: UUID
    let parking: CrewParking
    var side: CGFloat = 60
    /// Off: heads are switched off for this crew, and the bubble is only the
    /// crew's picture.
    var showsHeads = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let parked = showsHeads ? parking.parked.compactMap { id in crew.member(id) } : []
        let k = parked.count
        let circle = Self.circle(for: k, side: side)
        ZStack {
            if k == 0 {
                CrewFaces(crew: crew, me: me, side: side)
                    .background(Circle().fill(AppColors.quietFill).padding(-3))
            } else {
                Color.clear
                    .frame(width: circle, height: circle)
                    .stillGlassCircle()
                // While they are fanned out below, the bubble is empty glass:
                // the heads are in the fan, not in two places at once.
                ForEach(Array(parked.enumerated()), id: \.element.id) { index, member in
                    crammed(member, index: index, of: k, circle: circle)
                }
                .opacity(parking.fanned ? 0 : 1)
            }
        }
        .frame(width: circle, height: circle)
        .phaseAnimator([false, true], trigger: parking.landed) { content, swell in
            content.scaleEffect(swell && !reduceMotion ? 1.12 : 1)
        } animation: { swell in
            swell ? GridConstants.tapSquashSpring : GridConstants.elasticPop
        }
        .scaleEffect(parking.over && !reduceMotion ? 1.16 : 1)
        .animation(GridConstants.motionSnappy, value: parking.fanned)
        .animation(GridConstants.motionSnappy, value: parking.over)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { parking.bubbleFrame = $0 }
    }

    @ViewBuilder
    private func crammed(_ member: CrewMember, index: Int, of count: Int, circle: CGFloat) -> some View {
        let spot = Self.spot(index, of: count)
        let size = circle * spot.size
        let rig = CrewHeads.shared.rig(for: member, in: crew.id, me: me)
        Group {
            if let rig {
                LivingHeadView(rig: rig, side: size, liveliness: .calm)
                    .frame(width: size, height: size)
            } else {
                CrewFace(member: member, crew: crew.id, me: me, side: size * 0.8)
            }
        }
        // Squashed toward the middle: pressed by the others.
        .scaleEffect(x: count > 1 ? 0.9 : 1, y: count > 1 ? 1.04 : 1)
        .rotationEffect(.degrees(count > 1 ? spot.tilt : 0))
        .offset(x: circle * spot.x, y: circle * spot.y)
        // Everyone shuffles up when someone new squeezes in.
        .phaseAnimator([false, true], trigger: parking.landed) { content, shove in
            content.offset(x: shove && !reduceMotion ? spot.x * 6 : 0, y: shove && !reduceMotion ? spot.y * 6 : 0)
        } animation: { shove in
            shove ? GridConstants.tapSquashSpring : GridConstants.elasticPop
        }
        // Alive in there: each head bobs on its own slow beat, never in
        // step with its neighbours, so the crowd fidgets rather than pulses.
        .phaseAnimator(reduceMotion ? [false] : [false, true]) { content, up in
            content.offset(y: up ? -1.5 : 0.5)
        } animation: { _ in
            .easeInOut(duration: 1.5 + Double((index * 3) % 5) * 0.21)
        }
        .zIndex(Double(index))
        .allowsHitTesting(false)
        // In with a swell; out at once, because the tower already draws him
        // leaving from this spot and a fading copy here was a second head for
        // two frames (filmed, 2026-10-02).
        .transition(.asymmetric(insertion: .scale(scale: 0.4).combined(with: .opacity), removal: .identity))
        .accessibilityHidden(true)
    }

    /// How wide the bubble is with `count` heads in it.
    static func circle(for count: Int, side: CGFloat) -> CGFloat {
        count <= 1 ? side : side + min(CGFloat(count - 1) * 4, 24)
    }

    /// Where head `index` of `count` sits, as fractions of the circle, how big
    /// it is, and how far it is tipped. Bigger than fits, deliberately.
    ///
    /// **Rows, like a group photo, never a ring** (the owner, 2026-10-02: "it
    /// kinda looks like a cross"). A ring of four round a fifth in the middle
    /// IS a plus sign. People crammed into a booth sit in rows, the back row a
    /// little smaller and higher, each row offset from the one in front so
    /// every face shows between two others: two over two staggered, 2 over 3,
    /// a 1-2-3 pyramid, a 2-3-2 honeycomb, 2-3-3. Later arrivals land in the
    /// front row and are drawn over the back.
    static func spot(_ index: Int, of count: Int) -> (x: CGFloat, y: CGFloat, size: CGFloat, tilt: Double) {
        let tilts: [Double] = [-7, 6, -4, 8, -6, 5, -8, 4]
        let seats: [(x: CGFloat, y: CGFloat, size: CGFloat)]
        switch count {
        case 1: return (0, 0.02, 0.92, 0)
        case 2: seats = [(-0.19, 0.03, 0.72), (0.2, -0.03, 0.68)]
        case 3: seats = [(-0.19, -0.12, 0.6), (0.2, -0.13, 0.57), (0.02, 0.19, 0.62)]
        case 4: seats = [(-0.19, -0.16, 0.52), (0.15, -0.19, 0.5),
                         (-0.12, 0.17, 0.53), (0.22, 0.13, 0.52)]
        case 5: seats = [(-0.14, -0.19, 0.46), (0.16, -0.2, 0.44),
                         (-0.27, 0.13, 0.45), (0.0, 0.18, 0.47), (0.27, 0.12, 0.45)]
        case 6: seats = [(0.01, -0.27, 0.4),
                         (-0.15, -0.03, 0.42), (0.16, -0.04, 0.41),
                         (-0.27, 0.21, 0.42), (0.0, 0.23, 0.43), (0.27, 0.2, 0.42)]
        case 7: seats = [(-0.13, -0.23, 0.36), (0.14, -0.24, 0.36),
                         (-0.27, 0.0, 0.37), (0.0, 0.0, 0.38), (0.27, -0.01, 0.37),
                         (-0.13, 0.24, 0.37), (0.14, 0.23, 0.37)]
        default: seats = [(-0.13, -0.26, 0.34), (0.14, -0.27, 0.34),
                          (-0.26, -0.03, 0.36), (0.0, -0.02, 0.36), (0.26, -0.04, 0.36),
                          (-0.25, 0.22, 0.37), (0.0, 0.25, 0.37), (0.25, 0.21, 0.37)]
        }
        let seat = seats[min(index, seats.count - 1)]
        return (seat.x, seat.y, seat.size, tilts[index % tilts.count])
    }
}

// MARK: - Everyone's heads, loose

/// What every head in one crew tower shares: where each one is, so they can
/// bump, and the world they are in. Not observed, like `TowerCompanionLife`:
/// writing to it invalidates nothing.
@MainActor
final class CrewArenaBox {
    var positions: [UUID: (point: CGPoint, radius: CGFloat)] = [:]
    var statusBar: CGFloat = 0
    var windowSize: CGSize = .zero
}

/// Every member with a head, alive in the crew tower: floating, bouncing off
/// the walls, the blocks and each other; carried by a finger; tapped for a
/// face; dropped into the bubble.
///
/// Built from the same parts as the head on your own tower:
/// `TowerCompanionSim` moves each one and `LivingHeadView` draws it. Each head
/// runs its own `TimelineView`, so each head's view is built once outside its
/// clock and only its transform changes per frame, which is what keeps the
/// Wins tab's one head cheap.
struct CrewHeadArena: View {
    let crew: Crew
    let me: UUID
    let model: CrewTowerModel
    let parking: CrewParking

    @State private var box = CrewArenaBox()

    var body: some View {
        GeometryReader { geo in
            let arena = geo.frame(in: .global)
            ZStack(alignment: .topLeading) {
                // **Everyone, head or not** (the owner, 2026-10-03: "even if a
                // friend doesnt have a head there pfp should still show... they
                // shouldnt be excluded"). A member with no head floats as the
                // circle they are everywhere else in Crews: their photo, or
                // their initial.
                ForEach(crew.members) { member in
                    CrewHeadRunner(member: member, isMe: member.profileID == me,
                                   rig: CrewHeads.shared.rig(for: member, in: crew.id, me: me),
                                   crewID: crew.id, me: me,
                                   arena: arena, model: model, parking: parking, box: box)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .onChange(of: crew.members.map(\.profileID), initial: true) { _, ids in
            parking.keepOnly(ids)
        }
    }
}

@MainActor
private final class CrewHeadLife {
    var sim: TowerCompanionSim
    var placed = false
    var lastFrame: Date?
    var position: CGPoint = .zero
    var tilt: Double = 0
    var world = TowerCompanionWorld(bounds: .zero)
    var emergeFrom: CGSize = .zero
    var emergeStart: Date?
    var emergePending = false
    /// A flight into the bubble: from, and when it started.
    var flightFrom: CGPoint?
    var flightStart: Date?

    init(seed: UInt64) {
        sim = TowerCompanionSim(halfWidth: TowerCompanion.side * TowerCompanion.inkHalfWidth,
                                halfHeight: TowerCompanion.side * TowerCompanion.inkHalfHeight,
                                seed: seed)
    }
}

private struct CrewHeadRunner: View {
    let member: CrewMember
    let isMe: Bool
    /// Nil for someone with no head: they float as their circle.
    let rig: HeadRig?
    let crewID: CrewID
    let me: UUID
    let arena: CGRect
    let model: CrewTowerModel
    let parking: CrewParking
    let box: CrewArenaBox

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.headsAwake) private var headsAwake
    @State private var life: CrewHeadLife
    @State private var take: HeadTake.Played?
    @State private var deck = HeadTakeDeck()

    init(member: CrewMember, isMe: Bool, rig: HeadRig?, crewID: CrewID, me: UUID, arena: CGRect,
         model: CrewTowerModel, parking: CrewParking, box: CrewArenaBox) {
        self.member = member
        self.isMe = isMe
        self.rig = rig
        self.crewID = crewID
        self.me = me
        self.arena = arena
        self.model = model
        self.parking = parking
        self.box = box
        let bits = member.profileID.uuid
        _life = State(initialValue: CrewHeadLife(seed: UInt64(bits.0) << 32 | UInt64(bits.1) << 16 | UInt64(bits.2) | 1))
    }

    private var id: UUID { member.profileID }
    private var name: String { isMe ? "Your head" : "\(member.shortName.isEmpty ? "A friend" : member.shortName)'s head" }

    var body: some View {
        let hidden = parking.isParked(id)
        let flying = parking.arriving[id] != nil
        let carried = parking.dragging == id
        let paused = (reduceMotion && !carried && !flying) || !headsAwake || scenePhase != .active
            || (hidden && !flying)
        // **The Wins head's size, exactly** (the owner, 2026-10-03: "the head
        // should be the same size on the crew and normal"). It was 0.86 of
        // it here, to make room for eight; one head is one size everywhere,
        // and 0.88 of a cell is the size that size was settled at, legible
        // at arm's length and still smaller than one block. See
        // `TowerCompanion.side(forCell:)`.
        let side = TowerCompanion.side(forCell: model.probe.cellSize)
        let head = Group {
            if let rig {
                LivingHeadView(rig: rig, side: side, liveliness: .calm, take: take)
            } else {
                CrewFace(member: member, crew: crewID, me: me, side: side * 0.78)
            }
        }
        .frame(width: side, height: side)
        .contentShape(Circle())

        TimelineView(.animation(paused: paused)) { context in
            let flight = step(to: context.date, paused: paused, side: side)
            if !hidden {
                let emerge = emergence(at: context.date)
                head
                    .scaleEffect(flight)
                    .rotationEffect(.degrees(life.tilt))
                    .offset(x: life.position.x - side / 2 + emerge.width,
                            y: life.position.y - side / 2 + emerge.height)
                    .gesture(drag(side: side))
                    .simultaneousGesture(TapGesture().onEnded { changeFace() })
                    .accessibilityElement()
                    .accessibilityLabel(name)
                    .accessibilityHint("Double-tap for a new face.")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { changeFace() }
                    .accessibilityAction(named: "Put in the bubble") {
                        if reduceMotion { parking.parkNow(id) } else {
                            parking.beginArrival(id, from: CGPoint(x: arena.minX + life.position.x,
                                                                   y: arena.minY + life.position.y))
                        }
                    }
                    .transition(.identity)
            }
        }
        .frame(width: arena.width, height: arena.height, alignment: .topLeading)
        .onChange(of: parking.popped?.count) {
            guard let popped = parking.popped, popped.member == id else { return }
            leaveTheBubble(from: popped.from)
        }
        // An arrival this head did not start itself (VoiceOver's action, a
        // debug film): fly from wherever it is.
        .onChange(of: parking.arriving[id] != nil) { _, arriving in
            guard arriving, life.flightFrom == nil else { return }
            life.flightFrom = life.position
            life.flightStart = nil
        }
    }

    // MARK: Gestures

    private func drag(side: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                let p = CGPoint(x: value.location.x - arena.minX, y: value.location.y - arena.minY)
                if parking.dragging != id { parking.dragging = id }
                let over = parking.isOver(value.location)
                if over != parking.over {
                    parking.over = over
                    if over { HapticsEngine.tick() }
                }
                life.sim.touch(life.sim.state == .held ? .moved : .began, at: p, in: life.world)
            }
            .onEnded { value in
                let p = CGPoint(x: value.location.x - arena.minX, y: value.location.y - arena.minY)
                let v = CGVector(dx: (value.predictedEndTranslation.width - value.translation.width) / 0.25,
                                 dy: (value.predictedEndTranslation.height - value.translation.height) / 0.25)
                let parks = parking.over
                parking.over = false
                parking.dragging = nil
                life.sim.touch(.ended, at: p, velocity: parks ? .zero : v, in: life.world)
                guard parks else { return }
                if reduceMotion {
                    parking.parkNow(id)
                } else {
                    // From where he is drawn, not from the finger.
                    parking.beginArrival(id, from: CGPoint(x: arena.minX + life.position.x,
                                                           y: arena.minY + life.position.y))
                    life.flightFrom = life.position
                    life.flightStart = nil
                }
            }
    }

    private func changeFace() {
        guard let rig else { HapticsEngine.tick(); return }
        let available = HeadTake.available(faces: rig.takeFaces, hasShut: rig.shut != nil, reduceMotion: reduceMotion)
        guard let next = deck.next(from: available) else { return }
        HapticsEngine.tick()
        take = HeadTake.Played(id: next.id, direction: Bool.random() ? 1 : -1, nonce: (take?.nonce ?? 0) + 1)
    }

    // MARK: The bubble

    private var bubbleCentre: CGPoint {
        CGPoint(x: parking.bubbleFrame.midX - arena.minX, y: parking.bubbleFrame.midY - arena.minY)
    }

    /// Out of the bubble: placed at its centre, drawn from there, and clear of
    /// it a third of a second later.
    private func leaveTheBubble(from point: CGPoint? = nil) {
        if let point {
            // Out of the fan: from exactly where the finger chose it.
            let local = CGPoint(x: point.x - arena.minX, y: point.y - arena.minY)
            life.sim.place(in: life.world, at: CGPoint(x: local.x, y: local.y + 30),
                           velocity: CGVector(dx: CGFloat.random(in: -60...60), dy: 150))
            life.emergeFrom = CGSize(width: local.x - life.sim.position.x, height: local.y - life.sim.position.y)
            life.emergeStart = nil
            life.emergePending = !reduceMotion
            return
        }
        let centre = bubbleCentre
        // Out under the bubble and the name, into the room, not onto the
        // bubble's rim: placed on the rim, a head pressed against it and sat
        // there (filmed 2026-10-02).
        let below = (parking.controls["name"]?.maxY ?? parking.bubbleFrame.maxY) - arena.minY
        life.sim.place(in: life.world, at: CGPoint(x: centre.x + CGFloat.random(in: -30...30),
                                                   y: below + life.sim.halfHeight + 12),
                       velocity: CGVector(dx: CGFloat.random(in: -90...90), dy: 140))
        life.emergeFrom = CGSize(width: centre.x - life.sim.position.x, height: centre.y - life.sim.position.y)
        life.emergeStart = nil
        life.emergePending = !reduceMotion
    }

    private func emergence(at now: Date) -> CGSize {
        if life.emergePending {
            life.emergePending = false
            life.emergeStart = now
        }
        guard let start = life.emergeStart else { return .zero }
        let p = min(max(now.timeIntervalSince(start) / 0.32, 0), 1)
        if p >= 1 { life.emergeStart = nil; return .zero }
        let left = pow(1 - p, 3)
        return CGSize(width: life.emergeFrom.width * left, height: life.emergeFrom.height * left)
    }

    // MARK: The frame

    /// Steps the head; during a flight into the bubble, carries it there
    /// instead and returns how small it has got.
    private func step(to now: Date, paused: Bool, side: CGFloat) -> CGFloat {
        guard arena.width > 1, arena.height > 1, arena.minX.isFinite, arena.minY.isFinite else { return 1 }
        let world = makeWorld(side: side)
        life.world = world
        life.sim.halfWidth = side * TowerCompanion.inkHalfWidth
        life.sim.halfHeight = side * TowerCompanion.inkHalfHeight

        if !life.placed {
            life.placed = true
            // Spread across the room, not all on one spot.
            let slot = CGFloat(abs(id.hashValue) % 5) / 4
            life.sim.place(in: world, at: CGPoint(x: world.bounds.minX + world.bounds.width * (0.18 + 0.64 * slot),
                                                  y: world.opening.lowerBound + 40 + CGFloat(abs(id.hashValue) % 90)))
            life.lastFrame = now
        }

        if let from = life.flightFrom {
            if life.flightStart == nil { life.flightStart = now }
            let t = min(now.timeIntervalSince(life.flightStart ?? now) / 0.26, 1)
            let e = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
            // **To his own seat, at his own seat's size.** Flown to the
            // centre at 55%, he landed and jumped to the 92% the bubble draws
            // a lone head at (filmed, 2026-10-02). The seat is the one the
            // bubble will give him: the next of however many are in it.
            let count = parking.parked.count + 1
            let circle = CrewBubble.circle(for: count, side: parking.bubbleFrame.width > 0
                                           ? min(parking.bubbleFrame.width, 60) : 60)
            let seat = CrewBubble.spot(count - 1, of: count)
            let to = CGPoint(x: bubbleCentre.x + seat.x * circle, y: bubbleCentre.y + seat.y * circle)
            let landing = circle * seat.size / side
            life.position = CGPoint(x: from.x + (to.x - from.x) * e, y: from.y + (to.y - from.y) * e)
            life.tilt *= 0.9
            if t >= 1 {
                life.flightFrom = nil
                life.flightStart = nil
                parking.land(id)
            }
            return 1 + (landing - 1) * e
        }

        life.sim.reduceMotion = reduceMotion
        let elapsed = life.lastFrame.map { now.timeIntervalSince($0) } ?? TowerCompanionSim.tick
        life.lastFrame = now
        if !paused || reduceMotion {
            life.sim.update(world, elapsed: elapsed)
            // The others, where they were last frame.
            for (other, spot) in box.positions where other != id && !parking.isHidden(other) {
                life.sim.bump(away: spot.point, otherRadius: spot.radius)
            }
        }
        guard life.sim.position.x.isFinite, life.sim.position.y.isFinite else { return 1 }
        life.position = life.sim.position
        life.tilt = life.sim.tilt
        box.positions[id] = parking.isHidden(id) ? nil : (life.position, life.sim.halfWidth)
        return 1
    }

    private func makeWorld(side: CGFloat) -> TowerCompanionWorld {
        if box.windowSize == .zero {
            for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
                if let w = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
                    box.windowSize = w.bounds.size
                    box.statusBar = w.safeAreaInsets.top
                    break
                }
            }
        }
        let probe = model.probe
        let cell = probe.cellSize
        let gutter = GridConstants.spacing
        let gridWidth = CGFloat(TowerSkyline.columns) * cell + CGFloat(TowerSkyline.columns - 1) * gutter
        let originX = max((arena.width - gridWidth) / 2, 0)
        let gridTopY = probe.gridTopOnScreen - arena.minY
        let ceiling = box.statusBar
        let bounds = CGRect(x: -arena.minX, y: -arena.minY + ceiling,
                            width: max(box.windowSize.width, arena.width),
                            height: arena.minY + arena.height - ceiling)
        let skyline: TowerSkyline = probe.hasMeasured
            ? TowerSkyline.build(cells: model.tower.placedBlocks.lazy.map {
                TowerCompanionWorld.Cell($0.column, $0.row, $0.columnSpan, $0.rowSpan)
              }, originX: originX, cellSize: cell, gutter: gutter, gridTopY: gridTopY,
              gridHeight: probe.gridHeight, cornerInset: GridConstants.blockCornerRadius(forCell: cell))
            : TowerSkyline()
        // The header's controls and, unless a head is being carried to it,
        // the bubble: real objects he bounces off, never invisible walls.
        var obstacles = Array(parking.controls.values)
        if parking.dragging == nil { obstacles.append(parking.bubbleFrame) }
        let local = obstacles.filter { !$0.isEmpty }.map { $0.offsetBy(dx: -arena.minX, dy: -arena.minY) }
        // **They float in the room between the header and the tower**, not
        // in the default band under the status bar: with eight heads there,
        // they lined up along the top edge (filmed 2026-10-02).
        let headerBottom = (parking.controls["name"]?.maxY ?? parking.bubbleFrame.maxY) - arena.minY
        let lower = max(headerBottom + side * 0.5, bounds.minY)
        let roof = probe.hasMeasured ? skyline.highestTop(from: bounds.minX, to: bounds.maxX) : bounds.maxY
        let upper = max(lower + side, min(roof - side * 0.6, lower + 320))
        return TowerCompanionWorld(bounds: bounds, opening: lower...upper, skyline: skyline, obstacles: local)
    }
}

// MARK: - The fan

/// The bubble's heads, spread out: one row up to four, two rows beyond, each
/// at 56pt on one glass panel under the bubble. Tap one and only that one
/// comes out, from where it is. Tapping anywhere else folds them back.
struct CrewFan: View {
    let crew: Crew
    let me: UUID
    let parking: CrewParking
    /// **Draw, last in the fan** (2026-10-07). With heads in the bubble a tap
    /// fans them, so the middle's Draw tab is the fan's last circle: the
    /// bubble still opens Draw, one step further in.
    var onDraw: (() -> Void)? = nil

    static let side: CGFloat = 56
    static let gap: CGFloat = 10

    @State private var centres: [UUID: CGPoint] = [:]

    /// The circles in the fan: the heads, and Draw after them.
    private var count: Int { parking.parked.compactMap { crew.member($0) }.count + (onDraw == nil ? 0 : 1) }

    static func rows(_ count: Int) -> [Range<Int>] {
        guard count > 0 else { return [] }
        let perRow = count <= 4 ? count : Int((Double(count) / 2).rounded(.up))
        return stride(from: 0, to: count, by: perRow).map { $0..<min($0 + perRow, count) }
    }

    static func height(_ count: Int) -> CGFloat {
        let rows = CGFloat(rows(count).count)
        return rows * side + max(rows - 1, 0) * gap + 2 * 14
    }

    var body: some View {
        let parked = parking.parked.compactMap { crew.member($0) }
        VStack(spacing: Self.gap) {
            ForEach(Self.rows(count), id: \.lowerBound) { range in
                HStack(spacing: Self.gap) {
                    ForEach(parked[range.clamped(to: 0..<parked.count)]) { member in head(member) }
                    if let onDraw, range.contains(parked.count) { drawCircle(onDraw) }
                }
            }
        }
        .padding(14)
        .glassRoundedRect(cornerRadius: 28)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Heads in the bubble")
    }

    /// A pencil on the disc a head sits on: the middle's Draw tab.
    private func drawCircle(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "scribble.variable")
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.inkPrimary)
                .frame(width: Self.side, height: Self.side)
                .background(Circle().fill(AppColors.quietFill))
                .contentShape(Circle())
        }
        .buttonStyle(.pressSurface)
        .transition(.scale(scale: 0.6).combined(with: .opacity))
        .accessibilityLabel("Draw")
        .accessibilityHint("Draws something for this crew's tower.")
    }

    private func head(_ member: CrewMember) -> some View {
        let rig = CrewHeads.shared.rig(for: member, in: crew.id, me: me)
        return Button {
            parking.pop(member.profileID, from: centres[member.profileID])
        } label: {
            // Everyone in the same circle: a head on the disc a photo fills.
            Group {
                if let rig {
                    LivingHeadView(rig: rig, side: Self.side * 0.92, liveliness: .calm)
                        .frame(width: Self.side, height: Self.side)
                        .background(Circle().fill(AppColors.quietFill))
                        .clipShape(Circle())
                } else {
                    CrewFace(member: member, crew: crew.id, me: me, side: Self.side)
                }
            }
            .frame(width: Self.side, height: Self.side)
            .contentShape(Circle())
        }
        .buttonStyle(.pressSurface)
        .onGeometryChange(for: CGPoint.self) { proxy in
            let f = proxy.frame(in: .global)
            return CGPoint(x: f.midX, y: f.midY)
        } action: { centres[member.profileID] = $0 }
        .transition(.scale(scale: 0.6).combined(with: .opacity))
        .accessibilityLabel(member.profileID == me ? "Your head" : "\(member.shortName.isEmpty ? "A friend" : member.shortName)'s head")
        .accessibilityHint("Lets them out of the bubble.")
    }
}
