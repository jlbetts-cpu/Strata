import AppIntents
import SwiftUI
import WidgetKit

// **Logging without opening the app** (the owner, 2026-10-05, from the
// research: the fastest log is the one that never opens the app). Both run
// `QuickLogIntent`, which is performed in the app's process, so nothing here
// touches the store.

/// Control Center, the Lock Screen and the Action button: one tap, one win,
/// the size a tap on the tower makes.
struct LogWinControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "JaydenBetts.Strata.LogWin") {
            // Hollow (the cohesion pass, 2026-10-05): `docs/research/
            // visual-cohesion.md` §4.3, "filled = selected, outline = not,
            // everywhere", and a control that adds a win is never "selected".
            ControlWidgetButton(action: LogQuickWinIntent()) {
                Label("Log a Win", systemImage: "plus.square")
            }
        }
        .displayName("Log a Win")
        .description("Adds a win to today's tower.")
    }
}

/// **The Log widget: the tower's empty slots, one for each size.** The same
/// dashed slot the tower and the Today widget's empty state invite you with,
/// in the three shapes a block comes in, packed as the tower packs them:
/// Deep on the left, Regular over Quick on the right. A tap drops that size
/// onto today's tower.
struct LogWinWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StrataLogWin", provider: LogWinProvider()) { entry in
            LogWinWidgetView(today: entry.today)
                .containerBackground(for: .widget) { WidgetGround() }
        }
        .configurationDisplayName("Log a Win")
        .description("Tap a size to add a win to today's tower.")
        .supportedFamilies([.systemSmall])
    }
}

struct LogWinEntry: TimelineEntry {
    let date: Date
    /// Today's wins, so a tap visibly counted (2026-10-06). The intent
    /// writes the snapshot before the widget redraws.
    var today: Int = 0
}

/// Nothing changes on this face, so one entry, for ever.
struct LogWinProvider: TimelineProvider {
    func placeholder(in context: Context) -> LogWinEntry { LogWinEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (LogWinEntry) -> Void) {
        completion(entry(context.isPreview ? 2 : nil))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<LogWinEntry>) -> Void) {
        // Redrawn by the intent after every log, and at midnight, when the
        // count goes back to nothing.
        let midnight = Calendar.current.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 1),
                                                 matchingPolicy: .nextTime) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry(nil)], policy: .after(midnight)))
    }
    private func entry(_ preview: Int?) -> LogWinEntry {
        LogWinEntry(date: Date(), today: preview ?? WidgetSnapshot.read().asOf(Date()).today)
    }
}

struct LogWinWidgetView: View {
    var today: Int = 0
    private let gap: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let cell = (geo.size.width - gap * 3) / 4
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Log a win")
                        .font(.system(size: 15, weight: .medium, design: .default))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    // Today's count, so a tap is seen to land.
                    if today > 0 {
                        Text("\(today)")
                            .font(.system(size: 15, weight: .semibold, design: .default))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText(value: Double(today)))
                            .widgetAccentable()
                            .accessibilityLabel("\(today) today")
                    }
                }
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: gap) {
                    slot(.deep, width: cell * 2 + gap, height: cell * 2 + gap)
                    VStack(alignment: .leading, spacing: gap) {
                        slot(.regular, width: cell * 2 + gap, height: cell)
                        // One cell drawn, two cells pressable: a Quick
                        // block is about 38pt here, under the 44pt a target
                        // should be, and the cell beside it is empty.
                        slot(.quick, width: cell, height: cell, hitWidth: cell * 2 + gap)
                    }
                }
            }
        }
    }

    private func slot(_ size: QuickLogSize, width: CGFloat, height: CGFloat,
                      hitWidth: CGFloat? = nil) -> some View {
        Button(intent: Self.intent(size)) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 1.4, dash: [3, 3]))
                    .foregroundStyle(.tertiary)
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: width, height: height)
            .frame(width: hitWidth ?? width, height: height, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log a \(size.rawValue) win")
    }

    private static func intent(_ size: QuickLogSize) -> any AppIntent {
        switch size {
        case .quick: LogQuickWinIntent()
        case .regular: LogRegularWinIntent()
        case .deep: LogDeepWinIntent()
        }
    }
}
