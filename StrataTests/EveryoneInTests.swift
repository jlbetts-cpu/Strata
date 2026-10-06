import Testing
import Foundation
@testable import Strata

/// **Everyone's in** (2026-10-06, "the ritual of winning together"): the win
/// that completes the crew's day sets the tower dancing, as the tenth does.
@Suite("Everyone's in")
struct EveryoneInTests {
    let jayden = UUID(), sam = UUID(), leo = UUID()

    func win(_ who: UUID) -> SharedWin {
        SharedWin(winID: UUID(), crewID: CrewID(rawValue: "c"), senderProfileID: who, crewDay: "2026-10-06",
                  title: "Gym", colour: .health, icon: .health, blockSize: .small, photo: nil,
                  cropX: nil, cropY: nil, createdAt: .now, updatedAt: .now)
    }

    @Test("everyone is in when every member has a win today, and a crew of one never is")
    func everyone() {
        let members = [jayden, sam, leo]
        #expect(!CrewTowerModel.everyoneIn(wins: [win(jayden), win(sam), win(sam)], members: members))
        #expect(CrewTowerModel.everyoneIn(wins: [win(jayden), win(sam), win(leo)], members: members))
        #expect(!CrewTowerModel.everyoneIn(wins: [win(jayden)], members: [jayden]))
        #expect(!CrewTowerModel.everyoneIn(wins: [], members: []))
    }

    @Test("only the turn dances: not the first look, and not staying full")
    func onlyTheTurn() {
        #expect(CrewTowerModel.becameFull(was: false, now: true))
        #expect(!CrewTowerModel.becameFull(was: nil, now: true), "opening a finished day does not dance again")
        #expect(!CrewTowerModel.becameFull(was: true, now: true))
        #expect(!CrewTowerModel.becameFull(was: true, now: false))
    }

    @Test("the crew's tower passes it in, and never names who was last")
    func wired() throws {
        let view = SourceSweep.code(try SourceSweep.read("Strata/Views/Crews/CrewTowerView.swift"))
        #expect(view.contains("everyoneIn: CrewTowerModel.everyoneIn(wins: wins"))
        let model = SourceSweep.code(try SourceSweep.read("Strata/Views/Crews/CrewTowerModel.swift"))
        #expect(model.contains("|| justFull"))
    }
}
