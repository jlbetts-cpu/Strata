import Foundation

/// The map's places, as blocks.
///
/// A namespace of value functions, by direct analogy with `MonthTower`. It
/// imports **no MapKit and no CoreLocation** and works in normalized Web
/// Mercator, so it is testable with plain numbers — no framework, no device,
/// no simulator.
///
/// **When two photographs are one block.** The owner, from a phone: "the map
/// placement algorithm is still not the most accurate in terms of when to
/// connect and when not, it should be a lot like snap maps in that aspect,
/// only merge if its in the same location." And, choosing between three rules
/// laid out for him: *overlap a little, then merge*.
///
/// So there are exactly two reasons, and no others:
///
/// 1. **The same spot.** Photographs within `samePlaceMetres` of each other
///    are one place at every zoom — the ordinary wander of a phone's fix is
///    not a second place.
/// 2. **They would cover each other.** At the zoom being drawn, each place's
///    block has a real size on screen. Two blocks may overlap by up to a third
///    (`maxOverlap`), stacked newest on top, and still read as two places;
///    past that the smaller joins the busier, and the block stays standing on
///    the busier spot's own coordinate.
///
/// **It used to be a grid**, and the grid was the inaccuracy. Places were
/// bucketed into cells about a third of a screen wide, so whether two
/// photographs merged depended on where the cell lines fell, not on how far
/// apart they were. Measured over 400 random pairs a distance: at street zoom
/// two spots 80 metres apart merged 30% of the time though their blocks were
/// nowhere near touching; at a city's zoom, places 1.2 km apart merged 36%
/// of the time. A density cap then coarsened the grid further, and blocks with
/// a neighbour were nudged off their coordinates to keep the cells apart.
/// None of that is left.
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

    /// One block, as a route: which place leads it, at which scale it was
    /// drawn. `PhotoCollectionView` re-derives the block's photographs from
    /// the store with it rather than carrying them.
    struct PlaceKey: Hashable, Sendable {
        /// The scale step the block was drawn at. See `step(pointsPerUnit:)`.
        let step: Int
        /// The leading place's identity. See `Spot.id`.
        let spot: String
    }

    /// A place, and everything you did there.
    struct Cluster: Identifiable, Equatable {
        let key: PlaceKey
        /// The leading place's own coordinate: a spot somebody stood on, never
        /// a point between two.
        let latitude: Double
        let longitude: Double
        let winCount: Int
        let category: HabitCategory
        /// Newest first, de-duplicated.
        let photoFileNames: [String]
        /// The newest photograph's time, which is what stacks a block on top
        /// of a block it overlaps.
        let newest: Date

        /// **The leading place, not the scale.** A place that is still leading
        /// its block after a zoom keeps its identity, so SwiftUI keeps its view
        /// and nothing on screen is torn down and rebuilt for a block that did
        /// not change.
        var id: String { key.spot }

        /// **One win is its own size; a crowd is one cell.**
        ///
        /// The owner: "they should still stay in the same area dont need to
        /// get bigger." A block already says how many it holds, on its badge.
        var size: BlockSize { winCount == 1 ? loneSize : .small }

        /// The single member's own size, when there is a single member.
        var loneSize: BlockSize = .small

        /// Where the block is drawn: exactly on its leading place.
        var anchor: (latitude: Double, longitude: Double) { (latitude, longitude) }
    }

    // MARK: - Tuning

    /// **Photographs this close together are one place.** The app already
    /// decided 60 metres is the same place for opening one; the drawing uses
    /// the same number, so the two can never disagree.
    static let samePlaceMetres: Double = 60

    /// **How much of a block may be covered before it joins its neighbour**,
    /// as a share of the smaller block. The owner's rule, chosen from three:
    /// overlap a little, then merge. A third still reads as two blocks on a
    /// pile; beyond it the one underneath is mostly hidden and stops being a
    /// place you can see.
    static let maxOverlap: Double = 1.0 / 3.0

    /// How big a grid cell is on screen at an integer zoom, in points. Only
    /// `zoomLevel` still uses a grid, to decide when the map is close enough
    /// to show place names.
    static let targetBlockPitch: Double = 116

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

    // MARK: - Zoom and scale

    /// A coarse integer zoom for a camera, used for place names and labels.
    /// Clamped to 0...20.
    static func zoomLevel(spanLongitude: Double, viewportWidth: Double) -> Int {
        guard spanLongitude > 0, viewportWidth > 0 else { return 0 }
        let cellsAcross = viewportWidth / targetBlockPitch
        let degreesPerCell = spanLongitude / cellsAcross
        let raw = log2(360.0 / (degreesPerCell * cellsPerTile))
        return min(max(Int(raw.rounded(.down)), 0), 20)
    }

    /// **Points on screen per unit of the projected world**, for a camera
    /// showing `spanLongitude` degrees across `viewportWidth` points. Exact:
    /// Mercator's x is linear in longitude.
    static func pointsPerUnit(spanLongitude: Double, viewportWidth: Double) -> Double {
        guard spanLongitude > 0, viewportWidth > 0 else { return 1 }
        return viewportWidth / (spanLongitude / 360)
    }

    /// **The scale, in quarter-zoom steps.** Blocks are laid out again only
    /// when this changes: often enough that a merge happens when two blocks
    /// really start to cover each other, not so often that every pixel of a
    /// pinch re-lays the map.
    static func step(pointsPerUnit: Double) -> Int {
        Int((log2(max(pointsPerUnit, 1)) * 4).rounded(.down))
    }

    /// The scale a step stands for — its lower edge, so a layout is never
    /// drawn tighter than it was worked out for.
    static func pointsPerUnit(step: Int) -> Double {
        pow(2, Double(step) / 4)
    }

    /// The step of the old integer zoom, whose cell was `targetBlockPitch`
    /// points across. For tests and probes that think in zooms.
    static func step(zoom z: Int) -> Int {
        step(pointsPerUnit: targetBlockPitch / cellSide(at: z))
    }

    static func cellSide(at z: Int) -> Double {
        1 / (pow(2, Double(z)) * cellsPerTile)
    }

    /// A grid cell's rough width in metres at an integer zoom.
    static func cellMetres(at z: Int) -> Double {
        cellSide(at: z) * 360 * 111_000
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

    /// A block's size on screen, in points. Mirrors `PlaceBlock` in
    /// `MemoriesMapView`, and has to: overlap is measured against what is
    /// actually drawn.
    static func blockPoints(for size: BlockSize) -> (width: Double, height: Double) {
        let cell = 44.0, gutter = 2.0
        return (cell * Double(size.columnSpan) + gutter * Double(size.columnSpan - 1),
                cell * Double(size.rowSpan) + gutter * Double(size.rowSpan - 1))
    }

    // MARK: - Places

    /// Photographs within `samePlaceMetres` of each other.
    struct Spot {
        var pins: [Pin]
        /// **The earliest photograph's name**: stable as later photographs
        /// join, so a place does not change identity because you went back.
        var id: String {
            pins.min { ($0.completedAt, $0.photoFileName) < ($1.completedAt, $1.photoFileName) }?
                .photoFileName ?? ""
        }
        var centre: (latitude: Double, longitude: Double) {
            let n = Double(max(pins.count, 1))
            return (pins.reduce(0) { $0 + $1.place.latitude } / n,
                    pins.reduce(0) { $0 + $1.place.longitude } / n)
        }
        var newest: Date { pins.map(\.completedAt).max() ?? .distantPast }
    }

    /// Gathers photographs into places. Each photograph joins the nearest
    /// place within `samePlaceMetres`, oldest first, and places that end up
    /// within that distance of each other are joined, until nothing moves.
    static func spots(_ pins: [Pin]) -> [Spot] {
        var spots: [Spot] = []
        for pin in pins.sorted(by: { ($0.completedAt, $0.photoFileName) < ($1.completedAt, $1.photoFileName) }) {
            let here = (pin.place.latitude, pin.place.longitude)
            if let nearest = spots.indices
                .map({ ($0, metres(between: spots[$0].centre, and: here)) })
                .filter({ $0.1 <= samePlaceMetres })
                .min(by: { $0.1 < $1.1 })?.0 {
                spots[nearest].pins.append(pin)
            } else {
                spots.append(Spot(pins: [pin]))
            }
        }
        var changed = true
        while changed {
            changed = false
            search: for i in spots.indices {
                for j in spots.indices where j > i
                    && metres(between: spots[i].centre, and: spots[j].centre) <= samePlaceMetres {
                    spots[i].pins += spots[j].pins
                    spots.remove(at: j)
                    changed = true
                    break search
                }
            }
        }
        return spots
    }

    // MARK: - Blocks

    /// How much of the smaller of two blocks the larger covers, 0...1, for
    /// blocks centred `dx`, `dy` points apart.
    static func overlap(dx: Double, dy: Double,
                        _ a: (width: Double, height: Double),
                        _ b: (width: Double, height: Double)) -> Double {
        let ox = max(0, min((a.width + b.width) / 2 - abs(dx), min(a.width, b.width)))
        let oy = max(0, min((a.height + b.height) / 2 - abs(dy), min(a.height, b.height)))
        return (ox / min(a.width, b.width)) * (oy / min(a.height, b.height))
    }

    /// The blocks to draw at a scale step. See the type's documentation for
    /// the rule.
    ///
    /// Places are taken busiest first (then newest), and each either leads a
    /// block of its own or joins the first block it would cover past
    /// `maxOverlap`. Then any two blocks that still cover each other past it —
    /// a block shrinks to one cell when it gains a second win, which changes
    /// what it covers — are joined, the less busy into the busier, until none
    /// do. Every block stands on its leading place.
    ///
    /// - Parameter minAccuracy: a photograph whose fix is vaguer than a
    ///   block's own width on screen is not drawn. A reduced-accuracy fix is
    ///   good to kilometres, and a confident block in the wrong neighbourhood
    ///   is worse than no block.
    static func cluster(_ pins: [Pin], step: Int) -> [Cluster] {
        let scale = pointsPerUnit(step: step)
        let metresPerPoint = 360 * 111_000 / scale
        let blockMetres = blockPoints(for: .small).width * metresPerPoint
        let visible = pins.filter { ($0.place.accuracy ?? 0) <= max(blockMetres, samePlaceMetres) }

        struct Group {
            var lead: Spot
            var members: [Spot]
            let x: Double
            let y: Double
            var wins: Int { members.reduce(0) { $0 + $1.pins.count } }
            var size: BlockSize { wins == 1 ? (lead.pins.first?.size ?? .small) : .small }
            var newest: Date { members.map(\.newest).max() ?? .distantPast }
        }

        func position(_ spot: Spot) -> (x: Double, y: Double) {
            let c = spot.centre
            let (px, py) = project(WinPlace(latitude: c.latitude, longitude: c.longitude))
            return (px * scale, py * scale)
        }
        func covered(_ a: Group, _ b: Group) -> Double {
            // The world wraps: take the shorter way round.
            let world = scale
            var dx = abs(a.x - b.x)
            dx = min(dx, world - dx)
            return overlap(dx: dx, dy: a.y - b.y, blockPoints(for: a.size), blockPoints(for: b.size))
        }
        func busier(_ a: Group, _ b: Group) -> Bool {
            if a.wins != b.wins { return a.wins > b.wins }
            if a.newest != b.newest { return a.newest > b.newest }
            return a.lead.id < b.lead.id
        }

        var groups: [Group] = []
        let ordered = spots(visible).map { spot -> Group in
            let p = position(spot)
            return Group(lead: spot, members: [spot], x: p.x, y: p.y)
        }.sorted(by: busier)
        for candidate in ordered {
            if let host = groups.indices.first(where: { covered(groups[$0], candidate) > maxOverlap }) {
                groups[host].members.append(candidate.lead)
            } else {
                groups.append(candidate)
            }
        }
        var changed = true
        while changed {
            changed = false
            search: for i in groups.indices {
                for j in groups.indices where j > i && covered(groups[i], groups[j]) > maxOverlap {
                    let (keep, fold) = busier(groups[i], groups[j]) ? (i, j) : (j, i)
                    groups[keep].members += groups[fold].members
                    groups.remove(at: fold)
                    changed = true
                    break search
                }
            }
        }

        return groups.map { group in
            let all = group.members.flatMap(\.pins)
            let newestFirst = all.sorted { $0.completedAt > $1.completedAt }
            var seen = Set<String>()
            let names = newestFirst.compactMap { seen.insert($0.photoFileName).inserted ? $0.photoFileName : nil }
            let centre = group.lead.centre
            return Cluster(
                key: PlaceKey(step: step, spot: group.lead.id),
                latitude: centre.latitude,
                longitude: centre.longitude,
                winCount: all.count,
                category: MonthTower.dominantCategory(all.map { (category: $0.category, at: $0.completedAt) }),
                photoFileNames: names,
                newest: group.newest,
                loneSize: all.count == 1 ? all[0].size : .small
            )
        }
        // **Newest on top.** Annotations draw in order, so the block drawn last
        // is the one on top of any it overlaps. Ties go by identity, so the
        // order is the same on every pass.
        .sorted { ($0.newest, $0.id) < ($1.newest, $1.id) }
    }

    /// The blocks at an old integer zoom. For tests and probes.
    static func cluster(_ pins: [Pin], zoom z: Int) -> [Cluster] {
        cluster(pins, step: step(zoom: z))
    }

    /// Equirectangular, which is exact enough for tens of metres and needs no
    /// trigonometry beyond one cosine.
    static func metres(between a: (latitude: Double, longitude: Double),
                       and b: (latitude: Double, longitude: Double)) -> Double {
        let metresPerDegree = 111_000.0
        let dLat = (a.latitude - b.latitude) * metresPerDegree
        let dLon = (a.longitude - b.longitude) * metresPerDegree
            * cos((a.latitude + b.latitude) / 2 * .pi / 180)
        return (dLat * dLat + dLon * dLon).squareRoot()
    }

    /// **The photographs a block stood for**, laid out again at the scale it
    /// was drawn at. Opening a block opens what it showed: a lone block opens
    /// its one place, a joined block every place that joined it, and never the
    /// next town because a grid cell happened to reach it.
    static func members(of key: PlaceKey, in pins: [Pin]) -> [Pin] {
        guard let block = cluster(pins, step: key.step).first(where: { $0.key == key }) else {
            return []
        }
        let names = Set(block.photoFileNames)
        return pins.filter { names.contains($0.photoFileName) }
    }
}
