import Foundation

/// Crews, on or off. **Off by default**, and off means no button, no
/// checkboxes, no subscription, no network call and no zone.
///
/// It stays off for everyone until the safety and privacy pass in the spec
/// (section 9) has landed. `-strataCrews 1` turns it on for a run.
nonisolated enum CrewsFlag {
    static let key = "crewsEnabled"

    static var isOn: Bool { isOn(in: .standard, arguments: ProcessInfo.processInfo.arguments) }

    static func isOn(in defaults: UserDefaults, arguments: [String]) -> Bool {
        if let i = arguments.firstIndex(of: "-strataCrews"), i + 1 < arguments.count {
            return arguments[i + 1] == "1"
        }
        return defaults.bool(forKey: key)
    }
}
