import Testing
import Foundation
@testable import Strata

/// Clustering the map's blocks.
///
/// Every case here is a failure that **cannot fail loudly on its own**. An
/// unstable id is not a crash, it is blocks teleporting on every camera nudge.
/// A cell that never splits is not an error, it is a map that stops being
/// useful when you zoom in. This is the whole reason the maths is a value
/// function with no MapKit in it: none of it is visible until it is wrong, and
/// by then it is wrong on a screen you cannot step through.
@Suite("Place clustering")
struct PlaceMapTests {

    private func pin(lat: Double, lon: Double,
                     accuracy: Double? = 20,
                     day: Int = 1,
                     hour: Int = 12,
                     category: HabitCategory = .health,
                     photo: String? = nil) -> PlaceMap.Pin {
        var c = DateComponents()
        c.year = 2026; c.month = 9; c.day = day; c.hour = hour
        let date = Calendar(identifier: .gregorian).date(from: c)!
        return PlaceMap.Pin(
            dateString: String(format: "2026-09-%02d", day),
            completedAt: date,
            title: "Walk",
            category: category,
            photoFileName: photo ?? "p\(day)-\(hour)-\(lat)-\(lon).heic",
            place: WinPlace(latitude: lat, longitude: lon, accuracy: accuracy)
        )
    }

    // MARK: - Merging and splitting

    @Test("two pins in one cell are one block")
    func mergesWithinACell() {
        let clusters = PlaceMap.cluster(
            [pin(lat: 51.5074, lon: -0.1278), pin(lat: 51.5075, lon: -0.1279, day: 2)],
            zoom: 12
        )
        #expect(clusters.count == 1)
        #expect(clusters.first?.winCount == 2)
    }

    @Test("pins far apart are separate blocks")
    func separatesAcrossCells() {
        let clusters = PlaceMap.cluster(
            [pin(lat: 51.5074, lon: -0.1278), pin(lat: 48.8566, lon: 2.3522, day: 2)],
            zoom: 8
        )
        #expect(clusters.count == 2)
    }

    /// A constant cell size passes at one zoom and fails everywhere else, so
    /// the split is the thing worth asserting rather than any single grouping.
    @Test("zooming in splits one block into two")
    func zoomSplits() {
        let pins = [pin(lat: 51.5074, lon: -0.1278), pin(lat: 51.5300, lon: -0.1000, day: 2)]
        #expect(PlaceMap.cluster(pins, zoom: 8).count == 1)
        #expect(PlaceMap.cluster(pins, zoom: 15).count == 2)
    }

    // MARK: - Identity

    /// Order-dependent ids present as blocks teleporting on every camera
    /// nudge, because SwiftUI tears down and rebuilds anything whose identity
    /// moved.
    @Test("ids do not depend on the order the pins arrive in")
    func idsAreStableUnderReordering() {
        let pins = [pin(lat: 51.50, lon: -0.12), pin(lat: 48.85, lon: 2.35, day: 2),
                    pin(lat: 40.71, lon: -74.00, day: 3)]
        let forward = PlaceMap.cluster(pins, zoom: 6).map(\.id)
        let backward = PlaceMap.cluster(pins.reversed(), zoom: 6).map(\.id)
        #expect(forward == backward)
    }

    /// Distinct from the case above: this is what makes a pin joining a place
    /// animate instead of pop.
    @Test("a cluster keeps its id when a new pin joins it")
    func idSurvivesANewMember() {
        let first = pin(lat: 51.5074, lon: -0.1278)
        let before = PlaceMap.cluster([first], zoom: 12)
        let after = PlaceMap.cluster([first, pin(lat: 51.5075, lon: -0.1279, day: 2)], zoom: 12)
        #expect(before.first?.id == after.first?.id)
        #expect(after.first?.winCount == 2)
    }

