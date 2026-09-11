import Foundation

/// The map's places, as blocks.
///
/// A namespace of value functions, by direct analogy with `MonthTower`. It
/// imports **no MapKit and no CoreLocation** and works in normalized Web
/// Mercator, so it is testable with plain numbers — no framework, no device,
/// no simulator.
///
/// **The blocks are the point.** Other photo maps drop thumbnails or dots;
/// this one drops the app's own object, sized by how much you did in that
/// place, on the same rank encoding the month tower uses. It delegates to
/// `MonthTower.size(forWinCount:)` and `MonthTower.dominantCategory(_:)`
/// rather than restating them, which is what makes a place block and a day
/// block the same object with the same grammar.
enum PlaceMap {

    // MARK: - Types

    /// One photographed win that knows where it was.
    struct Pin: Equatable {
        let dateString: String
        let completedAt: Date
        let title: String
        let category: HabitCategory
        let photoFileName: String
        let place: WinPlace
        /// How big the win itself was. **`var` with a default**, so every
        /// existing literal keeps compiling — a `let` with a default is
        /// dropped from the synthesized memberwise initializer entirely.
        var size: BlockSize = .small
    }

    /// Which cell of the world grid, at which zoom. Also the route.
    ///
    /// Three `Int`s, `Hashable`, tiny — so a cluster can be pushed as a
    /// destination and re-derived from the store rather than carried as a
    /// payload, which is the contract `PhotoCollectionView` already documents.
    struct PlaceKey: Hashable, Sendable {
        let z: Int
        let x: Int
        let y: Int
    }

    /// A place, and everything you did there.
    struct Cluster: Identifiable, Equatable {
        let key: PlaceKey
        /// Centroid of its members, so the block sits on what it contains
        /// rather than on the corner of an invisible grid.
        let latitude: Double
        let longitude: Double
        let winCount: Int
        let category: HabitCategory
        /// Newest first, de-duplicated.
        let photoFileNames: [String]

        /// **Deterministic from the grid, not from the members.**
        ///
        /// A centroid-based id changes whenever a pin joins, so every block
        /// would get a new identity on every data change and SwiftUI would
        /// tear it down and build a new one — which reads as blocks
        /// teleporting around the map. The cell is stable: same cell, same id,
        /// however many pins are in it and whatever order they arrived in.
        var id: String { "\(key.z)/\(key.x)/\(key.y)" }

        /// The size of the win itself when there is one win, and the rank by
        /// count when there are several.
        ///
        /// **One win should be its own size.** Every block on the map was
        /// drawing at `MonthTower.size(forWinCount:)`, which is `.small` for
        /// anything under three — so on a real map, where most places have one
        /// or two photographs, every block came out identical. The owner:
        /// "the blocks arent showing there size on the map." A lone win
        /// already has a size, chosen with a finger when it was logged, and
        /// that is the honest thing to draw. Only once a place holds several
        /// does the count become the more useful fact.
        var size: BlockSize { winCount == 1 ? loneSize : MonthTower.size(forWinCount: winCount) }

        /// The single member's own size, when there is a single member.
        var loneSize: BlockSize = .small

        /// **Where the block is DRAWN**: its true centroid, nudged only as far
        /// as it must be to keep blocks from overlapping.
        ///
        /// This was the cell's CENTRE, which guaranteed no two blocks could
        /// touch and was badly wrong about where things happened. The owner,
        /// testing on real wins: "the location blocks are a bit innacurate, it
        /// wont even be in the same area." Measured, he was understating it —
        /// pinning to a cell centre displaces a block by up to half a cell,
        /// and half a cell is 1.2km at the zoom where you see a city and 4.9km
        /// one step out. A map that puts your morning in the wrong
        /// neighbourhood is not a map.
        ///
        /// So the block stands on its members and is clamped into the middle
        /// of its cell only by the width of the block itself. Two neighbours
        /// still cannot overlap — each is confined to a box a block narrower
        /// than the cell, so the gap between boxes is exactly one block — and
        /// whenever the real centroid is inside that box, which is most of the
        /// time, the block is drawn exactly where the photograph was taken.
        /// The worst-case error drops from half a cell to half a block.
        var anchor: (latitude: Double, longitude: Double) {
            PlaceMap.anchor(forCentroidAt: (latitude, longitude), in: key, size: size)
        }
    }

