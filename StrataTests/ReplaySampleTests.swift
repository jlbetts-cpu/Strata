import Foundation
import Testing
import UIKit
@testable import Strata

@Suite("Replay sample")
struct ReplaySampleTests {
    private let now = Date(timeIntervalSince1970: 1_789_300_000)

    @Test("the same every time")
    func deterministic() {
        let a = ReplaySample.replay(.week, now: now)
        let b = ReplaySample.replay(.week, now: now)
        #expect(a.blocks.map { [$0.column, $0.row, $0.day] } == b.blocks.map { [$0.column, $0.row, $0.day] })
        #expect(a.blocks.map(\.win.title) == b.blocks.map(\.win.title))
    }

    @Test("shows every part of the choreography", arguments: [ReplayKind.week, .month])
    func coverage(kind: ReplayKind) {
        let r = ReplaySample.replay(kind, now: now)
        #expect(r.countsByDay.contains(0), "an empty day")
        #expect(r.countsByDay.filter { $0 == r.countsByDay.max() }.count == 1, "one busiest day")
        #expect(r.blocks.contains { $0.win.size == .hard }, "a 2x2")
        #expect(r.blocks.contains { $0.win.photo != nil }, "photographs")
        #expect(r.blocks.contains { $0.win.photo == nil }, "plain colour")
        #expect(r.count >= (kind == .week ? 18 : 90))
    }

    @Test("only real bundled photographs, and every one is in the bundle")
    func photos() {
        var photos = Set<ReplayPhoto>()
        for kind in [ReplayKind.week, .month] {
            photos.formUnion(ReplaySample.replay(kind, now: now).blocks.compactMap(\.win.photo))
        }
        #expect(!photos.isEmpty)
        for photo in photos {
            guard case .bundled(let name) = photo else {
                Issue.record("\(photo.key) is not a bundled photograph")
                continue
            }
            #expect(name.hasPrefix("DemoPhoto"))
            #expect(UIImage(named: name) != nil, "\(name) is not in the app bundle")
        }
    }

    @Test("sample ids are stable, formatted from Int with the long length modifier")
    func ids() {
        let a = ReplaySample.replay(.month, now: now).blocks.map(\.id)
        #expect(a.contains(UUID(uuidString: "00000000-0000-0000-0011-000000000007")!))
        #expect(Set(a).count == a.count)
    }
}
