import SwiftUI

/// Calendar heatmap of completion density over the selected range.
///
/// Positive-only by design: a day with nothing done is an empty track, never a
/// red mark. Intensity encodes completion rate through *lightness*, not hue, so
/// the scale survives greyscale and colour-blind viewing (WCAG 1.4.1 — the
/// information is not carried by colour alone). Every cell carries a VoiceOver
/// label with the underlying counts.
struct MomentumHeatmap: View {
    let days: [InsightsDay]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    private let cellSpacing: CGFloat = 4
    private let cellRadius: CGFloat = 4

    private var weekdaySymbols: [String] {
        Calendar.current.veryShortWeekdaySymbols
    }

    /// Blank cells so the first day sits under its real weekday column.
    private var leadingBlanks: Int {
        guard let first = days.first else { return 0 }
        return Calendar.current.component(.weekday, from: first.date) - 1
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: cellSpacing), count: 7)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Weekday header
            LazyVGrid(columns: columns, spacing: cellSpacing) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(Typography.caption2)
                        .foregroundStyle(Color.primary.opacity(0.4))
                }
            }
            .accessibilityHidden(true)

            LazyVGrid(columns: columns, spacing: cellSpacing) {
                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }
                ForEach(days) { day in
                    HeatCell(day: day, radius: cellRadius, revealed: hasAppeared)
                }
            }
        }
        .onAppear {
            guard !hasAppeared else { return }
            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation(GridConstants.progressFill) { hasAppeared = true }
            }
        }
    }
}

// MARK: - Cell

private struct HeatCell: View {
    let day: InsightsDay
    let radius: CGFloat
    let revealed: Bool

    @Environment(\.colorScheme) private var colorScheme

    private static let labelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()

    /// Lightness ramp — 0.22 floor so a single completion is still visible.
    private var fillOpacity: Double {
        guard day.completed > 0 else { return 0 }
        return 0.22 + (day.completionRate * 0.78)
    }

    private var trackOpacity: Double {
        colorScheme == .dark ? 0.10 : 0.06
    }

    private var accessibilityLabel: String {
        let dateStr = Self.labelFormatter.string(from: day.date)
        guard day.scheduled > 0 else { return "\(dateStr), nothing scheduled" }
        var parts = ["\(day.completed) of \(day.scheduled) completed"]
        if day.skipped > 0 { parts.append("\(day.skipped) skipped") }
        return "\(dateStr), " + parts.joined(separator: ", ")
    }

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Color.primary.opacity(day.scheduled > 0 ? trackOpacity : trackOpacity * 0.5))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                // Completed density
                if day.completed > 0 {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(AppColors.healthGreen.opacity(revealed ? fillOpacity : 0))
                }
                // Handled-but-not-completed reads as a neutral mark, never a failure
                else if day.skipped > 0 {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(Color.primary.opacity(revealed ? 0.18 : 0))
                }
            }
            .overlay {
                if day.isToday {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(Color.primary.opacity(0.45), lineWidth: 1.5)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(day.isToday ? .isSelected : [])
    }
}
