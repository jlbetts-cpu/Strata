import Foundation
import Testing
@testable import Strata

/// **A crew's photo can be taken off** (the owner, 2026-10-14: "there is no
/// way to remove pfps from chats", of a crew's own picture). Removing is the
/// path a new picture takes, `setPhoto(_:jpeg: nil)`, so it reaches every
/// phone in the crew, and the crew goes back to its people's faces.
extension CrewStoreTests {
    @Test func aCrewPhotoTakenOffGoesForEveryone() async throws {
        let (a, b, crew) = try await pair()
        try await a.setPhoto(crew.id, jpeg: Data([1, 2, 3]))
        await b.refresh()
        #expect(b.crew(crew.id)?.photo != nil)

        // Anyone in the crew may change its picture, so anyone may take it
        // off: here the friend who joined.
        try await b.setPhoto(crew.id, jpeg: nil)
        #expect(b.crew(crew.id)?.photo == nil)
        #expect(world.records(of: .crew, in: crew.id).values.first?["photo"] == nil, "the server still has it")
        await a.refresh()
        #expect(a.crew(crew.id)?.photo == nil, "the starter's phone still shows it")
    }

    @Test("the crew's card offers Remove Photo off Edit, asks first, and removes through setPhoto")
    func theCardOffersIt() throws {
        let info = SourceSweep.code(try SourceSweep.read("Strata/Views/Crews/CrewInfoSheet.swift"))
        #expect(info.contains("Button(\"Remove Photo\", systemImage: \"trash\", role: .destructive) { confirmsRemovePhoto = true }"))
        #expect(info.contains("try await store.setPhoto(crewID, jpeg: nil)"))
        #expect(info.contains("if crew.photo != nil {"), "Remove Photo is offered on a crew with no photo")
        // The same people who may choose one: not 13 to 15, who send none.
        #expect(info.contains("if CrewAge.current.sendsPhotos {\n                    photoEdit(crew)"))
    }
}
