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
    /// Today's count, shown in the gap the guides leave open.
    var winCount: Int? = nil

    @State private var camera = CameraService()
    @State private var flashOpacity: Double = 0
    @State private var shutterScale: CGFloat = 1
    @State private var previousBrightness: CGFloat = UIScreen.main.brightness
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Geometry, from the Figma frame (402 x 874)

    /// Rule-of-quarters guides. Two verticals and two horizontals, which is
    /// what the design specifies — not a full nine-cell thirds grid.
    private enum Guide {
        /// Thirds, evenly. The Figma has them at 0.25/0.74 and 0.26/0.50,
        /// which is a designer eyeballing a grid rather than a grid — the
        /// cells came out different sizes. This is the rule of thirds the
        /// iPhone camera draws, and it is the one everybody composing a shot
        /// is expecting.
        static let verticalX: [CGFloat] = [1.0 / 3.0, 2.0 / 3.0]
        static let horizontalY: [CGFloat] = [1.0 / 3.0, 2.0 / 3.0]
        /// The break in the first vertical, left open for the mark and the
        /// count. Kept at the design's proportions.
        static let gapTop: CGFloat = 48.0 / 874.0
        static let gapBottom: CGFloat = 127.0 / 874.0
        static let colour = Color.white.opacity(0.28)
        static let width: CGFloat = 0.5
    }

    private let cornerRadius: CGFloat = 20
    /// Distance from the right edge to the centre of the control column.
    private let controlInset: CGFloat = 40
    private let shutterOuter: CGFloat = 80
    private let shutterInner: CGFloat = 66
    /// Where the design puts the shutter's centre: 131pt up from the bottom of
    /// an 874pt frame. Kept as the reference the runtime placement matches.
    private let shutterBottomGap: CGFloat = 874.0 - 743.0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                Color(red: 0.031, green: 0.031, blue: 0.031)
                    .ignoresSafeArea()

                CameraPreview(session: camera.session)
                    .clipShape(
                        .rect(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: cornerRadius,
                            bottomTrailingRadius: cornerRadius,
                            topTrailingRadius: 0
                        )
                    )
                    .ignoresSafeArea()

                // Drawn over the whole preview, which is full-bleed — so the
                // thirds have to be thirds of the SCREEN, not of the area left
                // over after the tab bar. Computed against the safe box they
                // came out at 0.35 and 0.63: not thirds, and not even
                // symmetrical.
                guides(
                    w: w + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing,
                    h: h + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
                )
                .offset(x: -geo.safeAreaInsets.leading, y: -geo.safeAreaInsets.top)
                .allowsHitTesting(false)

                controls(w: w, h: h, bottomInset: geo.safeAreaInsets.bottom)

                if let winCount {
                    tally(winCount, topInset: geo.safeAreaInsets.top)
                        .allowsHitTesting(false)
                }

                warmFlash
                    .allowsHitTesting(false)
            }
        }
        .background(Color.black.ignoresSafeArea())
        // No `.preferredColorScheme(.dark)`.
        //
        // It was here so the status bar would be legible on a black preview.
        // Applied inside a tab it propagates to the WHOLE WINDOW: `.primary`
        // flipped to white, so the tower's "N wins" became white text on the
        // light background and vanished, and the tab bar stayed dark after
        // leaving the camera. The app is light-only by decision and one screen
        // does not get to argue with that.
        //
        // It turned out not to be needed: over a black preview the status bar
        // renders light on its own. Hiding it instead was worse — collapsing
        // the top safe area made the tab bar draw a ghost of itself along the
        // top edge.
        .statusBarHidden(false)
        .task { await camera.start() }
        .onDisappear {
            camera.stop()
            UIScreen.main.brightness = previousBrightness
        }
    }

    // MARK: - Guides

    private func guides(w: CGFloat, h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // The first vertical is broken near the top. The gap is not a
            // rendering artefact — it is reserved space for the mark, and the
            // line resuming below it is what makes the break read as
            // deliberate rather than as a line that failed to draw.
            let x0 = Guide.verticalX[0] * w
            Rectangle()
                .fill(Guide.colour)
                .frame(width: Guide.width, height: Guide.gapTop * h)
                .offset(x: x0, y: 0)

            Rectangle()
                .fill(Guide.colour)
                .frame(width: Guide.width, height: h - Guide.gapBottom * h)
                .offset(x: x0, y: Guide.gapBottom * h)

            Rectangle()
                .fill(Guide.colour)
                .frame(width: Guide.width, height: h)
                .offset(x: Guide.verticalX[1] * w, y: 0)

            ForEach(Guide.horizontalY, id: \.self) { fraction in
                Rectangle()
                    .fill(Guide.colour)
                    .frame(width: w, height: Guide.width)
                    .offset(x: 0, y: fraction * h)
            }
        }
        .frame(width: w, height: h, alignment: .topLeading)
    }

    /// The count, in the gap.
    ///
    /// The guides leave a break in the top-left vertical, and this is what
    /// goes in it. It sits at exactly the offset the tower's header uses — the
    /// same 4pt below the safe area, the same horizontal padding, the same
    /// 40pt rounded numeral — so moving between the two screens does not move
    /// the number. It is the same fact in the same place, wearing the colours
    /// of whichever page you are on.
    private func tally(_ count: Int, topInset: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(count)")
                .font(.system(size: 40, weight: .medium, design: .rounded))
                .foregroundStyle(Color(white: 0.96))
                .contentTransition(.numericText())
            Text(count == 1 ? "win" : "wins")
                .font(Typography.bodyMedium)
                .foregroundStyle(Color(white: 0.96).opacity(0.55))
            Spacer(minLength: 0)
        }
        // Legible over anything the lens happens to be pointing at.
        .shadow(color: .black.opacity(0.45), radius: 8, x: 0, y: 1)
        .padding(.horizontal, GridConstants.horizontalPadding)
        .padding(.top, topInset + 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Controls

    private func controls(w: CGFloat, h: CGFloat, bottomInset: CGFloat) -> some View {
        // The design has nothing below the shutter; this screen has a tab bar.
        // Measuring up from the safe area keeps the same visual gap under the
        // button that the design has, instead of letting the tab bar sit on it.
        let shutterCentre = h - bottomInset - shutterOuter / 2 - 52
        return ZStack(alignment: .topLeading) {
            glyphButton("arrow.triangle.2.circlepath") {
                withAnimation(GridConstants.motionSmooth) { camera.flip() }
            }
            .position(x: w - controlInset, y: 86)
            .accessibilityLabel("Switch camera")

            glyphButton(camera.isFlashOn ? "bolt.fill" : "bolt.slash.fill") {
                camera.isFlashOn.toggle()
            }
            .position(x: w - controlInset, y: 140)
            .accessibilityLabel(camera.isFlashOn ? "Flash on" : "Flash off")

            shutter
                .position(x: w / 2, y: shutterCentre)

            if let onClose {
                Button {
                    HapticsEngine.lightTap()
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color(white: 0.90))
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .position(x: controlInset, y: 86)
                .accessibilityLabel("Close camera")
            }
        }
        .frame(width: w, height: h, alignment: .topLeading)
    }

    private func glyphButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticsEngine.tick()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(Color(white: 0.90))
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// A block, not a circle.
    ///
    /// Everything you make in this app is a block, and this is the button that
    /// makes one. A circle here was a camera's shutter; a rounded square is
    /// this app's shutter. The proportions are the block's own — the corner
    /// radius is 14.7% of the side, the same ratio every block on the tower
    /// uses, so it reads as the same object at a different size.
    ///
    /// Still a rim and a fill: the outline is the button's edge and the fill is
    /// the shutter itself, so pressing it compresses the fill inside a rim that
    /// stays put.
    private var shutter: some View {
        let outerRadius = shutterOuter * 0.147
        let innerRadius = shutterInner * 0.147
        return ZStack {
            RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                .strokeBorder(Color(white: 0.90), lineWidth: 1)
                .frame(width: shutterOuter, height: shutterOuter)

            RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                .fill(Color(white: 0.90))
                .frame(width: shutterInner, height: shutterInner)
                .scaleEffect(shutterScale)
        }
        .contentShape(RoundedRectangle(cornerRadius: outerRadius, style: .continuous))
        .onTapGesture { fire() }
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
    private var warmFlash: some View {
        RadialGradient(
            stops: [
                .init(color: Color(red: 1.0, green: 0.94, blue: 0.86).opacity(0.55), location: 0.0),
                .init(color: Color(red: 1.0, green: 0.91, blue: 0.78), location: 0.72),
                .init(color: Color(red: 1.0, green: 0.88, blue: 0.72), location: 1.0)
            ],
            center: .center,
            startRadius: 0,
            endRadius: 620
        )
        .opacity(flashOpacity)
        .ignoresSafeArea()
    }

    // MARK: - Firing

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
        let needsScreenFlash = camera.isFlashOn && camera.usesScreenFlash
        if needsScreenFlash {
            previousBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1.0
            withAnimation(.easeOut(duration: 0.12)) { flashOpacity = 1 }
        }

        Task { @MainActor in
            if needsScreenFlash {
                // Long enough for auto-exposure to settle on the new light.
                try? await Task.sleep(for: .milliseconds(220))
            }
            camera.capture { image in
                if needsScreenFlash {
                    UIScreen.main.brightness = previousBrightness
                    withAnimation(.easeOut(duration: 0.22)) { flashOpacity = 0 }
                }
                guard let image else { return }
                HapticsEngine.success()
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
