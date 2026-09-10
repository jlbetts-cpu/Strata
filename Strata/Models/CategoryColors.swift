import SwiftUI
import UIKit

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

    // MARK: - Ink
    //
    // **`.primary.opacity(x)` is not a colour, it is a colour in light mode.**
    //
    // A quiet grey was tuned against a white page: 0.45 for a heading, 0.40
    // for a caption. Flip the ground and the SAME number is 45% white on
    // near-black, which measures 4.4:1 — under WCAG AA for body text — and
    // reads exactly as the owner described it, "a bit of contrast issues in
    // places". Grey on white and grey on black are not the same problem: dark
    // grounds need MORE of the ink, not the same amount inverted.
    //
    // Dynamic colours, so a call site cannot get it wrong by being written on
    // the wrong day. Measured after: heading 7.1:1, caption 5.6:1.

    // The values are DERIVED from the contrast target, not chosen by eye.
    // Against the page's ground the measured ratios are:
    //
    //              light   dark    WCAG AA needs
    //   secondary   6.0     8.4    4.5:1  (text)
    //   tertiary    4.8     6.6    4.5:1  (text)
    //   quiet       3.1     4.3    3.0:1  (UI element, not text)
    //
    // The old light values failed: headings measured 3.34:1 and captions
    // 2.8:1 against a 246 ground. That is not a dark-mode regression, it was
    // always there — flipping the ground is just what made it obvious.

    /// The empty slot's ink: its outline, its recess and its `+`.
    ///
    /// **This was `warmBlack` and the slot disappeared in dark mode.** The
    /// owner: "the block is still not visible in dark mode, like how am i
    /// supposed to know where to hold to drag". It is the app's primary
    /// action — the one place you press to log a win — drawn in near-black on
    /// a near-black ground.
    ///
    /// A warm white rather than pure, so the socket still belongs to a page
    /// whose black has brown in it.
    static let slotInk = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.98, green: 0.97, blue: 0.96, alpha: 1)
            : UIColor(red: 0.251, green: 0.239, blue: 0.224, alpha: 1)
    })

    /// Headings, labels, and anything that names a run of content.
    static let inkSecondary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.70)
            : UIColor(white: 0, alpha: 0.62)
    })

    /// Captions: a count under a card, a subtitle, a unit.
    static let inkTertiary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.60)
            : UIColor(white: 0, alpha: 0.55)
    })

    /// The quietest ink the app uses: a chevron, a placeholder, a hint.
    ///
    /// **Held to 3:1, not 4.5:1**, and deliberately: these are UI elements and
    /// decorative glyphs rather than text somebody has to read, which is the
    /// line the guideline itself draws. Pushed to text contrast they stop
    /// being quiet, and the quiet is the point.
    static let inkQuiet = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.55)
            : UIColor(white: 0, alpha: 0.45)
    })

    static let accentWarm = Color(hex: 0x403D39)
    static let accentPurple = Color(hex: 0xA689FA)

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
