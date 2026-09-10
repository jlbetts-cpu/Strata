import AVFoundation
import SwiftUI
import UIKit

/// The in-app camera. Figma "Apollo" `600:104`.
///
/// A photo of a win, taken in the app, that becomes the block's face. The
/// system picker could take the picture but it cannot look like this, and this
/// screen is a surface of the app rather than a detour out of it.
///
/// **Deviation from the design, on purpose:** the two glyphs are SF Symbols
/// rather than the exported `lucide` and `mdi` assets. CLAUDE.md settles this —
/// SF Symbols only, no second icon pack — and the shapes are equivalent.
struct CameraView: View {

    /// Hands back the captured photo. Nil means the viewer backed out.
    /// The photograph, the size it was drawn at, and where it was taken.
    ///
    /// The place is read at SHUTTER time rather than at save time. The add
    /// sheet can sit open while you walk away, so save time is the wrong
    /// clock; a two-minute staleness cap is what makes "shutter time" honest
    /// rather than "the last fix, whenever that was".
    var onCaptured: (UIImage, BlockSize, WinPlace?) -> Void = { _, _, _ in }
    var onClose: (() -> Void)? = nil
    /// True when nothing else is on screen — presented as its own sheet rather
    /// than as a tab with a bar beneath it.
    var fillsScreen: Bool = false

    @State private var camera = CameraService()
    @State private var flashOpacity: Double = 0
    /// Whether the composition guides are drawn. Remembered, because it is a
    /// preference about how you shoot rather than a per-session choice.
    ///
    /// Plain `@State` over an explicit `UserDefaults` read, not `@AppStorage`.
    /// The wrapper version read `false` on a launch where the key did not
    /// exist at all and never changed when toggled, while the flash button —
    /// same button helper, same action path, `@Observable` storage — toggled
    /// correctly in the same run. Measured, twice.
    @State private var shutterScale: CGFloat = 1

    /// Seconds left, while a timed shot counts down. Nil when idle.
    @State private var countdown: Int?
    @State private var countdownTask: Task<Void, Never>?
    /// What the screen was set to before the ring light raised it. Nil when
    /// the ring is not holding it up.
    @State private var brightnessBeforeRing: CGFloat?
    /// Where the lens was when the current pinch began. A `MagnifyGesture`
    /// reports a magnification RELATIVE to the start of the gesture, so
    /// multiplying it by a live value would compound on every frame.
    @State private var zoomAtPinchStart: CGFloat?
    /// The size being drawn out of the shutter, and the state the drag needs.
    ///
    /// The camera could only ever make a 1x1 unless you went into the add
    /// sheet afterwards and tapped "Regular" or "Deep" — so the size of a
    /// photographed win was a form field, while the size of every other win
    /// was a gesture. Same gesture here now, through `BlockSizeDraw`.
    @State private var drawnSize: BlockSize = .small
    /// The shot waiting to be kept or thrown away. Nil while composing.
    ///
    /// A state on the camera rather than a screen of its own, because
    /// "retake" has to land back on the live viewfinder — and the camera tab
    /// dismisses itself into the add sheet on the tower, so a retake from
    /// there would have to navigate backwards to get here.
    @State private var review: UIImage?
    @State private var shutterDown = false
    /// Where the last tap-to-focus landed, in the viewfinder's own space, and
    /// when — the reticle fades itself out.
    @State private var focusPoint: CGPoint?
    @State private var focusShownAt = Date.distantPast
    /// The exposure the current drag started from, for the same reason the
    /// pinch keeps one.
    @State private var biasAtDragStart: Float?
    /// The layer, so a point on screen can be turned into a point on the
    /// sensor. `.resizeAspectFill` crops, and the crop depends on the preview's
    /// aspect against the format's — arithmetic here would be a second copy of
    /// a conversion AVFoundation already does exactly.
    @State private var previewBox = PreviewLayerBox()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Geometry, from the Figma frame (402 x 874)

    /// Rule-of-quarters guides. Two verticals and two horizontals, which is
    /// what the design specifies — not a full nine-cell thirds grid.
    private enum Guide {
        /// Thirds, evenly. The Figma has them at 0.25/0.74 across and
        /// 0.26/0.50 down, which is a designer eyeballing a grid rather than a
        /// grid — the cells came out different sizes. This is the rule of
        /// thirds the iPhone camera draws, and the one anybody composing a
        /// shot is expecting.
        static let verticalX: [CGFloat] = [1.0 / 3.0, 2.0 / 3.0]
        static let horizontalY: [CGFloat] = [1.0 / 3.0, 2.0 / 3.0]

        /// Pure white, one weight, everywhere.
        ///
        /// It was a 0.5pt grey. Half a point does not land on a pixel boundary
        /// at 3x, so each line was antialiased across two rows by a different
        /// amount depending on where it fell — the lines were the same value
        /// and visibly different weights. A full point is exact at every
        /// scale, and white matches the icons and the count rather than being
        /// a fourth grey nobody chose.
        static let colour = Color.white.opacity(0.55)
        static let width: CGFloat = 1
        /// How much of the frame the bottom fade occupies.
        static let fadeHeight: CGFloat = 0.20
    }

