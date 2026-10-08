import Foundation

/// **Where a person reaches the owner, in one place** (2026-10-08).
///
/// The address was written straight into Settings' mailto link. It is still
/// his own inbox for now, the one the privacy page already publishes; when a
/// role address exists it changes here, and the privacy page and
/// `PrivacyPolicyView` change with it (those two are the owner's to edit).
///
/// A message arrives with a subject and a footer that says which build and
/// which phone, because "it crashed" with no version is a reply asking for
/// the version. Nothing personal goes in: no name, no account, no wins.
nonisolated enum Support {
    static let address = "jbett5@hotmail.com"
    static let subject = "Some Wins feedback"

    /// Info.plist key for the App Store's numeric app ID, once there is one.
    static let appStoreIDKey = "SomeWinsAppStoreID"

    /// The footer under the space a person writes in.
    static func footer(version: String, build: String, model: String, system: String) -> String {
        "\n\n\nSome Wins \(version) (\(build))\n\(model), iOS \(system)"
    }

    /// The footer for this build on this phone.
    static var currentFooter: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return footer(version: info["CFBundleShortVersionString"] as? String ?? "",
                      build: info["CFBundleVersion"] as? String ?? "",
                      model: deviceModel(),
                      system: "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)")
    }

    /// A mailto with the subject and body filled in, every character escaped.
    static func mailtoURL(address: String = address, subject: String = subject, body: String) -> URL? {
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = address
        c.queryItems = [URLQueryItem(name: "subject", value: subject),
                        URLQueryItem(name: "body", value: body)]
        return c.url
    }

    /// The machine identifier ("iPhone17,1"), never the name the person gave
    /// the phone.
    static func deviceModel() -> String {
        var machine = utsname()
        uname(&machine)
        return withUnsafeBytes(of: &machine.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    // MARK: - The App Store

    /// **The review page itself, not `requestReview`** (2026-10-08). A
    /// button that calls `requestReview` does nothing once iOS has shown the
    /// prompt its three times a year, so "Rate on App Store" was a row that
    /// sometimes did nothing at all. Nil until the ID is in Info.plist, and
    /// Settings hides the row while it is.
    static func reviewURL(appStoreID: String?) -> URL? {
        guard let id = appStoreID?.trimmingCharacters(in: .whitespaces),
              !id.isEmpty, id.allSatisfy(\.isASCII), id.allSatisfy(\.isNumber) else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(id)?action=write-review")
    }

    static var appStoreID: String? {
        switch Bundle.main.infoDictionary?[appStoreIDKey] {
        case let s as String: s
        case let n as NSNumber: n.stringValue
        default: nil
        }
    }
}

/// **The one review prompt the app raises by itself** (2026-10-08).
///
/// Apple shows `requestReview` at most three times a year and decides itself
/// whether to show it at all, so the app's job is only to ask at a moment
/// that is honest: somebody who has used it on several days, a calm screen,
/// never on the day they installed it (which is also the day of onboarding
/// and of the first win), and never twice for the same version.
nonisolated enum ReviewAsk {
    static let firstDayKey = "review.firstDay"
    static let askedVersionKey = "review.askedVersion"
    static let minimumWins = 5
    static let minimumDays = 3

    /// The whole rule. Days are `yyyy-MM-dd` keys, so they compare as dates.
    static func shouldAsk(wins: Int, winDays: Int, firstDay: String?, today: String,
                          askedVersion: String?, version: String, calm: Bool) -> Bool {
        guard calm, let firstDay, firstDay < today, askedVersion != version else { return false }
        return wins >= minimumWins && winDays >= minimumDays
    }

    /// The gates that need no fetch, checked first so the store is only
    /// asked when the answer could be yes.
    static func mayAsk(firstDay: String?, today: String, askedVersion: String?, version: String) -> Bool {
        guard let firstDay else { return false }
        return firstDay < today && askedVersion != version
    }

    /// The first day the app was opened, written once.
    static func noteLaunch(today: String, defaults: UserDefaults = .standard) {
        if defaults.string(forKey: firstDayKey) == nil { defaults.set(today, forKey: firstDayKey) }
    }

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
}
