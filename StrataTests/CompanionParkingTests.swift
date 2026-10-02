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

    @Test("the bubble sits directly left of the Plan button, in the header row")
    func placement() throws {
        let text = try MorningSource.read("Views/MainAppView.swift")
        let header = text.components(separatedBy: "private var towerHeader: some View {").last ?? ""
        let row = header.components(separatedBy: "headerPlan").first ?? ""
        #expect(row.contains("CompanionDock()"))
        #expect(row.contains("HStack(alignment: .center, spacing: GridConstants.gapTight)"))
        #expect(!header.prefix(1500).contains(".headerGlassGroup"), "one glass group fused the two into a peanut")
    }

    @Test("a tap on the tower head plays a face, from the same deck as the camera")
    func tapChangesFace() throws {
        let text = try MorningSource.read("Views/TowerCompanionLayer.swift")
        #expect(text.contains(".simultaneousGesture(TapGesture().onEnded { changeFace() })"))
        #expect(text.contains("LivingHeadView(rig: rig, side: side, liveliness: .calm, take: take)"))
        #expect(text.contains("guard let next = deck.next(from: available) else { return }"))
    }

    @Test("parked or flying in, the tower stops simulating him and the bubble draws him")
    func parkedPausesTheHead() throws {
        let text = try MorningSource.read("Views/TowerCompanionLayer.swift")
        #expect(text.contains("|| parking.parked || parking.arriving"))
        #expect(text.contains("parking.parked || parking.arriving || parking.releasing"))
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

    @Test("VoiceOver can reach him, change his face, park him, and pop the bubble")
    func voiceOver() throws {
        let layer = try MorningSource.read("Views/TowerCompanionLayer.swift")
        #expect(layer.contains(".accessibilityLabel(\"Your head\")"))
        #expect(layer.contains(".accessibilityAction(named: \"Park in the bubble\") { parkWithoutCarrying() }"))
        let dock = try MorningSource.read("Views/CompanionDock.swift")
        #expect(dock.contains(".accessibilityAction { pop() }"))
    }
}