    /// The header the grid is built around.
    ///
    /// The count, the flip and the flash all sit on one line, and the break in
    /// the left vertical is measured FROM that line rather than copied from the
    /// design's 48-127pt. The gap exists to hold the header, so the header is
    /// what decides where it starts and stops — that is the difference between
    /// the count sitting in the gap and the count happening to overlap it.
    private enum Header {
        /// Solved from the wordmark's size, so its cap lands on the same line
        /// as every other screen's title. It used to hard-code the tower's 4pt,
        /// which only aligned the two layout BOXES — the type inside them is a
        /// different size, so the ink did not line up.
        static var topPadding: CGFloat {
            // Artwork, not type — see `headerArtworkTopPadding`. Using the
            // type version put the wordmark 9.3pt above the line every other
            // header sits on.
            GridConstants.headerArtworkTopPadding
        }
        /// Cap height for the wordmark.
        ///
        /// Cap height for the wordmark. Bigger than a page title, on
        /// purpose.
        ///
        /// It was 61 — what Jaro needed to set "Strata" 147pt wide — then 40,
        /// then 28, then `Typography.screenTitleCap` at 23.96. The face is
        /// 6.5:1 against Jaro's 2.4:1, so 61 ran the word 396pt across a
        /// 370pt page and clipped the final `a`, and 40 still ran it to 276pt
        /// — across the SECOND vertical guide, which sits at 268 on a 402pt
        /// screen. The guides are the composition, and a title lying over two
        /// thirds of them is covering the grid rather than sitting in it.
        ///
        /// **Then 24 was too small**, and that is the owner's read of it: the
        /// other screens are a title over a page of content, and this one is a
        /// wordmark over an empty viewfinder with nothing else in the top
        /// two thirds to hold the other end of it. A title matched to a page
        /// it does not have leaves the frame unbalanced.
        ///
        /// 32 sets the word 208pt: from the margin at 16 to 224, crossing the
        /// first vertical at 134 — the one that is broken for it — and
        /// stopping 44pt short of the second.
        static let wordmarkSize: CGFloat = 32
        /// The break in the first vertical is cut to the wordmark exactly, so
        /// the word is centred in it by construction rather than by a second
        /// number that has to be kept in step. It used to be 72, sized for a
        /// 61pt wordmark, which left a 40pt word hanging at the top of a gap
        /// half again as tall as it was.
        static var height: CGFloat { wordmarkSize }
        /// Air between the header and the cut ends of the line.
        static let breathing: CGFloat = 14
    }

    /// Rounder than the design's 20.
    ///
    /// The Figma draws the viewfinder against a bezel it never leaves. Here it
    /// stops above the tab bar, so the curve is a real edge you look at rather
    /// than a corner tucked into the phone's own — and at 20 it read as a
    /// square that had been slightly softened rather than as a shape.
    private let cornerRadius: CGFloat = 34
    /// Air between the bottom of the viewfinder and the tab bar.
    private let tabGap: CGFloat = 14
    /// Air between the shutter and the bottom edge of the viewfinder.
    private let shutterBottomGap: CGFloat = 40
    /// Distance from the right edge to the centre of the control column.
    private let controlInset: CGFloat = 40
    private let shutterOuter: CGFloat = 80
    private let shutterInner: CGFloat = 66


