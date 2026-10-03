import Foundation

/// Crews, on or off. **Off by default**, and off means no button, no
/// checkboxes, no subscription, no network call and no zone.
///
/// It stays off for everyone until the safety and privacy pass in the spec
/// (section 9) has landed. `-strataCrews 1` turns it on for a run.
nonisolated enum CrewsFlag {
    static let key = "crewsEnabled"

    static var isOn: Bool {
        isOn(in: .standard, arguments: ProcessInfo.processInfo.arguments) || isTestFlight
    }

    /// **On in TestFlight builds, so the owner can try crews with friends**
    /// (2026-10-02), and only there: an App Store build stays dark until the
    /// spec's section 9 is done. A TestFlight install carries a sandbox
    /// receipt; an App Store one does not, and nor does a debug run.
    static let isTestFlight: Bool = {
        #if DEBUG
        return false
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }()

    static func isOn(in defaults: UserDefaults, arguments: [String]) -> Bool {
        if let i = arguments.firstIndex(of: "-strataCrews"), i + 1 < arguments.count {
            return arguments[i + 1] == "1"
        }
        return defaults.bool(forKey: key)
    }
}
