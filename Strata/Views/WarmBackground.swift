import SwiftUI

struct WarmBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if colorScheme == .dark {
                // #6: Dark mode — system background + 2% warm tint (Palmer & Schloss 2010)
                Color(uiColor: .systemBackground)
                    .overlay(Color(red: 0.15, green: 0.10, blue: 0.05).opacity(0.02))
            } else {
                // #5: Light mode — subtle vertical gradient, bottom 1-2% warmer
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.98, green: 0.975, blue: 0.965), location: 0.0),
                        .init(color: Color(red: 0.975, green: 0.968, blue: 0.955), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .accessibilityHidden(true)
    }
}