    var body: some View {
        GeometryReader { geo in
            let topInset = geo.safeAreaInsets.top
            // Edge to edge, both here and presented on its own.
            //
            // The tab bar goes dark over it — it is Liquid Glass and samples
            // what is behind it, and three ways to stop that were tried and
            // none reaches it (`UITabBarAppearance`,
            // `toolbarColorScheme(_:for: .tabBar)`, and
            // `toolbarBackground(_:for: .tabBar)`). That is fine now rather
            // than a bug: the camera declares the dark scheme, so the bar's
            // icons and its highlight go white, which is what belongs on a
            // black viewfinder anyway.
            //
            // Without this the modal camera drew to the top of the home
            // indicator and left a stray light strip below itself with the
            // rounded corners floating above it — which is what was broken
            // about the add sheet's camera.
            let bottomInset = fillsScreen ? geo.safeAreaInsets.bottom : 0
            let w = geo.size.width
            let h = geo.size.height + topInset + bottomInset - (fillsScreen ? 0 : tabGap)

            ZStack {
                CameraPreview(session: camera.session, box: previewBox)

                // The gestures the native camera has, on the viewfinder and
                // under the chrome, so the buttons still take their own taps.
                viewfinderGestures(w: w, h: h)

                if camera.showsGuides {
                    guides(w: w, h: h, topInset: topInset)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }

                header(topInset: topInset)

                // The count, over the frame. Big and central because you are
                // standing in the shot looking at the lens, not at a corner.
                if let countdown {
                    Text("\(countdown)")
                        // Medium, not light. The app has two weights and a
                        // third one on the largest thing on any screen is
                        // the most visible place to break that rule.
                        // The owner's own digits — the same face the tally
                        // and the month blocks are set in. A countdown is a
                        // number the app is stating, so it takes the app's
                        // numerals.
                        .font(Typography.numeral(96))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 14)
                        .transition(.opacity.combined(with: .scale(scale: 1.25)))
                        .id(countdown)
                        .allowsHitTesting(false)
                        .accessibilityLabel("\(countdown) seconds")
                }

                controls(w: w, h: h, topInset: topInset, bottomInset: bottomInset)
                    // The controls belong to composing. While a shot is
                    // waiting to be judged there is nothing to compose.
                    .opacity(review == nil ? 1 : 0)
                    .allowsHitTesting(review == nil)

                warmFlash
                    .allowsHitTesting(false)

                if let review {
                    reviewLayer(image: review, topInset: topInset,
                                bottomInset: bottomInset)
                        .transition(.opacity)
                }
            }
            .frame(width: w, height: h)
            .background(Color(red: 0.031, green: 0.031, blue: 0.031))
            // Square where it meets the edge of the screen, rounded where it
            // stops short of one — the shape the Figma draws, and one that
            // only makes sense because something is behind it. Full screen, it
            // rounds nothing.
            .clipShape(
                .rect(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: fillsScreen ? 0 : cornerRadius,
                    bottomTrailingRadius: fillsScreen ? 0 : cornerRadius,
                    topTrailingRadius: 0
                )
            )
            .offset(y: -topInset)
        }
        // No `.ignoresSafeArea` on the GeometryReader: it reports ZERO insets
        // once told to ignore them, and the header needs the real value to
        // clear the notch. The preview reaches the edges by being drawn taller
        // and offset instead.
        .background { WarmBackground().ignoresSafeArea() }
        .task { await camera.start() }
        // The ring owns screen brightness while it is lit. It is the only
        // thing that makes the overlay actually EMIT: a warm wash on a screen
        // at 30% lights nothing.
        .onChange(of: ringIsArmed) { _, armed in setRingBrightness(armed) }
        .onAppear { if ringIsArmed { setRingBrightness(true) } }
        #if DEBUG
        .onAppear {
            if let size = DebugHarness.openReviewSize {
                drawnSize = size
                review = DebugHarness.placeholderPhoto()
            }
        }
        #endif
        .onAppear {
            // Warm the fix alongside the lens. A cold GPS read takes seconds
            // and a warm one is immediate, so by the time a shot is framed the
            // answer has already arrived and the shutter never waits on it.
            LocationService.shared.start()
        }
        .onDisappear {
            // Not a tracker: it runs while the camera is open and not a
            // moment longer.
            LocationService.shared.stop()
            camera.stop()
            // Every exit path restores it. Leaving somebody's screen pinned at
            // full brightness because they walked away from the camera tab is
            // the kind of bug that gets noticed as battery drain, not as a
            // bug.
            setRingBrightness(false)
        }
    }

    /// Raises the screen for the ring light, and puts it back afterwards.
    ///
    /// `brightnessBeforeRing` is set only on the way up and cleared on the way
    /// down, so arming twice cannot capture 1.0 as the value to restore.
    private func setRingBrightness(_ on: Bool) {
        if on {
            if brightnessBeforeRing == nil {
                brightnessBeforeRing = UIScreen.main.brightness
            }
            UIScreen.main.brightness = 1.0
        } else if let previous = brightnessBeforeRing {
            UIScreen.main.brightness = previous
            brightnessBeforeRing = nil
        }
    }

    // MARK: - Review

    /// The shot, before it becomes anything.
    ///
    /// Asked for so a photograph can be looked at properly and thrown away —
    /// and the moment it existed it turned the camera-roll write into a bug,
    /// because that happened at capture. Nothing is kept until `Use Photo`.
    ///
    /// **The size you drew is still on screen**, in the middle, where the
    /// shutter was. The shutter became the block; here the block stays, so the
    /// two frames are continuous and you can see what you are about to make
    /// before you commit to it.
    ///
    /// One extra tap on every capture, and `docs/product-direction.md` says
    /// recording a win must be the fastest thing in the app. That cost is real
    /// and is the thing to watch: if it drags, the fix is a Settings toggle,
    /// not a redesign.
    private func reviewLayer(image: UIImage, topInset: CGFloat,
                             bottomInset: CGFloat) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // The same print the viewer lays down — inset, with the app's
                // surface radius — so a photograph looks like the same object
                // the moment after you take it as it does a month later.
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(image.size.width / max(image.size.height, 1),
                                 contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: GridConstants.radiusSurface,
                                                style: .continuous))
                    .padding(.horizontal, 20)

                Spacer(minLength: 0)

                HStack(spacing: 0) {
                    Button {
                        HapticsEngine.tick()
                        withAnimation(GridConstants.gentleReveal) { review = nil }
                    } label: {
                        Text("Retake")
                            .font(Typography.headerSmall)
                            .foregroundStyle(.white.opacity(0.75))
                            .frame(minWidth: 88, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }

                    Spacer(minLength: 0)

                    // What you drew, still showing.
                    RoundedRectangle(cornerRadius: reviewMarkSize.height * 0.147,
                                     style: .continuous)
                        .fill(.white.opacity(0.9))
                        .frame(width: reviewMarkSize.width, height: reviewMarkSize.height)
                        .accessibilityLabel("Block size, \(drawnSize.effortLabel)")

                    Spacer(minLength: 0)

                    Button {
                        HapticsEngine.success()
                        keep(image)
                    } label: {
                        Text("Use Photo")
                            .font(Typography.headerSmall)
                            .foregroundStyle(.white)
                            .frame(minWidth: 88, minHeight: 44, alignment: .trailing)
                            .contentShape(Rectangle())
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
                .padding(.bottom, bottomInset + shutterBottomGap)
            }
            .padding(.top, topInset + Header.topPadding)
        }
    }

    /// The drawn size, small enough to sit on a toolbar line. Same proportions
    /// as the shutter, a third of the size.
    private var reviewMarkSize: CGSize {
        let cell: CGFloat = 22
        let gutter = cell * GridConstants.spacing / GridConstants.blockReferenceCell
        return CGSize(
            width: cell * CGFloat(drawnSize.columnSpan)
                + gutter * CGFloat(drawnSize.columnSpan - 1),
            height: cell * CGFloat(drawnSize.rowSpan)
                + gutter * CGFloat(drawnSize.rowSpan - 1)
        )
    }

    /// Keep it: the camera roll, then the win.
    ///
    /// This is the only place the full-resolution frame exists — `ImageManager`
    /// downscales to 1024px for the block — so it is the only place the camera
    /// roll can be given the real photograph. No second haptic: the button
    /// press already confirmed it, and buzzing again when a background write
    /// lands is two confirmations for one action.
    private func keep(_ image: UIImage) {
        Task { await PhotoLibrarySaver.save(image) }
        onCaptured(image, drawnSize, LocationService.shared.place())
        review = nil
        // Back to one cell for the next shot. A size drawn once is not a
        // preference, and a shutter that stayed wide would make every later
        // photograph a 2x1 nobody asked for.
        drawnSize = .small
    }

    // MARK: - Viewfinder gestures

    /// Pinch to zoom, tap to focus, drag to expose, double tap to flip.
    ///
    /// One transparent layer carrying all four rather than four modifiers
    /// spread over the preview: the guards between them only work if they can
    /// see each other. A pinch also produces a drag translation, so without
    /// `zoomAtPinchStart` in the drag's guard the exposure would swing every
    /// time you zoomed.
    ///
    /// The double tap is `exclusively(before:)` the single one, which costs
    /// the single tap a recognition delay. That is the same trade the native
    /// camera makes and it is unavoidable: nothing can know a tap was single
    /// until the window for a second one has passed.
    private func viewfinderGestures(w: CGFloat, h: CGFloat) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture(count: 2)
                    .onEnded { _ in
                        HapticsEngine.snap()
                        withAnimation(GridConstants.motionSmooth) { camera.flip() }
                        focusPoint = nil
                    }
                    .exclusively(before:
                        SpatialTapGesture(count: 1).onEnded { value in
                            focus(at: value.location)
                        }
                    )
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        let start = zoomAtPinchStart ?? camera.zoom
                        if zoomAtPinchStart == nil { zoomAtPinchStart = start }
                        camera.setZoom(start * value.magnification)
                    }
                    .onEnded { _ in zoomAtPinchStart = nil }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        // Only while the reticle is up, and never during a
                        // pinch — two fingers moving apart is also a drag.
                        guard focusPoint != nil, zoomAtPinchStart == nil else { return }
                        let start = biasAtDragStart ?? camera.exposureBias
                        if biasAtDragStart == nil { biasAtDragStart = start }
                        // Up is brighter. 120pt to a stop, so the whole usable
                        // range is about a screen and a half of travel — far
                        // enough that a shaky thumb does not blow the picture
                        // out, short enough to reach the end.
                        camera.setExposureBias(start + Float(-value.translation.height / 120))
                        focusShownAt = Date()
                    }
                    .onEnded { _ in biasAtDragStart = nil }
            )
            .overlay(alignment: .topLeading) { reticle }
            .frame(width: w, height: h)
    }

    /// The yellow square, and the sun you drag.
    ///
    /// Scaled down into place rather than faded in: the native camera's
    /// reticle arrives by contracting onto the point, which reads as the lens
    /// gathering onto the subject. It dims to 0.4 once it has settled and
    /// leaves after four seconds — long enough to drag the exposure, short
    /// enough not to become part of the picture.
    @ViewBuilder
    private var reticle: some View {
        if let point = focusPoint {
            FocusReticle(bias: camera.exposureBias, range: camera.exposureBiasRange)
                .position(point)
                .transition(.scale(scale: 1.4).combined(with: .opacity))
                .allowsHitTesting(false)
                .task(id: focusShownAt) {
                    try? await Task.sleep(for: .seconds(4))
                    guard !Task.isCancelled else { return }
                    withAnimation(GridConstants.gentleReveal) { focusPoint = nil }
                }
        }
    }

    private func focus(at location: CGPoint) {
        guard let layer = previewBox.layer else { return }
        let devicePoint = layer.captureDevicePointConverted(fromLayerPoint: location)
        camera.focus(at: devicePoint)
        HapticsEngine.tick()
        withAnimation(GridConstants.motionSnappy) { focusPoint = location }
        focusShownAt = Date()
    }

    // MARK: - Guides

    private func guides(w: CGFloat, h: CGFloat, topInset: CGFloat) -> some View {
        // The break holds the wordmark, which is always drawn — so unlike the
        // count it replaced, the line is always broken. The gap is not a
        // rendering artefact: it is the wordmark's space, and the line
        // resuming below it is what makes the break read as deliberate.
        let gapTop = topInset + Header.topPadding - Header.breathing
        let gapBottom = topInset + Header.topPadding + Header.height + Header.breathing

        return ZStack(alignment: .topLeading) {
            // The first vertical is broken where the header crosses it. The
            // gap is not a rendering artefact — it is the header's space, and
            // the line resuming below it is what makes the break read as
            // deliberate rather than as a line that failed to draw.
            // Centred ON the boundary, not started at it. A 1pt line drawn
            // from the third leaves its whole width on one side, which pushes
            // its centre half a point past where the third actually is — small,
            // but it is the difference between the bands measuring equal and
            // measuring a hair unequal, and unequal is what the eye reports as
            // "the middle one looks longer".
            let x0 = round(Guide.verticalX[0] * w) - Guide.width / 2
            Rectangle()
                .fill(Guide.colour)
                .frame(width: Guide.width, height: max(gapTop, 0))
                .offset(x: x0, y: 0)

            Rectangle()
                .fill(Guide.colour)
                .frame(width: Guide.width, height: max(h - gapBottom, 0))
                .offset(x: x0, y: gapBottom)

            Rectangle()
                .fill(Guide.colour)
                .frame(width: Guide.width, height: h)
                .offset(x: round(Guide.verticalX[1] * w) - Guide.width / 2, y: 0)

            ForEach(Guide.horizontalY, id: \.self) { fraction in
                Rectangle()
                    .fill(Guide.colour)
                    .frame(width: w, height: Guide.width)
                    // Rounded to a whole point for the same reason the width
                    // is: a line at a fractional offset is smeared across two
                    // pixel rows and reads lighter than its neighbour.
                    .offset(x: 0, y: round(fraction * h) - Guide.width / 2)
            }
        }
        .frame(width: w, height: h, alignment: .topLeading)
        // The grid dissolves before it reaches the tab bar.
        //
        // Ruled lines running hard into a floating bar is the one place this
        // screen looked pasted together — two systems meeting at an edge
        // neither of them drew. Fading them out over the last stretch is the
        // same move the tower's water makes at the bottom of the blocks: the
        // page stops rather than being cut off.
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 1 - Guide.fadeHeight * 1.6),
                    .init(color: .clear, location: 1 - Guide.fadeHeight * 0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    /// The count, the flip and the flash — one line, in the gap.
    ///
    /// They were three things at three heights: the count at the top left, the
    /// flip 86pt down the right edge, the flash 54pt below that. Nothing lined
    /// up with anything, which is what made the screen read as wonky. On one
    /// bar they are a header, and the break in the grid line is cut to fit it.
    ///
    /// The count sits at exactly the tower's offset — the same padding below
    /// the safe area, the same horizontal inset — so moving between the two
    /// screens does not move the number.
    private func header(topInset: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 0) {
            // Sized to the grid rather than to the page — see
            // `Header.wordmarkSize`.
            StrataWordmark(size: Self.Header.wordmarkSize, color: .white)
                // Legible over whatever the lens is pointing at.
                .shadow(color: .black.opacity(0.40), radius: 10, x: 0, y: 1)

            Spacer(minLength: 0)
        }
        // Top-aligned, and now the box is the wordmark's own height, so
        // top-aligned and centred are the same placement — which is the
        // point: the break holds the word and nothing else, so the word
        // cannot drift inside it.
        .frame(height: Header.height, alignment: .top)
        .padding(.horizontal, GridConstants.horizontalPadding)
        // The preview starts at the very top of the screen now, so the header
        // has to clear the notch itself.
        .padding(.top, topInset + Header.topPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Controls

    private func controls(w: CGFloat, h: CGFloat, topInset: CGFloat, bottomInset: CGFloat) -> some View {
        // An HStack, not five individually `.position`ed children.
        //
        // Each `.position` expands its child to fill the whole container, so
        // the row was five full-screen layers stacked on top of each other and
        // only the last one reliably took a touch. The grid toggle was the
        // first, and it never fired: measured, its accessibility value stayed
        // "off" across two taps while the flash — same helper, same action
        // path — toggled correctly in the same run.
        //
        // A row also makes the arrangement honest: two settings either side of
        // the shutter, symmetrical, inside the arc a thumb already sweeps.
        ZStack(alignment: .bottom) {
            VStack(spacing: 16) {
            // Above the shutter, clear of it. It was an overlay on the row,
            // and the row's top IS the shutter's top — so it sat on the
            // button.
            //
            // Its height is reserved whether or not it is there. The pill
            // comes and goes with the zoom, and a control that appears by
            // pushing the shutter down is a control that moves the one thing
            // on this screen that must not move.
            ZStack { zoomPill }
                .frame(height: 34)
                .animation(GridConstants.motionSnappy, value: camera.zoom)

            ZStack {
            HStack(spacing: 0) {
                // `rectangle.split.3x3`, not `grid`. Both are real SF Symbols,
                // but `grid` is a 3x3 of separate tiles — an app-grid mark —
                // and this is a rectangle divided by two verticals and two
                // horizontals, which is the thing it turns on. Dimmed rather
                // than slashed, because there is no slashed variant; it stays
                // visible and pressable so the guides can always come back.
                glyphButton("rectangle.split.3x3",
                            label: camera.showsGuides ? "Hide the grid" : "Show the grid",
                            identifier: "gridToggle",
                            value: camera.showsGuides ? "on" : "off",
                            dimmed: !camera.showsGuides) {
                    withAnimation(GridConstants.motionSmooth) { camera.showsGuides.toggle() }
                    UserDefaults.standard.set(camera.showsGuides, forKey: "cameraShowsGuides")
                }

                Spacer(minLength: 0)

                glyphButton(camera.isFlashOn ? "bolt.fill" : "bolt.slash.fill",
                            label: camera.isFlashOn ? "Flash on" : "Flash off",
                            identifier: "flashToggle",
                            value: camera.isFlashOn ? "on" : "off") {
                    camera.isFlashOn.toggle()
                }

                Spacer(minLength: 0)

                // A placeholder the size the shutter is at rest. The shutter
                // itself is drawn OVER the row, centred, so growing it moves
                // nothing else.
                Color.clear
                    .frame(width: Self.shutterBounds(.small).width,
                           height: Self.shutterBounds(.small).height)

                Spacer(minLength: 0)

                glyphButton("arrow.triangle.2.circlepath", label: "Switch camera") {
                    withAnimation(GridConstants.motionSmooth) { camera.flip() }
                }

                Spacer(minLength: 0)

                timerButton
            }
            // The four settings step out of the way while you draw.
            //
            // A drawn block runs to 149pt across and the row has about 138 to
            // give, so something has to move — and the honest something is the
            // four controls you are not using at that moment. They are already
            // set; you are taking the picture. Back the instant you let go.
            .opacity(isDrawing ? 0 : 1)
            .allowsHitTesting(!isDrawing)
            .animation(GridConstants.slotSnap, value: isDrawing)

            // **A SIBLING of the row, not an overlay on it.**
            //
            // It was `.overlay { shutter }` on the row, which put the drag
            // gesture inside a subtree whose `allowsHitTesting` flipped the
            // instant the first threshold was crossed. SwiftUI cancels an
            // in-flight gesture when that happens, so `onEnded` never ran and
            // letting go after drawing a bigger block took no photograph at
            // all — the one thing the gesture exists to do.
            //
            // As a sibling its ancestors do not change while the finger is
            // down. It still centres on the row, because the row is full
            // width and its placeholder is centred.
            shutter
            }
            }
            .padding(.horizontal, 44)
            .padding(.bottom, bottomInset + shutterBottomGap)

            if let onClose {
                GlassIconButton(
                    systemName: "xmark",
                    tint: .white,
                    glyphSize: 16,
                    accessibilityLabel: "Close camera",
                    action: onClose
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, GridConstants.horizontalPadding)
                // Below the status bar, not under it: at y=34 in screen
                // coordinates this landed beside the Dynamic Island, drawn but
                // with the system's touch areas over most of it.
                .padding(.top, topInset + Header.topPadding)
            }
        }
        .frame(width: w, height: h, alignment: .bottom)
    }

    /// How far the lens is in, above the shutter.
    ///
    /// iOS Camera puts a row of lens buttons there — 0.5x, 1x, 3x — one per
    /// physical camera. This app uses the wide-angle lens only, so a row of
    /// buttons would be a row of one, and a control offering a single choice
    /// is not a choice. What is left is the part that is true here: a readout
    /// of where the lens is.
    ///
    /// **It is not there at 1x.** At the lens's own field there is nothing to
    /// report and nothing to undo, and a permanent `1x` badge is a label for a
    /// state that is not worth naming. It appears when you pinch and leaves
    /// when you come back.
    ///
    /// **Tapping it returns to 1x**, which is also what makes it leave.
    /// Getting back from 4.7x by pinching outward takes several passes and
    /// usually overshoots; one tap is the undo, and it is the same gesture
    /// Apple gives the lens buttons.
    @ViewBuilder
    private var zoomPill: some View {
        if camera.canZoom, camera.zoom > 1.005 {
            Button {
                HapticsEngine.lightTap()
                withAnimation(GridConstants.motionSnappy) { camera.setZoom(1) }
            } label: {
                Text(Self.zoomLabel(camera.zoom))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 34)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            // After the layout, not before: the material takes its shape from
            // the final frame.
            .zoomGlass()
            // It grows out of the shutter's line rather than fading in on the
            // spot, which is what makes it read as belonging to the gesture
            // that produced it.
            .transition(.scale(scale: 0.7).combined(with: .opacity))
            .accessibilityLabel("Zoom \(Self.zoomLabel(camera.zoom))")
            .accessibilityHint("Returns to 1x")
        }
    }

    /// `1x`, `2.4x` — one decimal, and none when it is a round number, which
    /// is what iOS Camera does.
    static func zoomLabel(_ factor: CGFloat) -> String {
        let rounded = (factor * 10).rounded() / 10
        return rounded == rounded.rounded()
            ? String(format: "%.0fx", rounded)
            : String(format: "%.1fx", rounded)
    }

    /// Off / 3s / 10s, cycling, exactly the set iOS Camera offers.
    private var timerButton: some View {
        glyphButton(camera.timerSeconds == 0 ? "timer" : "timer",
                    label: camera.timerSeconds == 0 ? "Timer off" : "Timer \(camera.timerSeconds) seconds",
                    identifier: "timerToggle",
                    value: "\(camera.timerSeconds)",
                    dimmed: camera.timerSeconds == 0) {
            withAnimation(GridConstants.motionSmooth) {
                camera.timerSeconds = camera.timerSeconds == 0 ? 3 : (camera.timerSeconds == 3 ? 10 : 0)
            }
            UserDefaults.standard.set(camera.timerSeconds, forKey: "cameraTimerSeconds")
        }
        .overlay(alignment: .bottom) {
            // The chosen delay, under the glyph — iOS shows the number too,
            // because "timer on" is not the same as "timer set to what".
            if camera.timerSeconds > 0 {
                Text("\(camera.timerSeconds)")
                    .font(Typography.numeral(10))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 4)
                    .offset(y: 4)
                    .allowsHitTesting(false)
            }
        }
    }

    /// No box.
    ///
    /// They were small blocks for a while, to rhyme with the shutter. Three
    /// bordered objects in a row turned the quietest part of the screen into
    /// the busiest, and a setting does not need a container to be a setting —
    /// the glyph is the control. The shutter keeps its rim because it is the
    /// one thing here that is a button rather than a toggle.
    /// The label belongs ON the button.
    ///
    /// These used to be `.accessibilityLabel(...)` applied after `.position()`,
    /// which wraps the button in a container that fills the ZStack — so the
    /// label was attached to the wrapper, not the control, and it did not
    /// track the state it was describing. The grid toggle read "Show the grid"
    /// whether the grid was on or off, which is also why it looked like it
    /// could not be turned back on.
    private func glyphButton(_ symbol: String,
                             label: String,
                             identifier: String? = nil,
                             value: String? = nil,
                             dimmed: Bool = false,
                             action: @escaping () -> Void) -> some View {
        Button {
            HapticsEngine.tick()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 21, weight: .regular))
                // Dimming lives on the GLYPH, not as an `.opacity` over the
                // button. A toggle wrapped in `.opacity(...)` stopped
                // receiving taps entirely — measured: its action never ran,
                // proven by having it toggle the flash as a probe and watching
                // the flash not move, while the flash's own button (identical
                // helper, no opacity modifier) toggled every time.
                .foregroundStyle(.white.opacity(dimmed ? 0.5 : 1))
                .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 1)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier ?? symbol)
        .accessibilityValue(value ?? "")
    }

    /// A block, not a circle.
    ///
    /// Everything this app makes is a block and this is the button that makes
    /// one, so it is a rounded square at the block's own 14.7% corner ratio —
    /// the same ratio every block on the tower uses, so it reads as the same
    /// object at a different size.
    ///
    /// A rim and a fill, so pressing it compresses the fill inside a rim that
    /// stays put.
    /// True while the shutter is showing something bigger than one cell.
    private var isDrawing: Bool { drawnSize != .small }

    /// The shutter's outer bounds at a given size — rim included.
    ///
    /// The rim changes shape with the fill, so a 2x1 draw makes the whole
    /// control a rectangle and a 2x2 makes it a bigger square. An inner square
    /// growing inside a fixed circle-analogue said the size in a language you
    /// had to learn; the button BECOMING the block says it in the app's own.
    static func shutterBounds(_ size: BlockSize) -> CGSize {
        let cell: CGFloat = 66
        let gutter = cell * GridConstants.spacing / GridConstants.blockReferenceCell
        let rim: CGFloat = 14
        return CGSize(
            width: cell * CGFloat(size.columnSpan)
                + gutter * CGFloat(size.columnSpan - 1) + rim,
            height: cell * CGFloat(size.rowSpan)
                + gutter * CGFloat(size.rowSpan - 1) + rim
        )
    }

    private var shutter: some View {
        let bounds = Self.shutterBounds(drawnSize)
        let inner = CGSize(width: bounds.width - 14, height: bounds.height - 14)
        let outerRadius = min(bounds.width, bounds.height) * 0.147
        return ZStack {
            RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                .strokeBorder(.white, lineWidth: 1)
                .frame(width: bounds.width, height: bounds.height)

            // ONE block, in the shape you are drawing.
            //
            // It was a grid of cells — two squares for a 2x1, four for a 2x2 —
            // which was wrong twice over: it read as a keypad, and a 2x1 in
            // this app is not two blocks, it is one block two cells wide.
            RoundedRectangle(cornerRadius: min(inner.width, inner.height) * 0.147,
                             style: .continuous)
                .fill(.white)
                .frame(width: inner.width, height: inner.height)
                .scaleEffect(shutterScale)
        }
        .animation(GridConstants.slotSnap, value: drawnSize)
        .contentShape(RoundedRectangle(cornerRadius: outerRadius, style: .continuous))
        .gesture(draw)
        .accessibilityLabel("Take photo")
        .accessibilityValue(drawnSize.effortLabel)
        .accessibilityAddTraits(.isButton)
        // VoiceOver cannot draw a block out, so the plain action takes the
        // one-cell shot rather than leaving the control unusable.
        .accessibilityAction { shutterPressed() }
    }

    /// Press, and pull to draw the block out — the tower's gesture, on the
    /// camera's button.
    ///
    /// A tap is a drag of zero distance, so this one gesture sees both and has
    /// to tell them apart. Under 6pt of travel is a tap: the ordinary shot,
    /// and the only thing that respects the timer. Anything further was a
    /// draw, and a draw shoots the moment you let go.
    private var draw: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !shutterDown {
                    shutterDown = true
                    HapticsEngine.tick()
                }
                guard !reduceMotion else { return }
                let (lateral, up) = BlockSizeDraw.axes(translation: value.translation)
                let next = BlockSizeDraw.size(lateral: lateral, up: up, from: drawnSize)
                guard next != drawnSize else { return }
                // A haptic on every crossing, in both directions — the only
                // unambiguous signal that a size actually committed.
                HapticsEngine.snap()
                withAnimation(GridConstants.slotSnap) { drawnSize = next }
            }
            .onEnded { value in
                // A gesture that never began cannot take a photograph.
                // `minimumDistance: 0` can deliver `onEnded` with no matching
                // `onChanged` when the view rebuilds under a touch.
                guard shutterDown else { return }
                shutterDown = false
                // **Every release goes through the same door.**
                //
                // A draw used to skip the countdown and shoot immediately, on
                // my reasoning that "holding a shape in your fingers for ten
                // seconds is not a thing anybody wants". That reasoning was
                // simply wrong, and the owner caught it: "with the timer on,
                // even if you resize the win the timer should still go — why
                // is it only when you do the small win tap. same with flash".
                //
                // Nobody holds anything. `drawnSize` is committed by the time
                // you lift, so the countdown runs against a size that is
                // already decided and the shutter fires with it. Skipping it
                // meant the timer worked on a 1x1 and silently did not on a
                // 2x1 — the same control behaving differently depending on how
                // hard you pulled, which is the definition of a control you
                // cannot trust. The flash rode on the same path and was lost
                // the same way.
                //
                // The `moved` test still matters, but only for what it
                // originally fixed: a press that never travelled is a TAP, and
                // a tap on a running countdown cancels it. A draw is never a
                // cancel — you cannot draw a size by accident.
                let moved = hypot(value.translation.width, value.translation.height) > 6
                if moved, countdownTask == nil {
                    // A fresh draw: start the timer if there is one, exactly
                    // as a tap would.
                    shutterPressed()
                } else if moved {
                    // Drawing while a countdown runs re-sizes the shot in
                    // flight rather than cancelling it. The count keeps going.
                } else {
                    shutterPressed()
                }
            }
    }

    // MARK: - The warm flash

    /// A ring light, not a flashbulb.
    ///
    /// The front camera has no lamp, so its flash is the screen — and what you
    /// put on the screen decides what the photo looks like. Two decisions,
    /// both of which have a reason:
    ///
    /// **Warm, not white.** A phone screen at full white is around 6500K, which
    /// on skin reads clinical and blue and is why front-flash selfies look
    /// washed out. This is roughly 3400K — the warm end of a ring light, and
    /// the same choice Snapchat makes.
    ///
    /// **A ring, not a wash.** The brightness sits at the perimeter and falls
    /// off toward the middle, which is what a ring light physically is: light
    /// arriving from around the lens rather than through it. Flat light from
    /// dead centre removes every shadow that gives a face shape; light from the
    /// rim keeps the modelling and puts the catchlight in the eye.
    /// The warm light, at a given base-fill strength.
    ///
    /// Two things use it. The CAPTURE flash wants the full fill, because at
    /// that moment nothing matters except photons on the face. The MODELLING
    /// ring is held on while the front flash is armed so you can see yourself
    /// before you shoot — and there the fill has to stay low, or the overlay
    /// whites out the very preview it exists to light.
    private func warmLight(fillOpacity: Double) -> some View {
        GeometryReader { geo in
            ZStack {
                // 1. Fill. A base wash so the whole face is lifted out of the
                //    dark rather than only its edges — without this a pure
                //    ring carves the face into a bright outline and a dim
                //    middle, which is a horror-film key, not a beauty light.
                // 0.72, not 0.42. On a phone every photon comes from the same
                // plane a foot from the face, so a dark middle does not
                // "shape" anything the way a physical ring does — it just
                // throws away light. Measured at 0.42 the centre sat at
                // luminance 96 against edges of 164-243, which is a dim flash
                // with a bright border. The ring still does its real job on
                // top of this: the catchlight in the eye.
                Self.warmFill
                    .opacity(fillOpacity)

                // 2. The ring. Brightest in a band near the screen's edge and
                //    genuinely absent through the middle third, because that
                //    is what a ring light IS: light arriving from around the
                //    lens rather than through it. Flat light from dead centre
                //    removes the shadow that gives a face shape; light from
                //    the rim keeps the modelling and puts the catchlight in
                //    the eye.
                // ELLIPTICAL, not radial.
                //
                // A circular gradient on a 402x874 screen never reaches the
                // left and right edges: measured, a point 10% in from the side
                // was pixel-identical to the centre, so the "ring" was lighting
                // the top and bottom only. An elliptical gradient takes its
                // radii from the view's own proportions, so the bright band
                // lands on all four edges of whatever shape the screen is.
                EllipticalGradient(
                    stops: [
                        .init(color: .clear, location: 0.00),
                        .init(color: .clear, location: 0.30),
                        .init(color: Self.warmRing.opacity(0.30), location: 0.55),
                        .init(color: Self.warmRing.opacity(0.90), location: 0.82),
                        .init(color: Self.warmRing, location: 1.00)
                    ],
                    center: .center,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.62
                )
                .blur(radius: 28)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }

    /// The front flash's modelling ring, and the capture flash over it.
    private var warmFlash: some View {
        ZStack {
            warmLight(fillOpacity: Self.ringFill)
                .opacity(ringIsArmed ? Self.ringLevel : 0)
                .animation(.easeOut(duration: 0.22), value: ringIsArmed)
            warmLight(fillOpacity: Self.captureFill)
                .opacity(flashOpacity)
        }
    }

    /// Whether the ring light is lit: the flash is on and the lens is the one
    /// pointing at you. There is nothing to model with the back camera, which
    /// has a real flash.
    private var ringIsArmed: Bool {
        #if DEBUG
        if DebugHarness.holdsRingLight { return true }
        #endif
        return camera.isFlashOn && camera.usesScreenFlash
    }

    /// Held on, the fill has to stay low or the overlay hides your face
    /// instead of lighting it. The ring itself does the work.
    private static let ringFill: Double = 0.10
    private static let ringLevel: Double = 0.92
    /// At the moment of capture nothing matters but light on the face.
    private static let captureFill: Double = 0.72

    /// ~3400K. A phone screen at full white is about 6500K, which on skin
    /// reads clinical and blue and is why front-flash selfies look washed out.
    /// This is the warm end of a ring light.
    private static let warmFill = Color(red: 1.00, green: 0.90, blue: 0.78)
    /// A touch brighter and a touch less saturated than the fill, so the rim
    /// reads as the source and the middle as what it lights.
    private static let warmRing = Color(red: 1.00, green: 0.95, blue: 0.88)

    // MARK: - Firing

    /// A press either fires now or starts the countdown, and a press DURING a
    /// countdown cancels it — which is what iOS Camera does, and the only
    /// sensible answer once you have walked into frame and changed your mind.
    private func shutterPressed() {
        if countdownTask != nil {
            cancelCountdown()
            return
        }
        guard camera.timerSeconds > 0 else { fire(); return }
        HapticsEngine.tick()
        countdown = camera.timerSeconds
        countdownTask = Task { @MainActor in
            var remaining = camera.timerSeconds
            while remaining > 0 {
                // One tick a second, and a haptic with it — the count is on
                // screen but you are usually looking at the lens, not at it.
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                remaining -= 1
                countdown = remaining > 0 ? remaining : nil
                if remaining > 0 { HapticsEngine.tick() }
            }
            countdownTask = nil
            fire()
        }
    }

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        countdown = nil
        HapticsEngine.lightTap()
    }

    private func fire() {
        guard !camera.isCapturing else { return }
        HapticsEngine.snap()

        withAnimation(.easeOut(duration: 0.08)) { shutterScale = 0.86 }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.6).delay(0.08)) {
            shutterScale = 1
        }

        // The screen has to be BRIGHT before the shutter opens, not with it —
        // the sensor is already metering by the time a simultaneous flash
        // arrives, so a flash fired on the same frame lights nothing.
        //
        // Brightness is already at 1.0 here: arming the flash lights the
        // modelling ring, and that is what raises it. `fire` only has to add
        // the fill.
        let needsScreenFlash = camera.isFlashOn && camera.usesScreenFlash
        if needsScreenFlash {
            withAnimation(.easeOut(duration: 0.12)) { flashOpacity = 1 }
        }

        Task { @MainActor in
            if needsScreenFlash {
                // Long enough for auto-exposure to settle on the new light.
                try? await Task.sleep(for: .milliseconds(220))
            }
            camera.capture { image in
                if needsScreenFlash {
                    // Back to the ring, not to darkness — the flash is still
                    // armed, so the light you were composing under stays.
                    withAnimation(.easeOut(duration: 0.22)) { flashOpacity = 0 }
                }
                guard let image else {
                    // No photograph, so nothing was drawn for. Leaving the
                    // shutter wide would make the NEXT shot inherit a size
                    // nobody asked for.
                    withAnimation(GridConstants.slotSnap) { drawnSize = .small }
                    return
                }
                HapticsEngine.success()
                // Nothing is kept yet.
                //
                // The camera roll used to be written HERE, before anything was
                // confirmed — which was fine while there was no way to reject
                // a shot and became a bug the moment there was: every photo
                // you retook would already be in your library. It happens on
                // "Use Photo" now.
                withAnimation(GridConstants.gentleReveal) { review = image }
            }
        }
    }
}

