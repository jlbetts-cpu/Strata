import SwiftUI

// MARK: - Screen titles

/// A title that is data, not a name: a day ("Saturday 5 September") or a
/// place. Set in the owner's face only when it can be set WHOLE and on one
/// line; otherwise SF Pro Rounded for the whole string.
///
/// Two checks, both required by `docs/research/font.md` (a) item 2:
/// - **Coverage** (`StrataFont.covers`). A missing glyph would fall back one
///   character at a time and patch the word.
/// - **Width.** The face runs about 19% wider than SF, and "Saturday 5
///   September" measures 415pt at 34 against a 370pt column. `ViewThatFits`
///   takes the owner's face only at its full size; there is no shrunken
///   Strata rung, which would be a sixth size. The SF fallback keeps the
///   `minimumScaleFactor` it always had.
struct DynamicScreenTitle: View {
    let text: String

    var body: some View {
        if StrataFont.covers(text) {
            ViewThatFits(in: .horizontal) {
                Text(verbatim: text)
                    .font(Typography.screenTitleDrawn)
                    .lineLimit(1)
                    .fixedSize()
                system
            }
            .accessibilityAddTraits(.isHeader)
        } else {
            system.accessibilityAddTraits(.isHeader)
        }
    }

    private var system: some View {
        Text(verbatim: text)
            .font(Typography.screenTitle)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

// MARK: - Sheet titles

extension View {
    /// A sheet's or a pushed page's inline title.
    ///
    /// The system draws an inline title in SF Pro SEMIBOLD, a second family
    /// and a third weight. This puts the title in the principal slot in
    /// either the owner's face at 17 (`drawn`, for a title that names the
    /// sheet: "Add a win", "Edit", "Profile", "Plan") or SF Pro Rounded
    /// Medium at 17. `navigationTitle` is still set, so VoiceOver and a back
    /// button read the name.
    ///
    /// Settings stays SF: its header is already the mark and the wordmark,
    /// and a screen gets one drawn word.
    func sheetTitle(_ title: String, drawn: Bool) -> some View {
        modifier(SheetTitle(title: title, drawn: drawn))
    }
}

private struct SheetTitle: ViewModifier {
    let title: String
    let drawn: Bool

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { SheetTitleItem(title: title, drawn: drawn) }
    }
}

private struct SheetTitleItem: ToolbarContent {
    let title: String
    let drawn: Bool

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .principal) { label }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .principal) { label }
        }
    }

    private var label: some View {
        Text(verbatim: title)
            .font(drawn && StrataFont.covers(title)
                  ? Typography.sheetTitleDrawn : Typography.headerMedium)
            .foregroundStyle(AppColors.inkPrimary)
            .lineLimit(1)
            .accessibilityAddTraits(.isHeader)
    }
}
