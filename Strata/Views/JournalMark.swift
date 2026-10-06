import SwiftUI

/// **What a day shows for its journal, by the owner's exact rule**
/// (2026-10-05).
///
/// - A day with an emoji shows the emoji, and NOTHING extra: the emoji
///   already says something is written there.
/// - A day with a note and no emoji shows a tiny ink dot, in the same corner
///   the emoji would sit in.
/// - Locked (Lock Journal on and not opened this session), neither shows,
///   the way the emoji have always been hidden (`JournalLock.hidesWriting`).
///
/// A pure rule, so the calendar cell and the journal button cannot disagree
/// about it and `WinsBatchTests` can hold it without a view.
nonisolated enum JournalMark: Equatable {
    case none
    case emoji(String)
    case dot

    static func forDay(symbol: String?, written: Bool, hidden: Bool = false) -> JournalMark {
        guard !hidden else { return .none }
        if let symbol, !symbol.isEmpty { return .emoji(symbol) }
        return written ? .dot : .none
    }

    /// **The journal button's dot.** On a day's own page only, when the day
    /// has a note and the journal is not locked. Never on the Wins header:
    /// there, Crews is the only thing that ever carries a dot, and a dot on
    /// today's journal would read as the app asking for a note, which the
    /// journal never does.
    static func buttonShowsDot(hasNote: Bool, hidden: Bool, onDayPage: Bool) -> Bool {
        onDayPage && hasNote && !hidden
    }

    /// The dot's side. Tiny: a mark that a note is there, under the weight
    /// of the 15pt emoji it stands in for, and well under the Crews dot's 10,
    /// which is news rather than a fact about a day.
    static let dotSide: CGFloat = 5
}

/// The dot itself, in one place for the calendar and the button.
struct JournalDot: View {
    var ink: Color = AppColors.inkSecondary

    var body: some View {
        Circle()
            .fill(ink)
            .frame(width: JournalMark.dotSide, height: JournalMark.dotSide)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
