import QuartzCore
import MapKit
import SwiftUI

/// Where you have been, as blocks.
///
/// Every photographed win that knows its place, clustered into the app's own
/// object through `PlaceMap`.
///
/// **Size says nothing here, and that is now true rather than nearly true**
/// (2026-10-01). This line used to read "sized by how much you did there, the
/// same rank encoding the month tower uses", and the capture it was written
/// over disproves it: the largest block on screen was 89.0 x 89.0pt and held
/// ONE win, while the block holding 24 was 44pt. The owner has settled that a
/// crowd does not grow ("they should still stay in the same area dont need to
/// get bigger"), so the rank encoding cannot survive on this screen, and the
/// honest move was to finish the rule rather than keep half of it. Every block
/// on the map is one cell. The badge is the only thing that says how many. See
/// `PlaceMap.Cluster.size` for the three measurements that decided it.
///
/// **MapKit cannot be recoloured.** `MapStyle` offers elevation, points of
/// interest, traffic and an emphasis, and nothing else; there is no palette to
/// set. So the only levers are what to strip, and both of those are used:
/// every point of interest is excluded below `labelZoom` and the emphasis is
/// muted. Measured on the capture, that leaves the tiles at saturation 0.035
/// to 0.039 against the blocks' 0.52 to 0.86, which is the whole of "the
/// blocks are the only saturated thing on the screen". **There is no longer a
/// wash on top**, and the arithmetic that took it off is in `map`.
struct MemoriesMapView: View {
    let pins: [PlaceMap.Pin]
    /// Whether the pins have been read. The empty state waits for it: the
    /// view is drawn before the store is read, so for that first moment no
    /// pins is not an empty map, and every open of Memories flashed "Your map
    /// starts here" over a map about to fill with photographs.
    var hasLoaded: Bool = true
    /// Where the map writes the moment its camera last moved, for the
    /// Memories page's off-screen build. **A reference, not state**: it is
    /// written on every frame of a pan, and observing it would redraw the map
    /// and every annotation with the gesture.
    var motion: MapMotion? = nil
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
    /// **The two scrim rows are history, not an option** (2026-10-01). The
    /// scrim is gone; see `map`. It is worth saying what it looks like read
    /// back now: a mean luminance is a measurement of the whole frame, blocks
    /// included, so every row above that improves on a wash improves by
    /// darkening the photographs along with the tiles. The edge figures move
    /// the same way. A metric that cannot tell the content from the ground was
    /// the wrong instrument for a figure and ground question, and it is what
    /// kept a wash on this screen for a month.
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
        /// **Apple's dark palette.**
        ///
        /// MapKit cannot be recoloured — there is no palette API and there
        /// never has been. But it HAS two palettes, and only one of them was
        /// ever tried: the map renders light or dark from the environment's
        /// colour scheme, so forcing `.dark` on the map alone is a real second
        /// ground rather than the same one tinted.
        ///
        /// This used to say the warm scrim "actually bites" here, because it
        /// darkens something already dark rather than greying something pale.
        /// Measured, it is the reverse: the palette renders at mean luminance
        /// 63.6 and warmBlack is 60.7, so the 0.20 wash moved the tiles 0.6 of
        /// one level and took a photograph at 180 down to 156. It bit nothing
        /// but the blocks. See `map`.
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
    #if DEBUG
    @State private var debugOpenWindowed = false
    @State private var debugSweepStarted = false
    #endif
    @State private var drawn = DrawnBlocks()
    /// Observed, so the empty state follows the answer to its own prompt
    /// rather than waiting for the screen to be opened again.
    ///
    /// `@State`, not a plain stored property: a stored `private` property
    /// joins the memberwise initializer and makes the whole init private,
    /// which stops every caller constructing this view.
    @State private var location = LocationService.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// For the empty state's hairline, which is one device pixel rather than
    /// a point. Read here rather than inside the panel helper: a `View`
    /// extension has no environment of its own to read it from.
    @Environment(\.displayScale) private var displayScale

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
            .overlay(alignment: .bottomTrailing) {
                if isInteractive {
                    RecentreButton(location: location, night: style == .night) { goToMe() }
                }
            }
            // The recentre button starts location; leaving the map ends it.
            .onDisappear { location.stop(for: Self.locationHolder) }
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

    /// Frame on the user, or ask if we have never asked.
    ///
    /// Falls back to their own places rather than doing nothing: "I pressed it
    /// and the map sat there" is the worst outcome, and the second-best answer
    /// to "where am I" is "here is everywhere you have been".
    private func goToMe() {
        guard !location.canAsk else {
            location.requestAccess()
            location.start(for: Self.locationHolder)
            return
        }
        location.start(for: Self.locationHolder)
        guard let fix = location.fix(maxAge: 600, maxAccuracy: 1000) else {
            didFrame = false
            frameOnYourPlaces()
            return
        }
        withAnimation(GridConstants.motionSnappy) {
            camera = .region(MKCoordinateRegion(
                center: fix.coordinate,
                // A few streets: close enough that the labels are up and a
                // block means "this corner" rather than "this city".
                span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
            ))
        }
    }

