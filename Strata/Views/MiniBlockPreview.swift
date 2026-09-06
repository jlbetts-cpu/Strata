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
            // #242: Fill gradient — aligned to vertical direction (matches HabitBlockView)
            LinearGradient(
                stops: [
                    .init(color: style.lightTint, location: 0.0),
                    .init(color: style.baseColor, location: 0.3),
                    .init(color: style.baseColor, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Frosted overlay — depth cue per color scheme
            if colorScheme == .light {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .white.opacity(0.20), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.10), location: 0.0),
                        .init(color: .clear, location: 0.5)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            // Mini content
            VStack(alignment: .leading, spacing: 2) {
                if let icon = category.iconName {
                    Image(systemName: icon)
                        .font(Typography.miniBlockIcon)
                        .foregroundStyle(.white.opacity(0.60))
                }
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
        .clipShape(RoundedRectangle(cornerRadius: GridConstants.blockCornerRadius, style: .continuous))
        // Border removed — iOS 17-18: shadow alone carries depth
        .shadow(
            color: .black.opacity(GridConstants.adaptiveShadowOpacity(GridConstants.shadowOpacity, colorScheme: colorScheme)),
            radius: GridConstants.shadowRadius,
            x: 0,
            y: GridConstants.shadowY
        )
    }
}
