import SwiftUI

struct MiniBlockPreview: View {
    let category: HabitCategory
    let blockSize: BlockSize
    let title: String
    var showTitle: Bool = true

    private var style: CategoryStyle { category.style }

    var body: some View {
        let aspect = CGFloat(blockSize.columnSpan) / CGFloat(blockSize.rowSpan)

        BlockSurface(cornerRadius: GridConstants.cornerRadius, scale: 0.75) {
            LinearGradient(
                stops: [
                    .init(color: style.lightTint, location: 0.0),
                    .init(color: style.baseColor, location: 0.3),
                    .init(color: style.baseColor, location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .aspectRatio(aspect, contentMode: .fit)
        // Content above the band, sharp
        .overlay {
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
    }
}