    private static let locationHolder = "map"

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
        // `GridConstants.tabBarClearance`, not `DrawerMetrics.tabBarClearance`,
        // which was the same number under a second name and is deleted with its
        // file (2026-10-01). It was all that was left of the drawer: one alias
        // whose only two readers were this file and the recentre button below,
        // and it outlived the drawer by a day because this file was off limits
        // to the sweep that removed the rest. Nothing is lost by the file
        // going: the two Swift traps it carried forward are written out in
        // full in CLAUDE.md under the Memories drawer. They are that static
        // STORED properties are not allowed in a generic type at all, and that
        // a type nested in a generic picks the generic up.
        .safeAreaPadding(.bottom, GridConstants.tabBarClearance - 22)
        .safeAreaPadding(.leading, 6)
        // **There is no scrim any more, and the reason is arithmetic**
        // (2026-10-01).
        //
        // A `Rectangle` filled with `warmBlack` at 0.03 to 0.34 sat here as an
        // `.overlay` on the `Map`, and its note claimed it "lets the blocks be
        // the only saturated thing on the screen". MapKit's annotations live
        // INSIDE the map, so an overlay on the map is an overlay on the blocks
        // as well. Proved off the shipping capture rather than argued: the
        // count badge's capsule is declared rgb(249, 249, 251) and rendered
        // rgb(231, 230, 232), which solves to alpha 0.097 against warmBlack.
        // That is the 0.10 the quiet ground asks for, landing in full on a
        // photograph's own chrome.
        //
        // **A uniform wash cannot raise any contrast ratio, ever.** Compositing
        // two things against one ink at alpha a takes each luminance to kL + c
        // with k = 1 - a and c = a * L(ink). Every ratio on the screen is of
        // the form (L + 0.05) over (L + 0.05), and scaling both terms down by k
        // while adding the same c to each always lands closer to 1:1 than the
        // pair it started from. Figure and ground are washed by exactly the
        // same factor, so the separation the comment promised was never
        // available from this object, on any ground, at any alpha.
        //
        // Measured on the capture, each block against the tile beside it, with
        // the scrim and then with the composite solved back off:
        //
        //     red 2x2    on pale fill   2.51 -> 2.62
        //     blue 1x1   on pale fill   2.61 -> 2.74
        //     green 1x1  on park        3.02 -> 3.19
        //     purple 2x1 on pale fill   2.28 -> 2.37
        //     orange 1x1 on pale fill   1.92 -> 1.98
        //
        // Five pairs, five losses, and the price of them was 10% of every
        // photograph's luminance. Saturation, the word the old note actually
        // used, goes the same way: the scrim moved the tiles 0.035 to 0.036 and
        // the blocks 0.534 to 0.521, so it desaturated the content thirteen
        // times harder than it desaturated the ground.
        //
        // On `.night`, the other ground that ships, it is worse than useless.
        // Apple's dark palette renders at mean luminance 63.6 and warmBlack is
        // 60.7, so a 0.20 wash moves the tiles by 0.6 of one level out of 255
        // while taking a photograph at 180 down to 156. Forty times the effect
        // on the content as on the thing it was aimed at.
        //
        // **What was tried and rejected**, in order:
        //
        // - *Keep it where the ground is loud.* `.night` is a shipping ground
        //   and is the case above. `.satellite` is reachable only through
        //   `-strataMapStyle`, so a rule kept for it is a rule that ships for
        //   nobody.
        // - *Move it under the annotations.* SwiftUI will do this: MapKit draws
        //   every overlay below every annotation, so a world-covering
        //   `MapPolygon` in the map's own content is a wash on the tiles alone.
        //   It was rejected because on a PALE map it pulls the wrong way. The
        //   blocks are darker than the tiles here, luminance 0.06 to 0.27
        //   against the ground's 0.80, so darkening only the ground moves it
        //   towards them. Measured on the red block: 2.62 with no wash at all,
        //   2.23 with a tiles-only wash at 0.10, 1.67 at 0.26. A tiles-only wash
        //   pays only where the ground is darker than the content, which is
        //   `.satellite`, which does not ship.
        // - *A gentler alpha.* The arithmetic above has no zero crossing. The
        //   best alpha is 0.
        // - *Brightening the blocks back by as much as the wash took.* A
        //   photograph cannot be un-darkened; it clips at the top. `BlockSurface`
        //   is already carrying a 0.06 wash here for a different reason.
        //
        // What does deliver the claim is already in this file and costs the
        // photographs nothing: `worthNaming` strips the points of interest and
        // the emphasis is muted below `labelZoom`. Measured on the same capture,
        // the tiles sit at saturation 0.035 to 0.039 and the blocks at 0.52 to
        // 0.86. The blocks ARE the only saturated thing on the screen, and that
        // was never the scrim's doing.
        #if DEBUG
        // **`id:`, not a bare `.task`.** A bare one runs once at appear and
        // captures the view value it had then — which is before the fetch
        // lands, so `pins` was empty and the probe dutifully reported zero
        // blocks at every zoom while the map on screen was full of them. An
        // instrument aimed at the wrong thing looks exactly like a null
        // result. Keyed on the count, it re-runs with a fresh `self`.
        .task(id: pins.count) {
            guard DebugHarness.sweepsMap, !pins.isEmpty else { return }
            // `-strataMapSweepAfter s`: start the sweep once launch has
            // settled, with every picture dropped from memory, so the
            // figure is the image pipeline's and not the launch's main-thread
            // work (the replay shelf's reload and the drawer's prebuild held
            // the main thread for seconds in the plain sweep).
            if let after = DebugHarness.argument("-strataMapSweepAfter").flatMap(Double.init) {
                guard !debugSweepStarted else { return }
                debugSweepStarted = true
                try? await Task.sleep(for: .seconds(after))
                ImageManager.shared.emptyThumbnailCacheForBenchmark()
            }
            await sweep()
        }
        // `-strataPerfProbe`: the map's first eight seconds with nobody
        // moving it, so a cold block-to-picture figure is not also a
        // measurement of the sweep's own clustering on the main thread.
        .task(id: pins.isEmpty) {
            guard PerfProbe.isOn, !pins.isEmpty, !DebugHarness.sweepsMap, !debugOpenWindowed else { return }
            debugOpenWindowed = true
            PerfProbe.window("Map open", seconds: 8)
        }
        #endif
        // **Continuous, and it writes nothing this view reads.** Noting the
        // moment the camera moved costs one assignment a frame and invalidates
        // nothing; the Memories page reads it to keep its off-screen build out
        // of a gesture. See `MapMotion`.
        .onMapCameraChange(frequency: .continuous) { _ in
            motion?.movedAt = ContinuousClock.now
        }
        // Clustering is `.onEnd`, not `.continuous`. Re-clustering every camera
        // frame both costs CPU and looks wrong — blocks twitch between two
        // cells while you pan, because the cell under a pin changes several
        // times a second.
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

