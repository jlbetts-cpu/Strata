import MapKit
import SwiftUI

/// Where you have been, as blocks.
///
/// Every photographed win that knows its place, clustered into the app's own
/// object and sized by how much you did there — the same rank encoding the
/// month tower uses, through `PlaceMap`.
///
/// **MapKit cannot be recoloured.** `MapStyle` offers elevation, points of
/// interest, traffic and an emphasis, and nothing else; there is no palette to
/// set. So the only levers are what to strip and what to put on top, and both
/// are used: every point of interest is excluded, the emphasis is muted, and
/// the blocks are the only saturated thing on the screen.
struct MemoriesMapView: View {
    let pins: [PlaceMap.Pin]
    /// Whether the map takes gestures.
    var isInteractive: Bool = true
    /// **Imagery, chosen by measuring.**
    ///
    /// Both grounds were rendered at phone size with real blocks on them and
    /// scored the way the "Memories is boring" diagnosis was: mean luminance,
    /// the 5th-to-95th spread, and edge density as a proxy for clutter.
    ///
    ///     standard, muted, no POIs   mean 232   edges 6.5%
    ///     imagery                    mean 117   edges 10.9%
    ///     standard + scrim           mean 215   edges 5.7%
    ///     imagery + scrim            mean  99   edges 5.9%   <-- this
    ///     (the camera, for scale)    mean   9   edges 2.0%
    ///     (Memories as it was)       mean 207   edges 3.9%
    ///
    /// The standard ground FAILS the thing it was meant to fix: at 232 it is
    /// brighter than the 207 page it replaces, and it is full of place names
    /// and road shields that MapKit will not let us remove — `excludingAll`
    /// drops the pins, not the labels. Imagery commits to a value the way the
    /// camera does and leaves the blocks as the only saturated thing on
    /// screen.
    var style: Style = .satellite
    var onSelect: (PlaceMap.PlaceKey) -> Void = { _ in }

    /// The two grounds worth considering, since we cannot invent a third.
    enum Style: Equatable {
        /// Standard, muted, no points of interest. Nearly-blank pale geometry.
        case quiet
        /// Real imagery. Dark and textured, the register the camera works in.
        case satellite
    }

    @State private var camera: MapCameraPosition = .automatic
    @State private var zoom: Int = 12
    @State private var viewportWidth: CGFloat = 393
    /// What is on screen right now, with the coordinate each block is drawn
    /// at — which is not always where its cluster is. During a merge a block
    /// sits at the point it is travelling to. See `apply(_:)`.
    @State private var displayed: [Placed] = []
    @State private var didFrame = false
    /// Observed, so the empty state follows the answer to its own prompt
    /// rather than waiting for the screen to be opened again.
    ///
    /// `@State`, not a plain stored property: a stored `private` property
    /// joins the memberwise initializer and makes the whole init private,
    /// which stops every caller constructing this view.
    @State private var location = LocationService.shared

    /// A cluster, and where it is being drawn.
    ///
    /// The coordinate is separate from the cluster's own because a merge moves
    /// blocks: the ones being swallowed travel to the joining point before
    /// they go, and the one that arrives starts from that same point. Without
    /// that the set can only cross-fade, which is what "the blocks blink"
    /// looks like.
    struct Placed: Identifiable, Equatable {
        let cluster: PlaceMap.Cluster
        var latitude: Double
        var longitude: Double
        var id: String { cluster.id }
        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }

