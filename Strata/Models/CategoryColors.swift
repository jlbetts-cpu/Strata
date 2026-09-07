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
                baseColor: Color(hex: 0x0EAD74),   // Deeper for WCAG contrast
                border: Color(hex: 0x0B9362),
                glow: Color(hex: 0x0EAD74).opacity(0.20),
                text: .white,
                lightTint: Color(hex: 0x30C494),
                darkShade: Color(hex: 0x0B9362)
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
                baseColor: Color(hex: 0xF97066),   // Coral — 153° from Health, ADHD-safe
                border: Color(hex: 0xD45E55),
                glow: Color(hex: 0xF97066).opacity(0.20),
                text: .white,
                lightTint: Color(hex: 0xFB8E86),
                darkShade: Color(hex: 0xD45E55)
            )
        case .unlabeled:
            // Warm grey, sitting in the same family as the ground rather than
            // competing with the six category colours.
            return CategoryStyle(
                baseColor: Color(hex: 0x9C9791),
                border: Color(hex: 0x857F79),
                glow: Color(hex: 0x9C9791).opacity(0.30),
                text: .white,
                lightTint: Color(hex: 0xB5B0AA),
                darkShade: Color(hex: 0x857F79)
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

// MARK: - App Colors

enum AppColors {
    static let warmBlack = Color(hex: 0x403D39)

    static let accentWarm = Color(hex: 0x403D39)
    static let accentPurple = Color(hex: 0xA689FA)

    /// The one highlight colour, on light and on dark.
    ///
    /// The tab bar is light on most screens and dark on the camera, and a
    /// highlight that has to change with it is a highlight you have to think
    /// about — it was `.primary`, which meant the selected item was a
    /// different colour on different tabs and read as two different controls.
    ///
    /// **4.5:1 on both grounds is impossible, and this is the proof.** To
    /// clear 4.5 against the app's off-white a colour needs luminance ≤ 0.168;
    /// to clear it against the viewfinder's near-black it needs ≥ 0.186. The
    /// windows do not overlap, so no colour exists that does both.
    ///
    /// The best any colour can do is sit at the geometric mean of the two
    /// grounds — L = 0.177 — which gives exactly 4.33:1 against each. That is
    /// what this is. It clears WCAG 1.4.11's 3:1 for interface components on
    /// both with room to spare, and falls a little short of the 4.5:1 body-text
    /// bar, which no colour could have met here.
    static let accentEither = Color(hex: 0xAD6135)
    static let healthGreen = Color(hex: 0x34C48B)
    static let warmRed = Color(hex: 0xE85D4A)
    /// Ghost block background for incomplete timeline habits (light mode) — 12% luminance contrast to warm background (WCAG AA)
    static let ghostBase = Color(red: 0.90, green: 0.89, blue: 0.88)
    /// Ghost block background for incomplete timeline habits (dark mode) — native iOS card color
    static let ghostBaseDark = Color(uiColor: .secondarySystemGroupedBackground)
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