    /// **Where you are, then your town, then the planet.**
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

        // **Where you are comes first, and the places arrange themselves
        // around it.**
        //
        // The owner, 2026-09-23: "when going to the maps screen it should
        // focus on where you are first, not just loose."
        //
        // It framed the bounding box of every pin, which is only the right
        // answer while your pins are all in one town. One trip and the map
        // opens on two cities and a lot of sea, which is the loose he means:
        // technically it contains everything and it shows you nothing. When
        // the phone already knows roughly where it is, that is the centre,
        // and the span is sized to the places NEAR it rather than to the
        // furthest one. The bounding box stays as the answer for when there
        // is no fix at all.
        if let fix = location.fix(maxAge: 900, maxAccuracy: 2000) {
            let here = fix.coordinate
            // How far the nearest handful of places sit from here, in
            // degrees. A place on another continent does not get a vote.
            let nearby = pins.map { pin in
                max(abs(pin.place.latitude - here.latitude),
                    abs(pin.place.longitude - here.longitude))
            }.filter { $0 < 0.6 }
            // A town if there is nothing near, widening only as far as a
            // wide city to take in the places that are.
            let reach = min(max((nearby.max() ?? 0) * 2.4, 0.03), 0.14)
            camera = .region(MKCoordinateRegion(
                center: here,
                span: MKCoordinateSpan(latitudeDelta: reach, longitudeDelta: reach)
            ))
            return
        }

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
    ///
    /// **A panel, not a darkened screen** (2026-09-23).
    ///
    /// It was a full bleed radial gradient of the app's black, 0.88 at the
    /// centre out to 0.55, with white type on it. It worked, in that you could
    /// read it, and it was the wrong object: the design language's §1 is
    /// "optimistic, bright and precise... white and light grey, not black and
    /// neon", and §8 refuses a decorative gradient laid over a page outright.
    /// A screen that turns itself dark to hold up two sentences is the
    /// opposite of a bright room.
    ///
    /// So the words stand on the app's own surface instead: translucency and a
    /// hairline (§6), the surface radius, ink from `AppColors` and nothing
    /// borrowed from the map underneath. It is the same material the recentre
    /// button and the header's buttons are made of, which is the whole point
    /// of §3, one system per screen.
    ///
    /// **It follows the scheme rather than being pinned light.** The round
    /// buttons over the map are pinned, because a 44pt disc over an IMAGE is
    /// not standing on the app's ground. A panel this size is: in dark mode
    /// the night map IS dark mode (see `MemoriesView.mapStyle`), and a bright
    /// slab in the middle of it would be the one thing on the screen that had
    /// not been told.
    @ViewBuilder
    private var emptyState: some View {
        let denied = location.isDenied
        VStack(spacing: GridConstants.gapTight) {
            Text(denied ? "Places are off" : "Your map starts here")
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.inkPrimary)

            // No measure of its own any more. The 40pt inset was holding the
            // line length down inside a panel that was the whole screen; this
            // one is the page's own width less its margins, so the panel's
            // padding is the measure.
            Text(denied
                 ? "Some Wins can't tell where a photo was taken."
                 : "Photos you take in Some Wins keep the place they were taken, and land here.")
                .font(Typography.screenSubtitle)
                .foregroundStyle(AppColors.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // **Gone, not hidden, when there is nothing left to ask.**
            //
            // The owner, on the shipped build: "the map looks odd when it's
            // waiting for a win, like it's expecting a button that's not
            // there to be there." It was: the button was dimmed to zero with
            // `.opacity`, which hid the ink and kept the height (46pt then, 50
            // now that it is `PrimaryCapsule`)
            // and its top padding, so the panel had a button shaped hole in
            // it. Opacity is for something that is still there; this one is
            // not, so it leaves the layout.
            if location.canAsk || denied {
                // **`PrimaryCapsule`, and this was the fourth private copy of
                // it** (2026-10-01, `docs/consistency-audit.md` §1.6).
                //
                // The note that stood here said this button "takes the app's own
                // primary pill: `slotInk` filled with the page's ground for a
                // label, which is what `OnboardingView.pillFill` draws on a light
                // ground and what makes this the same button as the one on the
                // onboarding page that asks the same question." **There is no
                // `pillFill` in the tree** — onboarding draws `PrimaryCapsule`,
                // and so do restore and store-unavailable. So the precedent the
                // comment cited is the component this was not using, and the
                // sweep that extracted the type took three copies and missed this
                // one because it was in a file that was off limits that day.
                //
                // What it actually differed by, every line of it:
                //
                //     fill     slotInk rgb(64,61,57)   vs  inkPrimary
                //     height   46                      vs  50
                //     width    content + 22 each side  vs  full
                //     label    headerSmall (15)        vs  headerMedium (17)
                //     rim      none                    vs  BlockRim.gradient
                //     press    .plain, so no answer    vs  .pressWord
                //     haptic   at the call site        vs  inside the type
                //
                // The fill is the one that matters: `PrimaryCapsule`'s own header
                // is "**It is ink, flat, and the owner asked for that by name**",
                // and `slotInk` is the tower's warm block ground. Both invert, so
                // nothing was broken — the app simply said "this is the thing to
                // press" in two near-blacks at two heights depending on which
                // screen you were standing on, which is the exact sentence that
                // type was written to end.
                //
                // **Full width inside the panel, which is a change worth
                // looking at.** The panel's content box is the page less its
                // margins less `gapSection` either side — about 306pt at 402 —
                // so the pill is now a 306x50 bar rather than a 160x46 pill
                // floating in the middle of a panel. That is what the primary
                // action looks like on the other three screens that have one, and
                // it is the thing to check by eye rather than by number.
                //
                // The reason the fill is here at all, kept because it is a real
                // finding: it was white type with a `contentShape` and no fill, a
                // button-shaped hit area with nothing to press. On a map, of all
                // grounds, invisible chrome is the one thing that cannot work.
                //
                PrimaryCapsule(title: denied ? "Open Settings" : "Turn On Places") {
                    if denied {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } else {
                        location.requestAccess()
                    }
                }
                .padding(.top, GridConstants.gapTight)
            }
        }
        .frame(maxWidth: .infinity)
        // **CENTRED, AND IT IS THE ONLY CENTRED COMPOSITION IN THE APP, SO IT IS
        // WRITTEN DOWN AS AN EXEMPTION RATHER THAN LEFT TO BE FOUND AGAIN.**
        // (2026-10-01, `docs/consistency-audit.md` §3.5 and check 11d.)
        //
        // `MemoriesView` removed exactly this from the Memories empty state and
        // left the reason on it: "Centred copy on a left aligned page is two
        // alignment systems on one screen, and the same fault the empty tower
        // had." The audit's §3.5 then counted five empty states in two alignments
        // and noted that this one "has an excuse the others do not, because it is
        // a panel over a map rather than a page, but nothing says so".
        //
        // So: **this is not a page.** A page has a margin, which is the thing
        // 11d measures, and every band on it starts at 16 — the map's own page
        // does, title, picker and calendar alike. A panel is an object floating
        // in the middle of a full-bleed photograph, with no margin of its own to
        // align to and nothing above or below it to align WITH. Its left edge is
        // `horizontalPadding` from the screen and its content is `gapSection`
        // inside that, so left-aligning the words would put them 48pt from the
        // screen edge and 16 from their own panel's: two margins, visible,
        // against a centred panel. That is a worse failure of the same clause
        // than centring is.
        //
        // The fix would be to make the panel full-bleed and left-aligned, which
        // is the drawer this app removed on 2026-09-30.
        .padding(GridConstants.gapSection)
        // `1 / displayScale` is the hairline the design language asks for
        // (§6): one device pixel, in ink at low alpha, never a grey line.
        .mapPanel(hairline: 1 / displayScale)
        .padding(.horizontal, GridConstants.horizontalPadding)
        // Centred on the map, and only the panel takes touches: the map
        // around it still pans, which it could not do under the old wash.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        // One window over the whole sweep: how long a block waited for its
        // picture, how many decodes landed, the worst frame gap, and the
        // memory high-water. This is the map's before/after line.
        PerfProbe.window("Map sweep", seconds: 11)
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
            // **A button to VoiceOver, because it is one** (2026-10-02,
            // design review, WCAG 4.1.2). A tap gesture gives the block an
            // action and no role, so VoiceOver read "3 wins here" and nothing
            // that says it opens. The trait is the role; the label above is
            // still the name.
            .accessibilityAddTraits(.isButton)
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

    // `scrimOpacity` lived here and is gone. It returned 0.03 / 0.10 on quiet,
    // 0.10 / 0.20 on night and 0.22 / 0.34 on satellite, lifting as you arrived
    // so a wash never sat over the place names. The measurements that took the
    // whole object off the map are written at the modifier it used to be, in
    // `map`.
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
            // **The size it is actually drawn at**, which is now one number
            // and no more: every block on the map is one cell. It used to be
            // two, because a lone win kept the size a finger drew for it, and
            // the lesson that put this line here still holds either way.
            // Asking for 88 for everything meant a 2x2 block drew an 88pt
            // picture across 90pt at 3x, which is soft, and the owner saw it:
            // "the photos dont even zoom in."
            //
            // One width is also why this is safe. `CachedImageView` keys its
            // cache on the requested width, and a block's size no longer
            // changes with the camera or with what joins it, so nothing
            // re-decodes as you zoom.
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

    /// **One size of photograph for every block on the map**, and now it is
    /// the size they are drawn at.
    ///
    /// The rule is unchanged and was always "decode once at the largest a block
    /// can be": each size asking for its own decode is what made a block go
    /// grey while its picture was remade at a new width. What changed is the
    /// answer. A block could be a 2x2, so this read `cell * 2 + gutter` and
    /// came out at 90. Every block is one cell now (`PlaceMap.Cluster.size`),
    /// so the largest a block can be is `cell`, and asking for 90 means every
    /// photograph on the map is read at 270 device pixels to be drawn across
    /// 132 on a 3x phone: 2.05 times the width, 4.2 times the pixels, for every
    /// picture in the cache at once.
    ///
    /// The one thing to watch on the first launch after this lands: the store
    /// keys its derivatives on the exact width asked for, so the 270px copies
    /// are orphaned and every visible block reads its picture once more. That
    /// is the path this file already designs for, the block comes up on its own
    /// fill and the photograph fades in on top, and it happens once.
    static let decodeWidth: CGFloat = cell

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

    #if DEBUG
    /// When MapKit brought this block on screen, for `MapBlockToArrive`.
    @State private var appearedAt: CFTimeInterval = 0
    #endif

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
                    // Memory only. Asking the store here scheduled a visible
                    // read for EVERY photograph in the place — a crowd of
                    // forty asked for forty — just to find one already there.
                    let width = CGFloat(ThumbnailStore.bucket(Self.decodeWidth * displayScale, exact: true))
                    let ready = cluster.photoFileNames.first {
                        $0.hasPrefix(Self.bundledPrefix)
                            || ImageManager.shared.cachedThumbnail(fileName: $0, maxWidth: width) != nil
                    }
                    base = showing.map { isDecoded($0) ? $0 : (ready ?? $0) }
                    if base != showing { handover(to: showing) }
                }
            }
            .onChange(of: waitingIsReady) { _, ready in
                if ready, let name = waitingFor { handover(to: name) }
            }
            // Read the next beat's photograph ahead of time, on the prefetch
            // lane: nobody is looking at it yet, so it must not queue in
            // front of a picture that is on screen.
            .task(id: upcoming) {
                guard let upcoming, !upcoming.hasPrefix(Self.bundledPrefix) else { return }
                // Ambient: every block does this every beat, so on an
                // unmigrated library it would keep a "foreground" read live
                // almost all the time and starve the migration and the
                // drawer's quiet gate.
                ThumbnailStore.shared.prefetch([upcoming], width: Self.decodeWidth * displayScale,
                                               exact: true, ambient: true)
            }
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
                #if DEBUG
                if PerfProbe.isOn, appearedAt == 0 { appearedAt = CACurrentMediaTime() }
                #endif
                guard !arrived else { return }
                guard !reduceMotion else { arrived = true; return }
                arrive()
            }
            .onDisappear { drawn?.ids.remove(cluster.id) }
    }

    @Environment(\.displayScale) private var displayScale

    /// Whether a photograph is in memory at the map's size. Asking also starts
    /// reading it if it is not, on the visible lane.
    private func isDecoded(_ name: String) -> Bool {
        guard !name.hasPrefix(Self.bundledPrefix) else { return true }
        return ThumbnailStore.shared.state(for: name, width: Self.decodeWidth * displayScale, exact: true).image != nil
    }

    /// The photograph the next beat of the clock will ask for, read ahead so
    /// it is ready by the time it is due.
    private var upcoming: String? { Self.showing(for: cluster, tick: tick &+ 1) }

    /// Whether the photograph a handover is waiting on has now been read.
    private var waitingIsReady: Bool { waitingFor.map(isDecoded) ?? false }

    /// **A block arrives at once; its photograph follows** (2026-09-16).
    ///
    /// It used to be the other way round: "a block arrives with its
    /// photograph, not before it", written after a zoom out filmed two grey
    /// squares for a sixth of a second each. The gate held a block invisible
    /// until its picture decoded, and gave up after 600ms and showed the grey
    /// square anyway — so the map paid the wait AND showed the thing the wait
    /// was for, and a block that is not drawn cannot be seen, tapped or
    /// found. The owner: "hard to find things on the map because they won't
    /// load". Now the block comes up on its own opaque fill and the picture
    /// fades in on top of it when it lands, which is what a block is: a
    /// coloured block that becomes a photograph. Reading from a 320px
    /// derivative, that second step is tens of milliseconds, and a picture
    /// already on a block is still never cleared while zooming (`carry`,
    /// `decodeWidth`).
    private func arrive() {
        #if DEBUG
        // **How long MapKit drew nothing where a block belongs.** The gate
        // this used to sit behind is the map half of "hard to find things on
        // the map because they won't load", so it is the number that says
        // whether removing it worked.
        if PerfProbe.isOn, appearedAt > 0 {
            PerfProbe.sample("MapBlockToArrive", ms: (CACurrentMediaTime() - appearedAt) * 1000)
            appearedAt = -1
        }
        #endif
        withAnimation(GridConstants.mapFade.delay(delay)) { arrived = true }
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
        .animation(reduceMotion ? nil : GridConstants.motionSnappy, value: showsCount)
        .accessibilityLabel(spokenName)
    }

    /// The place's name when it is already known, then the count. Every block
    /// said "3 wins here", so two places could only be told apart by opening
    /// them (2026-10-02, design review, `map.md` #3). The name is read, never
    /// fetched: geocoding is rate-limited hard and a map of twenty blocks
    /// would be refused, so a block gains its name once its place has been
    /// opened, and says the count until then.
    private var spokenName: String {
        let count = "\(cluster.winCount) \(cluster.winCount == 1 ? "win" : "wins")"
        let place = WinPlace(latitude: cluster.latitude, longitude: cluster.longitude)
        guard let name = PlaceNames.shared.name(for: place) else { return "\(count) here" }
        return "\(name), \(count)"
    }
}

