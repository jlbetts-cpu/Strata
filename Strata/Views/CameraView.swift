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
    var onCaptured: (UIImage, BlockSize, WinPlace?, CGPoint) -> Void = { _, _, _, _ in }
    var onClose: (() -> Void)? = nil
    /// True when nothing else is on screen — presented as its own sheet rather
    /// than as a tab with a bar beneath it.
    var fillsScreen: Bool = false
    /// The crews of the win this photo is for, when the camera is opened
    /// from Add Win. Its ticks are the sheet's own, so a crew ticked there
    /// (or the crew whose tower opened it) is still ticked here, and a
    /// change here is the sheet's change. Nil from the tower's camera, which
    /// keeps last time's choice (the owner, 2026-10-02: "it unchecks the
    /// slot when you are adding the photo").
    var crews: Binding<Set<CrewID>>? = nil

    @State private var camera = CameraService()
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
    /// Your head on the photo being reviewed, if you added it. See
    /// `HeadSticker`.
    @State private var sticker: StickerPlacement?
    /// **Every shot starts on none** (the owner: "the default filter should
    /// always be on none"). A look is a decision about this photograph, not a
    /// setting that follows you: a remembered one means the picture you take
    /// tomorrow is graded by something you chose today and forgot.
    @State private var lookRaw = FilmLook.Kind.none.rawValue
    /// Who sees this photograph, decided where it is taken (the owner,
    /// 2026-10-02: posting a photo is when you decide who sees it). The
    /// sticky choice itself, so the win that follows goes where these say.
    @State private var crewChoice: Set<CrewID> = []
    /// Whether the looks panel is open. Shut on every appearance: it is a
    /// decision, not a state to come back to.
    /// The review photograph with the chosen look on it, at screen size. The
    /// real one is rendered full size only when the photograph is kept.
    @State private var looked: UIImage?
    /// Which part of the photograph the block will show, as a fraction away
    /// from the middle. Moved by dragging the picture on the review.
    @State private var crop: CGPoint = .zero
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
    // **The live graded viewfinder is gone, at the owner's call.**
    //
    // 2026-09-23: "I don't think I like the live film simulation or the
    // button, let's remove for now completely." So the viewfinder is the
    // scene as the lens sees it again, and a look is applied to the
    // photograph at the shutter, which is what it did before today and what
    // `FilmLookStrip` on the review screen still does.
    //
    // The lens picker, the front flash change and the ruled thirds lines all
    // came in the same pass and all stay: he asked for those.
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
        static let colour = AppColors.onDarkQuiet
        static let width: CGFloat = 1
        // **`fadeHeight` is gone.** It was the bottom dissolve expressed as a
        // fraction of the frame, which is the wrong unit for it: the thing the
        // grid has to stop short of is the control row, and the row is placed
        // in points from the bottom edge. `guides` solves it from the row now.
    }

    /// **The line the top of this screen is measured from.**
    ///
    /// There is no header any more — the wordmark that was one is off, and the
    /// grid runs unbroken through where it stood. What the name still buys is
    /// the shared line: the countdown and the shutter row both measure from
    /// here, so moving between this screen and the tower does not move them.
    private enum Header {
        /// It used to hard-code the tower's 4pt, which only aligned the two
        /// layout BOXES — the type inside them is a different size, so the ink
        /// did not line up.
        static var topPadding: CGFloat {
            // Artwork, not type — see `headerArtworkTopPadding`.
            GridConstants.headerArtworkTopPadding
        }
        // **`wordmarkSize`, `height` and `breathing` are gone with the
        // wordmark.** They were three numbers solved against each other — a cap
        // height, the gap cut to it, and the air either side — and all three
        // existed to place one word over a lens. What is left is `topPadding`,
        // which the shutter row and the countdown still measure from.
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


    /// Whether the arrival dissolve has finished. See the overlay on the body.
    @State private var hasArrived = false

    var body: some View {
        #if DEBUG
        let _ = PerfProbe.count("CameraView")
        #endif
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

                // **What a refused camera says, instead of saying nothing.**
                //
                // Over the preview rather than instead of it, so the one
                // layout serves both states and nothing below has to move.
                if camera.isDenied { accessRefused }

                // The gestures the native camera has, on the viewfinder and
                // under the chrome, so the buttons still take their own taps.
                viewfinderGestures(w: w, h: h)

                // Kept mounted and ruled in or out, never inserted and
                // removed. See `guides`.
                // **Not while the camera is refused.** The thirds are for
                // composing a frame and there is no frame, so they drew as
                // two lines through the middle of the sentence explaining
                // that. Same rule the guides already follow: they are for the
                // picture, not for the screen.
                guides(w: w, h: h, bottomInset: bottomInset,
                       shown: camera.showsGuides && !camera.isDenied)
                    .allowsHitTesting(false)

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
                        .legibleOnImagery(display: true)
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
        // **THE SCREEN DISSOLVES IN INSTEAD OF CUTTING.**
        //
        // The owner, 2026-09-30: "the transitions of the screens are still a bit
        // off — the Wins screen to the camera loads out really sudden, there is
        // no clean transition."
        //
        // A `TabView` switches instantly and cannot be asked not to, and the two
        // screens either side of this particular switch are the furthest apart
        // in the app: a clean white page and a near-black viewfinder. The cut
        // itself is only half of what reads as sudden — the other half is that
        // the lens takes a moment to produce a frame, so the first thing that
        // arrives is not the camera, it is BLACK, and then the camera appears
        // inside it a beat later. Two hard edges, a tenth of a second apart.
        //
        // This covers both with one dissolve. The page's own ground is held over
        // the whole screen and faded out across `--dur-reveal`, so the tab
        // arrives as the white page you were already looking at and the
        // viewfinder comes up THROUGH it. Nothing has to know when the session
        // starts: by the time the cover is gone the frames are there, and if
        // they are not, what is underneath is the dark ground rather than a cut
        // to it.
        //
        // It cannot be done on the way out — the tab unmounts — and it does not
        // need to be. Leaving goes to a page that is already drawn.
        .overlay {
            if !hasArrived {
                WarmBackground()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .task {
            // One frame's grace before the fade starts, so the cover is
            // actually on screen for the first composite rather than being
            // animated from a state nobody saw.
            await Task.yield()
            // **This is a check-10 failure and it STAYS. Reviewed 2026-10-01.**
            //
            // `docs/screen-audit.md` check 10 is "anything that animates
            // because it appeared fails", and `docs/motion-audit.md` §4.2 names
            // this site. It is the only one of the six it calls defensible, and
            // the reason is two lines up this file: **the owner asked for it by
            // name** ("the Wins screen to the camera loads out really sudden,
            // there is no clean transition"). Taking it off restores exactly
            // the thing he complained about, and a check cannot overrule the
            // person the check is for. It is Reduce Motion gated, it covers two
            // hard edges rather than decorating one, and nothing under it can
            // be interacted with. Written down here rather than only in the
            // audit so the next pass does not re-derive it from the rubric.
            //
            // **What DID change is the number.** It was a typed
            // `.easeOut(duration: 0.36)`, which the audit's other half is about:
            // the app's longest fade outside the heads' float, on a value that
            // existed nowhere else in the app. `mapFade` is the same curve one
            // rung down, and its own doc describes this case in general terms —
            // "long enough to read as a change rather than a cut, short enough
            // to be finished by the time your eye has moved to it". Its name is
            // where it was first needed, not what it means.
            //
            // The 60ms is not load-bearing: the cover is not timed against the
            // lens. `camera.start()` is awaited AFTER this line, so the fade is
            // over long before a first frame on any device, and the comment
            // above already says what happens if it is not — what is underneath
            // is the dark ground rather than a cut to it. **Unverified on a
            // real lens**: the simulator has no capture device, so what this
            // reveals here is the dark ground and never a camera frame.
            withAnimation(reduceMotion ? nil : GridConstants.mapFade) {
                hasArrived = true
            }
            await camera.start()
            // **After `start`, never beside it.** A session that is not
            // configured cannot take an output, and mutating one underneath a
            // `startRunning` raises an Objective-C exception, which is a
            // termination rather than an error. `CameraPreviewFrames` waits
            // for the session to be running before it touches anything; if it
            // never attaches, no frames arrive, the overlay stays hidden and
            // this is the camera exactly as it was before.
            //
        }
        .onChange(of: lookRaw) { _, raw in
        }
        // The review covers the viewfinder completely, and the same phone is
        // busy grading the photograph that was just taken. Nothing is drawn
        // under it.
        .onChange(of: review == nil) { _, composing in
        }
        // The ring owns screen brightness while it is lit. It is the only
        // thing that makes the overlay actually EMIT: a warm wash on a screen
        // at 30% lights nothing.
        .onChange(of: ringIsArmed) { _, armed in setRingBrightness(armed) }
        .onAppear { if ringIsArmed { setRingBrightness(true) } }
        #if DEBUG
        .onAppear {
            if let size = DebugHarness.openReviewSize {
                drawnSize = size
                review = DebugHarness.reviewPhoto ?? DebugHarness.placeholderPhoto()
                if DebugHarness.placesReviewSticker, let photo = review {
                    sticker = StickerPlacement(crop: BlockCropOutline.crop(photo: photo.size, block: size),
                                               photoAspect: photo.size.width / max(photo.size.height, 1))
                }
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
            // **Detached BEFORE the session is stopped**, while it is still
            // running and there is nothing in flight on the service's own
            // queue to collide with. See `CameraPreviewFrames.detach`.
            camera.stop()
            // A panel is a decision in progress, and leaving the screen ends
            // it. Coming back to an open tray would be the app remembering
            // something nobody asked it to.
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
    /// **The camera tab, when the answer was no.**
    ///
    /// The owner, on build 33 from internal TestFlight: "why when I'm testing
    /// it on internal I just get a blank black screen?"
    ///
    /// This is that screen. `CameraService.start` does
    /// `guard isAuthorized else { return }` and returns, so the session never
    /// runs, the preview layer has nothing to draw and the app's LAUNCH TAB is
    /// a black rectangle with the wordmark and a dead shutter on it. A tester
    /// who taps Don't Allow gets it on every launch from then on, with nothing
    /// anywhere saying why or what to do, and on a phone it is indistinguishable
    /// from an app that failed to start.
    ///
    /// Three lines and one button, in the viewfinder's own register: white on
    /// black, the app's ink is for the page and would be invisible here.
    ///
    /// **The glass capsule is gone, and the reason it was wrong is written at
    /// the top of `GlassIconButton.swift`.** That file's one rule is: before
    /// adding a caller, answer what is UNDERNEATH it. "A viewfinder" was the
    /// answer given here, and on this state it is not true: the session never
    /// started, so there is no scene, no refraction and nothing for the
    /// material to be a material over. `GlassRecipe.onPage` documents the same
    /// failure in the other direction: `.regular` over a smooth near-white
    /// field collapses to a flat opaque capsule, because blurring a flat field
    /// returns the same flat field.
    ///
    /// Measured on the built screen, over pure black: the capsule rendered
    /// rgb(19, 19, 19) against an rgb(0, 0, 0) ground, which is **1.13:1** on a
    /// 3:1 floor for a shape. It was not a quiet container, it was an absent
    /// one, and nothing about it could be tuned toward 3:1 without it becoming
    /// a 36% grey slab on a black screen. The word carries the button at
    /// 21:1 and takes the app's press response, which is what every plain
    /// action button on the platform is.
    ///
    /// It does not try to re-ask. Once the answer is no, iOS will not present
    /// the prompt again, and a button that looked like it might is worse than
    /// one that says where the switch really is.
    private var accessRefused: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: GridConstants.gapItem) {
                // **"cannot see" is out.** Head and camera copy in this app
                // never reads as watching, and "see" beside "camera" is the
                // exact register that rule guards. It was also simply wrong
                // about the fault: the lens is there and working, the app has
                // not been allowed to use it, and naming the permission is
                // what makes the button below make sense.
                //
                // **And the name is asked of the bundle** (2026-10-01). Both
                // lines read "Strata" while the built `Info.plist` has carried
                // a `CFBundleDisplayName` of **Sturdy** since the rename began,
                // so the screen whose whole job is to send somebody to a row in
                // Settings was naming a row that is not there. See `AppName`
                // in `MainAppView`.
                Text("\(AppName.display) cannot use the camera")
                    .font(Typography.screenTitle)
                    .foregroundStyle(.white)
                Text("A win can be a photograph. Turn the camera on for \(AppName.display) in Settings and this becomes the viewfinder.")
                    .font(Typography.bodyLarge)
                    .foregroundStyle(AppColors.onDarkSecondary)
                    .padding(.bottom, GridConstants.gapItem)
                Button {
                    HapticsEngine.lightTap()
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                } label: {
                    Text("Open Settings")
                        // The middle tier, not the body tier. It was
                        // `bodyLarge`, the same size and weight as the
                        // sentence above it, so the only thing separating the
                        // action from the explanation was that one was white
                        // and one was 75% white. `headerSmall` is the tier the
                        // review screen's Retake and Use Photo are set in, so
                        // the camera's actions are one size everywhere.
                        .font(Typography.headerSmall)
                        .foregroundStyle(.white)
                        .padding(.horizontal, GridConstants.gapWide)
                        // Unchanged: the drawn word is the size it is drawn,
                        // the thing a thumb has to find is 44.
                        .frame(height: GlassIconButton.defaultSide)
                        .contentShape(Rectangle())
                }
                // `.pressWord`, not `.press`: the file's own note says a word
                // at 6% reads as a wobble, so it moves less and dims more.
                .buttonStyle(.pressWord)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, GridConstants.gapWide)
        }
        // Above the preview, below the chrome: the shutter and the tab bar
        // stay reachable, so the way out of this screen is where it always is.
        .transition(.opacity)
    }

    private func reviewLayer(image: UIImage, topInset: CGFloat,
                             bottomInset: CGFloat) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // **THE SPACERS HAD NO MINIMUM AND A PORTRAIT SHOT USES EVERY
                // POINT, SO THE PICTURE LANDED ON THE CHROME.**
                //
                // Measured on the built review at 402x874 with the 3:4 frame a
                // phone actually produces in portrait: the photograph ran
                // 80.7 to 603.3 and the first film-look swatch began at 604.
                // **A 0.7pt gap**, on a screen where every other gap is 24 or
                // 40. It was not a tuning miss, it was the spacers: at
                // `minLength: 0` the picture is free to take the entire region
                // and a 3:4 one does, so the bottom spacer resolves to nothing
                // and the strip is simply the next thing after the photograph.
                // The side margins told the same story from the other end:
                // 5.0pt left and 5.3pt right, which is not "edge to edge", it
                // is edge to edge missing by a sliver, and a sliver reads as a
                // misalignment rather than as a margin.
                //
                // `gapLabel` as the floor on both, which is the gap between a
                // heading and what it heads and the smallest one on this
                // screen. It costs the picture 32pt of height, so a 3:4 frame
                // goes from 391.7 x 522.7 to 367.7 x 490.3: 16 above, 16
                // below, 17.2 either side. A print with even air on four sides
                // rather than one touching two things and nearly touching two
                // more.
                //
                // **A fuller 24 was tried and is wrong here.** It takes the
                // picture to 355.7 wide, 9% narrower, and the photograph is
                // the subject of this screen; buying an eight-point gap with
                // that is the wrong trade.
                Spacer(minLength: GridConstants.gapLabel)

                // **As large as the air allows, not literally to the edges.**
                //
                // It was an inset print with the app's surface radius, which
                // is right in the VIEWER — a photograph you are revisiting is
                // an object on a page — and wrong here. This is the frame you
                // just took, still warm. So it stays as big as it can be and
                // takes no radius, and the only thing that changed is that its
                // room is now guaranteed rather than left over.
                Image(uiImage: looked ?? image)
                    .resizable()
                    .aspectRatio(image.size.width / max(image.size.height, 1),
                                 contentMode: .fit)
                    // What the block will show of it: a hairline, nothing
                    // dimmed. It changes with the size you drew, and with
                    // where you drag it.
                    .overlay {
                        BlockCropOutline(crop: BlockCropOutline.crop(photo: image.size, block: drawnSize),
                                         offset: crop)
                    }
                    // Over the photograph's own frame, so the head's place and
                    // the block's window are both places in the picture.
                    .overlay {
                        HeadStickerOverlay(
                            rig: sticker == nil ? nil : HeadStore.shared.headForSticker,
                            placement: $sticker,
                            crop: $crop,
                            cropRange: BlockCropOutline.range(
                                for: BlockCropOutline.crop(photo: image.size, block: drawnSize)),
                            look: FilmLook.look(FilmLook.Kind(rawValue: lookRaw) ?? .none))
                    }
                    // **The size control hangs off the PICTURE, not off the
                    // top of the screen.**
                    //
                    // It was a second `VStack` in this `ZStack` padded to
                    // `topInset + Header.topPadding`, which put it at a fixed
                    // 81pt down the screen whatever the photograph did. With
                    // the 3:4 frame that lands at exactly the photograph's own
                    // top edge (measured: capsule top 81.0 against picture
                    // top 80.7), so the control looked glued to the edge of
                    // the print rather than floating in it. With a LANDSCAPE
                    // 4:3 frame it is worse and it is a plain bug: the picture
                    // is 301.5pt tall and centres at y 191.4, leaving the
                    // control stranded 110pt above it in the black, pointing
                    // at nothing.
                    //
                    // An overlay on the image fixes both at once, because the
                    // image's layout frame under `.aspectRatio(_:.fit)` IS the
                    // drawn picture's rectangle, the same fact the crop
                    // outline above already relies on. Declared last so it
                    // takes its own taps: the head sticker's drag covers the
                    // whole picture and later siblings are hit first.
                    //
                    // `gapLabel` inside the top edge, the same floor the
                    // spacers above and below the picture now use, so the
                    // control sits in the print rather than on its rim.
                    .overlay(alignment: .top) {
                        sizePicker.padding(.top, GridConstants.gapLabel)
                    }

                Spacer(minLength: GridConstants.gapLabel)

                FilmLookStrip(photo: image, selection: Binding(
                    get: { FilmLook.Kind(rawValue: lookRaw) ?? .none },
                    set: { lookRaw = $0.rawValue }))
                    .padding(.bottom, GridConstants.gapWide)

                CrewPicker(selection: crews ?? Binding(get: { crewChoice },
                                                       set: { crewChoice = $0; CrewChoice.save($0) }),
                           onDark: true, mentionsPhotos: true)
                    .padding(.bottom, GridConstants.gapTight)
                    // Read fresh each review: the choice may have changed in
                    // Add Win since this view was built.
                    .onAppear { if crews == nil { crewChoice = CrewChoice.load() } }

                HStack(spacing: 0) {
                    Button {
                        HapticsEngine.tick()
                        withAnimation(GridConstants.motionSnappy) {
                            review = nil
                            // **Retake means retake.** The size you drew was
                            // for the shot you just rejected, and keeping it
                            // meant coming back to a shutter already stretched
                            // into a shape you did not ask for this time. The
                            // owner: "when retaking a photo it shouldnt stay
                            // on the size, it should go back to the normal
                            // camera with all the options."
                            drawnSize = .small
                            sticker = nil
                            looked = nil
                            crop = .zero
                            lookRaw = FilmLook.Kind.none.rawValue
                        }
                    } label: {
                        Text("Retake")
                            .font(Typography.headerSmall)
                            .foregroundStyle(AppColors.onDarkSecondary)
                            .frame(minWidth: 88, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }

                    Spacer(minLength: 0)

                    // Your head, between the two words, only if you made one
                    // and switched the sticker on.
                    if let rig = HeadStore.shared.headForSticker {
                        HeadStickerButton(rig: rig, isOn: sticker != nil) {
                            withAnimation(GridConstants.motionSnappy) {
                                sticker = sticker == nil
                                    ? StickerPlacement(crop: BlockCropOutline.crop(photo: image.size, block: drawnSize),
                                                       photoAspect: image.size.width / max(image.size.height, 1))
                                    : nil
                            }
                        }
                        Spacer(minLength: 0)
                    }

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
                // **The two most-pressed words in the capture flow, which had
                // no press answer at all** (2026-10-01,
                // `docs/consistency-audit.md` §1.8). The refused screen two
                // screens earlier already used `.pressWord`; this row was
                // `.plain`, which draws the label and nothing else. The sticker
                // button between them carries its own style and is unaffected.
                .buttonStyle(.pressWord)
                // On the scale, and the same margin as the head maker's
                // matching Retake / Save row. It was 28.
                .padding(.horizontal, GridConstants.gapWide)
                .padding(.bottom, bottomInset + shutterBottomGap)
            }
            .padding(.top, topInset + Header.topPadding)
            // The look on the shown photograph, rendered again whenever
            // either of them changes.
            .task(id: LookRequest(photo: image, look: lookRaw)) { await showLook(on: image) }

        }
    }

    /// **The size in a word, at the top, not a square in the middle.**
    ///
    /// A white rounded rectangle sat between Retake and Use Photo, drawing the
    /// footprint of the block you had pulled out of the shutter. The owner:
    /// "there is a random square in the middle." It was: nothing on that
    /// screen explained it, and the bottom row of a camera review is somewhere
    /// everybody already knows the shape of: one word left, one word right,
    /// nothing between them. The size still matters, so it is said rather than
    /// drawn.
    ///
    /// **The size, still changeable.** It was the word alone, which said what
    /// you had drawn and offered no way to change your mind without retaking
    /// the photograph. The owner: "on that screen you should be able to change
    /// its size on the top." Three words, the one you are on lit, in the same
    /// language the shutter's draw gesture speaks, and the crop outline below
    /// follows it.
    ///
    /// **Its own property, and placed by the picture rather than by the
    /// screen.** See the overlay in `reviewLayer` for why.
    private var sizePicker: some View {
        HStack(spacing: 0) {
            ForEach(BlockSize.allCases, id: \.self) { option in
                Button {
                    guard option != drawnSize else { return }
                    HapticsEngine.tick()
                    withAnimation(GridConstants.slotSnap) { drawnSize = option }
                } label: {
                    // Sentence case in `headerSmall`: these are choices, not
                    // headings. Uppercase kerned words are `SectionHeading`'s
                    // style, and the add sheet spells the same three options
                    // in sentence case.
                    Text(option.effortLabel)
                        .font(Typography.headerSmall)
                        // **`onDarkQuiet` was the wrong token on this ground.**
                        //
                        // The `onDark` scale is defined against the
                        // viewfinder's BLACK, and `CategoryColors` states its
                        // ratios there: strong 18.8:1, secondary 12.0:1, quiet
                        // 6.7:1. The ground here is not black, it is whatever
                        // photograph you just took. Measured on the built
                        // review, with the capsule rendering rgb(108, 102,
                        // 130) over a mid-tone frame, the two unlit words
                        // came out at **2.91:1** against a 4.5:1 floor. The
                        // lit one was fine at 5.07:1, which is how this got
                        // past: one of the three words passed.
                        //
                        // Secondary, not quiet. On the same measured ground
                        // under the darker panel below, 0.75 white lands at
                        // 5.83:1 and the lit word at 8.1:1, so the two are
                        // still plainly different and both are readable.
                        .foregroundStyle(option == drawnSize
                                         ? AppColors.onDarkStrong : AppColors.onDarkSecondary)
                        // The app's named treatment for light type over
                        // imagery it does not control. The panel carries most
                        // of it; this is what holds the words up over a
                        // blown-out sky, where a translucent material is at
                        // its lightest.
                        .legibleOnImagery()
                        .padding(.horizontal, GridConstants.gapItem)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                // `.pressWord`, not `.press`: these are words, and a word at
                // 6% reads as a wobble. `PressResponse`'s own doc lists "the
                // size chips beside the shutter" with the glyph row, which is
                // where they sit and not what they are — the glyph rung is the
                // grid, the flash, the flip and the timer.
                .buttonStyle(.pressWord)
                .accessibilityAddTraits(option == drawnSize ? [.isSelected] : [])
            }
        }
        // **This panel carries TYPE, and it was wearing the glyph recipe.**
        //
        // `glassCapsule()` is `.regular.interactive()` with no ink, which is
        // the material `GlassIconButton.swift` describes as right for a
        // control holding one chevron: "a button can be almost invisible
        // because it holds one chevron, and the chevron is legible against
        // anything. Four rows of names need a ground." Three names need one
        // too. That file's own measured table puts bare `.regular` at 1.56:1
        // over a bright sky and `.regular` plus 30% ink at 5.44:1, and
        // `GlassRecipe.typePanel` is that second row.
        //
        .glassCapsule(carriesType: true)
    }

    /// What the shown preview is of: a photograph and a look together, so
    /// changing either renders it again.
    private struct LookRequest: Equatable {
        let photo: UIImage
        let look: String
    }

    /// The review photograph with the look on it, at about screen size, which
    /// is all anybody can see here and a fraction of what the full photograph
    /// costs.
    private func showLook(on image: UIImage) async {
        let kind = FilmLook.Kind(rawValue: lookRaw) ?? .none
        guard kind != .none else {
            looked = nil
            return
        }
        let look = FilmLook.look(kind)
        let rendered = await Task.detached(priority: .userInitiated) { () -> UIImage in
            FilmLookRenderer.shared.render(image.scaledDown(to: 1400), look: look)
        }.value
        guard !Task.isCancelled else { return }
        looked = rendered
    }

    /// Keep it: the camera roll, then the win.
    ///
    /// This is the only place the full-resolution frame exists — `ImageManager`
    /// downscales to 1024px for the block — so it is the only place the camera
    /// roll can be given the real photograph. No second haptic: the button
    /// press already confirmed it, and buzzing again when a background write
    /// lands is two confirmations for one action.
    private func keep(_ image: UIImage) {
        // The head, drawn into the picture, if you added it. The camera roll
        // and the win both get the same photograph you approved.
        var composed = image
        if let placement = sticker, let rig = HeadStore.shared.headForSticker {
            composed = HeadSticker.composite(image, rig: rig, placement: placement)
        }
        sticker = nil
        let look = FilmLook.look(FilmLook.Kind(rawValue: lookRaw) ?? .none)
        let size = drawnSize
        let place = LocationService.shared.place()
        let window = crop
        let final = composed
        // **The look goes on last, over the head as well.** A cut-out face in
        // its own colours sitting on a graded photograph reads as stuck on;
        // grade the whole thing and it belongs to the picture.
        //
        // **And it is chosen only here.** The owner's call: "that should be a
        // camera only feature." It is put on once, and everything downstream —
        // the camera roll, the block, the map, the gallery — sees one finished
        // photograph. Nothing later offers to change it, because by then the
        // picture is a win rather than a shot you are still composing.
        //
        // Off the main actor: a full-size photograph through the whole
        // pipeline is tens of milliseconds, and the shutter must never be the
        // thing that stutters.
        Task { @MainActor in
            let graded = look.kind == .none ? final : await Task.detached(priority: .userInitiated) {
                FilmLookRenderer.shared.render(final, look: look)
            }.value
            Task { await PhotoLibrarySaver.save(graded) }
            onCaptured(graded, size, place, window)
        }
        looked = nil
        crop = .zero
        lookRaw = FilmLook.Kind.none.rawValue
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
                        withAnimation(GridConstants.motionSnappy) { flip() }
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
                        // Up is brighter, 120pt to a stop, so the whole two
                        // stops `CameraService.biasLimit` allows is 240pt of
                        // travel: about a third of the screen, which is the
                        // same order as the throw on Apple's own sun slider.
                        // This comment used to claim the range was a screen and
                        // a half; under the old eight-stop range it was 1920pt,
                        // and that is what "exposure goes way too high and low"
                        // was.
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
                    withAnimation(GridConstants.motionSnappy) { focusPoint = nil }
                }
        }
    }

    /// Turn the camera round, and tell the graded surface which way up it is
    /// now.
    ///
    /// The connection is NEW after a flip, a different device and a different
    /// input, so the rotation and the mirroring have to be set on it again.
    private func flip() {
        camera.flip()
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

    /// **The grid draws itself out; it does not fade in.**
    ///
    /// The owner, 2026-09-23: "I like our rule of third lines better in this
    /// app than in Apollo so let's keep that one, but the animation of the
    /// lines coming in should be updated." So the lines are untouched: same
    /// colour, same weight, same break for the wordmark, same dissolve at the
    /// bottom, and only their arrival has changed.
    ///
    /// It was `.transition(.opacity)` on the whole group, which is a
    /// rectangle appearing: the cheapest-looking way for a grid to arrive, and
    /// a layer fading in rather than an instrument ruling a line. Each line
    /// now grows along its own length from its own middle, all of them
    /// together, which is what a machine drawing a grid looks like and is the
    /// 1990s Japanese future the design doc asks for.
    ///
    /// **`shown` rather than an `if`.** A transition can only fade a group; a
    /// line held in the hierarchy can be scaled along its own length. Four
    /// rectangles cost nothing to keep.
    ///
    /// The animation is attached to `shown` and to nothing else, so the grid
    /// moves because somebody pressed the button and never because the screen
    /// appeared. `gentleReveal` is 0.22s and all but critically damped: an
    /// overshoot here would run the line past its own end, and nothing about
    /// a button press is momentum.
    private func guides(w: CGFloat, h: CGFloat, bottomInset: CGFloat,
                        shown: Bool) -> some View {
        // **THE GUIDES STOP WHERE THE CONTROL ROW STARTS, IN POINTS.**
        //
        // The fade used to be a FRACTION of the frame (clear at 0.89h) while
        // the control row is placed from the frame's BOTTOM EDGE
        // (`bottomInset + shutterBottomGap`). Two anchors in opposite
        // directions, so where the grid met the row was whatever the
        // arithmetic happened to produce on that phone.
        //
        // Measured on the built screen at 402x874, h = 873, bottomInset = 82:
        // the fade went clear at 777 and the shutter's rim starts at 671, so
        // the whole control row sat inside the grid. The vertical at 268.2 ran
        // straight THROUGH the flip glyph (ink 265.3 to 289.3) and the one at
        // 134.2 cleared the flash glyph by 3.2pt. At the glyph row the lines
        // still measured rgb 42 to 60 on black; over a daylit scene they are
        // 55% white crossing a 21pt symbol.
        //
        // So the clear point is now the row's own top, computed from the same
        // expression that places the row. On any screen the two agree by
        // construction rather than by coincidence.
        //
        // **The fade cannot simply start higher to compensate.** The lower
        // horizontal rule sits at 2/3 h = 582, and anything that dims it while
        // the upper one at 291 stays full renders a rule of thirds with two
        // weights, which is worse than the collision. So the run is bounded
        // below by that rule plus `gapTight`: 590 to 671 here, an 81pt
        // dissolve on a 1pt line, where it was 183.
        let rowTop = h - bottomInset - shutterBottomGap
            - Self.shutterBounds(.small).height
        let clear = max(0, min(h, rowTop))
        let solid = max(0, min(clear, h * Guide.horizontalY[1] + GridConstants.gapTight))
        let span = max(h, 1)

        // **BOTH VERTICALS RUN THE WHOLE HEIGHT NOW.**
        //
        // The first one used to be cut, and the break was good: it held the
        // wordmark, and a line resuming below a gap reads as deliberate rather
        // than as a line that failed to draw. The wordmark is gone (see
        // `header`), so the gap holds nothing — and a gap holding nothing is
        // exactly the "failed to draw" it was written to avoid. The owner:
        // "just extend the lines."
        //
        // It also makes the grid honest: a rule of thirds with one line short
        // is not a rule of thirds, and this screen's whole argument is that it
        // is an instrument.
        return ZStack(alignment: .topLeading) {
            // Centred ON the boundary, not started at it. A 1pt line drawn
            // from the third leaves its whole width on one side, which pushes
            // its centre half a point past where the third actually is — small,
            // but it is the difference between the bands measuring equal and
            // measuring a hair unequal, and unequal is what the eye reports as
            // "the middle one looks longer".
            ForEach(Guide.verticalX, id: \.self) { fraction in
                Rectangle()
                    .fill(Guide.colour)
                    .frame(width: Guide.width, height: h)
                    .ruled(shown, along: .vertical)
                    .offset(x: round(fraction * w) - Guide.width / 2, y: 0)
            }

            ForEach(Guide.horizontalY, id: \.self) { fraction in
                Rectangle()
                    .fill(Guide.colour)
                    .frame(width: w, height: Guide.width)
                    .ruled(shown, along: .horizontal)
                    // Rounded to a whole point for the same reason the width
                    // is: a line at a fractional offset is smeared across two
                    // pixel rows and reads lighter than its neighbour.
                    .offset(x: 0, y: round(fraction * h) - Guide.width / 2)
            }
        }
        .frame(width: w, height: h, alignment: .topLeading)
        // Both ways at the same speed, and interruptible: pressing the button
        // again while a line is still drawing sends it back from where it is,
        // because a spring animates from the presentation value.
        .animation(reduceMotion ? nil : GridConstants.motionSnappy, value: shown)
        // The grid dissolves before it reaches the controls.
        //
        // Ruled lines running hard into chrome is the one place this screen
        // looked pasted together: two systems meeting at an edge neither of
        // them drew. Fading them out over the last stretch means the page
        // stops rather than being cut off. See the note at the top of this
        // function for where the two stops come from.
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: solid / span),
                    .init(color: .clear, location: clear / span)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
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
        // A row also makes the arrangement honest: the settings sit either
        // side of the shutter, inside the arc a thumb already sweeps.
        //
        // **The margin is what is left over, not a fixed 44.** Four glyphs and
        // a shutter is 256pt, and 44 either side leaves 58pt of air on a 402pt
        // phone. A row that overflows its own margin looks squeezed on the
        // smallest phone and correct on the biggest, so solving for the margin
        // instead keeps the air even on every screen, floored at the app's own
        // page margin.
        //
        // **The multiplier was 5 and there are 4 glyphs.** It was right while
        // the looks button was in this row; that button moved to the top right
        // and the arithmetic did not follow, so the row has been solving for a
        // 300pt object that is 256pt wide. On a 402pt screen it does not show,
        // because `(402 - 300) / 2` is 51 and the `min(44, ...)` caps it
        // anyway. On an SE's 375 it does: the stale figure gives a 37.5pt
        // margin where the real one gives the full 44, so the row was pinched
        // by 6.5pt a side on the one phone the cap was written to protect.
        let rowWidth = Self.controlSide * 4 + Self.shutterBounds(.small).width
        let rowMargin = max(GridConstants.horizontalPadding,
                            min(44, (w - rowWidth) / 2))
        return ZStack(alignment: .bottom) {
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
                // **The looks button is NOT in this row**, and that is the
                // owner's correction rather than a layout preference: "the
                // filter button is in the row, I thought we were porting the
                // button from Apollo, like the one that's in the top right
                // for filters."
                //
                // Putting it here was my instruction to the person who did
                // the port, and photographed it was plainly worse: five
                // glyphs plus the shutter crowds a 300pt row into an SE's
                // 287, the flash mark ends up under the shutter's edge, and
                // the one control that changes the PICTURE was sitting in the
                // row of controls that change the camera. It lives in the top
                // right now, with the tray growing out of it. See `looksButton`.

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
                    // No `withAnimation` here. The grid owns its own timing,
                    // attached to this value inside `guides`, so it can never
                    // be animated by a transaction that happens to be running
                    // for some other reason.
                    camera.showsGuides.toggle()
                    UserDefaults.standard.set(camera.showsGuides, forKey: "cameraShowsGuides")
                }

                Spacer(minLength: 0)

                glyphButton(camera.isFlashOn ? "bolt.fill" : "bolt.slash.fill",
                            label: camera.isFlashOn ? "Flash on" : "Flash off",
                            identifier: "flashToggle",
                            value: camera.isFlashOn ? "on" : "off",
                            // Off is DIMMED, as the grid and the timer are
                            // and as iOS Camera does it. It was a full-white
                            // slashed glyph beside a dimmed timer, so one row
                            // of four said "off" two different ways.
                            dimmed: !camera.isFlashOn) {
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
                    withAnimation(GridConstants.motionSnappy) { flip() }
                }

                Spacer(minLength: 0)

                timerButton
            }
            // The settings step out of the way while you draw.
            //
            // A drawn block runs to 149pt across and the row has about 138 to
            // give, so something has to move — and the honest something is the
            // controls you are not using at that moment. They are already
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
            .padding(.horizontal, rowMargin)
            .padding(.bottom, bottomInset + shutterBottomGap)
            // **FIVE CONTROLS FOR A CAMERA THAT CANNOT RUN.**
            //
            // The refused screen kept this whole row. The shutter was dimmed
            // to 0.3 and its gesture disabled, and the four glyphs were left
            // live, so a tap on "Show the grid" flipped a stored preference
            // that `guides` suppresses while denied, the flip button turned a
            // session that is not running, and the timer counted down to a
            // photograph that cannot be taken. Measured on the built screen:
            // zero of five controls could change anything, and the disabled
            // shutter alone was 3,836pt^2 of rgb(77, 77, 77), the largest
            // object on the page and the brightest thing on it after the
            // headline it was competing with.
            //
            // The note it carried said the row stayed so the way out of the
            // screen stayed where it always is. That was already untrue: the
            // way out is the tab bar, which is the system's and is not in this
            // view at all, and the close button below is a sibling of the row
            // rather than part of it, so it survives this.
            //
            // The subject of a refused camera is one sentence and one button.
            // Everything else is subtraction.
            //
            // Ruled out rather than removed, which is the same choice `body`
            // already makes for the review state: an `if` would unmount the
            // row and remount it the moment permission changed, and the
            // shutter is
            // the one thing on this screen that must never arrive by animating
            // itself in. `accessibilityHidden` as well as `allowsHitTesting`,
            // because a 0-opacity button is still a button to VoiceOver and
            // reading out four controls that do nothing is the same bug with
            // the screen turned off.
            .opacity(camera.isDenied ? 0 : 1)
            .allowsHitTesting(!camera.isDenied)
            .accessibilityHidden(camera.isDenied)

            if let onClose {
                GlassIconButton(
                    systemName: "xmark",
                    // The token, not a raw white. This and the head maker's
                    // close are the same button on the two dark screens and
                    // this was the last place on the pair that wrote the
                    // colour out by hand. 0.95 against 1.0 is not a visible
                    // change; a screen with its own idea of white is.
                    tint: AppColors.onDarkStrong,
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

    /// The looks panel, drawn from the glyph at the row's leading edge.
    ///
    /// Its own property rather than inline in `controls`, which is already a
    /// long expression: CLAUDE.md records what the type-checker does when one
    /// of these grows one modifier too far.

    /// **The lens control, and on a phone with one lens it is still just the
    /// zoom readout it was.**
    ///
    /// The owner, 2026-09-23: "what is the RAW and lens picker, don't we need
    /// those for the camera as well?" Nobody pinches to find a lens; they tap.
    ///
    /// **One pill rather than a row of them.** The system camera draws 0.5x,
    /// 1x and 2x side by side; three buttons is three pieces of chrome on a
    /// photograph, and this screen's whole argument is that the picture is the
    /// only lit thing on it. So it is the pill that was already here, showing
    /// where the lens is, and a tap moves to the next stop and wraps. Pinch
    /// still goes anywhere in between.
    ///
    /// **It degrades honestly, and on `main` today that is what it does.**
    /// `CameraLenses.offer` asks the device in the session what pieces of
    /// glass it has. With one, which is every phone until
    /// `CameraService.configure()` opens a virtual device, and every simulator,
    /// which has no camera at all, there is one stop, `hasChoice` is false,
    /// and this is exactly the control it has always been: absent at 1x,
    /// present after a pinch, and a tap undoes the pinch. No dead buttons, and
    /// nothing drawn for a lens that is not there.
    @ViewBuilder
    private var zoomPill: some View {
        let lenses = CameraLenses.offer(from: camera)
        let label = CameraLenses.label(forDeviceFactor: camera.zoom, base: lenses.base)
        // A choice of glass is worth a permanent control; a bare readout is
        // not. See the note above `shutterBounds` about reserving its height
        // either way.
        if camera.canZoom, lenses.hasChoice || camera.zoom > 1.005 {
            let next = lenses.hasChoice
                ? CameraLenses.stop(after: camera.zoom, in: lenses.stops)
                : 1
            Button {
                HapticsEngine.lightTap()
                withAnimation(GridConstants.motionSnappy) { camera.setZoom(next) }
            } label: {
                Text(label)
                    .font(Typography.headerSmall)
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    // After the layout, not before: the material takes its
                    // shape from the final frame.
                    .frame(width: 56, height: 34)
                    // The app's one glass capsule, not a private fourth copy of
                    // it. See the note where `zoomGlass()` used to be, at the
                    // bottom of this file.
                    .glassCapsule()
                    // **The capsule stays 34pt and the TARGET is 44.** The
                    // drawn pill is the size it is drawn; the thing a thumb
                    // has to find is not. It was 34 tall, ten points under the
                    // floor every other control on this screen meets, and it
                    // is the one control that appears mid-gesture with a
                    // finger already moving. The extra ten points are
                    // invisible and are the difference between tapping it and
                    // tapping the viewfinder, which refocuses the shot.
                    .frame(width: 60, height: Self.controlSide)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // It grows out of the shutter's line rather than fading in on the
            // spot, which is what makes it read as belonging to the gesture
            // that produced it.
            .transition(.scale(scale: 0.7).combined(with: .opacity))
            .accessibilityLabel("Lens, \(label)")
            .accessibilityHint(lenses.hasChoice
                               ? "Switches to \(CameraLenses.label(forDeviceFactor: next, base: lenses.base))"
                               : "Returns to 1x")
        }
    }

    // `zoomLabel` was here. It is `CameraLenses.label(forDeviceFactor:base:)`
    // now, because a number on a lens control has to have the lens base
    // divided out of it before it is formatted, and doing that in two places
    // is how a pill ends up reading 1x while showing something else.

    /// Off / 3s / 10s, cycling, exactly the set iOS Camera offers.
    private var timerButton: some View {
        glyphButton("timer",
                    label: camera.timerSeconds == 0 ? "Timer off" : "Timer \(camera.timerSeconds) seconds",
                    identifier: "timerToggle",
                    value: "\(camera.timerSeconds)",
                    // **The delay is BESIDE the glyph now, at 15, and it was a
                    // 10pt numeral stacked under it** (2026-10-01, the type
                    // pass). The owner: "no tiny text under or anythign like
                    // that I want it to be controlled" — a 10pt digit hung
                    // below a control, over a live viewfinder, is the clearest
                    // case of it in the app.
                    //
                    // It is not deleted, because the glyph does not carry what
                    // it says: dimmed-against-lit tells you the timer is on and
                    // nothing tells you whether it is 3 or 10, and iOS Camera
                    // draws the number for the same reason.
                    //
                    // The "s" is not drawn. Measured at 15 Medium monospaced:
                    // the 21pt glyph is 25.0pt, "10" is 18.9 and "10s" is 26.7,
                    // so the pair comes to 43.9pt against 51.7 — the bare
                    // number fits inside the 44pt control and "10s" does not.
                    badge: camera.timerSeconds > 0 ? "\(camera.timerSeconds)" : nil,
                    dimmed: camera.timerSeconds == 0) {
            withAnimation(GridConstants.motionSnappy) {
                camera.timerSeconds = camera.timerSeconds == 0 ? 3 : (camera.timerSeconds == 3 ? 10 : 0)
            }
            UserDefaults.standard.set(camera.timerSeconds, forKey: "cameraTimerSeconds")
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
    /// Every glyph in the control row is this square. It is the HIG's minimum
    /// target and the number the row's width is solved from, so it is stated
    /// once rather than written into both.
    static let controlSide: CGFloat = 44

    /// `badge` is a short run of DIGITS drawn beside the glyph, on its line.
    /// It exists for the timer, whose delay used to be a 10pt numeral stacked
    /// underneath (see `timerButton`), and it is a parameter here rather than a
    /// second kind of button so the row keeps one control type.
    ///
    /// **Fixed 15, not a type tier, and SF's own digits rather than the
    /// owner's.** Both for the reason the 21 below is fixed: this row is solved
    /// against a 44pt control over a viewfinder, so anything in it that grew
    /// with Dynamic Type would run into its neighbour. Measured at 44pt of box:
    /// the `timer` glyph is 25.0pt wide at 21pt, "10" is 18.9pt in SF Medium
    /// monospaced digits and 27.2pt in `StrataFont` (tabular at 0.906 em), so
    /// the pair comes to **43.9pt** in SF and 52.2 in the owner's face. There
    /// is no spacing: the glyph's own side bearing is the gap.
    private func glyphButton(_ symbol: String,
                             label: String,
                             identifier: String? = nil,
                             value: String? = nil,
                             badge: String? = nil,
                             dimmed: Bool = false,
                             action: @escaping () -> Void) -> some View {
        Button {
            HapticsEngine.tick()
            action()
        } label: {
            HStack(spacing: 0) {
                Image(systemName: symbol)
                    // **`iconSize`, not `.font(.system(size:))`** (2026-10-01,
                    // `docs/consistency-audit.md` §1.15). A fixed size does not
                    // respond to the user's text size at all, and brand.md asks
                    // for Dynamic Type on every screen (WCAG 1.4.4). 21 is kept
                    // as the value — it is the number the chrome row was
                    // composed against and the badge beside it is solved off it
                    // in this function's own doc — and it now grows.
                    .iconSize(21, relativeTo: .body, weight: .regular)
                if let badge {
                    Text(verbatim: badge)
                        // Scaled with the glyph, not against it. This function's
                        // own doc solves the pair against each other — 21pt of
                        // glyph plus 15pt of monospaced digits comes to 43.9pt —
                        // so growing one with Dynamic Type and pinning the other
                        // would pull the pair apart. `iconSize` sets the same
                        // `.system(size:weight:)` the literal did, through
                        // `@ScaledMetric`.
                        .iconSize(15, relativeTo: .body, weight: .medium)
                        .monospacedDigit()
                }
            }
            // Dimming lives on the GLYPH, not as an `.opacity` over the
            // button. A toggle wrapped in `.opacity(...)` stopped
            // receiving taps entirely — measured: its action never ran,
            // proven by having it toggle the flash as a probe and watching
            // the flash not move, while the flash's own button (identical
            // helper, no opacity modifier) toggled every time.
            .foregroundStyle(.white.opacity(dimmed ? 0.5 : 1))
            .legibleOnImagery()
            .frame(width: Self.controlSide, height: Self.controlSide)
            .contentShape(Rectangle())
        }
        // **The four controls `PressResponse` names by name**: the grid, the
        // flash, the flip and the timer all come through this helper, and all
        // four were `.plain` while the style written for them had zero call
        // sites (`docs/consistency-audit.md` §1.8). A glyph over a photograph
        // has no background to shift, so the scale and the dim together are the
        // whole of the feedback — and the glyph's own legibility shadow moves
        // with the scale, which is the part that sells it.
        .buttonStyle(.press)
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
        // One control, drawn in one place. See `ShutterBlock`: this and the
        // head maker's were two copies of the same rim and block, and the
        // audit improved one of them and left them disagreeing.
        let block = ShutterBlock(size: drawnSize, lit: true, scale: shutterScale)
        return block
        .animation(GridConstants.slotSnap, value: drawnSize)
        // **THE ONE PIECE OF CHROME HERE THAT HAD NO ANSWER FOR A WHITE WALL.**
        //
        // Every other mark on the viewfinder already carries `Legibility`: the
        // four glyphs, the countdown, the timer's digit, the exposure sun. The
        // shutter, the biggest object on the screen and the only primary
        // action, did not, and it is white fill inside a white 1pt rim with a
        // 6pt gap that shows the scene THROUGH it. On the simulator's black
        // frame it measures 255 on 0 and looks perfect. Point it at a lit wall
        // and every part of it is white on white: the rim, the fill and the gap
        // all go to the same value, and the only control that takes a
        // photograph disappears.
        //
        // A scrim under the row was the other candidate and is the thing the
        // house rule rejects: it is a band of ink laid over the picture, on a
        // screen whose whole argument is that the picture is the only lit
        // thing on it. This is the treatment the app already named for exactly
        // this case ("white type over imagery it does not control"), applied
        // to the one control that was missing it. On black it costs nothing,
        // because a 42% black blur on black is black.
        .legibleOnImagery()
        .contentShape(block.shape)
        .gesture(draw, isEnabled: !camera.isDenied)
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
        // Shared with the head maker, so both light a face with one light.
        WarmRingLight(fillOpacity: fillOpacity)
    }

    /// **The front flash is the ring, and there is no second one.**
    ///
    /// There used to be a capture flash over this: a near-solid warm screen at
    /// the moment of the shot, on the argument that at that moment nothing
    /// matters except photons on the face.
    ///
    /// The owner: "for the front flash I think it might be too bright, and
    /// also what's the point of the additional flash when you take the photo?
    /// The ring is enough. A tip is make sure the person with the front flash
    /// is able to check themselves out, like the person still needs to be
    /// visible enough to admire themselves."
    ///
    /// **He is right, and it was wrong in three ways.** A ring light does not
    /// pulse; it is on, and the light you compose by is the light you are
    /// photographed by, which is the entire reason to hold a modelling light
    /// at all. The blast covered the viewfinder at the one instant somebody
    /// most wants to see their own face. And because a sudden light needs
    /// auto-exposure to catch up, firing it meant SLEEPING 220ms before the
    /// shutter, so the blast was also the reason the front camera felt slow.
    ///
    /// Removing it removes the delay, and the ring is already at full screen
    /// brightness and was always doing most of the work.
    private var warmFlash: some View {
        warmLight(fillOpacity: Self.ringFill)
            .opacity(ringIsArmed ? Self.ringLevel : 0)
            .animation(GridConstants.screenFlashOut, value: ringIsArmed)
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
    private static let ringFill = WarmRingLight.modellingFill
    private static let ringLevel = WarmRingLight.modellingLevel

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

        withAnimation(GridConstants.shutterPress) { shutterScale = 0.86 }
        withAnimation(GridConstants.shutterRelease.delay(0.08)) {
            shutterScale = 1
        }

        // **No wait before the shutter any more.** This used to raise a
        // capture flash and then sleep 220ms for auto-exposure to settle on
        // the new light. With the ring held on there is no new light: the
        // metering has been settled on it the whole time you were composing,
        // and the screen is already at full brightness because arming the
        // flash is what raises it. So the front camera fires as fast as the
        // back one.
        Task { @MainActor in
            camera.capture { image in Task { @MainActor in
                guard let image else {
                    // No photograph, so nothing was drawn for. Leaving the
                    // shutter wide would make the NEXT shot inherit a size
                    // nobody asked for.
                    withAnimation(GridConstants.slotSnap) { drawnSize = .small }
                    return
                }
                HapticsEngine.success()
                // **What the viewfinder showed, and you at your best.** Cut to
                // the viewfinder's own shape (the preview fills its frame from
                // a wider sensor), then each face gently polished; both off
                // the main thread, and the review shows the result.
                let bounds = previewBox.layer?.bounds.size ?? .zero
                let aspect = bounds.height > 0 ? bounds.width / bounds.height : 0
                let finished = await Task.detached(priority: .userInitiated) {
                    PortraitPolish.apply(to: PortraitPolish.cropped(image, toAspect: aspect))
                }.value
                // Nothing is kept yet.
                //
                // The camera roll used to be written HERE, before anything was
                // confirmed — which was fine while there was no way to reject
                // a shot and became a bug the moment there was: every photo
                // you retook would already be in your library. It happens on
                // "Use Photo" now.
                withAnimation(GridConstants.motionSnappy) { review = finished }
            } }
        }
    }
}

private extension View {
    /// A composition line that is drawn out from its own middle rather than
    /// faded in. See `CameraView.guides`.
    ///
    /// A scale along the line's own length, and nothing else: no opacity, or
    /// it is a fade again with extra steps. At zero the line has no length and
    /// is not there; at one it is exactly the line it always was, so nothing
    /// about how the grid LOOKS when it is on has changed.
    func ruled(_ shown: Bool, along axis: Axis) -> some View {
        scaleEffect(x: axis == .horizontal ? (shown ? 1 : 0) : 1,
                    y: axis == .vertical ? (shown ? 1 : 0) : 1,
                    anchor: .center)
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

/// Internal, not private: the head maker shows the same viewfinder, so it is
/// the app's camera rather than a second one that looks almost the same.
struct CameraPreview: UIViewRepresentable {
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
            RoundedRectangle(cornerRadius: GridConstants.radiusMark, style: .continuous)
                .strokeBorder(Color(red: 1, green: 0.82, blue: 0.24), lineWidth: 1.4)
                .frame(width: Self.side, height: Self.side)

            Image(systemName: "sun.max.fill")
                .font(Typography.headerSmall)
                .foregroundStyle(Color(red: 1, green: 0.82, blue: 0.24))
                .offset(y: sunOffset)
                .animation(GridConstants.motionSnappy, value: sunOffset)
                .legibleOnImagery()
        }
        // The square is what is pointed at, so the pair has to hang off the
        // square's centre rather than the row's — otherwise tapping puts the
        // gap between them on the subject.
        .offset(x: 12)
    }
}


// **`zoomGlass()` was here and is DELETED** (2026-10-01,
// `docs/motion-audit.md` §6). It was `glassCapsule()` spelled a fourth time,
// 480 lines from the comment in `GlassIconButton.swift` whose whole job is to
// stop exactly that: *"It was typed out three times, once in each shape below,
// which is the drift this file exists to stop."*
//
// The zoom pill calls `.glassCapsule()` now. **Identical on iOS 26**: both
// resolved to `.glassEffect(.regular.interactive(), in: .capsule)`, and
// `glassCapsule`'s default arguments (`onPage: false`, `carriesType: false`)
// select that same recipe. `carriesType` is correctly false even though the
// label is a word: the recipe exists for several rows of names over a
// photograph, and this is one monospaced digit and an `x`, already carrying
// `.white` with the viewfinder's own exposure under it.
//
// **The pre-26 fallback is not identical and the difference is a gain**: the
// shared one adds `GlassFallback.rim`, white 0.18 at 0.5pt, which the private
// copy left off. That rim is documented as being for exactly this case, "a
// light rim on a material floating over a photograph", and a viewfinder is the
// only place in the app where a glass capsule genuinely is.
//
// `.interactive()` is still the right variant and the reason the private copy
// gave still holds: this is a button, so the effect reacting to the press is an
// affordance rather than decoration. That argument now lives once, on
// `glassCircle`, instead of twice.
