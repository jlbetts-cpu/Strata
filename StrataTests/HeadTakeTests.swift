import Testing
import Foundation
import CoreGraphics
@testable import Strata

/// A tap's expressions: the catalogue, the deck that picks them, and how long
/// they hold. Owner, 2026-09-15: "there should be a bunch of expressions and
/// they should hold for longer."
///
/// Self-test: set any take's hold to 1.4 (the old wink) and
/// `everyTakeHoldsLongEnough` fails; drop the swap-first rule in
/// `HeadTakeDeck.next` and `neverTheSameTwiceRunning` fails (about one repeat
/// in twelve refills).
@Suite("HeadTake")
struct HeadTakeTests {

    /// A tiny deterministic generator; `SystemRandomNumberGenerator` cannot be seeded.
    struct SplitMix: RandomNumberGenerator {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    private let allFaces = Set(HeadRig.Expression.allCases)

    @Test("a bunch of expressions: twelve, none twice")
    func twelveTakes() {
        #expect(HeadTake.catalogue.count == 12)
        #expect(Set(HeadTake.catalogue.map(\.id)).count == 12)
        #expect(HeadTake.ID.allCases.count == 12)
    }

    @Test("every take holds 2.6 to 3.4 seconds, and every cue lands inside the hold")
    func everyTakeHoldsLongEnough() {
        for take in HeadTake.catalogue {
            #expect((GridConstants.headTakeHoldShort...GridConstants.headTakeHoldLong).contains(take.hold),
                    "\(take.id) holds \(take.hold)")
            #expect(take.hold >= 2.6 && take.hold <= 3.4)
            #expect(take.cues.map(\.at) == take.cues.map(\.at).sorted(), "\(take.id) cues out of order")
            for cue in take.cues { #expect(cue.at >= 0 && cue.at < take.hold, "\(take.id) cue at \(cue.at)") }
            // The player walks `schedule`, so this is the timing that runs.
            let schedule = take.schedule(direction: 1)
            #expect(schedule.last?.event == .easeBack)
            #expect(schedule.last?.at == take.hold)
            #expect(schedule.dropLast().allSatisfy { $0.at < take.hold })
            #expect(schedule.count == take.cues.count + 1)
        }
    }

    @Test("a take's face is one it needs, and a face without drawn irises gets no gaze")
    func facesAndGaze() {
        for take in HeadTake.catalogue {
            #expect(take.face == .neutral || take.needs.contains(take.face), "\(take.id)")
            // With every face, the take ends on its signature face or goes
            // back to neutral, never somewhere unannounced.
            var wearing: HeadRig.Expression = .neutral
            for cue in take.cues {
                switch cue.step {
                case let .face(next): wearing = next
                case .look:
                    #expect(wearing != .smile && wearing != .wink, "\(take.id) looks with the photograph's own eyes")
                default: break
                }
            }
        }
    }

    @Test("a take's face is up for at least a second and a half before it eases back")
    func theFaceIsHeld() {
        // Owner: "they should hold for longer". The tap's face used to be up
        // for 1.4s; every take now shows the face it reaches for longer than
        // that before anything starts going back.
        for take in HeadTake.catalogue {
            var reached: TimeInterval?
            var wearing: HeadRig.Expression = .neutral
            for moment in take.schedule(direction: 1) {
                guard case let .cue(step) = moment.event, case let .face(next) = step else { continue }
                wearing = next
                reached = next == .neutral ? nil : moment.at
            }
            guard let reached else {
                // A take with no face of its own (sideEye, thinking, sleepy)
                // carries its whole hold on the eyes and the head instead.
                #expect(take.face == .neutral, "\(take.id)")
                #expect(take.hold >= 2.6)
                continue
            }
            #expect(wearing != .neutral)
            #expect(take.hold - reached >= 1.5, "\(take.id) holds its face \(take.hold - reached)s")
        }
    }

    @Test("a take that keeps its eyes somewhere says where, for the photograph")
    func stillGazeIsTheLastLook() {
        #expect(HeadTake.take(.sideEye).stillGaze(direction: 1) == CGPoint(x: 0.9, y: 0.05))
        #expect(HeadTake.take(.sideEye).stillGaze(direction: -1) == CGPoint(x: -0.9, y: 0.05))
        #expect(HeadTake.take(.thinking).stillGaze(direction: 1) == CGPoint(x: 0.2, y: -0.85))
        // A look that keeps the resting point wanders, so there is nothing to keep.
        #expect(HeadTake.take(.sleepy).stillGaze(direction: 1) == nil)
        #expect(HeadTake.take(.nod).stillGaze(direction: 1) == nil)
        #expect(HeadTake.take(.grin).stillGaze(direction: 1) == nil)
    }

