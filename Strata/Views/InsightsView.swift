import SwiftUI

struct InsightsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                Text("Coming soon")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 400)
            }
            .background { WarmBackground().ignoresSafeArea() }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
