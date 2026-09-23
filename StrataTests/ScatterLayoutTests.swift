import Testing
import CoreGraphics
@testable import Strata

/// **The whole point of packing first is that these can be ASSERTED rather
/// than looked at.** A hand-arranged scatter has to be judged at every count
/// by eye; this one either holds at all of them or fails here.
struct ScatterLayoutTests {

    private static let width: CGFloat = 360

    /// **Mostly small, because most wins are.** The fixture used to cycle
    /// small, medium, hard evenly, which meant no two 1x1s were ever
    /// adjacent and therefore no row ever held two cards — so every test
    /// about what happens BETWEEN cards on a line was silently checking
    /// nothing.
    private func items(_ n: Int,
                       sizes: [BlockSize] = [.small, .small, .medium,
                                             .small, .hard, .small]) -> [ScatterLayout.Item] {
        (0..<n).map { ScatterLayout.Item(id: "win-\($0)", size: sizes[$0 % sizes.count]) }
    }

    /// **No win is ever buried, at every count from one to twenty.**
    ///
    /// This rule has moved twice and each move was the owner looking at it.
    /// It was "nothing touches", then "no win more than a fifth covered" so
    /// cards could tuck, then back to "nothing touches" when he said they
    /// should not be touching, and now here: space is the rule and a little
    /// contact is the exception he allowed. The bound is what makes any of
    /// those safe to change — whatever the arrangement, a win stays
    /// recognisable and stays tappable.
    @Test("No win is ever buried, at any count from one to twenty")
    func nothingIsEverBuried() {
        for count in 1...20 {
            let placed = ScatterLayout.place(items(count), in: Self.width)
            #expect(placed.count == count, "\(count) in, \(placed.count) out")
            for i in placed.indices {
                let mine = placed[i].frame
                let area = mine.width * mine.height
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

    /// **Most pairs have air between them.** Contact is the exception, so if
    /// it ever becomes the rule again this fails.
    @Test("Space is the rule and touching is the exception")
    func mostCardsHaveAirAroundThem() {
        let placed = ScatterLayout.place(items(20), in: Self.width)
        var pairs = 0, touching = 0
        for i in placed.indices {
            for j in placed.indices where j > i {
                guard abs(placed[i].frame.midY - placed[j].frame.midY)
                        < placed[i].frame.height * 0.5 else { continue }
                pairs += 1
                if placed[i].frame.intersects(placed[j].frame) { touching += 1 }
            }
        }
        #expect(pairs > 0)
        #expect(Double(touching) / Double(pairs) < 0.55,
                "\(touching) of \(pairs) pairs on a line are touching, which is a pile")
    }

    /// **A win reaches the margins.** They were sized off a made-up fraction
    /// of the width and came out tiny with a dead strip down both sides.
    /// `BlockSize` spans a TWO column grid, so a small is half the folder and
    /// a medium is all of it.
    @Test("Wins fill the folder rather than floating in the middle of it")
    func winsReachTheMargins() {
        let w = Self.width
        let small = ScatterLayout.size(for: .small, in: w)
        let medium = ScatterLayout.size(for: .medium, in: w)
        let hard = ScatterLayout.size(for: .hard, in: w)
        #expect(abs(medium.width - w) < 0.01, "a 2x1 must span the whole folder")
        #expect(abs(hard.width - w) < 0.01, "a 2x2 must span the whole folder")
        #expect(abs(small.width * 2 + ScatterLayout.gutter - w) < 0.01,
                "two 1x1s and a gutter must span the whole folder")
        #expect(abs(small.width - small.height) < 0.01, "a 1x1 is square")
        #expect(abs(medium.height - small.height) < 0.01, "a 2x1 is one row tall")
        #expect(hard.height > medium.height, "a 2x2 is taller than a 2x1")
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

            // **This asserted one width, and the assertion WAS the bug.**
            //
            // Updated 2026-09-22, not relaxed. The owner: "make sure the
            // different sizes are shown, and inside the folders it is nice
            // and organised." Forcing every card to a single column was
            // what made a 1x1 and a 2x2 identical, so the test was pinning
            // the defect it was written beside.
            //
            // What "organised" actually means here is still checked, and
            // more of it than before: a card is either ONE column or the
            // FULL width — never a third, arbitrary size — every card starts
            // on one of the two column origins, nothing leans, and nothing
            // overlaps. That is a grid. One width was never the property
            // that made it one.
            // **Exactly one width now, and that is the contract.** This
            // allowed a column OR the full width, from the day a 2x1 spanned
            // both. The owner's call is the Cosmos grid: "make sure if an
            // image is shown it is consistent on every page, no crazy
            // different sizes everywhere." One width, heights from the
            // pictures. A full-width card reappearing should fail here.
            let column = (Self.width - ScatterLayout.gutter) / 2
            let widths = Set(tidy.map { Int($0.frame.width.rounded()) })
            #expect(widths == Set([Int(column.rounded())]),
                    "cards came out \(widths) wide, and a column is \(Int(column.rounded()))")
            let columns = Set(tidy.map { Int($0.frame.minX.rounded()) })
            #expect(columns.count <= 2, "there are \(columns.count) columns, not two")
            #expect(columns.isSubset(of: [0, Int((column + ScatterLayout.gutter).rounded())]),
                    "a card starts at \(columns), which is not a column origin")

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
