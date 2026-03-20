import SwiftUI

struct AltimeterPill: View {
    let heightMeters: Double

    private var meterLabel: String {
        if heightMeters < 1 { return "0m" }
        if heightMeters >= 1000 {
            return String(format: "%.1fkm", heightMeters / 1000)
        }
        return "\(Int(heightMeters))m"
    }

    var body: some View {
        Text(meterLabel)
            .font(Typography.caption)
            .foregroundStyle(Color.primary.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
    }
}
