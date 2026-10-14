import Foundation
import CoreGraphics
import Testing
@testable import Strata

/// **The tower head's bubble and his faces, 2026-10-02.** The owner: tap him
/// and he changes faces "just like the camera"; drag him and a glass bubble
/// appears left of the Plan button, the same size; let go in it and he parks;
/// tap it and it pops.
@MainActor
@Suite("Tower head: faces and the bubble")
struct CompanionParkingTests {

    @Test("a finger is in the bubble with a little slop, and not beyond it")
    func catchArea() {
        let parking = CompanionParking.shared
        let before = parking.dockFrame
        defer { parking.dockFrame = before }
        parking.dockFrame = CGRect(x: 290, y: 75, width: 44, height: 44)
        #expect(parking.isOver(CGPoint(x: 312, y: 97)))
        #expect(parking.isOver(CGPoint(x: 290 - CompanionParking.catchSlop + 1, y: 97)))
        #expect(!parking.isOver(CGPoint(x: 200, y: 300)))
        parking.dockFrame = .zero
        #expect(!parking.isOver(CGPoint(x: 0, y: 0)), "no bubble measured yet, nothing catches")
    }

    @Test("the bubble is the Plan button's size, and he fits inside it with glass round him")
    func sizes() {
        #expect(CompanionParking.parkedSide < GlassIconButton.defaultSide)
        #expect(GlassIconButton.defaultSide - CompanionParking.parkedSide >= 8)
    }

    /// **Reversed by the owner on 2026-10-05.** This pinned the bubble
    /// "directly left of the Plan button" (his call, 2026-10-02); he then took
    /// it off the Wins header: "remove the head from the main home screen
    /// because i feel like it would make too many buttons there since we
    /// added the journal component." So it now pins the opposite.
    ///
    /// **And the dock came back as the crest, 2026-10-14** (the owner,
    /// 2026-10-13: "pfp/head in middle of wins tower (press, head comes
    /// out)"). It pinned `!hasDock` and "never parked", because a head
    /// parked in a bubble nobody can see has vanished. The crest is on
    /// screen whenever the tower is, so parking in it is somewhere he can
    /// be seen and let out of; what this still pins is that the crest
    /// reports its frame, the thing that made the old bubble safe.
    @Test("the Wins header has no head bubble; the crest is his dock and says where it is")
    func placement() throws {
        let text = try MorningSource.read("Views/MainAppView.swift")
        let header = text.components(separatedBy: "private var towerHeader: some View {").last ?? ""
        // Up to the day's button, which replaced the Journal and Plan pair
        // on 2026-10-05: the bubble stood directly left of the Plan.
        let row = header.components(separatedBy: "Spacer(minLength: 0)").first ?? ""
        #expect(!row.contains("CompanionDock()"), "the bubble is back in the Wins header, which the owner removed")
        #expect(row.contains("headerDay"))
        #expect(CompanionParking.hasDock)
        let ring = try MorningSource.read("Views/GoalRing.swift")
        #expect(ring.contains("CompanionParking.shared.dockFrame = $0"),
                "parked in a crest that never said where it is, he could not be let out of it")
        #expect(row.contains("HStack(alignment: .center, spacing: GridConstants.gapTight)"))
        // The 2026-10-02 group fused two discs into one peanut, which is what
        // this guards. Journal and Plan were one `HeaderGlassPair` for the
        // morning of 2026-10-05 and are one button now, so nothing on the
        // header can fuse: `WinsBatchTests.pairDoesNotFuse` holds that.
        #expect(!header.prefix(1500).contains(".headerGlassGroup"), "one glass group fused the two into a peanut")
    }

    @Test("a tap on the tower head plays a face, from the same deck as the camera")
    func tapChangesFace() throws {
        let text = try MorningSource.read("Views/TowerCompanionLayer.swift")
        #expect(text.contains(".simultaneousGesture(TapGesture().onEnded { changeFace() })"))
        #expect(text.contains("LivingHeadView(rig: rig, side: side, liveliness: .calm, take: take)"))
        #expect(text.contains("guard let next = deck.next(from: available) else { return }"))
    }

    /// **Flying in is the tower's now** (2026-10-14). This pinned `arriving`
    /// among the things that pause and hide him, because the header bubble
    /// drew his flight. The crest does not; the tower's layer sits over the
    /// header, so it draws the flight itself, as a crew's arena does, and
    /// needs its clock to.
    @Test("parked, the tower stops simulating him and the crest draws him; flying in, the tower does")
    func parkedPausesTheHead() throws {
        let text = try MorningSource.read("Views/TowerCompanionLayer.swift")
        #expect(text.contains("|| parking.parked\n"))
        #expect(text.contains("parking.parked || parking.releasing"))
        #expect(text.contains("if fly(at: now) {"))
        #expect(text.contains("if !hidden {"))
        let dock = try MorningSource.read("Views/CompanionDock.swift")
        #expect(dock.contains(".overlay { head(rig: rig) }"), "he is drawn over the glass, not under it")
        // One view for flying in, parked and bursting out, so his face loads once.
        #expect(dock.contains("if parking.flightFrom != nil || parking.parked || bursting {"))
    }

    @Test("the pop sets the burst before it lets go of parked, and the bubble stays while releasing")
    func popOrdering() throws {
        let dock = try MorningSource.read("Views/CompanionDock.swift")
        #expect(dock.contains("var showsDock: Bool { dragging || arriving || parked || releasing }"))
        let burst = dock.components(separatedBy: "private func burst() {").last ?? ""
        let burstAt = burst.range(of: "bursting = true")
        let letGoAt = burst.range(of: "parking.parked = false")
        #expect(burstAt != nil && letGoAt != nil)
        if let b = burstAt, let l = letGoAt { #expect(b.lowerBound < l.lowerBound) }
    }

    @Test("the drops leave from his edge and land past it, so they are seen")
    func dropsClearHim() throws {
        let dock = try MorningSource.read("Views/CompanionDock.swift")
        #expect(dock.contains("private var dropReach: CGFloat { parking.headSide / 2 + 22 }"))
        #expect(dock.contains("private var dropStart: CGFloat { parking.headSide * 0.4 }"))
    }

    @Test("his ceiling is the status bar, where iOS would otherwise take the tap")
    func statusBarCeiling() throws {
        let layer = try MorningSource.read("Views/TowerCompanionLayer.swift")
        #expect(layer.contains("life.statusBar = w.safeAreaInsets.top"))
        #expect(layer.contains("let box = CGRect(x: -arena.minX, y: -arena.minY + ceiling,"))
    }

    /// "Park him" came out on 2026-10-05 with the bubble (see `placement`):
    /// an action that parks him into a place that is not on screen hides him.
    @Test("VoiceOver can reach him and change his face, and is not offered a bubble that is gone")
    func voiceOver() throws {
        let layer = try MorningSource.read("Views/TowerCompanionLayer.swift")
        #expect(layer.contains(".accessibilityLabel(\"Your head\")"))
        #expect(!layer.contains(".accessibilityAction(named: \"Park in the bubble\")"))
        // The crest is on screen, so VoiceOver can put him there (2026-10-14).
        #expect(layer.contains(".accessibilityAction(named: \"Put in the Ring\")"))
        let dock = try MorningSource.read("Views/CompanionDock.swift")
        #expect(dock.contains(".accessibilityAction { pop() }"))
    }
}

