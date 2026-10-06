import SwiftUI

/// **One line in a band that cannot grow, at a large text size** (the QoL
/// review's accessibility pass, 2026-10-06).
///
/// The photo viewer's title sits in a 44pt band and its caption in a 56pt one,
/// both fixed on purpose (`PhotoViewer.dateHeight` says why: a stage that
/// changes size under a photograph is worse than the room it saves). So they
/// cannot wrap, and at the accessibility sizes a `.lineLimit(1)` cut "Regular ·
/// 8 September · 6:26 PM" down to "Regular · 8 Sep…" and a win's name to its
/// first word.
///
/// This lets such a line shrink to fit instead, but **never below the 15pt
/// floor** (CLAUDE.md, and `TypographyTests`): the factor is 15 over the size
/// the style has actually reached, so at the default size a 15pt line does not
/// shrink at all and a 17pt one gives up two points at most, while at AX5 the
/// same line has a long way to come down before it reaches a size the app
/// would set anyway. A fixed `minimumScaleFactor(0.7)` would put a long title
/// at 11.9pt on a phone at the default size, which is the thing the floor is
/// for.
struct LargeTypeFit: ViewModifier {
    /// The style's size at the default setting, scaled with Dynamic Type.
    @ScaledMetric private var reached: CGFloat

    init(_ style: Font.TextStyle) {
        _reached = ScaledMetric(wrappedValue: Self.defaultSize(of: style), relativeTo: style)
    }

    func body(content: Content) -> some View {
        content.minimumScaleFactor(Self.factor(reached: reached))
    }

    /// The app's floor for type, in points at any setting.
    static let floor: CGFloat = 15

    /// How far a line may shrink, given the size its style has reached.
    static func factor(reached: CGFloat) -> CGFloat {
        min(1, floor / max(reached, 1))
    }

    /// The tiers the app sets (`Typography.tierStyles`), at Large.
    static func defaultSize(of style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: 34
        case .subheadline: 15
        default: 17
        }
    }
}

extension View {
    /// See `LargeTypeFit`: shrink rather than truncate at a large text size,
    /// never under 15pt.
    func fitsLargeType(_ style: Font.TextStyle) -> some View {
        modifier(LargeTypeFit(style))
    }
}
