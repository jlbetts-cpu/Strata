import SwiftUI

struct StrataHeaderView: View {
    let month: String
    let day: String
    let isScrolled: Bool
    let gridWidth: CGFloat
    let onPlusTap: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            // Glass background — fades in on scroll
            Rectangle()
                .fill(.ultraThinMaterial)
                .frame(height: 120)
                .ignoresSafeArea(.container, edges: .top)
                .mask {
                    LinearGradient(
                        colors: [.black, .black, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .opacity(isScrolled ? 1 : 0)

            HStack {
                Text("\(month) \(day)")
                    .font(Typography.appTitle)
                    .kerning(Typography.titleKerning)
                    .foregroundColor(isScrolled ? .white : .primary)

                Spacer()

                Button(action: onPlusTap) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isScrolled ? .white : .primary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                        )
                }
            }
            .frame(width: gridWidth)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, GridConstants.horizontalPadding)
            .padding(.top, 8)
        }
        .allowsHitTesting(true)
        .animation(.easeInOut, value: isScrolled)
    }
}
