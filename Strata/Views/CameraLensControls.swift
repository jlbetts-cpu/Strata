import AVFoundation
import SwiftUI

/// **The camera's hands, in one place** (the owner, 2026-10-18: "The inline
/// camera lost the old camera's features. Bring back everything: double tap
/// to flip, pinch to zoom, the zoom pill ..."). The old full-screen camera's
/// viewfinder gestures and lens pill, lifted out of `CameraView` so the
/// camera card has the same ones (`docs/camera-parity-2026-10-18.md`).

/// Pinch to zoom, tap to focus, drag to expose, double tap to flip: one
/// transparent layer carrying all four, so the guards between them can see
/// each other (a pinch is also a drag, so without `zoomAtPinchStart` in the
/// drag's guard the exposure would swing every time you zoomed). The double
/// tap is `exclusively(before:)` the single, the native camera's own trade.
struct LensGestureLayer: View {
    let camera: CameraService
    let box: PreviewLayerBox
    /// The lens row is written out: a touch on the picture folds it.
    @Binding var lensesOpen: Bool
    /// A pinch or the focus square is up: the card's swipe down waits, so an
    /// exposure drag never closes it.
    @Binding var busy: Bool

    @State private var focusPoint: CGPoint?
    @State private var focusShownAt = Date.distantPast
    @State private var zoomAtPinchStart: CGFloat?
    @State private var biasAtDragStart: Float?

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture(count: 2)
                    .onEnded { _ in
                        HapticsEngine.snap()
                        withAnimation(GridConstants.motionSnappy) { camera.flip() }
                        focusPoint = nil
                    }
                    .exclusively(before:
                        SpatialTapGesture(count: 1).onEnded { value in focus(at: value.location) }
                    )
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        let start = zoomAtPinchStart ?? camera.zoom
                        if zoomAtPinchStart == nil {
                            zoomAtPinchStart = start
                            if lensesOpen { withAnimation(GridConstants.motionSnappy) { lensesOpen = false } }
                        }
                        camera.setZoom(start * value.magnification)
                    }
                    .onEnded { _ in zoomAtPinchStart = nil }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        // Only while the square is up, never during a pinch.
                        // Up is brighter, 120pt to a stop (`CameraView`).
                        guard focusPoint != nil, zoomAtPinchStart == nil else { return }
                        let start = biasAtDragStart ?? camera.exposureBias
                        if biasAtDragStart == nil { biasAtDragStart = start }
                        camera.setExposureBias(start + Float(-value.translation.height / 120))
                        focusShownAt = Date()
                    }
                    .onEnded { _ in biasAtDragStart = nil }
            )
            .overlay(alignment: .topLeading) {
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
            // The camera went back to focusing by itself: the square goes.
            .onChange(of: camera.focusReleases) { _, _ in
                withAnimation(GridConstants.motionSnappy) { focusPoint = nil }
            }
            .onChange(of: focusPoint != nil || zoomAtPinchStart != nil) { _, now in busy = now }
            .accessibilityHidden(true)
    }

    private func focus(at location: CGPoint) {
        if lensesOpen { withAnimation(GridConstants.motionSnappy) { lensesOpen = false } }
        guard let layer = box.layer else { return }
        camera.focus(at: layer.captureDevicePointConverted(fromLayerPoint: location))
        HapticsEngine.tick()
        withAnimation(GridConstants.motionSnappy) { focusPoint = location }
        focusShownAt = Date()
    }
}

/// **The lens, said and changed**: one small pill reading where the lens is
/// ("1x", "1.4x"); a tap writes out the lenses (.5, 1, 2, 3) and a tap on
/// one glides there and folds the row, as do a pinch, a touch on the picture
/// or three seconds of nothing. With two lenses a tap goes to the other; with
/// one, the readout shows after a pinch and a tap goes back to 1x.
struct LensPill: View {
    let camera: CameraService
    @Binding var open: Bool
    @State private var touched = Date()

