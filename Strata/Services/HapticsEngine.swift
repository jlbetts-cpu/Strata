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

    /// Heavy impact for tower block landing, scaled by mass tier
    static func thud(mass: Int = 1) {
        let gen: UIImpactFeedbackGenerator = switch mass {
        case 1: lightGenerator
        case 2: mediumGenerator
        default: heavyGenerator
        }
        gen.impactOccurred()
        gen.prepare()
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