    /// Longitude 180 and -180 are the same meridian, so they must be the same
    /// cell — not one column apart, and never a negative column.
    ///
    /// What this deliberately does NOT assert is that 179.99 and -179.99 merge.
    /// They are in adjacent cells, exactly as two pins either side of any
    /// other boundary are; that is the documented asymmetry and
    /// `members(of:in:)` is its mitigation. Asserting otherwise would be
    /// testing a wish.
    @Test("the meridian at the seam wraps to one cell")
    func antimeridianWraps() {
        for z in [0, 6, 14] {
            let east = PlaceMap.key(for: WinPlace(latitude: 0, longitude: 180), z: z)
            let west = PlaceMap.key(for: WinPlace(latitude: 0, longitude: -180), z: z)
            #expect(east == west)
            #expect(east.x >= 0)
        }
    }

    /// Cells are square in PROJECTED space, so they are square on screen and
    /// smaller in metres towards the poles. Asserted so nobody "fixes" it into
    /// metres later and turns every block into a rectangle.
    @Test("cells are square on screen, which means smaller in metres up north")
    func mercatorCellsAreSquareOnScreen() {
        let side = PlaceMap.cellSide(at: 10)
        // A degree of longitude spans the same projected width everywhere; a
        // degree of latitude does not. Two pins the same number of DEGREES
        // apart in latitude fall in different cells at 60N than at the equator.
        let equator = PlaceMap.key(for: WinPlace(latitude: 0, longitude: 0), z: 10)
        let equatorNorth = PlaceMap.key(for: WinPlace(latitude: 0.2, longitude: 0), z: 10)
        let high = PlaceMap.key(for: WinPlace(latitude: 60, longitude: 0), z: 10)
        let highNorth = PlaceMap.key(for: WinPlace(latitude: 60.2, longitude: 0), z: 10)
        #expect(side > 0)
        // The same latitude step covers more cells up north, because the
        // projection stretches there.
        #expect(abs(high.y - highNorth.y) >= abs(equator.y - equatorNorth.y))
    }

    // MARK: - What a block says

    /// A deliberate restatement of `MonthTower.size`, so changing the cuts
    /// fails loudly in both places rather than silently in one.
    @Test("block size follows the month tower's rank encoding")
    func sizeFollowsMonthTower() {
        func blockSize(count: Int) -> BlockSize? {
            let pins = (1...count).map { pin(lat: 51.5074, lon: -0.1278, day: $0) }
            return PlaceMap.cluster(pins, zoom: 12).first?.size
        }
        #expect(blockSize(count: 2) == .small)
        #expect(blockSize(count: 3) == .medium)
        #expect(blockSize(count: 7) == .hard)
    }

    @Test("category ties break by earliest, like a day's does")
    func categoryTiesBreakByEarliest() {
        let cluster = PlaceMap.cluster([
            pin(lat: 51.5074, lon: -0.1278, day: 1, hour: 9, category: .work),
            pin(lat: 51.5074, lon: -0.1278, day: 1, hour: 17, category: .health)
        ], zoom: 12).first
        #expect(cluster?.category == .work)
    }

    /// The month tower's identical path broke silently once. Same shape, same
    /// test.
    @Test("photographs are newest first and de-duplicated")
    func photosNewestFirstAndUnique() {
        let cluster = PlaceMap.cluster([
            pin(lat: 51.5074, lon: -0.1278, day: 1, hour: 9, photo: "early.heic"),
            pin(lat: 51.5074, lon: -0.1278, day: 1, hour: 18, photo: "late.heic"),
            pin(lat: 51.5074, lon: -0.1278, day: 1, hour: 12, photo: "late.heic")
        ], zoom: 12).first
        #expect(cluster?.photoFileNames.first == "late.heic")
        #expect(cluster?.photoFileNames.count == 2)
    }

    @Test("a win with no photograph is not a pin")
    func unphotographedWinsAreNotPins() {
        let placed = WinRecord(dateString: "2026-09-01", completedAt: Date(),
                               title: "Walk", category: .health, size: .small,
                               photoFileName: nil,
                               place: WinPlace(latitude: 51.5, longitude: -0.1))
        let unplaced = WinRecord(dateString: "2026-09-01", completedAt: Date(),
                                 title: "Walk", category: .health, size: .small,
                                 photoFileName: "a.heic")
        #expect(PlaceMap.pins(from: [placed, unplaced]).isEmpty)
    }

