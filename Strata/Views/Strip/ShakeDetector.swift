import CoreMotion
import SwiftUI
import UIKit

/// **A shake, from the phone** (the booth's "shake to develop"). Two sources,
/// because each catches what the other misses: the accelerometer, for a real
/// hand's shake however it is held, and UIKit's shake gesture, which is also
/// what the simulator's Device › Shake sends. Each shake is reported once,
/// however long it lasts. No permission is needed for either.
struct ShakeDetector: UIViewRepresentable {
    var onShake: () -> Void

    func makeUIView(context: Context) -> ShakeView {
        let view = ShakeView()
        view.onShake = onShake
        return view
    }

    func updateUIView(_ view: ShakeView, context: Context) {
        view.onShake = onShake
    }

    static func dismantleUIView(_ view: ShakeView, coordinator: ()) {
        view.stop()
    }

    final class ShakeView: UIView {
        var onShake: () -> Void = {}
        private let motion = CMMotionManager()
        private var last = Date.distantPast
        /// A shake is a jolt over this, in g, after gravity is taken out.
        private static let threshold = 1.35
        /// One report per shake, not one per sample.
        private static let settle: TimeInterval = 0.32

        override var canBecomeFirstResponder: Bool { true }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil {
                becomeFirstResponder()
                start()
            } else {
                stop()
            }
        }

        override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            if motion == .motionShake { report() }
        }

        private func start() {
            guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
            motion.deviceMotionUpdateInterval = 1.0 / 60
            motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
                guard let a = data?.userAcceleration else { return }
                if (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot() > Self.threshold { self?.report() }
            }
        }

        func stop() {
            if motion.isDeviceMotionActive { motion.stopDeviceMotionUpdates() }
        }

        private func report() {
            let now = Date()
            guard now.timeIntervalSince(last) > Self.settle else { return }
            last = now
            onShake()
        }
    }
}
