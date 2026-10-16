import CryptoKit
import Foundation

/// **A personal chat, started from a story reply** (the owner, 2026-10-16:
/// "make it so you can reply to stories and it go to your personal chat",
/// "it just goes to your guys personal chat").
///
/// Friends here are the people you share a crew with, so a one-to-one chat
/// is a crew of two (`Crew.isPersonal`), made the first time one of you
/// replies to the other's story, as a Snapchat friendship has a chat without
/// anyone setting one up. The invitation to it is left in a crew you already
/// share, **sealed to that friend's own public key** (HPKE, the key their
/// member record publishes for re-keys, `CrewAgreement`), so nobody else in
/// that crew can open it, and their phone joins on its next sync.
nonisolated struct PersonalInvite: Equatable, Sendable {
    let from: UUID
    let to: UUID
    /// The new crew's invitation link, sealed to `to` alone.
    let sealed: Data
    let createdAt: Date

    static func name(from: UUID, to: UUID) -> String { "\(from.uuidString)-\(to.uuidString)" }
    var name: String { Self.name(from: from, to: to) }
}

/// One message sealed to one person's public key: HPKE, as `CrewRekey` locks
/// a crew's new key to each member.
nonisolated enum CrewSealedNote {
    private static let suite = HPKE.Ciphersuite.Curve25519_SHA256_ChachaPoly
    private static let encapsulated = 32
    /// Larger than any invitation link could be.
    static let largest = 4096

    static func info(from: UUID, to: UUID) -> Data { Data("somewins.personal|\(from.uuidString)|\(to.uuidString)".utf8) }

    static func seal(_ data: Data, to publicText: String, info: Data) -> Data? {
        guard let raw = Data(base64Encoded: publicText),
              let key = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: raw),
              var sender = try? HPKE.Sender(recipientKey: key, ciphersuite: suite, info: info),
              let sealed = try? sender.seal(data) else { return nil }
        return sender.encapsulatedKey + sealed
    }

    static func open(_ data: Data, with key: Curve25519.KeyAgreement.PrivateKey, info: Data) -> Data? {
        guard data.count > encapsulated, data.count <= largest,
              var recipient = try? HPKE.Recipient(privateKey: key, ciphersuite: suite, info: info,
                                                  encapsulatedKey: data.prefix(encapsulated)),
              let opened = try? recipient.open(data.dropFirst(encapsulated)) else { return nil }
        return Data(opened)
    }
}
