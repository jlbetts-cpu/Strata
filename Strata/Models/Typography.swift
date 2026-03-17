import SwiftUI

enum Typography {
    // App title (34pt, -2% tracking)
    static let appTitle = Font.custom("FamiljenGrotesk-Medium", size: 34)
    // Headers (Medium weight, -2% tracking)
    static let headerLarge = Font.custom("FamiljenGrotesk-Medium", size: 20)
    static let headerMedium = Font.custom("FamiljenGrotesk-Medium", size: 17)
    static let headerSmall = Font.custom("FamiljenGrotesk-Medium", size: 15)
    // Body (Regular weight, 0% tracking)
    static let bodyLarge = Font.custom("FamiljenGrotesk-Regular", size: 16)
    static let bodyMedium = Font.custom("FamiljenGrotesk-Regular", size: 14)
    static let bodySmall = Font.custom("FamiljenGrotesk-Regular", size: 12)
    static let caption = Font.custom("FamiljenGrotesk-Regular", size: 11)
    static let caption2 = Font.custom("FamiljenGrotesk-Medium", size: 10)
    static let blockTitle = Font.custom("FamiljenGrotesk-Medium", size: 16)
    static let headerKerning: CGFloat = -0.3  // -2% at ~15pt
    static let titleKerning: CGFloat = -0.68  // -2% at 34pt
}