    private static let side: CGFloat = 44

    var body: some View {
        let lenses = CameraLenses.offer(from: camera)
        Group {
            if camera.canZoom || Self.debugLenses, lenses.hasChoice {
                if open, lenses.stops.count > 2 {
                    row(lenses)
                        .task(id: touched) {
                            try? await Task.sleep(for: .seconds(3))
                            guard !Task.isCancelled else { return }
                            withAnimation(GridConstants.motionSnappy) { open = false }
                        }
                } else {
                    let label = CameraLenses.label(forDeviceFactor: camera.zoom, base: lenses.base)
                    let chosen = CameraLenses.chosen(for: camera.zoom, in: lenses.stops)
                    let other = lenses.stops.first { $0 != chosen } ?? chosen
                    lensButton(label, chosen: true, name: "Lens, \(label)",
                               hint: lenses.stops.count > 2
                                   ? "Shows the lenses"
                                   : "Switches to \(CameraLenses.label(forDeviceFactor: other, base: lenses.base))") {
                        if lenses.stops.count > 2 {
                            touched = Date()
                            withAnimation(GridConstants.motionSnappy) { open = true }
                        } else {
                            camera.glide(to: other)
                        }
                    }
                    .frame(height: 34)
                    .lensGlass()
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
            } else if camera.canZoom, camera.zoom > 1.005 {
                let label = CameraLenses.label(forDeviceFactor: camera.zoom, base: lenses.base)
                lensButton(label, chosen: true, name: "Lens, \(label)", hint: "Returns to 1x") {
                    withAnimation(GridConstants.motionSnappy) { camera.setZoom(1) }
                }
                .frame(height: 34)
                .lensGlass()
                .transition(.scale(scale: 0.7).combined(with: .opacity))
            }
        }
        .environment(\.colorScheme, .dark)
    }

    private func row(_ lenses: CameraLenses.Offer) -> some View {
        let chosen = CameraLenses.chosen(for: camera.zoom, in: lenses.stops)
        return HStack(spacing: 0) {
            ForEach(lenses.stops, id: \.self) { stop in
                let isChosen = stop == chosen
                let name = CameraLenses.label(forDeviceFactor: stop, base: lenses.base)
                lensButton(isChosen
                           ? CameraLenses.label(forDeviceFactor: camera.zoom, base: lenses.base)
                           : CameraLenses.shortLabel(forDeviceFactor: stop, base: lenses.base),
                           chosen: isChosen, name: "Lens \(name)", hint: nil) {
                    camera.glide(to: stop)
                    withAnimation(GridConstants.motionSnappy) { open = false }
                }
            }
        }
        .frame(height: 34)
        .lensGlass()
        .transition(.scale(scale: 0.7).combined(with: .opacity))
    }

    private func lensButton(_ label: String, chosen: Bool, name: String, hint: String?,
                            action: @escaping () -> Void) -> some View {
        Button {
            HapticsEngine.lightTap()
            action()
        } label: {
            Text(label)
                .font(Typography.headerSmall)
                .monospacedDigit()
                .foregroundStyle(.white.opacity(chosen ? 1 : 0.6))
                .frame(width: chosen ? 56 : Self.side, height: Self.side)
                .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .accessibilityLabel(name)
        .accessibilityHint(hint ?? "")
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }

    private static var debugLenses: Bool {
        #if DEBUG
        DebugHarness.fakeLenses != nil
        #else
        false
        #endif
    }
}

extension View {
    /// **The camera card's darker glass** (`InlineCameraCard`'s `inlineGlass`,
    /// deep): white type on light frosted glass vanished over a bright scene
    /// (seen 2026-10-18, the lens row over a white wall).
    @ViewBuilder
    func lensGlass() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(.black.opacity(0.36)), in: Capsule())
        } else {
            self.background(.ultraThinMaterial, in: Capsule()).environment(\.colorScheme, .dark)
        }
    }
}
