import UIKit

enum HapticsEngine {

    /// The Settings toggle, honoured.
    ///
    /// It was an `@AppStorage` nobody read: the switch moved, the key was
    /// written, and every generator fired anyway. A control that reports a
    /// state it does not have is worse than no control, and this one is also
    /// an accessibility setting — some people turn haptics off because they
    /// need them off.
    private static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
    }

    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    /// Prime all generators for lower-latency feedback
    static func prepare() {
        selectionGenerator.prepare()
        lightGenerator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
        rigidGenerator.prepare()
        notificationGenerator.prepare()
    }

    /// Light selection tap — scrubber dragging
    static func tick() {
        guard isEnabled else { return }
        selectionGenerator.selectionChanged()
    }

    /// Light tap for subtle confirmations (photo save, filter change, gear tap)
    static func lightTap() {
        guard isEnabled else { return }
        lightGenerator.impactOccurred(intensity: 0.5)
        lightGenerator.prepare()
    }

    /// Notification success — milestone moments ("All done!", achievements)
    static func success() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }

    /// Decrescendo reward pattern — level-up celebrations
    static func reward() {
        guard isEnabled else { return }
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
        guard isEnabled else { return }
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
        guard isEnabled else { return }
        rigidGenerator.impactOccurred(intensity: 0.8)
        rigidGenerator.prepare()
    }

    /// Warning feedback — drag below threshold, failed action
    static func warning() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.warning)
        notificationGenerator.prepare()
    }

    /// Error feedback — operation failed (photo save, network)
    static func error() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.error)
        notificationGenerator.prepare()
    }

    /// Increasing intensity cascade sequence
    static func cascade(index: Int) {
        guard isEnabled else { return }
        let intensity = min(1.0, 0.4 + Double(index) * 0.15)
        heavyGenerator.impactOccurred(intensity: intensity)
        heavyGenerator.prepare()
    }
}
