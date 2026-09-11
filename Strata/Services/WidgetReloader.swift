import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Asks the home screen to redraw.
///
/// Wrapped rather than called directly so the app still builds and runs on a
/// checkout where the widget extension has not been added — `WidgetKit` is
/// available on iOS regardless, but keeping the dependency in one file means
/// there is exactly one place to look when the widget stops updating.
enum WidgetReloader {
    static func reload() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
