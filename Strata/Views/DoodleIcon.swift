import SwiftUI

/// **The owner's own drawn icons** (2026-10-06), cut from his Procreate sheet
/// by `docs/icons/slice_icons.py`.
///
/// The split he approved after the research: "less is so much more to me, if
/// we can make something more minimal and intuitive we should do it". His hand
/// goes where you DRAW (the ink tools, the day's sticker) and on the six
/// category chips, where the colour already says "yours". Everything whose job
/// is to be recognised in a glance and pressed without thinking (back, close,
/// share, trash, send) stays an SF Symbol, and **a drawn icon never stands in
/// the same row as a symbol at the same level**: two kinds of line side by
/// side read as a mistake, not as character. Then, the next morning: "make
/// sure the icons still look clean and premium, I don't want the app to lose
/// value from this update", which is why the script thickens every outline to
/// one weight on screen and smooths his pen edge rather than shipping the
/// sheet as drawn.
enum Doodle: String, CaseIterable {
    case eraser = "DoodleEraser"
    /// The eraser while it is on, filled, as `eraser.fill` is a selected tool
    /// across iOS. Made from his outline by the script, not drawn twice.
    case eraserOn = "DoodleEraserOn"
    case undo = "DoodleUndo"
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
