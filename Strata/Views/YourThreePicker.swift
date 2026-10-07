import SwiftUI

/// **Choosing your three** (`YourThree`), from Your day: the picks, any of
/// yours that are not one of them, and a line to write your own.
///
/// The same inset list on the warm page as Your day under it, so it reads as
/// one place. Three at most: once three are ticked the rest go quiet and
/// cannot be ticked, and a tick taken off frees a place. Nothing is ticked
/// for you, and Done keeps whatever is ticked, even none.
struct YourThreePicker: View {
    let initial: [YourThree.Item]
    var onDone: ([YourThree.Item]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var chosen: [YourThree.Item] = []
    /// Yours that are not picks: kept from before, or written here.
    @State private var own: [YourThree.Item] = []
    @State private var writing = ""
    @State private var loaded = false

    private var full: Bool { chosen.count >= YourThree.size }
    private var options: [YourThree.Item] { own + YourThree.picks }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(YourThree.Copy.pickerLine)
                        .font(Typography.bodyLarge)
                        .foregroundStyle(AppColors.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .listRowBackground(Color.clear)
                Section {
                    ForEach(options) { item in row(item) }
                    TextField(YourThree.Copy.ownPrompt, text: $writing,
                              prompt: Text(YourThree.Copy.ownPrompt).foregroundStyle(AppColors.inkTertiary))
                        .font(Typography.bodyLarge)
                        .foregroundStyle(AppColors.inkPrimary)
                        .submitLabel(.done)
                        .onSubmit(write)
                        .frame(minHeight: SheetAction.target)
                }
                .listRowSeparator(.hidden)
            }
            .listSectionSeparator(.hidden)
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(WarmBackground().ignoresSafeArea())
            .animation(GridConstants.crossFade, value: chosen)
            .sheetTitle(YourThree.Copy.pickerTitle, drawn: false)
            .toolbar {
                // Done alone, as Your day under it has: a swipe down is the
                // way out that keeps nothing.
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onDone(chosen)
                        dismiss()
                    } label: { Text("Done").sheetAction(.confirm) }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground { WarmBackground().ignoresSafeArea() }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            chosen = initial
            let picks = Set(YourThree.picks.map(\.id))
            own = initial.filter { !picks.contains($0.id) }
        }
    }

    /// One win: its words, and a tick once chosen. Unticked while three are
    /// already chosen, it is set in the quieter ink and does nothing.
    private func row(_ item: YourThree.Item) -> some View {
        let on = chosen.contains { $0.id == item.id }
        return Button {
            HapticsEngine.lightTap()
            if on { chosen.removeAll { $0.id == item.id } } else if !full { chosen.append(item) }
        } label: {
            HStack(spacing: GridConstants.gapLabel) {
                Text(item.title)
                    .font(Typography.bodyLarge)
                    .foregroundStyle(on || !full ? AppColors.inkPrimary : AppColors.inkTertiary)
                Spacer(minLength: 0)
                if on {
                    Image(systemName: "checkmark")
                        .font(Typography.headerSmall)
                        .foregroundStyle(AppColors.inkPrimary)
                        .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .disabled(!on && full)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    /// A win of your own: added to the list, and ticked while there is room.
    private func write() {
        let title = writing.trimmingCharacters(in: .whitespacesAndNewlines)
        writing = ""
        guard !title.isEmpty else { return }
        let item = YourThree.Item(title: title, category: nil)
        if !options.contains(where: { $0.id == item.id }) { own.append(item) }
        let existing = options.first { $0.id == item.id } ?? item
        if !chosen.contains(where: { $0.id == item.id }), !full { chosen.append(existing) }
    }
}
