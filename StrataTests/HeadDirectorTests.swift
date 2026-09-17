import Testing
import Foundation
import CoreGraphics
@testable import Strata

/// One engine: the idle beats as data, the director that picks them, and the
/// limits on eye contact. Owner, 2026-09-16: a made head must be "as
/// expressive as" his own, and an expressive head may rest its eyes on you
/// for up to three seconds, then look away on purpose; chrome never stares.
///
/// Self-test: set `headContactMax` to 4 and give `headContactHold` an upper
/// bound of 4, and `contactIsBounded` fails; drop the `!lastWasContact`
/// check in `nextFixation` and `contactAlwaysLooksAway` fails; put `.turn` in
/// `HeadLife.calm`'s weights and `calmNeverMovesOrStares` fails.
@Suite("HeadDirector")
struct HeadDirectorTests {
    private let allFaces = Set(HeadRig.Expression.allCases)

    private func full(_ life: HeadLife = .expressive, seed: UInt64 = 7, target: CGPoint? = nil) -> HeadDirector {
        HeadDirector(life: life, faces: allFaces, shutFaces: [.neutral, .browsUp, .surprised],
                     lookTarget: target, seed: seed)
    }

    // MARK: - Beat data

    @Test("every beat resolves in order, ends on .end, and only uses what the head has")
    func beatData() {
        let heads: [(Set<HeadRig.Expression>, Set<HeadRig.Expression>)] = [
            (allFaces, [.neutral, .browsUp, .surprised]),
            ([.neutral], [.neutral]),
            ([.neutral], []),
            ([.neutral, .smile], [.neutral])
        ]
        for life in [HeadLife.expressive, .calm] {
            for (faces, shut) in heads {
                var director = HeadDirector(life: life, faces: faces, shutFaces: shut, seed: 11)
                for id in director.weights.map(\.0) + [.hello] {
                    for direction in [1.0, -1.0] {
                        let moments = director.resolve(id, direction: direction)
                        #expect(moments.last?.event == .end, "\(id)")
                        #expect(moments.map(\.at) == moments.map(\.at).sorted(), "\(id) out of order")
                        #expect(moments.allSatisfy { $0.at >= 0 && $0.at <= 4 }, "\(id)")
                        #expect(moments.dropLast().allSatisfy { $0.event != .end })
                        for moment in moments {
                            guard case let .cue(step) = moment.event else { continue }
                            switch step {
                            case let .face(face):
                                #expect(face == .neutral || faces.contains(face), "\(id) wears \(face)")
                            case .lids, .blink:
                                #expect(shut.contains(.neutral), "\(id) blinks without shut eyes")
                            case let .pose(yaw, roll, _, _, _):
                                #expect(life.movesHead, "\(id) moves a calm head")
                                #expect(abs(yaw) <= GridConstants.headMaxYaw && abs(roll) <= 6, "\(id)")
                            case let .look(x, y, keepsRest, _):
                                // A beat's look is never at you: the stare floor.
                                if !keepsRest { #expect(hypot(x, y) >= 0.45 - 1e-9, "\(id) looks near the middle") }
                            default:
                                break
                            }
                        }
                    }
                }
            }
        }
    }

    @Test("the creator's six beats keep 80% of the weight, and a third of beats turn the head")
    func expressiveMix() {
        let weights = Dictionary(uniqueKeysWithValues: full().weights)
        let total = weights.values.reduce(0, +)
        #expect(abs(total - 1) < 1e-9)
        let core = [HeadBeat.ID.glance, .turn, .tilt, .smile, .down, .brow].compactMap { weights[$0] }.reduce(0, +)
        #expect(abs(core - 0.8) < 1e-9)
        let turns = (weights[.glance] ?? 0) + (weights[.turn] ?? 0)
        #expect(turns >= 0.35, "yaw share \(turns)")
    }

    @Test("a turn is 16°, a glance 5°, and the eyes land first")
    func turnAndGlance() {
        var director = full()
        let turn = director.resolve(.turn, direction: 1)
        let yaws = turn.compactMap { m -> (Double, Double)? in
            if case let .cue(.pose(yaw, _, _, _, _)) = m.event, yaw != 0 { return (m.at, yaw) }
            return nil
        }
        #expect(yaws.map(\.1) == [16])
        let firstLook = turn.first { if case .cue(.look) = $0.event { return true }; return false }
        #expect(firstLook?.at == 0)
        #expect(yaws.first.map { $0.0 >= GridConstants.headEyesLead } == true)
        let glance = director.resolve(.glance, direction: -1)
        #expect(glance.contains { if case let .cue(.pose(yaw, _, _, _, _)) = $0.event { return yaw == -5 }; return false })
        // A page's target sets where a turn goes.
        var aimed = full(target: CGPoint(x: -0.8, y: -0.8))
        #expect(aimed.resolve(.turn, direction: 1).contains {
            if case let .cue(.pose(yaw, _, _, _, _)) = $0.event { return abs(yaw + 12.8) < 1e-9 }; return false
        })
    }

    @Test("the same seed is the same life on any head with the same faces")
    func sameSeedSameLife() {
        var a = full(seed: 42), b = full(seed: 42)
        for _ in 0..<400 {
            #expect(a.nextRest() == b.nextRest())
            let beatA = a.nextBeat(), beatB = b.nextBeat()
            #expect(beatA.id == beatB.id && beatA.direction == beatB.direction)
            #expect(a.resolve(beatA.id, direction: beatA.direction) == b.resolve(beatB.id, direction: beatB.direction))
            #expect(a.nextFixation() == b.nextFixation())
            #expect(a.nextBlink() == b.nextBlink())
        }
    }

    @Test("never the same beat twice running")
    func neverTwiceRunning() {
        var director = full(seed: 3)
        var last: HeadBeat.ID?
        for _ in 0..<5_000 {
            let next = director.nextBeat().id
            #expect(next != last)
            last = next
        }
    }

    @Test("a head with only neutral and shut still moves: lift for brows, nod for a smile")
    func fallbacksStillMove() {
        let small = HeadDirector(life: .expressive, faces: [.neutral], shutFaces: [.neutral], seed: 1)
        let weights = Dictionary(uniqueKeysWithValues: small.weights)
        #expect(weights[.lift] != nil && weights[.nod] != nil)
        #expect(weights[.brow] == nil && weights[.smile] == nil && weights[.wink] == nil)
        let yaw = (weights[.glance] ?? 0) + (weights[.turn] ?? 0)
        let fullYaw = Dictionary(uniqueKeysWithValues: full().weights)
        #expect(yaw / weights.values.reduce(0, +) >= ((fullYaw[.glance] ?? 0) + (fullYaw[.turn] ?? 0)) * 0.9)
        // A head that cannot blink turns instead of blinking slowly.
        let noShut = HeadDirector(life: .expressive, faces: [.neutral], shutFaces: [], seed: 1)
        let w = Dictionary(uniqueKeysWithValues: noShut.weights)
        #expect(w[.slowBlink] == nil)
        #expect((w[.turn] ?? 0) > (weights[.turn] ?? 0))
    }

    // MARK: - Eye contact

    /// An hour of fixations, as the eyes loop plays them.
    private func hour(_ director: inout HeadDirector, allowContact: Bool = true)
        -> (contact: Double, total: Double, holds: [Double], fixations: [HeadDirector.Fixation]) {
        var t = 0.0, contact = 0.0, holds: [Double] = [], all: [HeadDirector.Fixation] = []
        while t < 3600 {
            let f = director.nextFixation(allowContact: allowContact)
            all.append(f)
            if f.contact { contact += f.hold; holds.append(f.hold) }
            t += f.hold
        }
        return (contact, t, holds, all)
    }

    @Test("eye contact never lasts more than three seconds")
    func contactIsBounded() {
        for seed in UInt64(1)...5 {
            var director = full(seed: seed)
            let result = hour(&director)
            #expect(!result.holds.isEmpty)
            // The owner's number, as a literal: raising the token must fail here.
            #expect(result.holds.allSatisfy { $0 <= 3.0 }, "longest \(result.holds.max() ?? 0)")
            #expect(result.holds.allSatisfy { $0 >= GridConstants.headContactHold.lowerBound })
            // Enough to feel engaged, not so much it stares.
            let share = result.contact / result.total
            #expect(share > 0.3 && share < 0.6, "contact share \(share)")
        }
    }

    @Test("after contact the eyes always look away, and away is never near the middle")
    func contactAlwaysLooksAway() {
        var director = full(seed: 9)
        let fixations = hour(&director).fixations
        for (a, b) in zip(fixations, fixations.dropFirst()) where a.contact {
            #expect(!b.contact)
        }
        for f in fixations {
            if f.contact {
                #expect(hypot(f.gaze.x, f.gaze.y) < 0.1)
            } else {
                #expect(hypot(f.gaze.x, f.gaze.y) >= GridConstants.headStareFloor - 1e-9)
            }
        }
    }

    @Test("calm heads and takes never rest on you, and a calm head never moves on its own")
    func calmNeverMovesOrStares() {
        var calm = full(.calm)
        #expect(hour(&calm).holds.isEmpty)
        var taking = full()
        #expect(hour(&taking, allowContact: false).holds.isEmpty)
        #expect(HeadLife.calm.contactShare == 0)
        #expect(HeadLife.expressive.contactHold.upperBound <= 3.0)
        #expect(GridConstants.headContactMax <= 3.0)
        for (id, _) in calm.weights {
            #expect(!calm.resolve(id, direction: 1).contains {
                if case .cue(.pose) = $0.event { return true }
                return false
            }, "\(id)")
        }
        #expect(calm.nextMicro() == nil)
    }

    @Test("a look that keeps the rest never pulls an away point near the middle, for any beat or take")
    func keptRestNeverNearContact() {
        var offsets: [CGPoint] = []
        for take in HeadTake.catalogue {
            for direction in [1.0, -1.0] {
                for cue in take.cues(direction: direction) {
                    if case let .look(x, y, true, _) = cue.step { offsets.append(CGPoint(x: x, y: y)) }
                }
            }
        }
        for seed in UInt64(1)...20 {
            var director = full(seed: seed)
            for id in director.weights.map(\.0) + [.hello] {
                for direction in [1.0, -1.0] {
                    for moment in director.resolve(id, direction: direction) {
                        if case let .cue(.look(x, y, true, _)) = moment.event { offsets.append(CGPoint(x: x, y: y)) }
                    }
                }
            }
        }
        #expect(offsets.contains { $0.y >= 0.3 }, "sleepy's droop is in the set")
        // The worst away points: every direction at the floor, plus the director's own.
        var aways: [CGPoint] = (0..<72).map { i in
            let a = Double(i) / 72 * 2 * .pi
            return CGPoint(x: cos(a) * 0.45, y: sin(a) * 0.45)
        }
        var director = full(seed: 99)
        for _ in 0..<2_000 { aways.append(director.nextAway()) }
        let micro = GridConstants.headMicroX, microY = GridConstants.headMicroY
        var worst = 1.0
        for away in aways {
            for offset in offsets + [.zero] {
                for m in [CGPoint(x: micro, y: microY), CGPoint(x: -micro, y: -microY), .zero] {
                    let g = HeadDirector.composedGaze(rest: away, restShare: 1, micro: m, look: offset, restIsContact: false)
                    worst = min(worst, hypot(g.x, g.y))
                }
            }
        }
        #expect(worst >= GridConstants.headStareFloor - 1e-9, "nearest \(worst)")
        // Contact is left alone: that is the one time the eyes are meant to be on you.
        let onYou = HeadDirector.composedGaze(rest: CGPoint(x: 0.05, y: 0), restShare: 1, micro: .zero,
                                              look: .zero, restIsContact: true)
        #expect(hypot(onYou.x, onYou.y) < 0.1)
    }

    // MARK: - Blinks

    @Test("blinks: 2.6 to 5.8s apart, a crunch on an expressive head only, one in four doubled")
    func blinks() {
        var expressive = full(seed: 5), calm = full(.calm, seed: 5)
        var doubles = 0
        let n = 5_000
        for _ in 0..<n {
            let b = expressive.nextBlink()
            #expect(GridConstants.headBlinkGap.contains(b.gap))
            #expect(GridConstants.headBlinkDepth.contains(b.depth))
            #expect((1...2).contains(b.steps))
            if b.double { doubles += 1 }
            #expect(calm.nextBlink().depth == 1)
        }
        let share = Double(doubles) / Double(n)
        #expect(abs(share - GridConstants.headDoubleBlinkShare) < 0.03, "double share \(share)")
    }

    @Test("no tap's take uses the idle-only steps")
    func takesDoNotBlinkOrSettle() {
        for take in HeadTake.catalogue {
            for cue in take.cues {
                switch cue.step {
                case .blink, .settle: Issue.record("\(take.id) uses an idle-only step")
                default: break
                }
            }
        }
    }
}
