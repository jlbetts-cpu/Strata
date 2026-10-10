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
            // A public key that is not one (see `isKey`) gets no copy; the
            // caller has already refused to re-key over one.
            guard let raw = Data(base64Encoded: text),
                  let key = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: raw),
                  var sender = try? HPKE.Sender(recipientKey: key, ciphersuite: suite, info: info(crew)),
                  let sealed = try? sender.seal(new.bytes) else { continue }
            wraps[text] = (sender.encapsulatedKey + sealed).base64EncodedString()
        }
        let prev = try new.seal(old.bytes, context: prevContext(crew)).base64EncodedString()
        return try JSONEncoder().encode(Box(mark: new.mark, wraps: wraps, prev: prev))
    }

    /// Whether `text` is a public key a new crew key can be locked to.
    static func isKey(_ text: String) -> Bool {
        guard let raw = Data(base64Encoded: text), raw.count == 32,
              let key = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: raw),
              (try? HPKE.Sender(recipientKey: key, ciphersuite: suite, info: Data())) != nil else { return false }
        return true
    }

    /// The most a rekey record can be: a copy for each of eight people is
    /// about two thousand bytes. Anything larger is not one.
    static let largest = 8192

    static func read(_ data: Data) -> Box? {
        guard data.count <= largest else { return nil }
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
    /// record of a crew.
    ///
    /// - **The crew's key is the one the starter's newest record gives this
    ///   phone**, whether or not the phone has seen that key before (the
    ///   re-key review, 2026-10-10: taking only keys it had never seen, a
    ///   phone pushed back to an old key by a stale backup could never
    ///   return to the right one).
    /// - **The keys before** are followed back through `prev`, from the
    ///   starter's records only once the starter is known: followed from
    ///   anyone's, a removed person holding an old key could feed a phone
    ///   made-up "earlier keys" until the real ones were crowded out.
    static func learn(_ seen: [Seen], crew: String, current: CrewKey?, older: [CrewKey],
                      mine: Curve25519.KeyAgreement.PrivateKey?, starterKnown: Bool = false) -> Learned {
        var known = (current.map { [$0] } ?? []) + older
        var found: [CrewKey] = []
        let trusted = starterKnown ? seen.filter(\.fromStarter) : seen
        /// Every key before any key held, back to the first.
        func chain() {
            var more = true
            while more {
                more = false
                for record in trusted {
                    guard let before = previous(record.box, crew: crew, known: known), !known.contains(before) else { continue }
                    known.append(before)
                    found.append(before)
                    more = true
                }
            }
        }
        chain()
        var learned = Learned()
        if let mine {
            for record in seen.filter(\.fromStarter).sorted(by: { $0.at > $1.at }) {
                guard let key = unwrap(record.box, crew: crew, mine: mine) else { continue }
                if key != current {
                    learned.current = key
                    if let current, !older.contains(current) { found.append(current) }
                    if !known.contains(key) { known.append(key) }
                    chain()
                }
                break
            }
        }
        let now = learned.current
        for key in found where key != now && !older.contains(key) && !learned.older.contains(key) {
            learned.older.append(key)
        }
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

    /// The private key this phone has, or nil. **Reading never makes one**
    /// (`CrewKeyWrap.existing` says why): a key minted before the real one
    /// arrived from the iCloud Keychain could win there, and the public key
    /// already in your member record would have no private half anywhere.
    static func existing() -> Curve25519.KeyAgreement.PrivateKey? {
        var find = query()
        find[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        find[kSecReturnData as String] = true
        find[kSecMatchLimit as String] = kSecMatchLimitOne
        var found: CFTypeRef?
        guard SecItemCopyMatching(find as CFDictionary, &found) == errSecSuccess, let data = found as? Data else { return nil }
        return try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data)
    }

    /// The private key, made if there is none: only for publishing its
    /// public half in your member record.
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
