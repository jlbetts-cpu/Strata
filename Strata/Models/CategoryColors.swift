import SwiftUI

struct CategoryStyle {
    /// The single solid category color
    let baseColor: Color
    let border: Color
    let glow: Color
    let text: Color

    // Legacy accessors — kept so existing code compiles without changes
    var gradientTop: Color { baseColor }
    var gradientBottom: Color { baseColor }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [baseColor, baseColor],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

extension HabitCategory {
    var style: CategoryStyle {
        switch self {
        case .health:
            return CategoryStyle(
                baseColor: Color(hex: 0x10B77F),
                border: Color(hex: 0x0A8F63),
                glow: Color(hex: 0x10B77F).opacity(0.35),
                text: .white
            )
        case .work:
            return CategoryStyle(
                baseColor: Color(hex: 0x3C83F6),
                border: Color(hex: 0x2A66D0),
                glow: Color(hex: 0x3C83F6).opacity(0.35),
                text: .white
            )
        case .creativity:
            return CategoryStyle(
                baseColor: Color(hex: 0xA589FB),
                border: Color(hex: 0x8669DA),
                glow: Color(hex: 0xA589FB).opacity(0.35),
                text: .white
            )
        case .focus:
            return CategoryStyle(
                baseColor: Color(hex: 0xF59F0A),
                border: Color(hex: 0xD07F00),
                glow: Color(hex: 0xF59F0A).opacity(0.35),
                text: .white
            )
        case .social:
            return CategoryStyle(
                baseColor: Color(hex: 0x00CCB8),
                border: Color(hex: 0x00A898),
                glow: Color(hex: 0x00CCB8).opacity(0.35),
                text: .white
            )
        case .mindfulness:
            return CategoryStyle(
                baseColor: Color(hex: 0xF570AC),
                border: Color(hex: 0xD45195),
                glow: Color(hex: 0xF570AC).opacity(0.35),
                text: .white
            )
        }
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}
