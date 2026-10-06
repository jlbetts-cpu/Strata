import Foundation
import LocalAuthentication
import Observation
import UIKit

/// **Lock Journal: Face ID, or the passcode, once a session.**
///
/// Off by default, switched on in Settings (spec section 2: "Settings has a
/// 'Lock Journal' switch, off by default, using Face ID or the passcode ... It
/// is asked once per app session before a note opens.").
///
/// `.deviceOwnerAuthentication`, not the biometrics-only policy: a phone
/// whose face is not recognised, or that has no Face ID, still opens with
/// its passcode, which is what the switch's words promise.
///
/// **A session ends when the app goes to the background.** The process can
/// live for days behind the home screen, and a phone handed to somebody else
/// with the journal unlocked since Tuesday is not what the switch is for. The
/// Face ID sheet itself only makes the app inactive, never backgrounded, so
/// it does not undo its own answer.
///
/// **A phone with no passcode at all opens without asking.** There is nothing
/// to check against, and refusing would lock a person out of their own notes
/// with no way back in.
///
/// **Locked means locked everywhere, not only at the sheet** (the cohesion
/// pass, 2026-10-05). While it is locked the calendar shows no emoji and
/// marks no day as written, the journal button does not tell VoiceOver
/// "Written", and the app-switcher snapshot is covered. Observable, so all
/// of those come back the moment the journal is opened.
@MainActor
@Observable
final class JournalLock {
    static let shared = JournalLock()

    /// The Settings switch's key.
    nonisolated static let defaultsKey = "journalLocked"

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let authenticate: @MainActor () async -> Bool
    private(set) var isUnlocked = false
    /// Face ID or the passcode is on screen. The app is inactive under it,
    /// and the snapshot cover must not come up over the thing asking.
    private(set) var isAsking = false
    @ObservationIgnored private var token: NSObjectProtocol?

    init(defaults: UserDefaults = .standard,
         authenticate: (@MainActor () async -> Bool)? = nil) {
        self.defaults = defaults
        self.authenticate = authenticate ?? JournalLock.deviceOwner
        token = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.relock() }
        }
    }

    /// Whether the Settings switch is on.
    var isOn: Bool { defaults.bool(forKey: Self.defaultsKey) }

    /// True when a note may open: the lock is off, already answered this
    /// session, or answered now.
    func unlock() async -> Bool {
        guard isOn, !isUnlocked else { return true }
        isAsking = true
        defer { isAsking = false }
        let passed = await authenticate()
        if passed { isUnlocked = true }
        return passed
    }

    /// Whether the lock may come off. It could be switched off in Settings
    /// without asking, which made it a lock anyone holding the phone could
    /// open (found 2026-10-06). Called after the switch has gone off, so it
    /// does not read `isOn`: already unlocked this session, or asked now.
    func mayTurnOff() async -> Bool {
        guard !isUnlocked else { return true }
        isAsking = true
        defer { isAsking = false }
        let passed = await authenticate()
        if passed { isUnlocked = true }
        return passed
    }

    /// The session is over: the next note asks again.
    func relock() { isUnlocked = false }

    /// What the journal holds is hidden: the switch is on and this session
    /// has not opened it. `isOn` is read from the defaults, which nothing
    /// observes, so a view also reads the switch through `@AppStorage`.
    var hidesWriting: Bool { isOn && !isUnlocked }

    /// The real check.
    private static func deviceOwner() async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No passcode set: nothing to check against. See the type's note.
            return error?.code == LAError.passcodeNotSet.rawValue
        }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication,
                                                  localizedReason: "Open your journal")) ?? false
    }
}