    @Test("no take looks straight at you")
    func nobodyStares() {
        for take in HeadTake.catalogue {
            for cue in take.cues {
                if case let .look(x, y, keepsRest, _) = cue.step, !keepsRest {
                    // The file's own floor for the eyes: 45% of the way out.
                    #expect(hypot(x, y) >= 0.45, "\(take.id) looks near the middle")
                }
            }
        }
    }

    @Test("which takes a head gets depends on the faces it has")
    func availability() {
        #expect(HeadTake.available(faces: [.neutral], hasShut: false, reduceMotion: false).map(\.id)
                == [.sideEye, .thinking, .nod, .shake])
        #expect(HeadTake.available(faces: [.neutral], hasShut: true, reduceMotion: false).map(\.id)
                == [.sideEye, .sleepy, .thinking, .nod, .shake])
        #expect(HeadTake.available(faces: allFaces, hasShut: true, reduceMotion: false).count == 12)
    }

    @Test("Reduce Motion: one take per face, none neutral, so no tap repeats a picture")
    func reduceMotionIsFacesOnly() {
        let deck = HeadTake.available(faces: allFaces, hasShut: true, reduceMotion: true)
        #expect(deck.count == 4)
        #expect(Set(deck.map(\.face)).count == deck.count)
        #expect(!deck.contains { $0.face == .neutral })
        #expect(HeadTake.available(faces: [.neutral], hasShut: true, reduceMotion: true).isEmpty)
        #expect(HeadTake.available(faces: [.neutral, .smile], hasShut: true, reduceMotion: true).map(\.face) == [.smile])
    }

    @Test("never the same take twice running, and every take before any repeats")
    func neverTheSameTwiceRunning() {
        var rng = SplitMix(seed: 7)
        var deck = HeadTakeDeck()
        let all = HeadTake.catalogue
        var draws: [HeadTake.ID] = []
        for _ in 0..<10_000 {
            draws.append(deck.next(from: all, using: &rng)!.id)
        }
        for i in 1..<draws.count {
            #expect(draws[i] != draws[i - 1], "repeat at \(i)")
            if draws[i] == draws[i - 1] { break }
        }
        for start in stride(from: 0, to: draws.count - 11, by: 12) {
            #expect(Set(draws[start..<start + 12]).count == 12)
        }
        // A smaller head still never repeats.
        let few = HeadTake.available(faces: [.neutral], hasShut: false, reduceMotion: false)
        var small = HeadTakeDeck()
        var previous: HeadTake.ID?
        for _ in 0..<2_000 {
            let id = small.next(from: few, using: &rng)!.id
            #expect(id != previous)
            previous = id
        }
    }

    @Test("one take available always plays it; none plays nothing")
    func oneOrNone() {
        var rng = SplitMix(seed: 3)
        var deck = HeadTakeDeck()
        let one = [HeadTake.take(.grin)]
        for _ in 0..<5 { #expect(deck.next(from: one, using: &rng)?.id == .grin) }
        #expect(deck.next(from: [], using: &rng) == nil)
    }

    @Test("mirroring flips x, yaw, roll and lean, never y, dip or faces")
    func mirroring() {
        for take in HeadTake.catalogue {
            let left = take.cues(direction: -1)
            #expect(left.count == take.cues.count)
            for (a, b) in zip(take.cues, left) {
                #expect(a.at == b.at)
                switch (a.step, b.step) {
                case let (.look(x1, y1, k1, s1), .look(x2, y2, k2, s2)):
                    #expect(x2 == -x1 && y2 == y1 && k1 == k2 && s1 == s2)
                case let (.pose(yaw1, roll1, lean1, dip1, m1), .pose(yaw2, roll2, lean2, dip2, m2)):
                    #expect(yaw2 == -yaw1 && roll2 == -roll1 && lean2 == -lean1 && dip2 == dip1 && m1 == m2)
                default:
                    #expect(a.step == b.step)
                }
            }
        }
    }

    @Test("the face a sticker keeps is the last face the head could do")
    func endFace() {
        #expect(HeadTake.take(.winkGrin).endFace(has: { _ in true }) == .smile)
        #expect(HeadTake.take(.nod).endFace(has: { _ in true }) == .smile)
        #expect(HeadTake.take(.nod).endFace(has: { $0 == .neutral }) == .neutral)
        #expect(HeadTake.take(.sleepy).endFace(has: { _ in true }) == .neutral)
        #expect(HeadTake.take(.sideEye).endFace(has: { _ in true }) == .neutral)
        for take in HeadTake.catalogue where take.face != .neutral {
            #expect(take.endFace(has: { _ in true }) == take.face, "\(take.id)")
        }
    }
}
