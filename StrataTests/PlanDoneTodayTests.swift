import Foundation
import Testing
@testable import Strata

/// The one planner's crew side (the add-on, 2026-10-17): a shared plan line
/// says who in the crew did it today.
@MainActor
@Suite("Plan done today", .serialized)
struct PlanDoneTodayTests {
    @Test func aCrewMateWhoDidItIsNamed() async throws {
        let world = FakeCrewWorld()
        let store = SocialStore(cloud: FakeCrewCloud(world: world), defaults: UserDefaults(suiteName: "plan-\(UUID())")!,
                                directory: FileManager.default.temporaryDirectory.appending(path: "plan-\(UUID())"))
        store.isEnabled = { true }
        let (crew, _) = try await store.createCrew(name: "Roommates")
        let sam = UUID()
        func win(_ title: String, by who: UUID, day: String) -> SharedWin {
            SharedWin(winID: UUID(), crewID: crew.id, senderProfileID: who, crewDay: day, title: title,
                      colour: .health, icon: .health, blockSize: .small, photo: nil, cropX: nil, cropY: nil,
                      createdAt: .now, updatedAt: .now)
        }
        let today = CrewDay.string(for: .now, in: crew.timeZone)
        store.receive(win("Walk", by: sam, day: today))
        store.receive(win("Walk", by: sam, day: "2020-01-01"))
        store.receive(win("Gym", by: UUID(), day: today))
        #expect(store.didToday(" walk", in: crew.id) == [sam])
        #expect(store.didToday("Read", in: crew.id).isEmpty)
        store.block(sam, name: "Sam")
        #expect(store.didToday("Walk", in: crew.id).isEmpty, "someone blocked is never named")
    }
}
