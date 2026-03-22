import SwiftUI

struct TowerHeaderBar: View {
    let tower: Tower?
    let onMenuTap: () -> Void
    let onRename: (String) -> Void

    @State private var editingName: String = ""
    @State private var isEditing: Bool = false
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Tower emoji button — opens side menu
            Button(action: onMenuTap) {
                Text(tower?.emoji ?? "🏗️")
                    .font(.system(size: 18))
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Circle())

            // Tower name — editable inline
            if isEditing {
                TextField("Tower name", text: $editingName)
                    .font(Typography.headerLarge)
                    .focused($nameFieldFocused)
                    .onSubmit {
                        commitRename()
                    }
                    .submitLabel(.done)
            } else {
                Button {
                    editingName = tower?.name ?? ""
                    isEditing = true
                    nameFieldFocused = true
                } label: {
                    HStack(spacing: 4) {
                        Text(tower?.name ?? "Tower")
                            .font(Typography.headerLarge)
                            .foregroundStyle(.primary)

                        Image(systemName: "pencil")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
    }

    private func commitRename() {
        let trimmed = editingName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            onRename(trimmed)
        }
        isEditing = false
        nameFieldFocused = false
    }
}
