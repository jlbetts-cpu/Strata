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
    /// What somebody typed, and nothing until they do. Empty means they were
    /// happy with `suggestion`, which is what the head is then called.
    @State private var name = ""
    /// What this head will be called if nobody says otherwise. Worked out when
    /// the preview arrives and DRAWN rather than typed into the field, so that
    /// naming stays something you can change rather than something you must do,
    /// and so the line reads as the hint it is. See `nameField`.
    @State private var suggestion = ""

    /// `CameraView`'s viewfinder ground.
    private static let ground = Color(red: 0.031, green: 0.031, blue: 0.031)
    /// The new head, shown near the size of the thank-you page's.
    private static let previewSide: CGFloat = 200
    /// Room either side of the shutter for a control and its label, so the
    /// shutter stays dead centre whatever sits beside it.
    private static let sideSlot: CGFloat = 88
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
    /// The Camera section's own drawing, white: a figure with a hand over the
    /// lens. Shared rather than drawn again: see `illustrationSlot` for why
    /// this screen's dead end is the camera's dead end. Nothing ships under
    /// this name yet either.
    private static let noCameraDrawing = "CameraNoAccess"

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
        // A sentence that replaces another sentence in place is the one kind of
        // change VoiceOver can miss entirely: nothing moved, nothing gained
        // focus, and the person may be nowhere near the caption. The error
        // haptic answers the press for everybody else.
        .onChange(of: model.saveFailure) { _, failure in
            guard !failure.isEmpty else { return }
            AccessibilityNotification.Announcement(failure).post()
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

    /// **One list of the asking steps, not three.** This file wrote out
    /// "blink, smile, brows, surprised, wink, blinkAgain" by hand in three
    /// places (here, in `showsPips` and in `shutter`), and its own comment
    /// records the bill for that: "The comment here said four, in three places",
    /// after the surprised face made it five. The list lives on the model now,
    /// built from the sequence it already publishes, and this is the one thing
    /// the screen adds to it: making the head is still pointing the camera at
    /// somebody, so the outline stays closed and the shutter stays lit through
    /// it.
    private var taking: Bool { model.isAsking || model.step == .making }

    private var isLinedUp: Bool {
        model.step == .lining ? model.hint == nil : taking
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
    /// **`.unavailable` holds the Camera section's drawing, not one of its
    /// own.** It used to get the room and nothing else, on the reasoning that
    /// the planned figure holds a frame up because a face was not found in one,
    /// which a missing camera is not. That half was right and the conclusion
    /// was wrong, because of what `.unavailable` actually is: `CameraService`
    /// leaves `isConfigured` false both when there is no camera and when there
    /// is one the app has not been allowed to use, and on a phone only the
    /// second ever happens. So this state is the Camera tab's refused state,
    /// reached through a different door. The doc already plans a drawing for
    /// that door, white, and the right move is to walk through it rather than
    /// to invent a twenty-fourth drawing: one situation, one drawing, and the
    /// two screens say the same thing about the same switch.
    ///
    /// It holds for the other half too, thinly. A hand over the lens is about
    /// as true of a camera that is not there as any one figure could be, and
    /// the alternative is a drawing commissioned for a state only the simulator
    /// can reach.
    ///
    /// `UIImage(named:)` rather than `Image(_:)` because `Image` of a missing
    /// asset draws a warning placeholder and this has to draw nothing. Same
    /// pattern, and the same reason, as `OnboardingView.mark`.
    private func illustrationSlot(hole: CGRect) -> some View {
        Color.clear
            .frame(width: hole.width, height: hole.width)
            .overlay {
                if let asset = drawing, let art = UIImage(named: asset) {
                    Image(uiImage: art)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(AppColors.onDarkStrong)
                }
            }
            .position(x: hole.midX, y: hole.midY)
            .opacity(drawing == nil ? 0 : 1)
            .animation(GridConstants.crossFade, value: model.step)
            .accessibilityHidden(true)
    }

    /// Which drawing this state holds, or none. The two states that have one
    /// are terminal and neither can follow the other, so nothing ever swaps
    /// drawings mid-fade.
    private var drawing: String? {
        switch model.step {
        case .failed: return Self.noFaceDrawing
        case .unavailable: return Self.noCameraDrawing
        default: return nil
        }
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
        // **The dead end had a way out and never said so.** This was one
        // sentence for two situations: a camera that is not there, and a
        // camera the app has not been allowed to use. On a phone it is always
        // the second, and "isn't available here" is both wrong about it and
        // silent about the switch that fixes it, on the one screen somebody
        // reached by choosing to make a head. `CameraView` names the
        // permission and says where it lives; this now says the same thing in
        // the one line this screen has for a sentence, and the button under it
        // goes there.
        //
        // The camera's own wording, short of its title: "Turn the camera on
        // for Strata in Settings and this becomes the viewfinder." The second
        // half is the camera tab explaining what it would be; here the person
        // already knows what they came for.
        case .unavailable:
            return model.isDenied
                ? "Turn the camera on for Strata in Settings."
                : "The camera isn't available here."
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
    private var pips: some View {
        let steps = HeadMakerModel.sequence.map(\.step)
        let rowWidth = Self.pipCurrentSide
            + Self.pipSide * CGFloat(steps.count - 1)
            + Self.pipGap * CGFloat(steps.count - 1)
        return HStack(spacing: Self.pipGap) {
            ForEach(steps, id: \.self) { step in
                let done = model.landed.contains(step)
                let current = HeadMakerModel.pip(for: model.step) == step
                // **`ShutterBlock.cornerFraction`, not a literal 0.147.** The
                // whole argument for this shape is that a mark is a small one
                // of the thing the shutter draws, and that argument was being
                // made by two files agreeing on a number by hand. It is the
                // shared view's number now, which is the same lift the shutter
                // itself just had.
                RoundedRectangle(cornerRadius: Self.pipSide * ShutterBlock.cornerFraction,
                                 style: .continuous)
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

    private var showsPips: Bool { taking || model.step == .lining }

    @ViewBuilder
    private var controls: some View {
        switch model.step {
        // **One button, and it says what it will do.** `.failed` is reachable
        // only from `make()`, which fails before a head exists, so Try Again
        // means take it again and costs nothing to press. `.unavailable` is
        // the one with a choice: when the camera is off for Strata rather than
        // absent there is a switch to go and turn on, and a button that only
        // closed was the second half of a dead end that was never one.
        //
        // The close control top right is unchanged and is still the way out of
        // all three, so nothing here is the only exit.
        case .failed, .unavailable:
            Button {
                HapticsEngine.lightTap()
                switch model.step {
                case .failed:
                    model.retake()
                default:
                    // It does not try to re-ask, for `CameraView`'s reason:
                    // once the answer is no, iOS will not present the prompt
                    // again, and a button that looked like it might is worse
                    // than one that says where the switch really is.
                    if model.isDenied, let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    } else {
                        dismiss()
                    }
                }
            } label: {
                Text(model.step == .failed ? "Try Again" : (model.isDenied ? "Open Settings" : "Close"))
                    .font(Typography.headerSmall)
                    .foregroundStyle(AppColors.onDarkStrong)
                    .frame(minWidth: Self.sideSlot, minHeight: GlassIconButton.defaultSide)
                    .contentShape(Rectangle())
            }
            // `.pressWord` for a word, not `.plain`, which draws the label and
            // nothing else (`docs/consistency-audit.md` §1.8: twenty controls in
            // the app with no answer to a finger, and the camera's own refused
            // screen two files away already uses this). "A word at 6% reads as a
            // wobble, so it moves less and dims more."
            .buttonStyle(.pressWord)
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
                // A glyph's point size, not a type tier: `CameraView`'s own
                // chrome glyph is this same 21 and the two rows have to match,
                // or the flash is a different size in two places a thumb treats
                // as one control.
                //
                // **`iconSize`, and this was the last fixed icon size in the
                // app** (2026-10-02, `docs/consistency-audit.md` §1.15).
                // `IconStyle`'s own doc is the rule: "`.font(.system(size:))` is
                // a fixed size, it does not respond to the user's text size at
                // all, so icons stayed put while the labels beside them grew",
                // and brand.md asks for Dynamic Type on every screen (WCAG
                // 1.4.4). The camera's twin moved first and kept its 21 the same
                // way; keeping the number is what keeps the two rows matching,
                // and `relativeTo: .body` is what the twin passes, so the pair
                // grows at one rate.
                .iconSize(21, relativeTo: .body, weight: .regular)
                .foregroundStyle(AppColors.onDarkStrong)
                .legibleOnImagery()
                .frame(width: GlassIconButton.defaultSide, height: GlassIconButton.defaultSide)
                .contentShape(Rectangle())
        }
        // `.press` for a glyph. `PressResponse` names this exact control in its
        // own doc — "the plain-glyph row: the grid, the flash, the flip and the
        // timer" — and then had no call sites on any of them.
        .buttonStyle(.press)
        .accessibilityLabel(flashIsOn ? "Flash on" : "Flash off")
    }

    /// `ShutterBlock`: one block at the block's own 14.7% corner, in a rim.
    /// An empty rim until your head is in the outline, and solid from the
    /// moment it will take until the head is made.
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
        let watching = taking
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
            // **`spacing: 0`, and every gap on this page is now declared where
            // it belongs.** It was `gapWide`, which put 24 between the head and
            // its name as well as between the name and the controls, and those
            // two gaps are not the same kind of thing: one is inside an object
            // and the other is the page's break.
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                // **The head and its name are ONE object, so there is no gap
                // declared between them** (2026-10-01, check 11b).
                //
                // Measured before: the page's five gaps were 186.7, 38.3, 26.3,
                // 225.3 and 48.3, and clause 11b asks a page of three or more
                // gaps for at least one at 17pt or less. The smallest here was
                // 26.3 and the page failed. `docs/space.md`'s P1 is why that is
                // a real failure and not a number miss: with nothing tight on
                // the page, nothing on it groups, so the head, the name and the
                // caption read as three separate things rather than as a
                // portrait with a caption under it.
                //
                // **The 26.3 was never 8pt of spacing.** `nameField` reserves
                // `GlassIconButton.defaultSide` (44) so a bare centred field is
                // still a 44pt target, and its 20.3pt line box sits in the
                // middle of that, which puts 11.9pt of slack above the word
                // before any declared gap is added. So a declared `gapTight`
                // measures about 22 here and a declared `gapWide` measured
                // 38.3. Declaring nothing leaves the field's own slack, which
                // is what a caption's gap should be anyway: the name is the
                // portrait's label, not the next thing down the page.
                TappableHead(rig: rig, side: Self.previewSide, greets: true)
                VStack(spacing: GridConstants.gapTight) {
                    nameField
                    // **The failure takes the caption's place rather than
                    // sitting under it.** Two sentences here would be the one
                    // thing this page cannot afford: the caption says what the
                    // head can do, which is a thing to know before you press
                    // Save and not while you are being told the press did not
                    // take. One slot, whichever sentence is the live one.
                    //
                    // **And the slot is empty when neither has anything to
                    // say** (cut 7, see `previewCaption`), which is why this is
                    // an `if let` rather than a `Text` of a possibly empty
                    // string: an empty `Text` still takes a line box, and the
                    // emptiness this page is built on would have a 20pt hole in
                    // it. The animation moved onto the stack for the same
                    // reason — a view that is being inserted and removed cannot
                    // carry the animation for its own arrival.
                    //
                    // `inkPrimary`, not the caption's `inkSecondary`: it is the
                    // only line on the page that has changed since you looked
                    // away, and 14.2:1 against the caption's 6.1 on this page's
                    // (246, 246, 246) is what says so, without a colour this
                    // page has no other use for.
                    if let line = model.saveFailure.isEmpty
                        ? previewCaption(rig) : model.saveFailure {
                        Text(line)
                            .font(Typography.screenSubtitle)
                            .foregroundStyle(model.saveFailure.isEmpty
                                             ? AppColors.inkSecondary : AppColors.inkPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, GridConstants.gapSection)
                    }
                }
                .animation(GridConstants.crossFade, value: model.saveFailure)
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
                            // means the drawn suggestion was accepted, which is
                            // the name the page has been showing all along.
                            if let id = HeadStore.shared.activeID {
                                HeadStore.shared.rename(id, to: name.isEmpty ? suggestion : name)
                            }
                            HapticsEngine.success()
                            dismiss()
                        }
                    } label: {
                        // **The verb changes with what the press will do.** A
                        // save that failed and a button still reading Save is
                        // a press with no visible answer; the sentence above
                        // carries what happened and this carries what happens
                        // next. It is not "Try Again", which is Retake's
                        // meaning on this same row and would make the two
                        // controls read as the same offer.
                        Text(model.saveFailure.isEmpty ? "Save" : "Try Saving Again")
                            .font(Typography.headerSmall)
                            // **`inkPrimary`, AND IT WAS A FIXED WHITE NOBODY
                            // COULD SEE** (2026-10-01, `docs/consistency-audit.md`).
                            //
                            // `AppColors.onDarkStrong` is `white.opacity(0.95)`
                            // and this page's ground is `WarmBackground`, so on
                            // the light page the word rendered **rgb(239) on
                            // rgb(243), 1.04:1**. Retake, on the same row, is
                            // `inkSecondary` at rgb(91), **6.11:1**. The press
                            // that keeps a head somebody has just spent two
                            // minutes making was the one thing on the screen
                            // that could not be seen.
                            //
                            // It is the fault `CLAUDE.md` records about
                            // `.primary.opacity(x)` wearing its other hat: **a
                            // fixed white is not a colour, it is a colour in
                            // dark mode.** The `onDark*` scale is measured
                            // against the VIEWFINDER's black, which is the page
                            // two steps back in this flow and not this one — the
                            // same structural note the add sheet's audit wrote
                            // about the review screen.
                            //
                            // **`inkPrimary` because it inverts with the
                            // scheme**: rgb(37) on the light page, near white on
                            // the night one, about 14:1 either way round. It is
                            // what Profile's Done wears, so the two sheets that
                            // both end in a press agree.
                            //
                            // **The old comment argued for `accentPrimary` and
                            // its hazard is kept, because it is real.** It said
                            // a near-black Save sits at the same weight as the
                            // name field above it. The ROW answers that: Retake
                            // is `inkSecondary` at 6.11:1 beside this at 14:1, a
                            // 2.3x step inside the one band that holds both
                            // controls, and that is what says which of the two
                            // is the press. The name is a field you type in,
                            // centred, 200pt up the page, not the other half of
                            // this pair. `accentPrimary` would also now be the
                            // only blue word in the app, which is a worse kind
                            // of odd one out than a strong ink.
                            .foregroundStyle(AppColors.inkPrimary)
                            .frame(minWidth: Self.sideSlot, minHeight: GlassIconButton.defaultSide,
                                   alignment: .trailing)
                            .contentShape(Rectangle())
                    }
                }
                // **`.pressWord`, and these are the two most-pressed words in the
                // whole capture flow** (2026-10-01,
                // `docs/consistency-audit.md` §1.8). The camera's refused screen
                // uses `.pressWord`; its review's Retake and Use Photo, two
                // screens later, were `.plain`, and so were this row's Retake and
                // Save. So the one press that keeps a head somebody has just made
                // answered with nothing on screen at all.
                .buttonStyle(.pressWord)
                // **`horizontalPadding`, and it was `gapWide`** (2026-10-01,
                // check 11d). Measured off the built preview, Retake's ink
                // started at 25.3 and Save's ended at 377.0 — a 24pt margin on
                // the one screen in the app whose siblings are all on 16. The
                // audit has made this exact correction twice already, on
                // Restore ("A 24pt margin — the app is 16") and on Store
                // unavailable ("A 32pt margin"), and this row is the third. The
                // vertical `gapSection` stays: that one is a floor, not a
                // margin, and it puts the controls at the same height as the
                // walkthrough's and Store unavailable's.
                .padding(.horizontal, GridConstants.horizontalPadding)
                .padding(.bottom, GridConstants.gapSection)
            }
        }
    }

    /// **The name, and it never blocks finishing.** The owner asked for several
    /// heads on 2026-09-23 ("add your friend's head"), and a row of unnamed
    /// faces is a row you have to guess at. So a name is always decided, Save
    /// works without a keyboard ever appearing, and nothing here has to be
    /// touched.
    ///
    /// **Nothing said it could be typed into.** Measured off the preview
    /// capture: "Head 2" rendered (36, 36, 36) on a (246, 246, 246) page, a
    /// centred near-black line directly under the head, identical in every
    /// visual respect to a title. Somebody who wanted to call it "Me" had no
    /// reason to try.
    ///
    /// The lightest treatment that says editable is the one already true: this
    /// is a SUGGESTION, not a name somebody chose. So it is drawn as the hint
    /// it is, at `inkQuiet`, and the field under it is empty until somebody
    /// types. That composites to (135, 135, 135) on this page, 3.3:1, which is
    /// the ratio `inkQuiet` is held to and the category its own doc names
    /// first: "a chevron, a placeholder, a hint". It is also what Profile's
    /// name field does, two taps away, for the measurement written over it.
    ///
    /// Everything louder was tried on paper and costs more than it returns: an
    /// underline or a well is a boxed form field on a page whose whole argument
    /// is emptiness, a pencil glyph is a twenty-fourth drawing nobody asked
    /// for, and a caret needs focus, which needs the keyboard this screen is
    /// built to not need.
    ///
    /// **Drawn rather than handed to `prompt:`**, for the reason written over
    /// `ProfileView.nameField`: the style set on a prompt's `Text` is not
    /// applied by every control that takes one, and a contrast fix that may or
    /// may not land is not a fix.
    ///
    /// **A field with no well is still a target.** A bare centred `TextField`
    /// at `headerMedium` is 20.3pt of line box and nothing else, so the only
    /// way into the name was a 20.3pt strip, under half the 44 every other
    /// control on this screen measures. The height and the `contentShape` are
    /// on the stack, so the air above and below the word takes the tap too.
    private var nameField: some View {
        ZStack {
            if name.isEmpty {
                Text(suggestion)
                    .font(Typography.headerMedium)
                    .foregroundStyle(AppColors.inkQuiet)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            TextField("", text: $name)
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.inkPrimary)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .accessibilityLabel("This head's name")
                // The suggestion is what this head will be called, so it is
                // what VoiceOver reads, empty field or not.
                .accessibilityValue(name.isEmpty ? suggestion : name)
        }
        .multilineTextAlignment(.center)
        .frame(minHeight: GlassIconButton.defaultSide)
        .contentShape(Rectangle())
        .padding(.horizontal, GridConstants.gapSection)
    }

    /// Says what this head CANNOT do, and says nothing at all when it can do
    /// everything.
    ///
    /// **The happy sentence is cut** (cut 7, `docs/copy-audit.md`,
    /// 2026-10-01). It read "Your head is ready. It only shows up where you
    /// turn it on." over a head that is on screen, blinking, and greeting you.
    /// The first half describes a head anybody can see is ready. The second
    /// half is the same sentence as `ProfileView`'s one-head footer, which is
    /// where somebody stands when "where does it show up" is actually their
    /// question, and that one was cut on the same day for saying what four
    /// labelled switches already say.
    ///
    /// Measured on the built preview at 402x874: it was the biggest piece of
    /// ink on the page after the head itself, two wrapped lines, a 31.7pt band
    /// sitting 26.3pt under the name and competing with it. What is left is a
    /// portrait, its name, and two words to press.
    ///
    /// **The honest branch stays**, which is why this returns an optional
    /// rather than being deleted: it names the one thing no picture can show,
    /// which is what this head will never be able to do.
    private func previewCaption(_ rig: HeadRig) -> String? {
        Self.previewCaption(blinks: rig.shut != nil,
                            smiles: rig.has(.smile),
                            raisesBrows: rig.has(.browsUp),
                            isSurprised: rig.has(.surprised),
                            winks: rig.has(.wink))
    }

    /// The sentence itself, over the five facts it is made of rather than over
    /// a `HeadRig`.
    ///
    /// Split out so `SettingsAndProfileCopyTests` can hold both branches —
    /// nothing when the head is whole, the honest list when it is not —
    /// without building a rig out of images, a simulator or a camera. The rig
    /// is read in exactly one place, immediately above.
    static func previewCaption(blinks: Bool, smiles: Bool, raisesBrows: Bool,
                               isSurprised: Bool, winks: Bool) -> String? {
        var missing: [String] = []
        if !blinks { missing.append("blink") }
        if !smiles { missing.append("smile") }
        if !raisesBrows { missing.append("raise its brows") }
        if !isSurprised { missing.append("look surprised") }
        if !winks { missing.append("wink") }
        guard !missing.isEmpty else { return nil }
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
            //
            // **Worked out here and applied on Save**, rather than left to the
            // store's own default, because the two do not agree: `HeadStore`
            // names a nameless save with `suggestedName()` and no person, which
            // for a first head is "Me" even when Profile knows you are Jayden.
            // The screen must not show one name and save another.
            //
            // A name somebody typed survives a Retake on purpose: it is the
            // same head being made again, and retyping it is work this screen
            // has already made somebody do once.
            suggestion = HeadStore.shared.suggestedName(person: ProfileStore.shared.name)
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
