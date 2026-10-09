import Foundation

/// **The invite link**: `https://jlbetts-cpu.github.io/Strata/join.html#<crew>.<key>`.
/// The page opens the app by its own scheme, `somewins://join#<crew>.<key>`,
/// and both forms are read here. A link without a valid crew and key is no
/// invitation.
nonisolated enum CrewInviteLink {
    static let page = "https://jlbetts-cpu.github.io/Strata/join.html"
    static let scheme = "somewins"

    static func url(crew: CrewID, key: CrewKey) -> URL {
        URL(string: "\(page)#\(crew.rawValue).\(key.linkText)")!
    }

    static func appURL(crew: CrewID, key: CrewKey) -> URL {
        URL(string: "\(scheme)://join#\(crew.rawValue).\(key.linkText)")!
    }

    /// The crew and key a link carries, or nil.
    static func read(_ url: URL) -> (crew: CrewID, key: CrewKey)? {
        let isPage = url.absoluteString.hasPrefix(page)
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
    func set(_ key: CrewKey?, for crew: CrewID) { ring.set(key, for: crew.rawValue) }
    func removeAll() { ring.removeAll() }
}
