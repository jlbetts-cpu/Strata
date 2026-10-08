import Testing
import Foundation
@testable import Strata

/// **Declined is 13 to 15, and a head is a photograph** (the 2026-10-08
/// launch audit). The privacy policy says "If you would rather not say, Some
/// Wins treats you as 13 to 15"; the app now does, and a head cut out of a
/// photo leaves the phone on the photo rule and through the photo check.
@MainActor
@Suite("Crew age rule", .serialized)
struct CrewAgeRuleTests {
    let world = FakeCrewWorld()
    let jayden = UUID()
    let sam = UUID()

    func store(_ me: UUID) -> SocialStore {
        let suite = "age-rule-\(UUID().uuidString)"
        let store = SocialStore(cloud: FakeCrewCloud(world: world, me: me),
                                defaults: UserDefaults(suiteName: suite)!,
                                directory: FileManager.default.temporaryDirectory.appending(path: suite))
        store.isEnabled = { true }
        store.derive = { $0 }
        return store
    }

    @Test func declinedIsTreatedExactlyAsThirteenToFifteen() {
        let declined = CrewAge.declined, teen = CrewAge.teen
        #expect(declined.rule == .teen)
        #expect(declined.opensCrews == teen.opensCrews)
        #expect(declined.sendsPhotos == teen.sendsPhotos)
        #expect(declined.seesPhotosUnchecked == teen.seesPhotosUnchecked)
        #expect(declined.writesInCrews == teen.writesInCrews)
        #expect(!declined.seesPhotosUnchecked, "a friend's photo is checked, or hidden, as for 13 to 15")
        #expect(declined.writesInCrews, "13 to 15 may write in the chat, so declined may")
        #expect(!CrewAge.unknown.writesInCrews && CrewAge.adult.writesInCrews)
        #expect(!CrewAge.under13.writesInCrews)
    }

    @Test func aHeadIsNotSentUnderTheAgeForPhotos() async throws {
        let a = store(jayden)
        a.photosAllowed = { false }
        a.myHeadPack = { Data([7, 7, 7]) }
        let (crew, _) = try await a.createCrew(name: "One")
        #expect(world.records(of: .member, in: crew.id)[jayden.uuidString]?["head"] == nil)
        // Sixteen now: the head goes.
        a.photosAllowed = { true }
        await a.shareMyself()
        #expect(world.records(of: .member, in: crew.id)[jayden.uuidString]?["head"] != nil)
        // And back under the rule: the head sent before is taken back.
        a.photosAllowed = { false }
        await a.shareMyself()
        #expect(world.records(of: .member, in: crew.id)[jayden.uuidString]?["head"] == nil)
    }

    @Test func aHeadTheCheckHoldsBackIsNotSent() async throws {
        let a = store(jayden)
        a.myHeadPack = { Data([7, 7, 7]) }
        a.headCheck = { _ in false }
        let (crew, _) = try await a.createCrew(name: "One")
        #expect(world.records(of: .member, in: crew.id)[jayden.uuidString]?["head"] == nil)
        // Held back is remembered: the next launch does not send it, or ask
        // the check again.
        var asked = 0
        a.headCheck = { _ in asked += 1; return false }
        a.checkedSelf = false
        await a.shareMyselfIfChanged()
        #expect(asked == 0)
        #expect(world.records(of: .member, in: crew.id)[jayden.uuidString]?["head"] == nil)
    }

    @Test func everyFaceInAPackIsChecked() async throws {
        func pack(_ files: [String: Data]) throws -> Data {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            return try encoder.encode(CrewHeadPack(files: files))
        }
        let fine = Data([1]), flagged = Data([2])
        let good = try pack(["head.json": Data("{}".utf8), "neutral.png": fine, "smile.png": fine])
        let bad = try pack(["head.json": Data("{}".utf8), "neutral.png": fine, "smile.png": flagged])
        let check: @Sendable (Data) async -> Bool = { $0 != flagged }
        #expect(await CrewHeadPack.passes(good, check: check))
        #expect(!(await CrewHeadPack.passes(bad, check: check)))
        #expect(CrewHeadPack.images(in: good)?.count == 2)
        // Not a pack, or a pack with no face: nothing to vouch for.
        #expect(!(await CrewHeadPack.passes(Data([7, 7, 7]), check: check)))
        #expect(!(await CrewHeadPack.passes(try pack(["head.json": Data()]), check: check)))
    }
}
