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

        /// The same rank encoding the month tower uses. Restated nowhere.
        var size: BlockSize { MonthTower.size(forWinCount: winCount) }
    }

    // MARK: - Tuning

    /// How big a cell should be on screen, in points.
    ///
    /// **A cell is about the size of a block plus its gap.**
    /// `GridConstants.blockReferenceCell` is 86.5, so 100 gives roughly four
    /// cells across a phone — the same density the tower already uses, which
    /// reads as *arranged* rather than *scattered*.
    static let targetBlockPitch: Double = 100

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
                       place: place)
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
        // Density is the invariant, not zoom.
        while result.count > limit, level < 20 {
            level += 1
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
                photoFileNames: names
            )
        }
        // Sorted so the output is deterministic whatever order a dictionary
        // hands its keys back in — otherwise a snapshot test flakes and,
        // worse, `ForEach` reorders the map for no reason.
        .sorted { $0.id < $1.id }
    }

    /// The pins belonging to one cell, **plus a half-cell margin**.
    ///
    /// A cell is a geographic identity, not a place identity, so two pins
    /// twenty metres apart can straddle a boundary — and "my two photos of the
    /// same café are in different piles" is a bad bug. The map draws crisp
    /// cells; opening one is generous. That asymmetry is deliberate: the map
    /// is a layout, the detail screen is an answer.
    static func members(of key: PlaceKey, in pins: [Pin]) -> [Pin] {
        let side = cellSide(at: key.z)
        let margin = side / 2
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
