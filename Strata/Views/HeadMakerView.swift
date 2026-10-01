import SwiftUI
import UIKit

/// Making your head, in Strata's own camera.
///
/// The same viewfinder, shutter block, flash and warm ring light as
/// `CameraView`, on the front lens — never the system camera, which would look
/// like leaving the app. A head-shaped outline comes up in the middle of
/// the screen; the shutter turns solid once you are in it; pressed, it asks
/// for a blink, a smile and raised brows in turn; then the viewfinder gives
/// way to the page and your head is left on it, alive.
/// Plan: `docs/profile-and-head-plan.md` §5.2.
///
/// **No wordmark, and nothing here describes this as watching.** The mark came
/// off every screen. The sentence above used to read "while it watches you
/// blink", which is the one register this screen can never use: it points a
/// camera at somebody's face, so the copy and these comments both stay on the
/// side of making a thing rather than observing a person.
///
/// No rule-of-thirds lines (the owner's call): the outline is the only
/// composition there is to follow.
///
/// **Capture cannot run in the simulator** — no camera, and no subject
/// lifting. Every state can be photographed with `-strataOpenHeadMaker`.
struct HeadMakerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model = HeadMakerModel()
    @State private var previewBox = PreviewLayerBox()
    /// 0 before the outline and its dim have arrived, 1 after.
    @State private var outlineDrawn: CGFloat = 0
    /// What the screen was set to before the ring light raised it.
    @State private var brightnessBeforeFlash: CGFloat?
    /// What this head will be called. Filled in when the preview arrives, so
    /// naming is something you can change rather than something you must do.
    @State private var name = ""

    /// `CameraView`'s viewfinder ground.
    private static let ground = Color(red: 0.031, green: 0.031, blue: 0.031)
    /// The new head, shown near the size of the thank-you page's.
    private static let previewSide: CGFloat = 200
    /// Room either side of the shutter for a control and its label, so the
    /// shutter stays dead centre whatever sits beside it.
    private static let sideSlot: CGFloat = 88
    /// `CameraView`'s shutter: a 66pt block inside a 14pt rim.
    /// One line of the prompt, reserved so the outline does not move when a
    /// prompt changes length.
    private static let promptHeight: CGFloat = 24
    /// A head is about three quarters as wide as it is tall.
    private static let headAspect: CGFloat = 0.76
    /// One of the marks that say how many expressions there are and how many
    /// have landed. A small block, at the block's own 14.7% corner: five of
    /// the thing this whole app is made of. (The comment here said four, in
    /// three places, after the surprised face made it five.)
    private static let pipSide: CGFloat = 7
    /// **The ladder's tightest rung, not a sixth number.** This was a bare 6,
    /// which is the one spacing value on the screen that is not on the scale
    /// (the rest are 16, 24 and 32). `gapTight` is 8, which is what it is for:
    /// the marks are five parts of one row, not five separate things, so they
    /// are not on `gapItem`. It also lands where Apple's own page control sits,
    /// a little more air between the marks than the marks are wide. The row is
    /// centred, so the 8pt it adds to the row's width moves nothing else.
    private static let pipGap: CGFloat = GridConstants.gapTight
    /// The mark for the expression being asked for right now: a 2x1 of the
    /// same block rather than a brighter 1x1. See `pips` for the measurement
    /// that ruled the brighter one out.
    private static let pipCurrentSide: CGFloat = pipSide * 2
    /// The name of the drawing `docs/illustrations.md` asks for on the state
    /// where no face was found: a figure holding a frame up to its own face,
    /// white because this screen is dark. Nothing ships under this name yet;
    /// `illustrationSlot` holds its room open and draws nothing until it does.
    private static let noFaceDrawing = "HeadMakerNoFace"

    var body: some View {
        GeometryReader { outer in
            let insets = outer.safeAreaInsets
            let screen = CGSize(width: outer.size.width, height: outer.size.height + insets.top + insets.bottom)
            let hole = headHole(screen: screen, insets: insets)
            ZStack {
                // The chrome sets the layout, inside the safe area; the
                // viewfinder is its BACKGROUND, reaching the screen's edges
                // without taking part in layout. As a sibling with a
                // full-screen frame it made the whole stack taller than the
                // safe area and pushed the shutter off the bottom of the
                // screen — measured on the first build.
                chrome
                    .frame(width: outer.size.width, height: outer.size.height)
                    .background { viewfinder(hole: hole).ignoresSafeArea() }
                    .environment(\.colorScheme, .dark)
                // The page comes up OVER the viewfinder, opaque, rather than
                // the two crossfading: two layers fading at once composite to
                // less than opaque and the black shows through (CLAUDE.md).
                if model.step == .preview, let result = model.result {
                    preview(result.rig)
                        .transition(.opacity)
                }
            }
            // **Both, not just the outline.** The target maps the outline on
            // screen through the camera's frame, so it depends on the frame's
            // size as much as on where the outline is drawn — and the frame's
            // real size only arrives with the first picture, after this has
            // already run once. Without the second trigger the whole session
            // measured against a guessed 1080x1920, which is how somebody
            // standing in the right place is told to move back however far
            // back they go. Reported from a phone: "it tells me to move back
            // when im in frame."
            .onChange(of: hole, initial: true) { _, hole in
                model.setTarget(target(for: hole, screen: screen))
            }
            .onChange(of: model.frameSize) { _, _ in
                model.setTarget(target(for: hole, screen: screen))
            }
        }
        .animation(reduceMotion ? GridConstants.crossFade : GridConstants.gentleReveal, value: model.step)
        .task {
            #if DEBUG
            if let state = DebugHarness.headMakerState {
                model.applyDebugState(state)
                return
            }
            #endif
            await model.start()
        }
        .onDisappear {
            model.stop()
            setFlashBrightness(false)
        }
        .onChange(of: model.step, initial: true) { _, step in respond(to: step) }
        .onChange(of: model.hint) { _, hint in
            guard model.step == .lining, let hint else { return }
            AccessibilityNotification.Announcement(hint.caption).post()
        }
    }

    // MARK: - Where the head goes

    /// The outline, in full-screen points: centred in the space between the
    /// close button and the prompt block, as tall as that space comfortably
    /// allows.
    ///
    /// **Both ends were measuring something that is not on the screen.**
    ///
    /// The top reserved `wordmarkSize`, 32pt, for a wordmark that came off on
    /// the owner's instruction. What is actually in that row is one 44pt
    /// `GlassIconButton`, so the top was 12pt short of the thing it was
    /// clearing.
    ///
    /// The bottom was worse, and it is the one that showed. It subtracted the
    /// shutter, one `gapWide` and the prompt, and stopped: the pip row and the
    /// gap above it were added to `chrome` later and never reached here. On a
    /// 402x874 screen that put the outline's floor at 656pt while the prompt's
    /// own box actually starts at 649. That is 31pt of overlap, and it only
    /// stayed invisible because the outline's height is capped by the screen's
    /// WIDTH and never reaches its floor. What it did do is drag the centre
    /// down by half the error: measured on the capture, 86pt of air above the
    /// outline against 61pt below it, on a shape whose whole job is to be the
    /// centre of the screen.
    ///
    /// So the block is built from the same pieces `chrome` stacks, in the same
    /// order, rather than re-listed by hand. Recomputed at 402x874 against a
    /// 62pt top inset and a 34pt bottom: 71.7pt above and 71.7pt below.
    private func headHole(screen: CGSize, insets: EdgeInsets) -> CGRect {
        let top = insets.top + GridConstants.headerArtworkTopPadding
            + GlassIconButton.defaultSide + GridConstants.gapWide
        // What `chrome`'s bottom VStack occupies, top of the prompt to the
        // bottom of the shutter.
        let promptBlock = Self.promptHeight + GridConstants.gapWide
            + Self.pipSide + GridConstants.gapWide
            + CameraView.shutterBounds(.small).height
        let bottom = screen.height - insets.bottom - GridConstants.gapSection
            - promptBlock - GridConstants.gapWide
        let available = max(bottom - top, 1)
        let height = min(available * 0.92, screen.width * 0.72 / Self.headAspect)
        let width = height * Self.headAspect
        let centreY = (top + bottom) / 2
        return CGRect(x: (screen.width - width) / 2, y: centreY - height / 2, width: width, height: height)
    }

    /// The outline turned into what the engine checks: the face's height and
    /// centre as shares of the camera frame, through the preview's aspect
    /// fill. The outline holds a whole head; the face is its lower part.
    private func target(for hole: CGRect, screen: CGSize) -> HeadFraming.Target {
        let frame = model.frameSize
        let scale = max(screen.width / frame.width, screen.height / frame.height)
        let shownHeight = frame.height * scale
        let dy = (shownHeight - screen.height) / 2
        let chinY = hole.maxY - hole.height * 0.04
        let faceHeight = hole.height / HeadFraming.headOverFace
        let faceCentreY = chinY - faceHeight / 2
        return HeadFraming.Target(height: faceHeight / shownHeight, centreY: (faceCentreY + dy) / shownHeight)
    }

    // MARK: - Viewfinder

    private var flashIsOn: Bool { model.camera.isFlashOn }

    /// Drawn in full-screen points: it sits behind the chrome with the safe
    /// area ignored, so its origin is the screen's top-left corner — the same
    /// space `headHole` is worked out in.
    private func viewfinder(hole: CGRect) -> some View {
        ZStack {
            Self.ground
            CameraPreview(session: model.camera.session, box: previewBox)
            // **When it has stopped, it looks stopped.** `fail(_:)` puts the
            // engine back to idle but leaves the capture session running, so
            // the failed state was a live picture of your face with "Couldn't
            // get a clear picture" written across it: a screen still working
            // at the one moment it has admitted it cannot. It is also the
            // ground the drawing needs. `docs/illustrations.md` asks for a
            // white figure here, and white flat art over a lit face is
            // unreadable whatever size it is drawn at.
            //
            // The session is left running rather than torn down, because Try
            // Again has to come back instantly and a restart is about a second.
            Self.ground
                .opacity(stilled ? 1 : 0)
                .animation(GridConstants.crossFade, value: stilled)
            // **Where your head goes, unmistakably.** From a phone: "the frame
            // [should be] more clear, like where you should put your face."
            // The outline was a one-point dash at 55% white, which on a live
            // camera image disappears into whatever is behind you, and the
            // dim around it was light enough that the hole did not read as a
            // hole. Darker outside, and a line that holds its own against the
            // picture before you are lined up as well as after.
            GeometryReader { geometry in
                HeadOutline.around(hole, in: geometry.size)
                    .fill(Color.black.opacity(0.6), style: FillStyle(eoFill: true))
                    .opacity(outlineDrawn)
            }
            // **It arrives; it does not draw itself.** This was
            // `.trim(from: 0, to: outlineDrawn)`, so the outline was stroked on
            // stroke by stroke over 0.55s of `layoutReflow` the moment the
            // camera came up. That is the thing on this screen that was there
            // to look designed: the flourish is a path assembling itself, and
            // the WORK is a complete shape you can stand your head in. The
            // design language's §5 is explicit both ways: nothing animates
            // because a screen appeared, and "if an animation makes the person
            // wait for it, it is wrong however good it looks". Half a second
            // is a long time to withhold the one guide this screen has, and a
            // partial head shape is not a head shape.
            //
            // It still fades up rather than snapping in, because the camera
            // going live IS something happening, on the reveal rung
            // (`naturalSettle`, §5's curve for arriving). Same opacity the dim
            // around it already came up on, so the hole and its edge arrive as
            // one object instead of a line being drawn over a darkened room.
            //
            // **One white, and it is the scale's.** The line was
            // `.white.opacity(isLinedUp ? 1 : 0.85)`, and 0.85 is not a value
            // this app has: `AppColors`'s own note says the dark screens each
            // reached for a white opacity of their own until an audit counted
            // more than twenty of them, and names this screen as one of the
            // three. 0.85 and 0.95 are 17.0:1 and 18.8:1 on the viewfinder's
            // ground, which is no signal at all; what actually says you are in
            // the outline is the dash closing up and the line going from 2pt to
            // 3pt. So the state is carried by the two channels that can be
            // seen, and the colour is one token.
            HeadOutline()
                .stroke(AppColors.onDarkStrong,
                        style: StrokeStyle(lineWidth: isLinedUp ? 3 : 2,
                                           lineCap: .round,
                                           dash: isLinedUp ? [] : [8, 7]))
                .frame(width: hole.width, height: hole.height)
                .position(x: hole.midX, y: hole.midY)
                .animation(GridConstants.motionSnappy, value: isLinedUp)
                // Outside the `isLinedUp` animation on purpose: the arrival is
                // its own transaction (`respond(to:)`), and the lining-up
                // spring has no business governing it.
                .opacity(outlineDrawn)
            illustrationSlot(hole: hole)
            // The camera's modelling ring, held on while the flash is armed.
            // It lights the face the frames are read from, and a face in good
            // light is a face Vision can find the eyes of.
            WarmRingLight(fillOpacity: WarmRingLight.modellingFill)
                .opacity(flashIsOn ? WarmRingLight.modellingLevel : 0)
                .animation(GridConstants.crossFade, value: flashIsOn)
        }
        .allowsHitTesting(false)
    }

    private var isLinedUp: Bool {
        switch model.step {
        case .lining: return model.hint == nil
        case .blink, .smile, .brows, .surprised, .wink, .blinkAgain, .making: return true
        default: return false
        }
    }

    /// The two states where there is nothing left to point the camera at.
    private var stilled: Bool {
        model.step == .failed || model.step == .unavailable
    }

    /// **The drawing's room, held open before there is a drawing.**
    ///
    /// `docs/illustrations.md` asks for one here: a figure holding a frame up
    /// to its own face, for the state where no face was found, drawn white
    /// because this screen is dark. Until it exists this is air, which is the
    /// honest version of what the state already was.
    ///
    /// **Its room is the outline's room**, the same centre and the same width,
    /// so the thing you were looking at is answered in place rather than the
    /// page rearranging itself around a failure. Measured on the capture
    /// before this: 515pt of nothing between the close button and the message,
    /// and 98.1% of the page pure black, because the failed state was being
    /// laid out by a viewfinder, which is bottom weighted because a
    /// viewfinder's subject is the picture, and there was no picture.
    ///
    /// Square, not the outline's 0.76 portrait: the doc's format line is
    /// "viewBox square or 4:3", and a square centred on the outline's centre
    /// claims only the height a square drawing will use.
    ///
    /// `.unavailable` gets the room and not the drawing. The planned figure is
    /// holding a frame up because a face could not be found in one, which is
    /// not what a missing camera is; the drawing for that is the Camera
    /// section's own ("a figure with a hand over the lens") and it is not
    /// this screen's to invent.
    ///
    /// `UIImage(named:)` rather than `Image(_:)` because `Image` of a missing
    /// asset draws a warning placeholder and this has to draw nothing. Same
    /// pattern, and the same reason, as `OnboardingView.mark`.
    private func illustrationSlot(hole: CGRect) -> some View {
        Color.clear
            .frame(width: hole.width, height: hole.width)
            .overlay {
                if let art = UIImage(named: Self.noFaceDrawing) {
                    Image(uiImage: art)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(AppColors.onDarkStrong)
                }
            }
            .position(x: hole.midX, y: hole.midY)
            .opacity(model.step == .failed ? 1 : 0)
            .animation(GridConstants.crossFade, value: model.step)
            .accessibilityHidden(true)
    }

    // MARK: - Chrome

    private var chrome: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: GridConstants.gapTight) {
                // **No wordmark here either.** The camera's came off on the
                // owner's instruction and this is the same object in the same
                // situation: the app's name over a live lens, on a screen you
                // reached by tapping the app's own icon. Said out loud in the
                // reply rather than slipped in, because he named the camera and
                // not this.
                Spacer(minLength: 0)
                // **The offset went with the wordmark.** It was
                // `(wordmarkSize - defaultSide) / 2`, which centred a 44pt disc
                // on a 32pt mark's cap: with nothing to centre on it was just
                // 6pt of lift, and it put this button 6pt above the line every
                // other artwork header in the app sits on
                // (`headerArtworkTopPadding`). Measured on the capture: top at
                // 75.0pt, against the 80.8pt `CameraView`'s own close sits on,
                // which is the same inset plus the same padding and no offset.
                // That file deleted its `wordmarkSize` when the mark came off;
                // this one kept the arithmetic that depended on it.
                GlassIconButton(systemName: "xmark", tint: AppColors.onDarkStrong,
                                glyphSize: 16,
                                accessibilityLabel: "Close") { dismiss() }
            }
            .padding(.horizontal, GridConstants.horizontalPadding)
            .padding(.top, GridConstants.headerArtworkTopPadding)

            Spacer(minLength: 0)

            VStack(spacing: GridConstants.gapWide) {
                Text(prompt)
                    .font(Typography.headerMedium)
                    // `AppColors`'s dark scale, not a raw white. Its own note
                    // names the head maker as one of the three screens that
                    // made the scale necessary, and this was the last raw white
                    // on it.
                    .foregroundStyle(AppColors.onDarkStrong)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(minHeight: Self.promptHeight)
                    .legibleOnImagery()
                    .padding(.horizontal, GridConstants.gapWide)
                    .contentTransition(.opacity)
                    .animation(GridConstants.crossFade, value: prompt)
                    .accessibilityAddTraits(.updatesFrequently)
                pips
                controls
            }
            .padding(.bottom, GridConstants.gapSection)
        }
    }

    private var prompt: String {
        switch model.step {
        case .starting:    return " "
        case .unavailable: return "The camera isn't available here."
        case .lining:
            // Once the shutter will take, say so. Holding the correction up
            // while the shutter is already lit is the screen contradicting
            // itself, and the outline is still there to guide by.
            guard !model.canCapture else { return "Press when you're ready" }
            return model.hint?.caption ?? "Press when you're ready"
        // **"Got it" is the whole point of this pass.** From a phone: "idk if
        // it is working." The maker used to ask for four expressions in seven
        // seconds and acknowledge none of them, and whether a smile had been
        // caught was only ever said afterwards, on the preview caption, as an
        // apology. It is the same judgement that decides whether the smile is
        // kept, so it cannot say this and then not have it.
        case .blink:       return model.caught ? "Got it" : "Blink slowly"
        case .smile:       return model.caught ? "Got it" : "Now a big smile"
        case .brows:       return model.caught ? "Got it" : "Raise your eyebrows"
        case .surprised:   return model.caught ? "Got it" : "Now look surprised"
        // "Last" only when it is: a missed blink is asked for again after it.
        case .wink:        return model.caught ? "Got it" : (model.landed.contains(.blink) ? "Last one, a wink" : "Now a wink")
        // Only when the first blink was missed. Without one the head can
        // never blink, so it is worth one more second.
        case .blinkAgain:  return model.caught ? "Got it" : "One more quick blink"
        case .making:      return "Making your head…"
        case .preview:     return " "
        case .failed:      return model.failure
        }
    }

    /// Five marks: how many expressions there are, and how many have landed.
    ///
    /// The other half of "idk if it is working" is not knowing how much is
    /// left. They are shown from the moment the outline does, quiet and empty,
    /// so pressing the shutter is not a step into the dark — you can see
    /// there are five things before you agree to any of them.
    ///
    /// **Its height is reserved whether or not it is drawn**, the camera's
    /// own rule for the zoom pill: a mark that appears by pushing the shutter
    /// down moves the one control on this screen that must not move.
    /// **Two facts, two channels.** Lightness says done or not. Width says
    /// which one is being asked for. They used to share lightness, and sharing
    /// it made the row say the opposite of what it meant.
    ///
    /// The empty mark was `.white.opacity(0.28)` and the current one was that
    /// plus a 1pt white border. On a 7pt square a 1pt border is 24 of the 49
    /// square points, so the current mark's mean lightness was 0.49 of white
    /// from the ring plus 0.51 of 0.28 from the fill: 0.63, against 0.28 for a
    /// mark not yet asked for and 1.0 for one that is done. The mark that means
    /// "you are here, and it has not landed" rendered two thirds of the way to
    /// done. Growing the square does not fix it, because a bright ring always
    /// adds lightness in the one direction it must not: at 12pt the mean is
    /// still 0.78, at 16pt 0.73.
    ///
    /// So the current mark is a 2x1 of the same block at the same lightness,
    /// which is this app's own shape vocabulary (`CameraView`'s shutter: "a 2x1
    /// in this app is not two blocks, it is one block two cells wide") and the
    /// corner stays the height's 14.7% so the two read as the same object.
    ///
    /// **And the fill is a token, because 0.28 failed.** Measured off the
    /// capture, the empty marks came out rgb(71, 71, 71) on the viewfinder's
    /// ground: 2.26:1, against the 3:1 a shape has to clear. `onDarkQuiet` is
    /// 6.2:1, and it is the scale's own quietest readable step.
    ///
    /// **The row's width is reserved too.** With one mark 7pt wider than the
    /// rest, a row sized to its content would breathe by 7pt the moment the
    /// shutter is pressed, and it is centred under a centred prompt where that
    /// shows. `.lining` and `.making` have no current mark; the frame holds the
    /// width they would otherwise give back.
    ///
    /// **Its height is reserved whether or not it is drawn**, the camera's
    /// own rule for the zoom pill: a mark that appears by pushing the shutter
    /// down moves the one control on this screen that must not move.
    private var pips: some View {
        let steps = HeadMakerModel.sequence.map(\.step)
        let rowWidth = Self.pipCurrentSide
            + Self.pipSide * CGFloat(steps.count - 1)
            + Self.pipGap * CGFloat(steps.count - 1)
        return HStack(spacing: Self.pipGap) {
            ForEach(steps, id: \.self) { step in
                let done = model.landed.contains(step)
                let current = HeadMakerModel.pip(for: model.step) == step
                RoundedRectangle(cornerRadius: Self.pipSide * 0.147, style: .continuous)
                    .fill(done ? Color.white : AppColors.onDarkQuiet)
                    .frame(width: current ? Self.pipCurrentSide : Self.pipSide,
                           height: Self.pipSide)
            }
        }
        .frame(width: rowWidth, height: Self.pipSide)
        .legibleOnImagery()
        .opacity(showsPips ? 1 : 0)
        .animation(GridConstants.crossFade, value: model.landed)
        .animation(GridConstants.crossFade, value: showsPips)
        // The mark widens because somebody finished the expression before it,
        // on the snappy rung the outline's own state change uses.
        .animation(GridConstants.motionSnappy, value: model.step)
        .accessibilityLabel("\(model.landed.count) of \(steps.count) done")
    }

    private var showsPips: Bool {
        switch model.step {
        case .lining, .blink, .smile, .brows, .surprised, .wink, .blinkAgain, .making: return true
        default: return false
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch model.step {
        case .failed, .unavailable:
            Button {
                HapticsEngine.lightTap()
                if model.step == .failed { model.retake() } else { dismiss() }
            } label: {
                Text(model.step == .failed ? "Try Again" : "Close")
                    .font(Typography.headerSmall)
                    .foregroundStyle(AppColors.onDarkStrong)
                    .frame(minWidth: Self.sideSlot, minHeight: GlassIconButton.defaultSide)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(height: CameraView.shutterBounds(.small).height)
        default:
            // `CameraView`'s own row, slot for slot — grid, flash, shutter,
            // flip, timer — with only the flash filled, so the flash is exactly
            // where a thumb that has used the camera expects it. The other
            // three are empty rather than moved together, which would put the
            // flash somewhere it has never been.
            HStack(spacing: 0) {
                Color.clear.frame(width: GlassIconButton.defaultSide, height: GlassIconButton.defaultSide)
                Spacer(minLength: 0)
                flashButton
                Spacer(minLength: 0)
                shutter
                Spacer(minLength: 0)
                Color.clear.frame(width: GlassIconButton.defaultSide, height: GlassIconButton.defaultSide)
                Spacer(minLength: 0)
                Color.clear.frame(width: GlassIconButton.defaultSide, height: GlassIconButton.defaultSide)
            }
            .padding(.horizontal, GlassIconButton.defaultSide)
        }
    }

    /// `CameraView`'s flash glyph, and the same light behind it.
    private var flashButton: some View {
        Button {
            HapticsEngine.tick()
            model.camera.isFlashOn.toggle()
            setFlashBrightness(model.camera.isFlashOn)
        } label: {
            Image(systemName: flashIsOn ? "bolt.fill" : "bolt.slash.fill")
                // A glyph's point size, not a type tier: `CameraView.glyphButton`
                // is this same 21 and the two rows have to match, or the flash
                // is a different size in two places a thumb treats as one
                // control.
                .font(.system(size: 21, weight: .regular))
                .foregroundStyle(AppColors.onDarkStrong)
                .legibleOnImagery()
                .frame(width: GlassIconButton.defaultSide, height: GlassIconButton.defaultSide)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(flashIsOn ? "Flash on" : "Flash off")
    }

    /// `CameraView`'s shutter: one block at the block's own 14.7% corner, in a
    /// rim. Dim until your head is in the outline, and solid from the moment
    /// it will take until the head is made.
    ///
    /// **It used to fill from the bottom as a timer, and that had to go.** A
    /// stage now ends when the expression lands rather than when a clock runs
    /// out, so a bar driven by the clock would be telling you something that
    /// is no longer true. The pips above carry progress, and they carry it
    /// next to the prompt you are reading rather than at the bottom edge of a
    /// screen you are not looking at. Two readings of one fact is the mistake
    /// the tower header already made once — "the filter said Day while the
    /// title said Today" — so there is one.
    private var shutter: some View {
        let ready = model.canCapture
        let watching: Bool = [.blink, .smile, .brows, .surprised, .wink, .blinkAgain, .making].contains(model.step)
        let lit = ready || watching
        // **One control, drawn in one place.** This and `CameraView`'s were
        // two copies of the same rim and block from the same bounds and the
        // same corner, and the day the audit went through both they came out
        // disagreeing: this one an empty rim when unlit, that one still a
        // dimmed fill. `ShutterBlock` carries the shape, the rim, the corner
        // and the unlit state, with the measurements that chose them. No
        // `Legibility` here: that treatment answers a white wall seen through
        // a viewfinder, and this screen's ground is its own dimmed outline.
        let block = ShutterBlock(size: .small, lit: lit)

        return Button {
            model.beginCapture()
        } label: {
            block.contentShape(block.shape)
        }
        .buttonStyle(.plain)
        // **Disabled on `lit`, not on `ready`**, measured, because a disabled
        // plain button is dimmed by the environment and the block came out at
        // 128 of 255 during capture instead of white. A shutter that goes
        // half grey the moment it starts taking says the opposite of what is
        // happening. `beginCapture()` guards on `isLinedUp` itself, so a
        // press while it is watching does nothing either way.
        .disabled(!lit)
        .animation(GridConstants.motionSnappy, value: lit)
        .accessibilityLabel(watching ? "Taking" : "Start")
        // **The progress is the pips', and it is said once.** This hint used
        // to read "\(landed.count) of \(sequence.count) done", which is the
        // same
        // sentence the row of marks immediately above it already carries as
        // its own label. Two elements, six points apart, reporting one number
        // is exactly the fault the comment over `shutter` cites against the
        // tower header ("the filter said Day while the title said Today"), and
        // it is the one the Memories page was cut back for on 2026-09-23. The
        // marks are where that fact is drawn, so the marks keep it, and the
        // shutter says what the shutter is for.
        .accessibilityHint(watching
                           ? "Hold still while the expressions are taken"
                           : ready
                           ? "Takes a slow blink, a smile, raised eyebrows, a surprised face and a wink"
                           : "Line your head up in the outline first")
    }

    /// Raises the screen for the ring light and puts it back — `CameraView`'s
    /// rule: set only on the way up, cleared on the way down, and restored on
    /// every exit, so nobody is left with a screen pinned at full brightness.
    private func setFlashBrightness(_ on: Bool) {
        if on {
            if brightnessBeforeFlash == nil { brightnessBeforeFlash = UIScreen.main.brightness }
            UIScreen.main.brightness = 1.0
        } else if let previous = brightnessBeforeFlash {
            UIScreen.main.brightness = previous
            brightnessBeforeFlash = nil
        }
    }

    // MARK: - The head, on the page

    private func preview(_ rig: HeadRig) -> some View {
        ZStack {
            WarmBackground().ignoresSafeArea()
            VStack(spacing: GridConstants.gapWide) {
                Spacer(minLength: 0)
                // Expressive, and it says hello: brows, then a smile. The
                // first thing a new head does is show it is alive. Tap it
                // for an expression.
                TappableHead(rig: rig, side: Self.previewSide, greets: true)
                VStack(spacing: GridConstants.gapTight) {
                    // **The name, and it never blocks finishing.** It arrives
                    // filled in, so Save works without a keyboard ever
                    // appearing; clearing it keeps the suggestion rather than
                    // leaving a head with no name. The owner asked for several
                    // heads on 2026-09-23 ("add your friend's head"), and a row
                    // of unnamed faces is a row you have to guess at.
                    //
                    // Profile's own name field, to the point: a bare centred
                    // field at header size, no well and no rule under it.
                    TextField("Name", text: $name)
                        .font(Typography.headerMedium)
                        .foregroundStyle(AppColors.inkPrimary)
                        .multilineTextAlignment(.center)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        // **A field with no well is still a target.** A bare
                        // centred `TextField` at `headerMedium` is 20.3pt of
                        // line box and nothing else, so the only way into the
                        // name was a 20.3pt strip, under half the 44 every
                        // other control on this screen measures. The well stays
                        // off (it is Profile's own field, to the point); what it
                        // gets is the height, and a `contentShape` so the air
                        // above and below the word takes the tap too.
                        .frame(minHeight: GlassIconButton.defaultSide)
                        .contentShape(Rectangle())
                        .padding(.horizontal, GridConstants.gapSection)
                        .accessibilityLabel("This head's name")
                    Text(previewCaption(rig))
                        .font(Typography.bodySmall)
                        .foregroundStyle(AppColors.inkSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, GridConstants.gapSection)
                }
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    Button {
                        HapticsEngine.tick()
                        model.retake()
                    } label: {
                        Text("Retake")
                            .font(Typography.headerSmall)
                            .foregroundStyle(AppColors.inkSecondary)
                            .frame(minWidth: Self.sideSlot, minHeight: GlassIconButton.defaultSide,
                                   alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    Spacer(minLength: 0)
                    Button {
                        if model.save() {
                            // The head is on disk before the name is applied,
                            // so a name that will not stick can never cost
                            // somebody the head they just made. An empty field
                            // is ignored and the suggestion stands.
                            if let id = HeadStore.shared.activeID {
                                HeadStore.shared.rename(id, to: name)
                            }
                            HapticsEngine.success()
                            dismiss()
                        }
                    } label: {
                        Text("Save")
                            .font(Typography.headerSmall)
                            .foregroundStyle(AppColors.accentWarm)
                            .frame(minWidth: Self.sideSlot, minHeight: GlassIconButton.defaultSide,
                                   alignment: .trailing)
                            .contentShape(Rectangle())
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, GridConstants.gapWide)
                .padding(.bottom, GridConstants.gapSection)
            }
        }
    }

    /// Says what this head can do, honestly — including what it can't.
    private func previewCaption(_ rig: HeadRig) -> String {
        var missing: [String] = []
        if rig.shut == nil { missing.append("blink") }
        if !rig.has(.smile) { missing.append("smile") }
        if !rig.has(.browsUp) { missing.append("raise its brows") }
        if !rig.has(.surprised) { missing.append("look surprised") }
        if !rig.has(.wink) { missing.append("wink") }
        guard !missing.isEmpty else {
            return "Your head is ready. It only shows up where you turn it on."
        }
        return "Your head is ready, but it won't \(missing.joined(separator: " or ")). Retake if you'd like to try again."
    }

    // MARK: - Steps

    private func respond(to step: HeadMakerModel.Step) {
        switch step {
        case .lining:
            // `naturalSettle`, §5's reveal rung, not `layoutReflow`: nothing
            // here is reflowing, and 0.55s was outside the ladder for an
            // arrival. See the outline in `viewfinder(hole:)`.
            withAnimation(reduceMotion ? nil : GridConstants.naturalSettle) { outlineDrawn = 1 }
        case .blink, .smile, .brows, .surprised, .wink, .blinkAgain:
            outlineDrawn = 1
        // **It was latched on, and a screenshot could never show it.**
        // `outlineDrawn` is set to 1 at `.lining` and nothing ever put it back,
        // so a failure after lining up left the dashed head outline and its
        // 0.6 dim drawn over "Couldn't get a clear picture": the screen still
        // telling you where to stand under a sentence saying it had stopped
        // trying. The captures never caught it because `-strataOpenHeadMaker
        // failed` jumps straight to the state and never passes through
        // `.lining`, so `outlineDrawn` is still 0 in every photograph of it.
        //
        // `crossFade`, not the reveal rung: this is a thing leaving, and §5's
        // out-curve is the short one.
        case .failed, .unavailable:
            withAnimation(reduceMotion ? nil : GridConstants.crossFade) { outlineDrawn = 0 }
        case .preview:
            // The page is lit by the room, not by a ring the viewfinder needed.
            setFlashBrightness(false)
            // The first head takes the name in Profile, because it is you.
            // After that they are numbered: guessing whose head it is would be
            // worse than not guessing.
            name = HeadStore.shared.suggestedName(person: ProfileStore.shared.name)
        default:
            break
        }
    }
}

/// A head's outline: a rounded crown, full cheeks, and a broad jaw that
/// rounds into the chin — not a capsule, which is a pill you are asked to fit
/// a face into, and not an egg with a pointed chin, which the first version
/// was and which read as a balloon.
struct HeadOutline: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var path = Path()
        path.move(to: p(0.5, 0))
        // Crown to the widest point, at the temples.
        path.addCurve(to: p(1.0, 0.36), control1: p(0.84, 0.0), control2: p(1.0, 0.14))
        // Down the cheek, staying full almost to the jaw.
        path.addCurve(to: p(0.90, 0.76), control1: p(1.0, 0.56), control2: p(0.98, 0.67))
        // A broad jaw and a wide, round chin. The second version still came
        // to a point and read as an egg.
        path.addCurve(to: p(0.5, 1.0), control1: p(0.82, 0.90), control2: p(0.68, 1.0))
        path.addCurve(to: p(0.10, 0.76), control1: p(0.32, 1.0), control2: p(0.18, 0.90))
        path.addCurve(to: p(0.0, 0.36), control1: p(0.02, 0.67), control2: p(0.0, 0.56))
        path.addCurve(to: p(0.5, 0), control1: p(0.0, 0.14), control2: p(0.16, 0.0))
        path.closeSubpath()
        return path
    }

    /// The whole screen with a head-shaped hole in it — filled even-odd, it
    /// dims the viewfinder around the outline.
    static func around(_ hole: CGRect, in screen: CGSize) -> Path {
        var path = Path(CGRect(origin: .zero, size: screen))
        path.addPath(HeadOutline().path(in: hole))
        return path
    }
}
