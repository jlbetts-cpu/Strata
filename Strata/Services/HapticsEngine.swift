import UIKit

enum HapticsEngine {
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)

    /// Prime all generators for lower-latency feedback
    static func prepare() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
        rigidGenerator.prepare()
    }

    /// Light selection tap — scrubber dragging
    static func tick() {
        selectionGenerator.selectionChanged()
    }

    /// Light tap for subtle confirmations (photo save, filter change, gear tap)
    static func lightTap() {
        lightGenerator.impactOccurred(intensity: 0.5)
        lightGenerator.prepare()
    }

    /// Notification success — milestone moments ("All done!", achievements)
    static func success() {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
    }

    /// Decrescendo reward pattern — level-up celebrations
    static func reward() {
        heavyGenerator.impactOccurred(intensity: 1.0)
        heavyGenerator.prepare()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            mediumGenerator.impactOccurred(intensity: 0.6)
            mediumGenerator.prepare()
            try? await Task.sleep(for: .milliseconds(200))
            lightGenerator.impactOccurred(intensity: 0.3)
            lightGenerator.prepare()
        }
    }

    /// Rigid impact for polished resin drop landings, scaled by mass via intensity
    static func squish(mass: Int = 1) {
        let intensity: CGFloat = switch mass {
        case 1: 0.45
        case 2: 0.60
        default: 0.75
        }
        rigidGenerator.impactOccurred(intensity: intensity)
        rigidGenerator.prepare()
    }

    /// Rigid impact for drawer toggle and swipe-to-complete
    static func snap() {
        rigidGenerator.impactOccurred(intensity: 0.8)
        rigidGenerator.prepare()
    }

    /// Increasing intensity cascade sequence
    static func cascade(index: Int) {
        let intensity = min(1.0, 0.4 + Double(index) * 0.15)
        heavyGenerator.impactOccurred(intensity: intensity)
        heavyGenerator.prepare()
    }
}
