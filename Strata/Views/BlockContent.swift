import SwiftUI

/// The two things every block view shares: how a time is written, and what is
/// drawn on the face.
///
/// They used to live in `HabitBlockView.swift` alongside a block view that only
/// `TowerView` rendered — and `TowerView` was referenced by nothing. Deleting
/// the dead view would have taken these with it, so they moved here first.
/// `FlippableBlockView` (the one the tower actually renders) and
/// `TowerViewModel` both depend on them.

// MARK: - Time Formatting Helpers

enum BlockTimeFormatter {
    /// Computes end time from a start "HH:mm" string + duration in minutes.
    static func endTime(_ startStr: String, durationMinutes: CGFloat) -> String {
        let parts = startStr.split(separator: ":")
        guard !parts.isEmpty, let h = Int(parts[0]) else { return startStr }
        let m = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        let totalMinutes = h * 60 + m + Int(durationMinutes)
        let endH = (totalMinutes / 60) % 24
        let endM = totalMinutes % 60
        return String(format: "%02d:%02d", endH, endM)
    }

    /// Converts "14:00" → "2 PM", "14:30" → "2:30 PM"
    static func format12Hour(_ timeStr: String) -> String {
        let parts = timeStr.split(separator: ":")
        guard !parts.isEmpty, let h = Int(parts[0]) else { return timeStr }
        let m = parts.count > 1 ? String(parts[1]) : "00"
        let period = h < 12 ? "AM" : "PM"
        let hour12 = h % 12 == 0 ? 12 : h % 12
        return m == "00" ? "\(hour12) \(period)" : "\(hour12):\(m) \(period)"
    }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let localeTimeFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        return fmt
    }()

    /// Formats a Date using the user's locale (e.g. "3:30 PM" or "15:30")
    static func format12Hour(_ date: Date) -> String {
        localeTimeFormatter.string(from: date)
    }

    /// Returns a single timestamp for a block: completion time if available, otherwise scheduled start.
    static func timeRange(scheduledTime: String?, durationMinutes: CGFloat, completedAt: Date?) -> String? {
        if let completed = completedAt {
            return format12Hour(completed)
        } else if let time = scheduledTime {
            return format12Hour(time)
        }
        return nil
    }

    /// Converts "2026-03-19" → "3/19"
    static func dateLabel(from dateString: String) -> String {
        let parts = dateString.split(separator: "-")
        guard parts.count == 3,
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return dateString }
        return "\(month)/\(day)"
    }

    /// Returns the appropriate display text based on filter mode.
    /// Day → time range, Week/Month → date label.
    static func displayText(
        filterMode: TowerFilterMode,
        dateString: String,
        scheduledTime: String?,
        durationMinutes: CGFloat,
        completedAt: Date?
    ) -> String? {
        switch filterMode {
        case .day:
            return timeRange(scheduledTime: scheduledTime, durationMinutes: durationMinutes, completedAt: completedAt)
        case .week, .month:
            return dateLabel(from: dateString)
        }
    }
}


// MARK: - Shared Block Content Overlay

struct BlockContentOverlay: View {
    let title: String
    let category: HabitCategory
    let rowSpan: Int
    let timeText: String?
    var hasImage: Bool = false

    /// A block nobody has named carries no text at all — no title, no time.
    ///
    /// "Win" is not a name, it is the absence of one, and a block that says it
    /// is louder than the thing it describes. Its presence already says "this
    /// happened"; a label repeating that is the only part of it that could be
    /// wrong. Naming it in the card gives it its text.
    private var isUnnamed: Bool {
        Self.isUnnamed(title)
    }

    /// Shared so the block view can ask the same question before deciding
    /// whether a photograph needs a veil under text that is not there.
    static func isUnnamed(_ title: String) -> Bool {
        title == QuickWinService.untitled || title.isEmpty
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // No icon on the block.
            //
            // The colour already says which category it is, and the icon was
            // repeating that in the one place where two same-coloured blocks
            // are trying to look like one object — a corner mark halfway down a
            // merged shape is the clearest possible statement that it is two.
            // Icons still name categories where the colour alone cannot: the
            // picker, the timeline rows, the plan list.

            VStack(alignment: .leading, spacing: 2) {
                Spacer()
                if !isUnnamed {
                    Text(title)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        // One size on every block, and an ellipsis when it
                        // does not fit.
                        //
                        // `minimumScaleFactor` shrank the type to fit, so a
                        // tower of ten blocks could carry six different text
                        // sizes and the size read as emphasis nobody had
                        // chosen — the shortest title looked the most
                        // important. Truncation is honest: same size
                        // everywhere, and the ones that run long say so.
                        .lineLimit(rowSpan > 1 ? 2 : 1)
                        .truncationMode(.tail)
                        // On a photo the scrim is a light veil now, so the type
                        // carries its own contrast instead of the block being
                        // darkened until anything would be legible on it.
                        .shadow(color: .black.opacity(hasImage ? 0.55 : 0), radius: 3, x: 0, y: 1)

                    // No time on the block.
                    //
                    // A tower of a dozen blocks was a dozen timestamps nobody
                    // reads — the same information twelve times, in the one
                    // place the app is meant to be a picture rather than a
                    // log. What a block says is what you did; when you did it
                    // is on the card if you ever want it.
                }
            }
            .frame(maxWidth: .infinity, alignment: .bottomLeading)
            .padding(.leading, 12)
            .padding(.bottom, 12)
            .padding(.trailing, 8)
        }
    }
}
