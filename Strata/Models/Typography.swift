import SwiftUI

enum Typography {
    static let appTitle = Font.system(.largeTitle, design: .rounded, weight: .medium)
    static let headerLarge = Font.system(.title3, design: .rounded, weight: .medium)
    static let headerMedium = Font.system(.headline, design: .rounded, weight: .medium)
    static let headerSmall = Font.system(.subheadline, design: .rounded, weight: .medium)
    static let bodyLarge = Font.system(.body, design: .rounded)
    static let bodyMedium = Font.system(.callout, design: .rounded)
    static let bodySmall = Font.system(.footnote, design: .rounded)
    static let caption = Font.system(.caption, design: .rounded)
    static let caption2 = Font.system(.caption2, design: .rounded, weight: .medium)
    static let blockTitle = Font.system(.callout, design: .rounded, weight: .medium)
    // Mini block preview (fixed size — too small for text styles)
    static let miniBlockTitle = Font.system(size: 9, weight: .medium, design: .rounded)
    static let miniBlockIcon = Font.system(size: 8, weight: .medium, design: .rounded)
    // Kerning (SF Rounded has built-in optical kerning — no manual adjustment needed)
    static let headerKerning: CGFloat = 0
    static let titleKerning: CGFloat = 0
}
