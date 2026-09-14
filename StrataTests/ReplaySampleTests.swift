import Foundation
import Testing
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

    @Test("only real bundled photographs")
    func photos() {
        let names = Set(ReplaySample.replay(.month, now: now).blocks.compactMap { $0.win.photo?.key })
        for name in names { #expect(name.hasPrefix("bundled:DemoPhoto")) }
    }
}
