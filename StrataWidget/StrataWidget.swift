import SwiftUI
import WidgetKit

/// The tower, on the home screen.
///
/// **This is the loop the app was missing.** Strata is retrospective: it asks
/// you to record something you have already finished, which is a lovely idea
/// and a fragile habit, because nothing in your day reminds you to do it. A
/// to-do list nags by existing. A tower does not — unless you can see it
/// without opening anything.
///
/// It draws from `WidgetSnapshot`, which the app writes. No SwiftData here and
/// no photographs: a widget gets a few tens of megabytes and a few hundred
/// milliseconds, and the point of the snapshot is that every decision was
/// already made in the app.
struct StrataWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StrataTower", provider: TowerProvider()) { entry in
            TowerWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { WidgetGround() }
        }
        .configurationDisplayName("Your Tower")
        .description("How much you have stacked up, without opening the app.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct TowerEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// **One entry, and no schedule of its own.**
///
/// The app calls `WidgetCenter.reloadAllTimelines()` when the snapshot
/// actually changes, which is the only moment this can be wrong. Asking for a
/// refresh every fifteen minutes would spend the widget's budget redrawing a
/// tower nobody added to, and WidgetKit answers that by throttling — which is
/// how widgets end up stale. The `.after` date is only a long backstop so a
/// day boundary eventually moves "today" even if the app is never opened.
struct TowerProvider: TimelineProvider {
    func placeholder(in context: Context) -> TowerEntry {
        TowerEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (TowerEntry) -> Void) {
        let snapshot = context.isPreview ? .preview : WidgetSnapshot.read()
        completion(TowerEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TowerEntry>) -> Void) {
        let entry = TowerEntry(date: Date(), snapshot: WidgetSnapshot.read())
        let tomorrow = Calendar.current.nextDate(
            after: Date(), matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(tomorrow)))
    }
}

@main
struct StrataWidgetBundle: WidgetBundle {
    var body: some Widget {
        StrataWidget()
    }
}