    // MARK: - Tuning

    /// How big a cell should be on screen, in points.
    ///
    /// **A cell is the size of the BIGGEST block plus its gap.** Blocks are
    /// drawn on cell centres (`Cluster.anchor`), so the pitch is literally the
    /// distance between two neighbours: a 2x2 on the map is about 90pt across,
    /// which is why this is 116 and not the 100 it started at. At 100 two
    /// neighbouring 2x2s touched.
    ///
    /// That gives roughly three and a half cells across a phone — a little
    /// coarser than the tower, which is right: it merges sooner, and merging
    /// is the behaviour the map is for.
    static let targetBlockPitch: Double = 116

    /// The most blocks allowed on screen at once.
    ///
    /// Density is the invariant, not zoom: past this the zoom is bumped and
    /// everything re-clustered. It is a performance cap and a design one at
    /// the same time — more than this many places on screen is a scatter plot,
    /// not a map.
    static let maxOnScreen = 28

    /// One tile is this many cells across.
    private static let cellsPerTile: Double = 4

    // MARK: - Pins

    /// Every record that could be drawn: photographed, and placed.
    ///
    /// A win with no photograph is not a pin. A colour-only block on a map
    /// would be a marker with nothing to show, and the whole claim of this
    /// screen is that you can see what you did there.
    static func pins(from records: [WinRecord]) -> [Pin] {
        records.compactMap { record in
            guard let name = record.photoFileName, let place = record.place else { return nil }
            return Pin(dateString: record.dateString,
                       completedAt: record.completedAt,
                       title: record.title,
                       category: record.category,
                       photoFileName: name,
                       place: place,
                       // The size the win was logged at, so a lone block on
                       // the map is drawn at the size a finger chose for it.
                       size: record.size)
        }
    }

    // MARK: - Zoom

    /// Which grid to cluster on, for a camera showing `spanLongitude` degrees
    /// across `viewportWidth` points.
    ///
    /// Clamped to 0...20: past 20 a cell is smaller than a GPS fix is
    /// accurate, so splitting further would be drawing precision the data does
    /// not have.
    static func zoomLevel(spanLongitude: Double, viewportWidth: Double) -> Int {
        guard spanLongitude > 0, viewportWidth > 0 else { return 0 }
        let cellsAcross = viewportWidth / targetBlockPitch
        let degreesPerCell = spanLongitude / cellsAcross
        let raw = log2(360.0 / (degreesPerCell * cellsPerTile))
        return min(max(Int(raw.rounded(.down)), 0), 20)
    }

    // MARK: - Projection

    /// Web Mercator, normalized to 0...1. Pure arithmetic — `MKMapPoint` does
    /// the same job and would drag MapKit into the model layer and the tests.
    static func project(_ place: WinPlace) -> (x: Double, y: Double) {
        let x = (place.longitude + 180) / 360
        // Clamped short of the poles: `tan` diverges at ±90 and Mercator
        // cannot draw them anyway.
        let lat = min(max(place.latitude, -85.05112878), 85.05112878)
        let radians = lat * .pi / 180
        let y = (1 - log(tan(radians) + 1 / cos(radians)) / .pi) / 2
        return (x, y)
    }

    /// Web Mercator, back again. The exact inverse of `project`.
    static func unproject(x: Double, y: Double) -> (latitude: Double, longitude: Double) {
        let longitude = x * 360 - 180
        let latitude = atan(sinh(.pi * (1 - 2 * y))) * 180 / .pi
        return (latitude, longitude)
    }

    /// A block's own width on screen, in points.
    ///
    /// Mirrors `PlaceBlock` in `MemoriesMapView`, and has to: the clamp below
    /// is the reason two blocks cannot overlap, and it can only promise that
    /// if it knows how wide they actually are. `targetBlockPitch` is the other
    /// half of the same arithmetic and lives here for the same reason.
    static func blockPoints(for size: BlockSize) -> Double {
        let cell = 44.0, gutter = 2.0
        return cell * Double(size.columnSpan) + gutter * Double(size.columnSpan - 1)
    }

