import CoreLocation
import Foundation

/// What a coordinate is CALLED.
///
/// A map full of blocks is a map of places, and a place with no name is a
/// coordinate. "12 here" is a count; "Trafalgar Square" is an answer — and it
/// is the difference between a screen that shows you your data and one that
/// tells you something about your life.
///
/// **`CLGeocoder`, not `MKReverseGeocodingRequest`.** The modern API is iOS 26
/// and the deployment target is 18.0. `CLGeocoder` has been here since iOS 5,
/// does the same job, and is the only version that runs on the phone in the
/// owner's pocket.
///
/// **Everything about this is best-effort.** It is a network call: it needs a
/// connection, Apple rate-limits it hard (roughly one request at a time, and
/// it will refuse a burst outright), and it can simply fail. So nothing waits
/// on it and nothing breaks without it — a name is something a screen GAINS,
/// never something it needs. Every caller renders correctly with `nil`.
@Observable
@MainActor
final class PlaceNames {

    static let shared = PlaceNames()

    /// Answers already known, so opening the same place twice is free and so a
    /// list of photographs from one afternoon makes one request rather than
    /// forty. Keyed to about 100m, which is the accuracy the app captures at —
    /// a finer key would miss on two photographs of the same café.
    private var known: [String: String] = [:]
    private var asking: Set<String> = []
    private let geocoder = CLGeocoder()

    /// The name, if it is already known. Never blocks, never fetches.
    func name(for place: WinPlace) -> String? { known[Self.key(for: place)] }

    /// Ask for a name, if nobody has. Safe to call from `.task` on every
    /// appearance — a repeat is a dictionary lookup.
    func resolve(_ place: WinPlace) async {
        let key = Self.key(for: place)
        guard known[key] == nil, !asking.contains(key) else { return }
        asking.insert(key)
        defer { asking.remove(key) }

        let location = CLLocation(latitude: place.latitude, longitude: place.longitude)
        guard let marks = try? await geocoder.reverseGeocodeLocation(location),
              let mark = marks.first,
              let name = Self.label(from: mark) else { return }
        known[key] = name
    }

    /// **The most specific thing that is still a place.**
    ///
    /// `name` is the building or landmark — "Trafalgar Square", "Tate Modern" —
    /// and is what somebody would actually say. But CoreLocation also puts the
    /// street NUMBER in there when there is nothing better ("42 Charing Cross
    /// Road"), and a house number is an address, not a memory. So a `name`
    /// that is merely the number plus the street is stepped over in favour of
    /// the street, then the neighbourhood, then the town.
    static func label(from mark: CLPlacemark) -> String? {
        if let name = mark.name,
           !name.isEmpty,
           name != [mark.subThoroughfare, mark.thoroughfare]
               .compactMap({ $0 }).joined(separator: " ") {
            return name
        }
        return mark.thoroughfare ?? mark.subLocality ?? mark.locality
            ?? mark.administrativeArea ?? mark.country
    }

    /// About 100m — the accuracy the app captures at. Two photographs of the
    /// same café must land on the same key or they ask twice and disagree.
    static func key(for place: WinPlace) -> String {
        String(format: "%.3f,%.3f", place.latitude, place.longitude)
    }
}