        /// At rest, a block sits on its cell — see `Cluster.anchor`.
        static func atRest(_ cluster: PlaceMap.Cluster) -> Placed {
            Placed(cluster: cluster,
                   latitude: cluster.anchor.latitude,
                   longitude: cluster.anchor.longitude)
        }
    }

    /// How long a merge or a split takes.
    ///
    /// Slower than a cross-fade on purpose: the whole point is that you can
    /// SEE where a block went. `docs/apple-design.md` §8 — the intermediate
    /// frames are what tell you the outcome.
    private static let travel: Double = 0.42

    var body: some View {
        map
            .overlay { if pins.isEmpty { emptyState } }
    }

    private var map: some View {
        Map(position: $camera, interactionModes: isInteractive ? .all : []) {
            ForEach(displayed) { placed in
                Annotation("", coordinate: placed.coordinate, anchor: .center) {
                    PlaceBlock(cluster: placed.cluster)
                        .onTapGesture { onSelect(placed.cluster.key) }
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(mapStyle)
        .mapControls { }
        // **Apple's attribution, moved rather than removed.**
        //
        // It cannot be removed: displaying it is a condition of the Apple
        // Developer Program License Agreement, and there is no API that hides
        // it. There is also no API that positions it — but it is laid out
        // inside the map's safe area, so an inset moves it. This lifts it
        // clear of the floating tab bar, where it was colliding, to just above
        // it: still legible, still complete, and reading as a caption on the
        // map rather than as something stuck to the corner of the screen.
        .safeAreaPadding(.bottom, DrawerMetrics.tabBarClearance - 22)
        .safeAreaPadding(.leading, 6)
        // **A scrim we own.**
        //
        // MapKit cannot be recoloured, so this is the only lever left after
        // stripping points of interest and muting the emphasis. Measured, it
        // is doing real work: the standard ground came out at mean luminance
        // 232 — BRIGHTER than the Memories page it was meant to fix, which was
        // 207 — and imagery at 117 against the camera's 9. The scrim pulls the
        // tiles down towards the app's own register and lets the blocks be the
        // only saturated thing on the screen.
        .overlay {
            Rectangle()
                .fill(AppColors.warmBlack.opacity(scrimOpacity))
                // Nothing announces itself. The wash lifting as the names
                // arrive is a thing you should never catch happening.
                .animation(GridConstants.gentleReveal, value: scrimOpacity)
                .allowsHitTesting(false)
        }
        #if DEBUG
        // **`id:`, not a bare `.task`.** A bare one runs once at appear and
        // captures the view value it had then — which is before the fetch
        // lands, so `pins` was empty and the probe dutifully reported zero
        // blocks at every zoom while the map on screen was full of them. An
        // instrument aimed at the wrong thing looks exactly like a null
        // result. Keyed on the count, it re-runs with a fresh `self`.
        .task(id: pins.count) {
            guard DebugHarness.sweepsMap, !pins.isEmpty else { return }
            await sweep()
        }
        #endif
        // `.onEnd`, not `.continuous`. Re-clustering every camera frame both
        // costs CPU and looks wrong — blocks twitch between two cells while
        // you pan, because the cell under a pin changes several times a
        // second.
        .onMapCameraChange(frequency: .onEnd) { context in
            let next = PlaceMap.zoomLevel(
                spanLongitude: context.region.span.longitudeDelta,
                viewportWidth: Double(viewportWidth)
            )
            guard next != zoom else { return }
            let previous = zoom
            zoom = next
            apply(PlaceMap.cluster(pins, zoom: next), from: previous, to: next)
        }
        .task(id: pins.count) {
            displayed = PlaceMap.cluster(pins, zoom: zoom).map(Placed.atRest)
            frameOnYourPlaces()
        }
    }

    // MARK: - Merging and splitting

    /// Moves from one set of blocks to another so you can see what became what.
    ///
    /// **Zooming out is a merge.** Every block that is about to be swallowed
    /// travels to the point where its parent will sit, then the parent arrives
    /// there. **Zooming in is a split**: the new blocks are placed on their
    /// parent's point first and then move out to where they belong. Either
    /// way something travels, which is the difference between a map and a
    /// slideshow.
    ///
    /// The join is weighted by how much each block holds, so a merge lands on
    /// the busy place rather than in the gap between two.
    private func apply(_ next: [PlaceMap.Cluster], from old: Int, to new: Int) {
        let zoomingOut = new < old
        let byID = Dictionary(uniqueKeysWithValues: next.map { ($0.id, $0) })

        if zoomingOut {
            // Walk each current block up to the cell it is joining, and send
            // it there.
            var moved: [Placed] = []
            for placed in displayed {
                let target = ancestor(of: placed.cluster.key, at: new).flatMap { byID[keyID($0)] }
                moved.append(Placed(cluster: placed.cluster,
                                    latitude: target?.anchor.latitude ?? placed.latitude,
                                    longitude: target?.anchor.longitude ?? placed.longitude))
            }
            withAnimation(.easeInOut(duration: Self.travel)) { displayed = moved }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(Self.travel))
                guard zoom == new else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    displayed = next.map(Placed.atRest)
                }
            }
        } else {
            // Place the arrivals on the block they came out of, then let them
            // travel to their own ground.
            let origins = Dictionary(uniqueKeysWithValues: displayed.map { ($0.id, $0) })
            displayed = next.map { cluster in
                let from = ancestor(of: cluster.key, at: old).flatMap { origins[keyID($0)] }
                return Placed(cluster: cluster,
                              latitude: from?.latitude ?? cluster.anchor.latitude,
                              longitude: from?.longitude ?? cluster.anchor.longitude)
            }
            withAnimation(.easeInOut(duration: Self.travel)) {
                displayed = next.map(Placed.atRest)
            }
        }
    }

    /// The cell containing `key` at a coarser zoom, by halving until it gets
    /// there. Nil if `level` is not coarser.
    private func ancestor(of key: PlaceMap.PlaceKey, at level: Int) -> PlaceMap.PlaceKey? {
        guard level < key.z else { return nil }
        var current = key
        while current.z > level, let up = PlaceMap.parent(of: current) { current = up }
        return current.z == level ? current : nil
    }

    private func keyID(_ key: PlaceMap.PlaceKey) -> String { "\(key.z)/\(key.x)/\(key.y)" }

    #if DEBUG
    /// The distance between the two closest blocks, in POINTS on screen.
    ///
    /// This is the overlap question asked directly rather than inferred from a
    /// screenshot. A 2x2 is about 90pt across, so anything at or under that is
    /// two blocks touching. Measured in projected space, which is the space the
    /// blocks are laid out in, then converted through the camera's own span.
    private func closestPair(_ clusters: [PlaceMap.Cluster], span: Double) -> Int {
        guard clusters.count > 1 else { return 9999 }
        let pointsPerUnitX = Double(viewportWidth) / (span / 360)
        var best = Double.infinity
        let points = clusters.map { cluster -> (Double, Double) in
            PlaceMap.project(WinPlace(latitude: cluster.anchor.latitude,
                                      longitude: cluster.anchor.longitude))
        }
        for i in points.indices {
            for j in points.indices where j > i {
                let dx = (points[i].0 - points[j].0) * pointsPerUnitX
                let dy = (points[i].1 - points[j].1) * pointsPerUnitX
                best = min(best, (dx * dx + dy * dy).squareRoot())
            }
        }
        return Int(best.rounded())
    }
    #endif

    // MARK: - Where it opens

    /// **Your town, not the planet.**
    ///
    /// `.automatic` frames every annotation, which is right in the middle and
    /// wrong at both ends: two places a country apart open on a continent, and
    /// one place opens on a doorway. This clamps the span at both ends, so the
    /// map always opens somewhere that reads as *around here* — near enough to
    /// recognise streets, far enough to be a place rather than a pin.
    private func frameOnYourPlaces() {
        guard !didFrame, !pins.isEmpty else { return }
        didFrame = true
        let lats = pins.map(\.place.latitude)
        let lons = pins.map(\.place.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }
        let centre = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                            longitude: (minLon + maxLon) / 2)
        // A comfortable town: roughly three kilometres across at the tight end,
        // a wide city at the loose one.
        let span = min(max(max(maxLat - minLat, maxLon - minLon) * 1.4, 0.03), 0.35)
        camera = .region(MKCoordinateRegion(
            center: centre,
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        ))
    }

    // MARK: - Nothing on it yet

    /// **The map is empty on day one and cannot be otherwise.**
    ///
    /// No photograph taken before location capture shipped has a place, and
    /// none ever will: every path into `ImageManager` re-encodes a resized
    /// `UIImage` with no metadata container. That is said out loud here rather
    /// than left for somebody to discover, because "why is my map empty, I
    /// have three hundred photos" is this screen's real failure mode.
    ///
    /// This is also the only place the app asks for location. The camera would
    /// be the wrong place — a permission prompt in the middle of taking a
    /// photograph is a prompt with no visible payoff.
    @ViewBuilder
    private var emptyState: some View {
        let denied = location.isDenied
        VStack(spacing: GridConstants.gapTight) {
            Text(denied ? "Places are off" : "Your map starts here")
                .font(Typography.headerMedium)
                .foregroundStyle(.white)

            Text(denied
                 ? "Strata can't tell where a photo was taken."
                 : "Photos you take from now on remember where you were. The ones you already have don't — that isn't something we can go back and add.")
                .font(Typography.screenSubtitle)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                HapticsEngine.lightTap()
                if denied {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } else {
                    location.requestAccess()
                }
            } label: {
                Text(denied ? "Open Settings" : "Turn on places")
                    .font(Typography.headerSmall)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .frame(height: 44)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .mapPrimeGlass()
            .padding(.top, GridConstants.gapTight)
            // Once it is granted there is nothing left to ask, and a button
            // that does nothing is worse than no button.
            .opacity(location.canAsk || denied ? 1 : 0)
        }
        .padding(GridConstants.gapSection)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Dark enough to read white type on, whatever the imagery underneath
        // happens to be.
        .background(AppColors.warmBlack.opacity(0.55))
    }

    #if DEBUG
    /// Pulls the camera in through a ladder of spans and reports what
    /// clustered at each one.
    ///
    /// The numbers to look for: the count should fall as the span widens and
    /// rise as it narrows, never exceed `PlaceMap.maxOnScreen`, and never
    /// reach zero — a map that blanks as you zoom was a real bug the unit
    /// tests caught, and this is the same claim checked on the live view.
    private func sweep() async {
        let centre = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        // Out and then back in, so a MERGE is exercised and not just a split.
        for span in [0.004, 0.015, 0.06, 0.25, 1.0, 4.0, 1.0, 0.25, 0.06, 0.015, 0.004] {
            withAnimation(nil) {
                camera = .region(MKCoordinateRegion(
                    center: centre,
                    span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
                ))
            }
            try? await Task.sleep(for: .milliseconds(900))
            let z = PlaceMap.zoomLevel(spanLongitude: span,
                                       viewportWidth: Double(viewportWidth))
            let found = PlaceMap.cluster(pins, zoom: z)
            NSLog("[strata-probe] mapSweep span=\(span) zoom=\(z) "
                  + "blocks=\(found.count) wins=\(found.reduce(0) { $0 + $1.winCount }) "
                  + "of \(pins.count) "
                  + "closestPair=\(closestPair(found, span: span))pt")
        }
    }
    #endif

    /// Where the town appears.
    ///
    /// Below this the map is a shape — countries, coastlines, the blocks. At
    /// and above it you are looking at a neighbourhood, and a neighbourhood
    /// without its names is a diagram. Zoom 13 is roughly "a few streets
    /// across a phone", which is exactly the point at which a block stops
    /// meaning *this city* and starts meaning *this corner*.
    private static let labelZoom = 13

    private var isClose: Bool { zoom >= Self.labelZoom }

    /// **Landmarks only — the things that tell you where you are.**
    ///
    /// This list was twice as long and included cafés, restaurants and
    /// bakeries. Photographed over Trafalgar Square, that produced about
    /// twenty-five orange pins against two blocks: the map named every
    /// sandwich shop in central London and buried the only thing on the screen
    /// that was actually yours. The blocks are the content; the map is the
    /// ground under them.
    ///
    /// What is left is sparse by nature and is what a person navigates by —
    /// the gallery, the park, the theatre, the stadium. One of these on screen
    /// tells you the corner you are looking at. Twenty restaurants tell you
    /// nothing you did not already know about a city.
    private static let worthNaming: [MKPointOfInterestCategory] = [
        .museum, .library, .theater, .musicVenue, .stadium,
        .park, .nationalPark, .beach, .marina, .campground,
        .amusementPark, .aquarium, .zoo
    ]

    private var mapStyle: MapStyle {
        switch style {
        case .quiet:
            // **Pale, and it earns its names as you arrive.**
            //
            // The owner's call after seeing both grounds side by side. Far
            // out it is nearly-blank geometry with no labels at all, so the
            // blocks are the only thing on the screen with anything to say.
            // Close in the emphasis comes up and a curated set of places
            // appears, the way Snap Map fills in as you drop into a
            // neighbourhood — because at that distance the question has
            // changed from "where in the world" to "which corner".
            return .standard(elevation: .flat,
                             emphasis: isClose ? .automatic : .muted,
                             pointsOfInterest: isClose
                                 ? .including(Self.worthNaming)
                                 : .excludingAll,
                             showsTraffic: false)
        case .satellite:
            return .imagery(elevation: .flat)
        }
    }

    /// How hard the scrim pulls the tiles towards the app's ground.
    ///
    /// It lifts as you arrive. Far out there is nothing under it but colour
    /// fields and it can do its full work; close in there are names under it,
    /// and a wash over type is the one thing that makes a map feel cheap.
    private var scrimOpacity: Double {
        switch style {
        case .satellite: return isClose ? 0.22 : 0.34
        case .quiet: return isClose ? 0.03 : 0.10
        }
    }
}

