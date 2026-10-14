import Foundation
import Testing
@testable import Strata

/// **One identity component** (the owner, 2026-10-14: "treat the head not
/// really as an optional thing but an identity ... I want to make sure they
/// are pretty normalized throughout the app"). `docs/heads-as-identity-2026-10-14.md`.
@MainActor
@Suite("Heads as identity: PersonHead and HeadIdentity")
struct PersonHeadTests {

    @Test("a person's colour is picked by their id, so every phone agrees")
    func colourIsStable() {
        let id = UUID(uuidString: "07000000-0000-0000-0000-000000000000")!
        #expect(HeadIdentity.paletteIndex(for: id, count: 6) == 1)
        #expect(HeadIdentity.paletteIndex(for: id, count: 6) == HeadIdentity.paletteIndex(for: id, count: 6))
        // The rule `CrewFace` used, unchanged: the id's first byte.
        let other = UUID(uuidString: "0C000000-0000-0000-0000-000000000000")!
        #expect(HeadIdentity.paletteIndex(for: other, count: 6) == 0)
        #expect(HeadIdentity.paletteIndex(for: other, count: 0) == 0, "an empty palette never divides by zero")
    }

    @Test("your initial is read the way a friend's is")
    func initial() {
        #expect(HeadIdentity.initial(fromName: "jayden betts") == "J")
        #expect(HeadIdentity.initial(fromName: "  Sam ") == "S")
        #expect(HeadIdentity.initial(fromName: "") == "")
        #expect(HeadIdentity.initial(fromName: "   ") == "")
        let sam = CrewMember(profileID: UUID(), firstName: "sam lee", head: nil, joinedAt: .now)
        #expect(HeadIdentity.initial(fromName: sam.firstName) == sam.initial)
    }

    @Test("a member who is you resolves to your own head, never a copy")
    func meAsAMember() {
        let me = UUID()
        let member = CrewMember(profileID: me, firstName: "Me", head: nil, joinedAt: .now)
        let crew = CrewID(rawValue: "c")
        let asMember = HeadIdentity.rig(for: .member(member, crew: crew, me: me))
        let asMe = HeadIdentity.rig(for: .me)
        #expect((asMember == nil) == (asMe == nil))
        #expect(asMember?.faces.count == asMe?.faces.count)
    }

    @Test("one share for a head in a disc, one for a head in a ring")
    func shares() {
        #expect(PersonHead.discShare == 0.9)
        #expect(PersonHead.ringShare == 0.76)
        // The blank head stands where a head of the same side would.
        #expect(HeadPlaceholder.aspect < 1)
    }

    @Test("no screen draws a person with its own decision tree any more")
    func oneTree() throws {
        // The four that used to choose between a head, a photo, initials and
        // a glyph are thin over `PersonHead` now.
        let avatar = SourceSweep.code(try SourceSweep.read("Strata/Views/ProfileAvatar.swift"))
        #expect(!avatar.contains("store.photo"))
        #expect(!avatar.contains("person.fill"))
        #expect(avatar.contains("PersonHead(person: .me"))
        let faces = SourceSweep.code(try SourceSweep.read("Strata/Views/Crews/CrewFaces.swift"))
        #expect(!faces.contains("member.photo"))
        #expect(faces.contains("PersonHead(person: .member(member, crew: crew, me: me), side: side)"))
        let arena = SourceSweep.code(try SourceSweep.read("Strata/Views/Crews/CrewHeadArena.swift"))
        #expect(!arena.contains("CrewFace(member:"), "a crew tower's heads have no disc fallback of their own")
        // The injection, so this can fail.
        #expect("if let photo = member.photo".contains("member.photo"))
    }
}
