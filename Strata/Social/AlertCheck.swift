import Foundation
import UserNotifications

/// **Where a crew alert's path last stood, link by link** (the owner,
/// 2026-10-14: notifications set up, "did you ever finish ... and getting
/// those to work?", and he had never had one). Every link (the push
/// registration, the iCloud subscription, an alert written for friends)
/// failed only into a log nobody on a phone can read. This keeps the last
/// outcome of each, with the error's own words, for the TestFlight-only
/// Crew Alerts check in Settings (`AlertCheckSection`). Nothing is sent
/// anywhere; it is this phone's own note.
nonisolated enum AlertCheck {
    enum Link: String, CaseIterable {
        case push = "alerts.check.push"
        case listen = "alerts.check.listen"
        case send = "alerts.check.send"
    }

    struct Outcome: Equatable {
        let ok: Bool
        let detail: String
        let at: Date
    }

    static func note(_ link: Link, ok: Bool, _ detail: String = "", defaults: UserDefaults = .standard) {
        defaults.set(["ok": ok, "detail": String(detail.prefix(240)), "at": Date().timeIntervalSince1970] as [String: Any],
                     forKey: link.rawValue)
    }

    static func outcome(_ link: Link, defaults: UserDefaults = .standard) -> Outcome? {
        guard let kept = defaults.dictionary(forKey: link.rawValue),
              let ok = kept["ok"] as? Bool, let at = kept["at"] as? Double else { return nil }
        return Outcome(ok: ok, detail: kept["detail"] as? String ?? "", at: Date(timeIntervalSince1970: at))
    }
}

extension AlertCheck {
    /// In TestFlight builds and on the simulator; never in the App Store's.
    static var shown: Bool {
        #if DEBUG
        return true
        #else
        return CrewsFlag.isTestFlight
        #endif
    }
}
