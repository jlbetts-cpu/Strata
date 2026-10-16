import SwiftUI

/// **The username field** (`Handle`): "@" fixed in front, what you type
/// made a username as you type it (lower case, no spaces), and one quiet
/// line under it saying what is wrong, or that it is yours. The one field
/// for this job, in setup and in Edit Profile.
struct HandleField: View {
    @Binding var text: String
    /// What the last claim said, if anything ("Taken", "Saved").
    var note: String?
    var large = false
    /// Focused as it appears (the sheet), not in setup, where the name is.
    var autofocus = false
    var onSubmit: () -> Void = {}
    @FocusState private var focused: Bool

    private var handle: String { Handle.normalized(text) }
    private var problem: String? { handle.isEmpty ? nil : Handle.problem(handle) }

    var body: some View {
        VStack(spacing: GridConstants.gapTight) {
            HStack(spacing: 2) {
                Text(verbatim: "@")
                    .foregroundStyle(AppColors.inkTertiary)
                TextField("", text: Binding(get: { text }, set: { text = String(Handle.normalized($0).prefix(Handle.longest)) }),
                          prompt: Text("username").foregroundStyle(AppColors.inkTertiary))
                    .foregroundStyle(AppColors.inkPrimary)
                    // Not `.username`: that is a sign-in's, and it brought the
                    // keyboard's Passwords bar.
                    .textContentType(.none)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .submitLabel(.done)
                    .onSubmit(onSubmit)
                    .focused($focused)
                    .fixedSize()
                    .accessibilityLabel("Username")
            }
            .font(large ? Typography.headerMedium : Typography.bodyLarge)
            Text(problem ?? note ?? " ")
                .font(Typography.screenSubtitle)
                .foregroundStyle(problem == nil ? AppColors.inkSecondary : AppColors.destructiveInk)
                .animation(GridConstants.crossFade, value: problem ?? note)
        }
        // After the sheet has settled: focus asked for while it is still
        // rising is dropped, and the keyboard never comes.
        .task {
            guard autofocus else { return }
            try? await Task.sleep(for: .milliseconds(400))
            focused = true
        }
    }
}
