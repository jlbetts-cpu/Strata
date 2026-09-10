import CoreLocation
import Foundation

/// Where you were, for the photograph you just took.
///
/// One job: have a recent fix ready by the time the shutter fires, so nothing
/// ever waits on GPS. It is not a tracker — it runs only while the camera is
/// on screen, and it stops the moment you leave.
///
/// **Hundred-metre accuracy, not best.** A place is a café, a park, a street —
/// not a doorway. Asking for `kCLLocationAccuracyBest` turns a one-to-two
/// second fix into a five-to-ten second one and drains the battery for
/// precision the map throws away when it clusters.
///
/// **Nothing here blocks.** A win with no place is normal and always will be:
/// indoors, in aeroplane mode, on a simulator with no location set, or simply
/// before the first fix lands. The shutter never waits.
@Observable
@MainActor
final class LocationService: NSObject {

    /// One instance, for the same reason `ImageManager` and `SoundEngine` are
    /// singletons — and one specific one: a service recreated on every
    /// appearance never gets warm, and being warm is the entire point of it.
    /// It also keeps `CameraView`'s call site unchanged, which matters because
    /// `MainAppView.mainContent` is at the type-checker's ceiling and adding a
    /// parameter there has failed before.
    static let shared = LocationService()

    /// The most recent fix, whenever it arrived.
    private(set) var latest: CLLocation?
    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    /// Whether iOS is giving us a real position or a fuzzed one — see
    /// `fix(maxAge:maxAccuracy:)`.
    private(set) var isPrecise = true

    private let manager = CLLocationManager()
    private var isRunning = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // Ten metres. Standing still should not produce a stream of updates,
        // and moving across a room is not moving to a new place.
        manager.distanceFilter = 10
        authorization = manager.authorizationStatus
        isPrecise = manager.accuracyAuthorization == .fullAccuracy
    }

    /// Whether asking would show a prompt, so a caller can prime it first
    /// rather than springing a system alert on somebody.
    var canAsk: Bool { authorization == .notDetermined }

    /// Whether a fix could ever arrive. False once refused, and the screen
    /// that cares should say so rather than waiting forever.
    var isDenied: Bool {
        authorization == .denied || authorization == .restricted
    }

    func requestAccess() {
        guard canAsk else { return }
        manager.requestWhenInUseAuthorization()
    }

    /// Start warming up. Called when the camera appears.
    ///
    /// **Pre-warming is the whole design.** A cold fix takes seconds; a warm
    /// one is immediate. By the time you have framed a shot the answer has
    /// already arrived, so the shutter never has to wait for it and never has
    /// to show a spinner for it.
    func start() {
        guard !isRunning, !isDenied else { return }
        isRunning = true
        manager.startUpdatingLocation()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        manager.stopUpdatingLocation()
    }

    /// A fix good enough to pin a photograph to, or nil.
    ///
    /// Two filters, both of which exist to stop the map lying:
    ///
    /// **Age.** A fix from twenty minutes ago describes where you were, not
    /// where this photograph was taken. Two minutes is generous for a phone
    /// that has been in a pocket and mean enough to exclude a different place.
    ///
    /// **Accuracy.** With `.reducedAccuracy` — which a person can grant
    /// deliberately, and which is invisible unless you look — iOS returns a
    /// position good to one to five kilometres. Pinning a block to that puts
    /// it in the wrong neighbourhood, and an app that shows you a confident
    /// block in a place you have never been is worse than one that shows
    /// nothing.
    func fix(maxAge: TimeInterval = 120, maxAccuracy: CLLocationDistance = 200) -> CLLocation? {
        guard let latest else { return nil }
        guard -latest.timestamp.timeIntervalSinceNow <= maxAge else { return nil }
        guard latest.horizontalAccuracy > 0,
              latest.horizontalAccuracy <= maxAccuracy else { return nil }
        return latest
    }

    /// The same fix as a `WinPlace`, which is what everything downstream
    /// speaks. Nil for exactly the reasons `fix` returns nil.
    func place(maxAge: TimeInterval = 120,
               maxAccuracy: CLLocationDistance = 200) -> WinPlace? {
        guard let fix = fix(maxAge: maxAge, maxAccuracy: maxAccuracy) else { return nil }
        return WinPlace(latitude: fix.coordinate.latitude,
                        longitude: fix.coordinate.longitude,
                        accuracy: fix.horizontalAccuracy)
    }
}

extension LocationService: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in self.latest = last }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        // Silent on purpose. `kCLErrorLocationUnknown` is transient and
        // routine indoors, and a win with no place is a normal win.
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let precise = manager.accuracyAuthorization == .fullAccuracy
        Task { @MainActor in
            self.authorization = status
            self.isPrecise = precise
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                // Granted mid-session: start now rather than making somebody
                // leave the screen and come back.
                if self.isRunning {
                    manager.startUpdatingLocation()
                } else {
                    self.start()
                }
            }
        }
    }
}
