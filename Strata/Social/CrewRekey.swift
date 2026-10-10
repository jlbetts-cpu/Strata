import CryptoKit
import Foundation
import Security

/// **A crew gets a new key when someone is removed** (2026-10-10; the open
/// item from the review of the public-database move).
///
/// A crew is sealed with one key, and everyone in it holds it. Removing
/// someone stopped the app showing them the crew, but they still held the
/// key, so someone technical with the old invite link could go on reading.
/// The usual answer in sealed group chat is the one here: on a removal the
/// crew moves to a new key that the removed person never receives.
///
/// **How the new key reaches everyone else.** Every member's sealed member
/// record carries a public key (`CrewAgreement`); its private half lives in
/// that person's iCloud Keychain and nowhere else. The starter's phone makes
/// the new key and writes one `Rekey` record holding it once per remaining
/// member, each copy locked to that member's public key (HPKE, the standard
/// way to do this). Each phone unlocks its own copy. The removed person has
/// no copy.
///
/// **What else the record carries.**
/// - `mark`: a short public name of the new key, so a phone can tell whether
///   the key it holds is still the crew's.
/// - `prev`: the key before, sealed with the new one. Someone invited after
///   the change holds only the new key, and with this can still read the
///   two weeks of posts made before it.
///
/// **Who is believed.** A copy of a key is taken only from a record the
/// crew's starter wrote, which the server vouches for. Anyone can write a
/// record into a crew; a made-up one offering "the new key" would otherwise
/// hand the crew to whoever wrote it. `prev` needs no such check: only
/// someone holding the new key could have sealed it.
///
/// **Old links stop working.** They carry the old key. A phone that joins
/// with one cannot open the crew's own record, which the starter seals again
/// with the new key, and is told the link is old.
///
/// Pure: bytes in, keys out. `PublicCrewCloud` does the CloudKit.
nonisolated enum CrewRekey {
    static let kind = "Rekey"
    private static let suite = HPKE.Ciphersuite.Curve25519_SHA256_ChachaPoly
    private static let encapsulated = 32

    /// What the record holds. Not sealed as a whole: the people who must
    /// read it hold different keys. Each part protects itself.
    struct Box: Codable, Equatable {
        var v = 1
        /// The new key's public name (`CrewKey.mark`).
        var mark: String
        /// The new key, once per member, by that member's public key.
        var wraps: [String: String]
        /// The key before, sealed with the new one.
        var prev: String
    }

    private static func info(_ crew: String) -> Data { Data("somewins.rekey|\(crew)".utf8) }
    private static func prevContext(_ crew: String) -> String { "\(crew)|rekey-prev" }

    /// The record for moving `crew` from `old` to `new`, for the members
    /// whose public keys are `recipients`.
    static func make(new: CrewKey, old: CrewKey, recipients: [String], crew: String) throws -> Data {
        var wraps: [String: String] = [:]
        for text in Set(recipients) {
            guard let raw = Data(base64Encoded: text),
                  let key = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: raw) else { continue }
            var sender = try HPKE.Sender(recipientKey: key, ciphersuite: suite, info: info(crew))
            let sealed = try sender.seal(new.bytes)
            wraps[text] = (sender.encapsulatedKey + sealed).base64EncodedString()
        }
        let prev = try new.seal(old.bytes, context: prevContext(crew)).base64EncodedString()
        return try JSONEncoder().encode(Box(mark: new.mark, wraps: wraps, prev: prev))
    }

    static func read(_ data: Data) -> Box? {
        guard let box = try? JSONDecoder().decode(Box.self, from: data), box.v == 1 else { return nil }
        return box
    }

    /// The new key, from this phone's own copy. Nil when there is none for
    /// it, or it does not open.
    static func unwrap(_ box: Box, crew: String, mine: Curve25519.KeyAgreement.PrivateKey) -> CrewKey? {
        let text = mine.publicKey.rawRepresentation.base64EncodedString()
        guard let wrapped = box.wraps[text].flatMap({ Data(base64Encoded: $0) }), wrapped.count > encapsulated,
              var recipient = try? HPKE.Recipient(privateKey: mine, ciphersuite: suite, info: info(crew),
                                                  encapsulatedKey: wrapped.prefix(encapsulated)),
              let bytes = try? recipient.open(wrapped.dropFirst(encapsulated)), bytes.count == 32 else { return nil }
        let key = CrewKey(bytes: Data(bytes))
        // A copy that opens to some other key than the one the record names
        // is not this record's key.
        return key.mark == box.mark ? key : nil
    }

    /// The key before, for a phone holding the new one in `known`.
    static func previous(_ box: Box, crew: String, known: [CrewKey]) -> CrewKey? {
        guard let sealed = Data(base64Encoded: box.prev),
              let new = known.first(where: { $0.mark == box.mark }),
              let bytes = try? new.open(sealed, context: prevContext(crew)), bytes.count == 32 else { return nil }
        return CrewKey(bytes: bytes)
    }

    /// One rekey record as a phone holds it.
    struct Seen {
        var box: Box
        /// Written by the crew's starter, as the server says.
        var fromStarter: Bool
        var at: Date
    }

    struct Learned: Equatable {
        /// The crew's key now, when it changed.
        var current: CrewKey?
        /// Keys from before, new to this phone.
        var older: [CrewKey] = []
        var changed: Bool { current != nil || !older.isEmpty }
    }

    /// What a phone holding `current` and `older` learns from every rekey
    /// record of a crew, oldest first.
    static func learn(_ seen: [Seen], crew: String, current: CrewKey?, older: [CrewKey],
                      mine: Curve25519.KeyAgreement.PrivateKey?) -> Learned {
        var now = current
        var known = (current.map { [$0] } ?? []) + older
        var learned = Learned()
        /// Every key before any key held, back to the first.
        func chain() {
            var found = true
            while found {
                found = false
                for record in seen {
                    guard let before = previous(record.box, crew: crew, known: known), !known.contains(before) else { continue }
                    known.append(before)
                    learned.older.append(before)
                    found = true
                }
            }
        }
        chain()
        for record in seen.sorted(by: { $0.at < $1.at }) where record.fromStarter {
            guard let mine, let key = unwrap(record.box, crew: crew, mine: mine), !known.contains(key) else { continue }
            if let was = now, !learned.older.contains(was), !older.contains(was) { learned.older.append(was) }
            now = key
            known.append(key)
            learned.current = key
            chain()
        }
        // Read into a constant first: asking `learned` for its current key
        // inside a change to `learned` is two accesses at once, which Swift
        // stops the process for.
        let current = learned.current
        learned.older.removeAll { $0 == current }
        return learned
    }

    /// Whether the key held is still the crew's: it is the one the starter's
    /// newest rekey names, or there has been no rekey.
    static func isCurrent(_ key: CrewKey, seen: [Seen]) -> Bool {
        guard let newest = seen.filter(\.fromStarter).max(by: { $0.at < $1.at }) else { return true }
        return newest.box.mark == key.mark
    }
}