extension PlaceBlock {
    /// The badge's two colours, fixed in both appearances — see `countBadge`.
    static let badgeDisc = Color(red: 0.975, green: 0.978, blue: 0.984)
    static let badgeInk = AppColors.warmBlack

    /// How many wins are in this area.
    ///
    /// **The owner's own digits, on the app's own black.** `Typography.numeral`
    /// is `StrataFont` — the same face the tower's tally and the month
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
    ///
    /// **It sits INSIDE the block now, and the reason is not taste**
    /// (2026-10-01). It was `.offset(x: 8, y: -8)`, which put the capsule 8pt
    /// above and 8pt to the right of the block's own bounds, and the note that
    /// went with it argued the overhang was what made it read as attached.
    /// Measured off the built screen at 402x874, it does the opposite twice
    /// over:
    ///
    /// - **It lands on the neighbour.** `PlaceMap.maxOverlap` lets two blocks
    ///   cover each other by up to a third before they merge, so a block may be
    ///   touching the one beside it and still be two places. Anything drawn
    ///   outside a block's bounds is therefore drawn on whatever is next to it.
    ///   In the capture that is not hypothetical: of the three badges on
    ///   screen, the "2" sits bodily on the ORANGE block to its right rather
    ///   than on the purple one it counts, and the "3" and the "2" below it
    ///   each clip the block above. A count attached to the wrong block is not
    ///   a near miss, it is the wrong number.
    /// - **Its own ground is invisible.** The capsule is declared at
    ///   rgb(249, 249, 251) and renders at rgb(231, 230, 232) under the map's
    ///   0.10 scrim. MapKit's pale ground renders at rgb(233, 233, 224) right
    ///   beside it: **1.01:1**. So the part of the badge hanging over the map
    ///   had no disc at all, and the digits read as one more MapKit label among
    ///   ENFIELD, BARNET and the road shields. Taking the scrim off later the
    ///   same day did not rescue it and was never going to: both values rise
    ///   together, rgb(249, 249, 251) on rgb(251, 250, 242), which is 1.01:1
    ///   again. A near-white disc on a near-white map has no answer except not
    ///   being on the map.
    ///
    /// On the block both go away. The block is the ground the disc was always
    /// claiming to have: the numeral measures 8.15:1 on the capsule, and the
    /// capsule on the blue block under it 1.87:1. That edge is soft, which is
    /// what a light label on a saturated block always is, and it is the same
    /// relationship the tower's day numerals already have.
    ///
    /// Inset by `GridConstants.spacing`, which is the block grid's gutter at
    /// the reference cell rather than at this one: the map's own gutter is
    /// 44 x 4 / 86.5 = 2.03pt. 4 is kept anyway, and the reason is the corner
    /// rather than the grid. At 2.03 the capsule would sit inside the block's
    /// 6.1pt radius and its own corner would be cut by it; at 4 it clears both
    /// that and the 0.97pt rim.
    ///
    /// **The capsule's size WAS the open question and is now answered**
    /// (2026-10-01). Measured off the capture and then off the real metrics
    /// rather than tuned, on the 44pt cell every badged block wears:
    ///
    ///     digits   was            now           of the block
    ///     1        24.3 x 22      18.0 x 18     27.6% -> 16.7%
    ///     2        32.3 x 22      24.3 x 18     36.7% -> 22.6%
    ///     3        40.6 x 22      32.6 x 18     46.2% -> 30.3%
    ///
    /// It was half the block's height and 55% of its width for one digit, and
    /// 73% of its width for two: the "24" in the capture left a 7.7pt strip of
    /// photograph beside it. It is 41% of the height now, and 41% of the width
    /// for one digit.
    ///
    /// **Both numbers came out of the numeral's own metrics.**
    /// `Typography.numeral(13)` resolves to SF at 13pt Medium: digit advance
    /// 8.27pt, cap height 9.16, line box 15.31. Sampled off the built badge the
    /// "3" measured 9.7pt of ink with 6.3 above and 5.7 below inside a 21.7pt
    /// capsule, so twelve of the twenty-two points were air and the capsule
    /// stood at 2.24 times its own cap. At 18 it is 1.96 times, 4.4pt of air
    /// each side of the cap and 1.3 each side of the line box, and horizontally
    /// `GridConstants.spacing` leaves about 4.5 beside a digit. Vertical air 4.4
    /// against horizontal 4.5 is a capsule; 6.4 against 8.0 was not. Nothing
    /// about the numeral changes: same face, same size, same 8.15:1 on the
    /// capsule.
    ///
    /// What was NOT done, and why.
    ///
    /// - *A 6pt horizontal padding.* It is not a token. The grid's own gutter
    ///   is, it is already the number this badge is inset by, and it gets the
    ///   one-digit capsule to a true 18 x 18 disc, which the old `minWidth`
    ///   note claimed it already was and the measurement says it never was.
    /// - *16 as the height.* The line box is 15.31. A capsule clearing its own
    ///   text by 0.7pt is not a badge, it is a crop, and `minHeight` would stop
    ///   driving the frame at all.
    /// - *An 11pt numeral.* The badge is the only thing on this screen that
    ///   states a number about you, and now that every block is one cell it is
    ///   the only quantity on the map at all. Shrinking the digit pays for the
    ///   photograph with the one piece of information on top of it.
    ///
    /// `ClusterCountBadgeTests` pins both numbers against three digits
    /// wrapping, so it moves with them rather than being relaxed.
    var countBadge: some View {
        ClusterCountBadge(count: shownCount)
            .padding(GridConstants.spacing)
            .accessibilityHidden(true)
    }

