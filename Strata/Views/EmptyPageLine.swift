import SwiftUI

/// **The one way a page says it is empty** (the owner, 2026-10-15: "make sure
/// the empty states are consistent. thats super important consistency").
/// One sentence, in the heading's type and the page's ink, in the middle of
/// the room the page has. The chat, the journal, a past day, a crew's photos
/// and a place all say theirs through this, so none can drift a size down or
/// a grey quieter, or sit in a corner while the rest are centred.
///
/// **Muse's way, since 2026-10-16** (the owner: "I really like Muse's empty
/// states, it looks very clean"): a quiet outline picture, a short title in
/// the page's second ink, and one plain line under it saying what will come
/// here. No full stop on the title, as a heading has none.
struct EmptyPageLine: View {
    let words: String
    var icon: String? = nil
    var detail: String? = nil

    init(_ words: String, icon: String? = nil, detail: String? = nil) {
        self.words = words
        self.icon = icon
        self.detail = detail
    }

    var body: some View {
        VStack(spacing: GridConstants.gapTight) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(AppColors.inkTertiary)
                    .padding(.bottom, GridConstants.gapTight)
                    .accessibilityHidden(true)
            }
            Text(words)
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.inkSecondary)
            if let detail {
                Text(detail)
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkSecondary)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, GridConstants.horizontalPadding)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
