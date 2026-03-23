import SwiftUI

struct MiniBlockPreview: View {
    let category: HabitCategory
    let blockSize: BlockSize
    let title: String
    var showTitle: Bool = true

    @Environment(\.colorScheme) private var colorScheme

    private var style: CategoryStyle { category.style }
    private var borderHighlight: Color { style.lightTint }

    var body: some View {
        let aspect = CGFloat(blockSize.columnSpan) / CGFloat(blockSize.rowSpan)

        ZStack {
            // Fill gradient — matches HabitBlockView exactly
            LinearGradient(
                stops: [
                    .init(color: style.lightTint, location: 0.0),
                    .init(color: style.baseColor, location: 0.3),
                    .init(color: colorScheme == .dark ? style.darkShade : style.baseColor, location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Frosted overlay (light mode only)
            if colorScheme == .light {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .white.opacity(0.20), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            // Mini content
            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: category.iconName)
                    .font(Typography.miniBlockIcon)
                    .foregroundStyle(.white.opacity(0.60))
                Spacer()
                if showTitle {
                    Text(title)
                        .font(Typography.miniBlockTitle)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .aspectRatio(aspect, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous))
        // Crisp border (matches HabitBlockView overlay 1)
        .overlay(
            RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: borderHighlight.opacity(0.55), location: 0.0),
                            .init(color: borderHighlight.opacity(0.20), location: 0.4),
                            .init(color: borderHighlight.opacity(0.0), location: 0.75)
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
    }
}
