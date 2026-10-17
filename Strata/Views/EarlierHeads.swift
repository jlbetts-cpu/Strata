import SwiftUI

/// **Your last three heads, to take one back** (the owner, 2026-10-14: "I
/// took a head already but I deleted it to try the new feature I feel like
/// the app should save your previous three heads to go off of").
///
/// `HeadStore` keeps them (`earlierEntries`): a head deleted, or replaced by
/// a new one, waits here on this phone, never sent. These are the words and
/// the one action every screen that shows them shares.
@MainActor
enum EarlierHeads {
    static let title = "Earlier Heads"
    static let broughtBack = "Head brought back"
    /// Under the row in Profile: what they are, and the one press.
    /// **Says how to delete one** (the launch pass, 5½: nothing a person
    /// needs may hide behind a gesture nobody is told about).
    static let footer = "Your last three, kept on this phone and never sent. Press one to use it again, or hold it to delete it."
    /// Over the row on a page that asks you to make a head.
    static let instead = "Or use one you made before."

    /// **An earlier head is yours again, and Undo puts back what was**: the
    /// head that was in use, which has just joined the earlier ones, or no
    /// head at all.
    static func bringBack(_ id: UUID, store: HeadStore = .shared) {
        let before = store.activeID
        store.bringBack(id)
        UndoLine.shared.show(broughtBack, undo: {
            if let before { store.bringBack(before) } else { store.delete(id) }
        })
    }
}

/// The earlier heads in a row: a press brings one back, a hold offers Delete
/// for Good, which asks first. Drawn as `HeadPickerRow` draws a head (the
/// same square of `quietFill` at the block's corner, `HeadStill` in it), with
/// no ring, since none of them is the one in use. No shadow: a swatch is a
/// picture of a head, not a head standing on something.
struct EarlierHeadsRow: View {
    let entries: [HeadStore.Entry]
    /// Where the row sits: leading in a Profile row, centred on a page.
    var alignment: Alignment = .leading
    var onPick: (UUID) -> Void

    /// One still face per head, read off the main actor (`HeadStore.swatches`).
    @State private var swatches: [UUID: HeadRig] = [:]
    @State private var forgetting: HeadStore.Entry?

    /// `HeadPickerRow`'s swatch.
    private static let side: CGFloat = 60

    var body: some View {
        HStack(spacing: GridConstants.gapItem) {
            ForEach(entries.prefix(HeadStore.Roster.earlierLimit)) { tile($0) }
        }
        .padding(.vertical, GridConstants.gapTight)
        .frame(maxWidth: .infinity, alignment: alignment)
        .task(id: entries.map(\.id)) { swatches = await HeadStore.shared.swatches() }
        .confirmationDialog("Delete this head for good?",
                            isPresented: Binding(get: { forgetting != nil }, set: { if !$0 { forgetting = nil } }),
                            titleVisibility: .visible, presenting: forgetting) { entry in
            Button("Delete for Good", role: .destructive) {
                HapticsEngine.lightTap()
                HeadStore.shared.forget(entry.id)
            }
        } message: { _ in
            Text("It goes from this phone and can't be brought back.")
        }
    }

    private func tile(_ entry: HeadStore.Entry) -> some View {
        let radius = GridConstants.blockCornerRadius(forCell: Self.side)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return Button {
            HapticsEngine.tick()
            onPick(entry.id)
        } label: {
            ZStack {
                shape.fill(AppColors.quietFill)
                if let rig = swatches[entry.id] {
                    HeadStill(rig: rig, side: Self.side * 0.78)
                        .frame(width: Self.side, height: Self.side)
                        .clipShape(shape)
                }
            }
            .frame(width: Self.side, height: Self.side)
            .contentShape(shape)
        }
        .buttonStyle(.press)
        .contextMenu {
            Button("Delete for Good", systemImage: "trash", role: .destructive) { forgetting = entry }
        }
        .accessibilityLabel(Self.name(of: entry))
        .accessibilityHint("Use this head again")
        .accessibilityAction(named: "Delete for Good") { forgetting = entry }
    }

    /// A name somebody chose, or when it was made: a face is not a label
    /// somebody can hear, and "Head 2" is a name nobody chose.
    static func name(of entry: HeadStore.Entry, person: String? = nil) -> String {
        HeadPickerRow.isGenerated(entry.name, person: person ?? ProfileStore.shared.name)
            ? "Head from \(entry.created.formatted(.dateTime.month(.wide).day()))"
            : entry.name
    }
}
