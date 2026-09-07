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
    /// True when nothing else is on screen — presented as its own sheet rather
    /// than as a tab with a bar beneath it.
    var fillsScreen: Bool = false

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
        /// Matches the tower's `.padding(.top, 4)` exactly, so the number does
        /// not move between the two screens.
        static let topPadding: CGFloat = 4
        static let height: CGFloat = 72
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
            // Presented on its own there is no tab bar to leave room for, so
            // it takes the whole screen. In the tab it stops just above the
            // bar, which is what keeps the app's light ground under the bar
            // rather than a black viewfinder.
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

                guides(w: w, h: h, topInset: topInset)
                    .allowsHitTesting(false)

                header(topInset: topInset)

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
        .onDisappear {
            camera.stop()
            UIScreen.main.brightness = previousBrightness
        }
    }

    // MARK: - Guides

    private func guides(w: CGFloat, h: CGFloat, topInset: CGFloat) -> some View {
        // The break exists to hold the count. With no count — the camera
        // opened from the add sheet, where the tally would mean nothing —
        // there is nothing to make room for, so the line runs unbroken.
        let gapTop = winCount == nil ? h : topInset + Header.topPadding - Header.breathing
        let gapBottom = winCount == nil ? h : topInset + Header.topPadding + Header.height + Header.breathing

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
            if let winCount {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("\(winCount)")
                        .font(.system(size: GridConstants.tallyNumeral, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text(winCount == 1 ? "win" : "wins")
                        .font(.system(size: GridConstants.tallyWord, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
                // Legible over whatever the lens is pointing at.
                .shadow(color: .black.opacity(0.40), radius: 10, x: 0, y: 1)
                .accessibilityElement(children: .combine)
            }

            Spacer(minLength: 0)
        }
        .frame(height: Header.height)
        .padding(.horizontal, GridConstants.horizontalPadding)
        // The preview starts at the very top of the screen now, so the header
        // has to clear the notch itself.
        .padding(.top, topInset + Header.topPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Controls

    private func controls(w: CGFloat, h: CGFloat, topInset: CGFloat, bottomInset: CGFloat) -> some View {
        let shutterCentre = h - bottomInset - shutterOuter / 2 - shutterBottomGap
        // Where a thumb already is. The two settings you actually change while
        // shooting were in the top right corner, which on a phone this size is
        // a two-handed reach — so in practice you either put the phone down or
        // you never touch them. Beside the shutter they sit inside the arc the
        // thumb already sweeps to reach the button it is going for anyway.
        let flankOffset = shutterOuter / 2 + 34
        return ZStack(alignment: .topLeading) {
            glyphButton(camera.isFlashOn ? "bolt.fill" : "bolt.slash.fill") {
                camera.isFlashOn.toggle()
            }
            .position(x: w / 2 - flankOffset, y: shutterCentre)
            .accessibilityLabel(camera.isFlashOn ? "Flash on" : "Flash off")

            shutter
                .position(x: w / 2, y: shutterCentre)

            glyphButton("arrow.triangle.2.circlepath") {
                withAnimation(GridConstants.motionSmooth) { camera.flip() }
            }
            .position(x: w / 2 + flankOffset, y: shutterCentre)
            .accessibilityLabel("Switch camera")

            if let onClose {
                // Below the status bar, not under it.
                //
                // This sat at y=34 in a space whose origin is the top of the
                // SCREEN, so it landed inside the status bar and beside the
                // Dynamic Island — drawn, but with the system's own touch
                // areas over most of it, which is why it could not be pressed.
                // Measuring down from the safe inset puts it in the app's
                // space, where the whole 44pt target belongs to it.
                //
                // 44pt is the HIG minimum for a touch target and the button is
                // exactly that, with the glyph smaller inside it — the tappable
                // area is bigger than the mark, which is the point.
                Button {
                    HapticsEngine.lightTap()
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.black.opacity(0.28)))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .position(
                    x: w - GridConstants.horizontalPadding - 22,
                    y: topInset + 22 + Header.topPadding
                )
                .accessibilityLabel("Close camera")
            }
        }
        .frame(width: w, height: h, alignment: .topLeading)
    }

    /// No box.
    ///
    /// They were small blocks for a while, to rhyme with the shutter. Three
    /// bordered objects in a row turned the quietest part of the screen into
    /// the busiest, and a setting does not need a container to be a setting —
    /// the glyph is the control. The shutter keeps its rim because it is the
    /// one thing here that is a button rather than a toggle.
    private func glyphButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticsEngine.tick()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 21, weight: .regular))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 1)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
