import Foundation

/// View mode for the Today screen — List (default) or Timeline (Google Calendar-style).
/// Research: Norman 2004 (mode switching should be instant + labeled).
enum TodayViewMode: String, CaseIterable {
    case list = "List"
    case timeline = "Timeline"
}
