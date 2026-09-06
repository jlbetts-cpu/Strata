import SwiftUI

struct WarmBackground: View {
    var body: some View {
        // Light only. The gradient's bottom is 1-2% warmer, which is what keeps
        // the page from reading as flat white behind the blocks.
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.98, green: 0.975, blue: 0.965), location: 0.0),
                .init(color: Color(red: 0.975, green: 0.968, blue: 0.955), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .accessibilityHidden(true)
    }
}