    /// The count shown; `-strataBadgeCount` overrides it in DEBUG.
    private var shownCount: Int {
        #if DEBUG
        if let forced = DebugHarness.badgeCount { return forced }
        #endif
        return cluster.winCount
    }
}

/// The count on a map block, on its own light capsule.
///
/// **One line, whatever the count** (2026-09-16). It sits in the block's
/// `.overlay`, which proposes the BLOCK's width, and a `Text` offered less
/// than it needs wraps: 236 came out as "23" over "6". It keeps its own
/// width now and the capsule grows leftward from the block's corner. And the
/// count is `StrataFont.digits`, not `"\(count)"`, whose interpolation
/// formats 1000 as "1,000" in a face with no comma.
struct ClusterCountBadge: View {
    let count: Int

    /// The capsule's floor: round for one digit, wider past that.
    ///
    /// **24 x 22 until 2026-10-01**, when it was measured against the block it
    /// sits on rather than against itself. The full working is on
    /// `PlaceBlock.countBadge`; the numbers are 24.3 x 22 rendered for one
    /// digit, which is half the 44pt cell's height and 27.6% of its area, and
    /// 18.0 x 18 now, 41% and 16.7%.
    ///
    /// **`minWidth` was decorative and is now load-bearing.** Its own note said
    /// "round for one or two digits", and it never was: SF 13 Medium sets a
    /// digit at 8.27pt advance, so with `gapTight` on each side one digit came
    /// to 24.3 and the 24 floor was already beaten. The capsule was a 1.10:1
    /// oval calling itself a circle. At `GridConstants.spacing` the natural
    /// width is 16.3, the floor bites, and 18 x 18 is a disc.
    ///
    /// Both numbers are asserted by `ClusterCountBadgeTests`, and the height one
    /// can genuinely fail: the test reads the badge's own `sizeThatFits` in a
    /// 10pt-wide offer, so a height under the numeral's 15.31pt line box stops
    /// driving the frame and the measured height stops matching this constant.
    static let minWidth: CGFloat = 18
    static let height: CGFloat = 18

