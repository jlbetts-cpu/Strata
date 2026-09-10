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
    /// **Held, not computed.**
    ///
    /// This was a computed property, and it wedged the screen. The map's
    /// content depended on `zoom`, `onMapCameraChange` wrote `zoom`, and
    /// `.automatic` framed the camera from the content — a loop with no
    /// settling point. SwiftUI stopped re-evaluating the whole Memories body,
    /// which showed up as the page keeping its EMPTY state forever while the
    /// view model had forty pins in it. Nothing errored.
    ///
    /// Recomputed only when the integer zoom actually changes, which is a few
    /// times per pan rather than once per frame.
    @State private var clusters: [PlaceMap.Cluster] = []
    /// Observed, so the empty state follows the answer to its own prompt
    /// rather than waiting for the screen to be opened again.
    ///
    /// `@State`, not a plain stored property: a stored `private` property
    /// joins the memberwise initializer and makes the whole init private,
    /// which stops every caller constructing this view.
    @State private var location = LocationService.shared

    var body: some View {
        ZStack {
            map
            if pins.isEmpty { emptyState }
        }
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

    private var map: some View {
        Map(position: $camera, interactionModes: isInteractive ? .all : []) {
            ForEach(clusters) { cluster in
                Annotation("", coordinate: CLLocationCoordinate2D(
                    latitude: cluster.latitude, longitude: cluster.longitude
                ), anchor: .center) {
                    PlaceBlock(cluster: cluster)
                        .onTapGesture { onSelect(cluster.key) }
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(mapStyle)
        .mapControls { }
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
                .fill(AppColors.warmBlack.opacity(style == .satellite ? 0.34 : 0.10))
                .allowsHitTesting(false)
        }
        // `.onEnd`, not `.continuous`. Re-clustering every camera frame both
        // costs CPU and looks wrong — blocks twitch between two cells while
        // you pan, because the cell under a pin changes several times a
        // second.
        .onMapCameraChange(frequency: .onEnd) { context in
            viewportWidth = context.rect.width > 0 ? viewportWidth : viewportWidth
            let next = PlaceMap.zoomLevel(
                spanLongitude: context.region.span.longitudeDelta,
                viewportWidth: Double(viewportWidth)
            )
            // Only when the GRID changes. Assigning the same value back is
            // what turned this into a loop.
            guard next != zoom else { return }
            zoom = next
            withAnimation(GridConstants.crossFade) {
                clusters = PlaceMap.cluster(pins, zoom: next)
            }
        }
        // Never `camera = .automatic` here: `.automatic` frames itself from
        // the content, and the content is what this would be changing.
        .task(id: pins.count) {
            clusters = PlaceMap.cluster(pins, zoom: zoom)
        }
    }

    private var mapStyle: MapStyle {
        switch style {
        case .quiet:
            // Everything MapKit will let us take away.
            return .standard(elevation: .flat,
                             emphasis: .muted,
                             pointsOfInterest: .excludingAll,
                             showsTraffic: false)
        case .satellite:
            return .imagery(elevation: .flat)
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
