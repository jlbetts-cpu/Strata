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
        /// **Apple's dark palette, warmed by our own scrim.**
        ///
        /// MapKit cannot be recoloured — there is no palette API and there
        /// never has been. But it HAS two palettes, and only one of them was
        /// ever tried: the map renders light or dark from the environment's
        /// colour scheme, so forcing `.dark` on the map alone is a real second
        /// ground rather than the same one tinted. On it the app's warm scrim
        /// actually bites, because it is darkening something already dark
        /// instead of greying something pale.
        case night
    }

    @State private var camera: MapCameraPosition = .automatic
    @State private var zoom: Int = 12
    @State private var viewportWidth: CGFloat = 393
    /// What is on screen right now, with the coordinate each block is drawn
    /// at — which is not always where its cluster is. During a merge a block
    /// sits at the point it is travelling to. See `apply(_:)`.
    @State private var displayed: [Placed] = []
    @State private var didFrame = false
    /// Whether the first fill has happened. After it, blocks arriving are
    /// arriving because you moved the map, and they travel instead.
    @State private var hasSettled = false
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


    var body: some View {
        map
            .overlay { if pins.isEmpty { emptyState } }
            .overlay(alignment: .bottomTrailing) { if isInteractive { recentre } }
            #if DEBUG
            // **The map's zoom, readable from outside.**
            //
            // Pinch is the one gesture on this screen that cannot be checked by
            // screenshot — the tiles change but so do they on a pan, and the
            // block count changes only when the integer zoom does. XCUITest can
            // pinch for real; it just needs something to read. This publishes
            // the zoom as an accessibility value on a zero-size element, so it
            // costs nothing and shows nothing.
            .overlay(alignment: .topLeading) {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityIdentifier("MapZoomProbe")
                    .accessibilityLabel("zoom \(zoom)")
            }
            #endif
    }

    /// Take me back to where I am.
    ///
    /// **Not `MapUserLocationButton`.** That is the native control and it is
    /// the right idea, but it is styled by MapKit, placed by MapKit, and it
    /// shows a blue system chevron in a system capsule — three things this
    /// screen has spent its whole life not doing. This is the app's own glass
    /// button, the same one the title row uses, in the place Apple Maps puts
    /// it: bottom trailing, above the tab bar, where a thumb already is.
    ///
    /// It is the FOURTH piece of chrome on a screen aiming for three, and it
    /// earns the slot because it is the only one that answers a question the
    /// map itself raises. Once you have panned away from yourself there is
    /// otherwise no way back except pinching until the world fits.
    private var recentre: some View {
        GlassIconButton(systemName: locationGlyph,
                        accessibilityLabel: "Back to where I am") {
            goToMe()
        }
        // Light in both appearances — see `MemoriesView.overMap`. Glass
        // follows the system, and a dark disc on the night map is invisible.
        .environment(\.colorScheme, .light)
        .padding(.trailing, GridConstants.horizontalPadding)
        .padding(.bottom, DrawerMetrics.tabBarClearance)
        // It has nothing to say until it can say it.
        .opacity(location.isDenied ? 0 : 1)
        .allowsHitTesting(!location.isDenied)
        .animation(GridConstants.gentleReveal, value: location.isDenied)
    }

    /// Filled once we know where you are, hollow while we do not — the same
    /// grammar the system uses, so it needs no explaining.
    private var locationGlyph: String {
        location.fix(maxAge: 600, maxAccuracy: 1000) == nil
            ? "location" : "location.fill"
    }

    /// Frame on the user, or ask if we have never asked.
    ///
    /// Falls back to their own places rather than doing nothing: "I pressed it
    /// and the map sat there" is the worst outcome, and the second-best answer
    /// to "where am I" is "here is everywhere you have been".
    private func goToMe() {
        guard !location.canAsk else {
            location.requestAccess()
            location.start()
            return
        }
        location.start()
        guard let fix = location.fix(maxAge: 600, maxAccuracy: 1000) else {
            didFrame = false
            frameOnYourPlaces()
            return
        }
        withAnimation(GridConstants.naturalSettle) {
            camera = .region(MKCoordinateRegion(
                center: fix.coordinate,
                // A few streets: close enough that the labels are up and a
                // block means "this corner" rather than "this city".
                span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
            ))
        }
    }

    private var map: some View {
        Map(position: $camera, interactionModes: isInteractive ? .all : []) {
            // **Where you are.** The map had no indicator for the one place
            // every map has one for, which made "back to where I am" a button
            // that took you somewhere unmarked. It is Apple's own dot, not a
            // drawing of ours: a blue pulsing disc is a convention older than
            // this app and reproducing it in the app's own idiom would be
            // making a landmark out of something whose whole value is that it
            // needs no explaining.
            //
            // Only once there is something to show. `UserAnnotation` with no
            // authorization draws nothing anyway, but asking for it here
            // rather than checking would start the "which screen asks" loop
            // the empty state already answers.
            if showsUser { UserAnnotation() }

            ForEach(displayed) { placed in
                Annotation("", coordinate: placed.coordinate, anchor: .center) {
                    block(for: placed)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(mapStyle)
        .mapControls { }
        // The one thing that changes MapKit's palette. Scoped to the map.
        .environment(\.colorScheme, style == .night ? .dark : .light)
        // **The one place the app takes stock blue back.**
        //
        // `UserAnnotation` is tinted from the environment, so it inherited
        // `AppColors.accentWarm` and rendered as a near-black disc — which on
        // a pale map reads as a hole in it, not as you. CLAUDE.md's rule that
        // stock sky blue is where every "this looks like default iOS"
        // complaint came from is about CHROME: tab bars, menu labels, links.
        // The blue location dot is not chrome, it is a convention older than
        // this app and shared by every map anybody has ever used, and its
        // whole value is that it needs no explaining. Scoped to the map, so
        // nothing else inherits it.
        .tint(.blue)
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
            displayed = PlaceMap.cluster(pins, zoom: zoom).map { Placed.atRest($0) }
            frameOnYourPlaces()
            // Long enough for the stagger above to finish, so the NEXT change
            // is treated as a move rather than as a first fill.
            try? await Task.sleep(for: .milliseconds(600))
            hasSettled = true
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
            withAnimation(GridConstants.mapTravel) { displayed = moved }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(GridConstants.mapTravelDuration))
                guard zoom == new else { return }
                withAnimation(GridConstants.mapArrive) {
                    displayed = next.map { Placed.atRest($0) }
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
            withAnimation(GridConstants.mapTravel) {
                displayed = next.map { Placed.atRest($0) }
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
        guard !didFrame else { return }
        // **An empty map still opens somewhere.**
        //
        // With no placed wins this returned early and left the camera at
        // `.automatic`, which is the whole planet — so the one person who most
        // needs the map to look like a place, somebody on their first day,
        // got a picture of the Earth. If we know where they are, that is where
        // it opens.
        guard !pins.isEmpty else {
            if let fix = location.fix(maxAge: 900, maxAccuracy: 2000) {
                didFrame = true
                camera = .region(MKCoordinateRegion(
                    center: fix.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                ))
            }
            return
        }
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
                 : "Photos you take from now on remember where you were. The ones you already have don't, and that isn't something we can go back and add.")
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

    /// One block on the map.
    ///
    /// Extracted from the `Annotation` closure, not for tidiness: with it
    /// inline, `map` hit "unable to type-check this expression in reasonable
    /// time". `MainAppView` records the same ceiling and the same fix.
    private func block(for placed: Placed) -> some View {
        // The count only when the block is standing for a whole area rather
        // than for one place — see `PlaceBlock`.
        PlaceBlock(cluster: placed.cluster,
                   delay: arrivalDelay(for: placed),
                   showsCount: !isClose)
            .onTapGesture { onSelect(placed.cluster.key) }
    }

    /// How long a block waits before arriving.
    ///
    /// **A stagger, not a cascade.** The map fills in from the middle outwards
    /// over about a quarter of a second — enough that twenty blocks read as
    /// arriving rather than as being switched on, and short enough that the
    /// last one is not still moving by the time your eye reaches it. Ordered
    /// by distance from the centre of the screen, because that is the order
    /// somebody actually looks at a map in.
    ///
    /// Zero once the map has settled: a block appearing because you zoomed has
    /// already travelled from its parent, and a delay on top of that is two
    /// animations arguing about the same object.
    private func arrivalDelay(for placed: Placed) -> Double {
        guard !hasSettled else { return 0 }
        guard let index = displayed.firstIndex(where: { $0.id == placed.id }) else { return 0 }
        return min(Double(index) * 0.018, 0.26)
    }

    /// Whether iOS will actually give us a position to draw.
    private var showsUser: Bool {
        !location.isDenied && !location.canAsk
    }

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
        case .night:
            return .standard(elevation: .flat,
                             emphasis: isClose ? .automatic : .muted,
                             pointsOfInterest: isClose
                                 ? .including(Self.worthNaming)
                                 : .excludingAll,
                             showsTraffic: false)
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
        case .night: return isClose ? 0.10 : 0.20
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

    /// How long to wait before arriving — see `arrivalDelay(for:)`.
    var delay: Double = 0

    /// Whether to say how many wins are in here.
    ///
    /// **Only when zoomed out**, and the two owner calls that look opposite
    /// are not. "Why is there numbers on it, it should just be the pictures"
    /// was about a block that stands for ONE place: there the photograph is
    /// the answer and a number on it is noise. "There should be a number
    /// indicator of how many wins are in that area when you are zoomed out"
    /// is about a block that stands for a whole neighbourhood, where the
    /// photograph is one of forty and the only honest thing it can say is how
    /// many it is speaking for.
    ///
    /// The line between them is the same one the labels use: at
    /// `labelZoom` the map is a neighbourhood and a block is a corner;
    /// below it the map is a region and a block is an area.
    var showsCount = false

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

    @State private var arrived = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        block
            // **It arrives.** Twenty blocks switching on at once is a map
            // being drawn; twenty blocks landing is a map filling in. Scale
            // from 0.82 rather than from nothing, so it reads as coming
            // towards you rather than growing out of the ground.
            .scaleEffect(arrived || reduceMotion ? 1 : 0.82)
            .opacity(arrived || reduceMotion ? 1 : 0)
            .onAppear {
                guard !reduceMotion else { arrived = true; return }
                withAnimation(GridConstants.cascadeReveal.delay(delay)) { arrived = true }
            }
    }

    private var block: some View {
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
        .overlay(alignment: .topTrailing) {
            if showsCount && cluster.winCount > 1 {
                countBadge
                    // It belongs to the block, so it arrives out of the
                    // block's own corner rather than fading in over it.
                    .transition(.scale(scale: 0.4, anchor: .topTrailing)
                        .combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : GridConstants.gentleReveal, value: showsCount)
        .accessibilityLabel("\(cluster.winCount) \(cluster.winCount == 1 ? "win" : "wins") here")
    }
}

extension PlaceBlock {
    /// The badge's two colours, fixed in both appearances — see `countBadge`.
    static let badgeDisc = Color(red: 0.975, green: 0.978, blue: 0.984)
    static let badgeInk = AppColors.warmBlack

    /// How many wins are in this area.
    ///
    /// **The owner's own digits, on the app's own black.** `Typography.numeral`
    /// is `StrataNumerals` — the same face the tower's tally and the month
    /// blocks' day numbers are set in — so a count on the map is the same kind
    /// of object as every other number the app states about you.
    ///
    /// It is a badge rather than a numeral laid on the photograph, and that is
    /// the difference from the version that was removed. On the month tower a
    /// numeral sits directly on the block because it is that block's
    /// coordinate and belongs to it. This is a count OF blocks — it is about
    /// the pile, not about the picture under it — so it sits on its own
    /// ground, clear of the image, the way a badge does.
    ///
    /// Not a rim, not a frosted band, no blur: CLAUDE.md is explicit that
    /// those are a block's claim, and a badge is not a block.
    var countBadge: some View {
        Text("\(cluster.winCount)")
            .font(Typography.numeral(13))
            // **Light disc, dark numeral** — the owner's call, and it is the
            // right way round. A dark badge on a saturated block is a second
            // dark object competing with the photograph; a light one reads as
            // a label ON the block, the way every other count in the app is
            // ink on the app's own ground rather than a hole punched in it.
            // **Fixed, in both appearances.** The badge does not sit on the
            // page, it sits on a BLOCK — a saturated blue or orange that is
            // the same colour whatever the phone is set to. So the thing that
            // decides its contrast never flips, and neither should it. Made
            // adaptive it went dark-on-dark in dark mode, which is the badge
            // following a ground it is not actually standing on.
            .foregroundStyle(Self.badgeInk)
            .monospacedDigit()
            .padding(.horizontal, 7)
            .frame(minWidth: 24, minHeight: 22)
            .background {
                Capsule().fill(Self.badgeDisc)
            }
            // Just off the corner, so it reads as attached to the block rather
            // than as part of the photograph.
            .offset(x: 8, y: -8)
            .accessibilityHidden(true)
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