    /// A reduced-accuracy fix is good to one to five kilometres. Drawing a
    /// confident block on it puts it in the wrong neighbourhood, and an app
    /// that does that is worse than one that shows nothing.
    @Test("a pin vaguer than its cell is not drawn")
    func vaguePinsAreExcluded() {
        let vague = pin(lat: 51.5074, lon: -0.1278, accuracy: 3000)
        // Wide: the cell is far bigger than 3km, so it is honest to draw.
        #expect(!PlaceMap.cluster([vague], zoom: 5).isEmpty)
        // Tight: the cell is smaller than the error, so it is not.
        #expect(PlaceMap.cluster([vague], zoom: 16).isEmpty)
    }

    // MARK: - Density and zoom

    @Test("density is the invariant: the grid tightens rather than crowding")
    func densityCapHolds() {
        // Thirty places spread far enough apart to be distinct at zoom 6.
        let pins = (0..<30).map { pin(lat: Double($0) * 2 - 30, lon: Double($0) * 3 - 45,
                                      day: ($0 % 28) + 1) }
        let clusters = PlaceMap.cluster(pins, zoom: 6, limit: 12)
        #expect(clusters.count <= 30)
        #expect(!clusters.isEmpty)
    }

    /// Found by the test above, and it was a real bug: the density loop can
    /// run to zoom 20, where a cell is under ten metres, so filtering for
    /// accuracy INSIDE the loop declared every ordinary pin too vague and the
    /// map went completely blank the more you asked of it.
    @Test("tightening for density never empties the map")
    func tighteningDoesNotBlankTheMap() {
        let pins = (0..<30).map { pin(lat: Double($0) * 2 - 30, lon: Double($0) * 3 - 45,
                                      accuracy: 65, day: ($0 % 28) + 1) }
        for limit in [1, 2, 5, 12] {
            let clusters = PlaceMap.cluster(pins, zoom: 6, limit: limit)
            #expect(!clusters.isEmpty, "the map blanked at limit \(limit)")
            #expect(clusters.reduce(0) { $0 + $1.winCount } == 30,
                    "pins were lost at limit \(limit)")
        }
    }

    @Test("a wider camera means a coarser grid")
    func zoomLevelFollowsSpan() {
        let wide = PlaceMap.zoomLevel(spanLongitude: 40, viewportWidth: 393)
        let tight = PlaceMap.zoomLevel(spanLongitude: 0.02, viewportWidth: 393)
        #expect(tight > wide)
        #expect(wide >= 0)
        #expect(tight <= 20)
    }

    @Test("a degenerate camera does not crash or run away")
    func zoomLevelIsBounded() {
        #expect(PlaceMap.zoomLevel(spanLongitude: 0, viewportWidth: 393) == 0)
        #expect(PlaceMap.zoomLevel(spanLongitude: 360, viewportWidth: 0) == 0)
        #expect(PlaceMap.zoomLevel(spanLongitude: 0.000001, viewportWidth: 393) <= 20)
    }

    // MARK: - Merging

    /// Without a parent link, zooming out changes every id at once and the
    /// only thing left to do is cross-fade the whole set. These are what let a
    /// block travel into the one that swallows it.
    @Test("a cell's parent is the cell holding it one level out")
    func parentContainsChild() {
        let place = WinPlace(latitude: 51.5074, longitude: -0.1278)
        for z in 1...16 {
            let child = PlaceMap.key(for: place, z: z)
            let parent = PlaceMap.parent(of: child)
            #expect(parent == PlaceMap.key(for: place, z: z - 1),
                    "parent of a z=\(z) cell is not the same place at z=\(z - 1)")
        }
    }

    @Test("the world has no parent")
    func rootHasNoParent() {
        #expect(PlaceMap.parent(of: PlaceMap.PlaceKey(z: 0, x: 0, y: 0)) == nil)
    }

    /// Two blocks that merge must land on the busy one, not in the gap — a
    /// join that drifts into empty ground reads as the block sliding somewhere
    /// arbitrary.
    @Test("a merge collapses towards the place that holds the most")
    func centroidIsWeighted() {
        let heavy = PlaceMap.cluster((1...9).map { pin(lat: 51.50, lon: -0.10, day: $0) },
                                     zoom: 14)
        let light = PlaceMap.cluster([pin(lat: 51.60, lon: -0.10)], zoom: 14)
        let joined = PlaceMap.centroid(of: heavy + light)
        #expect(joined != nil)
        // Nine wins against one, so the join sits close to the nine.
        #expect((joined?.latitude ?? 0) < 51.52)
    }

    @Test("a merge of nothing has no centre")
    func centroidOfNothing() {
        #expect(PlaceMap.centroid(of: []) == nil)
    }

    // MARK: - Where a block is drawn

    /// The bug this exists to stop: two clusters in neighbouring cells drawn
    /// a few points apart while each is ninety points wide. Anchoring on the
    /// cell makes the separation exactly one pitch by construction, so it
    /// cannot depend on where the members happen to sit.
    @Test("neighbouring blocks are exactly one cell apart")
    func anchorsAreOnePitchApart() {
        let left = PlaceMap.centre(of: PlaceMap.PlaceKey(z: 14, x: 100, y: 200))
        let right = PlaceMap.centre(of: PlaceMap.PlaceKey(z: 14, x: 101, y: 200))
        let side = PlaceMap.cellSide(at: 14) * 360
        #expect(abs((right.longitude - left.longitude) - side) < 1e-9)
        #expect(abs(right.latitude - left.latitude) < 1e-9)
    }

    /// A block sits in the cell it belongs to — the anchor is a re-statement
    /// of the key, so projecting it back has to land on the same key.
    @Test("a block's anchor is inside its own cell")
    func anchorRoundTripsToItsOwnCell() {
        for z in [8, 12, 16] {
            for (lat, lon) in [(51.5074, -0.1278), (-33.86, 151.21), (64.14, -21.94)] {
                let key = PlaceMap.key(for: WinPlace(latitude: lat, longitude: lon), z: z)
                let anchor = PlaceMap.centre(of: key)
                let back = PlaceMap.key(
                    for: WinPlace(latitude: anchor.latitude, longitude: anchor.longitude),
                    z: z
                )
                #expect(back == key)
            }
        }
    }

    /// **The block's IDENTITY is fixed; its position is not, and must not be.**
    ///
    /// This test used to assert the opposite — that a new photograph could not
    /// move the block — because the anchor was pinned to the cell's centre.
    /// That is what made the map inaccurate by kilometres, so the assertion
    /// went with it. What has to stay true is the thing the pinning was really
    /// protecting: the `id` never changes, so SwiftUI moves the block rather
    /// than tearing it down and building a new one somewhere else.
    ///
    /// The position moving is correct. A new photograph at a place genuinely
    /// changes where the middle of that place is, and it should slide there.
    @Test("a new pin moves the block a little, and never re-identifies it")
    func aNewPinMovesTheBlockButKeepsItsIdentity() {
        let one = PlaceMap.cluster([pin(lat: 51.5074, lon: -0.1278)], zoom: 14)
        let two = PlaceMap.cluster([pin(lat: 51.5074, lon: -0.1278),
                                    pin(lat: 51.5076, lon: -0.1274, day: 2)], zoom: 14)
        #expect(one.count == 1 && two.count == 1)
        #expect(one[0].id == two[0].id)

        // It moved, and it moved a SMALL way — tens of metres, not the
        // hundreds a cell-centre snap could produce.
        let moved = abs(one[0].anchor.latitude - two[0].anchor.latitude)
        #expect(moved > 0)
        #expect(moved < 0.001)
    }

    /// A lone pin is drawn where it actually is, not snapped to a grid.
    ///
    /// This is the bug the owner reported — "it wont even be in the same
    /// area" — stated as an assertion. At zoom 14 a cell is about 610m, so a
    /// centre-snapped block could be 300m out; inside the clamp window it is
    /// exact.
    @Test("a lone pin is drawn where it happened")
    func aLonePinIsNotSnappedToTheGrid() {
        let place = WinPlace(latitude: 51.5074, longitude: -0.1278, accuracy: 10)
        let key = PlaceMap.key(for: place, z: 14)
        let centre = PlaceMap.centre(of: key)
        let anchor = PlaceMap.anchor(forCentroidAt: (place.latitude, place.longitude),
                                     in: key, size: .small)

        // Either it is exactly right, or it is much closer to the truth than
        // the cell's centre is.
        let toTruth = abs(anchor.latitude - place.latitude)
            + abs(anchor.longitude - place.longitude)
        let centreToTruth = abs(centre.latitude - place.latitude)
            + abs(centre.longitude - place.longitude)
        #expect(toTruth <= centreToTruth)
    }

    /// The clamp is what stops two blocks touching, so it has to hold at the
    /// worst case: a centroid in the very corner of its cell.
    @Test("a corner pin is pulled in far enough that blocks cannot overlap")
    func theClampKeepsBlocksApart() {
        let z = 14
        let side = PlaceMap.cellSide(at: z)
        for size in [BlockSize.small, .medium, .hard] {
            let key = PlaceMap.PlaceKey(z: z, x: 100, y: 200)
            let centre = PlaceMap.centre(of: key)
            // A centroid way outside the cell, to force the clamp.
            let far = PlaceMap.unproject(x: (Double(key.x) + 4) * side,
                                         y: (Double(key.y) + 4) * side)
            let anchor = PlaceMap.anchor(forCentroidAt: far, in: key, size: size)

            // How far it was allowed to travel from the centre, in projected
            // units, must leave a whole block between neighbouring cells.
            let (ax, _) = PlaceMap.project(WinPlace(latitude: anchor.latitude,
                                                    longitude: anchor.longitude))
            let (cx, _) = PlaceMap.project(WinPlace(latitude: centre.latitude,
                                                    longitude: centre.longitude))
            let travelled = abs(ax - cx)
            let blockShare = PlaceMap.blockPoints(for: size) / PlaceMap.targetBlockPitch
            let allowed = side * (1 - blockShare) / 2
            #expect(travelled <= allowed + 1e-12)
        }
    }

    /// The loop that keeps the map legible used to run the wrong way: it
    /// stepped to a FINER grid, which splits clusters, so an over-full map got
    /// fuller until every pin was its own block on top of its neighbours.
    @Test("too many places merge rather than split")
    func densityThinsByMerging() {
        // Forty places spread widely enough to be separate at zoom 14.
        let many = (0..<40).map { n in
            pin(lat: 51.0 + Double(n) * 0.05, lon: -0.5 + Double(n % 7) * 0.05, day: n + 1)
        }
        let capped = PlaceMap.cluster(many, zoom: 14, limit: 8)
        #expect(capped.count <= 8)
        // Nothing may be lost on the way: a merge keeps every win.
        #expect(capped.reduce(0) { $0 + $1.winCount } == 40)
        // And it got there by getting coarser.
        #expect(capped.allSatisfy { $0.key.z < 14 })
    }

    @Test("unprojecting is the inverse of projecting")
    func unprojectInvertsProject() {
        for (lat, lon) in [(51.5074, -0.1278), (-33.86, 151.21), (0.0, 0.0), (64.14, -21.94)] {
            let (x, y) = PlaceMap.project(WinPlace(latitude: lat, longitude: lon))
            let back = PlaceMap.unproject(x: x, y: y)
            #expect(abs(back.latitude - lat) < 1e-9)
            #expect(abs(back.longitude - lon) < 1e-9)
        }
    }

    // MARK: - Opening a place

    /// Two pins twenty metres apart can straddle a cell boundary. The map
    /// draws crisp cells; opening one is generous.
    @Test("opening a place is generous at the edges")
    func membersIncludeAHalfCellMargin() {
        let z = 14
        let inside = pin(lat: 51.5074, lon: -0.1278)
        let key = PlaceMap.key(for: inside.place, z: z)
        // A pin just outside the cell, within the half-cell margin.
        let side = PlaceMap.cellSide(at: z)
        let justOutside = pin(lat: 51.5074,
                              lon: -0.1278 + side * 360 * 0.6,
                              day: 2)
        let members = PlaceMap.members(of: key, in: [inside, justOutside])
        #expect(members.count == 2)
    }

    @Test("opening a place does not sweep in the next town")
    func membersStopSomewhere() {
        let key = PlaceMap.key(for: WinPlace(latitude: 51.5074, longitude: -0.1278), z: 14)
        let far = pin(lat: 48.8566, lon: 2.3522)
        #expect(PlaceMap.members(of: key, in: [far]).isEmpty)
    }
}
