import Testing
import Foundation
import UIKit
@testable import Strata

/// **Your strip into a crew** (`CrewStripShare`, `tasks/unification-log.md`
/// §4b): a marked chat picture that a friend's phone shows as a strip, not as
/// a doodle tinted to ink, and never as words.
@MainActor
@Suite("Strip to crew", .serialized)
struct StripToCrewTests {
    let world = FakeCrewWorld()
    let jayden = UUID()
    let sam = UUID()

    func store(_ me: UUID) -> SocialStore {
        let suite = "strip-\(UUID().uuidString)"
        let store = SocialStore(cloud: FakeCrewCloud(world: world, me: me), defaults: UserDefaults(suiteName: suite)!,
                                directory: FileManager.default.temporaryDirectory.appending(path: suite))
        store.isEnabled = { true }
        store.canReply = { true }
        let name = me == jayden ? "Jayden" : "Sam"
        store.myFirstName = { name }
        store.derive = { $0 }
        return store
    }

    func png() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 12, height: 36)).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 12, height: 36))
        }.pngData()!
    }

    @Test func aStripArrivesAsAStrip() async throws {
        let a = store(jayden), b = store(sam)
        let (crew, link) = try await a.createCrew(name: "Roommates")
        _ = try await b.accept(CrewInvite(url: link))
        await a.refresh()
        #expect(await a.sendStrip(png(), in: crew.id) == .sent)
        await b.refresh()
        let line = try #require(b.messages(in: crew.id).first)
        #expect(line.isStrip)
        #expect(!line.isToss)
        #expect(line.sketch != nil)
        #expect(b.tosses(in: crew.id).isEmpty, "a strip is a chat line, not a drawing on the tower")
    }

    @Test func theMarkerIsNeitherWordsNorAToss() {
        #expect(CrewMessage.stripMarker != CrewMessage.tossMarker)
        #expect(CrewMessage.stripMarker.trimmingCharacters(in: .whitespacesAndNewlines) == CrewMessage.stripMarker,
                "the decoder's trim must not eat the marker")
    }
}
