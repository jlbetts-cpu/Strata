import Testing
import CoreGraphics
@testable import Strata

/// **The whole point of packing first is that these can be ASSERTED rather
/// than looked at.** A hand-arranged scatter has to be judged at every count
/// by eye; this one either holds at all of them or fails here.
struct ScatterLayoutTests {

    private static let width: CGFloat = 360

    private func items(_ n: Int, sizes: [BlockSize] = [.small, .medium, .hard]) -> [ScatterLayout.Item] {
        (0..<n).map { ScatterLayout.Item(id: "win-\($0)", size: sizes[$0 % sizes.count]) }
    }

    /// **The guarantee, at every count from one to twenty.**
    ///
    /// It used to be "nothing touches", which held perfectly and looked
    /// wrong: cards that never overlap read as a grid with a lean on it
    /// rather than as clutter, and photographs in a real folder overlap.
    ///
    /// So the rule moved to the one that actually matters. Cards may tuck
    /// under each other; no card may end up more than a fifth covered by the
    /// ones drawn after it, because past that a win stops being recognisable
    /// and stops being comfortably tappable. Same assertable property, at
    /// every count, for the thing that is really required.
    @Test("No win is ever buried, at any count from one to twenty")
    func nothingIsEverBuried() {
        for count in 1...20 {
            let placed = ScatterLayout.place(items(count), in: Self.width)
            #expect(placed.count == count, "\(count) in, \(placed.count) out")
            for i in placed.indices {
                let mine = placed[i].frame
                let area = mine.width * mine.height
                // Later cards are drawn on top, so only those can cover it.
                var covered: CGFloat = 0
                for j in placed.indices where j > i {
                    let overlap = mine.intersection(placed[j].frame)
                    if !overlap.isNull { covered += overlap.width * overlap.height }
                }
                #expect(covered / area <= ScatterLayout.maxCovered + 0.001,
                        "at \(count) items, \(placed[i].id) is \(Int(covered / area * 100))% buried")
            }
        }
    }

    /// And the other half of it: they must actually overlap SOMEWHERE, or the
    /// tuck has quietly stopped happening and it is a grid again.
    @Test("Cards do overlap, because that is what clutter is")
    func cardsActuallyTouch() {
        let placed = ScatterLayout.place(items(12), in: Self.width)
        var touching = 0
        for i in placed.indices {
            for j in placed.indices where j > i {
                if placed[i].frame.intersects(placed[j].frame) { touching += 1 }
            }
        }
        #expect(touching > 0, "nothing overlaps, so this is a grid with a lean on it")
    }

    @Test("Everything stays inside the folder")
    func nothingEscapes() {
        for count in 1...20 {
            for p in ScatterLayout.place(items(count), in: Self.width) {
                #expect(p.frame.minX > -1, "\(p.id) hangs off the left at \(count)")
                #expect(p.frame.maxX < Self.width + 1, "\(p.id) hangs off the right at \(count)")
                #expect(p.frame.minY > 0, "\(p.id) is above the top at \(count)")
            }
        }
    }

    /// A single win should not be a postage stamp in a field of nothing, and
    /// it should be centred rather than parked in a corner.
    @Test("One photograph is centred and given room")
    func aSingleWinIsNotLonely() {
        let placed = ScatterLayout.place([ScatterLayout.Item(id: "only", size: .medium)],
                                         in: Self.width)
        let frame = try! #require(placed.first).frame
        #expect(abs(frame.midX - Self.width / 2) < ScatterLayout.gutter,
                "a lone win is not centred")
        #expect(frame.width > Self.width * 0.3, "a lone win is too small to be the point")
    }

    /// **The layout must be the same every launch.** Swift seeds String
    /// hashing per process, so the obvious implementation of this reshuffles
    /// the folder every time the app opens, which is the single worst thing
    /// this could do.
    @Test("The same wins land in the same places every time")
    func placementIsStable() {
        let once = ScatterLayout.place(items(9), in: Self.width)
        let twice = ScatterLayout.place(items(9), in: Self.width)
        #expect(once == twice)
        // And known ids give known seeds, so this survives a relaunch rather
        // than only surviving two calls in one process.
        let a = ScatterLayout.seed("win-3")
        #expect(a == ScatterLayout.seed("win-3"))
        #expect(a != ScatterLayout.seed("win-4"))
    }

    /// The size a win is drawn at the shutter is the size it is in the
    /// folder. If that stops being true, the sizes become decoration.
    /// **The shapes ARE the block system.** Small is 1x1, medium is 2x1,
    /// hard is 2x2, straight off `BlockSize`'s own spans. If this drifts, a
    /// win stops being recognisable as the thing that was drawn at the
    /// shutter, and the folder has a second size ladder to keep in step.
    @Test("A win is the shape its block size says it is")
    func shapesComeFromTheBlockSystem() {
        let w = Self.width
        let small = ScatterLayout.size(for: .small, in: w)
        let medium = ScatterLayout.size(for: .medium, in: w)
        let hard = ScatterLayout.size(for: .hard, in: w)

        #expect(abs(small.width - small.height) < 0.01, "small must be square")
        #expect(abs(medium.width - medium.height * 2) < 0.01, "medium must be 2 to 1")
        #expect(abs(hard.width - hard.height) < 0.01, "hard must be square")
        #expect(hard.width > small.width, "the big one must be bigger")
        #expect(abs(medium.width - hard.width) < 0.01, "2x1 and 2x2 are the same width")
        #expect(hard.height > medium.height, "2x2 is taller than 2x1")
    }

    /// The Organize button: the same wins, the mess turned off. Same cards,
    /// same order, no lean, no tuck.
    @Test("Organising keeps every win and takes the mess out")
    func tidyIsTheSameSetWithoutTheClutter() {
        let messy = ScatterLayout.place(items(12), in: Self.width)
        let tidy = ScatterLayout.place(items(12), in: Self.width, tidy: true)
        #expect(messy.map(\.id) == tidy.map(\.id), "organising lost or reordered a win")
        #expect(tidy.allSatisfy { $0.angle == 0 }, "a tidied win is still leaning")
        for i in tidy.indices {
            for j in tidy.indices where j > i {
                #expect(!tidy[i].frame.intersects(tidy[j].frame),
                        "organised wins must not overlap at all")
            }
        }
        #expect(messy != tidy, "organising did nothing")
    }

    /// Clutter, but not broken: past about four degrees a grid of photographs
    /// stops reading as casual.
    @Test("Nothing leans far enough to look like a bug")
    func theLeanIsBounded() {
        for p in ScatterLayout.place(items(20), in: Self.width) {
            #expect(abs(p.angle) <= ScatterLayout.lean + 0.001,
                    "\(p.id) leans \(p.angle) degrees")
        }
        // And they are not all leaning the same way, or it reads as a skew
        // rather than as a scatter.
        let angles = ScatterLayout.place(items(20), in: Self.width).map(\.angle)
        #expect(angles.contains(where: { $0 > 0.5 }) && angles.contains(where: { $0 < -0.5 }))
    }

    @Test("An empty folder lays out nothing rather than crashing")
    func emptyIsFine() {
        #expect(ScatterLayout.place([], in: Self.width).isEmpty)
        #expect(ScatterLayout.place(items(3), in: 0).isEmpty)
        #expect(ScatterLayout.height([]) > 0)
    }
}
