import Foundation

/// Which day a screen is showing.
///
/// A route rather than the album itself, so the day screen fetches its own
/// logs and does not depend on what the grid happens to have paged in.
struct DayRoute: Hashable {
    let dateString: String
}