    var body: some View {
        Text(verbatim: StrataFont.digits(count))
            // **13, and it is one of the three things the 2026-10-01 type pass
            // left under the app's 15pt floor.** The owner asked for "no tiny
            // thin font anywhere"; this stays because of the paragraph directly
            // above, about the badge's size against the block it sits on.
            //
            // It is a DIGIT on an 18pt capsule, not a line of text — the same
            // family as the month block's `cell * 0.16` numeral. Measured at
            // 15: SF Medium's digit advance goes 8.27pt to 9.54, so with
            // `GridConstants.spacing` a side the capsule goes 18.0 / 24.3 /
            // 32.6 to 18.0 / 27.1 / 36.6 for one, two and three digits. A
            // two-digit badge would go from 55% of the 44pt cell's width to
            // 62%, which re-inflates the badge that was deliberately measured
            // DOWN to 16.7% of the block on the same day.
            //
            // `TypographyTests.TypeSweep` carries this as a named exemption,
            // so it cannot drift silently.
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
            .foregroundStyle(PlaceBlock.badgeInk)
            // Tabular already, so no `.monospacedDigit()`: it does nothing
            // to a custom face.
            .lineLimit(1)
            // **The grid's gutter, not `gapTight`.** It was 8 a side, which on
            // an 8.27pt digit is 66% padding and is what made a one-digit
            // capsule 24.3 wide and 22 tall: wider than it is tall, on the
            // badge whose own note claimed it was round. `GridConstants.spacing`
            // is the same token the badge is already inset from the block's
            // corner by, so it is now one number twice rather than 4 outside
            // and 8 in. Measured at 13pt Medium: one digit 18.0 x 18, two 24.3,
            // three 32.6, against 24.3 / 32.3 / 40.6 before.
            .padding(.horizontal, GridConstants.spacing)
            .frame(minWidth: Self.minWidth, minHeight: Self.height)
            .background {
                Capsule().fill(PlaceBlock.badgeDisc)
            }
            // On the whole badge, not the text: a min-width frame clamps a
            // narrow offer to its floor, so fixing only the text left three
            // digits spilling out of a 24pt capsule (measured).
            .fixedSize()
    }
}

