import SwiftUI

/// Sizes an SF Symbol from a `GridConstants.icon*` token AND scales it with
/// Dynamic Type.
///
/// `.font(.system(size:))` is a fixed size — it does not respond to the user's
/// text size at all, so icons stayed put while the labels beside them grew.
/// brand.md requires Dynamic Type across every screen (WCAG 1.4.4), and
/// `@ScaledMetric` is the supported way to get it for a numeric size. Doing that
/// inline needs a stored property per view, which is why it had only been done in
/// one place; wrapping it in a modifier makes it a single line at the call site.
///
/// Pair the token with the text style it sits beside — a caption-sized badge
/// should grow at the caption's rate, not the body's.
private struct ScaledIcon: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design

    init(size: CGFloat, relativeTo textStyle: Font.TextStyle, weight: Font.Weight, design: Font.Design) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
    }
}

extension View {
    /// Size an SF Symbol from a token, scaling with Dynamic Type.
    func iconSize(
        _ size: CGFloat,
        relativeTo textStyle: Font.TextStyle = .body,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> some View {
        modifier(ScaledIcon(size: size, relativeTo: textStyle, weight: weight, design: design))
    }
}
