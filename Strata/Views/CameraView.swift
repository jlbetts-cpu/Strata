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

    @State private var camera = CameraService()
    @State private var flashOpacity: Double = 0
    @State private var shutterScale: CGFloat = 1
    @State private var previousBrightness: CGFloat = UIScreen.main.brightness
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Geometry, from the Figma frame (402 x 874)

    /// Rule-of-quarters guides. Two verticals and two horizontals, which is
    /// what the design specifies — not a full nine-cell thirds grid.
    private enum Guide {
        static let verticalX: [CGFloat] = [0.2516, 0.7394]
        static let horizontalY: [CGFloat] = [0.2580, 0.5000]
        /// The break in the first vertical, left open for the logo.
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

                guides(w: w, h: h)
                    .allowsHitTesting(false)

                controls(w: w, h: h, bottomInset: geo.safeAreaInsets.bottom)

                warmFlash
                    .allowsHitTesting(false)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .statusBarHidden(false)
        .preferredColorScheme(.dark)
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

    // MARK: - Controls

    private func controls(w: CGFloat, h: CGFloat, bottomInset: CGFloat) -> some View {
        // The design has nothing below the shutter; this screen has a tab bar.
        // Measuring up from the safe area keeps the same visual gap under the
        // button that the design has, instead of letting the tab bar sit on it.
        let shutterCentre = h - bottomInset - shutterOuter / 2 - 34
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

    /// A ring and a disc, as in the design: the outline is the button's edge
    /// and the fill is the shutter itself, so pressing it can compress the
    /// fill inside a rim that stays put.
    private var shutter: some View {
        ZStack {
            Circle()
                .strokeBorder(Color(white: 0.90), lineWidth: 1)
                .frame(width: shutterOuter, height: shutterOuter)

            Circle()
                .fill(Color(white: 0.90))
                .frame(width: shutterInner, height: shutterInner)
                .scaleEffect(shutterScale)
        }
        .contentShape(Circle())
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
