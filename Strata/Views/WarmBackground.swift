import SwiftUI

/// The app's warm ground. Light only — Strata ships a single appearance
/// (UIUserInterfaceStyle = Light), and the block style is built against this
/// off-white. Matches the Figma plate #FBFAF8 (Apollo, 248:14).
struct WarmBackground: View {
    var body: some View {
        Rectangle().fill(Color(hex: 0xFBFAF8))
    }
}
