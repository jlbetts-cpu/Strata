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
        #expect(text.contains("if !parking.parked && !parking.arriving {"))
        let dock = try MorningSource.read("Views/CompanionDock.swift")
        #expect(dock.contains(".overlay { arrivingHead(rig: rig) }"), "the flight is drawn over the glass, not under it")
    }
}
