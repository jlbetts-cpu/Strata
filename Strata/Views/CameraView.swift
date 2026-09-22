import CoreImage
import AVFoundation
import AVKit
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
    /// Whether the film looks are pulled down. Closed on every appearance,
    /// like the look itself — see `lookRaw`.
    @State private var showLookTray = CameraTestSwitches.trayOpen
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
    @Environment(\.scenePhase) private var scenePhase
    /// Whether this tab is the one being looked at. A `scenePhase` change is
    /// delivered to every tab that exists, and a TabView keeps them all
    /// alive, so without this the camera would start itself from behind
    /// another screen the moment the app came back.
    @State private var isOnScreen = false
    /// True once access has actually been asked for, so the refusal screen
    /// cannot flash up in the moment before the prompt.
    @State private var accessChecked = false
    @State private var previewBox = PreviewLayerBox()
    /// The live look. See `GradedViewfinder`: it is an overlay ON the preview
    /// layer, so every failure path uncovers the ordinary picture.
    @State private var graded = GradedViewfinder()
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
        /// **Glass, not paint, and the value is his.**
        ///
        /// Sampled from node 14172:8010's own vectors rather than from a
        /// screenshot: every line is `stroke="#98A184"` at
        /// `stroke-opacity="0.5"`, 1pt.
        ///
        /// `#98A184` is a desaturated sage. It is not a colour from the
        /// palette — it is **the grass in the photograph behind it**, lifted
        /// and drained. The owner: "I took the colour from the background kind
        /// of and then turned the transparency down, though it is still very
        /// visible... they are like glass themselves."
        ///
        /// **So the exact colour cannot be shipped, and that is the point.**
        /// A fixed sage line is right over grass and wrong over everything
        /// else; it would read as a green tint on a kitchen counter. What
        /// generalises is the RELATIONSHIP — a line that takes its colour from
        /// what is behind it, lightened and desaturated — which is what a
        /// material does. `.ultraThinMaterial` samples the live preview, so
        /// the line is sage over his grass and warm over a wooden table, by
        /// construction rather than by a constant.
        ///
        /// It was `onDarkQuiet`, pure white at 0.30. Two things were wrong
        /// with that against his: it is paint rather than glass, and at 0.30
        /// it is fainter than the 0.5 he describes as "still very visible".
        /// **Scene tinted, and lightened, which is his design and not the
        /// platform's.**
        ///
        /// The owner: "The rule of thirds lines need to pick up on the light
        /// and colour from the background a little... Think of my Figma design
        /// over the Apple iOS look for these components, because I made them
        /// very intentionally."
        ///
        /// His node draws them `#98A184` at 0.5 — the grass in his photograph,
        /// desaturated — so they sit IN the picture rather than on it. A
        /// material reproduces that relationship over any scene: sage over
        /// grass, pale blue over sky, dim over a dark street, by sampling
        /// rather than by a constant.
        ///
        /// **It was a material once and it vanished, and the reason was not
        /// the material.** The camera declares the dark appearance, so a
        /// material in it renders its DARK variant and darkens what is behind
        /// it — over a bright sky that is almost no change, which is why the
        /// line measured as a smooth 189 to 216 gradient with no line in it.
        /// The same fault as the glass button, found the same way.
        ///
        /// Declaring the light appearance for the guides alone makes the
        /// material LIFT the scene instead, which is what "pick up on the
        /// light and colour" means and what makes it readable over bright and
        /// dark alike.
        /// **Paint, because a material draws nothing here.**
        ///
        /// These lines were `.ultraThinMaterial`, chosen to sample the scene
        /// the way his `#98A184` at 0.5 samples his grass. Measured against a
        /// frame of the same screen with the grid switched off, the material
        /// version differed from it by **zero pixels** on all three scenes:
        /// not faint, not subtle, absent. A 60% white overlay in the same
        /// modifier chain drew nothing either, while a `Color` fill on the
        /// same rectangle at the same offset drew correctly.
        ///
        /// The cause is that `CameraPreview` is a `UIViewRepresentable`. A
        /// SwiftUI `Material` blurs the SwiftUI content behind it, and there
        /// is none: the viewfinder is a UIKit layer outside that tree, so the
        /// material has nothing to sample and composites to nothing. This is
        /// also why the glass button works where these did not, since
        /// `glassEffect` samples the rendered window rather than the SwiftUI
        /// backdrop.
        ///
        /// So the scene tint is not available to these lines on iOS, and the
        /// choice is paint or nothing. His own node is paint: one colour at
        /// half opacity. White at 0.45 is that relationship carried to any
        /// scene, and it is the one thing that is guaranteed to draw.
        /// **The line is Liquid Glass, not paint, and it is 2pt.**
        ///
        /// The owner, against his frame 13646-7517: "The rule of thirds lines
        /// still doesn't look there compared to mine. The thickness looks too
        /// thin and the glass effect isn't there."
        ///
        /// **His node's numbers, read from its own exported vectors.** Every
        /// line is `stroke="#98A184" stroke-opacity="0.5"` with NO
        /// `stroke-width` attribute, so it is the SVG default of 1, in a
        /// 402-wide frame, which is 1pt. There is no blur on them, no
        /// backdrop-filter and no blend mode. **We were already drawing 1.00pt
        /// (3 device pixels at 3x, measured off the render), so the widths
        /// were identical**, and his line is the FAINTER of the two: composited
        /// over these three scenes his sage at 0.5 lifts +18 to +37, where our
        /// white at 0.45 lifted +56 to +71.
        ///
        /// So neither fault was where it looked. The width was the same, and
        /// the "glass" is not an effect in his file at all. What his line has
        /// is a colour taken OUT of his photograph, which is why it sits in the
        /// picture while a white hairline sits on top of it.
        ///
        /// **`glassEffect` is the one thing that reproduces that here.** A
        /// `Material` cannot: it draws literally nothing over the viewfinder,
        /// which is what made these lines invisible in the first place, because
        /// `CameraPreview` is a `UIViewRepresentable` and a material has no
        /// SwiftUI backdrop to sample. Liquid Glass samples the rendered window
        /// instead, so it works where a material does not, and it is the same
        /// material family as his button.
        ///
        /// Measured on a 2pt line, the lift barely moves with the scene
        /// (+42 / +40 / +43 over sky, trees and a dark room) where paint swings
        /// with it, and the colour does move: cool over sky, warm over a lit
        /// room. That is the relationship his sage has to his grass.
        ///
        /// **2pt rather than his 1pt, deliberately.** His is 1pt and reads
        /// heavier to him because he is looking at it zoomed in Figma, where a
        /// point is several screen pixels; on the phone at 3x it is a crisp
        /// 3-pixel hairline. 2pt is what makes it read on the device the way
        /// his reads on his monitor.
        static let width: CGFloat = 2
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
        /// **The artwork's own box, not the cap height.**
        ///
        /// This was `wordmarkSize` (32), which is the cap height the mark is
        /// drawn to, while the artwork itself renders at
        /// `ApolloWordmark.boxHeight` (50). The break in the first vertical is
        /// cut to this number, so the line was being cut for a 32pt mark and
        /// then holding a 50pt one: measured, the gap above the mark was
        /// 14.4pt and the gap below it was MINUS 4pt, with the line resuming
        /// before the word had finished.
        ///
        /// The owner: "the rule of thirds lines don't look like they have even
        /// spacing between the title." That is the number he was seeing.
        static var height: CGFloat { markHeight }
        /// The wordmark's drawn box height.
        /// His node's own number, 50. He has asked for "slightly bigger" and
        /// has not picked a number yet; 56 and 62 were rendered for him beside
        /// this. Note that going above 50 puts the build out of step with his
        /// file, which specifies 145.638 x 50.
        static var markHeight: CGFloat { 56 }
        /// Air between the header and the cut ends of the line.
        static let breathing: CGFloat = 14
    }

    /// Rounder than the design's 20.
    ///
    /// The Figma draws the viewfinder against a bezel it never leaves. Here it
    /// stops above the tab bar, so the curve is a real edge you look at rather
    /// than a corner tucked into the phone's own — and at 20 it read as a
    /// square that had been slightly softened rather than as a shape.
    /// **40, from his frame** (node 14172:8010), not 34.
    ///
    /// The node draws the viewfinder 402 x 799 with `rounded-bl-[40px]` and
    /// `rounded-br-[40px]`. 34 was a value chosen here when the curve was
    /// being judged against a bezel; this is his.
    private let cornerRadius: CGFloat = 40

    /// **This screen's margin is 20, and the rest of the app's is 16.**
    ///
    /// His call, and it is recorded rather than generalised: in node
    /// 14172:8010 the wordmark's box starts at x=20 and the close control ends
    /// 20 from the right. The camera is full bleed and has no text column for
    /// anything to align to, so it does not owe the page grid the 16 that
    /// every other screen uses. Nothing else moves to 20.
    private let sideMargin: CGFloat = 20

    /// **Air between the viewfinder's rounded bottom and the tab bar.**
    ///
    /// The owner: "The bottom tabs need more breathing room."
    ///
    /// Measured before this: the viewfinder's bottom edge landed at 790 and
    /// the bar's top at 791 — **1pt** — so the bar was jammed against the
    /// curve with nothing between them. The strip was 84pt holding a 60pt bar
    /// with 1 above and 23 below.
    ///
    /// 20 gives the bar a band of its own: the strip becomes 104, with 20
    /// above the bar and the system's own 23 below it.
    ///
    /// **The 23 below is not ours to change.** A floating tab bar's distance
    /// from the bottom edge is the platform's, set by the home indicator's
    /// safe area; the only gap this screen owns is the one above it.
    private let stripBreathing: CGFloat = 20
    /// Air between the shutter and the bottom edge of the viewfinder.
    /// **18, not 40, because 40 sat the row too high.**
    ///
    /// The owner: "make sure that the controls for the shutter and other are
    /// in the right spot and not too high. I want it to be proper UX as well
    /// as looking good."
    ///
    /// Measured off the render at 40, the shutter's centre was at **691pt** on
    /// an 874pt screen, with a 39pt band of empty picture below it before the
    /// viewfinder ended. His own frame 14172-8010 puts `Rectangle 215` at
    /// y 673, 80 tall, so **his shutter centre is 713**. At 18 ours measures
    /// **712.8**, which is his number, and it costs nothing in picture height.
    ///
    /// The alternative was ending the viewfinder higher so the row sat in the
    /// black strip. Rendered at a trim of 80pt it was worse in both currencies:
    /// it spent 10% of the picture AND left the shutter against the picture's
    /// bottom edge rather than clear of it.
    ///
    /// Reach: 713 on an 874pt screen is 82% down, inside the lower third a
    /// thumb sweeps one handed, and 161pt from the bottom of the screen. The
    /// shutter's own bottom lands at 752, which is 18pt clear of the
    /// viewfinder's edge and 38pt clear of the tab bar's pill.
    private let shutterBottomGap: CGFloat = 18

    /// The shutter, from node 14172:8010: an 80pt ring and a 66pt fill, both
    /// `#E6E6E6`.
    private static let shutterRing: CGFloat = 80
    private static let shutterFill: CGFloat = 66
    private static let shutterInk = Grey.g100


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
            // **The black strip below the viewfinder is where the tabs
            // live.** The owner: "the area at the bottom to hold the tabs."
            //
            // In a tab, `geo.size.height` already stops at the top of the
            // bottom safe area, and on iOS 26 that inset IS the floating tab
            // bar. So ending the viewfinder there makes the strip exactly the
            // bar's own band, on any device, rather than a number.
            //
            // It used to subtract a further `tabGap` of 14, which floated the
            // picture 14pt clear of the bar and left the bar sitting on the
            // ground rather than in a strip belonging to the camera.
            let h = geo.size.height + topInset + bottomInset
                - (fillsScreen ? 0 : stripBreathing)

            ZStack {
                CameraPreview(session: camera.session, box: previewBox, graded: graded)

                // The gestures the native camera has, on the viewfinder and
                // under the chrome, so the buttons still take their own taps.
                viewfinderGestures(w: w, h: h)

                if !CameraTestSwitches.hideGuides {
                    // **Kept mounted, and shown or hidden rather than
                    // inserted and removed.** A transition can only fade the
                    // group; the lines are then a rectangle appearing, which
                    // is the cheapest-looking way for a grid to arrive. Held
                    // in the hierarchy, each line can be scaled along its own
                    // length, so the grid DRAWS itself out from the title
                    // rather than switching on. Four rectangles cost nothing
                    // to keep.
                    guides(w: w, h: h, topInset: topInset,
                           shown: camera.showsGuides || CameraTestSwitches.forceGuides)
                        .allowsHitTesting(false)
                }

                // **Something to read, and somewhere to go.**
                //
                // Refusing the camera left a black rectangle with a wordmark
                // and four working buttons on it, and no way back: the
                // permission prompt is asked once and never again, so the
                // only route is Settings and nothing said so. It is the first
                // thing somebody sees if they tap the wrong button on the
                // first run.
                if accessChecked && !camera.isAuthorized {
                    noCameraAccess
                        .transition(.opacity)
                }

                header(topInset: topInset)

                // **The button lives here, not in the header, because it and
                // the tray are one shape.** A tray placed under a separate
                // button is two pieces of glass with a gap; the owner asked
                // for them to merge "kind of like how the same colour blocks
                // merge". So `FilmLookTray` owns the button and grows out of
                // it, and it is placed once, on the same 20pt margin and the
                // same top line the header uses.
                // **Tapping anywhere else closes the tray.**
                //
                // The owner, on the device: "the menu doesn't close when
                // clicking outside of it." It did not, because nothing was
                // listening: the only way out was the chevron, which on a
                // panel that covers a third of the viewfinder is the one
                // place a thumb is not.
                //
                // A clear layer under the tray and over everything else, so
                // the tap that dismisses does not ALSO focus the camera or
                // fire the shutter underneath it. That double action is the
                // usual way this gets built wrong.
                if showLookTray {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(GridConstants.slotSnap) { showLookTray = false }
                        }
                        .accessibilityHidden(true)
                }

                if !fillsScreen {
                    FilmLookTray(
                        selection: Binding(
                            get: { FilmLook.Kind(rawValue: lookRaw) ?? .none },
                            set: { lookRaw = $0.rawValue }),
                        isOpen: $showLookTray)
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: .topTrailing)
                        .padding(.trailing, sideMargin)
                        .padding(.top, topInset + Header.topPadding)
                }

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
            .background(Grey.g950)
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
        // **The camera's ground is 950, his darkest, not the app's warm
        // charcoal.** The owner: "for the camera, for instance, I'd rather the
        // bottom panel be the darkest value."
        //
        // Every other screen keeps `WarmBackground`, which is a warm charcoal
        // and adaptive, because it is the ground a BLOCK stands on and the
        // whole app is lit from somewhere. The camera is not that: it is a
        // picture with a strip under it, and the strip's job is to stop
        // existing so the picture is the only lit thing on the screen. 950 is
        // 8, against the warm ground's 40 at its darkest.
        .background { Grey.g950.ignoresSafeArea() }
        .onAppear { isOnScreen = true }
        // **Back from the home screen, and back on.**
        //
        // `.task` runs once for the life of the view, and leaving the app is
        // not leaving the view, so a camera put away by the system stayed
        // away: the tab was open, the buttons worked, the picture was black.
        // Stopping on the way out also puts the orange camera light out,
        // which matters more than the code does.
        .onChange(of: scenePhase) { _, phase in
            guard isOnScreen else { return }
            switch phase {
            case .active: Task { await camera.start() }
            case .background: camera.stop()
            default: break
            }
        }
        .task {
            await camera.start()
            accessChecked = true
            // After `start`, because a session that is not configured cannot
            // take an output — and the attach itself hops onto the session
            // queue, so it is ordered AFTER `startRunning` rather than beside
            // it. Doing it here on the main actor is what crashed his phone.
            // If it does not attach, no frames arrive, the overlay stays
            // hidden and this is the camera exactly as it was before.
            // **The angle comes off the preview layer**, so the graded surface
            // and the layer it covers cannot disagree about which way is up.
            // Deriving it separately is what put the overlay 180 degrees out.
            camera.attachPreviewFrames(graded.relay.output,
                                       matching: previewBox.layer?.connection?.videoRotationAngle ?? 90)
            apply(look: FilmLook.look(FilmLook.Kind(rawValue: lookRaw) ?? .none))
        }
        .onChange(of: lookRaw) { _, raw in
            apply(look: FilmLook.look(FilmLook.Kind(rawValue: raw) ?? .none))
        }
        // **The volume buttons take the photograph**, and on a phone that has
        // one so does the Camera Control.
        //
        // It is muscle memory, it is how you hold a phone steady with one
        // hand, and it is the only way to take a photograph of yourself at
        // arm's length without the hand that is holding the phone also
        // reaching for the middle of the screen. Every camera people have
        // used does this.
        //
        // Off while a photograph is being judged: the buttons belong to
        // composing, and Retake and Use Photo are a decision rather than a
        // reflex.
        .onCameraCaptureEvent(isEnabled: review == nil) { event in
            guard event.phase == .ended else { return }
            shutterPressed()
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
            isOnScreen = false
            // Not a tracker: it runs while the camera is open and not a
            // moment longer.
            LocationService.shared.stop()
            camera.detachPreviewFrames()
            graded.stop()
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

                // **Edge to edge, the way the system camera shows a shot.**
                //
                // It was an inset print with the app's surface radius, which
                // is right in the VIEWER — a photograph you are revisiting is
                // an object on a page — and wrong here. This is the frame you
                // just took, still warm, and every camera on the phone shows
                // it filling the screen. Insetting it made the review feel
                // like a preview of a card rather than the picture itself.
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

                Spacer(minLength: 0)

                FilmLookStrip(photo: image, selection: Binding(
                    get: { FilmLook.Kind(rawValue: lookRaw) ?? .none },
                    set: { lookRaw = $0.rawValue }))
                    .padding(.bottom, GridConstants.gapWide)

                HStack(spacing: 0) {
                    Button {
                        HapticsEngine.tick()
                        withAnimation(GridConstants.gentleReveal) {
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

            // **The size in a word, at the top, not a square in the middle.**
            //
            // A white rounded rectangle sat between Retake and Use Photo,
            // drawing the footprint of the block you had pulled out of the
            // shutter. The owner: "there is a random square in the middle."
            // It was — nothing on that screen explained it, and the bottom row
            // of a camera review is somewhere everybody already knows the
            // shape of: one word left, one word right, nothing between them.
            // The size still matters, so it is said rather than drawn.
            // **The size, still changeable.** It was the word alone, which
            // said what you had drawn and offered no way to change your mind
            // without retaking the photograph. The owner: "on that screen you
            // should be able to change its size on the top." Three words, the
            // one you are on lit — the same language the shutter's draw
            // gesture speaks, and the crop outline below follows it.
            VStack {
                HStack(spacing: 0) {
                    ForEach(BlockSize.allCases, id: \.self) { option in
                        Button {
                            guard option != drawnSize else { return }
                            HapticsEngine.tick()
                            withAnimation(GridConstants.slotSnap) { drawnSize = option }
                        } label: {
                            // Sentence case in `headerSmall`: these are
                            // choices, not headings. Uppercase kerned words
                            // are `SectionHeading`'s style, and the add sheet
                            // spells the same three options in sentence case.
                            Text(option.effortLabel)
                                .font(Typography.headerSmall)
                                .foregroundStyle(option == drawnSize
                                                 ? AppColors.onDarkStrong : AppColors.onDarkQuiet)
                                .padding(.horizontal, GridConstants.gapItem)
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.pressWord)
                        .accessibilityAddTraits(option == drawnSize ? [.isSelected] : [])
                    }
                }
                // The app's own capsule for a control whose label is a word,
                // not a private grey. It was a flat 35% black back when this
                // was a LABEL saying which size you had drawn; now that it is
                // three words you can press, it is the same kind of thing as
                // the Memories header's control and wears the same material.
                .glassCapsule()
                .padding(.top, topInset + Header.topPadding)
                Spacer(minLength: 0)
            }
        }
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
            FilmLookRenderer.shared.render(image.scaledDown(to: 1400), look: look,
                                           pulledStops: look.pullStops)
        }.value
        guard !Task.isCancelled else { return }
        looked = rendered
    }

    /// **A look is two settings, not one.**
    ///
    /// It is the grade the overlay draws, and it is how far the sensor is
    /// asked to underexpose so the look's highlights survive. They have to
    /// move together or the viewfinder is a stop out from the picture: a pull
    /// with no lift is a dark preview, a lift with no pull is a blown one. So
    /// there is one function that sets both and nothing else touches either.
    private func apply(look: FilmLook) {
        graded.look = look
        camera.setLookPull(look.pullStops)
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
                FilmLookRenderer.shared.render(final, look: look, pulledStops: look.pullStops)
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
                        withAnimation(GridConstants.motionSmooth) { camera.flip() }
                        focusPoint = nil
                    }
                    .exclusively(before:
                        SpatialTapGesture(count: 1).onEnded { value in
                            focus(at: value.location)
                        }
                    )
            )
            // **Press and hold to lock**, which is what press-and-hold means on
            // every camera anybody has used. A tap points the camera at
            // something and lets it settle; a hold pins it there and says so,
            // for when the subject is about to move or when you meter off
            // your hand and then reframe. A tap anywhere releases it.
            //
            // `simultaneousGesture`, and `minimumDuration` well clear of a
            // tap, so the single and double taps above are untouched.
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.55)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onEnded { value in
                        guard case .second(true, let drag?) = value else { return }
                        lock(at: drag.startLocation)
                    }
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
            FocusReticle(bias: camera.exposureBias, range: camera.exposureBiasRange,
                         locked: camera.isLocked)
                .position(point)
                .transition(.scale(scale: 1.4).combined(with: .opacity))
                .allowsHitTesting(false)
                // **A locked reticle does not go away, and that IS the
                // indicator.** The system camera says AE/AF LOCK in a yellow
                // box; this screen's whole argument is that the picture is
                // the only lit thing on it, so the mark that is already there
                // stays instead of a banner arriving. Something held is
                // something still on screen.
                .task(id: focusShownAt) {
                    guard !camera.isLocked else { return }
                    try? await Task.sleep(for: .seconds(4))
                    guard !Task.isCancelled else { return }
                    withAnimation(GridConstants.gentleReveal) { focusPoint = nil }
                }
                .accessibilityHidden(false)
                .accessibilityLabel(camera.isLocked
                                    ? "Focus and exposure locked. Tap to release."
                                    : "Focus and exposure here")
        }
    }

    /// **When the hold locked, so the release that follows it does not
    /// immediately unlock.**
    ///
    /// A `SpatialTapGesture` has no maximum duration: it fires on release
    /// however long the finger was down. So holding for a lock fired the long
    /// press AND then the tap, and the tap releases a lock, so the feature
    /// cancelled itself every single time. Found by reading the gesture
    /// composition after shipping it, not by using it.
    ///
    /// Guarded on time rather than on a flag, because a flag that is set and
    /// never cleared eats a real tap later. This heals itself after a second
    /// whatever happens.
    @State private var lockedAt: Date?

    /// Pins focus and exposure where the finger was held.
    private func lock(at location: CGPoint) {
        guard let layer = previewBox.layer else { return }
        camera.lockFocusAndExposure(at: layer.captureDevicePointConverted(fromLayerPoint: location))
        lockedAt = Date()
        // Two knocks, because a lock is a state you are entering rather than
        // a thing that just happened.
        HapticsEngine.snap()
        withAnimation(GridConstants.motionSnappy) { focusPoint = location }
        focusShownAt = Date()
    }

    private func focus(at location: CGPoint) {
        // The release at the end of a hold is not a tap. See `lockedAt`.
        if let lockedAt, Date().timeIntervalSince(lockedAt) < 1 { return }
        guard let layer = previewBox.layer else { return }
        let devicePoint = layer.captureDevicePointConverted(fromLayerPoint: location)
        camera.focus(at: devicePoint)
        HapticsEngine.tick()
        withAnimation(GridConstants.motionSnappy) { focusPoint = location }
        focusShownAt = Date()
    }

    /// Shown when access was refused. Quiet, because it is an explanation
    /// rather than an alarm, and the app is not owed a camera.
    private var noCameraAccess: some View {
        VStack(spacing: GridConstants.gapWide) {
            Text("Apollo needs the camera to make a win a photograph.")
                .font(Typography.bodySmall)
                .foregroundStyle(AppColors.onDarkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)

            Button {
                HapticsEngine.lightTap()
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(Typography.headerSmall)
                    .foregroundStyle(.white)
                    .padding(.horizontal, GridConstants.gapWide)
                    .frame(height: 44)
                    .contentShape(Capsule())
                    .zoomGlass()
            }
            .buttonStyle(.pressWord)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, GridConstants.gapWide)
    }

    // MARK: - Guides

    /// **Flat, and the colour of what the camera is looking at.**
    ///
    /// The owner: "they look too much like glass; what I liked about my figma
    /// compared to this is it took the colour but it didn't emulate glass, it
    /// was more flat."
    ///
    /// He is describing his own node exactly: `#98A184` at half opacity, one
    /// flat stroke, no blur and no blend mode, in a colour lifted out of the
    /// grass behind it. `glassEffect` was reached for because a SwiftUI
    /// `Material` draws literally nothing over the camera's
    /// `UIViewRepresentable` — measured at zero pixels of difference — but
    /// glass has a refracted edge and a specular, and those are the thing he
    /// can see and does not want.
    ///
    /// `SceneTint` gets the relationship without the material: the camera is
    /// already measuring the whole frame's colour for white balance, so the
    /// line is painted from that, drained and lifted in the same proportion
    /// his line has to his grass. Flat paint, scene coloured, half opacity.
    private var guideInk: Color {
        graded.tint.colour.opacity(0.5)
    }

    /// How far a line is drawn back when the grid is off. Subtle on purpose:
    /// the motion should read as the grid settling onto the frame, not as a
    /// wipe. 12% of a line's length is about 100pt at the edges, which is
    /// enough to see and not enough to notice.
    private static let guideDrawBack: CGFloat = 0.88

    private func guides(w: CGFloat, h: CGFloat, topInset: CGFloat,
                        shown: Bool) -> some View {
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
            let draw = shown ? 1 : Self.guideDrawBack

            // The two halves of the broken vertical grow AWAY from the break,
            // so the line appears to come out of the title rather than to
            // arrive around it.
            Rectangle()
                .foregroundStyle(guideInk)
                .frame(width: Guide.width, height: max(gapTop, 0))
                .scaleEffect(x: 1, y: draw, anchor: .bottom)
                .offset(x: x0, y: 0)

            Rectangle()
                .foregroundStyle(guideInk)
                .frame(width: Guide.width, height: max(h - gapBottom, 0))
                .scaleEffect(x: 1, y: draw, anchor: .top)
                .offset(x: x0, y: gapBottom)

            Rectangle()
                .foregroundStyle(guideInk)
                .frame(width: Guide.width, height: h)
                .scaleEffect(x: 1, y: draw, anchor: .center)
                .offset(x: round(Guide.verticalX[1] * w) - Guide.width / 2, y: 0)

            ForEach(Guide.horizontalY, id: \.self) { fraction in
                Rectangle()
                    .foregroundStyle(guideInk)
                    .frame(width: w, height: Guide.width)
                    .scaleEffect(x: draw, y: 1, anchor: .center)
                    // Rounded to a whole point for the same reason the width
                    // is: a line at a fractional offset is smeared across two
                    // pixel rows and reads lighter than its neighbour.
                    .offset(x: 0, y: round(fraction * h) - Guide.width / 2)
            }
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .opacity(shown ? 1 : 0)
        // One curve for the fade and the draw, so they are one movement.
        // `naturalSettle` rather than `motionSmooth`: a grid arriving wants
        // to look like it is coming to rest, and 0.28 with a damping of 0.78
        // is the rung that does that. The toggle no longer wraps this in its
        // own `withAnimation`, because an animation declared at the value it
        // belongs to cannot be missed by a caller who forgets.
        .animation(GridConstants.naturalSettle, value: shown)
        // **No fade at the bottom.** The grid used to dissolve over the last
        // fifth of the frame, on the argument that ruled lines running into a
        // floating tab bar was two systems meeting at an edge neither drew.
        //
        // The owner: "I don't think I'm particularly the biggest fan of the
        // rule of thirds lines just because they fade away at the bottom,
        // which I think looks a bit cheap."
        //
        // He is right and the argument was already stale. The reason it was
        // added was lines hitting the bar; the viewfinder now ends in its own
        // rounded strip and CLIPS them, so they stop against a shape that is
        // part of the design rather than trailing off into nothing. A
        // gradient was solving a problem that the strip had already solved,
        // and a line that fades out is a line that looks like it failed to
        // draw. His file has no fade either: the strokes run the full frame.
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
            ApolloWordmark(height: Header.markHeight, color: .white)
                // Legible over whatever the lens is pointing at — the same
                // halo every other white thing on this screen uses.
                .legibleOverPhoto()

            Spacer(minLength: 0)

            // **His glass button, drawn in place and deliberately inert.**
            //
            // The owner: "The thing I do want to add is the glass button I
            // built. I think it looks so clean, but I don't know what it would
            // do, because before it was to close the screen and that doesn't
            // make sense any more."
            //
            // So it is built exactly as node 14172:8010 draws it — a 40pt
            // glass circle at the screen's 20pt margin, on the wordmark's row
            // — and it does NOTHING. Giving it an action would be inventing a
            // decision he has explicitly reserved, and a control that does
            // the wrong thing is worse than one that does nothing while he
            // looks at it.
            //
            // It is hidden from VoiceOver for the same reason: announcing a
            // button that cannot be used is a promise the screen does not
            // keep. Both go the moment it has a job.
        }
        // Top-aligned, and now the box is the wordmark's own height, so
        // top-aligned and centred are the same placement — which is the
        // point: the break holds the word and nothing else, so the word
        // cannot drift inside it.
        .frame(height: Header.height, alignment: .top)
        .padding(.horizontal, sideMargin)
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
            // Every white thing on the viewfinder carries the same halo.
            .legibleOverPhoto()
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
                .padding(.trailing, sideMargin)
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
    /// **The lens control, and on a phone with one lens it is still just the
    /// zoom pill it was.**
    ///
    /// It used to appear only once you had pinched past 1x and did one thing:
    /// go back. That was right when there was one piece of glass. Now that
    /// the ultra-wide and the telephoto are open, a control that can only
    /// return to the middle lens leaves two thirds of the camera reachable
    /// by pinch alone, and nobody pinches to find a lens — they tap.
    ///
    /// **One pill rather than a row of them.** The system camera draws 0.5x,
    /// 1x and 2x side by side; three buttons is three pieces of chrome on a
    /// photograph, and this screen's whole argument is that the picture is
    /// the only lit thing on it. So it is the pill that was already there,
    /// showing where the lens is, and a tap moves to the next stop and wraps.
    /// Pinch still goes anywhere in between.
    ///
    /// It is shown whenever there is more than one stop, because a control
    /// nobody can see is a lens nobody knows they have.
    private var zoomPill: some View {
        if camera.canZoom, camera.opticalStops.count > 1 || abs(camera.zoom - 1) > 0.005 {
            Button {
                HapticsEngine.lightTap()
                withAnimation(GridConstants.motionSnappy) { camera.setZoom(camera.nextStop) }
            } label: {
                Text(Self.zoomLabel(camera.zoom))
                    .font(Typography.bodySmall.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    // After the layout, not before: the material takes its
                    // shape from the final frame.
                    .frame(width: 56, height: 34)
                    .zoomGlass()
                    // **The capsule stays 34pt and the TARGET is 44.** The
                    // drawn pill is the size his frame draws it; the thing a
                    // thumb has to find is not. It was 34 tall, ten points
                    // under the floor every other control on this screen
                    // meets, and it is the one control that appears
                    // mid-gesture with a finger already moving. The extra
                    // ten points are invisible and are the difference
                    // between tapping it and tapping the viewfinder, which
                    // refocuses the shot.
                    .frame(width: 60, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // It grows out of the shutter's line rather than fading in on the
            // spot, which is what makes it read as belonging to the gesture
            // that produced it.
            .transition(.scale(scale: 0.7).combined(with: .opacity))
            .accessibilityLabel("Lens, \(Self.zoomLabel(camera.zoom))")
            .accessibilityHint("Switches to \(Self.zoomLabel(camera.nextStop))")
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
        glyphButton("timer",
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

    /// **One shape that changes, not two shapes that swap.**
    ///
    /// At rest it is his round shutter from node 14172:8010 — an 80pt ring and
    /// a 66pt fill in `#E6E6E6`. Press and hold and it becomes the block it is
    /// about to make, growing through the sizes as the finger draws, which is
    /// what the old rounded square did and what the circle had cost.
    ///
    /// The owner asked for it to "animate effortlessly in between states", and
    /// the way to get that is to never have two states in the view tree. Both
    /// faces are **the same `RoundedRectangle`**: only its frame and its corner
    /// radius differ, and SwiftUI interpolates both continuously. A circle is
    /// simply this rectangle at radius = side / 2. So there is no circle to
    /// dissolve and no rectangle to arrive — one object rounds off and grows.
    ///
    /// `.circular` rather than the app's usual `.continuous`, and the reason
    /// is the rest state: a continuous rounded rectangle at radius = side / 2
    /// is a squircle, visibly flatter down its sides than a circle, and the
    /// resting shutter is the thing he specified and the thing you look at
    /// almost all the time. The cost is that the block PREVIEW's corners are
    /// circular where a real block's are continuous, which is a fraction of a
    /// point at these radii and only visible while a finger is down.
    ///
    /// **The growth follows the gesture's own bands, not the raw finger.**
    /// `BlockSizeDraw` steps at 46pt to grow and 34 to shrink with 12 of
    /// hysteresis, and that banding is the feature — it is what makes a size
    /// commit rather than hover. What is continuous is the shape between those
    /// steps, each on `GridConstants.slotSnap`, the app's own rung at response
    /// 0.30 and damping **1.0**: critically damped, so it arrives and stops
    /// rather than wobbling into place.
    ///
    /// **Neutral, not the category's hue.** Both were drawn. The hue tells you
    /// what you are making, but the camera does not know the category — there
    /// is no `HabitCategory` anywhere in this file, because the win is not
    /// made until after the photograph — so it would have to be plumbed from
    /// the tower's next colour. And the shutter is the one control on the
    /// screen: turning it green mid-gesture reads as a state change in the
    /// CONTROL rather than a preview of the result. The size is the thing the
    /// gesture is choosing, so the size is the thing it previews.
    private var shutter: some View {
        let drawing = shutterDown && !reduceMotion
        let block = Self.shutterBounds(drawnSize)
        let outer = drawing ? block
                            : CGSize(width: Self.shutterRing, height: Self.shutterRing)
        let inner = drawing ? CGSize(width: block.width - 14, height: block.height - 14)
                            : CGSize(width: Self.shutterFill, height: Self.shutterFill)
        // A circle is this shape at half its side. The block's is the app's
        // own block radius ratio.
        let outerRadius = drawing ? min(outer.width, outer.height) * 0.147
                                  : min(outer.width, outer.height) / 2
        let innerRadius = drawing ? min(inner.width, inner.height) * 0.147
                                  : min(inner.width, inner.height) / 2

        return ZStack {
            RoundedRectangle(cornerRadius: outerRadius, style: .circular)
                .strokeBorder(Self.shutterInk, lineWidth: 1)
                .frame(width: outer.width, height: outer.height)

            RoundedRectangle(cornerRadius: innerRadius, style: .circular)
                .fill(Self.shutterInk)
                .frame(width: inner.width, height: inner.height)
                .scaleEffect(shutterScale)
        }
        .contentShape(RoundedRectangle(cornerRadius: outerRadius, style: .circular))
        .animation(GridConstants.slotSnap, value: shutterDown)
        .animation(GridConstants.slotSnap, value: drawnSize)
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
        // Shared with the head maker, so both light a face with one light.
        WarmRingLight(fillOpacity: fillOpacity)
    }

    /// **The front flash is the ring, and there is no second one.**
    ///
    /// There used to be a capture flash over this: a near-solid warm screen
    /// at the moment of the shot, on the argument that at that moment nothing
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
    /// shutter — so the blast was also the reason the front camera felt slow.
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

        // The screen has to be BRIGHT before the shutter opens, not with it —
        // the sensor is already metering by the time a simultaneous flash
        // arrives, so a flash fired on the same frame lights nothing.
        //
        // Brightness is already at 1.0 here: arming the flash lights the
        // modelling ring, and that is what raises it. `fire` only has to add
        // the fill.
        // **No wait before the shutter any more.** This used to raise a
        // capture flash and then sleep 220ms for auto-exposure to settle on
        // the new light. With the ring held on there is no new light: the
        // metering has been settled on it the whole time you were composing,
        // so the front camera fires as fast as the back one.
        Task { @MainActor in
            // **A look turns Apple's multi-frame processing off.** None is
            // "take the best photograph you can" and gets the whole fusion
            // stack; a look is "give me the picture I framed" and gets one
            // frame, so the still matches the viewfinder it was composed in.
            // See `CameraService.capture`.
            // A look means the sensor's own data and none of Apple's
            // finishing; None means the best photograph this phone can take.
            // See `CameraService.capture` and `RawDeveloper`.
            let wantsFilm = FilmLook.Kind(rawValue: lookRaw).map { $0 != .none } ?? false
            camera.capture(singleFrame: wantsFilm, raw: wantsFilm) { image in
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

/// Internal, not private: the head maker shows the same viewfinder, so it is
/// the app's camera rather than a second one that looks almost the same.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let box: PreviewLayerBox
    /// The graded surface, when there is one. Nil for the head maker, which
    /// wants the scene as the lens sees it and has its own frame output.
    var graded: GradedViewfinder? = nil

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        #if targetEnvironment(simulator)
        // **A stand-in scene, simulator only.**
        //
        // There is no camera here, so the viewfinder is a black rectangle and
        // nothing drawn over it can be judged: the thirds lines, the glass
        // button and the film-look container all exist to sit on a
        // photograph, and over black the button's blur has nothing to blur.
        // The owner's exact words about it were "I don't see it there in the
        // glass" — because there was nothing behind it.
        //
        // A bundled photograph behind the preview layer makes every one of
        // those judgeable on a screenshot. It can never reach a device:
        // `targetEnvironment(simulator)` is resolved at compile time, and on
        // hardware this block does not exist.
        // **Opt in only, and off by default even here.** It draws nothing
        // unless a launch argument names a scene: `-CameraStandIn DemoPhoto7`.
        //
        // It used to default to `DemoPhoto1`, which meant the simulator always
        // showed a photograph. That is a picture of the app rather than the
        // app, and the owner is now testing on his own phone, so the default
        // is no scene and the viewfinder here is black again unless somebody
        // deliberately asks for one.
        //
        // The glass and the guides over this viewfinder can only be judged
        // against a picture, and a single picture is not enough: the fault
        // that made the button read as "way brighter and too obvious" was
        // invisible over a bright sky (116% of the scene) and obvious over a
        // dark one (178%). That is why the seam is still here.
        if let name = UserDefaults.standard.string(forKey: "CameraStandIn"),
           let scene = UIImage(named: name) {
            let backing = UIImageView(image: scene)
            backing.contentMode = .scaleAspectFill
            backing.frame = view.bounds
            backing.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(backing)
            // **The guides take their colour from the camera, and here there
            // is none.** The stand-in exists so what is drawn OVER the
            // viewfinder can be judged on a screenshot, and a line painted
            // from the scene cannot be judged against a fallback grey. So the
            // stand-in measures itself once, exactly as a frame would.
            if let cg = scene.cgImage,
               let means = FilmLookRenderer.shared.measureMeans(CIImage(cgImage: cg)) {
                graded?.tint.update(sceneMean: means)
            }
        }
        #endif
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        box.layer = view.previewLayer

        // **On top of the preview layer, never instead of it.** The layer
        // keeps showing the scene the whole time, so a missing Metal device,
        // a stalled pipeline or simply no look selected all resolve to the
        // ordinary viewfinder rather than to black. It also stays the thing
        // that converts a tap into a focus point, which a `MTKView` cannot do.
        if let overlay = graded?.makeView() {
            overlay.frame = view.bounds
            overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(overlay)
        }
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
    /// Held rather than settled. A locked square is drawn heavier and stays
    /// on screen, which is the whole indicator.
    var locked: Bool = false

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
                .strokeBorder(Color(red: 1, green: 0.82, blue: 0.24),
                              lineWidth: locked ? 2.4 : 1.4)
                .frame(width: Self.side, height: Self.side)
                // A held square sits a little tighter than a settling one, so
                // the difference reads without a second element arriving.
                .scaleEffect(locked ? 0.88 : 1)
                .animation(GridConstants.motionSnappy, value: locked)

            Image(systemName: "sun.max.fill")
                .font(Typography.headerSmall)
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

// MARK: - His glass button

/// The button in the camera's top right corner, from node 14190:9740.
///
/// **His own component, not a system shape**, and the owner was explicit:
/// "The glass button in the corner has to be like the squarish design I made,
/// and mine was very custom."
///
/// Every value below is sampled from the node's own SVG rather than eyeballed
/// from a screenshot:
///
/// | | his node | built |
/// |---|---|---|
/// | size | 40 x 40 | 40 x 40 |
/// | corner radius | **9.9** | 9.9 |
/// | fill | `#080808` at **0.01** | the same |
/// | backdrop | `backdrop-filter: blur(8px)` | `.ultraThinMaterial` |
/// | stroke | `#CECECE` at **0.2pt** | the same |
/// | chevron | `M14 17 L20 23 L26 17`, 2pt, round caps | the same path |
/// | chevron ink | `#E6E6E6` | the same |
///
/// **Two things make it read as his rather than as a system control**, and
/// both are in those numbers. The radius is **9.9 on a 40pt square**, which is
/// squarish — a quarter of the side — where a system glass control of this
/// size is a circle. And the fill is **1% of the ground**, which is to say
/// nothing: the glassiness is entirely the backdrop blur, so whatever is
/// behind it tints it.
///
/// **There is no olive in the fill.** It reads olive in his frame because the
/// grass is behind it, exactly as the thirds lines do. That is why this uses a
/// material rather than a tinted colour: a baked olive would be right over his
/// lawn and wrong over everything else.
///
/// **It has no action, deliberately.** The owner: "I don't know what it would
/// do, because before it was to close the screen and that doesn't make sense
/// any more." It is inert and hidden from VoiceOver until he gives it a job;
/// announcing a button that cannot be used is a promise the screen does not
/// keep.
private struct CameraGlassButton: View {
    /// Which way the chevron points. Down invites the tray open; up closes it.
    var isOpen: Bool = false
    var action: (() -> Void)? = nil

    /// **The stroke is one physical pixel, not his 0.2pt, and that is why it
    /// was blurry.**
    ///
    /// The owner: "My button does look a little blurry, I would want it a bit
    /// better quality." Measured on the render rather than guessed — the pixel
    /// values across the button's left edge read `0, 0, 136, 31, 31, ...`, so
    /// the stroke was landing as a **single device pixel at 136** where
    /// `#CECECE` is 206. At 0.2pt on a 3x screen the line is **0.6 of a
    /// physical pixel**: it cannot land on the grid, so the renderer smears it
    /// and it arrives at about 60% of its own colour. That is not a colour
    /// that can be tuned brighter; it is a width that cannot be drawn.
    ///
    /// `1 / displayScale` is exactly one physical pixel at every scale —
    /// 0.333pt at 3x — which lands clean and draws `#CECECE` at full value.
    /// This file already records the same lesson for the thirds lines: "Half a
    /// point does not land on a pixel boundary at 3x, so each line was
    /// antialiased across two rows by a different amount."
    ///
    /// **Three other candidates were checked and cleared**, so the fix is the
    /// width and nothing else: the chevron is a vector `Path` drawn at his own
    /// coordinates rather than a rasterised asset; it sits ABOVE the material
    /// in the stack, so the blur samples what is behind the button and never
    /// its own contents; and the frame lands on x 342.00, a whole point and a
    /// whole device pixel, so there is no sub-pixel placement to correct.
    @Environment(\.displayScale) private var displayScale

    static let side: CGFloat = 40
    private static let radius: CGFloat = 9.9
    private static let strokeInk = Grey.g200
    private static let chevronInk = Grey.g100

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Self.radius, style: .continuous)
        return ZStack {
            shape
                .fill(Grey.g950.opacity(0.01))
                .background(.ultraThinMaterial, in: shape)

            // His path, at his scale: a 12 x 6 chevron centred in the 40pt
            // box, 2pt with round caps and joins.
            Path { p in
                p.move(to: CGPoint(x: 14, y: 17))
                p.addLine(to: CGPoint(x: 20, y: 23))
                p.addLine(to: CGPoint(x: 26, y: 17))
            }
            .stroke(Self.chevronInk,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .frame(width: Self.side, height: Self.side)

            shape.strokeBorder(Self.strokeInk, lineWidth: 1 / displayScale)
        }
        .frame(width: Self.side, height: Self.side)
        .rotationEffect(.degrees(isOpen ? 180 : 0))
        .contentShape(RoundedRectangle(cornerRadius: Self.radius, style: .continuous))
        .onTapGesture { action?() }
        // It has a job now, so it is a button to VoiceOver as well. It was
        // hidden while it was inert, because announcing a control that cannot
        // be used is a promise the screen does not keep.
        .accessibilityElement()
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Film look")
        .accessibilityValue(isOpen ? "Open" : "Closed")
    }
}


/// Simulator-only launch switches, for judging the viewfinder's chrome.
///
/// Chrome drawn over a photograph can only be measured against the same frame
/// without it: `-HideGuides 1` is to the thirds lines what `Glass.identity` is
/// to the button, an exact reference rather than a guess at which pixels the
/// line is on. Guessing is how they were once reported as invisible while they
/// were lifting.
///
/// `targetEnvironment(simulator)` is resolved at compile time, so none of this
/// exists on a device.
enum CameraTestSwitches {
    static var hideGuides: Bool {
        #if targetEnvironment(simulator)
        return UserDefaults.standard.bool(forKey: "HideGuides")
        #else
        return false
        #endif
    }
    static var forceGuides: Bool {
        #if targetEnvironment(simulator)
        return UserDefaults.standard.bool(forKey: "ForceGuides")
        #else
        return false
        #endif
    }
    static var trayOpen: Bool {
        #if targetEnvironment(simulator)
        return UserDefaults.standard.bool(forKey: "TrayOpen")
        #else
        return false
        #endif
    }
}

