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
    }

    /// The header the grid is built around.
    ///
    /// The count, the flip and the flash all sit on one line, and the break in
    /// the left vertical is measured FROM that line rather than copied from the
    /// design's 48-127pt. The gap exists to hold the header, so the header is
    /// what decides where it starts and stops — that is the difference between
    /// the count sitting in the gap and the count happening to overlap it.
    private enum Header {
        /// Matches the tower's `.padding(.top, 4)` exactly, so the number does
        /// not move between the two screens.
        static let topPadding: CGFloat = 4
        static let height: CGFloat = 52
        /// Air between the header and the cut ends of the line.
        static let breathing: CGFloat = 14
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
                    h: h + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom,
                    // In the guides' own space, which starts at the top of the
                    // screen rather than below the notch.
                    gapTop: geo.safeAreaInsets.top + Header.topPadding - Header.breathing,
                    gapBottom: geo.safeAreaInsets.top + Header.topPadding + Header.height + Header.breathing
                )
                .offset(x: -geo.safeAreaInsets.leading, y: -geo.safeAreaInsets.top)
                .allowsHitTesting(false)

                controls(w: w, h: h, bottomInset: geo.safeAreaInsets.bottom)

                header()

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

    private func guides(w: CGFloat, h: CGFloat, gapTop: CGFloat, gapBottom: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // The first vertical is broken where the header crosses it. The
            // gap is not a rendering artefact — it is the header's space, and
            // the line resuming below it is what makes the break read as
            // deliberate rather than as a line that failed to draw.
            let x0 = round(Guide.verticalX[0] * w)
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
                .offset(x: round(Guide.verticalX[1] * w), y: 0)

            ForEach(Guide.horizontalY, id: \.self) { fraction in
                Rectangle()
                    .fill(Guide.colour)
                    .frame(width: w, height: Guide.width)
                    // Rounded to a whole point for the same reason the width
                    // is: a line at a fractional offset is smeared across two
                    // pixel rows and reads lighter than its neighbour.
                    .offset(x: 0, y: round(fraction * h))
            }
        }
        .frame(width: w, height: h, alignment: .topLeading)
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
    private func header() -> some View {
        HStack(alignment: .center, spacing: 0) {
            if let winCount {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("\(winCount)")
                        .font(.system(size: GridConstants.tallyNumeral, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text(winCount == 1 ? "win" : "wins")
                        .font(Typography.bodyMedium)
                        .foregroundStyle(.white.opacity(0.55))
                }
                // Legible over whatever the lens is pointing at.
                .shadow(color: .black.opacity(0.40), radius: 10, x: 0, y: 1)
                .accessibilityElement(children: .combine)
            }

            Spacer(minLength: 0)

            HStack(spacing: 2) {
                glyphButton("arrow.triangle.2.circlepath") {
                    withAnimation(GridConstants.motionSmooth) { camera.flip() }
                }
                .accessibilityLabel("Switch camera")

                glyphButton(camera.isFlashOn ? "bolt.fill" : "bolt.slash.fill") {
                    camera.isFlashOn.toggle()
                }
                .accessibilityLabel(camera.isFlashOn ? "Flash on" : "Flash off")
            }
        }
        .frame(height: Header.height)
        .padding(.horizontal, GridConstants.horizontalPadding)
        // Just the padding. This container already starts below the notch —
        // only the GUIDES work in full-screen coordinates, because they are
        // drawn over a full-bleed preview. Adding the inset here too counted
        // it twice and dropped the count clean out of the gap cut for it.
        .padding(.top, Header.topPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Controls

    private func controls(w: CGFloat, h: CGFloat, bottomInset: CGFloat) -> some View {
        // Just above the tab bar, not floating in the frame. The design has
        // nothing below the shutter; this screen has a tab bar, and measuring
        // up from the safe area keeps a deliberate gap under the button
        // instead of letting the two collide or drift apart.
        let shutterCentre = h - bottomInset - shutterOuter / 2 - 18
        return ZStack(alignment: .topLeading) {
            shutter
                .position(x: w / 2, y: shutterCentre)

            if let onClose {
                Button {
                    HapticsEngine.lightTap()
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .position(x: w / 2, y: shutterCentre + shutterOuter / 2 + 34)
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
                .foregroundStyle(.white)
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
                .strokeBorder(.white, lineWidth: 1)
                .frame(width: shutterOuter, height: shutterOuter)

            RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                .fill(.white)
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
