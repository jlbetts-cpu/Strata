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
    // **Answered 2026-10-05:** logging from outside the app now goes through
    // `QuickLogIntent` (`Shared/`), a `LiveActivityIntent` in both targets
    // that the system performs in the APP's process, so this target still
    // never opens the store. See `LogWinWidgets.swift`. The note below is
    // kept for why it had to be done that way.
    //
    // **WHAT A TAP ON THIS WIDGET COSTS, measured 2026-10-01 rather than
    // guessed.** Nothing here is wired yet, and the sizing is the finding.
    //
    // **An in-place `Button(intent:)` is the thing worth having, and it is
    // not a small change.** Since iOS 17 a widget can run
    // an App Intent without opening anything, and this app has the intent
    // already: `LogWinIntent`, `openAppWhenRun = false`, through
    // `QuickWinService.logWin`. What it does not have is any way for the WIDGET
    // process to run it. The intent needs a `ModelContainer`, the container
    // needs the SwiftData schema, and the schema is eight `@Model` types in
    // `Strata/Models/`, which is the app target. The widget target sees
    // `StrataWidget/` and `Shared/` and nothing else, and that is not an
    // oversight: it is this widget's founding decision, written at the top of
    // this file as "No SwiftData here and no photographs: a widget gets a few
    // tens of megabytes and a few hundred milliseconds."
    //
    // **And the cheap half is not cheap either.** A `widgetURL` would at least
    // land the tap on the tower rather than wherever the app opens — it opens
    // on the camera by design — but **this app has no URL scheme at all**:
    // `CFBundleURLTypes` is absent from `Info.plist` and nothing calls
    // `onOpenURL`. So even that costs a scheme registered in both build
    // configurations and a handler, and a `widgetURL` added without them is a
    // link that silently does nothing, which is worse than the gap.
    //
    // Both numbers are the owner's to spend. Written here rather than in a
    // reply so the next person sizing this does not have to find it again.

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StrataTower", provider: TowerProvider()) { entry in
            TowerWidgetView(snapshot: entry.snapshot, photoIndex: entry.photoIndex)
                .containerBackground(for: .widget) {
                    TowerPhotoBackground(snapshot: entry.snapshot,
                                         photoIndex: entry.photoIndex)
                }
        }
        .configurationDisplayName("Today")
        .description("Today's wins, and what they looked like.")
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
/// how widgets end up stale. The `.after` date is the backstop that moves
/// "today" at midnight even if the app is never opened, by reading the
/// snapshot `asOf` the new day.
struct TowerProvider: TimelineProvider {
    func placeholder(in context: Context) -> TowerEntry {
        TowerEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (TowerEntry) -> Void) {
        let snapshot = context.isPreview ? .preview : WidgetSnapshot.read().asOf(Date())
        completion(TowerEntry(date: Date(), snapshot: snapshot))
    }

    /// **Cycling is a timeline, not an animation.** A widget cannot animate on
    /// its own — it renders at moments the system chooses. So one entry per
    /// photograph is handed over at once, already decided, and iOS draws them
    /// in turn without waking the app at all. Entries are free; a refresh
    /// REQUEST is what gets throttled, and this asks for none.
    func getTimeline(in context: Context, completion: @escaping (Timeline<TowerEntry>) -> Void) {
        let now = Date()
        // Read as of now: just after midnight this is what empties yesterday's
        // tower. See `WidgetSnapshot.asOf`.
        let snapshot = WidgetSnapshot.read().asOf(now)
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
        LogWinWidget()
        LogWinControl()
    }
}
