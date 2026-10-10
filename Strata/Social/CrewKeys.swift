import Foundation

/// **The invite link**: `https://jlbetts-cpu.github.io/Strata/join.html#<crew>.<key>`.
/// The page opens the app by its own scheme, `somewins://join#<crew>.<key>`,
/// and every form is read here. A link without a valid crew and key is no
/// invitation.
///
/// **It moves to `https://somewins.xyz/join`** (the owner's own address,
/// bought 2026-10-10: "there shouldnt say github in the link") in the build
/// after the domain is live: that day it still showed the registrar's
/// parking page, and a link to it would have been a dead invitation. This
/// build already reads those links, so the change is `page` and nothing else.
nonisolated enum CrewInviteLink {
    static let page = "https://jlbetts-cpu.github.io/Strata/join.html"
    /// The other addresses the page answers at, now or soon.
    static let otherPages = ["https://jlbetts-cpu.github.io/Strata/join", "https://somewins.xyz/join",
                             "https://somewins.xyz/join.html", "https://www.somewins.xyz/join"]
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
