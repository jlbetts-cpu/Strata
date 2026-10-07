import Testing
import UIKit
@testable import Strata

/// **The day's photo strip and its booth** (the owner, 2026-10-06: "the strip
/// needs to feel like our app, it's like its main representation").
@Suite("Photo strip")
@MainActor
struct PhotoStripTests {
    private func frame(_ size: BlockSize) -> PhotoStrip.Frame {
        PhotoStrip.Frame(id: UUID(), title: "", size: size, picture: UIImage())
    }

    @Test("packed as the tower is: Quicks pair, Regulars go wide, Deeps go tall")
    func layout() {
        #expect(StripLayout.rows([.small, .small]) == [.pair(0, 1)])
        #expect(StripLayout.rows([.medium]) == [.full(0, aspect: 2)])
        #expect(StripLayout.rows([.hard]) == [.full(0, aspect: 4.0 / 3.0)])
    }

    @Test("a Quick waits for the next Quick, and one with no partner goes wide")
    func quickWaits() {
        #expect(StripLayout.rows([.small, .medium, .small]) == [.pair(0, 2), .full(1, aspect: 2)])
        #expect(StripLayout.rows([.small, .medium]) == [.full(0, aspect: 2), .full(1, aspect: 2)])
        #expect(StripLayout.rows([]).isEmpty)
    }

    @Test("every frame is placed exactly once")
    func everyFramePlacedOnce() {
        let sizes: [BlockSize] = [.small, .hard, .small, .small, .medium, .small, .small]
        let placed = StripLayout.rows(sizes).flatMap { row -> [Int] in
            switch row {
            case .pair(let a, let b): [a, b]
            case .full(let i, _): [i]
            }
        }
        #expect(placed.sorted() == Array(sizes.indices))
    }

    @Test("taking a win off never makes the paper taller, so doodles stay put")
    func takingOffNeverGrows() {
        // A pair and a wide frame are each half the width tall, a Deep is
        // three quarters: removing one frame can only shorten the strip.
        func height(_ sizes: [BlockSize]) -> Double {
            StripLayout.rows(sizes).reduce(0) { sum, row in
                switch row {
                case .pair: sum + 0.5
                case .full(_, let aspect): sum + 1 / aspect
                }
            }
        }
        let day: [BlockSize] = [.small, .hard, .small, .small, .medium, .small]
        for i in day.indices {
            var less = day
            less.remove(at: i)
            #expect(height(less) <= height(day))
        }
    }

    @Test("up to eight on a strip, in the day's order, chosen by you")
    func choosing() {
        let all = (0..<10).map { _ in frame(.small) }
        let strip = PhotoStrip(owner: .me, day: "2026-10-06", candidates: all, signature: "Jayden")
        #expect(strip.frames(excluding: []).count == PhotoStrip.most)
        #expect(PhotoStrip.most == 8)
        let chosen = strip.frames(excluding: [all[0].id])
        #expect(chosen.first?.id == all[1].id)
        #expect(chosen.last?.id == all[8].id)
    }

    @Test("what is left off and whether it is developed are kept per owner and day")
    func keeping() {
        let day = "1999-01-0\(Int.random(in: 1...9))"
        let id = UUID()
        StripKeeping.setExcluded([id], .me, day: day)
        #expect(StripKeeping.excluded(.me, day: day) == [id])
        #expect(StripKeeping.excluded(.crew("x"), day: day).isEmpty)
        #expect(!StripKeeping.isDeveloped(.crew("x"), day: day))
        StripKeeping.setDeveloped(.crew("x"), day: day)
        #expect(StripKeeping.isDeveloped(.crew("x"), day: day))
        #expect(!StripKeeping.isDeveloped(.me, day: day))
        StripKeeping.setExcluded([], .me, day: day)
        UserDefaults.standard.removeObject(forKey: "strip.developed.crew-x.\(day)")
    }

    @Test("white or black paper, and nothing else")
    func paper() {
        #expect(StripPaper.allCases == [.black, .white])
    }

    @Test("the booth asks whether it may develop at the shake, not at the opening")
    func developAskedAtTheShake() throws {
        // The cover was built with `blocksToday >= dailyGoal` read once, so a
        // booth opened before the day's wins had loaded never developed.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let booth = try String(contentsOf: root.appending(path: "Strata/Views/Strip/StripBooth.swift"), encoding: .utf8)
        let main = try String(contentsOf: root.appending(path: "Strata/Views/MainAppView.swift"), encoding: .utf8)
        #expect(booth.contains("var canDevelop: () -> Bool"))
        // Today's goal, the one you set.
        #expect(main.contains("canDevelop: { blocksToday >= todaysGoal }"))
    }
}
