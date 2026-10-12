import SwiftUI

/// **A block's own menu, one drawing** (the owner, 2026-10-11, of a planned
/// win's choices: "this specific menu would be a lot clearer with icons ...
/// it should be like this", pointing at the add sheet's; and "the menu
/// shouldn't have been inconsistent in the first place because I asked for
/// a consistency pass").
///
/// He was right. The add sheet's block got the app's own menu, a glyph and
/// a word per row, hung off the block; the planned win beside it on the
/// tower got the system's sheet of bare words, built the same evening.
/// Rule 1 of `docs/ten.md`: one thing, one drawing. Both are these rows in
/// this box now, and anything else that opens from a block uses them too.
struct BlockMenuRow: View {
    let title: String
    let symbol: String
    var destructive = false
    let action: () -> Void

    init(_ title: String, _ symbol: String, destructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.destructive = destructive
        self.action = action
    }

    var body: some View {
        Button {
            HapticsEngine.lightTap()
            action()
        } label: {
            Label(title, systemImage: symbol)
                .font(Typography.bodyLarge)
                .foregroundStyle(destructive ? AppColors.destructiveInk : AppColors.inkPrimary)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, GridConstants.horizontalPadding)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressWord)
    }
}

/// The menu's box: its rows, at one width, for a popover hung off a block.
struct BlockMenuList<Rows: View>: View {
    @ViewBuilder var rows: () -> Rows

    static var width: CGFloat { 320 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            rows()
        }
        .padding(.vertical, GridConstants.gapTight)
        .frame(width: Self.width, alignment: .leading)
    }
}

extension View {
    /// Hangs a block's menu off this view. What a row asks for should run
    /// once the menu has left (a sheet asked for while a popover is still
    /// going is dropped), so rows call `BlockMenuAfter.run`.
    ///
    /// `above` opens it over the block, for one that stands low on the
    /// screen: a planned win sits just over the tab bar, and a menu opened
    /// downward there was cut to three of its five rows (seen 2026-10-11).
    func blockMenu<Rows: View>(isPresented: Binding<Bool>, above: Bool = false,
                               @ViewBuilder rows: @escaping () -> Rows) -> some View {
        popover(isPresented: isPresented, arrowEdge: above ? .bottom : .top) {
            BlockMenuList(rows: rows)
                .presentationCompactAdaptation(.popover)
        }
    }
}

/// Runs something once a block's menu has closed.
enum BlockMenuAfter {
    @MainActor
    static func run(closing isPresented: Binding<Bool>, _ action: @escaping () -> Void) {
        isPresented.wrappedValue = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            action()
        }
    }
}