/// **This account's key for being sent a crew's new key**: a Curve25519
/// key pair whose private half is kept in the iCloud Keychain, so your other
/// phones have it and nobody else does. The public half goes in your member
/// record. Without iCloud Keychain it stays on this phone, and a second
/// phone gets the crew's new key from the sealed key backup or a fresh link.
nonisolated enum CrewAgreement {
    private static let service = "JaydenBetts.Strata.crewAgreement"
    private static let account = "agree-v1"
    /// The member record's field for the public half.
    static let field = "agree"

    private static func query() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    private static func existing() -> Curve25519.KeyAgreement.PrivateKey? {
        var find = query()
        find[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        find[kSecReturnData as String] = true
        find[kSecMatchLimit as String] = kSecMatchLimitOne
        var found: CFTypeRef?
        guard SecItemCopyMatching(find as CFDictionary, &found) == errSecSuccess, let data = found as? Data else { return nil }
        return try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data)
    }

    /// The private key, made the first time it is asked for.
    static func privateKey() -> Curve25519.KeyAgreement.PrivateKey? {
        if let existing = existing() { return existing }
        let fresh = Curve25519.KeyAgreement.PrivateKey()
        var add = query()
        add[kSecAttrSynchronizable as String] = true
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        add[kSecValueData as String] = fresh.rawRepresentation
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess ? fresh : existing()
    }

    static func publicText(_ key: Curve25519.KeyAgreement.PrivateKey? = privateKey()) -> String? {
        key?.publicKey.rawRepresentation.base64EncodedString()
    }
}
