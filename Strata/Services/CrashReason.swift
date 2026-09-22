import Foundation
import os

/// Whatever handler was installed before ours, so nothing is swallowed.
private nonisolated(unsafe) var previousExceptionHandler: (@convention(c) (NSException) -> Void)?

/// **So the next Objective-C exception says what it was, on the next launch.**
///
/// The camera terminated on his phone inside `-[AVCaptureSession startRunning]`
/// and what came back was a screenshot of the thread list. The stack says
/// WHERE; only the exception's `reason` says WHAT, and that string is the
/// difference between a fix and a guess. Twice now the guess has cost a round
/// trip to a device only he has.
///
/// An `NSException` cannot be caught from Swift — it goes straight to
/// `std::terminate` — so the only moment it can be read is on the way out.
/// Writing it to `UserDefaults` there means it survives the death of the
/// process and is waiting at the next launch, where it is logged at fault
/// level. Xcode prints the reason too, in the console, but a console scrolls
/// and a screenshot of the debugger does not include it.
///
/// Installed from the app's initialiser, so it covers every screen rather than
/// only the one that crashed last time.
enum CrashReason {
    private static let log = Logger(subsystem: "JaydenBetts.Strata", category: "crash")
    private static let key = "lastUncaughtException"

    static func install() {
        if let stored = UserDefaults.standard.string(forKey: key) {
            UserDefaults.standard.removeObject(forKey: key)
            log.fault("previous launch died: \(stored, privacy: .public)")
        }
        previousExceptionHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler { exception in
            let name = exception.name.rawValue
            let reason = exception.reason ?? "no reason given"
            let frames = exception.callStackSymbols.prefix(12).joined(separator: " | ")
            UserDefaults.standard.set("\(name): \(reason) :: \(frames)",
                                      forKey: "lastUncaughtException")
            // Best effort: the process is already going down, and a
            // synchronous write is the only kind that can win the race.
            UserDefaults.standard.synchronize()
            CrashReason.report(name: name, reason: reason)
            previousExceptionHandler?(exception)
        }
    }

    /// Split out because the handler is a C function pointer and cannot close
    /// over anything, including a `Logger`.
    private static func report(name: String, reason: String) {
        log.fault("uncaught \(name, privacy: .public): \(reason, privacy: .public)")
    }
}
