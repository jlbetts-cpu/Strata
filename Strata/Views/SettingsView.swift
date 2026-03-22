import SwiftUI

struct SettingsView: View {
    var body: some View {
        ZStack {
            WarmBackground()
                .ignoresSafeArea()

            Text("Coming soon")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}
