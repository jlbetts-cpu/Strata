import Testing
import SwiftUI
@testable import Strata

/// **Where a day's sticker lands.**
///
/// The owner asked for varied sizes and placements, "but keep them on the
/// folder and visible". Those two halves pull against each other, and the
/// half that can break silently is the second: a placement that is random
/// enough to be interesting is random enough to walk off the edge on a seed
/// nobody happened to look at. Eyes cannot check a thousand days. This can.
@Suite("Where a sticker lands on a folder")
struct StickerPlacementTests {

    /// A folder at the size the Recents row draws one: 150pt wide at the
    /// aspect `WinFolder` applies, with the pocket open.
    private let width: CGFloat = 150
    private var height: CGFloat { width / 1.14 }
    private let pocketShare: CGFloat = 0.645

    private func spot(_ seed: String) -> StickerSpot {
        WinFolder.stickerSpot(seed: seed, width: width, height: height,
                              pocketShare: pocketShare)
    }

    private var days: [String] {
        var out: [String] = []
        var day = DateUtils.date(from: "2026-01-01") ?? Date()
        for _ in 0..<400 {
            out.append(DateUtils.dateString(from: day))
            day = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
        }
        return out
    }

    /// **The one thing it may never do.** A sticker is a mark on an object,
    /// so any part of it hanging off the object is the illusion gone. Tested
    /// against the TURNED box, not the square, because the lean is what makes
    /// a corner reach furthest.
    /// **Proven able to fail**: setting the margin to zero and dropping the
    /// lean's reservation puts stickers at x = −0.65 and x = 152 of a 150pt
    /// folder, and this test names them. Note what that exercise also showed
    /// — dropping the lean reservation ALONE still passes, because the margin
    /// happens to absorb it at ±10°. See the note in `WinFolder.stickerSpot`.
    @Test("No sticker ever hangs off the folder, over four hundred days")
    func staysOnTheFolder() {
        let folder = CGRect(x: 0, y: 0, width: width, height: height)
        for day in days {
            let box = spot(day).bounds
            #expect(folder.contains(box),
                    "\(day) puts a sticker at \(box), outside \(folder)")
        }
    }

    /// It has to be on the FRONT. Higher than the pocket's lip and it is
    /// behind the photographs, which is not where you stick something.
    @Test("Every sticker sits below the pocket's lip")
    func staysOnTheFront() {
        let lip = height * (1 - pocketShare)
        for day in days {
            #expect(spot(day).bounds.minY >= lip,
                    "\(day) puts a sticker above the lip at \(spot(day).bounds.minY)")
        }
    }

    /// The point of the exercise. If every day came out at the same size and
    /// the same place, the variation is not happening and only a person
    /// looking would ever notice.
    @Test("Size, place and lean all actually vary")
    func itVaries() {
        let spots = days.prefix(60).map(spot)
        let sides = Set(spots.map { Int(($0.side * 10).rounded()) })
        let xs = Set(spots.map { Int($0.centre.x.rounded()) })
        let ys = Set(spots.map { Int($0.centre.y.rounded()) })
        let leans = Set(spots.map { Int($0.lean.rounded()) })
        #expect(sides.count > 8, "only \(sides.count) sizes in sixty days")
        #expect(xs.count > 20, "only \(xs.count) horizontal positions in sixty days")
        #expect(ys.count > 15, "only \(ys.count) vertical positions in sixty days")
        #expect(leans.count > 6, "only \(leans.count) angles in sixty days")
    }

    /// Varied, but never silly. A sticker a quarter of the folder is a mark;
    /// one at half is a second folder.
    @Test("The size stays inside the band it is meant to")
    func sizeIsBounded() {
        for day in days {
            let side = spot(day).side
            #expect(side >= width * 0.26)
            #expect(side <= width * 0.37)
        }
        for day in days {
            #expect(abs(spot(day).lean) <= 10.5)
        }
    }

    /// A sticker that moved when you scrolled past it would read as a bug
    /// rather than as something stuck on by hand.
    @Test("The same day is the same sticker in the same place every time")
    func placementIsStable() {
        for day in days.prefix(40) {
            let first = spot(day)
            for _ in 0..<20 { #expect(spot(day) == first) }
        }
    }

    /// The closed folder's front is taller, so the safe region moves. It must
    /// still be a region rather than collapsing to a point or inverting.
    @Test("A closed folder still places its sticker on the front")
    func closedFoldersToo() {
        let closedShare: CGFloat = 0.845
        let folder = CGRect(x: 0, y: 0, width: width, height: height)
        let lip = height * (1 - closedShare)
        for day in days.prefix(120) {
            let box = WinFolder.stickerSpot(seed: day, width: width, height: height,
                                            pocketShare: closedShare).bounds
            #expect(folder.contains(box))
            #expect(box.minY >= lip)
        }
    }
}
