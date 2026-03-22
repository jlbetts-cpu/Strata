import SwiftUI

struct WarmBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Rectangle().fill(
            colorScheme == .dark
                ? Color(hex: 0x403D39)
                : Color(red: 0.98, green: 0.975, blue: 0.965)
        )
    }
}
