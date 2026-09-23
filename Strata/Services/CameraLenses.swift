import AVFoundation
import UIKit

/// **Where this phone's pieces of glass are, as numbers.**
///
/// The owner, 2026-09-23: "what is the RAW and lens picker, don't we need
/// those for the camera as well?" Without a lens control the camera is stuck
/// at one field of view, which reads as broken on a phone that has three
/// cameras in it.
///
/// **It works in DEVICE factors, not in the numbers on screen, and that is
/// deliberate.** `AVCaptureDevice.videoZoomFactor` is measured from a virtual
/// device's WIDEST lens, so on anything with an ultra-wide, factor 1.0 is the
/// 0.5x view and the familiar 1x lives at the first switchover point.
/// `CameraService.zoom` and `CameraService.setZoom` both speak device factors,
/// so this does too: one language, one place it is translated, which is
/// `label(forDeviceFactor:base:)` at the moment it is drawn. Converting in two
/// places is how a control ends up saying 1x while showing something else.
///
/// **What this cannot do, and why the control may be inert.** The session's
/// input is chosen in `CameraService.configure()`, which asks for
/// `.builtInWideAngleCamera`: the 1x lens and only the 1x lens. A virtual
/// device (`.builtInTripleCamera`, `.builtInDualWideCamera`,
/// `.builtInDualCamera`) is what presents the whole stack as one input and
/// hands over between the physical lenses itself as the zoom factor crosses
/// `virtualDeviceSwitchOverVideoZoomFactors`, which is what makes the
/// handover seamless, because the session never reconfigures and the preview
/// never blinks. Until `configure()` asks for one, a phone reports no
/// switchovers, `stops` comes back with a single entry, and the control hides
/// itself rather than drawing buttons that do nothing. Nothing here needs to
/// change when that day comes.
nonisolated enum CameraLenses {

    /// The device the session is currently reading, or nil where there is no
    /// camera at all, which is every simulator.
    @MainActor
    static func device(in session: AVCaptureSession) -> AVCaptureDevice? {
        session.inputs.lazy.compactMap { ($0 as? AVCaptureDeviceInput)?.device }.first
    }

    /// **The device factor that people call 1x.**
    ///
    /// On the back camera it is the first switchover point when the widest
    /// constituent lens is the ultra-wide, and 1 otherwise. The front camera's
    /// is its portrait crop, for the same reason: its 1x is a crop on Apple's
    /// own phones too, and pinching out from it reaches the full field. See
    /// `CameraService.frontPortraitCrop`.
    ///
    /// On the main actor because an `AVCaptureDevice` is a reference to shared
    /// hardware state and `frontPortraitCrop` lives on a main-actor class, not
    /// because there is anything slow in it.
    @MainActor
    static func base(for device: AVCaptureDevice) -> CGFloat {
        if device.position == .front {
            return min(CameraService.frontPortraitCrop, device.activeFormat.videoMaxZoomFactor)
        }
        guard device.constituentDevices.first?.deviceType == .builtInUltraWideCamera,
              let first = device.virtualDeviceSwitchOverVideoZoomFactors.first else { return 1 }
        return CGFloat(truncating: first)
    }

    /// The device factors a lens control should offer: the widest field, every
    /// switchover point, and 1x itself, in order and inside what the device
    /// accepts.
    ///
    /// **Pure**, so the mapping can be checked on a machine with no camera,
    /// which is the only place any of this can be checked at all.
    static func stops(base: CGFloat, switchovers: [CGFloat], maxFactor: CGFloat) -> [CGFloat] {
        guard base > 0 else { return [1] }
        // 1 is the widest the glass goes; `base` is the familiar 1x.
        var stops: [CGFloat] = [1, base]
        stops.append(contentsOf: switchovers)
        return stops
            .filter { $0 >= 1 - 0.001 && $0 <= maxFactor + 0.001 }
            .sorted()
            .reduce(into: [CGFloat]()) { kept, stop in
                // Two stops a hair apart are one stop: on a phone with no
                // ultra-wide the base IS 1, and a control offering "1x" twice
                // is a control that does nothing every other tap.
                if kept.last.map({ stop - $0 > 0.01 }) ?? true { kept.append(stop) }
            }
    }

    /// The stop a tap should go to: the next one up, and back to the widest
    /// from the top. From somewhere between two stops it goes to the one
    /// ABOVE, so a pinch followed by a tap tidies up rather than jumping
    /// backwards.
    static func stop(after factor: CGFloat, in stops: [CGFloat]) -> CGFloat {
        guard let first = stops.first, let last = stops.last else { return 1 }
        if let above = stops.first(where: { $0 > factor + 0.01 }) { return above }
        return factor > last - 0.01 ? first : last
    }

    /// What a device factor is called on screen. `1x`, `2.4x`: one decimal,
    /// and none when it is a round number, which is what iOS Camera does.
    static func label(forDeviceFactor factor: CGFloat, base: CGFloat) -> String {
        let shown = factor / max(base, 0.0001)
        let rounded = (shown * 10).rounded() / 10
        return rounded == rounded.rounded()
            ? String(format: "%.0fx", rounded)
            : String(format: "%.1fx", rounded)
    }
}

extension CameraLenses {
    /// What the camera in front of us can offer, read once per draw.
    ///
    /// **Every path is safe with no camera and with one lens.** No device at
    /// all (the simulator) gives one stop at 1 and a base of 1, so the
    /// control hides and the rest of the screen is untouched. One lens gives
    /// the same, which is what every phone reports today.
    struct Offer: Equatable {
        var base: CGFloat = 1
        var stops: [CGFloat] = [1]
        /// True only when there is genuinely more than one framing to choose
        /// between. A picker with one button is not a choice.
        var hasChoice: Bool { stops.count > 1 }
    }

    @MainActor
    static func offer(from service: CameraService) -> Offer {
        guard let device = device(in: service.session) else { return Offer() }
        let base = base(for: device)
        return Offer(base: base,
                     stops: stops(base: base,
                                  switchovers: device.virtualDeviceSwitchOverVideoZoomFactors.map {
                                      CGFloat(truncating: $0)
                                  },
                                  maxFactor: service.maxZoom))
    }
}
