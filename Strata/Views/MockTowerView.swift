import SwiftUI

struct MockTowerView: View {
    private let columns = 4
    private let spacing: CGFloat = 6
    private let cornerRadius: CGFloat = 12
    private let hPad: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            let colW = floor(
                (geo.size.width - hPad * 2 - spacing * 3) / 4
            )

            let blocks: [(String, UInt, Int, Int, Int, Int)] = [
                ("Gym",               0x10B77F, 0, 0, 1, 1),
                ("Meditate",          0xF471B5, 1, 0, 1, 1),
                ("Deep Work\nSession",0x3C83F6, 2, 0, 2, 2),
                ("Read 30 mins",      0xF59F0A, 0, 1, 2, 1),
                ("Morning\nExercise", 0x10B77F, 0, 2, 2, 1),
                ("Sketch",            0xA689FA, 2, 2, 1, 1),
                ("Call\nFriend",      0x00CCB8, 3, 2, 1, 1),
                ("Gym",               0x10B77F, 0, 3, 2, 2),
                ("Deep Work\nSession",0x3C83F6, 2, 3, 2, 2),
                ("Morning\nExercise", 0x10B77F, 0, 5, 2, 1),
                ("Water",             0x00CCB8, 2, 5, 1, 1),
                ("Journal",           0xF471B5, 3, 5, 1, 1),
            ]

            let maxRow = blocks.map { $0.3 + $0.5 }.max() ?? 1
            let totalH = CGFloat(maxRow) * colW + CGFloat(maxRow - 1) * spacing
            let gridW = CGFloat(columns) * colW + CGFloat(columns - 1) * spacing

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack {
                        Text("STRATA")
                            .font(.title2)
                            .fontWeight(.black)
                            .tracking(2)
                            .foregroundStyle(Color(hex: 0x648BF2))
                        Spacer()
                        Image(systemName: "plus")
                            .font(.title3)
                            .foregroundStyle(Color.primary)
                    }

                    // Masonry grid
                    ZStack(alignment: .topLeading) {
                        ForEach(0..<blocks.count, id: \.self) { i in
                            let b = blocks[i]
                            let w = CGFloat(b.4) * colW + CGFloat(b.4 - 1) * spacing
                            let h = CGFloat(b.5) * colW + CGFloat(b.5 - 1) * spacing
                            let x = CGFloat(b.2) * (colW + spacing)
                            let y = CGFloat(b.3) * (colW + spacing)

                            blockView(
                                title: b.0,
                                hex: b.1,
                                width: w,
                                height: h,
                                isBig: b.4 > 1 || b.5 > 1
                            )
                            .offset(x: x, y: y)
                        }
                    }
                    .frame(width: gridW, height: totalH, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, hPad)
                .padding(.top, 20)
                .padding(.bottom, 80)
            }
        }
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Block

    private func blockView(
        title: String,
        hex: UInt,
        width: CGFloat,
        height: CGFloat,
        isBig: Bool
    ) -> some View {
        let color = Color(hex: hex)

        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.82), color],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.28), Color.white.opacity(0)],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .frame(height: height * 0.4)
                Spacer(minLength: 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            Text(title)
                .font(isBig ? .subheadline : .caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.65)
                .padding(8)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: color.opacity(0.35), radius: 6, x: 0, y: 2)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    MockTowerView()
}
