import Testing
import Foundation
@testable import Strata

/// Laying out the map's blocks.
///
/// Every case here is a failure that **cannot fail loudly on its own**. An
/// unstable id is not a crash, it is blocks teleporting on every camera nudge.
/// Two places merging is not an error, it is a map that tells you that you
/// were somewhere you were not. This is the whole reason the maths is a value
/// function with no MapKit in it.
///
/// **The rule, chosen by the owner on 2026-09-13 from three laid out for him:
/// overlap a little, then merge.** The same spot is always one block; blocks
/// may cover each other by up to `maxOverlap`; past that the smaller joins the
/// busier, standing on the busier spot. The grid this file used to test —
/// cells, anchors clamped into them, a density cap that coarsened the grid —
/// is gone, because it made merging a matter of where cell lines fell. Its
/// tests went with it; the ones that pinned a behaviour still wanted are
/// restated against the rule below.
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

    /// A pin `points` to the east of another on screen at `step`.
    private func east(of base: PlaceMap.Pin, points: Double, step: Int, day: Int) -> PlaceMap.Pin {
        let dx = points / PlaceMap.pointsPerUnit(step: step)
        return pin(lat: base.place.latitude, lon: base.place.longitude + dx * 360, day: day)
    }

    // MARK: - The rule

    @Test("photographs of one spot are one block at every scale")
    func oneSpotIsOneBlock() {
        // Five photographs within about 25 metres — a person standing still,
        // with the jitter an ordinary fix has.
        let jitter = [(0.0, 0.0), (0.0002, 0.0001), (-0.0001, 0.0002),
                      (0.0001, -0.0002), (-0.0002, -0.0001)]
        let pins = jitter.map { pin(lat: 51.5074 + $0.0, lon: -0.1278 + $0.1, accuracy: 10) }
        for z in 8...19 {
            let clusters = PlaceMap.cluster(pins, zoom: z)
            #expect(clusters.count == 1, "zoom \(z) split one spot into \(clusters.count)")
            #expect(clusters.first?.winCount == 5)
        }
    }

    /// The owner: "only merge if its in the same location." At street zoom two
    /// spots 80 metres apart have blocks nowhere near touching. The grid
    /// merged exactly this pair 30% of the time.
    @Test("close up, different spots are different blocks")
    func streetZoomKeepsSpotsApart() {
        let a = pin(lat: 37.7749, lon: -122.4194, day: 1)
        let b = pin(lat: 37.7749, lon: -122.4194 + 80.0 / (111_000 * cos(37.7749 * .pi / 180)), day: 2)
        #expect(PlaceMap.cluster([a, b], zoom: 17).count == 2)
        #expect(PlaceMap.cluster([a, b], zoom: 16).count == 2)
    }

    @Test("blocks may cover each other by up to a third, and merge past that")
    func overlapThreshold() {
        // A scale at which a third of a block is hundreds of metres, so the
        // same-spot rule plays no part.
        let step = PlaceMap.step(zoom: 12)
        let base = pin(lat: 51.5074, lon: -0.1278, day: 1)
        // Two one-cell blocks 44pt wide, offset sideways: covered = (44 - d) / 44.
        // A third covered is d = 29.3pt.
        let apart = east(of: base, points: 31, step: step, day: 2)
        let over = east(of: base, points: 27, step: step, day: 2)
        #expect(PlaceMap.cluster([base, apart], step: step).count == 2, "a light overlap merged")
        #expect(PlaceMap.cluster([base, over], step: step).count == 1, "a heavy overlap stayed apart")
    }

    @Test("no two blocks ever cover each other past the limit")
    func nothingIsHiddenUnderAnotherBlock() {
        // A city's worth of photographs: three busy hubs and a scatter.
        var pins: [PlaceMap.Pin] = []
        for i in 0..<60 {
            let hub = [(51.5074, -0.1278), (51.5155, -0.1410), (51.4975, -0.1357)][i % 3]
            let spread = i % 4 == 0 ? 0.03 : 0.002
            pins.append(pin(lat: hub.0 + Double((i * 37) % 21 - 10) / 10 * spread,
                            lon: hub.1 + Double((i * 53) % 21 - 10) / 10 * spread,
                            day: (i % 28) + 1, hour: i % 24))
        }
        for step in stride(from: PlaceMap.step(zoom: 9), through: PlaceMap.step(zoom: 17), by: 1) {
            let clusters = PlaceMap.cluster(pins, step: step)
            let scale = PlaceMap.pointsPerUnit(step: step)
            #expect(clusters.reduce(0) { $0 + $1.winCount } == pins.count, "photographs lost at step \(step)")
            for i in clusters.indices {
                for j in clusters.indices where j > i {
                    let a = PlaceMap.project(WinPlace(latitude: clusters[i].latitude, longitude: clusters[i].longitude))
                    let b = PlaceMap.project(WinPlace(latitude: clusters[j].latitude, longitude: clusters[j].longitude))
                    let covered = PlaceMap.overlap(dx: (a.x - b.x) * scale, dy: (a.y - b.y) * scale,
                                                   PlaceMap.blockPoints(for: clusters[i].size),
                                                   PlaceMap.blockPoints(for: clusters[j].size))
                    #expect(covered <= PlaceMap.maxOverlap + 1e-9,
                            "step \(step): two blocks cover each other \(covered)")
                }
            }
        }
    }

    /// **A block stands where the photographs actually are**, not at the mean
    /// of two places nobody stood between. The owner: the map "is still not
    /// the most accurate at knowing where they are suppossed to be on zoom
    /// out".
    @Test("a joined block stands on the busier spot, exactly")
    func blockSitsOnTheCrowd() {
        var pins = (0..<8).map { pin(lat: 51.5000, lon: -0.1278, day: $0 + 1) }
        pins.append(pin(lat: 51.5045, lon: -0.1278, day: 20))
        let clusters = PlaceMap.cluster(pins, zoom: 10)
        #expect(clusters.count == 1, "the fixture no longer makes one block")
        #expect(abs(clusters[0].latitude - 51.5000) < 1e-9)
        #expect(abs(clusters[0].longitude + 0.1278) < 1e-9)
    }

    /// **Two cities merge only when their blocks would cover each other, and
    /// the block is never drawn between them.**
    ///
    /// This test used to say two cities never become one block at any zoom.
    /// That was the answer to a block drawn in a field between London and
    /// Manchester. The owner's rule since is overlap a little, then merge: at
    /// a continent's width the two blocks would sit almost on top of each
    /// other, so they are one — standing on London, which holds more.
    @Test("cities merge only when their blocks would cover each other, and on the busier city")
    func citiesMergeOnlyWhenTheyCoverEachOther() {
        let london = (0..<6).map { pin(lat: 51.5074 + Double($0) * 0.0002, lon: -0.1278, day: $0 + 1) }
        let manchester = (0..<4).map { pin(lat: 53.4808 + Double($0) * 0.0002, lon: -2.2426, day: $0 + 10) }
        // A country: apart.
        let country = PlaceMap.step(pointsPerUnit: PlaceMap.pointsPerUnit(spanLongitude: 6, viewportWidth: 393))
        #expect(PlaceMap.cluster(london + manchester, step: country).count == 2)
        // Wider and wider: whenever they are one block, it is on London.
        for span in [20.0, 60.0, 180.0] {
            let step = PlaceMap.step(pointsPerUnit: PlaceMap.pointsPerUnit(spanLongitude: span, viewportWidth: 393))
            for cluster in PlaceMap.cluster(london + manchester, step: step) {
                let isLondon = abs(cluster.latitude - 51.51) < 0.01
                let isManchester = abs(cluster.latitude - 53.48) < 0.01
                #expect(isLondon || isManchester, "a block sits between the cities at span \(span)")
                if cluster.winCount == 10 { #expect(isLondon, "a merged block stood on the smaller city") }
            }
        }
    }

    @Test("the newest block is drawn on top")
    func newestOnTop() {
        let step = PlaceMap.step(zoom: 12)
        let older = pin(lat: 51.5074, lon: -0.1278, day: 3)
        let newer = east(of: older, points: 36, step: step, day: 9)   // overlapping a little
        let clusters = PlaceMap.cluster([newer, older], step: step)
        #expect(clusters.count == 2)
        #expect(clusters.last?.photoFileNames.first == newer.photoFileName)
    }

    // MARK: - Identity

    @Test("a place keeps its identity at every scale it leads a block")
    func identityIsStableAcrossZoom() {
        let alone = pin(lat: 48.8566, lon: 2.3522, day: 2)
        let ids = Set((8...18).map { PlaceMap.cluster([alone], zoom: $0).first?.id })
        #expect(ids.count == 1)
    }

    @Test("ids do not depend on the order the pins arrive in")
    func idsAreOrderIndependent() {
        let pins = [pin(lat: 51.5074, lon: -0.1278, day: 1), pin(lat: 51.5075, lon: -0.1279, day: 2),
                    pin(lat: 51.5300, lon: -0.1000, day: 3)]
        let a = PlaceMap.cluster(pins, zoom: 15).map(\.id)
        let b = PlaceMap.cluster(pins.reversed(), zoom: 15).map(\.id)
        #expect(a == b)
    }

    @Test("going back to a place does not re-identify its block")
    func aNewPinKeepsTheIdentity() {
        let first = pin(lat: 51.5074, lon: -0.1278, day: 1)
        let later = pin(lat: 51.5075, lon: -0.1277, day: 5)
        let before = PlaceMap.cluster([first], zoom: 14)
        let after = PlaceMap.cluster([first, later], zoom: 14)
        #expect(before.first?.id == after.first?.id)
    }

    @Test("a lone block stands on its exact coordinate at every scale")
    func aLoneBlockIsNotMoved() {
        let place = pin(lat: 51.50741, lon: -0.12783, accuracy: 5)
        for z in 8...18 {
            let drawn = PlaceMap.cluster([place], zoom: z).first?.anchor
            #expect(drawn.map { abs($0.latitude - 51.50741) < 1e-9 && abs($0.longitude + 0.12783) < 1e-9 } == true,
                    "zoom \(z) moved a lone block")
        }
    }

    // MARK: - What a block shows

    /// The owner, on a phone: "they should still stay in the same area dont
    /// need to get bigger." A lone win keeps the size a finger drew for it;
    /// a crowd is one cell with its count on it.
    @Test("a lone win keeps its size, a crowd is one cell")
    func sizeSaysWhatItKnows() {
        func blockSize(count: Int, lone: BlockSize = .small) -> BlockSize? {
            let pins = (1...count).map {
                var p = pin(lat: 51.5074, lon: -0.1278, day: $0)
                p.size = lone
                return p
            }
            return PlaceMap.cluster(pins, zoom: 12).first?.size
        }
        #expect(blockSize(count: 1, lone: .hard) == .hard, "one win should keep its own size")
        #expect(blockSize(count: 2) == .small)
        #expect(blockSize(count: 30) == .small)
    }

    @Test("category ties break by earliest, like a day's does")
    func categoryTiesBreakByEarliest() {
        let cluster = PlaceMap.cluster([
            pin(lat: 51.5074, lon: -0.1278, day: 1, hour: 9, category: .work),
            pin(lat: 51.5074, lon: -0.1278, day: 1, hour: 17, category: .health)
        ], zoom: 12).first
        #expect(cluster?.category == .work)
    }

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
    /// confident block on it puts it in the wrong neighbourhood.
    @Test("a pin vaguer than a block is wide is not drawn")
    func vaguePinsAreExcluded() {
        let vague = pin(lat: 51.5074, lon: -0.1278, accuracy: 3000)
        #expect(!PlaceMap.cluster([vague], zoom: 5).isEmpty)
        #expect(PlaceMap.cluster([vague], zoom: 16).isEmpty)
    }

    // MARK: - Opening a block

    @Test("opening a lone block opens only its own place")
    func openingALoneBlock() {
        let step = PlaceMap.step(zoom: 16)
        let here = pin(lat: 51.5074, lon: -0.1278, day: 1)
        let sameSpot = pin(lat: 51.5075, lon: -0.1278, day: 2)
        let aFewStreets = pin(lat: 51.5074, lon: -0.1278 + 300.0 / 69_000, day: 3)
        let all = [here, sameSpot, aFewStreets]
        let block = try! #require(PlaceMap.cluster(all, step: step).first { $0.winCount == 2 })
        let opened = Set(PlaceMap.members(of: block.key, in: all).map(\.photoFileName))
        #expect(opened == [here.photoFileName, sameSpot.photoFileName])
    }

    @Test("opening a joined block opens every place that joined it")
    func openingAJoinedBlock() {
        let step = PlaceMap.step(zoom: 12)
        let base = pin(lat: 51.5074, lon: -0.1278, day: 1)
        let joined = east(of: base, points: 20, step: step, day: 2)
        let block = try! #require(PlaceMap.cluster([base, joined], step: step).first)
        #expect(PlaceMap.members(of: block.key, in: [base, joined]).count == 2)
        #expect(PlaceMap.members(of: block.key, in: [pin(lat: 48.8566, lon: 2.3522)]).isEmpty)
    }

    // MARK: - Scale

    @Test("a wider camera means a coarser scale")
    func scaleFollowsSpan() {
        let wide = PlaceMap.step(pointsPerUnit: PlaceMap.pointsPerUnit(spanLongitude: 40, viewportWidth: 393))
        let tight = PlaceMap.step(pointsPerUnit: PlaceMap.pointsPerUnit(spanLongitude: 0.02, viewportWidth: 393))
        #expect(tight > wide)
        #expect(PlaceMap.zoomLevel(spanLongitude: 0.02, viewportWidth: 393)
                > PlaceMap.zoomLevel(spanLongitude: 40, viewportWidth: 393))
    }

    @Test("a degenerate camera does not crash or run away")
    func zoomLevelIsBounded() {
        #expect(PlaceMap.zoomLevel(spanLongitude: 0, viewportWidth: 393) == 0)
        #expect(PlaceMap.zoomLevel(spanLongitude: 360, viewportWidth: 0) == 0)
        #expect(PlaceMap.zoomLevel(spanLongitude: 0.000001, viewportWidth: 393) <= 20)
        #expect(PlaceMap.pointsPerUnit(spanLongitude: 0, viewportWidth: 393) > 0)
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
}
