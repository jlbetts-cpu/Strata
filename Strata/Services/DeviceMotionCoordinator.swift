import CoreMotion
import SwiftUI

@Observable
final class DeviceMotionCoordinator {
    private let motionManager = CMMotionManager()
    var pitch: Double = 0
    var roll: Double = 0

    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 20 // 20Hz — smooth, battery-friendly
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion, let self else { return }
            // Low-pass filter: smooths sensor noise for clean parallax
            let alpha = 0.15
            self.pitch = self.pitch * (1 - alpha) + motion.attitude.pitch * alpha
            self.roll = self.roll * (1 - alpha) + motion.attitude.roll * alpha
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        pitch = 0
        roll = 0
    }
}
