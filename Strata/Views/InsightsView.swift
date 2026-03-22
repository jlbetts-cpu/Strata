import SwiftUI

struct InsightsView: View {
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