private extension View {
    /// The surface the map's empty state stands on.
    ///
    /// **Translucency and a hairline, never elevation** (§6). The same
    /// material `GlassIconButton` and the recentre button are made of, at the
    /// surface radius, so the one panel on this screen belongs to the same
    /// system as the three controls floating beside it.
    ///
    /// Not a block: CLAUDE.md is explicit that a white rim, a frosted band or
    /// a blurred edge is a block's claim, "you built this and it is standing
    /// on something". A hairline in ink at low alpha is a separation, not a
    /// rim, and nothing here casts a shadow.
    ///
    /// **`.regular`, not `.interactive()`.** That variant reacts to a press,
    /// which is an affordance a button buys and a panel would be lying about.
    ///
    /// It replaced `mapPrimeGlass`, which put this material behind a capsule
    /// that already had a solid fill of its own and therefore drew nothing.
    @ViewBuilder
    func mapPanel(hairline: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: GridConstants.radiusSurface,
                                     style: .continuous)
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: shape)
                .overlay { shape.strokeBorder(GridConstants.fillHairline, lineWidth: hairline) }
        } else {
            self.background(.ultraThinMaterial, in: shape)
                .overlay { shape.strokeBorder(GridConstants.fillHairline, lineWidth: hairline) }
        }
    }
}