/// One place, drawn as one of the app's blocks.
///
/// The real `BlockSurface`, so a place block and a tower block are the same
/// object. The photograph sits on the colour rather than replacing it — the
/// colour is what the block IS while the picture decodes, and it is what shows
/// through the rim.
private struct PlaceBlock: View {
    let cluster: PlaceMap.Cluster

    /// One cell, on the map. Smaller than the tower's, because a map is denser
    /// than a tower and a 2x2 has to fit on a phone beside its neighbours.
    private static let cell: CGFloat = 44

    private var size: CGSize {
        let gutter = Self.cell * GridConstants.spacing / GridConstants.blockReferenceCell
        return CGSize(
            width: Self.cell * CGFloat(cluster.size.columnSpan)
                + gutter * CGFloat(cluster.size.columnSpan - 1),
            height: Self.cell * CGFloat(cluster.size.rowSpan)
                + gutter * CGFloat(cluster.size.rowSpan - 1)
        )
    }

    var body: some View {
        BlockSurface(
            cornerRadius: GridConstants.blockCornerRadius(forCell: Self.cell),
            scale: Self.cell / GridConstants.blockReferenceCell,
            // A white wash floors a photograph's luminance at its own alpha.
            // The tower's photo blocks drop to 0.06 for exactly this reason.
            washOpacity: 0.06
        ) {
            ZStack {
                cluster.category.style.baseColor
                if let name = cluster.photoFileNames.first {
                    // **One width for every block on the map**, whatever size
                    // it draws at. `CachedImageView` keys its cache on the
                    // requested width, so asking for 88 at one zoom and 176 at
                    // the next decodes the same photograph twice and re-decodes
                    // it on every zoom step.
                    CachedImageView(fileName: name,
                                    width: Self.cell * 2,
                                    height: Self.cell * 2,
                                    cornerRadius: 0)
                        .frame(width: size.width, height: size.height)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .overlay(alignment: .bottomLeading) {
            // How much you did there. Where the month tower puts its day
            // number, in the same face.
            Text("\(cluster.winCount)")
                .font(Typography.numeral(Self.cell * 0.20))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
                .padding(Self.cell * 0.12)
                .accessibilityHidden(true)
        }
        .accessibilityLabel("\(cluster.winCount) \(cluster.winCount == 1 ? "win" : "wins") here")
    }
}

private extension View {
    /// The prime's own capsule. Not a block: CLAUDE.md is explicit that a rim,
    /// a frosted band or a blurred edge is a block's claim, and a button is
    /// not a block.
    @ViewBuilder
    func mapPrimeGlass() -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            self.background(.ultraThinMaterial, in: Capsule())
        }
    }
}