/// The live preview, as a layer rather than a view.
///
/// `AVCaptureVideoPreviewLayer` is the only thing that can render the session,
/// and it has to be resized by hand — a layer does not participate in Auto
/// Layout, so without this it keeps whatever bounds it had when it was made.
/// Somewhere to keep the preview layer.
///
/// A plain reference box, not `@Observable`: nothing re-renders when the layer
/// arrives, it is only read inside a gesture handler that runs long after.
@MainActor
final class PreviewLayerBox {
    var layer: AVCaptureVideoPreviewLayer?
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let box: PreviewLayerBox

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        box.layer = view.previewLayer
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        box.layer = uiView.previewLayer
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}


// MARK: - Focus reticle

/// The native camera's focus square, and its exposure sun.
///
/// Yellow because that is what a focus reticle is on this platform, and this
/// is the one place in the app where matching the system beats matching the
/// app: a person pointing a camera has a lifetime of knowing what a yellow
/// square on a viewfinder means, and spending that to make the reticle pink
/// would buy nothing.
private struct FocusReticle: View {
    let bias: Float
    let range: ClosedRange<Float>

    private static let side: CGFloat = 74
    private static let travel: CGFloat = 34

    /// Where the sun sits beside the square. Up is brighter, which is the
    /// direction the drag goes.
    private var sunOffset: CGFloat {
        guard range.upperBound > range.lowerBound else { return 0 }
        let span = Double(max(abs(range.lowerBound), abs(range.upperBound)))
        let unit = span == 0 ? 0 : Double(bias) / span
        return -CGFloat(max(-1, min(1, unit))) * Self.travel
    }

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(Color(red: 1, green: 0.82, blue: 0.24), lineWidth: 1.4)
                .frame(width: Self.side, height: Self.side)

            Image(systemName: "sun.max.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(red: 1, green: 0.82, blue: 0.24))
                .offset(y: sunOffset)
                .animation(GridConstants.motionSnappy, value: sunOffset)
                .shadow(color: .black.opacity(0.35), radius: 3)
        }
        // The square is what is pointed at, so the pair has to hang off the
        // square's centre rather than the row's — otherwise tapping puts the
        // gap between them on the subject.
        .offset(x: 12)
    }
}


private extension View {
    /// Liquid Glass where there is any, and the closest thing there was
    /// before it.
    ///
    /// `.interactive()` because this one is a button — the skill's rule is
    /// that the interactive variant is an affordance and putting it on
    /// decoration claims something untrue.
    @ViewBuilder
    func zoomGlass() -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            self.background(.ultraThinMaterial, in: Capsule())
        }
    }
}
