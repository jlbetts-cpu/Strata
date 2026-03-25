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
            self.pitch = motion.attitude.pitch
            self.roll = motion.attitude.roll
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        pitch = 0
        roll = 0
    }
}
