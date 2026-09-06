import SwiftUI

/// One habit's momentum: category identity, current run, trailing 7 days, rate.
///
/// The trailing strip is positive-only — a scheduled day that went unresolved is
/// an empty track, not a red mark (coordination.md, Tower principles: no shame
/// signalling). Category is encoded by icon *and* colour, never colour alone
/// (brand.md — Treisman 1980, WCAG 1.4.1).
struct HabitMomentumRow: View {
    let momentum: HabitMomentum

    @ScaledMetric(relativeTo: .body) private var iconWell: CGFloat = 28
    @ScaledMetric(relativeTo: .caption2) private var pipSize: CGFloat = 8

    private var style: CategoryStyle { momentum.category.style }

    private var runLabel: String {
        momentum.currentRun == 1 ? "1 day" : "\(momentum.currentRun) days"
    }

    private var accessibilityLabel: String {
        var parts = ["\(momentum.title), \(momentum.category.rawValue.capitalized)"]
        if momentum.currentRun > 0 { parts.append("running \(runLabel)") }
        if momentum.scheduled > 0 {
            parts.append("\(momentum.completed) of \(momentum.scheduled) completed, \(Int(momentum.rate * 100)) percent")
        }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon + colour — redundant encoding
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(style.baseColor.opacity(0.15))
                Image(systemName: momentum.category.iconName)
                    .iconSize(GridConstants.iconCategory, relativeTo: .caption, weight: .medium)
                    .foregroundStyle(style.baseColor)
            }
            .frame(width: iconWell, height: iconWell)

            VStack(alignment: .leading, spacing: 4) {
                Text(momentum.title)
                    .font(Typography.bodyMedium)
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if momentum.currentRun > 0 {
                        Text(runLabel)
                            .font(Typography.caption)
                            .foregroundStyle(AppColors.healthGreen)
                        Text("·")
                            .font(Typography.caption)
                            .foregroundStyle(Color.primary.opacity(0.25))
                    }
                    Text(momentum.scheduled > 0 ? "\(momentum.completed)/\(momentum.scheduled)" : "not scheduled")
                        .font(Typography.caption)
                        .foregroundStyle(Color.primary.opacity(0.5))
                }
            }

            Spacer(minLength: 8)

            // Trailing 7 days, oldest first
            HStack(spacing: 3) {
                ForEach(Array(momentum.recent.enumerated()), id: \.offset) { _, mark in
                    Circle()
                        .fill(pipColor(for: mark))
                        .frame(width: pipSize, height: pipSize)
                }
            }
            .accessibilityHidden(true)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private func pipColor(for mark: DayMark) -> Color {
        switch mark {
        case .completed:   return AppColors.healthGreen
        case .skipped:     return Color.primary.opacity(0.22)
        case .open:        return Color.primary.opacity(0.08)
        case .unscheduled: return Color.primary.opacity(0.03)
        }
    }
}
