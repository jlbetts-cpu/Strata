import SwiftUI

/// **The one way a page says it is empty** (the owner, 2026-10-15: "make sure
/// the empty states are consistent. thats super important consistency").
/// One sentence, in the heading's type and the page's ink, in the middle of
/// the room the page has. The chat, the journal, a past day, a crew's photos
/// and a place all say theirs through this, so none can drift a size down or
/// a grey quieter, or sit in a corner while the rest are centred.
struct EmptyPageLine: View {
    let words: String

    init(_ words: String) { self.words = words }

    var body: some View {
        Text(words)
            .font(Typography.headerMedium)
            .foregroundStyle(AppColors.inkPrimary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, GridConstants.horizontalPadding)
            .frame(maxWidth: .infinity)
    }
}
