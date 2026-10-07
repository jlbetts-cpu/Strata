import SwiftUI

/// **The owner's own drawn icons** (2026-10-06), cut from his Procreate sheet
/// by `docs/icons/slice_icons.py`.
///
/// **His rule: what is yours is drawn, tools are Apple's** (2026-10-07: custom
/// icons "make sense for the category and emoji picker, doesn't make as much
/// sense for the eraser"). His hand is on the six category chips, where the
/// colour already says "yours", and on the sticker button, your own
/// expression. Every tool and control (eraser, undo, back, close, share,
/// trash, send, Settings rows) stays an SF Symbol: those are recognised in a
/// glance and pressed without thinking. The eraser and undo were drawn for a
/// night and went back. A drawn sticker button beside Apple's eraser is his
/// call: it says this one is yours.
///
/// "Make sure the icons still look clean and premium, I don't want the app to
/// lose value from this update": the script thickens every outline to one
/// weight on screen and smooths his pen edge rather than shipping the sheet as
/// drawn, and simplifies the two that smudged at chip size (the bag's clasp,
/// the shoulder behind his two people).
enum Doodle: String, CaseIterable {
    case sticker = "DoodleSticker"
    case health = "DoodleHealth"
    case work = "DoodleWork"
    case creativity = "DoodleCreativity"
    case focus = "DoodleFocus"
    case social = "DoodleSocial"
    case mindfulness = "DoodleMindfulness"

    var isCategory: Bool {
        switch self {
        case .health, .work, .creativity, .focus, .social, .mindfulness: true
        default: false
        }
    }

    /// The `GridConstants.icon*` token the PNGs are cut for, and the canvas
    /// they are cut on at that size (the script's `ICONS`). The canvas is
    /// bigger than the token because a drawing is drawn `OPTICAL` (12%) larger
    /// than the symbol's ink to read the same size, and its round pen ends need
    /// the air; at the token the PNG lands pixel for pixel.
    var token: CGFloat { isCategory ? GridConstants.iconCategory : GridConstants.iconToolbar }
    var canvas: CGFloat { isCategory ? 20 : 26 }
}

extension HabitCategory {
    /// His filled glyph for the category, by meaning (the sheet's bottom row).
    /// `unlabeled` has none, as it has no symbol. Shortcuts, Focus and the
    /// App Intents keep `iconName`: the system draws those, beside its own.
    var doodle: Doodle? {
        switch self {
        case .health: .health
        case .work: .work
        case .creativity: .creativity
        case .focus: .focus
        case .social: .social
        case .mindfulness: .mindfulness
        case .unlabeled: nil
        }
    }
}

/// One of his icons at an SF Symbol's size, tinted like one.
///
/// `size` is the token the symbol it replaces was drawn at; it scales with the
/// user's text size through `@ScaledMetric`, as `iconSize` does for a symbol
/// (WCAG 1.4.4), so the two kinds of glyph grow at the same rate. A template
/// image, so `.foregroundStyle` tints it exactly as it tinted the symbol.
/// `label` is what VoiceOver says, the symbol's old name for it.
struct DoodleIcon: View {
    let doodle: Doodle
    let label: String
    @ScaledMetric private var side: CGFloat

    init(_ doodle: Doodle, size: CGFloat, relativeTo textStyle: Font.TextStyle = .body, label: String) {
        self.doodle = doodle
        self.label = label
        _side = ScaledMetric(wrappedValue: doodle.canvas * size / doodle.token, relativeTo: textStyle)
    }

    var body: some View {
        Image(doodle.rawValue, label: Text(label))
            .renderingMode(.template)
            .resizable()
            .interpolation(.high)
            .frame(width: side, height: side)
    }
}
