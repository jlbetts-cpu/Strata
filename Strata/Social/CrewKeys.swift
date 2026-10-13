import Foundation

/// **The invite link**: `https://somewins.xyz/join#<crew>.<key>`. Every form
/// is read here. A link without a valid crew and key is no invitation.
///
/// **The owner's own address since 2026-10-13** ("there shouldnt say github
/// in the link", 2026-10-10; the domain went live three days later). It was
/// `https://jlbetts-cpu.github.io/Strata/join.html`, which is still read
/// and which GitHub forwards to the new one.
///
/// **And a tap opens the app with no page in between** on a phone that has
/// it: the app is associated with the domain (`applinks:somewins.xyz` in
/// the entitlements, `docs/.well-known/apple-app-site-association` on the
/// site), so iPhone hands the link straight to
/// `StrataSceneDelegate.scene(_:continue:)`. Where that does not happen (a
/// link typed into Safari, a phone without the app) the page is still
/// there, and opens the app by its own scheme, `somewins://join#<crew>.<key>`.
/// Builds from 116 on read this address, so friends on an older build can
/// open a link this one sends.
nonisolated enum CrewInviteLink {
    static let page = "https://somewins.xyz/join"
    /// The other addresses the page answers at, or did.
    static let otherPages = ["https://somewins.xyz/join.html", "https://www.somewins.xyz/join",
                             "https://www.somewins.xyz/join.html",
                             "https://jlbetts-cpu.github.io/Strata/join.html",
                             "https://jlbetts-cpu.github.io/Strata/join"]
    /// The domain the app is associated with, as the entitlement spells it.
    static let appLinkDomain = "applinks:somewins.xyz"
    static let scheme = "somewins"

    static func url(crew: CrewID, key: CrewKey) -> URL {
        URL(string: "\(page)#\(crew.rawValue).\(key.linkText)")!
    }

    static func appURL(crew: CrewID, key: CrewKey) -> URL {
        URL(string: "\(scheme)://join#\(crew.rawValue).\(key.linkText)")!
    }

    /// The crew and key a link carries, or nil.
    static func read(_ url: URL) -> (crew: CrewID, key: CrewKey)? {
        // The address without what follows the #, so `/join` is not also
        // `/joinery`.
        let address = url.absoluteString.split(separator: "#", maxSplits: 1).first.map(String.init) ?? ""
        let isPage = ([page] + otherPages).contains(address)
        let isApp = url.scheme == scheme && url.host == "join"
        guard isPage || isApp, let fragment = url.fragment, let dot = fragment.lastIndex(of: ".") else { return nil }
        let crew = String(fragment[..<dot])
        guard crew.hasPrefix("crew-"), crew.count <= 64,
              crew.dropFirst(5).allSatisfy({ $0.isHexDigit || $0 == "-" }),
              let key = CrewKey(linkText: String(fragment[fragment.index(after: dot)...])) else { return nil }
        return (CrewID(rawValue: crew), key)
    }
}

/// **This phone's crew keys, by crew** (`CrewKeyRing`, shared with the
/// notification extension). A copy goes to the private database as a few
/// hundred bytes so a second phone of yours has them too
/// (`PublicCrewCloud.backUpKeys`); a full iCloud only means the second
/// phone re-joins by the link.
nonisolated struct CrewKeyStore: Sendable {
    let ring: CrewKeyRing

    init(suite: String? = CrewKeyRing.groupID) { ring = CrewKeyRing(suite: suite) }

    var all: [CrewID: CrewKey] {
        var out: [CrewID: CrewKey] = [:]
        for (crew, key) in ring.all { out[CrewID(rawValue: crew)] = key }
        return out
    }

    func key(for crew: CrewID) -> CrewKey? { ring.all[crew.rawValue] }
    /// Every key the crew's records may be sealed with, the current first.
    func candidates(for crew: CrewID) -> [CrewKey] { ring.candidates(for: crew.rawValue) }
    func remember(_ key: CrewKey, for crew: CrewID) { ring.remember(key, for: crew.rawValue) }
    func advance(to key: CrewKey, for crew: CrewID) { ring.advance(to: key, for: crew.rawValue) }
    func set(_ key: CrewKey?, for crew: CrewID) { ring.set(key, for: crew.rawValue) }
    func removeAll() { ring.removeAll() }
}
