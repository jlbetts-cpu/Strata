import SwiftUI

struct MiniBlockPreview: View {
    let category: HabitCategory
    let blockSize: BlockSize
    let title: String

    @State private var breathePhase: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var style: CategoryStyle { category.style }

    var body: some View {
        let aspect: CGFloat = CGFloat(blockSize.columnSpan) / CGFloat(blockSize.rowSpan)

        GeometryReader { geo in
            let fitted = fittedSize(in: geo.size, aspect: aspect)

            ZStack {
                // Fill gradient — matches HabitBlockView exactly
                LinearGradient(
                    stops: [
                        .init(color: style.lightTint, location: 0.0),
                        .init(color: style.baseColor, location: 0.3),
                        .init(color: style.baseColor, location: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Frosted overlay
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .white.opacity(0.20), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Mini content
                VStack(alignment: .leading, spacing: 2) {
                    Image(systemName: category.iconName)
                        .font(Typography.miniBlockIcon)
                        .foregroundStyle(.white.opacity(0.60))
                    Spacer()
                    Text(title)
                        .font(Typography.miniBlockTitle)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .padding(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            .frame(width: fitted.width, height: fitted.height)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            // Breathing border (matches HabitBlockView overlay 1)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(breathePhase ? 0.95 : 0.85), location: 0.0),
                                .init(color: .white.opacity(0.4), location: 0.4),
                                .init(color: .white.opacity(0.0), location: 0.75)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(
                color: .black.opacity(GridConstants.adaptiveShadowOpacity(GridConstants.shadowOpacity, colorScheme: colorScheme)),
                radius: GridConstants.shadowRadius,
                x: 0,
                y: GridConstants.shadowY
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: GridConstants.breatheDuration).repeatForever(autoreverses: true)) {
                    breathePhase = true
                }
            }
            .onDisappear { breathePhase = false }
        }
    }

    private func fittedSize(in container: CGSize, aspect: CGFloat) -> CGSize {
        if aspect >= 1 {
            // Wider or square: fit width first
            let w = min(container.width, container.height * aspect)
            return CGSize(width: w, height: w / aspect)
        } else {
            // Taller: fit height first
            let h = min(container.height, container.width / aspect)
            return CGSize(width: h * aspect, height: h)
        }
    }
}