    /// The centroid, clamped into the part of its cell where a block of that
    /// size cannot reach a neighbour.
    ///
    /// The window is the cell less one block, centred: a block whose centre
    /// stays inside it keeps at least half its width from every edge, so two
    /// blocks in touching cells are always at least a block apart. Everything
    /// inside the window is drawn exactly where it happened.
    static func anchor(forCentroidAt centroid: (latitude: Double, longitude: Double),
                       in key: PlaceKey,
                       size: BlockSize) -> (latitude: Double, longitude: Double) {
        let side = cellSide(at: key.z)
        // How much of a cell the block covers. Cells are `targetBlockPitch`
        // points across by construction, so this is a plain ratio.
        let covered = min(blockPoints(for: size) / targetBlockPitch, 1)
        let room = side * (1 - covered) / 2

        let (cx, cy) = ((Double(key.x) + 0.5) * side, (Double(key.y) + 0.5) * side)
        let (px, py) = project(WinPlace(latitude: centroid.latitude,
                                        longitude: centroid.longitude))
        let x = min(max(px, cx - room), cx + room)
        let y = min(max(py, cy - room), cy + room)
        return unproject(x: x, y: y)
    }

    /// The middle of a cell, in degrees.
    static func centre(of key: PlaceKey) -> (latitude: Double, longitude: Double) {
        let side = cellSide(at: key.z)
        return unproject(x: (Double(key.x) + 0.5) * side,
                         y: (Double(key.y) + 0.5) * side)
    }

    static func cellSide(at z: Int) -> Double {
        1 / (pow(2, Double(z)) * cellsPerTile)
    }

    /// Which cell a place falls in.
    ///
    /// **Cells are square in PROJECTED space**, which means square on screen
    /// and progressively smaller in metres towards the poles. That is the
    /// right trade for a screen: visual squareness is what a person perceives,
    /// and a grid that stayed square in metres would draw as rectangles.
    static func key(for place: WinPlace, z: Int) -> PlaceKey {
        let (x, y) = project(place)
        let side = cellSide(at: z)
        // The x axis wraps, so longitude 180 and -180 — the same meridian —
        // land in the same cell rather than one column apart.
        //
        // It does NOT make the two sides of the antimeridian one place. A pin
        // at 179.99 and a pin at -179.99 are in adjacent cells, exactly as two
        // pins either side of any other cell boundary are. That is the
        // documented asymmetry, and `members(of:in:)` is its mitigation.
        let columns = Int((1 / side).rounded())
        let cx = Int((x / side).rounded(.down)) % max(columns, 1)
        return PlaceKey(z: z,
                        x: cx < 0 ? cx + columns : cx,
                        y: Int((y / side).rounded(.down)))
    }

    // MARK: - Clustering

    /// Groups pins into place blocks at a zoom, tightening the grid until the
    /// result is under `maxOnScreen`.
    ///
    /// - Parameter minAccuracy: pins vaguer than the cell they would sit in
    ///   are dropped. A reduced-accuracy fix is good to one to five
    ///   kilometres, and a confident block in the wrong neighbourhood is worse
    ///   than no block.
    static func cluster(_ pins: [Pin], zoom z: Int,
                        limit: Int = maxOnScreen) -> [Cluster] {
        // **Honesty is judged at the camera's zoom; density is not.**
        //
        // Filtering inside the tightening loop below was a real bug and a
        // nasty one: the loop can run to zoom 20, where a cell is under ten
        // metres, so every ordinary pin became "too vague to draw" and the map
        // went completely blank the more you asked of it. The accuracy
        // question is about what the person is actually looking at, so it is
        // asked once, here, against the zoom they are actually at.
        let visible = pins.filter { pin in
            guard let accuracy = pin.place.accuracy else { return true }
            return accuracy <= cellMetres(at: z)
        }

        var level = z
        var result = clustered(visible, z: level)
        // **Density is the invariant, not zoom — and thinning means COARSER.**
        //
        // This loop used to step `level` UP, which is backwards and was a real
        // bug with a visible symptom. A higher zoom is a finer grid, so every
        // pass split the clusters further and the count went up, not down: the
        // loop ran all the way to 20, where a cell is under ten metres, and
        // every pin became its own block sitting on top of its neighbours.
        // Merging is what reduces a count, so the grid gets coarser until the
        // map is legible.
        while result.count > limit, level > 0 {
            level -= 1
            result = clustered(visible, z: level)
        }
        return result
    }

