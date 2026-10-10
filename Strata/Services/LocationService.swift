import CoreLocation
import UIKit
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

    /// Whether the person wants their photographs placed at all.
    ///
    /// Separate from the system permission on purpose: iOS answers "may this
    /// app know where you are", and this answers "do you want that written
    /// onto your wins". Somebody can reasonably say yes to the first and no to
    /// the second, and making them revoke a system permission to express it
    /// would be the app refusing to take an answer.
    static let defaultsKey = "remembersPlaces"

    /// The switch above, read wherever a place is about to be attached.
    var remembersPlaces: Bool {
        UserDefaults.standard.object(forKey: Self.defaultsKey) as? Bool ?? true
    }

    /// The most recent fix, whenever it arrived.
    private(set) var latest: CLLocation?
    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    /// Whether iOS is giving us a real position or a fuzzed one — see
    /// `fix(maxAge:maxAccuracy:)`.
    private(set) var isPrecise = true

    private let manager = CLLocationManager()
    /// Who wants updates running. The camera pre-warms for as long as it is
    /// open; the map's recentre button starts them too, and until 2026-09-15
    /// nothing on the map ever stopped them, so one tap left location running
    /// until the camera happened to be opened and closed. Each holder releases
    /// only its own claim, so the map leaving cannot stop a camera that has
    /// just appeared (the order of the two tabs' appear and disappear is not
    /// promised).
    private var holders: Set<String> = []
    private var isRunning: Bool { !holders.isEmpty }
    /// When the updates now running began, or nil when none are.
    private var runningSince: Date?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // Ten metres. Standing still should not produce a stream of updates,
        // and moving across a room is not moving to a new place.
        manager.distanceFilter = 10
        authorization = manager.authorizationStatus
        isPrecise = manager.accuracyAuthorization == .fullAccuracy
        // **"Running" means fixes are arriving** (found 2026-10-10 by the
        // second review). The camera is a tab, so leaving the app never
        // released its hold; iOS delivers nothing in the background; and a
        // fix from before then stayed "current" for ever, pinning a photo
        // taken across town to where the app was last open. The run starts
        // again each time the app comes forward, so a fix from before is
        // judged by its age like any other.
        let center = NotificationCenter.default
        center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.runningSince = nil }
        }
        center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isRunning else { return }
                self.runningSince = Date()
                // Started again, which always hands over a fix: standing
                // where you were, no movement would ever bring a new one.
                self.manager.stopUpdatingLocation()
                self.manager.startUpdatingLocation()
            }
        }
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
    func start(for holder: String = "camera") {
        guard !isDenied else { return }
        let wasRunning = isRunning
        holders.insert(holder)
        tuneAccuracy()
        if !wasRunning {
            runningSince = Date()
            manager.startUpdatingLocation()
        }
    }

    /// **Ten metres while the camera holds it, a hundred otherwise**
    /// (2026-10-09). A photo's pin came from a fix asked for at a hundred
    /// metres and up to two minutes old, so it could stand a block away or
    /// where you were before you walked. The camera is open for seconds at
    /// a time, so the finer fix costs little; the map keeps the coarse one.
    private func tuneAccuracy() {
        manager.desiredAccuracy = holders.contains("camera")
            ? kCLLocationAccuracyNearestTenMeters : kCLLocationAccuracyHundredMeters
    }

    func stop(for holder: String = "camera") {
        guard isRunning else { return }
        holders.remove(holder)
        // A start made by the permission arriving belongs to nobody in
        // particular; the first holder to leave releases it, as a stop always
        // did.
        holders.remove(Self.grantedHolder)
        if !isRunning {
            runningSince = nil
            manager.stopUpdatingLocation()
        } else {
            tuneAccuracy()
        }
    }

    private static let grantedHolder = "granted"

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
        guard Self.isCurrent(measured: latest.timestamp, now: Date(), maxAge: maxAge, runningSince: runningSince)
        else { return nil }
        guard latest.horizontalAccuracy > 0,
              latest.horizontalAccuracy <= maxAccuracy else { return nil }
        return latest
    }

    /// Whether a fix still says where the phone is.
    ///
    /// **A fix measured while updates have been running is current however
    /// old it is** (found 2026-10-10 by review). Updates only arrive after
    /// ten metres of movement (`distanceFilter`), so a phone standing still
    /// gets one fix and no more: with the camera's 30 second limit, framing
    /// a shot for half a minute without walking left the photo with no place
    /// at all. No newer fix while running means it has not moved. A fix from
    /// before the updates began (the system's cached one, handed over at the
    /// start) is still judged by its age.
    nonisolated static func isCurrent(measured: Date, now: Date, maxAge: TimeInterval, runningSince: Date?) -> Bool {
        if let runningSince, measured >= runningSince { return true }
        return now.timeIntervalSince(measured) <= maxAge
    }

    /// The same fix as a `WinPlace`, which is what everything downstream
    /// speaks. Nil for exactly the reasons `fix` returns nil.
    /// A fix no older than half a minute: one from before you walked
    /// somewhere is not where the photo was taken.
    func place(maxAge: TimeInterval = 30,
               maxAccuracy: CLLocationDistance = 200) -> WinPlace? {
        // The single gate. Every path that writes a coordinate onto a win goes
        // through here, so the preference is honoured once rather than at each
        // call site, where one of them would eventually be missed.
        guard remembersPlaces else { return nil }
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
                    // Fixes begin now, not when the camera asked for them.
                    self.runningSince = Date()
                    manager.startUpdatingLocation()
                } else {
                    self.start(for: Self.grantedHolder)
                }
            }
        }
    }
}
