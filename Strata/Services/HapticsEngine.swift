import UIKit

enum HapticsEngine {
    private static let selectionGenerator = UISelectionFeedbackGenerator()

    /// Light selection tap — scrubber dragging
    static func tick() {
        selectionGenerator.selectionChanged()
    }

    /// Heavy impact for tower block landing, scaled by mass tier
    static func thud(mass: Int = 1) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle = switch mass {
        case 1: .light
        case 2: .medium
        default: .heavy
        }
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.impactOccurred()
    }

    /// Rigid impact for drawer toggle and swipe-to-complete
    static func snap() {
        let gen = UIImpactFeedbackGenerator(style: .rigid)
        gen.impactOccurred(intensity: 0.8)
    }

    /// Increasing intensity cascade sequence
    static func cascade(index: Int) {
        let intensity = min(1.0, 0.4 + Double(index) * 0.15)
        let gen = UIImpactFeedbackGenerator(style: .heavy)
        gen.impactOccurred(intensity: intensity)
    }
}
