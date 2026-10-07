import CoreMotion
import SwiftUI

/// **The phone's tilt, for a card held in it** (the owner, 2026-10-07: the
/// strip should move and look like "Pokemon TCG level card movement ... how
/// it genuinely looks like a card"). How far the phone has turned from the
/// way it was held when the booth opened, in degrees, a few at most and
/// eased, so the strip leans and its gloss slides as a card in the hand does
/// even before a finger touches it.
///
/// Measured from the opening attitude, not from flat: however you hold the
/// phone is the strip's rest. No permission is needed for device motion.
@MainActor
@Observable
final class CardTilt {
    /// Around the card's upright axis (the phone rolled left or right) and
    /// its across axis (tipped toward or away), in degrees.
    private(set) var yaw: Double = 0
    private(set) var pitch: Double = 0

    /// The most the phone's own motion leans the card.
    static let reach = 7.0

    @ObservationIgnored private let motion = CMMotionManager()
    @ObservationIgnored private var reference: CMAttitude?
    /// A shake of the phone, from the same feed as the tilt: one reader of
    /// the motion sensors, not two competing (the booth's `ShakeDetector`
    /// keeps only UIKit's shake gesture, which is also the simulator's).
    @ObservationIgnored var onShake: () -> Void = {}
    /// False under Reduce Motion: the shake is still heard, the card does not
    /// lean with the phone.
    @ObservationIgnored var leans = true
    @ObservationIgnored private var lastShake = Date.distantPast
    /// A jolt over this, in g, after gravity is taken out. Gentler than the
    /// first 1.35: a person shaking a photo does not snap their wrist.
    static let shakeAt = 1.05

    func start() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 60
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data, let attitude = data.attitude.copy() as? CMAttitude else { return }
            let a = data.userAcceleration
            if (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot() > Self.shakeAt,
               Date().timeIntervalSince(self.lastShake) > 0.32 {
                self.lastShake = Date()
                self.onShake()
            }
            guard self.leans else { return }
            guard let reference = self.reference else { self.reference = attitude; return }
            attitude.multiply(byInverseOf: reference)
            let deg = 180 / Double.pi
            let toYaw = max(-Self.reach, min(Self.reach, attitude.roll * deg * 0.35))
            let toPitch = max(-Self.reach, min(Self.reach, -attitude.pitch * deg * 0.35))
            // Eased toward, so a hand's tremor reads as weight, not jitter.
            self.yaw += (toYaw - self.yaw) * 0.12
            self.pitch += (toPitch - self.pitch) * 0.12
        }
    }

    func stop() {
        if motion.isDeviceMotionActive { motion.stopDeviceMotionUpdates() }
        reference = nil
        yaw = 0
        pitch = 0
    }
}
