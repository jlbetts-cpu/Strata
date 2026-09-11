import SwiftUI
import UIKit

/// Making your head, in Strata's own camera.
///
/// The same viewfinder, wordmark, shutter block, flash and warm ring light as
/// `CameraView`, on the front lens — never the system camera, which would look
/// like leaving the app. A head-shaped outline draws itself in the middle of
/// the screen; the shutter turns solid once you are in it; pressed, its block
/// fills while it watches you blink, smile and raise your brows; then the
/// viewfinder gives way to the page and your head is left on it, alive.
/// Plan: `docs/profile-and-head-plan.md` §5.2.
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
    /// 0 before the outline has drawn itself, 1 after.
    @State private var outlineDrawn: CGFloat = 0
    /// How much of the shutter's block has filled while the expressions are
    /// watched.
    @State private var fill: CGFloat = 0
    /// What the screen was set to before the ring light raised it.
    @State private var brightnessBeforeFlash: CGFloat?

    /// `CameraView`'s viewfinder ground.
    private static let ground = Color(red: 0.031, green: 0.031, blue: 0.031)
    /// The wordmark at the camera's own size.
    private static let wordmarkSize: CGFloat = 32
    /// The new head, shown near the size of the thank-you page's.
    private static let previewSide: CGFloat = 200
    /// Room either side of the shutter for a control and its label, so the
    /// shutter stays dead centre whatever sits beside it.
    private static let sideSlot: CGFloat = 88
    /// `CameraView`'s shutter: a 66pt block inside a 14pt rim.
    private static let shutterRim: CGFloat = 14
    /// One line of the prompt, reserved so the outline does not move when a
    /// prompt changes length.
    private static let promptHeight: CGFloat = 24
    /// A head is about three quarters as wide as it is tall.
    private static let headAspect: CGFloat = 0.76

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
            .onChange(of: hole, initial: true) { _, hole in
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
    /// wordmark and the prompt, as tall as that space comfortably allows.
    private func headHole(screen: CGSize, insets: EdgeInsets) -> CGRect {
        let top = insets.top + GridConstants.headerArtworkTopPadding + Self.wordmarkSize + GridConstants.gapWide
        let bottom = screen.height - insets.bottom - GridConstants.gapSection
            - CameraView.shutterBounds(.small).height - GridConstants.gapWide - Self.promptHeight
            - GridConstants.gapWide
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
            GeometryReader { geometry in
                HeadOutline.around(hole, in: geometry.size)
                    .fill(Color.black.opacity(0.45), style: FillStyle(eoFill: true))
                    .opacity(outlineDrawn)
            }
            HeadOutline()
                .trim(from: 0, to: outlineDrawn)
                .stroke(Color.white.opacity(isLinedUp ? 1 : 0.55),
                        style: StrokeStyle(lineWidth: isLinedUp ? 2 : 1,
                                           lineCap: .round,
                                           dash: isLinedUp ? [] : [5, 6]))
                .frame(width: hole.width, height: hole.height)
                .position(x: hole.midX, y: hole.midY)
                .animation(GridConstants.motionSnappy, value: isLinedUp)
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
        case .blink, .smile, .brows, .surprised, .making: return true
        default: return false
        }
    }

    // MARK: - Chrome

    private var chrome: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: GridConstants.gapTight) {
                StrataWordmark(size: Self.wordmarkSize, color: .white)
                    .shadow(color: .black.opacity(0.40), radius: 10, x: 0, y: 1)
                Spacer(minLength: 0)
                GlassIconButton(systemName: "xmark", tint: .white, glyphSize: 16,
                                accessibilityLabel: "Close") { dismiss() }
                    // Centred on the wordmark's cap, like the Memories gear.
                    .offset(y: (Self.wordmarkSize - GlassIconButton.defaultSide) / 2)
            }
            .padding(.horizontal, GridConstants.horizontalPadding)
            .padding(.top, GridConstants.headerArtworkTopPadding)

            Spacer(minLength: 0)

            VStack(spacing: GridConstants.gapWide) {
                Text(prompt)
                    .font(Typography.headerMedium)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(minHeight: Self.promptHeight)
                    .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 1)
                    .padding(.horizontal, GridConstants.gapWide)
                    .contentTransition(.opacity)
                    .animation(GridConstants.crossFade, value: prompt)
                    .accessibilityAddTraits(.updatesFrequently)
                controls
            }
            .padding(.bottom, GridConstants.gapSection)
        }
    }

    private var prompt: String {
        switch model.step {
        case .starting:    return " "
        case .unavailable: return "The camera isn't available here."
        case .lining:      return model.hint?.caption ?? "Press when you're ready"
        case .blink:       return "Blink slowly"
        case .smile:       return "Now a big smile"
        case .brows:       return "Raise your eyebrows"
        case .surprised:   return "Now look surprised"
        case .making:      return "Making your head…"
        case .preview:     return " "
        case .failed:      return model.failure
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
                    .foregroundStyle(.white)
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
                .font(.system(size: 21, weight: .regular))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 1)
                .frame(width: GlassIconButton.defaultSide, height: GlassIconButton.defaultSide)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(flashIsOn ? "Flash on" : "Flash off")
    }

    /// `CameraView`'s shutter: one block at the block's own 14.7% corner, in a
    /// rim. Dim until your head is in the outline, solid when it will take,
    /// and while it watches the block fills from the bottom — a timer with no
    /// numbers, in the control that means "taking".
    private var shutter: some View {
        let outer = CameraView.shutterBounds(.small)
        let inner = CGSize(width: outer.width - Self.shutterRim, height: outer.height - Self.shutterRim)
        let outerRadius = outer.width * 0.147
        let innerRadius = inner.width * 0.147
        let ready = model.isLinedUp
        let watching = [.blink, .smile, .brows, .surprised, .making].contains(model.step)

        return Button {
            model.beginCapture()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                    .strokeBorder(.white, lineWidth: 1)
                    .frame(width: outer.width, height: outer.height)
                RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                    .fill(.white.opacity(ready ? 1 : 0.3))
                    .frame(width: inner.width, height: inner.height)
                if watching {
                    RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                        .fill(.white)
                        .frame(width: inner.width, height: inner.height)
                        .mask(alignment: .bottom) {
                            Rectangle().frame(height: inner.height * fill)
                        }
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: outerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!ready)
        .animation(GridConstants.motionSnappy, value: ready)
        .accessibilityLabel("Start")
        .accessibilityHint(ready
                           ? "Takes a slow blink, a smile, raised eyebrows and a surprised face"
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
                // first thing a new head does is show it is alive.
                LivingHeadView(rig: rig, side: Self.previewSide, liveliness: .expressive, greets: true)
                VStack(spacing: GridConstants.gapTight) {
                    Text("Looking good")
                        .font(Typography.headerLarge)
                        .foregroundStyle(.primary.opacity(0.9))
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
        guard !missing.isEmpty else {
            return "Your head is ready. It only shows up where you turn it on."
        }
        return "Your head is ready, but it won't \(missing.joined(separator: " or ")). Retake if you'd like to try again."
    }

    // MARK: - Steps

    private func respond(to step: HeadMakerModel.Step) {
        switch step {
        case .lining:
            fill = 0
            withAnimation(reduceMotion ? nil : GridConstants.layoutReflow) { outlineDrawn = 1 }
        case .blink:
            outlineDrawn = 1
            fill = 0
            // Linear, and not a spring token: this is a clock, not a
            // movement, and a clock that eases lies about how long is left.
            withAnimation(.linear(duration: 2.2)) { fill = 0.32 }
        case .smile:
            outlineDrawn = 1
            withAnimation(.linear(duration: 1.6)) { fill = 0.55 }
        case .brows:
            outlineDrawn = 1
            withAnimation(.linear(duration: 1.6)) { fill = 0.78 }
        case .surprised:
            outlineDrawn = 1
            withAnimation(.linear(duration: 1.6)) { fill = 1 }
        case .preview:
            // The page is lit by the room, not by a ring the viewfinder needed.
            setFlashBrightness(false)
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
