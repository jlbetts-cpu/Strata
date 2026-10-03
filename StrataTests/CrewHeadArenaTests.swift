import Testing
import Foundation
import CoreGraphics
@testable import Strata

/// **Everyone's heads in one crew tower.**
@MainActor
@Suite("Crew heads", .serialized)
struct CrewHeadArenaTests {
    static func world() -> TowerCompanionWorld {
        TowerCompanionWorld(bounds: CGRect(x: 0, y: 0, width: 400, height: 800))
    }

    @Test func twoHeadsDoNotPassThroughEachOther() {
        var a = TowerCompanionSim(halfWidth: 30, halfHeight: 34, seed: 1)
        var b = TowerCompanionSim(halfWidth: 30, halfHeight: 34, seed: 2)
        a.place(in: Self.world(), at: CGPoint(x: 200, y: 300), velocity: CGVector(dx: 50, dy: 0))
        b.place(in: Self.world(), at: CGPoint(x: 220, y: 300), velocity: CGVector(dx: -50, dy: 0))
        let aTouched = a.bump(away: b.position, otherRadius: b.halfWidth)
        let bTouched = b.bump(away: a.position, otherRadius: a.halfWidth)
        #expect(aTouched && bTouched)
        #expect(a.position.x < 200, "pushed away from the other")
        #expect(a.velocity.dx <= 0, "no longer heading into the other")
        #expect(b.velocity.dx >= 0)
        // Far apart: nothing happens.
        var c = TowerCompanionSim(halfWidth: 30, halfHeight: 34, seed: 3)
        c.place(in: Self.world(), at: CGPoint(x: 50, y: 50))
        let far = c.bump(away: CGPoint(x: 300, y: 600), otherRadius: 30)
        #expect(!far)
    }

    @Test func aCarriedHeadIsNeverShoved() {
        var held = TowerCompanionSim(halfWidth: 30, halfHeight: 34, seed: 4)
        held.place(in: Self.world(), at: CGPoint(x: 200, y: 300))
        held.touch(.began, at: CGPoint(x: 200, y: 300), in: Self.world())
        let before = held.position
        let shoved = held.bump(away: CGPoint(x: 205, y: 300), otherRadius: 30)
        #expect(!shoved)
        #expect(held.position == before)
    }

    @Test func theBubbleIsKeptPerCrewAndForgetsWhoLeft() async {
        let defaults = UserDefaults(suiteName: "crew-park-\(UUID().uuidString)")!
        let one = CrewID(rawValue: "crew-one"), two = CrewID(rawValue: "crew-two")
        let sam = UUID(), ana = UUID()
        let a = CrewParking(crewID: one, defaults: defaults)
        a.land(sam)
        a.land(ana)
        #expect(CrewParking(crewID: one, defaults: defaults).parked == [sam, ana])
        #expect(CrewParking(crewID: two, defaults: defaults).parked.isEmpty)
        a.pop(sam)
        // Let go a beat after being placed, so the pop has no stray frame.
        try? await Task.sleep(for: .milliseconds(50))
        #expect(a.parked == [ana])
        #expect(a.popped?.member == sam)
        a.keepOnly([sam])
        #expect(a.parked.isEmpty)
    }

    /// A crew never opened on this phone starts with everyone in the
    /// bubble; once anyone is let out, that is remembered, not undone.
    @Test func aFirstOpenStartsEveryoneContained() async {
        let defaults = UserDefaults(suiteName: "crew-park-\(UUID().uuidString)")!
        let crew = CrewID(rawValue: "crew-first")
        let sam = UUID(), ana = UUID()
        let a = CrewParking(crewID: crew, defaults: defaults)
        a.keepOnly([sam, ana])
        #expect(a.parked == [sam, ana])
        a.pop(sam)
        try? await Task.sleep(for: .milliseconds(50))
        a.keepOnly([sam, ana])
        #expect(a.parked == [ana])
        #expect(CrewParking(crewID: crew, defaults: defaults).parked == [ana])
    }

    @Test func everyCrampedHeadStaysCentredOnTheBubble() {
        for count in 1...CrewCaps.members {
            for index in 0..<count {
                let spot = CrewBubble.spot(index, of: count)
                #expect(hypot(spot.x, spot.y) <= 0.5, "head \(index) of \(count) is centred inside")
                // Crammed: bigger than a fair share of the circle would allow.
                #expect(spot.size * spot.size * CGFloat(count) >= 0.85 || count == 1)
            }
        }
    }
}
