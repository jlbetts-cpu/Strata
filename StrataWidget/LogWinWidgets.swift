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
            ControlWidgetButton(action: LogQuickWinIntent()) {
                Label("Log a Win", systemImage: "plus.square.fill")
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
        StaticConfiguration(kind: "StrataLogWin", provider: LogWinProvider()) { _ in
            LogWinWidgetView()
                .containerBackground(for: .widget) { WidgetGround() }
        }
        .configurationDisplayName("Log a Win")
        .description("Tap a size to add a win to today's tower.")
        .supportedFamilies([.systemSmall])
    }
}

struct LogWinEntry: TimelineEntry { let date: Date }

/// Nothing changes on this face, so one entry, for ever.
struct LogWinProvider: TimelineProvider {
    func placeholder(in context: Context) -> LogWinEntry { LogWinEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (LogWinEntry) -> Void) {
        completion(LogWinEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<LogWinEntry>) -> Void) {
        completion(Timeline(entries: [LogWinEntry(date: Date())], policy: .never))
    }
}

struct LogWinWidgetView: View {
    private let gap: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let cell = (geo.size.width - gap * 3) / 4
            VStack(alignment: .leading, spacing: 0) {
                Text("Log a win")
                    .font(.system(size: 15, weight: .medium, design: .default))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: gap) {
                    slot(.deep, width: cell * 2 + gap, height: cell * 2 + gap)
                    VStack(alignment: .leading, spacing: gap) {
                        slot(.regular, width: cell * 2 + gap, height: cell)
                        slot(.quick, width: cell, height: cell)
                    }
                }
            }
        }
    }

    private func slot(_ size: QuickLogSize, width: CGFloat, height: CGFloat) -> some View {
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
