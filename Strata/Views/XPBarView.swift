import SwiftUI

struct XPBarView: View {
    let level: Int
    let title: String
    let progress: Double
    let xpInto: Int
    let xpTotal: Int

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Lv.\(level)")
                    .font(Typography.bodyMedium)
                    .fontWeight(.bold)
                    .foregroundStyle(AppColors.accentWarm)

                Text(title)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(xpInto)/\(xpTotal) XP")
                    .font(Typography.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppColors.accentWarm, AppColors.accentPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * max(progress, 0.02))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
