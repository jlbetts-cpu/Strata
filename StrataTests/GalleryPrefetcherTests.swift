import Foundation
import Testing

@testable import Strata

/// The camera roll's lookahead: what it asks for, what it drops, and when it
/// stops guessing.
struct GalleryPrefetcherTests {

    @Test("scrolling down asks for the three rows past the appearing cell's row")
    func downAsksThreeRowsAhead() {
        let r = GalleryPrefetcher.plan(appeared: 10, previous: 7, count: 100, lead: [], fast: false)
        #expect(r.direction == .down)
        #expect(r.plan.ask == Array(12..<21))
        #expect(r.plan.cancel.isEmpty)
    }

    @Test("scrolling up asks for the three rows above, nearest first")
    func upAsksAbove() {
        let r = GalleryPrefetcher.plan(appeared: 30, previous: 33, count: 100, lead: [], fast: false)
        #expect(r.direction == .up)
        #expect(r.plan.ask == Array((21..<30).reversed()))
    }

    @Test("the lead stops at the ends of the roll")
    func clampsToEnds() {
        #expect(GalleryPrefetcher.plan(appeared: 97, previous: 94, count: 100, lead: [], fast: false).plan.ask == [99])
        #expect(GalleryPrefetcher.plan(appeared: 1, previous: 4, count: 100, lead: [], fast: false).plan.ask.isEmpty)
    }

    @Test("a cell in the last row, or a roll of one, asks for nothing and does not trap")
    func lastRowIsSafe() {
        #expect(GalleryPrefetcher.plan(appeared: 0, previous: nil, count: 1, lead: [], fast: false).plan.ask.isEmpty)
        #expect(GalleryPrefetcher.plan(appeared: 4, previous: 1, count: 5, lead: [], fast: false).plan.ask.isEmpty)
        #expect(GalleryPrefetcher.plan(appeared: 0, previous: nil, count: 0, lead: [], fast: false).plan.ask.isEmpty)
        let p = GalleryPrefetcher()
        p.update(["only"])
        #expect(p.appeared("only", rowHeight: 134).ask.isEmpty)
    }

    @Test("only what is new is asked for, and what fell out of the lead is cancelled")
    func incremental() {
        let first = GalleryPrefetcher.plan(appeared: 10, previous: 7, count: 100, lead: [], fast: false)
        let next = GalleryPrefetcher.plan(appeared: 13, previous: 10, count: 100, lead: first.lead, fast: false)
        #expect(next.plan.ask == [21, 22, 23])
        #expect(next.plan.cancel == [12, 13, 14])
    }

    @Test("a change of direction cancels the old lead")
    func reversalCancels() {
        let down = GalleryPrefetcher.plan(appeared: 30, previous: 27, count: 100, lead: [], fast: false)
        let up = GalleryPrefetcher.plan(appeared: 27, previous: 30, count: 100, lead: down.lead, fast: false)
        #expect(up.direction == .up)
        #expect(Set(up.plan.cancel) == down.lead)
    }

    @Test("a fling asks for nothing and drops everything it had asked for")
    func flingSuspends() {
        let lead: Set<Int> = [12, 13, 14]
        let r = GalleryPrefetcher.plan(appeared: 40, previous: 10, count: 100, lead: lead, fast: true)
        #expect(r.plan.ask.isEmpty)
        #expect(Set(r.plan.cancel) == lead)
        #expect(r.lead.isEmpty)
    }

    @Test("speed is rows over time, and a screen built at once is not movement")
    func speed() {
        let row = 134.0
        // Ten rows in 200ms is 6,700pt/s — a fling.
        let fling = (0..<11).map { (index: $0 * 3, at: 1.0 + Double($0) * 0.02) }
        #expect(GalleryPrefetcher.speed(fling, rowHeight: row, now: 1.2) > GalleryPrefetcher.flingSpeed)
        // One row every 200ms is 670pt/s — reading.
        let reading = [(index: 0, at: 1.0), (index: 3, at: 1.2)]
        #expect(GalleryPrefetcher.speed(reading, rowHeight: row, now: 1.2) < GalleryPrefetcher.flingSpeed)
        // Twenty rows in the same instant is the first layout.
        let layout = (0..<20).map { (index: $0 * 3, at: 1.0) }
        #expect(GalleryPrefetcher.speed(layout, rowHeight: row, now: 1.0) == 0)
    }

    @Test("names follow the flat order, and a cell in the same row asks nothing twice")
    func namesAndRows() {
        let p = GalleryPrefetcher()
        p.update((0..<30).map { "p\($0)" })
        let a = p.appeared("p3", rowHeight: 134, now: 1)
        #expect(a.ask == (6..<15).map { "p\($0)" })
        let b = p.appeared("p4", rowHeight: 134, now: 1.01)
        #expect(b.ask.isEmpty && b.cancel.isEmpty)
    }
}
