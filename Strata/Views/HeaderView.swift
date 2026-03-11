import SwiftUI

struct HeaderView: View {
    let completionRate: Double
    let totalBlocks: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("STRATA")
                    .font(.title2)
                    .fontWeight(.black)
                    .tracking(2)
                    .foregroundStyle(Color(hex: 0x648BF2))

                Text(dateString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Today's progress ring
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 3)

                Circle()
                    .trim(from: 0, to: completionRate)
                    .stroke(
                        Color(hex: 0x648BF2),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5), value: completionRate)

                Text("\(Int(completionRate * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }
}
