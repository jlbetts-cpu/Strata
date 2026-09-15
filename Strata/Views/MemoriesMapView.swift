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
    /// Whether the pins have been read. The empty state waits for it: the
    /// view is drawn before the store is read, so for that first moment no
    /// pins is not an empty map, and every open of Memories flashed "Your map
    /// starts here" over a map about to fill with photographs.
    var hasLoaded: Bool = true
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
    /// The scale the blocks were last laid out at, in quarter-zoom steps. See
    /// `PlaceMap.cluster(_:step:)`: whether two places are one block depends
    /// on how big their blocks are on screen, so this is measured from the
    /// camera exactly rather than rounded to a grid.
    @State private var step: Int = PlaceMap.step(zoom: 12)
    @State private var viewportWidth: CGFloat = 393
    /// What is on screen right now, with the coordinate each block is drawn
    /// at — which is not always where its cluster is. During a merge a block
    /// sits at the point it is travelling to. See `apply(_:)`.
    @State private var displayed: [Placed] = []
    @State private var didFrame = false

    /// **One clock for every block on the map.**
    ///
    /// A place with several photographs shows them in turn — the owner's
    /// call: "multiple photos in the same spot should just become a bundle you
    /// can click on... keep it in one bundle cycling through." But CLAUDE.md
    /// is explicit that the month tower's approach must NOT be reused here: a
    /// long-lived task per block, thirty of them crossfading while MapKit
    /// relays annotations every frame, is both a wall that blinks and the
    /// frame budget gone.
    ///
    /// So there is one task and one integer. Each block offsets it by a stable
    /// hash of its own id, so nothing changes in unison — a wall that blinks
    /// together reads as an alert — and the map pays for one timer rather
    /// than one per place.
    @State private var tick = 0
    /// When the camera last came to rest, so the pictures hold still around a
    /// move rather than changing in the middle of one.
    @State private var lastCameraMove = Date.distantPast
    /// How long a photograph stays up before the next one in its place. Was
    /// four seconds, which on a map of a dozen places is something changing
    /// every third of a second somewhere on screen.
    private static let cycleSeconds: Double = 7
    /// And how long after a camera move before any of them change.
    private static let cycleSettle: Double = 2.5
    /// Whether the first fill has happened. After it, blocks arriving are
    /// arriving because you moved the map, and they travel instead.
    @State private var hasSettled = false
    /// The blocks the last zoom brought in, which are the only ones that fade
    /// in. See `apply(_:from:to:)`.
    @State private var justArrived: Set<String> = []
    /// The photograph each arriving block opens on, when it holds one an old
    /// block on screen was showing. See `apply(_:from:to:)`.
    @State private var carry: [String: String] = [:]
    /// Which change a clean-up belongs to, so a late one cannot remove what a
    /// newer zoom has just put down.
    @State private var generation = 0
    /// Which blocks MapKit is drawing right now, as the blocks report it.
    ///
    /// A reference, not observed state: it changes every time a block scrolls
    /// on or off the screen, and redrawing the map for each of those would be
    /// the per-frame work the rest of this file is careful to avoid. It is
    /// only read at the moment a zoom is applied.
    final class DrawnBlocks { var ids: Set<String> = [] }
    @State private var drawn = DrawnBlocks()
    /// Observed, so the empty state follows the answer to its own prompt
    /// rather than waiting for the screen to be opened again.
    ///
    /// `@State`, not a plain stored property: a stored `private` property
    /// joins the memberwise initializer and makes the whole init private,
    /// which stops every caller constructing this view.
    @State private var location = LocationService.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

        /// At rest, a block stands on its leading place — see `Cluster.anchor`.
        static func atRest(_ cluster: PlaceMap.Cluster) -> Placed {
            Placed(cluster: cluster,
                   latitude: cluster.anchor.latitude,
                   longitude: cluster.anchor.longitude)
        }
    }


    var body: some View {
        #if DEBUG
        let _ = PerfProbe.count("MemoriesMapView")
        #endif
        return map
            .overlay { if hasLoaded && pins.isEmpty { emptyState } }
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
                        accessibilityLabel: "Show my location") {
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
            //
            // **Or your head**, when you have made one and switched it on in
            // Profile — never by default. Anchored at the bottom, so the
            // coordinate is where the head is standing rather than its nose.
            // Custom `UserAnnotation` content is not tappable; nothing needs
            // it to be, the recentre button already does that job.
            ForEach(displayed) { placed in
                Annotation("", coordinate: placed.coordinate, anchor: .center) {
                    block(for: placed)
                }
                .annotationTitles(.hidden)
            }

            // **Last, so it is never underneath a block.** Annotations are
            // drawn in the order they are declared, and this one used to be
            // declared first: stand where you have already photographed
            // something and the marker for where you are went behind the
            // picture of where you were. A player marker is the one thing on
            // a map that is always on top.
            if showsUser {
                if let head = HeadStore.shared.headForMap {
                    UserAnnotation(anchor: .bottom) { HeadMarker(head: head) }
                } else {
                    UserAnnotation()
                }
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
            lastCameraMove = Date()
            let span = context.region.span.longitudeDelta
            zoom = PlaceMap.zoomLevel(spanLongitude: span, viewportWidth: Double(viewportWidth))
            let next = PlaceMap.step(pointsPerUnit: PlaceMap.pointsPerUnit(
                spanLongitude: span, viewportWidth: Double(viewportWidth)))
            guard next != step else { return }
            let previous = step
            step = next
            apply(PlaceMap.cluster(pins, step: next), from: previous, to: next)
        }
        // The map's one clock. Stops itself when there is nothing to cycle and
        // never runs under Reduce Motion.
        .task(id: pins.count) {
            guard !reduceMotion, pins.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.cycleSeconds))
                guard !Task.isCancelled else { return }
                // **Not while the map is moving, and not straight after.**
                // Blocks travelling, merging and changing picture at the same
                // moment is three things asking for attention at once: "the
                // cycle like every zoom and everything feels too much."
                guard Date().timeIntervalSince(lastCameraMove) > Self.cycleSettle else { continue }
                tick &+= 1
            }
        }
        .task(id: pins.count) {
            displayed = PlaceMap.cluster(pins, step: step).map { Placed.atRest($0) }
            // **Only a fill with something in it settles the map.** The map is
            // drawn before the store is read, so the first pass has no pins;
            // settling on that meant the real blocks, a moment later, counted
            // as already there and appeared at full strength as grey squares
            // before their photographs. Filmed: a fifth of a second of them.
            guard !pins.isEmpty else { return }
            frameOnYourPlaces()
            // Long enough for the stagger above to finish, so the NEXT change
            // is treated as a move rather than as a first fill.
            try? await Task.sleep(for: .milliseconds(600))
            hasSettled = true
        }
    }

    // MARK: - Merging and splitting

    /// Moves from one set of blocks to another as the zoom changes.
    ///
    /// **Every block is in its own place from the moment it is on screen,
    /// and the picture you were looking at does not go anywhere.** The owner,
    /// from a phone: "the animations of the map photos moving doesnt make
    /// sense they come from nowhere they should always feel like they are in
    /// their area the second its there on the screen and the animations need
    /// to be more smooth."
    ///
    /// What was doing it, each found by filming the simulator at twenty frames
    /// a second:
    ///
    /// - A split set the new blocks on their parent and slid them out, but
    ///   both positions landed in one update, so the parent's point was never
    ///   drawn and they appeared mid-slide from nowhere.
    /// - Every block MapKit brought onto the screen sprang in from 82% and
    ///   invisible, because arriving was tied to its view appearing, and MapKit
    ///   makes that view when the block scrolls into sight. A block that had
    ///   been in place all along arrived again every time you moved.
    /// - Blocks being replaced were kept to fade or travel, and MapKit keeps
    ///   views for blocks just past the screen's edge too: as the zoom settled
    ///   those came into view already half-faded, as grey squares with no
    ///   photograph decoded, drifting into their joins. Each annotation also
    ///   draws in a hosting view of its own that the map's animation does not
    ///   reach, which is how one attempt emptied the whole map for a frame.
    ///
    /// So nothing is kept to leave. The new set replaces the old on one frame,
    /// and the continuity is in the pictures: **a block that holds the
    /// photograph an old block on screen was showing opens on that photograph**,
    /// already decoded, so zooming out the picture you were looking at is now
    /// the joined block, and zooming in it stays with the block it belongs to.
    /// Only a block with nothing on screen to carry on fades in, once its own
    /// picture is ready. Anything merely scrolled into view is simply there.
    private func apply(_ next: [PlaceMap.Cluster], from old: Int, to new: Int) {
        let onScreen = drawn.ids
        // What each block on screen is showing right now, biggest first, so a
        // join carries the picture of the place that holds the most.
        let shown: [String] = displayed
            .filter { onScreen.contains($0.id) }
            .sorted { $0.cluster.winCount > $1.cluster.winCount }
            .compactMap { PlaceBlock.showing(for: $0.cluster, tick: tick) }
        var claimed = Set<String>()
        var carried: [String: String] = [:]
        for cluster in next {
            let holds = Set(cluster.photoFileNames)
            if let picture = shown.first(where: { holds.contains($0) && !claimed.contains($0) }) {
                carried[cluster.id] = picture
                claimed.insert(picture)
            }
        }
        let presentIDs = Set(displayed.map(\.id))
        let nextIDs = Set(next.map(\.id))
        carry = carried
        justArrived = Set(next.lazy.filter { !presentIDs.contains($0.id) && carried[$0.id] == nil }.map(\.id))
        // **Held for a moment, unmoved, then gone.** MapKit adds a new
        // annotation's view a frame or two after it removes an old one, so a
        // swap on one frame showed an empty map for a frame. The blocks you
        // could see stay exactly as they are — not fading, not travelling —
        // until the new ones have had time to be drawn over them.
        let held = displayed.filter { onScreen.contains($0.id) && !nextIDs.contains($0.id) }
        generation &+= 1
        let current = generation
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { displayed = held + next.map { Placed.atRest($0) } }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(110))
            guard generation == current else { return }
            withTransaction(instant) { displayed.removeAll { !nextIDs.contains($0.id) } }
        }
    }

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
                 : "Photos you take in Strata keep the place they were taken, and land here.")
                .font(Typography.screenSubtitle)
                .foregroundStyle(AppColors.onDarkSecondary)
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
                // It was white type with a `contentShape` and no fill — a
                // button-shaped hit area with nothing to press. On a map, of
                // all grounds, invisible chrome is the one thing that cannot
                // work.
                Text(denied ? "Open Settings" : "Turn On Places")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(AppColors.warmBlack)
                    .padding(.horizontal, 22)
                    .frame(height: 46)
                    .background(Capsule().fill(AppColors.onDarkStrong))
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
            let z = PlaceMap.step(pointsPerUnit: PlaceMap.pointsPerUnit(
                spanLongitude: span, viewportWidth: Double(viewportWidth)))
            let found = PlaceMap.cluster(pins, step: z)
            NSLog("[strata-probe] mapSweep span=\(span) step=\(z) "
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
                   arrives: !hasSettled || justArrived.contains(placed.id),
                   carry: carry[placed.id],
                   delay: arrivalDelay(for: placed),
                   // A count wherever a block stands for more than one
                   // photograph, not only when zoomed out: "just have the
                   // number of photos if its in the relitive same area".
                   tick: tick,
                   showsCount: placed.cluster.winCount > 1,
                   drawn: drawn)
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
    /// Marks a photograph that lives in the asset catalogue rather than in the
    /// user's image directory. Only onboarding uses it.
    /// What a block shows for the moment before its photograph decodes.
    ///
    /// **A fixed neutral, not an ink.** This was `AppColors.inkQuiet`, which
    /// is a token for TEXT and inverts with the scheme — 45% black in light,
    /// 55% WHITE in dark. On a dark map that made a block flash pale before
    /// its picture arrived, which is a worse thing to look at than the
    /// category colour it replaced. An ink is not a surface, and using one as
    /// a fill is how that inversion sneaks in.
    ///
    /// One warm grey in both schemes: quiet against the pale tiles and
    /// against the satellite ones, and close enough to the average photograph
    /// that the handover is not a step.
    static let waitingFill = Color(hex: 0x7A736D)

    static let bundledPrefix = "bundle:"

    let cluster: PlaceMap.Cluster
    /// Whether it fades in at all. Only for the first fill and for blocks a
    /// zoom brought in; a block MapKit draws because you scrolled to it has
    /// been in its place the whole time. See `MemoriesMapView.apply`.
    var arrives: Bool = true
    /// The photograph to open on: one an old block on screen was just
    /// showing, so the picture carries on instead of starting again.
    var carry: String? = nil

    /// How long to wait before arriving — see `arrivalDelay(for:)`.
    var delay: Double = 0

    /// The map's shared clock — see `MemoriesMapView.tick`.
    var tick: Int = 0

    /// Which of this place's photographs is showing.
    ///
    /// Offset by a stable hash of the cluster's id, so two blocks side by side
    /// are never on the same frame of the same beat. `id` is `z/x/y`, which
    /// does not change as photographs join, so a block does not jump to a
    /// different picture just because a new one arrived.
    private var showing: String? { Self.showing(for: cluster, tick: tick) }

    /// Which photograph a block shows on a beat of the map's clock. Static so
    /// the map can ask what a block on screen is showing without reaching
    /// into it.
    static func showing(for cluster: PlaceMap.Cluster, tick: Int) -> String? {
        let names = cluster.photoFileNames
        guard !names.isEmpty else { return nil }
        guard names.count > 1 else { return names[0] }
        let offset = abs(cluster.id.hashValue % names.count)
        return names[(tick &+ offset) % names.count]
    }

    /// One frame of the slideshow, bundled or on disk.
    ///
    /// **A bundled photograph, for the onboarding map.** Onboarding shows a
    /// real map with real clustering, and its blocks have to carry real
    /// pictures — a map of flat colour squares does not make the case that
    /// your photographs land where you took them. Those ship in the asset
    /// catalogue rather than the image directory, so a name with this prefix
    /// is drawn straight from the bundle. Nothing the app writes starts with
    /// it.
    @ViewBuilder
    private func picture(_ name: String, in size: CGSize) -> some View {
        if name.hasPrefix(Self.bundledPrefix) {
            Image(String(name.dropFirst(Self.bundledPrefix.count)))
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
        } else if !name.isEmpty {
            // **The size it is actually drawn at**, which is one of two
            // numbers and no more: a lone win keeps the size a finger drew,
            // and every crowd is one cell. Asking for 88 for everything meant
            // a 2x2 block drew an 88pt picture across 90pt at 3x — soft, and
            // the owner saw it: "the photos dont even zoom in."
            //
            // Two widths is also why this is safe. `CachedImageView` keys its
            // cache on the requested width, and a block's size no longer
            // changes with the camera, so nothing re-decodes as you zoom.
            CachedImageView(fileName: name,
                            width: size.width,
                            height: size.height,
                            cornerRadius: 0,
                            showsPlaceholder: false,
                            decodeWidth: Self.decodeWidth)
                .frame(width: size.width, height: size.height)
                // See `FlippableBlockView`: a hair of overscan, so the colour
                // behind cannot show at a rounded corner.
                .scaleEffect(1.03)
        }
        // A name that is empty is not a photograph. Without that guard
        // `CachedImageView` draws its missing-file placeholder — a
        // broken-picture glyph on the block — which is worse than the colour
        // alone, and was visible on the onboarding map.
    }

    /// Bring the next photograph up over the one showing, then swap.
    ///
    /// No per-block `Task`: CLAUDE.md is explicit that thirty long-lived
    /// cycling tasks while MapKit relays annotations every frame is a wall
    /// that blinks and a frame budget gone. The shared `tick` decides WHEN,
    /// and this only decides HOW — with a completion rather than a sleep, so
    /// nothing is left running between beats.
    ///
    /// **Only to a photograph that is already there.** The owner, from a
    /// phone: on zoom out "the photos arent even loaded so it just shows up as
    /// a grey box. find a way that the photo always can stay and casually
    /// change." A handover to a picture still being read used to fade in the
    /// grey that stands in for it. Now the photograph showing stays until the
    /// next one has been read — which the block asks for a beat early, see
    /// `upcoming` — and only then crossfades.
    private func handover(to arriving: String?) {
        guard let arriving, arriving != base else { return }
        guard isDecoded(arriving) else { waitingFor = arriving; return }
        waitingFor = nil
        guard !reduceMotion else { base = arriving; return }
        top = arriving
        topOpacity = 0
        withAnimation(GridConstants.crossFade) {
            topOpacity = 1
        } completion: {
            base = arriving
            top = nil
            topOpacity = 0
        }
    }

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

    /// **One size of photograph for every block on the map.** A block
    /// changes size as you zoom — a lone place wears the size its win was
    /// drawn at, a crowd is one cell — and each size used to ask for its own
    /// decode, so a block that had just shown its picture went grey while
    /// the picture was made again at the new width. Decoded once at the
    /// largest a block can be, every size after that is already in memory.
    static let decodeWidth: CGFloat = cell * 2 + cell * GridConstants.spacing / GridConstants.blockReferenceCell

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

    @State private var arrived: Bool
    /// **Two slots, not one.** The picture underneath is always fully opaque
    /// and the incoming one fades in on top of it. A single slot with
    /// `.transition(.opacity)` crossfades symmetrically: both copies pass
    /// through partial alpha at the same moment, the pair composites to 0.75
    /// alpha, and the block's flat colour shows through the middle of every
    /// handover. The owner, on a device: "the photos cycling through I dont
    /// like how its not clean it shows the colored block behind it."
    ///
    /// The comment that used to sit on the transition argued this was safe
    /// "because both layers are opaque photographs". Two opaque layers at 50%
    /// do not composite to an opaque result, which is the whole of the bug,
    /// and it is the same mistake `BlockSurface` records about its own two
    /// masked copies.
    @State private var base: String?
    @State private var top: String?
    /// A photograph a handover is waiting on, still being read.
    @State private var waitingFor: String?
    @State private var topOpacity: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Where it says it is being drawn. See `MemoriesMapView.DrawnBlocks`.
    var drawn: MemoriesMapView.DrawnBlocks?

    init(cluster: PlaceMap.Cluster, arrives: Bool = true, carry: String? = nil,
         delay: Double = 0, tick: Int = 0, showsCount: Bool = false,
         drawn: MemoriesMapView.DrawnBlocks? = nil) {
        self.cluster = cluster
        self.drawn = drawn
        self.arrives = arrives
        self.carry = carry
        _base = State(initialValue: carry)
        self.delay = delay
        self.tick = tick
        self.showsCount = showsCount
        // Decided when the view is made, which is when MapKit brings the block
        // on screen: one that is not arriving is drawn in full on its first
        // frame, with nothing to animate from.
        _arrived = State(initialValue: !arrives)
    }

    var body: some View {
        block
            .onAppear {
                // **Open on something that is already there.** If the picture
                // this beat asks for is still being read, a picture of the
                // same place that is not goes up instead, and the handover
                // brings the asked-for one in once it lands.
                if base == nil {
                    let ready = cluster.photoFileNames.first(where: isDecoded)
                    base = showing.map { isDecoded($0) ? $0 : (ready ?? $0) }
                    if base != showing { handover(to: showing) }
                }
            }
            .onChange(of: waitingIsReady) { _, ready in
                if ready, let name = waitingFor { handover(to: name) }
            }
            // Read the next beat's photograph ahead of time.
            .task(id: upcoming) { if let upcoming { _ = isDecoded(upcoming) } }
            .onChange(of: showing) { _, arriving in handover(to: arriving) }
            // **It arrives, gently.** Twenty blocks switching on at once is a
            // map being drawn; twenty blocks landing is a map filling in. A
            // short ease from nearly full size, where it will stand — it was a
            // spring from 0.82 that overshot, which read as bouncing into
            // place from somewhere else.
            .scaleEffect(arrived || reduceMotion ? 1 : 0.94)
            .opacity(arrived || reduceMotion ? 1 : 0)
            .onAppear {
                drawn?.ids.insert(cluster.id)
                guard !arrived else { return }
                guard !reduceMotion else { arrived = true; return }
                if pictureReady { arrive() } else { waitForPicture() }
            }
            .onDisappear { drawn?.ids.remove(cluster.id) }
            .onChange(of: pictureReady) { _, ready in
                if ready, !arrived, !reduceMotion { arrive() }
            }
    }

    @Environment(\.displayScale) private var displayScale

    /// **A block arrives with its photograph, not before it.** A block that
    /// faded in ahead of its picture faded in as a grey square and then
    /// changed into a photograph, which is two arrivals. Filmed on a zoom out:
    /// two grey squares for a sixth of a second each.
    private var pictureReady: Bool {
        guard let name = base ?? showing else { return true }
        return isDecoded(name)
    }

    /// Whether a photograph is in memory at the map's size. Asking also starts
    /// reading it if it is not, which is what makes this a preload.
    private func isDecoded(_ name: String) -> Bool {
        guard !name.hasPrefix(Self.bundledPrefix) else { return true }
        return ThumbnailStore.shared.state(for: name, width: Self.decodeWidth * displayScale).image != nil
    }

    /// The photograph the next beat of the clock will ask for, read ahead so
    /// it is ready by the time it is due.
    private var upcoming: String? { Self.showing(for: cluster, tick: tick &+ 1) }

    /// Whether the photograph a handover is waiting on has now been read.
    private var waitingIsReady: Bool { waitingFor.map(isDecoded) ?? false }

    private func arrive() {
        withAnimation(GridConstants.mapFade.delay(delay)) { arrived = true }
    }

    /// A picture that cannot be read still needs its block, so the wait has
    /// a limit.
    private func waitForPicture() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            if !arrived { arrive() }
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
                // **No category colour under a photograph.**
                //
                // A block on the tower is its colour — that is what a win with
                // no category picks one for. A block on the MAP stands for a
                // place, usually holding several wins of several categories,
                // so the colour is not a fact about it: whichever category
                // happened to dominate. And it was visible, at the edges and
                // for an instant before a picture decoded, which is what it
                // looked like going wrong: "the color of the block still is
                // there when it glitches out it shouldnt even be on the maps
                // blocks whats the point of the color."
                //
                // A place with no photograph still needs a body, and there the
                // colour is the only thing there is. Everywhere else it is a
                // neutral that nobody can mistake for meaning.
                if cluster.photoFileNames.isEmpty {
                    cluster.category.style.baseColor
                } else {
                    Self.waitingFill
                }
                // **A bundled photograph, for the onboarding map.**
                //
                // Onboarding shows a real map with real clustering, and its
                // blocks have to carry real pictures — a map of flat colour
                // squares does not make the case that your photographs land
                // where you took them. Those pictures ship in the asset
                // catalogue rather than in the image directory, so a name with
                // this prefix is drawn straight from the bundle. Nothing the
                // app writes ever starts with it.
                if let base { picture(base, in: size) }
                if let top { picture(top, in: size).opacity(topOpacity) }
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
            .padding(.horizontal, GridConstants.gapTight)
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
