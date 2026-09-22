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

    /// **Nothing touches, at every count from one to twenty.**
    ///
    /// This was the rule, then I relaxed it to "no win is more than a fifth
    /// covered" so cards could overlap, on my own reading that organised
    /// clutter means contact. The owner looked at it: "why are they
    /// touching." His reference has clear air between every card, and he is
    /// right that photographs somebody KEEPS are laid out rather than
    /// dropped. The strong guarantee is back, and it is the one worth having
    /// because it is absolute at any count.
    @Test("No two wins ever touch, at any count from one to twenty")
    func nothingEverCollides() {
        for count in 1...20 {
            let placed = ScatterLayout.place(items(count), in: Self.width)
            #expect(placed.count == count, "\(count) in, \(placed.count) out")
            for i in placed.indices {
                for j in placed.indices where j > i {
                    #expect(!placed[i].frame.intersects(placed[j].frame),
                            "at \(count) items, \(placed[i].id) touches \(placed[j].id)")
                }
            }
        }
    }

    /// **A row must splay open rather than wedge shut.** Cards left of the
    /// middle lean one way and cards right of it lean the other, so a pair
    /// falls apart at the top instead of meeting there. Getting this
    /// backwards is invisible in any per-card assertion and obvious on sight.
    @Test("Neighbours lean away from each other, not into each other")
    func rowsSplayOpen() {
        let placed = ScatterLayout.place(items(12), in: Self.width)
        for i in placed.indices {
            for j in placed.indices where j > i {
                let sameRow = abs(placed[i].frame.midY - placed[j].frame.midY)
                    < placed[i].frame.height * 0.5
                guard sameRow else { continue }
                let (left, right) = placed[i].frame.midX < placed[j].frame.midX
                    ? (placed[i], placed[j]) : (placed[j], placed[i])
                #expect(left.angle <= 0.001,
                        "\(left.id) is on the left and leans right, into its neighbour")
                #expect(right.angle >= -0.001,
                        "\(right.id) is on the right and leans left, into its neighbour")
            }
        }
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
    /// **Organised is two columns**, not the scatter with the lean removed.
    /// Every card is the same width and sits in one of exactly two places
    /// across, which is what makes it read as a grid rather than as a
    /// straightened scatter.
    @Test("Organising is a two column grid that keeps every win")
    func tidyIsATwoColumnGrid() {
        for count in 1...20 {
            let tidy = ScatterLayout.place(items(count), in: Self.width, tidy: true)
            #expect(tidy.count == count)
            #expect(tidy.allSatisfy { $0.angle == 0 }, "a tidied win is still leaning")

            let widths = Set(tidy.map { Int($0.frame.width.rounded()) })
            #expect(widths.count == 1, "organised cards are not all one width")
            let columns = Set(tidy.map { Int($0.frame.minX.rounded()) })
            #expect(columns.count <= 2, "there are \(columns.count) columns, not two")

            for i in tidy.indices {
                for j in tidy.indices where j > i {
                    #expect(!tidy[i].frame.intersects(tidy[j].frame),
                            "organised wins must not overlap at all")
                }
            }
        }
    }

    /// **The same cards have to be on screen before and after**, or the
    /// change is a reload rather than an animation and nothing can glide.
    @Test("Organising moves every win rather than replacing it")
    func organisingIsAMoveNotAReload() {
        let messy = ScatterLayout.place(items(12), in: Self.width)
        let tidy = ScatterLayout.place(items(12), in: Self.width, tidy: true)
        #expect(Set(messy.map(\.id)) == Set(tidy.map(\.id)),
                "organising lost or gained a win")
        #expect(messy.map(\.id) == tidy.map(\.id), "organising reordered the wins")
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
        // Both directions must appear, or it is a skew rather than a
        // scatter. WHICH card leans which way is `rowsSplayOpen`'s job: the
        // first version of this test asked only that both signs existed
        // somewhere in twenty, and that passed while the leans came out
        // `----------++++++++++` and every card on one screen tilted the
        // same way. A property that holds over a set can be violated in
        // every pair inside it.
        let angles = ScatterLayout.place(items(20), in: Self.width).map(\.angle)
        #expect(angles.contains(where: { $0 > 0.5 }) && angles.contains(where: { $0 < -0.5 }))
        // And a lean has to be big enough to read as deliberate rather than
        // as a card somebody failed to line up.
        #expect(angles.allSatisfy { abs($0) > ScatterLayout.lean * 0.4 })
    }

    @Test("An empty folder lays out nothing rather than crashing")
    func emptyIsFine() {
        #expect(ScatterLayout.place([], in: Self.width).isEmpty)
        #expect(ScatterLayout.place(items(3), in: 0).isEmpty)
        #expect(ScatterLayout.height([]) > 0)
    }
}
