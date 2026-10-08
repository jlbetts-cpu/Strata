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

    /// **Crews need iOS 26** (the owner, 2026-10-08). The Declared Age Range
    /// API the age rule rests on exists only there, and below it the age was
    /// quietly stored as "declined" and crews opened anyway. The deployment
    /// target stays iOS 18 for everything else in the app.
    static var osSupportsCrews: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    /// On, and on a phone that can run them: what may touch the network
    /// (`SocialStore.isEnabled` reads this). The Crews button still reads
    /// `isOn`, so a phone below iOS 26 is told why rather than shown nothing.
    static var isUsable: Bool { isOn && osSupportsCrews }

    static func isOn(in defaults: UserDefaults, arguments: [String]) -> Bool {
        if let i = arguments.firstIndex(of: "-strataCrews"), i + 1 < arguments.count {
            return arguments[i + 1] == "1"
        }
        return defaults.bool(forKey: key)
    }
}
