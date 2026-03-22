import SwiftUI

enum Typography {
    // App title (34pt, -2% tracking)
    static let appTitle = Font.custom("FamiljenGrotesk-Medium", size: 34, relativeTo: .largeTitle)
    // Headers (Medium weight, -2% tracking)
    static let headerLarge = Font.custom("FamiljenGrotesk-Medium", size: 20, relativeTo: .title3)
    static let headerMedium = Font.custom("FamiljenGrotesk-Medium", size: 17, relativeTo: .headline)
    static let headerSmall = Font.custom("FamiljenGrotesk-Medium", size: 15, relativeTo: .subheadline)
    // Body (Regular weight, 0% tracking)
    static let bodyLarge = Font.custom("FamiljenGrotesk-Regular", size: 16, relativeTo: .body)
    static let bodyMedium = Font.custom("FamiljenGrotesk-Regular", size: 14, relativeTo: .callout)
    static let bodySmall = Font.custom("FamiljenGrotesk-Regular", size: 12, relativeTo: .footnote)
    static let caption = Font.custom("FamiljenGrotesk-Regular", size: 11, relativeTo: .caption)
    static let caption2 = Font.custom("FamiljenGrotesk-Medium", size: 10, relativeTo: .caption2)
    static let blockTitle = Font.custom("FamiljenGrotesk-Medium", size: 16, relativeTo: .body)
    // Mini block preview (used in MiniBlockPreview.swift)
    static let miniBlockTitle = Font.custom("FamiljenGrotesk-Medium", size: 9, relativeTo: .caption2)
    static let miniBlockIcon = Font.custom("FamiljenGrotesk-Medium", size: 8, relativeTo: .caption2)
    static let headerKerning: CGFloat = -0.3  // -2% at ~15pt
    static let titleKerning: CGFloat = -0.68  // -2% at 34pt
}
