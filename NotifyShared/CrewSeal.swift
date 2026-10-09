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
    let suite: String?

    init(suite: String? = CrewKeyRing.groupID) { self.suite = suite }

    private var defaults: UserDefaults { suite.flatMap(UserDefaults.init(suiteName:)) ?? .standard }

    var all: [String: CrewKey] {
        let raw = defaults.dictionary(forKey: Self.defaultsKey) as? [String: Data] ?? [:]
        var out: [String: CrewKey] = [:]
        for (crew, bytes) in raw where bytes.count == 32 { out[crew] = CrewKey(bytes: bytes) }
        return out
    }

    func set(_ key: CrewKey?, for crew: String) {
        var raw = defaults.dictionary(forKey: Self.defaultsKey) as? [String: Data] ?? [:]
        raw[crew] = key?.bytes
        defaults.set(raw, forKey: Self.defaultsKey)
    }

    func removeAll() { defaults.removeObject(forKey: Self.defaultsKey) }
}

/// **The public record a crew item lives in**: `CrewItem`, named
/// `<crew>~<kind>~<name>`, its fields sealed in `box` as JSON.
nonisolated enum CrewItemRecord {
    static let type = "CrewItem"

    static func name(crew: String, kind: String, name: String) -> String { "\(crew)~\(kind)~\(name)" }

    /// The string fields of an opened box, for the notification extension,
    /// which does not know the app's value type. The box is the app's
    /// `RecordFields` as JSON: each value `{"string": {"_0": ...}}` and so on.
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
