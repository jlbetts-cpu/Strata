import SwiftUI

struct CategoryStyle {
    /// The single solid category color
    let baseColor: Color
    let border: Color
    let glow: Color
    let text: Color

    /// Lighter tint for gradient top (simulates light hitting the surface)
    let lightTint: Color
    /// Darker shade for gradient bottom (simulates ambient occlusion)
    let darkShade: Color

    // Legacy accessors
    var gradientTop: Color { lightTint }
    var gradientBottom: Color { darkShade }

    /// Flat fill (was previously a 3-color gradient for clay effect)
    var gradient: LinearGradient {
        LinearGradient(
            colors: [baseColor],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Flat fill using base color (for contexts where gradient isn't appropriate)
    var flatFill: Color { baseColor }
}

extension HabitCategory {
    var style: CategoryStyle {
        switch self {
        case .health:
            return CategoryStyle(
                baseColor: Color(hex: 0x10B77F),
                border: Color(hex: 0x0D9A6B),
                glow: Color(hex: 0x10B77F).opacity(0.30),
                text: .white,
                lightTint: Color(hex: 0x3CCFA0),
                darkShade: Color(hex: 0x0D9A6B)
            )
        case .work:
            return CategoryStyle(
                baseColor: Color(hex: 0x40A9FF),
                border: Color(hex: 0x2E8BE6),
                glow: Color(hex: 0x40A9FF).opacity(0.30),
                text: .white,
                lightTint: Color(hex: 0x6DC0FF),
                darkShade: Color(hex: 0x2E8BE6)
            )
        case .creativity:
            return CategoryStyle(
                baseColor: Color(hex: 0xAF9CFA),
                border: Color(hex: 0x826DD0),
                glow: Color(hex: 0xAF9CFA).opacity(0.30),
                text: .white,
                lightTint: Color(hex: 0xC4B5FF),
                darkShade: Color(hex: 0x826DD0)
            )
        case .focus:
            return CategoryStyle(
                baseColor: Color(hex: 0xFDB54F),
                border: Color(hex: 0xD99A3A),
                glow: Color(hex: 0xFDB54F).opacity(0.30),
                text: .white,
                lightTint: Color(hex: 0xFEC873),
                darkShade: Color(hex: 0xD99A3A)
            )
        case .social:
            return CategoryStyle(
                baseColor: Color(hex: 0x14D4C1),
                border: Color(hex: 0x10B3A3),
                glow: Color(hex: 0x14D4C1).opacity(0.30),
                text: .white,
                lightTint: Color(hex: 0x42E0D2),
                darkShade: Color(hex: 0x10B3A3)
            )
        case .mindfulness:
            return CategoryStyle(
                baseColor: Color(hex: 0xEC85B4),
                border: Color(hex: 0xC86B98),
                glow: Color(hex: 0xEC85B4).opacity(0.30),
                text: .white,
                lightTint: Color(hex: 0xF2A0C8),
                darkShade: Color(hex: 0xC86B98)
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
