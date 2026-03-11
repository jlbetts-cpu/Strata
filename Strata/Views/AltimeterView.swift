import SwiftUI

struct AltimeterView: View {
    let heightMeters: Double
    let peakRows: Int

    // Approximate tick height — doesn't need to match grid exactly
    private let tickHeight: CGFloat = 28

    var body: some View {
        VStack(spacing: 4) {
            // Height value
            Text("\(Int(heightMeters))")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: 0x648BF2))

            Text("m")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(Color.secondary)

            // Vertical ruler ticks
            VStack(spacing: 0) {
                ForEach(0..<max(peakRows, 4), id: \.self) { row in
                    HStack(spacing: 2) {
                        Rectangle()
                            .fill(Color.primary.opacity(row % 3 == 0 ? 0.3 : 0.1))
                            .frame(width: row % 3 == 0 ? 12 : 6, height: 1)
                        Spacer()
                    }
                    .frame(height: tickHeight)
                }
            }
        }
        .padding(.vertical, 8)
    }
}