/// **Your face in the middle of Wins lets your head out** (the owner,
/// 2026-10-13: "pfp/head in middle of wins tower (press, head comes out)").
@MainActor
@Suite("Wins crest: the head goes in and comes out")
struct CrestDockTests {
    @Test("let out: handed over in order, out of the crest, and never twice")
    func letOutOrder() async {
        let parking = CompanionParking.shared
        let before = (parking.parked, parking.popped)
        defer { parking.parked = before.0 }
        parking.parked = true
        parking.letOut()
        #expect(!parking.parked)
        #expect(parking.releasing, "the crest keeps drawing him for the beat the tower takes to place him")
        #expect(parking.popped == before.1 + 1)
        parking.letOut()
        #expect(parking.popped == before.1 + 1, "a second press in the same beat lets nothing out")
        // The release clears on the main actor's next turn; a busy runner
        // takes more than two yields to give it one.
        for _ in 0..<100 where parking.releasing { try? await Task.sleep(for: .milliseconds(10)) }
        #expect(!parking.releasing)
    }

    @Test("he lands in the crest at the size the crest draws him")
    func sizes() {
        let side: CGFloat = 60
        // Within a hair: the sides are sums of fractions of a point.
        #expect(abs(GoalCrest.faceSide(crest: side) - 40) < 0.001)
        #expect(abs(CompanionParking.crestHeadSide(crest: side) - 40 * ProfileAvatar.headShare) < 0.001)
        #expect(CompanionParking.crestHeadSide(crest: side) < TowerCompanion.side, "he shrinks going in")
    }

    @Test("with no head, or with him out, the face opens Your day as it did")
    func pressWithoutAHead() throws {
        let ring = SourceSweep.code(try SourceSweep.read("Strata/Views/GoalRing.swift"))
        let press = try #require(ring.components(separatedBy: "private func pressFace() {").dropFirst().first?
            .components(separatedBy: "private func letOut()").first)
        #expect(press.contains("guard canLetOut else {"))
        #expect(press.contains("openDay()"))
        #expect(ring.contains("HeadStore.shared.headForCrews != nil && !Self.headIsOut"))
        // Out on the tower, the ring holds your picture, never a second head.
        #expect(ring.contains("ProfileAvatar(side: side, showsHead: !headIsOut)"))
    }
}
