import SwiftUI

/// Time-of-day greeting card that orients ADHD users on app open.
/// Shows habit count + first scheduled habit. Auto-dismisses after first completion.
/// Research: Brown 2005 (Activation barrier), Barkley 2015 (time blindness),
/// Aaker & Lee 2001 (time-of-day framing effects), Fogg 2020 (behavior-anchored dismissal).
struct MorningBriefingCard: View {
    let habitCount: Int
    let completedCount: Int
    let firstHabitName: String?
    let firstHabitTime: String?
    let currentHour: Int

    @Environment(\.colorScheme) private var colorScheme

    // Time-of-day icon + greeting (Barkley 2015: compensate time blindness)
    private var timeOfDayIcon: String {
        switch currentHour {
        case 6..<12: return "sun.max.fill"
        case 12..<18: return "cloud.sun.fill"
        default: return "moon.stars.fill"
        }
    }

    private var iconColor: Color {
        switch currentHour {
        case 6..<12: return Color(red: 0.992, green: 0.710, blue: 0.310) // Focus yellow #FDB54F
        case 12..<18: return Color(red: 0.251, green: 0.663, blue: 1.0)  // Work blue #40A9FF
        default: return Color(red: 0.686, green: 0.612, blue: 0.980)     // Creativity purple #AF9CFA
        }
    }

    private var greeting: String {
        switch currentHour {
        case 6..<12: return "Good morning!"
        case 12..<18: return "Good afternoon!"
        default: return "Good evening!"
        }
    }

    private var detail: String {
        let remaining = habitCount - completedCount

        // Afternoon valley nudge (Kleitman 1982: ultradian rhythm dip)
        if completedCount > 0 && currentHour >= 14 {
            return "Energy dip? Try your easiest habit next."
        }

        // Afternoon/evening with some done (Aaker & Lee 2001: promotion framing)
        if completedCount > 0 {
            return "\(completedCount) of \(habitCount) on track. Keep going!"
        }

        // Morning with first habit info
        if let name = firstHabitName, let time = firstHabitTime {
            return "\(remaining) habits today · \(name) is first at \(time)"
        }

        return "\(remaining) habits to complete today"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: timeOfDayIcon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(iconColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(Typography.headerSmall)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(Typography.bodySmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous))
        .shadow(
            color: .black.opacity(GridConstants.shadowOpacity),
            radius: GridConstants.shadowRadius,
            y: GridConstants.shadowY
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(greeting) \(detail)")
    }
}
