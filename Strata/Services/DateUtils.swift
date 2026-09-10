import Foundation

/// Shared date formatting utility — eliminates duplicate DateFormatter closures across the codebase.
/// Intent files and services use this directly; TimelineViewModel delegates to it.
/// `nonisolated`: it is called from `Task.detached` in `SpotlightIndexer`,
/// and default main-actor isolation would otherwise make that a Swift 6 error.
nonisolated enum DateUtils {
    private static let dateStringFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dateString(from date: Date) -> String {
        dateStringFormatter.string(from: date)
    }

    /// The inverse. Nil for anything that is not `yyyy-MM-dd`.
    static func date(from dateString: String) -> Date? {
        dateStringFormatter.date(from: dateString)
    }
}