/// The way back to Memories.
///
/// **The one it replaces was invisible, and it is the control the owner asked
/// for by name**: "make sure there is a way to get back to the Memories from
/// the map." The map's route in `MemoriesView` drew a `GlassIconButton` with
/// `tint: .white` under a forced `.dark` colour scheme, on the reasoning that
/// a control floating over a map is floating over imagery. The pale `.quiet`
/// ground is not imagery, and glass takes its brightness from what is behind
/// it rather than from the scheme it is handed. Sampled off the built screen:
///
///     chevron   rgb(255, 255, 255)
///     its disc  rgb(248, 248, 242)
///     ratio     1.10:1          (a shape needs 3.0)
///
/// On the screenshot it is an empty white circle. The person who most needs
/// this button is the one who does not know the swipe, and it has been showing
/// them nothing.
///
/// **And a darker disc is not the fix, because the DISC is not what carries
/// this control.** The map's own ground was sampled in five places on the same
/// capture and the glass disc was scored against each, which is the test a
/// control on a map has to pass: MapKit's ground is not one colour, it changes
/// under the chrome as you pan, and a value tuned over the pale fill is a
/// different value over a park.
///
///     ground               rgb              disc vs ground   white glyph   ink glyph
///     pale fill            (233, 233, 224)       1.15:1         1.07:1       19.70:1
///     park green           (203, 224, 198)       1.31:1         1.07:1       19.70:1
///     road grey            (213, 213, 206)       1.38:1         1.07:1       19.70:1
///     motorway shield      (209, 227, 204)       1.27:1         1.07:1       19.70:1
///     water blue           (132, 181, 221)       2.04:1         1.07:1       19.70:1
///
/// The disc clears 3:1 against NOTHING on this map, and it never will: it is a
/// near-white material and so is most of a standard map. So the glyph is the
/// whole control. A white one is 1.07:1 on every ground there is, and an ink
/// one is 19.70:1 on every ground there is, because its ground is the disc and
/// the disc is the one thing on this screen that does not change as you pan.
/// That is also why the material stays pinned light rather than following the
/// map: a light disc under an ink glyph is the only pairing that holds over the
/// pale `.quiet` ground AND over `.satellite` and `.night`, where the disc
/// gains contrast against the tiles and the glyph keeps every bit of its own.
///
/// So it is the same object as `RecentreButton` below, down to the line:
/// pinned light in both appearances, the system's own glyph colour, 44pt, on
/// the margin. That configuration is not a guess: the recentre button on the
/// same capture measures rgb(0, 0, 0) on rgb(242, 248, 236), **18.9:1**, and
/// the two controls are now one control in two corners.
///
/// **It carries its own placement**, so the page that pushes the map only has
/// to say where back goes. The numbers are the ones that were in `MemoriesView`
/// and they are the app's own: the leading margin, and `headerArtworkTopPadding`
/// so the chevron's centre lands on the same line every other screen's title
/// cap does.
///
/// **It stays top-leading, which is NOT where a thumb reaches** on an 874pt
/// screen: measured, its centre sits at 103pt from the top, and the disc runs
/// 16.0 to 60.0pt across and 80.7 to 124.7 down, so it is a true 44 on the
/// 16pt margin. The reach is accepted rather than overlooked. Back is
/// top-leading on every iOS screen including the one this map was pushed from,
/// the bottom-trailing corner is already the recentre button's, and a map whose
/// dismiss is at the bottom would be the only one on the phone. What it must
/// NOT rely on is the edge swipe: nothing in the app disables it, but the left
/// edge of this screen is also where a pan west starts, and a way back that
/// competes with the screen's main gesture is not a way back. That is the whole
/// argument for this button being visible, which until now it was not.
struct MapBackButton: View {
    /// The map is the night style: the button is dark glass with it.
    var night = false
    let action: () -> Void

    var body: some View {
        GlassIconButton(systemName: "chevron.left",
                        accessibilityLabel: "Back to Memories") {
            action()
        }
        // **The MAP's scheme, as `RecentreButton` has it** (2026-10-03). Both
        // were pinned light whatever the map was, and Liquid Glass then
        // re-decided each one from whatever lay under it: on the night map
        // the back button went dark and the locate button stayed light, two
        // controls of one screen in two styles (the owner: "looks off").
        // Following the map, they agree with it and with each other.
        .environment(\.colorScheme, night ? .dark : .light)
        .padding(.leading, GridConstants.horizontalPadding)
        .padding(.top, GridConstants.headerArtworkTopPadding)
    }
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
///
/// **Its own view, because it is the only thing that reads the fix.** As a
/// property of the map, reading `location.latest` for the glyph made every
/// location update (one per ten metres) re-evaluate the whole map and all of
/// its annotations. Now an update redraws this button.
private struct RecentreButton: View {
    let location: LocationService
    /// The map is the night style. See `MapBackButton`.
    var night = false
    let action: () -> Void

    var body: some View {
        GlassIconButton(systemName: locationGlyph,
                        accessibilityLabel: "Show my location") {
            action()
        }
        // The map's scheme, as the back button: see `MapBackButton`.
        .environment(\.colorScheme, night ? .dark : .light)
        .padding(.trailing, GridConstants.horizontalPadding)
        // See the map's own `safeAreaPadding` above for why this reads
        // `GridConstants` rather than the deleted `DrawerMetrics`.
        .padding(.bottom, GridConstants.tabBarClearance)
        // It has nothing to say until it can say it.
        .opacity(location.isDenied ? 0 : 1)
        .allowsHitTesting(!location.isDenied)
        .animation(GridConstants.motionSnappy, value: location.isDenied)
    }

    /// Filled once we know where you are, hollow while we do not — the same
    /// grammar the system uses, so it needs no explaining.
    private var locationGlyph: String {
        location.fix(maxAge: 600, maxAccuracy: 1000) == nil
            ? "location" : "location.fill"
    }
}

/// The moment the map's camera last moved. See `MemoriesMapView.motion`.
@MainActor
final class MapMotion {
    var movedAt: ContinuousClock.Instant = .now
    /// How long the camera has been still.
    var stillFor: Duration { ContinuousClock.now - movedAt }

    /// Returns once the camera has been still for `delay`, restarting the wait
    /// every time it moves again. Cancellation returns straight away.
    ///
    /// The Memories page waits on this before building its drawer off screen,
    /// so the build never takes a frame out of a pan. `MapMotionTests` drives
    /// it with a camera that keeps moving.
    func waitUntilStill(for delay: Duration,
                        sleep: (Duration) async -> Void = { try? await Task.sleep(for: $0) }) async {
        while !Task.isCancelled {
            let still = stillFor
            guard still < delay else { return }
            await sleep(delay - still)
        }
    }
}
