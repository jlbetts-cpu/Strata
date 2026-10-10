import CryptoKit
import Foundation

/// **A crew's secret, and the link that carries it** (the unification pass,
/// 2026-10-09; `tasks/unification-log.md` §1 has the reasoning in plain
/// words).
///
/// Crews live in the app's PUBLIC CloudKit database now, so a full iCloud
/// can never stop one. The public database has no per-crew access list, so
/// every crew is sealed end to end: one AES-256-GCM key per crew, made on
/// the phone that starts it, carried only inside the invite link after the
/// `#` (the part of a web address a browser never sends to a server), and
/// used on each phone to seal what it posts and open what it reads.
nonisolated struct CrewKey: Equatable, Sendable {
    let bytes: Data

    /// A short public name for the key, which says which key it is and
    /// nothing about it (`CrewRekey`).
    var mark: String {
        SHA256.hash(data: bytes).prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    static func new() -> CrewKey {
        CrewKey(bytes: SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) })
    }

    private var symmetric: SymmetricKey { SymmetricKey(data: bytes) }

    /// Sealed, bound to `context` (the record's name and slot), so a box
    /// cannot be lifted from one record and replayed into another.
    func seal(_ data: Data, context: String) throws -> Data {
        guard let combined = try AES.GCM.seal(data, using: symmetric, authenticating: Data(context.utf8)).combined else {
            throw CrewKeyError.sealFailed
        }
        return combined
    }

    func open(_ sealed: Data, context: String) throws -> Data {
        try AES.GCM.open(AES.GCM.SealedBox(combined: sealed), using: symmetric, authenticating: Data(context.utf8))
    }

    /// URL-safe base64, no padding: what the link carries.
    var linkText: String {
        bytes.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init(bytes: Data) { self.bytes = bytes }

    init?(linkText: String) {
        var text = linkText.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while text.count % 4 != 0 { text += "=" }
        guard let data = Data(base64Encoded: text), data.count == 32 else { return nil }
        bytes = data
    }
}

nonisolated enum CrewKeyError: Error { case sealFailed }

/// **This phone's crew keys, by crew ID**, in the app group's defaults so
/// the notification extension can open a friend's win to name it on the
/// lock screen. Never in the public database. The app reads it through
/// `CrewKeyStore`, typed by `CrewID`.
nonisolated struct CrewKeyRing: Sendable {
    static let groupID = "group.JaydenBetts.Strata"
    private static let defaultsKey = "crews.keys"
    /// The keys a crew had before its current one (`CrewRekey`): what was
    /// sealed before a re-key is still read with them.
    private static let olderKey = "crews.keys.older"
    let suite: String?

    init(suite: String? = CrewKeyRing.groupID) { self.suite = suite }

    private var defaults: UserDefaults { suite.flatMap(UserDefaults.init(suiteName:)) ?? .standard }

    var all: [String: CrewKey] {
        let raw = defaults.dictionary(forKey: Self.defaultsKey) as? [String: Data] ?? [:]
        var out: [String: CrewKey] = [:]
        for (crew, bytes) in raw where bytes.count == 32 { out[crew] = CrewKey(bytes: bytes) }
        return out
    }

    /// Setting a crew's key to nothing forgets its older keys too.
    func set(_ key: CrewKey?, for crew: String) {
        var raw = defaults.dictionary(forKey: Self.defaultsKey) as? [String: Data] ?? [:]
        raw[crew] = key?.bytes
        defaults.set(raw, forKey: Self.defaultsKey)
        if key == nil {
            var older = defaults.dictionary(forKey: Self.olderKey) as? [String: [Data]] ?? [:]
            older[crew] = nil
            defaults.set(older, forKey: Self.olderKey)
        }
    }

    func older(for crew: String) -> [CrewKey] {
        ((defaults.dictionary(forKey: Self.olderKey) as? [String: [Data]])?[crew] ?? [])
            .filter { $0.count == 32 }.map(CrewKey.init(bytes:))
    }

    /// Every key a crew's records may be sealed with, the current one first.
    func candidates(for crew: String) -> [CrewKey] {
        (all[crew].map { [$0] } ?? []) + older(for: crew)
    }

    /// A key the crew used to have, kept for reading.
    func remember(_ key: CrewKey, for crew: String) {
        guard all[crew] != key else { return }
        var older = defaults.dictionary(forKey: Self.olderKey) as? [String: [Data]] ?? [:]
        var list = older[crew] ?? []
        guard !list.contains(key.bytes) else { return }
        list.insert(key.bytes, at: 0)
        // A crew re-keyed more often than this in two weeks is not a crew.
        older[crew] = Array(list.prefix(16))
        defaults.set(older, forKey: Self.olderKey)
    }

    /// The crew's key becomes `key`; the one it had is kept for reading.
    func advance(to key: CrewKey, for crew: String) {
        let was = all[crew]
        guard was != key else { return }
        var older = defaults.dictionary(forKey: Self.olderKey) as? [String: [Data]] ?? [:]
        var list = (older[crew] ?? []).filter { $0 != key.bytes }
        if let was, !list.contains(was.bytes) { list.insert(was.bytes, at: 0) }
        older[crew] = Array(list.prefix(16))
        defaults.set(older, forKey: Self.olderKey)
        var raw = defaults.dictionary(forKey: Self.defaultsKey) as? [String: Data] ?? [:]
        raw[crew] = key.bytes
        defaults.set(raw, forKey: Self.defaultsKey)
    }

    func removeAll() {
        defaults.removeObject(forKey: Self.defaultsKey)
        defaults.removeObject(forKey: Self.olderKey)
    }
}

nonisolated enum CrewItemRecord {
    static let type = "CrewItem"

    static func name(crew: String, kind: String, name: String) -> String { "\(crew)~\(kind)~\(name)" }

    /// The string fields of an opened box, for the notification extension,
    /// which does not know the app's value type. The box is the app's
    /// `RecordFields` as JSON: each value `{"string": {"_0": ...}}` and so on.
    /// The words of a box sealed with any of `keys`: a crew that was
    /// re-keyed still has posts under the key before.
    static func strings(in box: Data, keys: [CrewKey], recordName: String) -> [String: String] {
        for key in keys {
            let found = strings(in: box, key: key, recordName: recordName)
            if !found.isEmpty { return found }
        }
        return [:]
    }

    static func strings(in box: Data, key: CrewKey, recordName: String) -> [String: String] {
        guard let json = try? key.open(box, context: recordName),
              let object = try? JSONSerialization.jsonObject(with: json) as? [String: Any] else { return [:] }
        var out: [String: String] = [:]
        for (name, value) in object {
            guard let tagged = value as? [String: Any], let inner = tagged.values.first as? [String: Any],
                  let text = inner["_0"] as? String else { continue }
            out[name] = text
        }
        return out
    }
}
