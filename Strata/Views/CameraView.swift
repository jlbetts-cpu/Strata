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
    var onCaptured: (UIImage) -> Void = { _ in }
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
        static let height: CGFloat = 72
        /// Air between the header and the cut ends of the line.
        static let breathing: CGFloat = 14
        /// Cap height for the wordmark.
        ///
        /// It was 61, which is what Jaro needed to set "Strata" 147pt wide.
        /// The wordmark is now the owner's own letterforms, and they are a
        /// much wider face — 6.5:1 against Jaro's 2.4:1 — so 61 ran the word
        /// 396pt across a 370pt page and clipped the final `a`. At 40 it sets
        /// about 260pt, which fills the header as a band without touching
        /// either margin.
        static let wordmarkSize: CGFloat = 40
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
                CameraPreview(session: camera.session)

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
                        .font(.system(size: 96, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 14)
                        .transition(.opacity.combined(with: .scale(scale: 1.25)))
                        .id(countdown)
                        .allowsHitTesting(false)
                        .accessibilityLabel("\(countdown) seconds")
                }

                controls(w: w, h: h, topInset: topInset, bottomInset: bottomInset)

                warmFlash
                    .allowsHitTesting(false)
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
        .onDisappear {
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
            // 61pt, solved rather than chosen: it is the size at which Jaro
            // sets "Strata" 147pt wide with a 41pt cap height, which is the
            // wordmark's measured box in the Figma frame.
            StrataWordmark(size: Self.Header.wordmarkSize, color: .white)
                // Legible over whatever the lens is pointing at.
                .shadow(color: .black.opacity(0.40), radius: 10, x: 0, y: 1)

            Spacer(minLength: 0)
        }
        // Top-aligned, not centred. The box is 72pt and a 61pt line is about
        // that tall, so centring only moved the wordmark by a fraction of a
        // point — but it put the cap somewhere the shared rule could not
        // predict, and the rule is the point.
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

                shutter

                Spacer(minLength: 0)

                glyphButton("arrow.triangle.2.circlepath", label: "Switch camera") {
                    withAnimation(GridConstants.motionSmooth) { camera.flip() }
                }

                Spacer(minLength: 0)

                timerButton
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
                    .font(.system(size: 10, weight: .medium, design: .rounded))
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
    private var shutter: some View {
        let outerRadius = shutterOuter * 0.147
        let innerRadius = shutterInner * 0.147
        return ZStack {
            RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                .strokeBorder(.white, lineWidth: 1)
                .frame(width: shutterOuter, height: shutterOuter)

            RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                .fill(.white)
                .frame(width: shutterInner, height: shutterInner)
                .scaleEffect(shutterScale)
        }
        .contentShape(RoundedRectangle(cornerRadius: outerRadius, style: .continuous))
        .onTapGesture { shutterPressed() }
        .accessibilityLabel("Take photo")
        .accessibilityAddTraits(.isButton)
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
                guard let image else { return }
                HapticsEngine.success()
                // The full-resolution frame, before `ImageManager` downscales
                // it to 1024px for the block. This is the only place it
                // exists, so it is the only place the camera roll can be
                // given the real photograph.
                //
                // No second haptic on success: `HapticsEngine.success()` above
                // has already confirmed the shot, and buzzing again when a
                // background write lands would be two confirmations for one
                // action.
                Task { await PhotoLibrarySaver.save(image) }
                onCaptured(image)
            }
        }
    }
}

/// The live preview, as a layer rather than a view.
///
/// `AVCaptureVideoPreviewLayer` is the only thing that can render the session,
/// and it has to be resized by hand — a layer does not participate in Auto
/// Layout, so without this it keeps whatever bounds it had when it was made.
private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
