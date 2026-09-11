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
            TowerWidgetView(snapshot: entry.snapshot, photoIndex: entry.photoIndex)
                .containerBackground(for: .widget) { WidgetGround() }
        }
        .configurationDisplayName("Today")
        .description("Todays wins, and what they looked like.")
        // **Small and the lock screen only.** The medium size was built and then
        // looked at: "i think the medium one is unnessasary the small one is
        // perfect enough." It is right — a tower is a tall object, and a wide
        // box either leaves half of itself empty or spreads the blocks out
        // until they stop reading as a stack.
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

struct TowerEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    /// Which of today's photographs this entry shows.
    var photoIndex: Int = 0
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

    /// **Cycling is a timeline, not an animation.** A widget cannot animate on
    /// its own — it renders at moments the system chooses. So one entry per
    /// photograph is handed over at once, already decided, and iOS draws them
    /// in turn without waking the app at all. Entries are free; a refresh
    /// REQUEST is what gets throttled, and this asks for none.
    func getTimeline(in context: Context, completion: @escaping (Timeline<TowerEntry>) -> Void) {
        let snapshot = WidgetSnapshot.read()
        let now = Date()
        let midnight = Calendar.current.nextDate(
            after: now, matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime) ?? now.addingTimeInterval(3600)

        let count = snapshot.photos.count
        guard count > 1 else {
            completion(Timeline(entries: [TowerEntry(date: now, snapshot: snapshot)],
                                policy: .after(midnight)))
            return
        }

        // Long enough that it is a slideshow rather than a flicker, short
        // enough that a glance an hour later shows something different.
        let dwell: TimeInterval = 15 * 60
        var entries: [TowerEntry] = []
        for step in 0..<min(count * 2, 16) {
            let date = now.addingTimeInterval(Double(step) * dwell)
            guard date < midnight else { break }
            entries.append(TowerEntry(date: date, snapshot: snapshot,
                                      photoIndex: step % count))
        }
        if entries.isEmpty {
            entries = [TowerEntry(date: now, snapshot: snapshot)]
        }
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }
}

@main
struct StrataWidgetBundle: WidgetBundle {
    var body: some Widget {
        StrataWidget()
    }
}
