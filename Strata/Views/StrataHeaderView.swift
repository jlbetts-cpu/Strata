import SwiftUI

struct StrataHeaderView: View {
    let month: String
    let day: String
    let isScrolled: Bool
    let onPlusTap: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            // Gradient background — binary opacity, animated
            LinearGradient(
                colors: [.black.opacity(0.7), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .ignoresSafeArea(.container, edges: .top)
            .opacity(isScrolled ? 1 : 0)

            HStack {
                Text("\(month) \(day)")
                    .font(Typography.appTitle)
                    .kerning(Typography.titleKerning)
                    .foregroundColor(isScrolled ? .white : .primary)

                Spacer()

                Button(action: onPlusTap) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isScrolled ? .white : .primary)
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .allowsHitTesting(true)
        .animation(.easeInOut, value: isScrolled)
    }
}