    /// A cell's rough width in metres. One degree of longitude is about 111km
    /// at the equator; nothing here needs better than an order of magnitude.
    static func cellMetres(at z: Int) -> Double {
        cellSide(at: z) * 360 * 111_000
    }

    private static func clustered(_ pins: [Pin], z: Int) -> [Cluster] {
        var groups: [PlaceKey: [Pin]] = [:]
        for pin in pins {
            groups[key(for: pin.place, z: z), default: []].append(pin)
        }

        return groups.map { key, members in
            let newestFirst = members.sorted { $0.completedAt > $1.completedAt }
            var seen = Set<String>()
            let names = newestFirst.compactMap { seen.insert($0.photoFileName).inserted
                ? $0.photoFileName : nil }
            return Cluster(
                key: key,
                latitude: members.reduce(0) { $0 + $1.place.latitude } / Double(members.count),
                longitude: members.reduce(0) { $0 + $1.place.longitude } / Double(members.count),
                winCount: members.count,
                category: MonthTower.dominantCategory(
                    members.map { (category: $0.category, at: $0.completedAt) }
                ),
                photoFileNames: names,
                loneSize: members.count == 1 ? members[0].size : .small
            )
        }
        // Sorted so the output is deterministic whatever order a dictionary
        // hands its keys back in — otherwise a snapshot test flakes and,
        // worse, `ForEach` reorders the map for no reason.
        .sorted { $0.id < $1.id }
    }

    /// The cell one level coarser that contains this one.
    ///
    /// **This is what makes blocks merge instead of blink.** Zooming out
    /// changes every id at once, so without a parent there is no way to say
    /// which blocks became which — the whole set can only cross-fade. With it,
    /// each child knows the point it should travel to as it goes, and each new
    /// block knows where it came from as it arrives.
    ///
    /// Halving the grid is exactly one zoom level, so the parent is the cell
    /// at `z - 1` holding half the coordinates.
    static func parent(of key: PlaceKey) -> PlaceKey? {
        guard key.z > 0 else { return nil }
        return PlaceKey(z: key.z - 1, x: key.x / 2, y: key.y / 2)
    }

    /// Where a set of clusters would sit if they were one block — the centre a
    /// merge collapses to, weighted by how much each holds so the join lands
    /// on the busy place rather than in the gap between them.
    static func centroid(of clusters: [Cluster]) -> (latitude: Double, longitude: Double)? {
        let total = clusters.reduce(0) { $0 + $1.winCount }
        guard total > 0 else { return nil }
        return (clusters.reduce(0) { $0 + $1.latitude * Double($1.winCount) } / Double(total),
                clusters.reduce(0) { $0 + $1.longitude * Double($1.winCount) } / Double(total))
    }

    /// The pins belonging to one cell, **plus a half-cell margin**.
    ///
    /// A cell is a geographic identity, not a place identity, so two pins
    /// twenty metres apart can straddle a boundary — and "my two photos of the
    /// same café are in different piles" is a bad bug. The map draws crisp
    /// cells; opening one is generous. That asymmetry is deliberate: the map
    /// is a layout, the detail screen is an answer.
    /// How far past a cell's edge counts as the same place, in metres.
    ///
    /// **A distance, not a fraction of the cell.** The margin used to be half
    /// a cell, which is 20m at the tightest zoom and FIVE KILOMETRES at the
    /// one where you see a city — so tapping a single block opened every
    /// photograph for miles around. The owner: "if you just click one thats
    /// alone it still opens all the photos in that area instead of just
    /// opening that one." The thing the margin is for — two photographs of
    /// the same cafe landing either side of an invisible line — is a
    /// fixed-distance problem and always was.
    static let sameePlaceMetres: Double = 60

    static func members(of key: PlaceKey, in pins: [Pin]) -> [Pin] {
        let side = cellSide(at: key.z)
        let margin = min(side / 2, sameePlaceMetres / (360 * 111_000))
        let minX = Double(key.x) * side - margin
        let maxX = Double(key.x + 1) * side + margin
        let minY = Double(key.y) * side - margin
        let maxY = Double(key.y + 1) * side + margin
        return pins.filter { pin in
            let (x, y) = project(pin.place)
            return x >= minX && x <= maxX && y >= minY && y <= maxY
        }
    }
}
