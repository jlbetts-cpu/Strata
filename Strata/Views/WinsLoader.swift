import SwiftUI

/// **The app's one loader: the system's** (the owner, 2026-10-16: "the
/// loading that we added doesn't look good, let's just keep the default
/// loading indicator for now"). The drawn and erased ring of 2026-10-15 came
/// out; this stays the one name every waiting screen uses, so a loader of
/// our own can come back in one place if he asks for one.
struct WinsLoader: View {
    var size: CGFloat = 28

    var body: some View {
        ProgressView()
            .controlSize(size < 24 ? .small : .regular)
            .frame(width: size, height: size)
            .accessibilityLabel("Loading")
    }
}
