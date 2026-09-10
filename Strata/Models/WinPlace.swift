import Foundation

/// Where a win happened.
///
/// A plain value with no CoreLocation in it, so everything downstream — the
/// clustering, its tests, the map's own maths — works on numbers and needs no
/// framework and no device. `LocationService` is the only thing that speaks
/// `CLLocation`, and it converts at the boundary.
///
/// `accuracy` travels with the pair because a coordinate on its own cannot say
/// how much to believe it. A reduced-accuracy fix is good to one to five
/// kilometres, and the map has to be able to refuse to draw a block that is
/// vaguer than the ground it would sit on.
struct WinPlace: Equatable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double
    /// Horizontal accuracy in metres. Nil when it was never recorded.
    let accuracy: Double?

    init(latitude: Double, longitude: Double, accuracy: Double? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.accuracy = accuracy
    }

    /// The pair off a log, or nil if it has none. One place that knows the
    /// three columns belong together.
    init?(latitude: Double?, longitude: Double?, accuracy: Double?) {
        guard let latitude, let longitude else { return nil }
        self.latitude = latitude
        self.longitude = longitude
        self.accuracy = accuracy
    }
}
