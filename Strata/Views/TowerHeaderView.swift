import SwiftUI

struct TowerHeaderView: View {
    let completedCount: Int
    let totalCount: Int
    let altimeterHeight: Double
    let showAltimeter: Bool
    let onGearTap: () -> Void
    @Binding var filterMode: TowerFilterMode
    @ScaledMetric(relativeTo: .body) private var gearIconSize: CGFloat = GridConstants.iconToolbar
    private let hPad: CGFloat = GridConstants.horizontalPadding

    private var dateString: String {
        Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private var progressText: String {
        "\(completedCount) of \(totalCount) today"
    }

    private var progressFraction: CGFloat {
        guard totalCount > 0 else { return 0 }
        return CGFloat(completedCount) / CGFloat(totalCount)
    }

    private var altimeterLabel: String {
        if altimeterHeight < 1 { return "0m" }
        if altimeterHeight >= 1000 {
            return String(format: "%.1fkm", altimeterHeight / 1000)
        }
        return "\(Int(altimeterHeight))m"
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                // Row 1: Date (left) + Filter pill + Gear (right)
                HStack(spacing: 12) {
                    Text(dateString)
                        .font(Typography.headerMedium)
                        .kerning(Typography.headerKerning)
                        .foregroundStyle(.primary)

                    Spacer()

                    TowerFilterMenuButton(selection: $filterMode)

                    Button {
                        HapticsEngine.lightTap()
                        onGearTap()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: gearIconSize, weight: .regular))
                            .foregroundStyle(Color.primary.opacity(0.4))
                    }
                }

                // Row 2: Progress text + bar (left) + altimeter (right)
                HStack(spacing: 8) {
                    Text(progressText)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)

                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 60, height: 4)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(AppColors.healthGreen)
                                .frame(width: 60 * progressFraction)
                                .animation(GridConstants.progressFill, value: progressFraction)
                        }

                    Spacer()

                    if showAltimeter {
                        Text(altimeterLabel)
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                            .animation(GridConstants.crossFade, value: altimeterLabel)
                    }
                }
            }
            .padding(.horizontal, hPad)
            .padding(.top, GridConstants.headerTopPadding)
            .padding(.bottom, GridConstants.headerBottomPadding)

            // Hairline divider matching ScheduleTimelineView
            Rectangle()
                .fill(Color.primary.opacity(GridConstants.headerDividerOpacity))
                .frame(height: GridConstants.headerDividerHeight)
        }
    }
}
